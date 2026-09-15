import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/field_graph_models.dart';
import 'models/gcs_field_graph_model.dart';
import 'models/gcs_mapping_model.dart';
import 'route_edit_page.dart' show showFieldEdgeEditorDialog;
import 'services/angles.dart';
import 'services/ros_mapping_contract.dart';
import 'widgets/map_preview_stage.dart';

const _bg = Color(0xFF121212);
const _panelBg = Color(0xFF1A1A1A);
const _borderC = Color(0xFF333333);
const _muted = Color(0xFF9E9E9E);
const _bright = Color(0xFFE0E0E0);
const _warning = Color(0xFFFFA726);
const _accent = Color(0xFF42A5F5);
const _success = Color(0xFF43A047);
const _danger = Color(0xFFE53935);

enum _PanelSection { nodes, edges, selected }

enum NodeTeachInitialSection { nodes, edges }

extension on FieldNodeRole {
  String get operatorLabel => switch (this) {
        FieldNodeRole.wait => 'Bekleme Noktası',
        FieldNodeRole.pickupApproach => 'Yük Alma Alanına Yaklaşma',
        FieldNodeRole.pickupDock => 'Yük Alma Noktası',
        FieldNodeRole.dropoffApproach => 'Yük Bırakma Alanına Yaklaşma',
        FieldNodeRole.dropoffDock => 'Yük Bırakma Noktası',
        FieldNodeRole.gateQ5 => 'Gidiş Kapı İzin Noktası (Q5)',
        FieldNodeRole.gateQ6 => 'Dönüş Kapı İzin Noktası (Q6)',
        FieldNodeRole.qrTrigger => 'QR Okuma / Tetikleme Noktası',
        FieldNodeRole.transit => 'Düğüm Noktası',
      };
}

class NodeTeachPage extends StatefulWidget {
  const NodeTeachPage({
    super.key,
    this.initialSection = NodeTeachInitialSection.nodes,
  });

  final NodeTeachInitialSection initialSection;

  @override
  State<NodeTeachPage> createState() => _NodeTeachPageState();
}

