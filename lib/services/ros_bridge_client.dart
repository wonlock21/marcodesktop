import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'ros_gcs_contract.dart';

enum RosConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error
}

class RosConnectionState {
  final RosConnectionStatus status;
  final String url;
  final String message;

  const RosConnectionState(this.status, {this.url = '', this.message = ''});

  bool get isConnected => status == RosConnectionStatus.connected;
  bool get isConnecting =>
      status == RosConnectionStatus.connecting ||
      status == RosConnectionStatus.reconnecting;
}

/// rosbridge v2 JSON istemcisi. Yalnizca yerel ws/wss adresine baglanir.
class RosBridgeClient {
  RosBridgeClient({
    this.connectTimeout = const Duration(seconds: 5),
    this.messageTimeout = const Duration(seconds: 6),
    this.serviceTimeout = const Duration(seconds: 5),
  });

  static const robotStatusTopic = '/robot_status';
  static const missionEventsTopic = '/mission/events';
  static const mapTopic = '/map';
  static const manualVelocityTopic = '/cmd_vel_manual';

  final Duration connectTimeout;
  final Duration messageTimeout;
  final Duration serviceTimeout;

  final ValueNotifier<RosConnectionState> state = ValueNotifier(
    const RosConnectionState(RosConnectionStatus.disconnected),
  );

  void Function(Map<String, dynamic> message)? onRobotStatus;
  void Function(String message)? onMissionEvent;
  void Function(OccupancyGridMetadata? metadata)? onMapMetadata;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _watchdogTimer;
  Timer? _manualHeartbeat;
  final Map<String, Completer<Map<String, dynamic>>> _serviceCalls = {};
  int _requestId = 0;
  int _generation = 0;
  int _reconnectAttempt = 0;
  DateTime? _lastInbound;
  Uri? _uri;
  bool _manualDisconnect = false;
  bool _manualModeEnabled = false;
  double _manualLinear = 0;
  double _manualAngular = 0;

  bool get manualModeEnabled => _manualModeEnabled;
  String get url => _uri?.toString() ?? '';

  static Uri normalizeAddress(String input) {
    var value = input.trim();
    if (value.isEmpty) throw const FormatException('ROS adresi bos olamaz');
    if (!value.contains('://')) value = 'ws://$value';
    if (value.startsWith('http://')) value = 'ws://${value.substring(7)}';
    if (value.startsWith('https://')) value = 'wss://${value.substring(8)}';
    final parsed = Uri.parse(value);
    if ((parsed.scheme != 'ws' && parsed.scheme != 'wss') ||
        parsed.host.isEmpty) {
      throw const FormatException('Adres ws://ROBOT_IP:9090 biciminde olmali');
    }
    return Uri(
      scheme: parsed.scheme,
      host: parsed.host,
      port: parsed.hasPort ? parsed.port : 9090,
      path: parsed.path.isEmpty ? '/' : parsed.path,
    );
  }

  Future<void> connect(String address) async {
    final nextUri = normalizeAddress(address);
    _manualDisconnect = false;
    _reconnectTimer?.cancel();
    _reconnectAttempt = 0;
    if (_channel != null) await disconnect();
    _manualDisconnect = false;
    _uri = nextUri;
    onMapMetadata?.call(null);
    await _open(reconnecting: false);
  }

