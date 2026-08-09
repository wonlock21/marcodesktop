import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'occupancy_grid_image.dart';
import 'ros_gcs_contract.dart';
import 'ros_hardware_contract.dart';
import 'ros_mapping_contract.dart';

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
    this.saveTimeout = const Duration(seconds: 40),
  });

  static const robotStatusTopic = '/robot_status';
  static const missionEventsTopic = '/mission/events';
  static const mapTopic = '/map';

  /// Mapping sözleşmesindeki tek kaynak (`RosMappingTopics.cmdVelManual`).
  static const manualVelocityTopic = RosMappingTopics.cmdVelManual;

  final Duration connectTimeout;
  final Duration messageTimeout;
  final Duration serviceTimeout;
  final Duration saveTimeout;

  final ValueNotifier<RosConnectionState> state = ValueNotifier(
    const RosConnectionState(RosConnectionStatus.disconnected),
  );

  void Function(Map<String, dynamic> message)? onRobotStatus;
  void Function(String message)? onMissionEvent;
  void Function(OccupancyGridMetadata? metadata)? onMapMetadata;
  void Function(OccupancyGridFrame? frame)? onMapFrame;

  void Function(MappingStatusSnapshot? status)? onMappingStatus;
  void Function(LocalizationStatusSnapshot? status)? onLocalizationStatus;
  void Function(Uint8List? pngBytes)? onMapPreviewImage;
  void Function(MapPreviewMetadata? metadata)? onMapPreviewMetadata;
  void Function(MapPreviewRobotPixel? robotPixel)? onMapPreviewRobotPixel;

  /// Mapping/preview abonelikleri (yeniden) gönderildikten sonra.
  /// UI last-good tutar; ilk taze preview gelene kadar "güncelleniyor" gösterebilir.
  void Function()? onMappingSubscriptionsReady;

  int _mapParseGeneration = 0;

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

  /// GCS UI manuel modu (fiziksel anahtar yok). `cmd_vel_manual` kapısı.
  bool _gcsManualEnabled = true;
  double _manualLinear = 0;
  double _manualAngular = 0;

  bool get manualModeEnabled => _gcsManualEnabled;
  String get url => _uri?.toString() ?? '';

  /// Operatör GCS’ten Manuel/Otonom seçince çağrılır.
  void setGcsManualEnabled(bool enabled) {
    if (_gcsManualEnabled && !enabled) stopManual();
    _gcsManualEnabled = enabled;
  }

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

  static String connectionErrorMessage(Object error) {
    if (error is TimeoutException) {
      return 'Baglanti zaman asimina ugradi. IP, port ve Wi-Fi baglantisini kontrol edin.';
    }
    final detail = error.toString();
    final normalized = detail.toLowerCase();
    if (normalized.contains('connection refused')) {
      return 'Baglanti reddedildi. Orange Pi acik mi ve rosbridge 9090 portunda calisiyor mu kontrol edin.';
    }
    if (normalized.contains('failed host lookup') ||
        normalized.contains('no such host')) {
      return 'Sunucu adresi bulunamadi. Girilen IP adresini kontrol edin.';
    }
    if (normalized.contains('network is unreachable') ||
        normalized.contains('no route to host')) {
      return 'Orange Pi agina ulasilamiyor. Cihazlarin ayni Wi-Fi aginda oldugunu kontrol edin.';
    }
    if (normalized.contains('certificate') || normalized.contains('tls')) {
      return 'Guvenli WebSocket sertifika hatasi olustu.';
    }
    return 'ROS baglantisi kurulamadi: $detail';
  }

  Future<void> connect(String address) async {
    final nextUri = normalizeAddress(address);
    _manualDisconnect = false;
    _reconnectTimer?.cancel();
    _reconnectAttempt = 0;
    if (_channel != null) await disconnect();
    _manualDisconnect = false;
    _uri = nextUri;
    // Yeni adrese bilinçli bağlanış: eski preview/occupancy temizlenir.
    _clearOccupancyCallbacks();
    _clearMappingPreviewCallbacks();
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
        message: connectionErrorMessage(error),
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
      // Büyük OccupancyGrid JSON; ~1 Hz.
      'throttle_rate': 1000,
    });
    _send({
      'op': 'subscribe',
      'topic': missionEventsTopic,
      'type': 'std_msgs/msg/String',
      'queue_length': 20,
    });
    _send({
      'op': 'subscribe',
      'topic': RosMappingTopics.mappingStatus,
      'type': RosMappingTypes.mappingStatusMsg,
      'queue_length': 1,
      'throttle_rate': 100,
    });
    _send({
      'op': 'subscribe',
      'topic': RosMappingTopics.localizationStatus,
      'type': RosMappingTypes.localizationStatusMsg,
      'queue_length': 1,
      'throttle_rate': 100,
    });
    _send({
      'op': 'subscribe',
      'topic': RosMappingTopics.mapPreviewCompressed,
      'type': RosMappingTypes.compressedImageMsg,
      'queue_length': 1,
      'throttle_rate': 200,
    });
    _send({
      'op': 'subscribe',
      'topic': RosMappingTopics.mapPreviewMetadata,
      'type': RosMappingTypes.mapPreviewMetadataMsg,
      'queue_length': 1,
      'throttle_rate': 200,
    });
    _send({
      'op': 'subscribe',
      'topic': RosMappingTopics.mapPreviewRobotPixel,
      'type': RosMappingTypes.mapPreviewRobotPixelMsg,
      'queue_length': 1,
      'throttle_rate': 50,
    });
    _send({
      'op': 'advertise',
      'topic': manualVelocityTopic,
      'type': RosMappingTypes.twistMsg,
    });
    _send({
      'op': 'advertise',
      'topic': RosHardwareTopics.cmdHardware,
      'type': RosHardwareTypes.stringMsg,
    });
    onMappingSubscriptionsReady?.call();
  }

  /// OccupancyGrid publish'i: ana thread'de jsonDecode yok.
  /// `/map_preview/*` ile karışmasın diye topic tam `/map` olmalı.
  static final RegExp _occupancyMapTopicRe =
      RegExp(r'"topic"\s*:\s*"/map"\s*[,}]');

  static bool _isOccupancyMapPublish(String data) =>
      _occupancyMapTopicRe.hasMatch(data);

  void _onMessage(dynamic data, int generation) {
    if (generation != _generation || data is! String) return;
    _lastInbound = DateTime.now();

    // Büyük OccupancyGrid: ham string'i isolate'e at; UI'yi kilitleme.
    if (_isOccupancyMapPublish(data)) {
      unawaited(_handleMapEnvelope(data, generation));
      return;
    }

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
            final responseMessage =
                response['message']?.toString().trim() ?? '';
            final outerMessage = message['message']?.toString().trim() ?? '';
            completer.completeError(StateError(
              responseMessage.isNotEmpty
                  ? responseMessage
                  : outerMessage.isNotEmpty
                      ? outerMessage
                      : 'ROS servis çağrısı başarısız: ${message['service'] ?? id}',
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
      // Fiziksel / ROS manual_mode_enabled kapısı kullanılmıyor; GCS UI seçer.
      onRobotStatus?.call(status);
    } else if (topic == missionEventsTopic && raw is Map) {
      final event = raw['data'];
      if (event is String) onMissionEvent?.call(event);
    } else if (topic == RosMappingTopics.mappingStatus && raw is Map) {
      _handleMappingStatus(Map<String, dynamic>.from(raw));
    } else if (topic == RosMappingTopics.localizationStatus && raw is Map) {
      _handleLocalizationStatus(Map<String, dynamic>.from(raw));
    } else if (topic == RosMappingTopics.mapPreviewCompressed && raw is Map) {
      _handleMapPreviewCompressed(Map<String, dynamic>.from(raw));
    } else if (topic == RosMappingTopics.mapPreviewMetadata && raw is Map) {
      _handleMapPreviewMetadata(Map<String, dynamic>.from(raw));
    } else if (topic == RosMappingTopics.mapPreviewRobotPixel && raw is Map) {
      _handleMapPreviewRobotPixel(Map<String, dynamic>.from(raw));
    }
  }

  void _handleMappingStatus(Map<String, dynamic> msg) {
    try {
      onMappingStatus?.call(MappingStatusSnapshot.fromRosMessage(msg));
    } catch (error) {
      debugPrint('Geçersiz /mapping/status: $error');
    }
  }

  void _handleLocalizationStatus(Map<String, dynamic> msg) {
    try {
      onLocalizationStatus?.call(
        LocalizationStatusSnapshot.fromRosMessage(msg),
      );
    } catch (error) {
      debugPrint('Geçersiz /localization/status: $error');
    }
  }

  void _handleMapPreviewCompressed(Map<String, dynamic> msg) {
    final bytes = RosCompressedImageCodec.decodeData(msg['data']);
    if (bytes == null || bytes.isEmpty) {
      debugPrint('Geçersiz /map_preview/compressed data');
      return;
    }
    onMapPreviewImage?.call(bytes);
  }

  void _handleMapPreviewMetadata(Map<String, dynamic> msg) {
    try {
      onMapPreviewMetadata?.call(MapPreviewMetadata.fromRosMessage(msg));
    } on FormatException catch (error) {
      debugPrint('Geçersiz /map_preview/metadata: $error');
    }
  }

  void _handleMapPreviewRobotPixel(Map<String, dynamic> msg) {
    try {
      onMapPreviewRobotPixel?.call(MapPreviewRobotPixel.fromRosMessage(msg));
    } on FormatException catch (error) {
      debugPrint('Geçersiz /map_preview/robot_pixel: $error');
    }
  }

  Future<void> _handleMapEnvelope(String rawEnvelope, int generation) async {
    final parseId = ++_mapParseGeneration;
    final result = await parseOccupancyEnvelopeInIsolate(rawEnvelope);
    if (generation != _generation || parseId != _mapParseGeneration) return;
    if (result.metadata == null) {
      debugPrint('Geçersiz /map metadata (isolate parse)');
      return;
    }
    onMapMetadata?.call(result.metadata);
    if (onMapFrame == null) return;
    if (result.frame == null) {
      debugPrint('Geçersiz /map data (parse başarısız)');
    }
    onMapFrame?.call(result.frame);
  }

  Future<Map<String, dynamic>> callService(
    String service,
    String type, [
    Map<String, dynamic> args = const {},
    Duration? timeout,
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
      return await completer.future.timeout(timeout ?? serviceTimeout);
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

  Future<Map<String, dynamic>> submitMission({
    required String taskId,
    required List<String> routeNodes,
    required bool returnHome,
  }) =>
      callService('/mission/submit', 'marco_msgs/srv/SubmitMission', {
        'task_id': taskId,
        'route_nodes': routeNodes,
        'return_home': returnHome,
      });

  Future<Map<String, dynamic>> cancelMission() =>
      callService('/mission/cancel', 'marco_msgs/srv/CancelMission');

  Future<Map<String, dynamic>> resetMissionSafety() =>
      callService('/mission/reset_safety', 'marco_msgs/srv/ResetMissionSafety');

  Future<Map<String, dynamic>> emergencyStop() =>
      callService('/mission/emergency_stop', 'std_srvs/srv/Trigger');

  Future<Map<String, dynamic>> startMapping({required String fieldName}) {
    final error = RosFieldNameRules.validate(fieldName);
    if (error != null) throw ArgumentError(error);
    return callService(
      RosMappingTopics.mappingStart,
      RosMappingTypes.startMappingSrv,
      {'field_name': fieldName.trim()},
    );
  }

  Future<Map<String, dynamic>> stopMapping() => callService(
        RosMappingTopics.mappingStop,
        RosMappingTypes.stopMappingSrv,
      );

  /// `/mapping/save` — ROS sözleşmesi boş args (`{}`).
  Future<Map<String, dynamic>> saveMapping([
    Map<String, dynamic> args = const {},
  ]) =>
      callService(
        RosMappingTopics.mappingSave,
        RosMappingTypes.saveMappingSrv,
        args,
        saveTimeout,
      );

  Future<Map<String, dynamic>> listFields() => callService(
        RosMappingTopics.fieldsList,
        RosMappingTypes.listFieldsSrv,
      );

  Future<Map<String, dynamic>> startLocalization({required String fieldName}) {
    final error = RosFieldNameRules.validate(fieldName);
    if (error != null) throw ArgumentError(error);
    return callService(
      RosMappingTopics.localizationStart,
      RosMappingTypes.startLocalizationSrv,
      {'field_name': fieldName.trim()},
    );
  }

  Future<Map<String, dynamic>> stopLocalization() => callService(
        RosMappingTopics.localizationStop,
        RosMappingTypes.stopLocalizationSrv,
      );

  // ── G.2 stations stubs ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> addStation({
    required String name,
    required String type,
    required double pixelX,
    required double pixelY,
    required double screenYaw,
    required String fieldName,
  }) =>
      callService(
        RosMappingTopics.stationsAdd,
        RosMappingTypes.addStationSrv,
        {
          'name': name.trim(),
          'type': type,
          'pixel_x': pixelX,
          'pixel_y': pixelY,
          'screen_yaw': screenYaw,
          'field_name': fieldName.trim(),
        },
      );

  Future<Map<String, dynamic>> updateStation({
    required String name,
    required String type,
    required double pixelX,
    required double pixelY,
    required double screenYaw,
    required String fieldName,
  }) =>
      callService(
        RosMappingTopics.stationsUpdate,
        RosMappingTypes.updateStationSrv,
        {
          'name': name.trim(),
          'type': type,
          'pixel_x': pixelX,
          'pixel_y': pixelY,
          'screen_yaw': screenYaw,
          'field_name': fieldName.trim(),
        },
      );

  Future<Map<String, dynamic>> deleteStation({required String name}) =>
      callService(
        RosMappingTopics.stationsDelete,
        RosMappingTypes.deleteStationSrv,
        {'name': name.trim()},
      );

  Future<Map<String, dynamic>> listStations([
    Map<String, dynamic> args = const {},
  ]) =>
      callService(
        RosMappingTopics.stationsList,
        RosMappingTypes.listStationsSrv,
        args,
      );

  // ── H.2 routes stubs ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> saveRoute({
    required String name,
    required List<String> nodeNames,
  }) =>
      callService(
        RosMappingTopics.routesSave,
        RosMappingTypes.saveRouteSrv,
        {
          'name': name.trim(),
          'nodes': nodeNames,
        },
      );

  Future<Map<String, dynamic>> listRoutes([
    Map<String, dynamic> args = const {},
  ]) =>
      callService(
        RosMappingTopics.routesList,
        RosMappingTypes.listRoutesSrv,
        args,
      );

  Future<Map<String, dynamic>> deleteRoute({required String name}) =>
      callService(
        RosMappingTopics.routesDelete,
        RosMappingTypes.deleteRouteSrv,
        {'name': name.trim()},
      );

  /// Birimsiz komut ölçeği yayınlar (−1…+1). m/s tavanı STM32’dedir.
  bool publishManualTwist(double linearX, double angularZ) {
    if (!state.value.isConnected || !_gcsManualEnabled) return false;
    final lx = RosManualDriveLimits.clampCommandScale(linearX);
    final az = RosManualDriveLimits.clampCommandScale(angularZ);
    _manualLinear = lx;
    _manualAngular = az;
    _publishTwist(lx, az);
    _manualHeartbeat?.cancel();
    if (lx != 0 || az != 0) {
      _manualHeartbeat = Timer.periodic(
        const Duration(milliseconds: RosManualDriveLimits.heartbeatDefaultMs),
        (_) {
          if (!state.value.isConnected || !_gcsManualEnabled) {
            _manualHeartbeat?.cancel();
            return;
          }
          _publishTwist(_manualLinear, _manualAngular);
        },
      );
    }
    return true;
  }

  /// Yön indeksi + ölçek (0…1) → `/cmd_vel_manual` komut ölçeği.
  bool publishManualDirection(int direction, {double scale = 1}) {
    final value = RosManualDriveLimits.clampCommandScale(scale.abs());
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
    if (state.value.isConnected && _gcsManualEnabled) _publishTwist(0, 0);
  }

  /// Donanım komutu (`/cmd_hardware` ← `std_msgs/String`).
  bool publishHardwareCommand(String command) {
    final data = command.trim();
    if (data.isEmpty || !state.value.isConnected) return false;
    _send({
      'op': 'publish',
      'topic': RosHardwareTopics.cmdHardware,
      'msg': {'data': data},
    });
    return true;
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
    // Geçici kopma: harita last-good kalsın (preview + occupancy silinmez).
    // GCS manuel tercih (_gcsManualEnabled) korunur.
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

  void _clearOccupancyCallbacks() {
    _mapParseGeneration++;
    onMapMetadata?.call(null);
    onMapFrame?.call(null);
  }

  void _clearMappingPreviewCallbacks() {
    onMappingStatus?.call(null);
    onLocalizationStatus?.call(null);
    onMapPreviewImage?.call(null);
    onMapPreviewMetadata?.call(null);
    onMapPreviewRobotPixel?.call(null);
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _watchdogTimer?.cancel();
    stopManual();
    // Manuel kes: komutlar durur; last-good harita UI'da kalabilir.
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
