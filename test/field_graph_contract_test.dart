import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liftant_v2_bitirme/models/field_graph_models.dart';
import 'package:liftant_v2_bitirme/models/gcs_field_graph_model.dart';
import 'package:liftant_v2_bitirme/services/agv_service.dart';
import 'package:liftant_v2_bitirme/services/field_graph_repository.dart';
import 'package:liftant_v2_bitirme/services/ros_bridge_client.dart';
import 'package:liftant_v2_bitirme/services/ros_mapping_contract.dart';

const _header = RosHeader(
  stamp: RosTime(sec: 1, nanosec: 2),
  frameId: 'map',
);

FieldNode _node([int id = 101]) => FieldNode(
      nodeId: id,
      name: 'A1',
      role: FieldNodeRole.pickupDock,
      stationId: 'A1',
      pose: const FieldPose2D(x: 2.4, y: 1.1, theta: 3.14),
      loadRule: FieldLoadRule.empty,
      approachMode: FieldApproachMode.dock,
    );

FieldEdge _edge([int id = 5001]) => FieldEdge(
      edgeId: id,
      startNodeId: 101,
      endNodeId: 102,
      bidirectional: true,
      cost: 1,
      maxSpeed: 0.2,
      loadRule: FieldLoadRule.any,
      movementDirection: FieldMovementDirection.forward,
    );

FieldPackageStatus _status({
  FieldPackageState state = FieldPackageState.draft,
  String hash = 'hash-1',
  List<String> errors = const [],
  List<String> warnings = const [],
}) =>
    FieldPackageStatus(
      header: _header,
      state: state,
      fieldName: 'saha_01',
      packageHash: hash,
      nodeCount: 2,
      edgeCount: 1,
      errors: errors,
      warnings: warnings,
      message: 'durum',
    );

ActiveField _active({bool active = false}) => ActiveField(
      header: _header,
      active: active,
      fieldName: active ? 'saha_01' : '',
      packageVersion: active ? 'v1' : '',
      packageHash: active ? 'hash-1' : '',
      graphFile: active ? '/robot/graph.json' : '',
      activatedAt: '',
      message: 'aktif durum',
    );

FieldInfo _fieldInfo() => const FieldInfo(
      fieldName: 'saha_01',
      fieldDirectory: '/robot/saha_01',
      mapYaml: '/robot/saha_01/map.yaml',
      previewPng: '/robot/saha_01/preview.png',
      createdAt: '2026-08-30',
      mapReady: true,
      initialPoseReady: true,
      localizationReady: true,
      routeReady: true,
      validationPassed: false,
      routeHash: '',
      active: false,
      packageVersion: '',
      packageHash: 'hash-1',
      message: 'hazır',
    );

