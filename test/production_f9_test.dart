import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:liftant_v2_bitirme/route_edit_page.dart';
import 'package:liftant_v2_bitirme/models/gcs_mapping_model.dart';
import 'package:liftant_v2_bitirme/services/ros_mapping_contract.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liftant_v2_bitirme/models/field_graph_models.dart';
import 'package:liftant_v2_bitirme/models/gcs_field_graph_model.dart';
import 'package:liftant_v2_bitirme/models/gcs_mission_model.dart';
import 'package:liftant_v2_bitirme/models/gcs_event_log_model.dart';
import 'package:liftant_v2_bitirme/models/robot_status.dart';
import 'package:liftant_v2_bitirme/production_mission_page.dart';
import 'package:liftant_v2_bitirme/scenerio_page.dart';
import 'package:liftant_v2_bitirme/data_model.dart';
import 'package:liftant_v2_bitirme/services/angles.dart';
import 'package:liftant_v2_bitirme/services/field_graph_repository.dart';
import 'package:liftant_v2_bitirme/services/ros_bridge_client.dart';

const dockA = FieldNode(
    nodeId: 761,
    name: 'custom_pickup',
    role: FieldNodeRole.pickupDock,
    stationId: 'WAREHOUSE',
    pose: FieldPose2D.zero,
    loadRule: FieldLoadRule.empty,
    approachMode: FieldApproachMode.dock);
const dockB = FieldNode(
    nodeId: 894,
    name: 'custom_dropoff',
    role: FieldNodeRole.dropoffDock,
    stationId: 'DESTINATION',
    pose: FieldPose2D.zero,
    loadRule: FieldLoadRule.loaded,
    approachMode: FieldApproachMode.dock);
const config = StationApproachConfig(
    stationId: 'WAREHOUSE',
    stationNodeId: 761,
    approachQrId: 'QR_CUSTOM_88',
    dockHeadingYaw: math.pi,
    turnDirection: 'left',
    lineFollowDurationS: 12.5);
Map<String, dynamic> status({int state = 0, String task = ''}) => {
      'mission_state': state,
      'linear_speed': 0.0,
      'task_id': task,
      'task_source': 'gui',
      'estop_active': false,
      'obstacle_detected': false,
      'localization_valid': true,
      'active_field_ready': true,
      'active_field_name': 'custom_field',
      'active_field_hash': 'hash',
      'active_field_version': 'v2',
      'mission_elapsed_s': 0.0,
      'status_detail': state == 1 ? 'gorev kabul edildi' : '',
    };
FieldPackageStatus package(
        {FieldPackageState state = FieldPackageState.active,
        List<String> errors = const [],
        List<String> warnings = const []}) =>
    FieldPackageStatus(
        header: RosHeader.empty,
        state: state,
        fieldName: 'custom_field',
        packageHash: 'hash',
        nodeCount: 2,
        edgeCount: 0,
        errors: errors,
        warnings: warnings,
        message: 'ROS');
ActiveField active() => const ActiveField(
    header: RosHeader.empty,
    active: true,
    fieldName: 'custom_field',
    packageVersion: 'v2',
    packageHash: 'hash',
    graphFile: '/robot/route.geojson',
    activatedAt: '',
    message: 'ROS');

class Repo extends FieldGraphRepository {
  @override
  Future<List<FieldInfo>> listFields() async => [];
  @override
  Future<ActiveFieldResult> getActive() async => ActiveFieldResult(
      message: 'ROS', activeField: active(), status: package());
  @override
  Future<FieldGraphData> getGraph(String name) async => FieldGraphData(
      message: 'ROS', nodes: [dockA, dockB], edges: [], status: package());
  @override
  Future<List<StationApproachConfig>> getStationConfigs(String name) async =>
      [config];
}

