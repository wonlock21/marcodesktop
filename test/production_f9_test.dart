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
import 'package:liftant_v2_bitirme/models/agv_sensor_model.dart';
import 'package:liftant_v2_bitirme/models/gcs_field_graph_model.dart';
import 'package:liftant_v2_bitirme/models/gcs_mission_model.dart';
import 'package:liftant_v2_bitirme/models/gcs_event_log_model.dart';
import 'package:liftant_v2_bitirme/models/robot_status.dart';
import 'package:liftant_v2_bitirme/production_mission_page.dart';
import 'package:liftant_v2_bitirme/scenerio_page.dart';
import 'package:liftant_v2_bitirme/data_model.dart';
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
  model.applyRouteLoadConstraintsReady(true);
  return model;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('fresh RobotStatus restores route readiness after GUI restart',
      () async {
    final graph = GcsFieldGraphModel(repository: Repo())..applyConnection(true);
    await graph.synchronize();

    expect(graph.routeLoadConstraintsFresh, false);
    graph.applyRobotStatus(status());
    expect(graph.routeRuntimeReadinessKnown, true);
    expect(graph.routeRuntimeReady, true);

    // A fresh explicit route topic remains the primary source.
    graph.applyRouteLoadConstraintsReady(false);
    expect(graph.routeRuntimeReady, false);

    graph.markDisconnected();
    expect(graph.routeRuntimeReadinessKnown, false);
    expect(graph.routeRuntimeReady, false);
    graph.dispose();
  });

  test('RobotStatus all source fields and optional defaults are safe', () {
    final fixture =
        jsonDecode(File('test/fixtures/robot_status.json').readAsStringSync())
            as Map<String, dynamic>;
    final robot = RobotStatus.fromRosJson(fixture);
    expect(robot.valid, true);
    expect(robot.raw.length, 56);
    expect(robot.selectedRouteEdges, [812, 999]);
    expect(robot.gateEntryNode, 'custom_gate_return');
    expect(robot.taskSourceLabel, 'GUI');
    expect(robot.gateDirectionLabel, '-');
    expect(robot.gatePermissionLabel, 'Bekleniyor');
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
    expect(empty.pose, isEmpty);
    expect(empty.selectedRouteEdges, [1]);

    final plcGate = RobotStatus.fromRosJson({
      'mission_state': 4,
      'task_source': 'plc',
      'gate_entry_node': 'custom_gate_outbound',
      'gate_direction': 'outbound',
      'gate_permission_granted': true,
    });
    expect(
        plcGate.missionStateLabel, 'Fabrika Otomasyon Sistemi İzni Bekleniyor');
    expect(plcGate.taskSourceLabel, 'PLC');
    expect(plcGate.gateDirectionLabel, 'Gidiş');
    expect(plcGate.gatePermissionLabel, 'Verildi');

    final inactiveGate = RobotStatus.fromRosJson(const {});
    expect(inactiveGate.gatePermissionLabel, 'Aktif Değil');
  });
  test('QR telemetry is shown only while ROS reports a detection', () {
    final telemetry = AgvSensorModel();

    void apply({required String data, required bool detected}) {
      telemetry.updateRobotStatus(
        x: 0,
        y: 0,
        yaw: 0,
        localizationValid: true,
        positionCovariance: 0,
        currentRouteEdge: '',
        nextNode: '',
        crossTrackError: 0,
        obstacleDetected: false,
        lastQrData: data,
        lastQrDetected: detected,
        plcConnected: false,
        estopActive: false,
      );
    }

    apply(data: 'Q2', detected: true);
    expect(telemetry.sonQR, 'Q2');
    apply(data: 'Q2', detected: false);
    expect(telemetry.sonQR, isEmpty);
    telemetry.dispose();
  });
  test('field name matches ROS manager initial-character and length rules', () {
    expect(RosFieldNameRules.isValid('_field'), false);
    expect(RosFieldNameRules.isValid('-field'), false);
    expect(RosFieldNameRules.isValid('field-1_ok'), true);
    expect(RosFieldNameRules.isValid('a' * 65), false);
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
    graph.applyConnection(false);
    graph.applyConnection(true);
    expect(graph.graphFresh, false);
    await graph.synchronize();
    expect(graph.graphFresh, true);
    graph.dispose();
  });
  test('unknown events retained, sorted by ROS timestamp, buffer bounded',
      () async {
    final events = GcsEventLogModel();
    await Future<void>.delayed(Duration.zero);
    events.ekleRosEvent(
        '{"stamp": 10, "event": "future_unknown", "payload": "kept"}');
    events.ekleRosEvent('{"stamp": 5, "event": "older"}');
    expect(events.kayitlar, isEmpty);
    expect(events.hamRosKayitlari.first.raw, contains('kept'));
    for (var i = 0; i < GcsEventLogModel.capacity + 5; i++) {
      events.ekleRosEvent('{"stamp": ${i + 20}, "event": "future_$i"}');
    }
    expect(events.hamRosKayitlari.length, GcsEventLogModel.capacity);
    expect(events.kayitlar, isEmpty);
    await Future<void>.delayed(Duration.zero);
    events.dispose();
  });
  test('operator log translates and merges one mission failure chain',
      () async {
    final events = GcsEventLogModel();
    await Future<void>.delayed(Duration.zero);
    events.ekleRosEvent('{"event":"timed_reverse_docking_failed","stamp":10,'
        '"station":"A3","task_id":"gui_1"}');
    events.ekleRosEvent('{"event":"mission_failed","stamp":11,'
        '"reason":"timed_docking:A3 status=6","task_id":"gui_1"}');
    events.ekleRosEvent('{"event":"mission_complete","stamp":12,'
        '"success":false,"reason":"timed_docking:A3 status=6",'
        '"task_id":"gui_1"}');

    expect(events.hamRosKayitlari, hasLength(3));
    expect(events.kayitlar, hasLength(1));
    expect(events.kayitlar.single.mesaj,
        'Görev başarısız: A3 istasyonuna yanaşılamadı.');
    expect(events.kayitlar.single.mesaj, isNot(contains('task_id')));
    expect(events.kayitlar.single.mesaj, isNot(contains('stamp')));
    events.dispose();
  });
  test('station turn events drive runtime direction and readable log',
      () async {
    final mission = GcsMissionModel();
    final events = GcsEventLogModel();
    await Future<void>.delayed(Duration.zero);
    const selected = '{"event":"station_turn_direction_selected","stamp":10,'
        '"station":"A3","selected_direction":"right",'
        '"left":{"safe":false,"minimum_clearance_m":0.1,'
        '"maximum_cost":254,"reason":"engel"},'
        '"right":{"safe":true,"minimum_clearance_m":0.42,'
        '"maximum_cost":20,"reason":""}}';
    mission.applyEvent(selected);
    events.ekleRosEvent(selected);
    expect(mission.stationTurnStatus?.station, 'A3');
    expect(mission.stationTurnStatus?.selectedDirection, 'right');
    expect(mission.stationTurnStatus?.right.minimumClearanceM, 0.42);
    expect(events.kayitlar.first.mesaj, contains('A3 dönüş yönü: Sağ'));
    expect(events.kayitlar.first.mesaj, contains('Sol yay: Engelli'));

    const unavailable =
        '{"event":"station_turn_direction_unavailable","stamp":11,'
        '"station":"B1","left":{"safe":false,"reason":"unknown"},'
        '"right":{"safe":false,"reason":"costmap dışı"}}';
    mission.applyEvent(unavailable);
    events.ekleRosEvent(unavailable);
    expect(mission.stationTurnStatus?.unavailable, true);
    expect(events.kayitlar.first.mesaj, contains('B1 dönüş yönü seçilemedi'));
    expect(events.kayitlar.first.mesaj, contains('unknown'));
    expect(events.kayitlar.first.mesaj, contains('costmap dışı'));
    mission.dispose();
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
  test('pose publish uses exact ROS wire contract; status error is visible',
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
    client.publishInitialPose(const FieldPose2D(x: 3, y: 4, theta: math.pi));
    await expectLater(
        client.callService('/unavailable', 'std_srvs/srv/Trigger'),
        throwsA(predicate((e) => e.toString().contains('does not exist'))));
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
    expect(find.byKey(const Key('scenario-start')), findsNothing);
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
      'original scenario submits multiple pairs without starting the mission',
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
    expect(find.byKey(const ValueKey('scenario-station-custom_pickup')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('scenario-station-custom_dropoff')),
        findsNothing);
    for (final name in ['custom_pickup', 'custom_dropoff']) {
      await tester.tap(find.byKey(ValueKey('scenario-station-$name')));
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('scenario-station-custom_pickup')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('scenario-station-custom_dropoff')),
        findsNothing);
    for (final name in ['custom_pickup', 'custom_dropoff']) {
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
    expect(find.byKey(const Key('scenario-start')), findsNothing);
    expect(find.textContaining('Ana ekrandan'), findsOneWidget);
    expect(client.calls, ['submit']);
    await tester.pumpWidget(const SizedBox());
    graph.dispose();
    mission.dispose();
    await client.dispose();
  });
  testWidgets('mission monitoring does not repeat scenario selection controls',
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
    expect(client.calls, isEmpty);
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    expect(find.byKey(const Key('mission-submit')), findsNothing);
    expect(find.byKey(const Key('mission-start')), findsNothing);
    expect(find.textContaining('yalnız çalışan görevi izler'), findsNothing);
    expect(find.byKey(const Key('raw-ros-logs-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('raw-ros-logs-button')));
    await tester.pumpAndSettle();
    expect(find.text('Ham ROS Mesajları'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    graph.dispose();
    mission.dispose();
    events.dispose();
    await client.dispose();
  });
  testWidgets('production monitoring never sends commands on init',
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
    expect(find.byKey(const Key('mission-submit')), findsNothing);
    expect(find.byKey(const Key('mission-start')), findsNothing);
    expect(find.textContaining('Ana Ekrandan'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    mission.dispose();
    graph.dispose();
    events.dispose();
    await client.dispose();
  });
}