void main() {
  group('Kanonik saha grafiği JSON modelleri', () {
    test('snake_case strict round-trip ve station_id korunur', () {
      final nodeJson = _node().toRosJson();
      final edgeJson = _edge().toRosJson();
      expect(FieldNode.fromRosJson(nodeJson).toRosJson(), nodeJson);
      expect(FieldEdge.fromRosJson(edgeJson).toRosJson(), edgeJson);
      expect(nodeJson['station_id'], 'A1');
      expect(nodeJson, isNot(contains('station')));

      final status = _status(
        state: FieldPackageState.valid,
        errors: const ['e1', 'e2'],
        warnings: const ['w1', 'w2'],
      );
      expect(
        FieldPackageStatus.fromRosJson(status.toRosJson()).toRosJson(),
        status.toRosJson(),
      );
      expect(
        ActiveField.fromRosJson(_active(active: true).toRosJson()).toRosJson(),
        _active(active: true).toRosJson(),
      );
      expect(
        FieldInfo.fromRosJson(_fieldInfo().toRosJson()).toRosJson(),
        _fieldInfo().toRosJson(),
      );
    });

    test('eksik, yanlış tip ve JSON object olmayan metadata reddedilir', () {
      final missing = Map<String, dynamic>.from(_node().toRosJson())
        ..remove('station_id');
      expect(() => FieldNode.fromRosJson(missing), throwsFormatException);

      final wrong = Map<String, dynamic>.from(_node().toRosJson())
        ..['pose'] = {'x': '2.4', 'y': 1.1, 'theta': 0};
      expect(() => FieldNode.fromRosJson(wrong), throwsFormatException);

      expect(
        () => _node().copyWith(metadataJson: '[]').toRosJson(),
        throwsFormatException,
      );
      expect(
        () => _node()
            .copyWith(
              pose: const FieldPose2D(x: double.nan, y: 0, theta: 0),
            )
            .toRosJson(),
        throwsFormatException,
      );
    });

    test('uint64 alanları yalnız güvenli JSON int kabul eder', () {
      expect(
          FieldGraphId.requireSafe(maxSafeRosJsonId, 'id'), maxSafeRosJsonId);
      expect(
        () => FieldGraphId.requireSafe(maxSafeRosJsonId + 1, 'id'),
        throwsFormatException,
      );
      expect(() => FieldGraphId.requireSafe(12.0, 'id'), throwsFormatException);
      expect(() => FieldGraphId.requireSafe(-1, 'id'), throwsFormatException);
      expect(FieldGraphId.next(), inInclusiveRange(1, maxSafeRosJsonId));
    });

    test('topic parser bilinmeyen ek alanı yok sayar, bozuk mesajı reddeder',
        () {
      final json = _active(active: true).toRosJson()..['future_field'] = 42;
      expect(ActiveField.tryFromTopic(json)?.fieldName, 'saha_01');
      expect(ActiveField.tryFromTopic({'active': true}), isNull);
    });
  });

  test('12 field servisi exact ad, tip ve request alanlarını kullanır',
      () async {
    final received = <Map<String, dynamic>>[];
    var includeResult = true;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((data) {
        if (data is! String) return;
        final message = Map<String, dynamic>.from(jsonDecode(data));
        if (message['op'] != 'call_service') return;
        received.add(message);
        socket.add(jsonEncode({
          'op': 'service_response',
          'id': message['id'],
          'service': message['service'],
          if (includeResult) 'result': true,
          'values': {'success': true, 'message': 'ok'},
        }));
      });
    });

    final client = RosBridgeClient();
    await client.connect('ws://127.0.0.1:${server.port}');
    await client.listFields();
    await client.getFieldGraph('saha_01');
    await client.saveFieldNode(fieldName: 'saha_01', node: _node());
    await client.saveCurrentPoseNode(fieldName: 'saha_01', node: _node());
    await client.deleteFieldNode(
      fieldName: 'saha_01',
      nodeId: 101,
      deleteConnectedEdges: true,
    );
    await client.saveFieldEdge(fieldName: 'saha_01', edge: _edge());
    await client.deleteFieldEdge(fieldName: 'saha_01', edgeId: 5001);
    await client.pixelToMap(
      fieldName: 'saha_01',
      pixelX: 12.5,
      pixelY: 8.5,
      screenYaw: 1.2,
    );
    await client.validateField('saha_01');
    await client.activateField(fieldName: 'saha_01', expectedHash: 'hash-1');
    await client.deactivateField(fieldName: 'saha_01', expectedHash: 'hash-1');
    await client.archiveField('saha_01');
    await client.getActiveField();

    final expected = <(String, String)>[
      (RosMappingTopics.fieldsList, RosMappingTypes.listFieldsSrv),
      (RosMappingTopics.fieldsGetGraph, RosMappingTypes.getFieldGraphSrv),
      (RosMappingTopics.fieldsSaveNode, RosMappingTypes.saveFieldNodeSrv),
      (
        RosMappingTopics.fieldsSaveCurrentPoseNode,
        RosMappingTypes.saveCurrentPoseNodeSrv,
      ),
      (RosMappingTopics.fieldsDeleteNode, RosMappingTypes.deleteFieldNodeSrv),
      (RosMappingTopics.fieldsSaveEdge, RosMappingTypes.saveFieldEdgeSrv),
      (RosMappingTopics.fieldsDeleteEdge, RosMappingTypes.deleteFieldEdgeSrv),
      (RosMappingTopics.fieldsPixelToMap, RosMappingTypes.pixelToMapSrv),
      (RosMappingTopics.fieldsValidate, RosMappingTypes.validateFieldSrv),
      (RosMappingTopics.fieldsActivate, RosMappingTypes.activateFieldSrv),
      (
        RosMappingTopics.fieldsDeactivate,
        RosMappingTypes.deactivateFieldSrv,
      ),
      (RosMappingTopics.fieldsArchive, RosMappingTypes.archiveFieldSrv),
      (RosMappingTopics.fieldsGetActive, RosMappingTypes.getActiveFieldSrv),
    ];
    expect(received.length, expected.length);
    for (var i = 0; i < expected.length; i++) {
      expect(received[i]['service'], expected[i].$1);
      expect(received[i]['type'], expected[i].$2);
    }
    expect(received[2]['args']['node']['station_id'], 'A1');
    expect(received[2]['args']['node'], isNot(contains('station')));
    expect(received[4]['args'], {
      'field_name': 'saha_01',
      'node_id': 101,
      'delete_connected_edges': true,
    });
    expect(received[7]['args'], {
      'field_name': 'saha_01',
      'pixel_x': 12.5,
      'pixel_y': 8.5,
      'screen_yaw': 1.2,
    });
    expect(received[9]['args']['expected_hash'], 'hash-1');
    expect(received[10]['args'], {
      'field_name': 'saha_01',
      'expected_hash': 'hash-1',
    });

    includeResult = false;
    await expectLater(client.listFields(), throwsA(isA<StateError>()));

    await client.dispose();
    await server.close(force: true);
  });

  test('disconnect bekleyen servis çağrısını hata ile kapatır', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((_) {});
    });
    final client = RosBridgeClient(serviceTimeout: const Duration(seconds: 5));
    await client.connect('ws://127.0.0.1:${server.port}');
    final pending = client.listFields();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await client.disconnect();
    await expectLater(pending, throwsA(isA<StateError>()));
    await client.dispose();
    await server.close(force: true);
  });

  test('values.success=false repository tarafından başarı sayılmaz', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((data) {
        if (data is! String) return;
        final message = Map<String, dynamic>.from(jsonDecode(data));
        if (message['op'] != 'call_service') return;
        socket.add(jsonEncode({
          'op': 'service_response',
          'id': message['id'],
          'service': message['service'],
          'result': true,
          'values': {'success': false, 'message': 'backend reddetti'},
        }));
      });
    });
    await AgvService.connectRos('ws://127.0.0.1:${server.port}');
    await expectLater(
      const FieldGraphRepository().listFields(),
      throwsA(
        isA<FieldServiceFailure>().having(
          (error) => error.message,
          'message',
          'backend reddetti',
        ),
      ),
    );
    await AgvService.disconnectRos();
    await server.close(force: true);
  });

  group('GcsFieldGraphModel durum kapıları', () {
    test('validate hash aktivasyonu açar; CRUD hash’i geçersiz kılar',
        () async {
      final repository = _FakeRepository();
      final model = GcsFieldGraphModel(repository: repository);
      model.applyConnection(true);
      await model.synchronize(preferredField: 'saha_01');
      model.applyRobotStatus({
        'mission_state': 0,
        'task_id': '',
        'task_source': '',
        'estop_active': false,
        'linear_speed': 0.0,
        'active_field_ready': false,
        'active_field_name': '',
        'active_field_version': '',
        'active_field_hash': '',
      });

      model.applyMappingActive(false);
      expect(model.canActivate, isFalse);
      await model.validateSelected();
      expect(model.validatedHash, 'validated-hash');
      expect(model.canActivate, isTrue);

      await model.saveNode(_node(), currentPose: false);
      expect(model.validatedHash, isNull);
      expect(model.canActivate, isFalse);
    });

    test('inside_map=false node kaydını servis çağrısından önce keser',
        () async {
      final repository = _FakeRepository()..insideMap = false;
      final model = GcsFieldGraphModel(repository: repository);
      model.applyConnection(true);
      await model.synchronize(preferredField: 'saha_01');

      await expectLater(
        model.saveNodeAtPixel(
          node: _node(),
          pixelX: 10,
          pixelY: 20,
          screenYaw: 0,
        ),
        throwsA(isA<StateError>()),
      );
      expect(repository.saveNodeCalls, 0);
    });

    test('reconnect list/get_active/get_graph çağrılarını yeniden kurar',
        () async {
      final repository = _FakeRepository();
      final model = GcsFieldGraphModel(repository: repository);
      model.applyConnection(true);
      await model.synchronize(preferredField: 'saha_01');
      model.markDisconnected();
      expect(model.activeFresh, isFalse);
      expect(model.validatedHash, isNull);
      model.applyConnection(true);
      await model.synchronize();
      expect(repository.listCalls, 2);
      expect(repository.activeCalls, 2);
      expect(repository.graphCalls, 2);
    });

    test('eş zamanlı synchronize graph isteğini single-flight birleştirir',
        () async {
      final repository = _RacingRepository();
      final model = GcsFieldGraphModel(repository: repository);
      model.applyConnection(true);

      final first = model.synchronize(preferredField: 'saha_01');
      await Future<void>.delayed(Duration.zero);
      expect(repository.graphRequests, hasLength(1));
      expect(model.graphLoading, isTrue);

      final second = model.synchronize(preferredField: 'saha_01');
      await Future<void>.delayed(Duration.zero);
      expect(repository.graphRequests, hasLength(1));

      repository.completeGraph(0, nodeName: 'single-flight');
      await Future.wait([first, second]);
      expect(model.graphLoading, isFalse);
      expect(model.graphFresh, isTrue);
      expect(model.nodes.first.name, 'single-flight');
      expect(repository.graphCalls, 1);
    });

    test('aynı saha için doğrudan loadGraph çağrıları birleştirilir', () async {
      final repository = _RacingRepository();
      final model = GcsFieldGraphModel(repository: repository);
      model.applyConnection(true);

      final first = model.loadGraph('saha_01');
      await Future<void>.delayed(Duration.zero);
      final second = model.loadGraph('saha_01');
      await Future<void>.delayed(Duration.zero);
      expect(repository.graphRequests, hasLength(1));

      repository.completeGraph(0, nodeName: 'shared');
      await Future.wait([first, second]);
      expect(repository.graphCalls, 1);
      expect(model.graphFresh, isTrue);
      expect(model.nodes.first.name, 'shared');
    });

    test('backend errors ve warnings dizilerinin tamamı korunur', () async {
      final repository = _FakeRepository()
        ..validationStatus = _status(
          state: FieldPackageState.error,
          errors: const ['e1', 'e2', 'e3'],
          warnings: const ['w1', 'w2'],
        );
      final model = GcsFieldGraphModel(repository: repository);
      model.applyConnection(true);
      await model.synchronize(preferredField: 'saha_01');
      await model.validateSelected();
      expect(model.packageStatus?.errors, ['e1', 'e2', 'e3']);
      expect(model.packageStatus?.warnings, ['w1', 'w2']);
    });
  });
}

