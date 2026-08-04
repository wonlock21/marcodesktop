import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:liftant_v2_bitirme/services/ros_bridge_client.dart';
import 'package:liftant_v2_bitirme/services/agv_service.dart';

void main() {
  test('adres ws://ROBOT_IP:9090 bicimine normalize edilir', () {
    expect(RosBridgeClient.normalizeAddress('localhost').toString(),
        'ws://localhost:9090/');
    expect(
        RosBridgeClient.normalizeAddress('ws://192.168.1.20:9090').port, 9090);
    expect(() => RosBridgeClient.normalizeAddress('ftp://robot'),
        throwsFormatException);
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
      });
      return next;
    }

    var server = await startServer();
    final port = server.port;
    final client = RosBridgeClient(messageTimeout: const Duration(seconds: 2));
    await client.connect('ws://127.0.0.1:$port');
    await Future<void>.delayed(const Duration(milliseconds: 100));
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
