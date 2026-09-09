import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:liftant_v2_bitirme/models/field_graph_models.dart';
import 'package:liftant_v2_bitirme/models/gcs_field_graph_model.dart';
import 'package:liftant_v2_bitirme/models/gcs_mapping_model.dart';
import 'package:liftant_v2_bitirme/node_teach_page.dart';
import 'package:liftant_v2_bitirme/services/field_graph_repository.dart';
import 'package:liftant_v2_bitirme/services/ros_bridge_client.dart';
import 'package:liftant_v2_bitirme/services/ros_mapping_contract.dart';

const _nodeA = FieldNode(
  nodeId: 101,
  name: 'pickup_dock_1',
  role: FieldNodeRole.pickupDock,
  stationId: 'PICKUP_1',
  pose: FieldPose2D(x: 1, y: 2, theta: 0),
  loadRule: FieldLoadRule.empty,
  approachMode: FieldApproachMode.dock,
);

const _nodeB = FieldNode(
  nodeId: 102,
  name: 'dropoff_dock_1',
  role: FieldNodeRole.dropoffDock,
  stationId: 'DROPOFF_1',
  pose: FieldPose2D(x: 3, y: 4, theta: 0),
  loadRule: FieldLoadRule.loaded,
  approachMode: FieldApproachMode.dock,
);

const _status = FieldPackageStatus(
  header: RosHeader.empty,
  state: FieldPackageState.active,
  fieldName: 'competition_field',
  packageHash: 'hash-1',
  nodeCount: 2,
  edgeCount: 0,
  errors: [],
  warnings: [],
  message: 'active',
);

const _active = ActiveField(
  header: RosHeader.empty,
  active: true,
  fieldName: 'competition_field',
  packageVersion: 'v1',
  packageHash: 'hash-1',
  graphFile: '/robot/field_graph.json',
  activatedAt: '',
  message: 'active',
);

class _NodePageRepository extends FieldGraphRepository {
  @override
  Future<List<FieldInfo>> listFields() async => const [
        FieldInfo(
          fieldName: 'competition_field',
          fieldDirectory: '/robot/competition_field',
          mapYaml: '/robot/competition_field/map.yaml',
          previewPng: '/robot/competition_field/preview.png',
          createdAt: '',
          mapReady: true,
          initialPoseReady: true,
          localizationReady: true,
          routeReady: true,
          validationPassed: true,
          routeHash: 'hash-1',
          active: true,
          packageVersion: 'v1',
          packageHash: 'hash-1',
          message: 'active',
        ),
      ];

  @override
  Future<ActiveFieldResult> getActive() async => const ActiveFieldResult(
        message: 'active',
        activeField: _active,
        status: _status,
      );

  @override
  Future<FieldGraphData> getGraph(String fieldName) async =>
      const FieldGraphData(
        message: 'loaded',
        nodes: [_nodeA, _nodeB],
        edges: [],
        status: _status,
      );

  @override
  Future<List<StationApproachConfig>> getStationConfigs(
    String fieldName,
  ) async =>
      const [];
}

class _DraftWithoutActiveRepository extends FieldGraphRepository {
  int saveNodeCalls = 0;
  List<FieldNode> nodes = const [];

  static const draftStatus = FieldPackageStatus(
    header: RosHeader.empty,
    state: FieldPackageState.draft,
    fieldName: 'competition_field',
    packageHash: 'draft-hash',
    nodeCount: 0,
    edgeCount: 0,
    errors: [],
    warnings: [],
    message: 'draft',
  );

  @override
  Future<List<FieldInfo>> listFields() async => const [
        FieldInfo(
          fieldName: 'competition_field',
          fieldDirectory: '/robot/competition_field',
          mapYaml: '/robot/competition_field/map.yaml',
          previewPng: '/robot/competition_field/preview.png',
          createdAt: '',
          mapReady: true,
          initialPoseReady: true,
          localizationReady: true,
          routeReady: false,
          validationPassed: false,
          routeHash: '',
          active: false,
          packageVersion: '',
          packageHash: 'draft-hash',
          message: 'draft',
        ),
      ];

  @override
  Future<ActiveFieldResult> getActive() =>
      throw StateError('active topic is not ready');

  @override
  Future<FieldGraphData> getGraph(String fieldName) async => FieldGraphData(
        message: 'loaded',
        nodes: nodes,
        edges: const [],
        status: draftStatus,
      );

  @override
  Future<FieldMutationResult> saveNode({
    required String fieldName,
    required FieldNode node,
    required bool currentPose,
  }) async {
    saveNodeCalls++;
    nodes = [node];
    return FieldMutationResult(
      message: 'saved',
      packageHash: 'draft-hash-2',
      savedNode: node,
    );
  }

  @override
  Future<List<StationApproachConfig>> getStationConfigs(
    String fieldName,
  ) async =>
      const [];
}