class _FakeRepository extends FieldGraphRepository {
  int listCalls = 0;
  int activeCalls = 0;
  int graphCalls = 0;
  int saveNodeCalls = 0;
  bool insideMap = true;
  FieldPackageStatus validationStatus = _status(
    state: FieldPackageState.valid,
    hash: 'validated-hash',
  );

  @override
  Future<List<FieldInfo>> listFields() async {
    listCalls++;
    return [_fieldInfo()];
  }

  @override
  Future<ActiveFieldResult> getActive() async {
    activeCalls++;
    return ActiveFieldResult(
      message: 'eşitlendi',
      activeField: _active(),
      status: _status(),
    );
  }

  @override
  Future<FieldGraphData> getGraph(String fieldName) async {
    graphCalls++;
    return FieldGraphData(
      message: 'grafik',
      nodes: [_node(), _node(102).copyWith(name: 'B1')],
      edges: [_edge()],
      status: _status(hash: saveNodeCalls == 0 ? 'hash-1' : 'hash-2'),
    );
  }

  @override
  Future<FieldValidationResult> validate(String fieldName) async =>
      FieldValidationResult(
        success: validationStatus.state == FieldPackageState.valid,
        message: 'doğrulandı',
        status: validationStatus,
      );

  @override
  Future<FieldMutationResult> saveNode({
    required String fieldName,
    required FieldNode node,
    required bool currentPose,
  }) async {
    saveNodeCalls++;
    return FieldMutationResult(
      message: 'kaydedildi',
      packageHash: 'hash-2',
      savedNode: node,
    );
  }

  @override
  Future<PixelToMapResult> pixelToMap({
    required String fieldName,
    required double pixelX,
    required double pixelY,
    required double screenYaw,
  }) async =>
      PixelToMapResult(
        success: true,
        message: 'dönüştürüldü',
        pose: FieldPose2D(x: pixelX, y: pixelY, theta: screenYaw),
        insideMap: insideMap,
        mapWidth: 200,
        mapHeight: 200,
      );
}

class _RacingRepository extends _FakeRepository {
  final List<Completer<FieldGraphData>> graphRequests = [];

  @override
  Future<FieldGraphData> getGraph(String fieldName) {
    graphCalls++;
    final request = Completer<FieldGraphData>();
    graphRequests.add(request);
    return request.future;
  }

  void completeGraph(
    int index, {
    required String nodeName,
    String packageHash = 'hash-1',
  }) {
    graphRequests[index].complete(
      FieldGraphData(
        message: nodeName,
        nodes: [_node().copyWith(name: nodeName)],
        edges: const [],
        status: _status(hash: packageHash),
      ),
    );
  }
}
