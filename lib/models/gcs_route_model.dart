import 'package:flutter/material.dart';

import 'gcs_node_model.dart';

/// Yerel kayıtlı rota draft’ı (H.2; ROS `/routes/*` sonra).
class SavedRouteDraft {
  final String id;
  final String name;
  final List<String> nodeIds;
  final List<String> nodeNames;
  final DateTime createdAt;

  const SavedRouteDraft({
    required this.id,
    required this.name,
    required this.nodeIds,
    required this.nodeNames,
    required this.createdAt,
  });

  String get summary => nodeNames.join(' → ');
}

/// H.1/H.2 — sıralı düğüm seçimi + yerel rota draft’ları.
/// Düğüm kaynağı: `GcsNodeModel` (Senaryo ile aynı havuz).
class GcsRouteModel extends ChangeNotifier {
  List<String> _selectionIds = const [];
  List<SavedRouteDraft> _saved = const [];
  int _seq = 0;

  List<String> get selectionIds => _selectionIds;
  List<SavedRouteDraft> get savedRoutes => _saved;

  bool get hasSelection => _selectionIds.isNotEmpty;

  List<TaughtFieldNode> selectedNodes(GcsNodeModel nodes) {
    final out = <TaughtFieldNode>[];
    for (final id in _selectionIds) {
      final n = nodes.byId(id);
      if (n != null) out.add(n);
    }
    return out;
  }

  void appendNode(String nodeId) {
    _selectionIds = List.unmodifiable([..._selectionIds, nodeId]);
    notifyListeners();
  }

  void undoLast() {
    if (_selectionIds.isEmpty) return;
    _selectionIds = List.unmodifiable(
      _selectionIds.sublist(0, _selectionIds.length - 1),
    );
    notifyListeners();
  }

  void clearSelection() {
    if (_selectionIds.isEmpty) return;
    _selectionIds = const [];
    notifyListeners();
  }

  /// Yerel kaydet. Başarıda draft; ad boşsa null.
  SavedRouteDraft? saveLocalDraft({
    required String name,
    required GcsNodeModel nodes,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _selectionIds.isEmpty) return null;
    final selected = selectedNodes(nodes);
    if (selected.isEmpty) return null;
    final draft = SavedRouteDraft(
      id: 'route_${++_seq}',
      name: trimmed,
      nodeIds: List.unmodifiable(selected.map((n) => n.id)),
      nodeNames: List.unmodifiable(selected.map((n) => n.name)),
      createdAt: DateTime.now(),
    );
    _saved = List.unmodifiable([draft, ..._saved]);
    notifyListeners();
    return draft;
  }

  bool removeSaved(String id) {
    final next = _saved.where((r) => r.id != id).toList(growable: false);
    if (next.length == _saved.length) return false;
    _saved = List.unmodifiable(next);
    notifyListeners();
    return true;
  }

  void loadSelection(SavedRouteDraft draft) {
    _selectionIds = List.unmodifiable(draft.nodeIds);
    notifyListeners();
  }
}