class _NodeTeachPageState extends State<NodeTeachPage> {
  final TextEditingController _searchController = TextEditingController();
  late _PanelSection _section;
  FieldNodeRole? _roleFilter;
  String? _stationFilter;
  int? _selectedNodeId;
  int? _selectedEdgeId;
  bool _mapPickMode = false;
  bool _fieldSyncScheduled = false;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection == NodeTeachInitialSection.edges
        ? _PanelSection.edges
        : _PanelSection.nodes;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final graph = context.read<GcsFieldGraphModel>();
      if (!graph.connected || !graph.hasSelectedField) return;
      unawaited(
        graph.synchronize(preferredField: graph.selectedFieldName),
      );
    });
  }

  String? _preferredField(
    GcsFieldGraphModel graph,
    GcsMappingModel mapping,
  ) {
    final selected = graph.selectedFieldName?.trim();
    if (selected?.isNotEmpty == true) return selected;
    final localized = mapping.activeLocalizedField?.trim();
    if (localized?.isNotEmpty == true) return localized;
    final pending = mapping.pendingLocalizedField?.trim();
    if (pending?.isNotEmpty == true) return pending;
    final mappingField = mapping.fieldName.trim();
    return mappingField.isEmpty ? null : mappingField;
  }

  void _ensureFieldSelection(
    GcsFieldGraphModel graph,
    GcsMappingModel mapping,
  ) {
    if (_fieldSyncScheduled || !graph.connected || graph.hasSelectedField) {
      return;
    }
    final preferred = _preferredField(graph, mapping);
    if (preferred == null) return;
    _fieldSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (mounted) await graph.synchronize(preferredField: preferred);
      } finally {
        _fieldSyncScheduled = false;
      }
    });
  }

  Future<void> _selectField(String? fieldName) async {
    if (fieldName == null || fieldName.trim().isEmpty) return;
    setState(() {
      _selectedNodeId = null;
      _selectedEdgeId = null;
      _mapPickMode = false;
      _section = _PanelSection.nodes;
    });
    await context.read<GcsFieldGraphModel>().selectField(fieldName);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  String _errorText(Object error) =>
      error.toString().replaceFirst('Bad state: ', '').trim();

  bool _robotPoseContext(GcsMappingModel mapping, GcsFieldGraphModel graph) {
    if (!mapping.isConnected) return false;
    if (mapping.localizationReady &&
        mapping.activeLocalizedField == graph.selectedFieldName) {
      return true;
    }
    return mapping.liveMappingStatus == MappingStatus.mapping &&
        mapping.fieldName == graph.selectedFieldName;
  }

  bool _mapPickContext(GcsMappingModel mapping, GcsFieldGraphModel graph) =>
      _robotPoseContext(mapping, graph) &&
      mapping.hasPreviewPng &&
      mapping.previewMetadata != null;

  Future<void> _refresh() async {
    final graph = context.read<GcsFieldGraphModel>();
    final field = graph.selectedFieldName;
    if (!graph.connected || field == null || graph.graphLoading) return;
    await graph.synchronize(preferredField: field);
  }

  Future<void> _chooseAddMethod() async {
    final graph = context.read<GcsFieldGraphModel>();
    final mapping = context.read<GcsMappingModel>();
    if (!graph.canEdit) {
      _toast(_editBlockReason(graph));
      return;
    }
    final robotReady = _robotPoseContext(mapping, graph);
    final mapReady = _mapPickContext(mapping, graph);
    final method = await showDialog<_AddMethod>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Düğüm ekleme yöntemi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: robotReady
                  ? () => Navigator.pop(dialogContext, _AddMethod.robot)
                  : null,
              icon: const Icon(Icons.my_location),
              label: const Text('Robot Konumundan Kaydet'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: mapReady
                  ? () => Navigator.pop(dialogContext, _AddMethod.map)
                  : null,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Haritadan Konum Seç'),
            ),
            if (!robotReady || !mapReady) ...[
              const SizedBox(height: 12),
              const Text(
                'Seçili saha için güncel mapping veya lokalizasyon önizlemesi bekleniyor.',
                style: TextStyle(color: _warning),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
        ],
      ),
    );
    if (!mounted || method == null) return;
    if (method == _AddMethod.robot) {
      await _createAtRobot();
    } else {
      _beginMapPick();
    }
  }

  void _beginMapPick() {
    final graph = context.read<GcsFieldGraphModel>();
    final mapping = context.read<GcsMappingModel>();
    if (!graph.canEdit) {
      _toast(_editBlockReason(graph));
      return;
    }
    if (!_mapPickContext(mapping, graph)) {
      _toast(
        'Seçili saha için güncel mapping veya lokalizasyon önizlemesi bekleniyor.',
      );
      return;
    }
    setState(() => _mapPickMode = true);
  }

  Future<void> _createAtRobot() async {
    final graph = context.read<GcsFieldGraphModel>();
    if (!graph.canEdit || graph.busy) return;
    final node = await showFieldNodeEditorDialog(
      context: context,
      currentPose: true,
      existingNodeIds: graph.nodes.map((node) => node.nodeId).toSet(),
    );
    if (node == null || !mounted || !graph.canEdit) return;
    if (graph.nodeById(node.nodeId) != null) {
      _toast('Düğüm kaydedilemedi: Node ID zaten kullanılıyor');
      return;
    }
    try {
      final result = await graph.saveNode(node, currentPose: true);
      if (!mounted) return;
      setState(() {
        _selectedNodeId = result.savedNode?.nodeId ?? node.nodeId;
        _selectedEdgeId = null;
        _section = _PanelSection.selected;
      });
      _toast(result.message);
    } catch (error) {
      _toast('Düğüm kaydedilemedi: ${_errorText(error)}');
    }
  }

  Future<void> _createAtPixel(double pixelX, double pixelY) async {
    if (!_mapPickMode) return;
    setState(() => _mapPickMode = false);
    final graph = context.read<GcsFieldGraphModel>();
    final mapping = context.read<GcsMappingModel>();
    if (!graph.canEdit || !_mapPickContext(mapping, graph) || graph.busy) {
      return;
    }
    try {
      final converted = await graph.pixelToMap(
        pixelX: pixelX,
        pixelY: pixelY,
        screenYaw: 0,
      );
      if (!converted.insideMap) {
        _toast('Seçilen nokta harita sınırlarının dışında');
        return;
      }
      if (!mounted || !graph.canEdit) return;
      final node = await showFieldNodeEditorDialog(
        context: context,
        initialPose: converted.pose,
        existingNodeIds: graph.nodes.map((node) => node.nodeId).toSet(),
      );
      if (node == null || !mounted || !graph.canEdit) return;
      if (graph.nodeById(node.nodeId) != null) {
        _toast('Düğüm kaydedilemedi: Node ID zaten kullanılıyor');
        return;
      }
      final result = await graph.saveNode(node, currentPose: false);
      if (!mounted) return;
      setState(() {
        _selectedNodeId = result.savedNode?.nodeId ?? node.nodeId;
        _selectedEdgeId = null;
        _section = _PanelSection.selected;
      });
      _toast(result.message);
    } catch (error) {
      _toast('Düğüm kaydedilemedi: ${_errorText(error)}');
    }
  }

  Future<void> _editNode(FieldNode node) async {
    final graph = context.read<GcsFieldGraphModel>();
    if (!graph.canEdit || graph.busy) return;
    final edited = await showFieldNodeEditorDialog(
      context: context,
      existing: node,
      existingNodeIds: graph.nodes.map((node) => node.nodeId).toSet(),
    );
    if (edited == null || !mounted || !graph.canEdit) return;
    try {
      final result = await graph.saveNode(edited, currentPose: false);
      if (mounted) _toast(result.message);
    } catch (error) {
      _toast('Düğüm güncellenemedi: ${_errorText(error)}');
    }
  }

  Future<void> _moveNodeToRobot(FieldNode node) async {
    final graph = context.read<GcsFieldGraphModel>();
    final mapping = context.read<GcsMappingModel>();
    if (!graph.canEdit || graph.busy || !_robotPoseContext(mapping, graph)) {
      return;
    }
    try {
      final result = await graph.saveNode(node, currentPose: true);
      if (mounted) _toast(result.message);
    } catch (error) {
      _toast('Düğüm robot konumuna taşınamadı: ${_errorText(error)}');
    }
  }

  Future<void> _deleteNode(FieldNode node) async {
    final graph = context.read<GcsFieldGraphModel>();
    if (!graph.canEdit || graph.busy) return;
    final connected = graph.connectedEdges(node.nodeId);
    var deleteEdges = false;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Düğümü sil'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${node.name} düğümünü silmek istediğinize emin misiniz?',
                  ),
                  if (connected.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('${connected.length} bağlı bağlantı bulundu.'),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Bağlı bağlantıları da sil'),
                      value: deleteEdges,
                      onChanged: (value) => setDialogState(
                        () => deleteEdges = value == true,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: connected.isEmpty || deleteEdges
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  child: const Text('Düğümü Sil'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!confirmed || !mounted || !graph.canEdit) return;
    try {
      final result = await graph.deleteNode(
        node.nodeId,
        deleteConnectedEdges: deleteEdges,
      );
      if (!mounted) return;
      setState(() {
        _selectedNodeId = null;
        _section = _PanelSection.nodes;
      });
      _toast(result.message);
    } catch (error) {
      _toast('Düğüm silinemedi: ${_errorText(error)}');
    }
  }

  Future<void> _editEdge({FieldEdge? edge, int? startNodeId}) async {
    final graph = context.read<GcsFieldGraphModel>();
    if (!graph.canEdit || graph.busy || graph.nodes.length < 2) return;
    final edited = await showFieldEdgeEditorDialog(
      context: context,
      nodes: graph.nodes,
      existing: edge,
      initialStartNodeId: startNodeId,
    );
    if (edited == null || !mounted || !graph.canEdit) return;
    try {
      final result = await graph.saveEdge(edited);
      if (!mounted) return;
      setState(() {
        _selectedEdgeId = result.savedEdge?.edgeId ?? edited.edgeId;
        _selectedNodeId = null;
        _section = _PanelSection.selected;
      });
      _toast(result.message);
    } catch (error) {
      _toast('Bağlantı kaydedilemedi: ${_errorText(error)}');
    }
  }

  Future<void> _deleteEdge(FieldEdge edge) async {
    final graph = context.read<GcsFieldGraphModel>();
    if (!graph.canEdit || graph.busy) return;
    final start = graph.nodeById(edge.startNodeId)?.name ?? edge.startNodeId;
    final end = graph.nodeById(edge.endNodeId)?.name ?? edge.endNodeId;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Bağlantıyı sil'),
            content: Text('$start → $end bağlantısı silinecek.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Bağlantıyı Sil'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted || !graph.canEdit) return;
    try {
      final result = await graph.deleteEdge(edge.edgeId);
      if (!mounted) return;
      setState(() {
        _selectedEdgeId = null;
        _section = _PanelSection.edges;
      });
      _toast(result.message);
    } catch (error) {
      _toast('Bağlantı silinemedi: ${_errorText(error)}');
    }
  }

  Future<void> _validateGraph() async {
    final graph = context.read<GcsFieldGraphModel>();
    if (!graph.canEdit || graph.busy) return;
    try {
      final result = await graph.validateSelected();
      if (!mounted) return;
      _toast(
        result.success && result.status.state == FieldPackageState.valid
            ? 'Saha doğrulandı.'
            : '${result.status.errors.length} hata, '
                '${result.status.warnings.length} uyarı bulundu.',
      );
    } catch (error) {
      _toast('Doğrulama başarısız: ${_errorText(error)}');
    }
  }

  Future<void> _showValidationMessages() async {
    final status = context.read<GcsFieldGraphModel>().packageStatus;
    if (status == null) return;
    final errors = status.errors;
    final warnings = status.warnings;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              errors.isNotEmpty ? Icons.error_outline : Icons.warning_amber,
              color: errors.isNotEmpty ? _danger : _warning,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Doğrulama Sonuçları · ${errors.length} hata, '
                '${warnings.length} uyarı',
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 700,
          child: errors.isEmpty && warnings.isEmpty
              ? const Text('Doğrulama hatası veya uyarısı bulunmuyor.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (var index = 0; index < errors.length; index++)
                      ListTile(
                        dense: true,
                        leading:
                            const Icon(Icons.error_outline, color: _danger),
                        title: SelectableText(
                          '${index + 1}. ${_validationMessageTr(errors[index])}',
                        ),
                      ),
                    for (var index = 0; index < warnings.length; index++)
                      ListTile(
                        dense: true,
                        leading:
                            const Icon(Icons.warning_amber, color: _warning),
                        title: SelectableText(
                          '${index + 1}. ${_validationMessageTr(warnings[index])}',
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Future<void> _autoConnectCompetitionGraph() async {
    final graph = context.read<GcsFieldGraphModel>();
    if (!graph.canEdit || graph.busy) return;

    final plan = _CompetitionEdgePlan.build(
      nodes: graph.nodes,
      existingEdges: graph.edges,
    );
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.auto_fix_high_outlined, color: _accent),
                SizedBox(width: 10),
                Text('Yarışma bağlantılarını oluştur'),
              ],
            ),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aşağıdaki bağlantılar Station ID ve düğüm rollerine '
                      'göre oluşturulacak. Mevcut bağlantılar korunur.',
                    ),
                    const SizedBox(height: 12),
                    if (plan.issues.isNotEmpty) ...[
                      for (final issue in plan.issues)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.error_outline,
                            color: _danger,
                          ),
                          title: Text(issue),
                        ),
                    ] else ...[
                      Text(
                        '${plan.edges.length} yeni bağlantı oluşturulacak, '
                        '${plan.existingCount} bağlantı zaten mevcut.',
                      ),
                      const SizedBox(height: 8),
                      for (final item in plan.edges)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            item.edge.bidirectional
                                ? Icons.swap_horiz
                                : Icons.arrow_forward,
                            color: item.edge.gateEvent.isEmpty
                                ? _accent
                                : _warning,
                          ),
                          title: Text(item.label),
                          subtitle: item.edge.gateEvent.isEmpty
                              ? null
                              : Text(item.edge.gateEvent),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: plan.issues.isEmpty && plan.edges.isNotEmpty
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: const Text('Bağlantıları Oluştur'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    var savedCount = 0;
    try {
      for (final item in plan.edges) {
        if (!mounted || !graph.canEdit) {
          throw StateError('Saha düzenleme durumu işlem sırasında değişti');
        }
        await graph.saveEdge(item.edge);
        savedCount++;
      }
    } catch (error) {
      if (mounted) {
        _toast(
          'Otomatik bağlantı tamamlanamadı '
          '($savedCount/${plan.edges.length} kaydedildi): ${_errorText(error)}',
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _selectedNodeId = null;
      _selectedEdgeId = null;
      _section = _PanelSection.edges;
    });
    try {
      final validation = await graph.validateSelected();
      if (!mounted) return;
      final status = validation.status;
      if (validation.success && status.state == FieldPackageState.valid) {
        _toast('$savedCount bağlantı oluşturuldu; saha doğrulandı.');
      } else {
        _toast(
          '$savedCount bağlantı oluşturuldu; '
          '${status.errors.length} hata, ${status.warnings.length} uyarı kaldı.',
        );
      }
    } catch (error) {
      if (mounted) {
        _toast(
          '$savedCount bağlantı oluşturuldu; doğrulama çağrısı başarısız: '
          '${_errorText(error)}',
        );
      }
    }
  }

  Future<void> _activateGraph() async {
    final graph = context.read<GcsFieldGraphModel>();
    if (!graph.canActivate || graph.busy) return;
    try {
      final result = await graph.activateSelected();
      if (mounted) _toast(result.message);
    } catch (error) {
      _toast('Saha aktifleştirilemedi: ${_errorText(error)}');
    }
  }

  Future<void> _deactivateGraph() async {
    final graph = context.read<GcsFieldGraphModel>();
    if (!graph.canDeactivate || graph.busy) {
      _toast('Saha şu anda düzenlemeye açılamıyor.');
      return;
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Sahayı düzenlemeye aç'),
            content: const Text(
              'Aktif rota çalışma sistemi durdurulacak ve saha salt okunur '
              'durumdan çıkarılacak. Harita, düğüm ve bağlantılar silinmez. '
              'Değişikliklerden sonra saha yeniden doğrulanıp '
              'aktifleştirilmelidir.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Düzenlemeye Aç'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    try {
      final result = await graph.deactivateSelected();
      if (mounted) _toast(result.message);
    } catch (error) {
      if (mounted) {
        _toast('Saha düzenlemeye açılamadı: ${_errorText(error)}');
      }
    }
  }

  void _selectNode(FieldNode node) {
    setState(() {
      _selectedNodeId = node.nodeId;
      _selectedEdgeId = null;
      _section = _PanelSection.selected;
    });
  }

  void _selectNodeByName(String name, List<FieldNode> nodes) {
    for (final node in nodes) {
      if (node.name == name) {
        _selectNode(node);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final graph = context.watch<GcsFieldGraphModel>();
    final mapping = context.watch<GcsMappingModel>();
    _ensureFieldSelection(graph, mapping);
    final metadata = mapping.previewMetadata;
    final selectedNode = _nodeById(graph.nodes, _selectedNodeId);
    final selectedEdge = _edgeById(graph.edges, _selectedEdgeId);
    final robotPoseReady = _robotPoseContext(mapping, graph);
    final mapPickReady = _mapPickContext(mapping, graph);
    final compactToolbar = MediaQuery.sizeOf(context).width < 1800;

    Widget toolbarAction({
      Key? key,
      required String label,
      required IconData icon,
      required VoidCallback? onPressed,
      Color? foregroundColor,
      Color? disabledForegroundColor,
    }) {
      if (compactToolbar) {
        return IconButton(
          key: key,
          tooltip: label,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            foregroundColor: foregroundColor,
            disabledForegroundColor: disabledForegroundColor,
          ),
          icon: Icon(icon),
        );
      }
      return TextButton.icon(
        key: key,
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: foregroundColor,
          disabledForegroundColor: disabledForegroundColor,
        ),
        icon: Icon(icon),
        label: Text(label),
      );
    }

    final markers = <MapPreviewNodeMarker>[];
    if (metadata != null) {
      for (final node in graph.nodes) {
        final pixel = metadata.mapToPixel(node.pose.x, node.pose.y);
        if (!pixel.insideMap) continue;
        markers.add(
          MapPreviewNodeMarker(
            label: node.name,
            pixelX: pixel.x,
            pixelY: pixel.y,
            color: node.nodeId == _selectedNodeId
                ? Colors.yellowAccent
                : _nodeColor(node.role),
          ),
        );
      }
    }
    final segments = <MapPreviewRouteSegment>[];
    if (metadata != null) {
      for (final edge in graph.edges) {
        final start = graph.nodeById(edge.startNodeId);
        final end = graph.nodeById(edge.endNodeId);
        if (start == null || end == null) continue;
        final a = metadata.mapToPixel(start.pose.x, start.pose.y);
        final b = metadata.mapToPixel(end.pose.x, end.pose.y);
        if (!a.insideMap || !b.insideMap) continue;
        segments.add(
          MapPreviewRouteSegment(
            start: Offset(a.x, a.y),
            end: Offset(b.x, b.y),
            bidirectional: edge.bidirectional,
            color: edge.edgeId == _selectedEdgeId
                ? Colors.yellowAccent
                : _edgeColor(edge),
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _panelBg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Düğümler'),
        actions: [
          toolbarAction(
            label: 'Doğrula',
            icon: Icons.fact_check_outlined,
            onPressed: graph.canEdit && !graph.busy
                ? () => unawaited(_validateGraph())
                : null,
          ),
          Builder(
            builder: (context) {
              final status = graph.packageStatus;
              final errorCount = status?.errors.length ?? 0;
              final warningCount = status?.warnings.length ?? 0;
              final hasMessages = errorCount + warningCount > 0;
              final color = status == null
                  ? null
                  : errorCount > 0
                      ? _danger
                      : warningCount > 0
                          ? _warning
                          : _success;
              return toolbarAction(
                key: const Key('validation-errors-button'),
                label: hasMessages ? 'Hatalar ($errorCount)' : 'Hatalar',
                icon: errorCount > 0
                    ? Icons.error_outline
                    : warningCount > 0
                        ? Icons.warning_amber
                        : Icons.check_circle_outline,
                onPressed: status == null
                    ? null
                    : () => unawaited(_showValidationMessages()),
                foregroundColor: color,
              );
            },
          ),
          toolbarAction(
            key: const Key('competition-auto-connect-button'),
            label: 'Otomatik Bağla',
            icon: Icons.auto_fix_high_outlined,
            onPressed: graph.canEdit && !graph.busy
                ? () => unawaited(_autoConnectCompetitionGraph())
                : null,
          ),
          if (graph.selectedFieldIsActive)
            toolbarAction(
              key: const Key('deactivate-field-button'),
              label: 'Sahayı Düzenlemeye Aç',
              icon: Icons.edit_outlined,
              foregroundColor: graph.canDeactivate ? _warning : _muted,
              disabledForegroundColor: _muted,
              onPressed: graph.canDeactivate && !graph.busy
                  ? () => unawaited(_deactivateGraph())
                  : null,
            ),
          toolbarAction(
            key: const Key('activate-field-button'),
            label: 'Aktifleştir',
            icon: Icons.check_circle_outline,
            foregroundColor: graph.canActivate ? _success : _muted,
            disabledForegroundColor: _muted,
            onPressed: graph.busy
                ? null
                : () {
                    if (graph.canActivate) {
                      unawaited(_activateGraph());
                    } else {
                      _toast(
                        'Saha aktifleştirilemiyor: '
                        '${_activationBlockReason(graph)}',
                      );
                    }
                  },
          ),
          if (graph.fields.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const Key('node-field-selector'),
                  value: graph.fields.any(
                    (field) => field.fieldName == graph.selectedFieldName,
                  )
                      ? graph.selectedFieldName
                      : null,
                  hint: const Text(
                    'Saha seç',
                    style: TextStyle(color: _bright),
                  ),
                  dropdownColor: _panelBg,
                  style: const TextStyle(color: _bright),
                  iconEnabledColor: _bright,
                  items: [
                    for (final field in graph.fields)
                      DropdownMenuItem(
                        value: field.fieldName,
                        child: Text(
                          compactToolbar
                              ? field.fieldName
                              : 'Saha: ${field.fieldName}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: graph.connected && !graph.busy
                      ? (value) => unawaited(_selectField(value))
                      : null,
                ),
              ),
            ),
          _PackageBadge(graph: graph),
          IconButton(
            tooltip: 'Grafiği yenile',
            onPressed: graph.connected && !graph.graphLoading
                ? () => unawaited(_refresh())
                : null,
            icon: graph.graphLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GraphStateBanner(
            graph: graph,
            mapping: mapping,
            mapPickMode: _mapPickMode,
            onCancelPick: () => setState(() => _mapPickMode = false),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: mapping.hasPreviewPng
                      ? MapPreviewStage(
                          pngBytes: mapping.previewPng!,
                          metadata: metadata,
                          robotPixel: mapping.visibleRobotPixel,
                          awaitingFresh: mapping.awaitingFreshPreview,
                          sourceLabel: mapping.previewSourceLabel,
                          nodeMarkers: markers,
                          routeSegments: segments,
                          onMapTap: _mapPickMode &&
                                  graph.canEdit &&
                                  mapPickReady &&
                                  !graph.busy
                              ? _createAtPixel
                              : null,
                          onNodeMarkerTap: (name) =>
                              _selectNodeByName(name, graph.nodes),
                        )
                      : _MapEmptyState(graph: graph, mapping: mapping),
                ),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width < 1000 ? 330 : 370,
                  child: _ProductionPanel(
                    graph: graph,
                    section: _section,
                    onSectionChanged: (value) =>
                        setState(() => _section = value),
                    searchController: _searchController,
                    roleFilter: _roleFilter,
                    stationFilter: _stationFilter,
                    onFilterChanged: (role, station) => setState(() {
                      _roleFilter = role;
                      _stationFilter = station;
                    }),
                    selectedNode: selectedNode,
                    selectedEdge: selectedEdge,
                    onSelectNode: _selectNode,
                    onSelectEdge: (edge) => setState(() {
                      _selectedEdgeId = edge.edgeId;
                      _selectedNodeId = null;
                      _section = _PanelSection.selected;
                    }),
                    onAddNode: _chooseAddMethod,
                    onAddNodeAtRobot: _createAtRobot,
                    onAddNodeFromMap: _beginMapPick,
                    onEditNode: _editNode,
                    onMoveNode: _moveNodeToRobot,
                    onDeleteNode: _deleteNode,
                    onAddEdge: ({int? startNodeId}) =>
                        _editEdge(startNodeId: startNodeId),
                    onEditEdge: (edge) => _editEdge(edge: edge),
                    onDeleteEdge: _deleteEdge,
                    robotPoseReady: robotPoseReady,
                    mapPickReady: mapPickReady,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _validationMessageTr(String message) {
  final trimmed = message.trim();
  final requiredStation = RegExp(
    r"^required station '([^']+)' is missing$",
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (requiredStation != null) {
    return "Zorunlu '${requiredStation.group(1)}' istasyonu eksik.";
  }
  final noEdges = RegExp(
    r"^node '([^']+)' has no edges$",
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (noEdges != null) {
    return "'${noEdges.group(1)}' düğümünün hiçbir bağlantısı yok.";
  }
  final noStation = RegExp(
    r"^node '([^']+)' has no station$",
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (noStation != null) {
    return "'${noStation.group(1)}' düğümünün Station ID alanı boş.";
  }
  const known = <String, String>{
    'route graph has no edges': 'Rota grafiğinde henüz bağlantı yok.',
    'exactly one outbound q5 gate node is required':
        'Tam olarak bir gidiş Q5 kapı düğümü gerekli.',
    'exactly one return q6 gate node is required':
        'Tam olarak bir dönüş Q6 kapı düğümü gerekli.',
    'directed q5->q6 crossing with gate_event=q5_outbound is required':
        'Q5 → Q6 yönünde q5_outbound kapı olaylı bağlantı gerekli.',
    'directed q6->q5 crossing with gate_event=q6_return is required':
        'Q6 → Q5 yönünde q6_return kapı olaylı bağlantı gerekli.',
  };
  return known[trimmed.toLowerCase()] ?? trimmed;
}

enum _AddMethod { robot, map }

class _PanelTabButton extends StatelessWidget {
  const _PanelTabButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Material(
            color: selected ? _accent.withValues(alpha: 0.22) : _panelBg,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: selected ? _accent : _borderC),
              borderRadius: BorderRadius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 17,
                      color: selected ? _accent : _bright,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? Colors.white : _bright,
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _ProductionPanel extends StatelessWidget {
  const _ProductionPanel({
    required this.graph,
    required this.section,
    required this.onSectionChanged,
    required this.searchController,
    required this.roleFilter,
    required this.stationFilter,
    required this.onFilterChanged,
    required this.selectedNode,
    required this.selectedEdge,
    required this.onSelectNode,
    required this.onSelectEdge,
    required this.onAddNode,
    required this.onAddNodeAtRobot,
    required this.onAddNodeFromMap,
    required this.onEditNode,
    required this.onMoveNode,
    required this.onDeleteNode,
    required this.onAddEdge,
    required this.onEditEdge,
    required this.onDeleteEdge,
    required this.robotPoseReady,
    required this.mapPickReady,
  });

  final GcsFieldGraphModel graph;
  final _PanelSection section;
  final ValueChanged<_PanelSection> onSectionChanged;
  final TextEditingController searchController;
  final FieldNodeRole? roleFilter;
  final String? stationFilter;
  final void Function(FieldNodeRole?, String?) onFilterChanged;
  final FieldNode? selectedNode;
  final FieldEdge? selectedEdge;
  final ValueChanged<FieldNode> onSelectNode;
  final ValueChanged<FieldEdge> onSelectEdge;
  final VoidCallback onAddNode;
  final VoidCallback onAddNodeAtRobot;
  final VoidCallback onAddNodeFromMap;
  final ValueChanged<FieldNode> onEditNode;
  final ValueChanged<FieldNode> onMoveNode;
  final ValueChanged<FieldNode> onDeleteNode;
  final void Function({int? startNodeId}) onAddEdge;
  final ValueChanged<FieldEdge> onEditEdge;
  final ValueChanged<FieldEdge> onDeleteEdge;
  final bool robotPoseReady;
  final bool mapPickReady;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: _panelBg,
          border: Border(left: BorderSide(color: _borderC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  _PanelTabButton(
                    key: const Key('nodes-tab'),
                    icon: Icons.place_outlined,
                    label: 'Düğümler',
                    selected: section == _PanelSection.nodes,
                    onTap: () => onSectionChanged(_PanelSection.nodes),
                  ),
                  _PanelTabButton(
                    key: const Key('edges-tab'),
                    icon: Icons.route_outlined,
                    label: 'Bağlantılar',
                    selected: section == _PanelSection.edges,
                    onTap: () => onSectionChanged(_PanelSection.edges),
                  ),
                  _PanelTabButton(
                    key: const Key('selected-tab'),
                    icon: Icons.info_outline,
                    label: 'Seçili',
                    selected: section == _PanelSection.selected,
                    onTap: () => onSectionChanged(_PanelSection.selected),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _borderC),
            Expanded(child: _content()),
          ],
        ),
      );

  Widget _content() => switch (section) {
        _PanelSection.nodes => _NodeSection(
            graph: graph,
            searchController: searchController,
            roleFilter: roleFilter,
            stationFilter: stationFilter,
            onFilterChanged: onFilterChanged,
            onSelect: onSelectNode,
            onAdd: onAddNode,
            onAddAtRobot: onAddNodeAtRobot,
            onAddFromMap: onAddNodeFromMap,
            robotPoseReady: robotPoseReady,
            mapPickReady: mapPickReady,
          ),
        _PanelSection.edges => _EdgeSection(
            graph: graph,
            onSelect: onSelectEdge,
            onAdd: () => onAddEdge(),
          ),
        _PanelSection.selected => _SelectedSection(
            graph: graph,
            node: selectedNode,
            edge: selectedEdge,
            onEditNode: onEditNode,
            onMoveNode: onMoveNode,
            onDeleteNode: onDeleteNode,
            onStartEdge: (node) => onAddEdge(startNodeId: node.nodeId),
            onEditEdge: onEditEdge,
            onDeleteEdge: onDeleteEdge,
            canMoveNode: robotPoseReady,
          ),
      };
}

class _NodeSection extends StatefulWidget {
  const _NodeSection({
    required this.graph,
    required this.searchController,
    required this.roleFilter,
    required this.stationFilter,
    required this.onFilterChanged,
    required this.onSelect,
    required this.onAdd,
    required this.onAddAtRobot,
    required this.onAddFromMap,
    required this.robotPoseReady,
    required this.mapPickReady,
  });

  final GcsFieldGraphModel graph;
  final TextEditingController searchController;
  final FieldNodeRole? roleFilter;
  final String? stationFilter;
  final void Function(FieldNodeRole?, String?) onFilterChanged;
  final ValueChanged<FieldNode> onSelect;
  final VoidCallback onAdd;
  final VoidCallback onAddAtRobot;
  final VoidCallback onAddFromMap;
  final bool robotPoseReady;
  final bool mapPickReady;

  @override
  State<_NodeSection> createState() => _NodeSectionState();
}

class _NodeSectionState extends State<_NodeSection> {
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant _NodeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController.removeListener(_refresh);
      widget.searchController.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final stations = widget.graph.nodes
        .map((node) => node.stationId.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final query = widget.searchController.text.trim().toLowerCase();
    final nodes = widget.graph.nodes.where((node) {
      final matchesText = query.isEmpty ||
          node.name.toLowerCase().contains(query) ||
          node.nodeId.toString().contains(query) ||
          node.stationId.toLowerCase().contains(query);
      return matchesText &&
          (widget.roleFilter == null || node.role == widget.roleFilter) &&
          (widget.stationFilter == null ||
              node.stationId == widget.stationFilter);
    }).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              TextField(
                controller: widget.searchController,
                style: const TextStyle(color: _bright),
                cursorColor: _accent,
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Düğüm ara',
                  labelStyle: TextStyle(color: _muted),
                  floatingLabelStyle: TextStyle(color: _accent),
                  prefixIconColor: _muted,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<FieldNodeRole?>(
                      initialValue: widget.roleFilter,
                      isExpanded: true,
                      dropdownColor: _panelBg,
                      iconEnabledColor: _bright,
                      style: const TextStyle(color: _bright),
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Rol',
                        labelStyle: TextStyle(color: _muted),
                        floatingLabelStyle: TextStyle(color: _accent),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Tümü')),
                        for (final role in FieldNodeRole.values.where(
                          (role) => role != FieldNodeRole.qrTrigger,
                        ))
                          DropdownMenuItem(
                            value: role,
                            child: Text(role.operatorLabel),
                          ),
                      ],
                      onChanged: (value) =>
                          widget.onFilterChanged(value, widget.stationFilter),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: stations.contains(widget.stationFilter)
                          ? widget.stationFilter
                          : null,
                      isExpanded: true,
                      dropdownColor: _panelBg,
                      iconEnabledColor: _bright,
                      style: const TextStyle(color: _bright),
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Station',
                        labelStyle: TextStyle(color: _muted),
                        floatingLabelStyle: TextStyle(color: _accent),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Tümü')),
                        for (final station in stations)
                          DropdownMenuItem(
                              value: station, child: Text(station)),
                      ],
                      onChanged: (value) =>
                          widget.onFilterChanged(widget.roleFilter, value),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Düğümler (${widget.graph.nodes.length})',
                  style: const TextStyle(
                    color: _bright,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              FilledButton.icon(
                key: const Key('production-add-node'),
                style: FilledButton.styleFrom(
                  disabledBackgroundColor: const Color(0xFF2A2A2A),
                  disabledForegroundColor: _muted,
                ),
                onPressed: widget.graph.selectedFieldIsActive ||
                        widget.graph.busy ||
                        !widget.graph.connected ||
                        !widget.graph.hasSelectedField
                    ? null
                    : widget.onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Düğüm Ekle'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Divider(height: 1, color: _borderC),
        Expanded(
          child: _NodeListBody(
            graph: widget.graph,
            nodes: nodes,
            onSelect: widget.onSelect,
            onAdd: widget.onAdd,
            onAddAtRobot: widget.onAddAtRobot,
            onAddFromMap: widget.onAddFromMap,
            robotPoseReady: widget.robotPoseReady,
            mapPickReady: widget.mapPickReady,
          ),
        ),
      ],
    );
  }
}

class _NodeListBody extends StatelessWidget {
  const _NodeListBody({
    required this.graph,
    required this.nodes,
    required this.onSelect,
    required this.onAdd,
    required this.onAddAtRobot,
    required this.onAddFromMap,
    required this.robotPoseReady,
    required this.mapPickReady,
  });

  final GcsFieldGraphModel graph;
  final List<FieldNode> nodes;
  final ValueChanged<FieldNode> onSelect;
  final VoidCallback onAdd;
  final VoidCallback onAddAtRobot;
  final VoidCallback onAddFromMap;
  final bool robotPoseReady;
  final bool mapPickReady;

  @override
  Widget build(BuildContext context) {
    if (!graph.connected) return const _PanelMessage('Robot bağlantısı yok.');
    if (!graph.hasSelectedField) {
      return const _PanelMessage('Önce bir saha seçin.');
    }
    if (graph.graphLoading) {
      return const _PanelMessage('Saha grafiği yükleniyor...', progress: true);
    }
    if (graph.graphError != null) return _PanelMessage(graph.graphError!);
    if (graph.nodes.isEmpty) {
      return _PanelMessage(
        'Bu sahada henüz düğüm bulunmuyor.',
        action: Column(
          children: [
            OutlinedButton.icon(
              onPressed: graph.canEdit && !graph.busy && robotPoseReady
                  ? onAddAtRobot
                  : null,
              icon: const Icon(Icons.my_location),
              label: const Text('Robot Konumundan Düğüm Ekle'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: graph.canEdit && !graph.busy && mapPickReady
                  ? onAddFromMap
                  : null,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Haritadan Düğüm Ekle'),
            ),
          ],
        ),
      );
    }
    if (nodes.isEmpty) return const _PanelMessage('Filtreye uyan düğüm yok.');
    return ListView.separated(
      itemCount: nodes.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: _borderC),
      itemBuilder: (context, index) {
        final node = nodes[index];
        return ListTile(
          dense: true,
          leading: Icon(Icons.location_on, color: _nodeColor(node.role)),
          title: Text(
            node.name.isEmpty ? node.nodeId.toString() : node.name,
            style: const TextStyle(color: _bright, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${node.role.operatorLabel}${node.stationId.isEmpty ? '' : ' · ${node.stationId}'}\n'
            'x: ${node.pose.x.toStringAsFixed(2)}  y: ${node.pose.y.toStringAsFixed(2)}',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          isThreeLine: true,
          onTap: () => onSelect(node),
        );
      },
    );
  }
}

class _EdgeSection extends StatelessWidget {
  const _EdgeSection({
    required this.graph,
    required this.onSelect,
    required this.onAdd,
  });

  final GcsFieldGraphModel graph;
  final ValueChanged<FieldEdge> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Bağlantılar (${graph.edges.length})',
                    style: const TextStyle(
                      color: _bright,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton.icon(
                  key: const Key('production-add-edge'),
                  onPressed:
                      graph.canEdit && graph.nodes.length >= 2 && !graph.busy
                          ? onAdd
                          : null,
                  icon: const Icon(Icons.add_road),
                  label: const Text('Bağlantı Ekle'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _borderC),
          Expanded(
            child: !graph.connected
                ? const _PanelMessage('Robot bağlantısı yok.')
                : !graph.hasSelectedField
                    ? const _PanelMessage('Önce bir saha seçin.')
                    : graph.graphLoading
                        ? const _PanelMessage(
                            'Saha grafiği yükleniyor...',
                            progress: true,
                          )
                        : graph.edges.isEmpty
                            ? _PanelMessage(
                                graph.nodes.length < 2
                                    ? 'Bağlantı için en az iki düğüm ekleyin.'
                                    : 'Bu sahada henüz bağlantı bulunmuyor.',
                              )
                            : ListView.separated(
                                itemCount: graph.edges.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  color: _borderC,
                                ),
                                itemBuilder: (context, index) {
                                  final edge = graph.edges[index];
                                  final start =
                                      graph.nodeById(edge.startNodeId)?.name ??
                                          edge.startNodeId.toString();
                                  final end =
                                      graph.nodeById(edge.endNodeId)?.name ??
                                          edge.endNodeId.toString();
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(
                                      Icons.route_outlined,
                                      color: _accent,
                                    ),
                                    title: Text(
                                      '$start ${edge.bidirectional ? '↔' : '→'} $end',
                                      style: const TextStyle(color: _bright),
                                    ),
                                    subtitle: Text(
                                      '${edge.maxSpeed.toStringAsFixed(2)} m/s · '
                                      '${edge.loadRule.wireName} · '
                                      '${edge.movementDirection.wireName}'
                                      '${edge.gateEvent.isEmpty ? '' : '\n${edge.gateEvent}'}',
                                      style: const TextStyle(color: _muted),
                                    ),
                                    onTap: () => onSelect(edge),
                                  );
                                },
                              ),
          ),
        ],
      );
}

class _SelectedSection extends StatelessWidget {
  const _SelectedSection({
    required this.graph,
    required this.node,
    required this.edge,
    required this.onEditNode,
    required this.onMoveNode,
    required this.onDeleteNode,
    required this.onStartEdge,
    required this.onEditEdge,
    required this.onDeleteEdge,
    required this.canMoveNode,
  });

  final GcsFieldGraphModel graph;
  final FieldNode? node;
  final FieldEdge? edge;
  final ValueChanged<FieldNode> onEditNode;
  final ValueChanged<FieldNode> onMoveNode;
  final ValueChanged<FieldNode> onDeleteNode;
  final ValueChanged<FieldNode> onStartEdge;
  final ValueChanged<FieldEdge> onEditEdge;
  final ValueChanged<FieldEdge> onDeleteEdge;
  final bool canMoveNode;

  @override
  Widget build(BuildContext context) {
    if (node == null && edge == null) {
      return const _PanelMessage(
        'Detaylarını görmek için haritadan veya listeden bir öğe seçin.',
      );
    }
    if (node != null) {
      final value = node!;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailTitle(icon: Icons.location_on, title: value.name),
            _detail('Node ID', value.nodeId.toString()),
            _detail('Rol', value.role.operatorLabel),
            _detail(
                'Station', value.stationId.isEmpty ? '--' : value.stationId),
            _detail('X / Y',
                '${value.pose.x.toStringAsFixed(3)} / ${value.pose.y.toStringAsFixed(3)}'),
            _detail('Yaw',
                '${radiansToDegrees(value.pose.theta).toStringAsFixed(1)}°'),
            _detail('Yük kuralı', value.loadRule.wireName),
            _detail('Yaklaşma', value.approachMode.wireName),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed:
                  graph.canEdit && !graph.busy ? () => onEditNode(value) : null,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Düzenle'),
            ),
            OutlinedButton.icon(
              onPressed: graph.canEdit && !graph.busy && canMoveNode
                  ? () => onMoveNode(value)
                  : null,
              icon: const Icon(Icons.my_location),
              label: const Text('Robot Konumuna Taşı'),
            ),
            OutlinedButton.icon(
              onPressed: graph.canEdit && !graph.busy && graph.nodes.length >= 2
                  ? () => onStartEdge(value)
                  : null,
              icon: const Icon(Icons.add_road),
              label: const Text('Buradan Bağlantı Başlat'),
            ),
            TextButton.icon(
              onPressed: graph.canEdit && !graph.busy
                  ? () => onDeleteNode(value)
                  : null,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Düğümü Sil'),
              style: TextButton.styleFrom(foregroundColor: _danger),
            ),
          ],
        ),
      );
    }

    final value = edge!;
    final start = graph.nodeById(value.startNodeId)?.name ?? value.startNodeId;
    final end = graph.nodeById(value.endNodeId)?.name ?? value.endNodeId;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailTitle(icon: Icons.route_outlined, title: '$start → $end'),
          _detail('Edge ID', value.edgeId.toString()),
          _detail('Çift yönlü', value.bidirectional ? 'Evet' : 'Hayır'),
          _detail('Maliyet', value.cost.toString()),
          _detail('Azami hız', '${value.maxSpeed} m/s'),
          _detail('Yük kuralı', value.loadRule.wireName),
          _detail('Hareket yönü', value.movementDirection.wireName),
          _detail(
              'Gate event', value.gateEvent.isEmpty ? '--' : value.gateEvent),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed:
                graph.canEdit && !graph.busy ? () => onEditEdge(value) : null,
            icon: const Icon(Icons.edit_road),
            label: const Text('Bağlantıyı Düzenle'),
          ),
          TextButton.icon(
            onPressed:
                graph.canEdit && !graph.busy ? () => onDeleteEdge(value) : null,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Bağlantıyı Sil'),
            style: TextButton.styleFrom(foregroundColor: _danger),
          ),
        ],
      ),
    );
  }
}

class _GraphStateBanner extends StatelessWidget {
  const _GraphStateBanner({
    required this.graph,
    required this.mapping,
    required this.mapPickMode,
    required this.onCancelPick,
  });

  final GcsFieldGraphModel graph;
  final GcsMappingModel mapping;
  final bool mapPickMode;
  final VoidCallback onCancelPick;

  @override
  Widget build(BuildContext context) {
    String text;
    Color color;
    if (!graph.connected) {
      text = 'Robot bağlantısı yok.';
      color = _danger;
    } else if (!graph.hasSelectedField) {
      text = 'Önce Kayıtlı Haritalar’dan bir saha seçin.';
      color = _warning;
    } else if (graph.graphLoading) {
      text = 'Saha grafiği yükleniyor...';
      color = _accent;
    } else if (graph.graphError != null) {
      text = graph.graphError!;
      color = _danger;
    } else if (graph.selectedFieldIsActive) {
      text =
          'Bu saha aktif ve salt okunur. Düzenlemek için üstteki "Sahayı Düzenlemeye Aç" düğmesini kullanın.';
      color = _warning;
    } else if (!graph.selectedFieldActivityKnown) {
      text = 'Aktif saha durumu güncel değil; düzenleme kilitli.';
      color = _warning;
    } else if (mapPickMode) {
      text = 'Haritada düğüm konumunu seçin.';
      color = _accent;
    } else if (graph.busy) {
      text = 'ROS saha işlemi sürüyor: ${graph.operation}';
      color = _accent;
    } else {
      text = 'Production saha grafiği düzenlemeye hazır.';
      color = _success;
    }
    return Container(
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color))),
          if (mapPickMode)
            TextButton(onPressed: onCancelPick, child: const Text('İptal')),
        ],
      ),
    );
  }
}

class _MapEmptyState extends StatelessWidget {
  const _MapEmptyState({required this.graph, required this.mapping});

  final GcsFieldGraphModel graph;
  final GcsMappingModel mapping;

  @override
  Widget build(BuildContext context) {
    final text = !graph.connected
        ? 'Robot bağlantısı yok.'
        : !graph.hasSelectedField
            ? 'Önce bir saha seçin.'
            : graph.graphLoading
                ? 'Saha grafiği yükleniyor...'
                : mapping.awaitingFreshPreview
                    ? 'Seçili saha için güncel harita önizlemesi bekleniyor...'
                    : 'Harita önizlemesi alınamadı.';
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: _muted, fontSize: 16),
      ),
    );
  }
}

