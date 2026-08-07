import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:liftant_v2_bitirme/services/ros_bridge_client.dart';
import 'package:liftant_v2_bitirme/services/agv_service.dart';
import 'package:liftant_v2_bitirme/services/ros_gcs_contract.dart';
import 'package:liftant_v2_bitirme/data_model.dart';

void main() {
  test('adres ws://ROBOT_IP:9090 bicimine normalize edilir', () {
    expect(RosBridgeClient.normalizeAddress('localhost').toString(),
        'ws://localhost:9090/');
    expect(
        RosBridgeClient.normalizeAddress('ws://192.168.1.20:9090').port, 9090);
    expect(() => RosBridgeClient.normalizeAddress('ftp://robot'),
        throwsFormatException);
  });

  test('baglanti hatalari anlasilir mesaja cevrilir', () {
    expect(
      RosBridgeClient.connectionErrorMessage(
        TimeoutException('WebSocket connection timed out'),
      ),
      contains('zaman asimina'),
    );
    expect(
      RosBridgeClient.connectionErrorMessage(
        Exception('Connection refused'),
      ),
      contains('Baglanti reddedildi'),
    );
    expect(
      RosBridgeClient.connectionErrorMessage(
        Exception('Network is unreachable'),
      ),
      contains('ayni Wi-Fi'),
    );
  });

  test('0.05 m OccupancyGrid metadata ekran grid donusumunu belirler', () {
    final metadata = OccupancyGridMetadata.fromRosMessage({
      'info': {
        'resolution': 0.05,
        'width': 200,
        'height': 200,
        'origin': {
          'position': {'x': -5.0, 'y': -5.0, 'z': 0.0},
          'orientation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
        },
      },
    });
    expect(metadata.mapWidthMeters, 10);
    expect(metadata.mapHeightMeters, 10);
    expect(
      RosGcsContract.editorGridToMap(14, 8, metadata).dx,
      closeTo(0, 1e-9),
    );
    expect(
      RosGcsContract.editorGridToMap(14, 8, metadata).dy,
      closeTo(0, 1e-9),
    );
    final bottomLeft = RosGcsContract.editorGridToMap(28, 0, metadata);
    final topRight = RosGcsContract.editorGridToMap(0, 16, metadata);
    expect(bottomLeft.dx, closeTo(-4.975, 1e-9));
    expect(bottomLeft.dy, closeTo(-4.975, 1e-9));
    expect(topRight.dx, closeTo(4.975, 1e-9));
    expect(topRight.dy, closeTo(4.975, 1e-9));
  });

  test('OccupancyGrid origin yaw konum ve yon donusumune uygulanir', () {
    final metadata = OccupancyGridMetadata.fromRosMessage({
      'info': {
        'resolution': 1.0,
        'width': 3,
        'height': 3,
        'origin': {
          'position': {'x': 10.0, 'y': 20.0},
          'orientation': {
            'x': 0.0,
            'y': 0.0,
            'z': 0.7071067811865476,
            'w': 0.7071067811865476,
          },
        },
      },
    });
    final point = RosGcsContract.editorGridToMap(28, 0, metadata);
    expect(point.dx, closeTo(9.5, 1e-9));
    expect(point.dy, closeTo(20.5, 1e-9));
    expect(
      RosGcsContract.editorYawToMap(0, metadata),
      closeTo(-1.5707963267948966, 1e-9),
    );
  });

  test('gercek ROS dugum eslemesi yalniz rota grafindan gelir', () {
    expect(
      RosGcsContract.nodeForPoint(
        DataPoint(type: 'pickupPointA2', x: 0, y: 0),
      ),
      'alma_2',
    );
    expect(
      RosGcsContract.nodeForPoint(
        DataPoint(type: 'dropoffPointB4', x: 0, y: 0),
      ),
      isNull,
    );
  });

  test('hatali IP timeout/hata durumuna gecer', () async {
    final client =
        RosBridgeClient(connectTimeout: const Duration(milliseconds: 300));
    await expectLater(client.connect('ws://127.0.0.1:1'), throwsA(anything));
    expect(client.state.value.status, RosConnectionStatus.error);
    await client.dispose();
  });

  test('kopunca yeniden baglanir ve manuel dead-man sifir yollar', () async {
    WebSocket? activeSocket;
    final received = <Map<String, dynamic>>[];

    Future<HttpServer> startServer([int port = 0]) async {
      final next = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      next.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        activeSocket = socket;
        socket.listen((data) {
          if (data is String) {
            received.add(Map<String, dynamic>.from(jsonDecode(data)));
          }
        });
        socket.add(jsonEncode({
          'op': 'publish',
          'topic': '/robot_status',
          'msg': {'manual_mode_enabled': false},
        }));
        socket.add(jsonEncode({
          'op': 'publish',
          'topic': '/map',
          'msg': {
            'info': {
              'resolution': 0.05,
              'width': 200,
              'height': 200,
              'origin': {
                'position': {'x': -5.0, 'y': -5.0, 'z': 0.0},
                'orientation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
              },
            },
            'data': const <int>[],
          },
        }));
      });
      return next;
    }

    var server = await startServer();
    final port = server.port;
    final client = RosBridgeClient(messageTimeout: const Duration(seconds: 2));
    final firstMap = Completer<OccupancyGridMetadata>();
    client.onMapMetadata = (metadata) {
      if (metadata != null && !firstMap.isCompleted) {
        firstMap.complete(metadata);
      }
    };
    await client.connect('ws://127.0.0.1:$port');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect((await firstMap.future).resolution, 0.05);
    expect(
      received.any((message) =>
          message['op'] == 'subscribe' && message['topic'] == '/map'),
      isTrue,
    );
    expect(client.publishManualDirection(2), isFalse);
    activeSocket?.add(jsonEncode({
      'op': 'publish',
      'topic': '/robot_status',
      'msg': {'manual_mode_enabled': true},
    }));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(client.publishManualDirection(2), isTrue);
    client.stopManual();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      received
          .where((m) => m['op'] == 'publish' && m['topic'] == '/cmd_vel_manual')
          .any((m) {
        final msg = m['msg'] as Map;
        return (msg['linear'] as Map)['x'] == 0.0;
      }),
      isTrue,
    );

    await activeSocket?.close();
    await server.close(force: true);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(client.state.value.status, isNot(RosConnectionStatus.connected));
    server = await startServer(port);
    final deadline = DateTime.now().add(const Duration(seconds: 4));
    while (
        !client.state.value.isConnected && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(client.state.value.isConnected, isTrue);
    await client.dispose();
    await activeSocket?.close();
    await server.close(force: true);
  });

  const definedLiveUrl = String.fromEnvironment('ROS_BRIDGE_URL');
  final liveUrl = definedLiveUrl.isNotEmpty
      ? definedLiveUrl
      : Platform.environment['ROS_BRIDGE_URL'];
  test('Phase 10 mock_plc servisleri rosbridge uzerinden calisir', () async {
    final client = AgvService.ros;
    final firstStatus = Completer<Map<String, dynamic>>();
    client.onRobotStatus = (status) {
      if (!firstStatus.isCompleted) firstStatus.complete(status);
    };
    await AgvService.connectRos(liveUrl!);
    final status = await firstStatus.future.timeout(const Duration(seconds: 5));
    expect(status, contains('mission_state'));
    expect((await AgvService.resetMissionSafety())['accepted'], isTrue);
    final manual = await AgvService.submitManualTask(
        taskId: 'gui_integration_test',
        pickupNode: 'alma_1',
        dropoffNode: 'birak_1');
    expect(manual['accepted'], isTrue);
    expect((await AgvService.cancelMission())['accepted'], isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect((await AgvService.resetMissionSafety())['accepted'], isTrue);
    expect((await AgvService.startMission())['accepted'], isTrue);
    expect((await AgvService.cancelMission())['accepted'], isTrue);
    await AgvService.disconnectRos();
  }, skip: liveUrl == null ? 'ROS_BRIDGE_URL tanimli degil' : false);
}
