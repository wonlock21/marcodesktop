import 'package:flutter/material.dart';

import '../services/ros_mapping_contract.dart';
import 'field_graph_models.dart';

/// Öğretilmiş düğüm (yerel draft; ROS `/stations/*` sonra).
class TaughtFieldNode {
  final String id;
  final String name;
  final FieldNodeType type;
  final double pixelX;
  final double pixelY;
  final double screenYaw;
  final String fieldName;

  const TaughtFieldNode({
    required this.id,
    required this.name,
    required this.type,
    required this.pixelX,
    required this.pixelY,
    required this.screenYaw,
    required this.fieldName,
  });

  Color get markerColor => type.markerColor;

  TaughtFieldNode copyWith({
    String? name,
    FieldNodeType? type,
    double? pixelX,
    double? pixelY,
    double? screenYaw,
    String? fieldName,
  }) {
    return TaughtFieldNode(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      pixelX: pixelX ?? this.pixelX,
      pixelY: pixelY ?? this.pixelY,
      screenYaw: screenYaw ?? this.screenYaw,
      fieldName: fieldName ?? this.fieldName,
    );
  }
}

extension FieldNodeTypeColor on FieldNodeType {
  Color get markerColor => switch (this) {
        FieldNodeType.alma => const Color(0xFF42A5F5),
        FieldNodeType.birakma => const Color(0xFFEF5350),
        FieldNodeType.baslangic => const Color(0xFF66BB6A),
        FieldNodeType.sarj => const Color(0xFFFFA726),
        FieldNodeType.kapi => const Color(0xFFAB47BC),
        FieldNodeType.qr => const Color(0xFF26C6DA),
      };
}

/// Düğüm adı kuralları (saha adı ile aynı karakter seti).
abstract final class NodeNameRules {
  static final RegExp pattern = RosFieldNameRules.pattern;

  static bool isValid(String value) {
    final v = value.trim();
    return v.isNotEmpty && pattern.hasMatch(v);
  }

  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Düğüm adı boş olamaz';
    }
    if (!pattern.hasMatch(value.trim())) {
      return 'Yalnız harf, rakam, _ ve - kullanılabilir (boşluk yok)';
    }
    return null;
  }
}

/// F.1/F.2 — öğretilmiş düğüm havuzu (yerel).
class GcsNodeModel extends ChangeNotifier {
  List<TaughtFieldNode> _nodes = const [];
  int _seq = 0;

  List<TaughtFieldNode> get nodes => _nodes;

  /// Canonical field graph projection used by the legacy scenario widgets.
  /// Runtime CRUD never writes this local model directly.
  void replaceFromFieldGraph({
    required List<FieldNode> graphNodes,
    required String fieldName,
    required MapPreviewMetadata? metadata,
  }) {
    final projected = <TaughtFieldNode>[];
    for (final node in graphNodes) {
      final type = switch (node.role) {
        FieldNodeRole.pickupApproach ||
        FieldNodeRole.pickupDock =>
          FieldNodeType.alma,
        FieldNodeRole.dropoffApproach ||
        FieldNodeRole.dropoffDock =>
          FieldNodeType.birakma,
        FieldNodeRole.wait || FieldNodeRole.transit => FieldNodeType.baslangic,
        FieldNodeRole.gateQ5 => FieldNodeType.kapi,
        FieldNodeRole.qrTrigger => FieldNodeType.qr,
      };
      final pixel = metadata?.mapToPixel(node.pose.x, node.pose.y);
      projected.add(TaughtFieldNode(
        id: node.nodeId.toString(),
        name: node.name,
        type: type,
        pixelX: pixel?.x ?? 0,
        pixelY: pixel?.y ?? 0,
        screenYaw: node.pose.theta,
        fieldName: fieldName,
      ));
    }
    _nodes = List.unmodifiable(projected);
    notifyListeners();
  }

  /// Senaryo A→B çiftleri için seçilebilir (alma / bırakma).
  List<TaughtFieldNode> get routeEligibleNodes => _nodes
      .where(
        (n) => n.type == FieldNodeType.alma || n.type == FieldNodeType.birakma,
      )
      .toList(growable: false);