class Client extends RosBridgeClient {
  final List<String> calls = [];
  Map<String, dynamic>? submitted;
  Completer<Map<String, dynamic>>? waiting;
  @override
  Future<Map<String, dynamic>> submitMission(
      {required String taskId,
      required List<String> routeNodes,
      bool returnHome = true}) async {
    calls.add('submit');
    submitted = {
      'task_id': taskId,
      'route_nodes': routeNodes,
      'return_home': returnHome
    };
    return waiting == null
        ? {'accepted': true, 'message': 'hazır'}
        : waiting!.future;
  }

  @override
  Future<Map<String, dynamic>> startMission() async {
    calls.add('start');
    return {'accepted': true, 'message': 'başladı'};
  }
}

Future<GcsFieldGraphModel> graphModel() async {
  final model = GcsFieldGraphModel(repository: Repo())..applyConnection(true);
  await model.synchronize();
  return model;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('RobotStatus all source fields and optional defaults are safe', () {
    final fixture =
        jsonDecode(File('test/fixtures/robot_status.json').readAsStringSync())
            as Map<String, dynamic>;
    final robot = RobotStatus.fromRosJson(fixture);
    expect(robot.valid, true);
    expect(robot.raw.length, 56);
    expect(robot.selectedRouteEdges, [812, 999]);
    expect(robot.gateEntryNode, 'custom_gate_return');
    expect(robot.dockingRemainingS, 3.5);
    expect(robot.lastQrAgeS, 0.2);
    expect(robot.activeFieldHash, 'hash');
    final empty = RobotStatus.fromRosJson({
      'mission_state': 'broken',
      'docking_remaining_s': null,
      'selected_route_edges': [1, 'bad'],
      'pose': 'bad'
    });
    expect(empty.valid, false);
    expect(empty.dockingRemainingS.isNaN, true);
    expect(empty.qrTriggerArmed, false);
    expect(empty.pose, isEmpty);
    expect(empty.selectedRouteEdges, [1]);
  });
  test('field name matches ROS manager initial-character and length rules', () {
    expect(RosFieldNameRules.isValid('_field'), false);
    expect(RosFieldNameRules.isValid('-field'), false);
    expect(RosFieldNameRules.isValid('field-1_ok'), true);
    expect(RosFieldNameRules.isValid('a' * 65), false);
  });
  test('station exact serialization and degree/radian round trip', () {
    expect(config.toRosJson(), {
      'station_id': 'WAREHOUSE',
      'station_node_id': 761,
      'approach_qr_id': 'QR_CUSTOM_88',
      'dock_heading_yaw': math.pi,
      'turn_direction': 'left',
      'line_follow_duration_s': 12.5
    });
    expect(StationApproachConfig.fromRosJson(config.toRosJson()).approachQrId,
        config.approachQrId);
    expect(degreesToRadians(180), closeTo(math.pi, 1e-12));
    expect(radiansToDegrees(-math.pi / 2), closeTo(-90, 1e-12));
    expect(radiansToDegrees(degreesToRadians(37.4)), closeTo(37.4, 1e-12));
    final auto = StationApproachConfig.fromRosJson(
        config.toRosJson()..['turn_direction'] = 'auto');
    expect(auto.toRosJson, throwsFormatException);
  });
  test('gate roles use arbitrary IDs, neighbours need no crossing event', () {
    final outbound = dockA.copyWith(role: FieldNodeRole.gateQ5);
    final inbound = dockB.copyWith(role: FieldNodeRole.gateQ6);
    expect(
        FieldNode.fromRosJson(inbound.toRosJson()).role, FieldNodeRole.gateQ6);
    final edge = FieldEdge(
        edgeId: 9351,
        startNodeId: outbound.nodeId,
        endNodeId: inbound.nodeId,
        bidirectional: false,
        cost: 1,
        maxSpeed: 0.2,
        loadRule: FieldLoadRule.any,
        movementDirection: FieldMovementDirection.forward,
        gateEvent: 'q5_outbound');
    expect(edge.validationErrors(nodes: [outbound, inbound]), isEmpty);
    expect(
        edge
            .copyWith(bidirectional: true)
            .validationErrors(nodes: [outbound, inbound]),
        isNotEmpty);
    expect(
        edge.copyWith(gateEvent: '').validationErrors(nodes: [outbound, dockB]),
        isEmpty);
    expect(gateEventForRoles(inbound.role, outbound.role), 'q6_return');
  });
  test('submit does not start; duplicate pending rejected; only explicit start',
      () async {
    final graph = await graphModel();
    final client = Client()..waiting = Completer();
    final model = GcsMissionModel(client: client)
      ..applyConnection(true)
      ..applyStatus(status());
    final pending =
        model.submit(graph: graph, stops: [dockA, dockB], returnHome: false);
    await expectLater(
        model.submit(graph: graph, stops: [dockA, dockB], returnHome: false),
        throwsStateError);
    expect(client.calls, ['submit']);
    client.waiting!.complete({'accepted': true, 'message': 'hazır'});
    await pending;
    expect(client.calls, ['submit']);
    await expectLater(
        model.submit(graph: graph, stops: [dockA, dockB], returnHome: false),
        throwsStateError);
    expect(client.calls, ['submit']);
    expect(model.readyToStart, false);
    model.applyStatus(status(state: 1, task: client.submitted!['task_id']));
    expect(model.readyToStart, true);
    expect(
        client.submitted!['route_nodes'], ['custom_pickup', 'custom_dropoff']);
    await model.start();
    expect(client.calls, ['submit', 'start']);
    await expectLater(model.start(), throwsStateError);
    model.applyStatus({});
    expect(model.statusFresh, false);
    model.applyConnection(false);
    expect(model.readyToStart, false);
    model.dispose();
    graph.dispose();
    await client.dispose();
  });
  test('active field editing is locked; reconnect awaits graph reload',
      () async {
    final graph = await graphModel();
    expect(graph.selectedFieldIsActive, true);
    expect(graph.canEdit, false);
    await expectLater(graph.saveStationConfig(config), throwsStateError);
    graph.applyConnection(false);
    graph.applyConnection(true);
    expect(graph.graphFresh, false);
    await graph.synchronize();
    expect(graph.graphFresh, true);
    expect(graph.stationConfigs.single.approachQrId, 'QR_CUSTOM_88');
    graph.dispose();
  });
  test('unknown events retained, sorted by ROS timestamp, buffer bounded',
      () async {
    final events = GcsEventLogModel();
    await Future<void>.delayed(Duration.zero);
    events.ekleRosEvent(
        '{"stamp": 10, "event": "future_unknown", "payload": "kept"}');
    events.ekleRosEvent('{"stamp": 5, "event": "older"}');
    expect(events.kayitlar.first.mesaj, contains('future_unknown'));
    expect(events.kayitlar.first.mesaj, contains('kept'));
    for (var i = 0; i < GcsEventLogModel.capacity + 5; i++) {
      events.ekleRosEvent('{"stamp": ${i + 20}, "event": "future_$i"}');
    }
    expect(events.kayitlar.length, GcsEventLogModel.capacity);
    await Future<void>.delayed(Duration.zero);
    events.dispose();
  });
  test(
      'fresh localization topic restores readiness without old GUI acknowledgement',
      () {
    final mapping = GcsMappingModel()
      ..applyConnectionState(
          const RosConnectionState(RosConnectionStatus.connected));
    mapping.applyLocalizationStatus(const LocalizationStatusSnapshot(
        status: LocalizationStatus.localizing, fieldName: 'custom_field'));
    expect(mapping.localizationReady, true);
    mapping.applyLocalizationStatus(null);
    expect(mapping.localizationReady, false);
    mapping.applyLocalizationStatus(const LocalizationStatusSnapshot(
        status: LocalizationStatus.localizing, fieldName: 'custom_field'));
    expect(mapping.localizationReady, true);
    mapping.dispose();
  });
  testWidgets('validator displays every error and warning with scroll access',
      (tester) async {
    final graph = GcsFieldGraphModel();
    graph.packageStatus = package(
        state: FieldPackageState.error,
        errors: List.generate(20, (i) => 'error_$i'),
        warnings: List.generate(10, (i) => 'warning_$i'));
    await tester.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
            home: Scaffold(body: FieldValidationPanel(graph: graph)))));
    expect(find.text('HATA: error_0'), findsOneWidget);
    expect(find.text('HATA: error_19'), findsOneWidget);
    expect(find.text('UYARI: warning_0'), findsOneWidget);
    expect(find.text('UYARI: warning_9'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    graph.dispose();
  });
  test(
      'station services and pose publish use exact ROS wire contract; status error is visible',
      () async {
    final requests = <Map<String, dynamic>>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((data) {
        final message = Map<String, dynamic>.from(jsonDecode(data as String));
        requests.add(message);
        if (message['op'] != 'call_service') return;
        if (message['service'] == '/unavailable') {
          socket.add(jsonEncode({
            'op': 'status',
            'level': 'error',
            'id': message['id'],
            'msg': 'Service /unavailable does not exist'
          }));
          return;
        }
        socket.add(jsonEncode({
          'op': 'service_response',
          'result': true,
          'id': message['id'],
          'values': {'success': true, 'message': 'ok'}
        }));
      });
    });
    final client = RosBridgeClient();
    await client.connect('ws://127.0.0.1:${server.port}');
    await client.getStationApproachConfigs('custom_field');
    await client.saveStationApproachConfig('custom_field', config);
    client.publishInitialPose(const FieldPose2D(x: 3, y: 4, theta: math.pi));
    await expectLater(
        client.callService('/unavailable', 'std_srvs/srv/Trigger'),
        throwsA(predicate((e) => e.toString().contains('does not exist'))));
    final get = requests.firstWhere(
        (r) => r['service'] == '/fields/get_station_approach_configs');
    expect(get['type'], 'marco_msgs/srv/GetStationApproachConfigs');
    expect(get['args'], {'field_name': 'custom_field'});
    final save = requests.firstWhere(
        (r) => r['service'] == '/fields/save_station_approach_config');
    expect(save['type'], 'marco_msgs/srv/SaveStationApproachConfig');
    expect(save['args'],
        {'field_name': 'custom_field', 'config': config.toRosJson()});
    final pose = requests.firstWhere(
            (r) => r['topic'] == '/initialpose' && r['op'] == 'publish')['msg']
        as Map;
    expect(pose['header']['frame_id'], 'map');
    expect(pose['pose']['pose']['orientation']['z'], closeTo(1, 1e-12));
    await client.dispose();
    for (final socket in sockets) {
      await socket.close();
    }
    await server.close(force: true);
  });
  testWidgets('original scenario edits and saves offline without ROS commands',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final graph = GcsFieldGraphModel();
    final client = Client();
    final mission = GcsMissionModel(client: client);
    Widget screen() => MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: graph),
              ChangeNotifierProvider.value(value: mission),
            ],
            child: ScreenUtilInit(
                designSize: const Size(390, 844),
                builder: (_, __) => MaterialApp(
                        home: ScenarioPage(
                      dataPoints: [
                        DataPoint(type: 'pickupPointLOCAL_PICK', x: 2, y: 3),
                        DataPoint(type: 'dropoffPointLOCAL_DROP', x: 20, y: 10)
                      ],
                      site: '',
                      rota: '',
                    ))));
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(find.text('SENARYO OLUŞTURMA'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('scenario-station-LOCAL_PICK')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('scenario-station-LOCAL_DROP')));
    await tester.pump();
    await tester.tap(find.text('SENARYOYU KAYDET').first);
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final draft = jsonDecode(prefs.getString('scenarioDraft:local')!);
    expect(draft['stops'], ['LOCAL_PICK', 'LOCAL_DROP']);
    expect(client.calls, isEmpty);
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('scenario-submit')))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('scenario-start')))
            .onPressed,
        isNull);
    expect(find.textContaining('Robota görev gönderilmedi'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(find.text('LOCAL_PICK → LOCAL_DROP'), findsOneWidget);
    await tester.tap(find.text('GERİ AL'));
    await tester.pump();
    expect(find.text('LOCAL_PICK → LOCAL_DROP'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    graph.dispose();
    mission.dispose();
    await client.dispose();
  });
  testWidgets(
      'original scenario submits multiple pairs and starts only explicitly',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final graph = await graphModel();
    final client = Client();
    final mission = GcsMissionModel(client: client)
      ..applyConnection(true)
      ..applyStatus(status());
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: graph),
          ChangeNotifierProvider.value(value: mission)
        ],
        child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, __) => const MaterialApp(
                home: ScenarioPage(dataPoints: [], site: '', rota: '')))));
    await tester.pumpAndSettle();
    for (final name in [
      'custom_pickup',
      'custom_dropoff',
      'custom_pickup',
      'custom_dropoff'
    ]) {
      await tester.tap(find.byKey(ValueKey('scenario-station-$name')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('scenario-submit')));
    await tester.pumpAndSettle();
    expect(client.submitted!['route_nodes'],
        ['custom_pickup', 'custom_dropoff', 'custom_pickup', 'custom_dropoff']);
    expect(client.calls, ['submit']);
    mission.applyStatus(status(state: 1, task: client.submitted!['task_id']));
    await tester.pump();
    await tester.tap(find.byKey(const Key('scenario-start')));
    await tester.pumpAndSettle();
    expect(client.calls, ['submit', 'start']);
    await tester.pumpWidget(const SizedBox());
    graph.dispose();
    mission.dispose();
    await client.dispose();
  });
  testWidgets('cached graph permits scenario selection while disconnected',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final graph = await graphModel();
    graph.applyConnection(false);
    final client = Client();
    final mission = GcsMissionModel(client: client);
    final events = GcsEventLogModel();
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider.value(value: graph),
      ChangeNotifierProvider.value(value: mission),
      ChangeNotifierProvider.value(value: events)
    ], child: const MaterialApp(home: ProductionMissionPage())));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('WAREHOUSE · custom_pickup').last);
    await tester.pumpAndSettle();
    expect(client.calls, isEmpty);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('mission-submit')))
            .onPressed,
        isNull);
    expect(find.textContaining('Gönderme: ROS bağlantısı yok'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    graph.dispose();
    mission.dispose();
    events.dispose();
    await client.dispose();
  });
  testWidgets('production submit and start are separate buttons, no init start',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final graph = await graphModel();
    final client = Client();
    final mission = GcsMissionModel(client: client)
      ..applyConnection(true)
      ..applyStatus(status());
    final events = GcsEventLogModel();
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider.value(value: graph),
      ChangeNotifierProvider.value(value: mission),
      ChangeNotifierProvider.value(value: events)
    ], child: const MaterialApp(home: ProductionMissionPage())));
    await tester.pumpAndSettle();
    expect(client.calls, isEmpty);
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('WAREHOUSE · custom_pickup').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('DESTINATION · custom_dropoff').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mission-submit')));
    await tester.pumpAndSettle();
    expect(client.calls, ['submit']);
    mission.applyStatus(status(state: 1, task: client.submitted!['task_id']));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mission-start')));
    await tester.pumpAndSettle();
    expect(client.calls, ['submit', 'start']);
    await tester.pumpWidget(const SizedBox());
    mission.dispose();
    graph.dispose();
    events.dispose();
    await client.dispose();
  });
}