class _PackageBadge extends StatelessWidget {
  const _PackageBadge({required this.graph});
  final GcsFieldGraphModel graph;

  @override
  Widget build(BuildContext context) {
    final active = graph.selectedFieldIsActive;
    final valid = graph.packageStatus?.state == FieldPackageState.valid;
    if (!active && !valid) return const SizedBox.shrink();
    final state = active ? 'ACTIVE' : 'VALID';
    final color = active
        ? _success
        : state == 'VALID'
            ? _accent
            : _warning;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(state, style: TextStyle(color: color, fontSize: 12)),
      ),
    );
  }
}

class _PanelMessage extends StatelessWidget {
  const _PanelMessage(this.message, {this.progress = false, this.action});
  final String message;
  final bool progress;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (progress) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 14),
              ],
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted),
              ),
              if (action != null) ...[
                const SizedBox(height: 14),
                action!,
              ],
            ],
          ),
        ),
      );
}

class _DetailTitle extends StatelessWidget {
  const _DetailTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            Icon(icon, color: _accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _bright,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
}

Widget _detail(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(label, style: const TextStyle(color: _muted)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(color: _bright, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );

class _CompetitionEdgePlanItem {
  const _CompetitionEdgePlanItem({required this.label, required this.edge});

  final String label;
  final FieldEdge edge;
}

class _CompetitionEdgePlan {
  const _CompetitionEdgePlan({
    required this.edges,
    required this.existingCount,
    required this.issues,
  });

  final List<_CompetitionEdgePlanItem> edges;
  final int existingCount;
  final List<String> issues;

  static _CompetitionEdgePlan build({
    required List<FieldNode> nodes,
    required List<FieldEdge> existingEdges,
  }) {
    final issues = <String>[];
    final resolved = <String, FieldNode>{};

    void resolveStation(
      String stationId,
      FieldNodeRole role, {
      String? key,
    }) {
      final matches = nodes
          .where(
            (node) =>
                node.stationId.trim().toUpperCase() == stationId &&
                node.role == role,
          )
          .toList(growable: false);
      final targetKey = key ?? stationId;
      if (matches.length == 1) {
        resolved[targetKey] = matches.single;
      } else if (matches.isEmpty) {
        issues.add(
          '$stationId için ${role.operatorLabel} rolünde düğüm bulunamadı.',
        );
      } else {
        issues.add(
          '$stationId için ${role.operatorLabel} rolünde birden fazla düğüm var.',
        );
      }
    }

    void resolveRole(String key, FieldNodeRole role) {
      final matches =
          nodes.where((node) => node.role == role).toList(growable: false);
      if (matches.length == 1) {
        resolved[key] = matches.single;
      } else if (matches.isEmpty) {
        issues.add('${role.operatorLabel} rolünde düğüm bulunamadı.');
      } else {
        issues.add('${role.operatorLabel} rolünde birden fazla düğüm var.');
      }
    }

    resolveStation('WAIT', FieldNodeRole.wait);
    for (var index = 1; index <= 6; index++) {
      resolveStation('D$index', FieldNodeRole.transit);
    }
    resolveRole('Q5', FieldNodeRole.gateQ5);
    resolveRole('Q6', FieldNodeRole.gateQ6);
    for (var index = 1; index <= 3; index++) {
      final station = 'A$index';
      final stationExists = nodes.any(
        (node) => node.stationId.trim().toUpperCase() == station,
      );
      if (!stationExists) continue;
      resolveStation(
        station,
        FieldNodeRole.pickupApproach,
        key: '${station}_APPROACH',
      );
      resolveStation(station, FieldNodeRole.pickupDock);
    }
    for (var index = 1; index <= 3; index++) {
      final station = 'B$index';
      final stationExists = nodes.any(
        (node) => node.stationId.trim().toUpperCase() == station,
      );
      if (!stationExists) continue;
      resolveStation(
        station,
        FieldNodeRole.dropoffApproach,
        key: '${station}_APPROACH',
      );
      resolveStation(station, FieldNodeRole.dropoffDock);
    }

    if (issues.isNotEmpty) {
      return _CompetitionEdgePlan(
        edges: const [],
        existingCount: 0,
        issues: issues,
      );
    }

    const bidirectionalLinks = <(String, String)>[
      ('WAIT', 'D1'),
      ('D1', 'D2'),
      ('D2', 'D3'),
      ('D3', 'Q5'),
      ('Q6', 'D4'),
      ('D4', 'D5'),
      ('D4', 'D6'),
      ('D1', 'A1_APPROACH'),
      ('A1_APPROACH', 'A1'),
      ('D2', 'A2_APPROACH'),
      ('A2_APPROACH', 'A2'),
      ('D3', 'A3_APPROACH'),
      ('A3_APPROACH', 'A3'),
      ('D5', 'B1_APPROACH'),
      ('B1_APPROACH', 'B1'),
      ('D4', 'B2_APPROACH'),
      ('B2_APPROACH', 'B2'),
      ('D6', 'B3_APPROACH'),
      ('B3_APPROACH', 'B3'),
    ];
    const directedGateLinks = <(String, String, String)>[
      ('Q5', 'Q6', 'q5_outbound'),
      ('Q6', 'Q5', 'q6_return'),
    ];

    final planned = <_CompetitionEdgePlanItem>[];
    var existingCount = 0;

    void addLink(
      String startKey,
      String endKey, {
      required bool bidirectional,
      String gateEvent = '',
    }) {
      final start = resolved[startKey]!;
      final end = resolved[endKey]!;
      final dx = start.pose.x - end.pose.x;
      final dy = start.pose.y - end.pose.y;
      final distance = math.sqrt(dx * dx + dy * dy);
      final label = '$startKey ${bidirectional ? '↔' : '→'} $endKey';
      if (distance <= 0 || !distance.isFinite) {
        issues.add('$label oluşturulamadı: düğümlerin konumları aynı.');
        return;
      }

      final betweenEndpoints = existingEdges.where((edge) {
        final sameDirection =
            edge.startNodeId == start.nodeId && edge.endNodeId == end.nodeId;
        final reverseDirection =
            edge.startNodeId == end.nodeId && edge.endNodeId == start.nodeId;
        return sameDirection || reverseDirection;
      }).toList(growable: false);
      final alreadyExists = betweenEndpoints.any((edge) {
        if (bidirectional) return edge.bidirectional;
        return !edge.bidirectional &&
            edge.startNodeId == start.nodeId &&
            edge.endNodeId == end.nodeId &&
            edge.gateEvent == gateEvent;
      });
      if (alreadyExists) {
        existingCount++;
        return;
      }
      final hasConflict = bidirectional
          ? betweenEndpoints.isNotEmpty
          : betweenEndpoints.any(
              (edge) =>
                  edge.bidirectional ||
                  (edge.startNodeId == start.nodeId &&
                      edge.endNodeId == end.nodeId),
            );
      if (hasConflict) {
        issues.add(
          '$label arasında farklı ayarlı bir bağlantı zaten var; '
          'önce elle kontrol edin.',
        );
        return;
      }

      planned.add(
        _CompetitionEdgePlanItem(
          label: label,
          edge: FieldEdge(
            edgeId: FieldGraphId.next(),
            startNodeId: start.nodeId,
            endNodeId: end.nodeId,
            bidirectional: bidirectional,
            cost: distance,
            maxSpeed: 0.20,
            loadRule: FieldLoadRule.any,
            movementDirection: FieldMovementDirection.forward,
            gateEvent: gateEvent,
          ),
        ),
      );
    }

    for (final link in bidirectionalLinks) {
      if (!resolved.containsKey(link.$1) || !resolved.containsKey(link.$2)) {
        continue;
      }
      addLink(link.$1, link.$2, bidirectional: true);
    }
    for (final link in directedGateLinks) {
      addLink(
        link.$1,
        link.$2,
        bidirectional: false,
        gateEvent: link.$3,
      );
    }

    return _CompetitionEdgePlan(
      edges: List.unmodifiable(planned),
      existingCount: existingCount,
      issues: List.unmodifiable(issues),
    );
  }
}

FieldNode? _nodeById(List<FieldNode> nodes, int? id) {
  if (id == null) return null;
  for (final node in nodes) {
    if (node.nodeId == id) return node;
  }
  return null;
}

FieldEdge? _edgeById(List<FieldEdge> edges, int? id) {
  if (id == null) return null;
  for (final edge in edges) {
    if (edge.edgeId == id) return edge;
  }
  return null;
}

String _editBlockReason(GcsFieldGraphModel graph) {
  if (!graph.connected) return 'Robot bağlantısı yok.';
  if (!graph.hasSelectedField) return 'Önce bir saha seçin.';
  if (graph.graphLoading) return 'Saha grafiği yükleniyor...';
  if (graph.graphError != null) return graph.graphError!;
  if (!graph.selectedFieldActivityKnown) {
    return 'Aktif saha durumu güncel değil.';
  }
  if (graph.selectedFieldIsActive) {
    return 'Bu saha aktif ve salt okunur. Önce Sahayı Düzenlemeye Aç düğmesini kullanın.';
  }
  if (graph.busy) return 'Başka bir saha işlemi devam ediyor.';
  return 'Saha şu anda düzenlenemiyor.';
}

String _activationBlockReason(GcsFieldGraphModel graph) {
  if (!graph.connected) return 'Robot bağlantısı yok.';
  if (!graph.hasSelectedField) return 'Önce bir saha seçin.';
  if (!graph.graphFresh) return 'Saha grafiği güncel değil.';
  if (graph.selectedFieldIsActive) return 'Bu saha zaten aktif.';
  if (!graph.validationCurrent) {
    if (graph.packageStatus?.state != FieldPackageState.valid) {
      return 'Saha doğrulaması başarılı değil.';
    }
    return 'ROS doğrulama durumu veya paket hash’i güncel değil.';
  }
  if (!graph.robotStatusFresh) return 'Robot telemetrisi güncel değil.';
  if (!graph.mappingStatusFresh) return 'Haritalama durumu henüz güncel değil.';
  if (graph.mappingActive) return 'Haritalama devam ediyor.';
  if (graph.missionActive) return 'Çalışan bir görev var.';
  if (graph.vehicleMoving) return 'Araç hareket ediyor.';
  return 'Aktivasyon koşulları henüz hazır değil.';
}

Color _nodeColor(FieldNodeRole role) => switch (role) {
      FieldNodeRole.pickupApproach => const Color(0xFF29B6F6),
      FieldNodeRole.pickupDock => const Color(0xFF1565C0),
      FieldNodeRole.dropoffApproach => const Color(0xFFFF8A65),
      FieldNodeRole.dropoffDock => _danger,
      FieldNodeRole.gateQ5 || FieldNodeRole.gateQ6 => Colors.purpleAccent,
      FieldNodeRole.qrTrigger => Colors.cyanAccent,
      FieldNodeRole.wait => _success,
      FieldNodeRole.transit => _muted,
    };

Color _edgeColor(FieldEdge edge) =>
    edge.loadRule == FieldLoadRule.loaded ? _warning : _accent;

Future<FieldNode?> showFieldNodeEditorDialog({
  required BuildContext context,
  FieldNode? existing,
  FieldPose2D? initialPose,
  bool currentPose = false,
  Set<int> existingNodeIds = const {},
}) =>
    showDialog<FieldNode>(
      context: context,
      builder: (_) => _FieldNodeEditorDialog(
        existing: existing,
        initialPose: initialPose,
        currentPose: currentPose,
        existingNodeIds: existingNodeIds,
      ),
    );

class _FieldNodeEditorDialog extends StatefulWidget {
  const _FieldNodeEditorDialog({
    this.existing,
    this.initialPose,
    required this.currentPose,
    required this.existingNodeIds,
  });

  final FieldNode? existing;
  final FieldPose2D? initialPose;
  final bool currentPose;
  final Set<int> existingNodeIds;

  @override
  State<_FieldNodeEditorDialog> createState() => _FieldNodeEditorDialogState();
}

class _FieldNodeEditorDialogState extends State<_FieldNodeEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nodeId;
  late final TextEditingController _name;
  late final TextEditingController _stationId;
  late final TextEditingController _x;
  late final TextEditingController _y;
  late final TextEditingController _yaw;
  late final TextEditingController _metadata;
  late FieldNodeRole _role;
  late FieldLoadRule _loadRule;
  late FieldApproachMode _approachMode;

  @override
  void initState() {
    super.initState();
    final node = widget.existing;
    final pose = node?.pose ?? widget.initialPose ?? FieldPose2D.zero;
    _nodeId = TextEditingController(
      text: (node?.nodeId ?? _nextAvailableNodeId(widget.existingNodeIds))
          .toString(),
    );
    _name = TextEditingController(text: node?.name ?? '');
    _stationId = TextEditingController(text: node?.stationId ?? '');
    _x = TextEditingController(text: pose.x.toStringAsFixed(3));
    _y = TextEditingController(text: pose.y.toStringAsFixed(3));
    _yaw = TextEditingController(
      text: radiansToDegrees(pose.theta).toStringAsFixed(1),
    );
    _metadata = TextEditingController(text: node?.metadataJson ?? '{}');
    _role = node?.role ?? FieldNodeRole.transit;
    _loadRule = node?.loadRule ?? FieldLoadRule.any;
    _approachMode = node?.approachMode ?? FieldApproachMode.navigate;
  }

  @override
  void dispose() {
    _nodeId.dispose();
    _name.dispose();
    _stationId.dispose();
    _x.dispose();
    _y.dispose();
    _yaw.dispose();
    _metadata.dispose();
    super.dispose();
  }

  String get _roleHelp => switch (_role) {
        FieldNodeRole.gateQ5 => 'Gidiş yönündeki kapı izin noktası',
        FieldNodeRole.gateQ6 => 'Dönüş yönündeki kapı izin noktası',
        FieldNodeRole.qrTrigger => 'QR doğrulamasını tetikleyen düğüm',
        FieldNodeRole.pickupApproach => 'Alma istasyonuna yaklaşma noktası',
        FieldNodeRole.pickupDock => 'Yükün alınacağı dock noktası',
        FieldNodeRole.dropoffApproach => 'Bırakma istasyonuna yaklaşma noktası',
        FieldNodeRole.dropoffDock => 'Yükün bırakılacağı dock noktası',
        FieldNodeRole.wait => 'Görevler arasında bekleme noktası',
        FieldNodeRole.transit => 'Normal rota geçiş noktası',
      };

  void _applyRole(FieldNodeRole role) {
    setState(() {
      _role = role;
      switch (role) {
        case FieldNodeRole.pickupDock:
          _loadRule = FieldLoadRule.empty;
          _approachMode = FieldApproachMode.dock;
          break;
        case FieldNodeRole.dropoffDock:
          _loadRule = FieldLoadRule.loaded;
          _approachMode = FieldApproachMode.dock;
          break;
        case FieldNodeRole.gateQ5 ||
              FieldNodeRole.gateQ6 ||
              FieldNodeRole.qrTrigger:
          _loadRule = FieldLoadRule.any;
          _approachMode = FieldApproachMode.trigger;
          break;
        case FieldNodeRole.pickupApproach ||
              FieldNodeRole.dropoffApproach ||
              FieldNodeRole.wait ||
              FieldNodeRole.transit:
          _loadRule = FieldLoadRule.any;
          _approachMode = FieldApproachMode.navigate;
          break;
      }
    });
  }

  String? _safeId(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null) return 'Node ID tam sayı olmalı';
    if (widget.existingNodeIds.contains(parsed) &&
        parsed != widget.existing?.nodeId) {
      return 'Bu Node ID başka bir düğüm tarafından kullanılıyor';
    }
    try {
      FieldGraphId.requireSafe(parsed, 'node_id');
      return null;
    } catch (error) {
      return _cleanError(error);
    }
  }

  String? _number(String? value) =>
      _parseNumber(value) == null ? 'Sonlu sayı girin' : null;

  String? _metadataObject(String? value) {
    try {
      return jsonDecode(value ?? '') is Map ? null : 'JSON object olmalı';
    } catch (_) {
      return 'Geçerli JSON object girin';
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    final pose = widget.currentPose
        ? FieldPose2D.zero
        : FieldPose2D(
            x: _parseNumber(_x.text)!,
            y: _parseNumber(_y.text)!,
            theta: degreesToRadians(_parseNumber(_yaw.text)!),
          );
    Navigator.pop(
      context,
      FieldNode(
        nodeId: int.parse(_nodeId.text.trim()),
        name: _name.text.trim(),
        role: _role,
        stationId: _stationId.text.trim(),
        pose: pose,
        loadRule: _loadRule,
        approachMode: _approachMode,
        metadataJson: _metadata.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
          widget.existing == null ? 'Yeni production düğümü' : 'Düğümü düzenle',
        ),
        content: SizedBox(
          width: 560,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nodeId,
                    readOnly: true,
                    enableInteractiveSelection: true,
                    decoration: const InputDecoration(
                      labelText: 'Node ID',
                      helperText: 'Otomatik oluşturulur ve değiştirilemez',
                      suffixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: _safeId,
                  ),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Ad'),
                    validator: (value) => value?.trim().isNotEmpty == true
                        ? null
                        : 'Mevcut ROS modeli için ad boş olamaz',
                  ),
                  DropdownButtonFormField<FieldNodeRole>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Rol'),
                    items: [
                      for (final role in FieldNodeRole.values.where(
                        (role) =>
                            role != FieldNodeRole.qrTrigger ||
                            widget.existing?.role == FieldNodeRole.qrTrigger,
                      ))
                        DropdownMenuItem(
                          value: role,
                          child: Text(role.operatorLabel),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) _applyRole(value);
                    },
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        _roleHelp,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ),
                  ),
                  TextFormField(
                    controller: _stationId,
                    decoration: const InputDecoration(
                      labelText: 'Station ID / Nokta Kimliği',
                      helperText: 'Örnek: WAIT, A1, B2, D1 veya Q5',
                    ),
                    validator: (value) => value?.trim().isNotEmpty == true
                        ? null
                        : 'ROS doğrulaması için Station ID gerekli',
                  ),
                  if (widget.currentPose)
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.my_location),
                      title: Text('X / Y robotun güncel pozundan alınacak'),
                      subtitle: Text(
                        '/fields/save_current_pose_node gerçek pozu kaydeder.',
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _x,
                            decoration:
                                const InputDecoration(labelText: 'X (m)'),
                            validator: _number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _y,
                            decoration:
                                const InputDecoration(labelText: 'Y (m)'),
                            validator: _number,
                          ),
                        ),
                      ],
                    ),
                  TextFormField(
                    controller: _yaw,
                    decoration: const InputDecoration(
                      labelText: 'Yaw (derece)',
                      helperText: 'ROS’a radyan olarak gönderilir',
                    ),
                    validator: _number,
                  ),
                  DropdownButtonFormField<FieldLoadRule>(
                    initialValue: _loadRule,
                    decoration: const InputDecoration(labelText: 'Load Rule'),
                    items: [
                      for (final rule in FieldLoadRule.values)
                        DropdownMenuItem(
                          value: rule,
                          child: Text(rule.wireName),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _loadRule = value);
                    },
                  ),
                  DropdownButtonFormField<FieldApproachMode>(
                    initialValue: _approachMode,
                    decoration:
                        const InputDecoration(labelText: 'Approach Mode'),
                    items: [
                      for (final mode in FieldApproachMode.values)
                        DropdownMenuItem(
                          value: mode,
                          child: Text(mode.wireName),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _approachMode = value);
                      }
                    },
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Gelişmiş'),
                    children: [
                      TextFormField(
                        controller: _metadata,
                        minLines: 2,
                        maxLines: 5,
                        decoration:
                            const InputDecoration(labelText: 'metadata_json'),
                        validator: _metadataObject,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(onPressed: _submit, child: const Text('Kaydet')),
        ],
      );
}

double? _parseNumber(String? raw) {
  final value = double.tryParse((raw ?? '').trim().replaceAll(',', '.'));
  return value?.isFinite == true ? value : null;
}

int _nextAvailableNodeId(Set<int> existingNodeIds) {
  var candidate = FieldGraphId.next();
  while (existingNodeIds.contains(candidate)) {
    candidate = FieldGraphId.next();
  }
  return candidate;
}

String _cleanError(Object error) =>
    error.toString().replaceFirst('Bad state: ', '').trim();