  bool get hasRouteEligibleNodes => routeEligibleNodes.isNotEmpty;

  TaughtFieldNode? byId(String id) {
    for (final n in _nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  bool hasName(String name, {String? exceptId}) {
    final key = name.trim().toLowerCase();
    return _nodes.any(
      (n) => n.id != exceptId && n.name.toLowerCase() == key,
    );
  }

  String? validateName(String? value, {String? exceptId}) {
    final format = NodeNameRules.validate(value);
    if (format != null) return format;
    if (hasName(value!.trim(), exceptId: exceptId)) {
      return 'Bu ad zaten kullanılıyor';
    }
    return null;
  }

  /// Geri uyumluluk: yeni ad için.
  String? validateNewName(String? value) => validateName(value);

  String _nextId() => 'node_${++_seq}';

  /// Robot veya dokunma konumuna düğüm ekler. Başarıda eklenen düğüm.
  TaughtFieldNode? addNode({
    required String name,
    required FieldNodeType type,
    required double pixelX,
    required double pixelY,
    required double screenYaw,
    required String fieldName,
  }) {
    final trimmed = name.trim();
    if (validateName(trimmed) != null) return null;
    final node = TaughtFieldNode(
      id: _nextId(),
      name: trimmed,
      type: type,
      pixelX: pixelX,
      pixelY: pixelY,
      screenYaw: screenYaw,
      fieldName: fieldName.trim(),
    );
    _nodes = List.unmodifiable([..._nodes, node]);
    notifyListeners();
    return node;
  }

  /// Robot konumuna düğüm ekler. Başarıda `true`.
  bool addAtRobot({
    required String name,
    required FieldNodeType type,
    required double pixelX,
    required double pixelY,
    required double screenYaw,
    required String fieldName,
  }) =>
      addNode(
        name: name,
        type: type,
        pixelX: pixelX,
        pixelY: pixelY,
        screenYaw: screenYaw,
        fieldName: fieldName,
      ) !=
      null;

  /// G.1 — haritaya dokunulan piksele düğüm (yaw varsayılan 0).
  TaughtFieldNode? addAtPixel({
    required String name,
    required FieldNodeType type,
    required double pixelX,
    required double pixelY,
    required String fieldName,
    double screenYaw = 0,
  }) =>
      addNode(
        name: name,
        type: type,
        pixelX: pixelX,
        pixelY: pixelY,
        screenYaw: screenYaw,
        fieldName: fieldName,
      );

  /// Ad / tür düzenle.
  bool updateMeta({
    required String id,
    required String name,
    required FieldNodeType type,
  }) {
    final i = _nodes.indexWhere((n) => n.id == id);
    if (i < 0) return false;
    final trimmed = name.trim();
    if (validateName(trimmed, exceptId: id) != null) return false;
    final next = [..._nodes];
    next[i] = next[i].copyWith(name: trimmed, type: type);
    _nodes = List.unmodifiable(next);
    notifyListeners();
    return true;
  }

  /// Konumu mevcut robot pikseline taşı.
  bool moveToRobot({
    required String id,
    required double pixelX,
    required double pixelY,
    required double screenYaw,
  }) {
    final i = _nodes.indexWhere((n) => n.id == id);
    if (i < 0) return false;
    final next = [..._nodes];
    next[i] = next[i].copyWith(
      pixelX: pixelX,
      pixelY: pixelY,
      screenYaw: screenYaw,
    );
    _nodes = List.unmodifiable(next);
    notifyListeners();
    return true;
  }

  bool remove(String id) {
    final next = _nodes.where((n) => n.id != id).toList(growable: false);
    if (next.length == _nodes.length) return false;
    _nodes = List.unmodifiable(next);
    notifyListeners();
    return true;
  }

  void clear() {
    if (_nodes.isEmpty) return;
    _nodes = const [];
    notifyListeners();
  }
}
