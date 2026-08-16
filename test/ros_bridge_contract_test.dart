import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:liftant_v2_bitirme/services/ros_bridge_client.dart';
import 'package:liftant_v2_bitirme/services/agv_service.dart';
import 'package:liftant_v2_bitirme/services/ros_gcs_contract.dart';
import 'package:liftant_v2_bitirme/services/ros_hardware_contract.dart';
import 'package:liftant_v2_bitirme/services/ros_mapping_contract.dart';
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

  test('harita sifirlama diger uygulama ayarlarini korur', () async {
    SharedPreferences.setMockInitialValues({
      'dataPoints': <String>['{}'],
      'rosBridgeAddress': 'ws://192.168.1.20:9090/',
      'gcsEventLog': <String>['baglanti kaydi'],
    });
    final model = DataModel();

    await model.clearDataPoints();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('dataPoints'), isFalse);
    expect(prefs.getString('rosBridgeAddress'), 'ws://192.168.1.20:9090/');
    expect(prefs.getStringList('gcsEventLog'), <String>['baglanti kaydi']);
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

  test('demo pozu preview metadata ile PNG pikseline çevrilir', () {
    const metadata = MapPreviewMetadata(
      width: 200,
      height: 200,
      resolution: 0.05,
      originX: -5,
      originY: -5,
    );
    final center = metadata.mapToPixel(0, 0);
    expect(center.x, closeTo(100, 1e-9));
    expect(center.y, closeTo(99, 1e-9));
    expect(center.insideMap, isTrue);

    final outside = metadata.mapToPixel(20, 20);
    expect(outside.insideMap, isFalse);
  });

  test('demo pozu dönüşümünde preview origin yaw uygulanır', () {
    const metadata = MapPreviewMetadata(
      width: 10,
      height: 10,
      resolution: 1,
      originX: 10,
      originY: 20,
      originYaw: 1.5707963267948966,
    );
    final pixel = metadata.mapToPixel(10, 21);
    expect(pixel.x, closeTo(1, 1e-9));
    expect(pixel.y, closeTo(9, 1e-9));
    expect(pixel.insideMap, isTrue);
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

  test('sessiz fakat acik websocket transport baglantisi koparilmaz', () async {
    WebSocket? socket;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      socket = await WebSocketTransformer.upgrade(request);
      socket!.listen((_) {});
    });

    final client = RosBridgeClient();
    await client.connect('ws://127.0.0.1:${server.port}');

    // Eski watchdog 6 saniye topic mesaji gelmeyince saglam socket'i kapatiyordu.
    await Future<void>.delayed(const Duration(milliseconds: 6500));
    expect(client.state.value.isConnected, isTrue);

    await client.dispose();
    await socket?.close();
    await server.close(force: true);
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
          'topic': '/buzzer/state',
          'msg': {'data': false},
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
    final client = RosBridgeClient();
    final buzzerStates = <bool?>[];
    client.onBuzzerState = buzzerStates.add;
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
    expect(
      received.any((message) =>
          message['op'] == 'subscribe' &&
          message['topic'] == '/buzzer/state' &&
          message['type'] == 'std_msgs/msg/Bool'),
      isTrue,
    );
    expect(buzzerStates, contains(false));
    expect(
      received.any((message) =>
          message['op'] == 'subscribe' &&
          message['topic'] == '/map_preview/metadata' &&
          message['type'] == 'nav_msgs/msg/MapMetaData'),
      isTrue,
    );
    expect(
      received.any((message) =>
          message['op'] == 'subscribe' &&
          message['topic'] == '/localization/status' &&
          message['type'] == 'marco_msgs/msg/LocalizationStatus'),
      isTrue,
    );
    expect(
      received.any((message) =>
          message['op'] == 'subscribe' &&
          message['topic'] == '/demo/status' &&
          message['type'] == 'marco_msgs/msg/DemoStatus'),
      isTrue,
    );
    expect(
      received.any((message) =>
          message['op'] == 'subscribe' &&
          message['topic'] == '/safety/obstacle_detected' &&
          message['type'] == 'std_msgs/msg/Bool'),
      isTrue,
    );
    // GCS manuel varsayılan açık; fiziksel anahtar / robot_status kapısı yok.
    expect(client.publishManualDirection(2), isTrue);
    client.setGcsManualEnabled(false);
    expect(client.publishManualDirection(2), isFalse);
    client.setGcsManualEnabled(true);
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
    expect(
      received.any((message) =>
          message['op'] == 'publish' &&
          message['topic'] == '/base/manual_mode' &&
          (message['msg'] as Map)['data'] == false),
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
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      received
          .where((message) =>
              message['op'] == 'subscribe' &&
              message['topic'] == '/buzzer/state')
          .length,
      greaterThanOrEqualTo(2),
    );
    expect(buzzerStates, contains(null));
    expect(buzzerStates.last, isFalse);
    await client.dispose();
    await activeSocket?.close();
    await server.close(force: true);
  });

  test('MapPixelPose boyut ve source alanlarını parse eder', () {
    final pixel = MapPreviewRobotPixel.fromRosMessage({
      'pixel_x': 12.5,
      'pixel_y': 8.0,
      'screen_yaw': 1.2,
      'map_width': 200,
      'map_height': 100,
      'inside_map': true,
      'source': 'slam_toolbox',
    });
    expect(pixel.mapWidth, 200);
    expect(pixel.mapHeight, 100);
    expect(pixel.source, MapPreviewSource.slam_toolbox);
  });

  test('LocalizationStatus state kodlarını parse eder', () {
    final status = LocalizationStatusSnapshot.fromRosMessage({
      'state': 3,
      'field_name': 'saha_01',
      'message': 'lokalize',
      'map_yaml': '/data/saha_01/map.yaml',
    });
    expect(status.status, LocalizationStatus.localizing);
    expect(status.fieldName, 'saha_01');
  });

  test('mapping/lokalizasyon servis zarfları uçtan uca doğrulanır', () async {
    var scenario = <String, dynamic>{};
    final received = <Map<String, dynamic>>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((data) {
        if (data is! String) return;
        final message = Map<String, dynamic>.from(jsonDecode(data));
        if (message['op'] != 'call_service') return;
        received.add(message);
        if (scenario['timeout'] == true) return;
        socket.add(jsonEncode({
          'op': 'service_response',
          'id': message['id'],
          'service': message['service'],
          'result': scenario['result'] ?? true,
          'values': scenario['values'] ?? <String, dynamic>{},
          if (scenario['message'] != null) 'message': scenario['message'],
        }));
      });
    });

    final client = RosBridgeClient(
      serviceTimeout: const Duration(milliseconds: 80),
      saveTimeout: const Duration(milliseconds: 80),
    );
    await client.connect('ws://127.0.0.1:${server.port}');

    final services = <({
      String name,
      String type,
      String key,
      Future<Map<String, dynamic>> Function() call,
      bool Function(Map<String, dynamic>) check,
    })>[
      (
        name: '/mapping/start',
        type: RosMappingTypes.startMappingSrv,
        key: 'accepted',
        call: () => client.startMapping(fieldName: 'saha_01'),
        check: RosServiceResponse.mappingStartAccepted,
      ),
      (
        name: '/mapping/stop',
        type: RosMappingTypes.stopMappingSrv,
        key: 'success',
        call: client.stopMapping,
        check: RosServiceResponse.mappingStopSucceeded,
      ),
      (
        name: '/mapping/save',
        type: RosMappingTypes.saveMappingSrv,
        key: 'success',
        call: client.saveMapping,
        check: RosServiceResponse.mappingSaveSucceeded,
      ),
      (
        name: '/fields/list',
        type: RosMappingTypes.listFieldsSrv,
        key: 'success',
        call: client.listFields,
        check: RosServiceResponse.fieldsListSucceeded,
      ),
      (
        name: '/localization/start',
        type: RosMappingTypes.startLocalizationSrv,
        key: 'accepted',
        call: () => client.startLocalization(fieldName: 'saha_01'),
        check: RosServiceResponse.localizationStartAccepted,
      ),
      (
        name: '/localization/stop',
        type: RosMappingTypes.stopLocalizationSrv,
        key: 'success',
        call: client.stopLocalization,
        check: RosServiceResponse.localizationStopSucceeded,
      ),
      (
        name: '/buzzer/set_enabled',
        type: RosHardwareTypes.setBoolSrv,
        key: 'success',
        call: () => client.setBuzzerEnabled(true),
        check: RosServiceResponse.triggerSucceeded,
      ),
      (
        name: '/demo/point/save',
        type: RosMappingTypes.saveDemoPointSrv,
        key: 'success',
        call: () => client.saveDemoPoint('A'),
        check: RosServiceResponse.demoPointSaveSucceeded,
      ),
      (
        name: '/demo/route/point/save',
        type: RosMappingTypes.saveDemoRoutePointSrv,
        key: 'success',
        call: () => client.saveDemoRoutePoint('A'),
        check: RosServiceResponse.demoRouteOperationSucceeded,
      ),
      (
        name: '/demo/route/clear',
        type: RosMappingTypes.clearDemoRouteSrv,
        key: 'success',
        call: () => client.clearDemoRoute('B'),
        check: RosServiceResponse.demoRouteOperationSucceeded,
      ),
      (
        name: '/demo/start_saved',
        type: RosMappingTypes.triggerSrv,
        key: 'success',
        call: client.startSavedDemo,
        check: RosServiceResponse.triggerSucceeded,
      ),
      (
        name: '/demo/continue',
        type: RosMappingTypes.triggerSrv,
        key: 'success',
        call: client.continueDemo,
        check: RosServiceResponse.triggerSucceeded,
      ),
      (
        name: '/demo/cancel',
        type: RosMappingTypes.triggerSrv,
        key: 'success',
        call: client.cancelDemo,
        check: RosServiceResponse.triggerSucceeded,
      ),
    ];

    for (final service in services) {
      scenario = {
        'result': true,
        'values': {service.key: true, 'message': 'tamam'},
      };
      final success = await service.call();
      expect(service.check(success), isTrue, reason: service.name);
      expect(received.last['service'], service.name);
      expect(received.last['type'], service.type);
      if (service.name == '/demo/point/save') {
        expect(received.last['args'], {'point_name': 'A'});
        expect(received.last['id'], startsWith('save_demo_point_A_'));
      }
      if (service.name == '/buzzer/set_enabled') {
        expect(received.last['args'], {'data': true});
        expect(received.last['id'], startsWith('buzzer_set_enabled_'));
      }
      if (service.name == '/demo/route/point/save') {
        expect(received.last['args'], {'target_name': 'A'});
        expect(received.last['id'], startsWith('save_demo_route_point_A_'));
      }
      if (service.name == '/demo/route/clear') {
        expect(received.last['args'], {'target_name': 'B'});
        expect(received.last['id'], startsWith('clear_demo_route_B_'));
      }
      const demoIds = {
        '/demo/start_saved': 'demo_start',
        '/demo/continue': 'demo_continue',
        '/demo/cancel': 'demo_cancel',
      };
      if (demoIds[service.name] case final expectedId?) {
        expect(received.last['args'], <String, dynamic>{});
        expect(received.last['id'], expectedId);
      }

      scenario = {
        'result': true,
        'values': {service.key: false, 'message': 'reddedildi'},
      };
      final rejected = await service.call();
      expect(service.check(rejected), isFalse, reason: service.name);
      expect(RosServiceResponse.failureMessage(rejected), 'reddedildi');

      scenario = {'result': true, 'values': <String, dynamic>{}};
      expect(service.check(await service.call()), isFalse,
          reason: service.name);

      scenario = {
        'result': false,
        'values': <String, dynamic>{},
        'message': '${service.name} bulunamadı',
      };
      await expectLater(
        service.call(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('bulunamadı'),
          ),
        ),
        reason: service.name,
      );

      scenario = {'timeout': true};
      await expectLater(service.call(), throwsA(isA<TimeoutException>()));
    }

    await client.dispose();
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
