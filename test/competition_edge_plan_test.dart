import 'package:flutter_test/flutter_test.dart';

import 'package:liftant_v2_bitirme/models/field_graph_models.dart';
import 'package:liftant_v2_bitirme/node_teach_page.dart';

FieldNode _node(
  int id,
  String name,
  FieldNodeRole role, {
  required String stationId,
  double? x,
  double? y,
}) =>
    FieldNode(
      nodeId: id,
      name: name,
      role: role,
      stationId: stationId,
      pose: FieldPose2D(
        x: x ?? id.toDouble(),
        y: y ?? (id * 2).toDouble(),
        theta: 0,
      ),
      loadRule: FieldLoadRule.any,
      approachMode: FieldApproachMode.navigate,
    );

FieldEdge _edge(
  int id,
  int start,
  int end, {
  bool bidirectional = true,
  FieldMovementDirection movement = FieldMovementDirection.forward,
  String gateEvent = '',
}) =>
    FieldEdge(
      edgeId: id,
      startNodeId: start,
      endNodeId: end,
      bidirectional: bidirectional,
      cost: 1,
      maxSpeed: 0.2,
      loadRule: FieldLoadRule.any,
      movementDirection: movement,
      gateEvent: gateEvent,
    );

List<FieldNode> _gates() => [
      _node(900, 'Q5', FieldNodeRole.gateQ5, stationId: 'Q5'),
      _node(901, 'Q6', FieldNodeRole.gateQ6, stationId: 'Q6'),
    ];

FieldEdge _findEdge(
  CompetitionEdgePlan plan,
  int start,
  int end,
) =>
    plan.edges.map((item) => item.edge).singleWhere(
          (edge) => edge.startNodeId == start && edge.endNodeId == end,
        );