  Future<void> _open({required bool reconnecting}) async {
    final uri = _uri;
    if (uri == null || _manualDisconnect) return;
    final generation = ++_generation;
    state.value = RosConnectionState(
      reconnecting
          ? RosConnectionStatus.reconnecting
          : RosConnectionStatus.connecting,
      url: uri.toString(),
      message: reconnecting ? 'Yeniden baglaniliyor' : 'Baglaniliyor',
    );

    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    try {
      await channel.ready.timeout(connectTimeout);
    } catch (error) {
      if (generation != _generation) return;
      await _closeSink(channel);
      _channel = null;
      state.value = RosConnectionState(
        RosConnectionStatus.error,
        url: uri.toString(),
        message: 'Baglanti hatasi: $error',
      );
      _scheduleReconnect();
      rethrow;
    }
    if (generation != _generation || _manualDisconnect) {
      await _closeSink(channel);
      return;
    }

    _lastInbound = DateTime.now();
    _subscription = channel.stream.listen(
      (data) => _onMessage(data, generation),
      onError: (_) => _onSocketClosed(generation, 'WebSocket hatasi'),
      onDone: () => _onSocketClosed(generation, 'Baglanti koptu'),
      cancelOnError: true,
    );
    _sendSubscriptions();
    _reconnectAttempt = 0;
    state.value = RosConnectionState(
      RosConnectionStatus.connected,
      url: uri.toString(),
      message: 'Bagli',
    );
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final last = _lastInbound;
      if (last != null && DateTime.now().difference(last) > messageTimeout) {
        _onSocketClosed(generation, 'RobotStatus timeout');
      }
    });
  }

  void _sendSubscriptions() {
    _send({
      'op': 'subscribe',
      'topic': robotStatusTopic,
      'type': 'marco_msgs/msg/RobotStatus',
      'queue_length': 1,
      'throttle_rate': 100,
    });
    _send({
      'op': 'subscribe',
      'topic': mapTopic,
      'type': 'nav_msgs/msg/OccupancyGrid',
      'queue_length': 1,
      'throttle_rate': 5000,
    });
    _send({
      'op': 'subscribe',
      'topic': missionEventsTopic,
      'type': 'std_msgs/msg/String',
      'queue_length': 20,
    });
    _send({
      'op': 'advertise',
      'topic': manualVelocityTopic,
      'type': 'geometry_msgs/msg/Twist',
    });
  }

  void _onMessage(dynamic data, int generation) {
    if (generation != _generation || data is! String) return;
    _lastInbound = DateTime.now();
    final dynamic decoded;
    try {
      decoded = jsonDecode(data);
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    final message = Map<String, dynamic>.from(decoded);
    if (message['op'] == 'service_response') {
      final id = message['id']?.toString();
      if (id != null) {
        final completer = _serviceCalls.remove(id);
        if (completer != null && !completer.isCompleted) {
          final values = message['values'];
          final response = values is Map
              ? Map<String, dynamic>.from(values)
              : <String, dynamic>{};
          if (message['result'] == false) {
            completer.completeError(StateError(
              response['message']?.toString() ??
                  'ROS servis çağrısı başarısız: ${message['service'] ?? id}',
            ));
          } else {
            completer.complete(response);
          }
        }
      }
      return;
    }
    if (message['op'] != 'publish') return;
    final topic = message['topic']?.toString();
    final raw = message['msg'];
    if (topic == robotStatusTopic && raw is Map) {
      final status = Map<String, dynamic>.from(raw);
      final nextManual = status['manual_mode_enabled'] == true;
      if (_manualModeEnabled && !nextManual) stopManual();
      _manualModeEnabled = nextManual;
      onRobotStatus?.call(status);
    } else if (topic == missionEventsTopic && raw is Map) {
      final event = raw['data'];
      if (event is String) onMissionEvent?.call(event);
    } else if (topic == mapTopic && raw is Map) {
      try {
        onMapMetadata?.call(
          OccupancyGridMetadata.fromRosMessage(
            Map<String, dynamic>.from(raw),
          ),
        );
      } on FormatException catch (error) {
        debugPrint('Geçersiz /map metadata: $error');
      }
    }
  }

  Future<Map<String, dynamic>> callService(
    String service,
    String type, [
    Map<String, dynamic> args = const {},
  ]) async {
    if (!state.value.isConnected) throw StateError('ROS bagli degil');
    final id = 'gui_${++_requestId}';
    final completer = Completer<Map<String, dynamic>>();
    _serviceCalls[id] = completer;
    _send({
      'op': 'call_service',
      'id': id,
      'service': service,
      'type': type,
      'args': args
    });
    try {
      return await completer.future.timeout(serviceTimeout);
    } finally {
      _serviceCalls.remove(id);
    }
  }

  Future<Map<String, dynamic>> startMission() =>
      callService('/mission/start', 'marco_msgs/srv/StartMission');

  Future<Map<String, dynamic>> submitManualTask({
    required String taskId,
    required String pickupNode,
    required String dropoffNode,
  }) =>
      callService(
        '/mission/submit_manual_task',
        'marco_msgs/srv/SubmitManualTask',
        {
          'task_id': taskId,
          'pickup_node': pickupNode,
          'dropoff_node': dropoffNode
        },
      );

  Future<Map<String, dynamic>> cancelMission() =>
      callService('/mission/cancel', 'marco_msgs/srv/CancelMission');

  Future<Map<String, dynamic>> resetMissionSafety() =>
      callService('/mission/reset_safety', 'marco_msgs/srv/ResetMissionSafety');

  bool publishManualTwist(double linearX, double angularZ) {
    if (!state.value.isConnected || !_manualModeEnabled) return false;
    _manualLinear = linearX;
    _manualAngular = angularZ;
    _publishTwist(linearX, angularZ);
    _manualHeartbeat?.cancel();
    if (linearX != 0 || angularZ != 0) {
      _manualHeartbeat = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!state.value.isConnected || !_manualModeEnabled) {
          _manualHeartbeat?.cancel();
          return;
        }
        _publishTwist(_manualLinear, _manualAngular);
      });
    }
    return true;
  }

  bool publishManualDirection(int direction, {double scale = 1}) {
    final value = scale.clamp(0.0, 1.0).toDouble();
    final command = switch (direction) {
      0 => (0.0, -value),
      1 => (0.7 * value, -0.7 * value),
      2 => (value, 0.0),
      3 => (0.7 * value, 0.7 * value),
      4 => (0.0, value),
      5 => (-0.7 * value, -0.7 * value),
      6 => (-value, 0.0),
      7 => (-0.7 * value, 0.7 * value),
      _ => (0.0, 0.0),
    };
    return publishManualTwist(command.$1, command.$2);
  }

  void stopManual() {
    _manualHeartbeat?.cancel();
    _manualHeartbeat = null;
    _manualLinear = 0;
    _manualAngular = 0;
    if (state.value.isConnected && _manualModeEnabled) _publishTwist(0, 0);
  }

  void _publishTwist(double linearX, double angularZ) {
    _send({
      'op': 'publish',
      'topic': manualVelocityTopic,
      'msg': {
        'linear': {'x': linearX, 'y': 0.0, 'z': 0.0},
        'angular': {'x': 0.0, 'y': 0.0, 'z': angularZ},
      },
    });
  }

  void _send(Map<String, dynamic> message) {
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (_) {
      // onDone yarisi: _onSocketClosed yeniden baglanmayi yonetir.
    }
  }

  Future<void> _closeSink(WebSocketChannel channel) async {
    try {
      await channel.sink.close().timeout(const Duration(milliseconds: 500));
    } catch (_) {
      // Ulasilamayan IP veya kopmus soket kapanis yaniti vermeyebilir.
    }
  }

  void _onSocketClosed(int generation, String reason) {
    if (generation != _generation || _manualDisconnect) return;
    stopManual();
    _generation++;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _subscription?.cancel();
    _subscription = null;
    final channel = _channel;
    if (channel != null) {
      unawaited(_closeSink(channel));
    }
    _channel = null;
    _manualModeEnabled = false;
    onMapMetadata?.call(null);
    for (final call in _serviceCalls.values) {
      if (!call.isCompleted) call.completeError(StateError(reason));
    }
    _serviceCalls.clear();
    state.value = RosConnectionState(
      RosConnectionStatus.error,
      url: url,
      message: reason,
    );
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_manualDisconnect ||
        _uri == null ||
        (_reconnectTimer?.isActive ?? false)) {
      return;
    }
    final seconds = (1 << _reconnectAttempt.clamp(0, 4).toInt());
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _open(reconnecting: true).catchError((_) {});
    });
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _watchdogTimer?.cancel();
    stopManual();
    _manualModeEnabled = false;
    onMapMetadata?.call(null);
    _generation++;
    await _subscription?.cancel();
    _subscription = null;
    final channel = _channel;
    if (channel != null) {
      await _closeSink(channel);
    }
    _channel = null;
    state.value = RosConnectionState(
      RosConnectionStatus.disconnected,
      url: url,
      message: 'Baglanti kesildi',
    );
  }

  Future<void> dispose() async {
    await disconnect();
    state.dispose();
  }
}