void main() {
  testWidgets('new node id is generated and cannot be edited', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            key: const Key('open-node-editor'),
            onPressed: () => showFieldNodeEditorDialog(
              context: context,
              existingNodeIds: const {101, 102},
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-node-editor')));
    await tester.pumpAndSettle();

    final nodeIdField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    final nodeIdEditor = tester.widget<EditableText>(
      find
          .descendant(
            of: find.byType(TextFormField).first,
            matching: find.byType(EditableText),
          )
          .first,
    );
    expect(nodeIdEditor.readOnly, isTrue);
    expect(find.text('Otomatik oluşturulur ve değiştirilemez'), findsOneWidget);
    final generated = int.parse(nodeIdField.controller!.text);
    expect({101, 102}, isNot(contains(generated)));

    expect(find.text('Düğüm Noktası'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<FieldNodeRole>));
    await tester.pumpAndSettle();
    expect(find.text('Bekleme Noktası'), findsOneWidget);
    expect(find.text('Yük Alma Alanına Yaklaşma'), findsOneWidget);
    expect(find.text('Yük Alma Noktası'), findsOneWidget);
    expect(find.text('Yük Bırakma Alanına Yaklaşma'), findsOneWidget);
    expect(find.text('Yük Bırakma Noktası'), findsOneWidget);
    expect(find.text('Gidiş Kapı İzin Noktası (Q5)'), findsOneWidget);
    expect(find.text('Dönüş Kapı İzin Noktası (Q6)'), findsOneWidget);
    expect(find.text('QR Okuma / Tetikleme Noktası'), findsOneWidget);

    expect(_nodeA.toRosJson()['role'], 'PICKUP_DOCK');
  });

  test('fresh draft field list permits editing while active topic catches up',
      () async {
    final repository = _DraftWithoutActiveRepository();
    final graph = GcsFieldGraphModel(repository: repository)
      ..applyConnection(true);
    addTearDown(graph.dispose);

    await graph.synchronize(preferredField: 'competition_field');

    expect(graph.activeFresh, isFalse);
    expect(graph.selectedFieldActivityKnown, isTrue);
    expect(graph.selectedFieldIsActive, isFalse);
    expect(graph.canEdit, isTrue);

    await graph.saveNode(_nodeA, currentPose: true);
    expect(repository.saveNodeCalls, 1);
    expect(graph.nodes, [_nodeA]);
  });

  testWidgets(
    'localized map field becomes the selected graph field automatically',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final graph = GcsFieldGraphModel(
        repository: _DraftWithoutActiveRepository(),
      )..applyConnection(true);
      final mapping = GcsMappingModel()
        ..applyConnectionState(
          const RosConnectionState(RosConnectionStatus.connected),
        )
        ..applyLocalizationStatus(
          const LocalizationStatusSnapshot(
            status: LocalizationStatus.localizing,
            fieldName: 'competition_field',
          ),
        );
      addTearDown(graph.dispose);
      addTearDown(mapping.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: graph),
            ChangeNotifierProvider.value(value: mapping),
          ],
          child: const MaterialApp(home: NodeTeachPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(graph.selectedFieldName, 'competition_field');
      expect(find.textContaining('Önce Kayıtlı Haritalar'), findsNothing);
      expect(find.byKey(const Key('node-field-selector')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('production-add-node')),
            )
            .onPressed,
        isNotNull,
      );

      final search = tester.widget<TextField>(find.byType(TextField).first);
      expect(search.style?.color, const Color(0xFFE0E0E0));
    },
  );

  testWidgets(
    'nodes page uses canonical graph and active field is read-only',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final graph = GcsFieldGraphModel(repository: _NodePageRepository())
        ..applyConnection(true);
      await graph.synchronize(preferredField: 'competition_field');
      final mapping = GcsMappingModel();
      addTearDown(graph.dispose);
      addTearDown(mapping.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: graph),
            ChangeNotifierProvider.value(value: mapping),
          ],
          child: const MaterialApp(home: NodeTeachPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('pickup_dock_1'), findsOneWidget);
      expect(find.text('dropoff_dock_1'), findsOneWidget);
      expect(find.textContaining('Demo A/B'), findsNothing);
      expect(find.textContaining('A Noktasını'), findsNothing);
      expect(find.textContaining('aktif ve salt okunur'), findsOneWidget);
      expect(find.byKey(const Key('nodes-tab')), findsOneWidget);
      expect(find.byKey(const Key('edges-tab')), findsOneWidget);
      expect(find.byKey(const Key('selected-tab')), findsOneWidget);

      final addNode = tester.widget<FilledButton>(
        find.byKey(const Key('production-add-node')),
      );
      expect(addNode.onPressed, isNull);

      await tester.tap(find.byIcon(Icons.route_outlined));
      await tester.pump();
      final addEdge = tester.widget<FilledButton>(
        find.byKey(const Key('production-add-edge')),
      );
      expect(addEdge.onPressed, isNull);
    },
  );
}