void main() {
  test('station pairs are directed, ordered by role, and matched by station_id',
      () {
    final nodes = [
      _node(22, 'A2', FieldNodeRole.pickupDock, stationId: 'A2'),
      _node(11, 'A1_approach', FieldNodeRole.pickupApproach, stationId: 'A1'),
      _node(31, 'B1', FieldNodeRole.dropoffDock, stationId: 'B1'),
      _node(21, 'A2_approach', FieldNodeRole.pickupApproach, stationId: 'A2'),
      _node(12, 'A1', FieldNodeRole.pickupDock, stationId: 'A1'),
      _node(30, 'B1_approach', FieldNodeRole.dropoffApproach, stationId: 'B1'),
      ..._gates(),
    ];

    final plan =
        CompetitionEdgePlan.build(nodes: nodes, existingEdges: const []);

    expect(plan.issues, isEmpty);
    expect(plan.edges, hasLength(8));
    for (final pair in const [(11, 12), (21, 22), (30, 31)]) {
      final approachToDock = _findEdge(plan, pair.$1, pair.$2);
      expect(approachToDock.bidirectional, isFalse);
      expect(
        approachToDock.movementDirection,
        FieldMovementDirection.reverse,
      );
      expect(approachToDock.loadRule, FieldLoadRule.any);
      expect(approachToDock.gateEvent, isEmpty);

      final dockToApproach = _findEdge(plan, pair.$2, pair.$1);
      expect(dockToApproach.bidirectional, isFalse);
      expect(
        dockToApproach.movementDirection,
        FieldMovementDirection.forward,
      );
      expect(dockToApproach.loadRule, FieldLoadRule.any);
      expect(dockToApproach.gateEvent, isEmpty);
    }

    expect(
      plan.edges.any(
        (item) => item.edge.startNodeId == 11 && item.edge.endNodeId == 22,
      ),
      isFalse,
    );
    expect(
      plan.edges.any(
        (item) => item.edge.startNodeId == 30 && item.edge.endNodeId != 31,
      ),
      isFalse,
    );
  });

  test('all station IDs are discovered without A1-A3/B1-B3 hard-coding', () {
    final nodes = [
      _node(1, 'A7_approach', FieldNodeRole.pickupApproach, stationId: 'a7'),
      _node(2, 'A7', FieldNodeRole.pickupDock, stationId: 'A7'),
      _node(3, 'B12_approach', FieldNodeRole.dropoffApproach, stationId: 'B12'),
      _node(4, 'B12', FieldNodeRole.dropoffDock, stationId: 'b12'),
      ..._gates(),
    ];

    final plan =
        CompetitionEdgePlan.build(nodes: nodes, existingEdges: const []);

    expect(plan.issues, isEmpty);
    expect(_findEdge(plan, 1, 2).movementDirection,
        FieldMovementDirection.reverse);
    expect(_findEdge(plan, 2, 1).movementDirection,
        FieldMovementDirection.forward);
    expect(_findEdge(plan, 3, 4).movementDirection,
        FieldMovementDirection.reverse);
    expect(_findEdge(plan, 4, 3).movementDirection,
        FieldMovementDirection.forward);
  });

  test('gate edges are two directed crossings with exact events', () {
    final plan = CompetitionEdgePlan.build(
      nodes: _gates(),
      existingEdges: const [],
    );

    expect(plan.issues, isEmpty);
    expect(plan.edges, hasLength(2));
    final outbound = _findEdge(plan, 900, 901);
    final returning = _findEdge(plan, 901, 900);
    expect(outbound.bidirectional, isFalse);
    expect(outbound.gateEvent, 'q5_outbound');
    expect(returning.bidirectional, isFalse);
    expect(returning.gateEvent, 'q6_return');
  });

  test('second auto-connect run coalesces exact existing edges', () {
    final nodes = [
      _node(1, 'A1_approach', FieldNodeRole.pickupApproach, stationId: 'A1'),
      _node(2, 'A1', FieldNodeRole.pickupDock, stationId: 'A1'),
      ..._gates(),
    ];
    final first =
        CompetitionEdgePlan.build(nodes: nodes, existingEdges: const []);
    final existing = first.edges.map((item) => item.edge).toList();

    final second =
        CompetitionEdgePlan.build(nodes: nodes, existingEdges: existing);

    expect(second.issues, isEmpty);
    expect(second.edges, isEmpty);
    expect(second.existingCount, existing.length);
  });

  test('delete with connected edges then recreate produces no stale node IDs',
      () {
    final originalNodes = [
      _node(1, 'A1_approach', FieldNodeRole.pickupApproach, stationId: 'A1'),
      _node(2, 'A1', FieldNodeRole.pickupDock, stationId: 'A1'),
      ..._gates(),
    ];
    final first = CompetitionEdgePlan.build(
      nodes: originalNodes,
      existingEdges: const [],
    );
    final afterDelete = first.edges
        .map((item) => item.edge)
        .where((edge) => edge.startNodeId != 2 && edge.endNodeId != 2)
        .toList();
    final recreatedNodes = [
      originalNodes.first,
      _node(20, 'A1', FieldNodeRole.pickupDock, stationId: 'A1'),
      ..._gates(),
    ];

    final recreated = CompetitionEdgePlan.build(
      nodes: recreatedNodes,
      existingEdges: afterDelete,
    );

    expect(recreated.issues, isEmpty);
    expect(recreated.edges.every((item) {
      final edge = item.edge;
      return edge.startNodeId != 2 && edge.endNodeId != 2;
    }), isTrue);
    expect(_findEdge(recreated, 1, 20).movementDirection,
        FieldMovementDirection.reverse);
    expect(_findEdge(recreated, 20, 1).movementDirection,
        FieldMovementDirection.forward);
  });

  test(
      'transit topology is not guessed and existing manual edges are preserved',
      () {
    final d1 = _node(101, 'D1', FieldNodeRole.transit, stationId: 'D1');
    final d2 = _node(102, 'D2', FieldNodeRole.transit, stationId: 'D2');
    final d3 = _node(103, 'D3', FieldNodeRole.transit, stationId: 'D3');
    final manual = _edge(500, d1.nodeId, d2.nodeId);
    final existing = [manual];

    final plan = CompetitionEdgePlan.build(
      nodes: [d1, d2, d3, ..._gates()],
      existingEdges: existing,
    );

    expect(plan.issues, isEmpty);
    expect(existing, same(existing));
    expect(existing.single, same(manual));
    expect(
      plan.edges.any(
        (item) =>
            const {101, 102, 103}.contains(item.edge.startNodeId) ||
            const {101, 102, 103}.contains(item.edge.endNodeId),
      ),
      isFalse,
    );
  });

  test('legacy bidirectional station edge is reported as a conflict', () {
    final nodes = [
      _node(1, 'A1_approach', FieldNodeRole.pickupApproach, stationId: 'A1'),
      _node(2, 'A1', FieldNodeRole.pickupDock, stationId: 'A1'),
      ..._gates(),
    ];

    final plan = CompetitionEdgePlan.build(
      nodes: nodes,
      existingEdges: [_edge(100, 1, 2)],
    );

    expect(plan.issues, isNotEmpty);
    expect(plan.edges.where((item) => {1, 2}.contains(item.edge.startNodeId)),
        isEmpty);
  });
}
