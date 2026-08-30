import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'data_model.dart';
import 'models/field_graph_models.dart';
import 'models/gcs_field_graph_model.dart';
import 'models/gcs_mapping_model.dart';
import 'models/gcs_node_model.dart';
import 'scenerio_page.dart';
import 'services/agv_service.dart';
import 'services/ros_mapping_contract.dart';
import 'widgets/map_preview_stage.dart';

const _bg = Color(0xFF121212);
const _panelBg = Color(0xFF1A1A1A);
const _borderC = Color(0xFF333333);
const _muted = Color(0xFF9E9E9E);
const _bright = Color(0xFFE0E0E0);
const _warn = Color(0xFFB7791F);
const _accent = Color(0xFF42A5F5);
const _danger = Color(0xFFE53935);

/// Düğüm öğretme: yalnızca robot konumuna (pixel X/Y) basılır.
class NodeTeachPage extends StatefulWidget {
  const NodeTeachPage({super.key});

  @override
  State<NodeTeachPage> createState() => _NodeTeachPageState();
}

class _NodeTeachPageState extends State<NodeTeachPage> {
  final Set<String> _savingDemoPoints = <String>{};
  final Set<String> _savingDemoRoutePoints = <String>{};
  final Set<String> _clearingDemoRoutes = <String>{};
  final Map<String, DemoPointSaveResult> _savedDemoPoints =
      <String, DemoPointSaveResult>{};

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  String _errorText(Object error) =>
      error.toString().replaceFirst('Bad state: ', '').trim();

  Future<_NodeEditorValue?> _openNodeEditor({
    FieldNode? existing,
    required bool screenYaw,
  }) =>
      showDialog<_NodeEditorValue>(
        context: context,
        builder: (_) => _NodeEditorDialog(
          existing: existing,
          screenYaw: screenYaw,
        ),
      );

  Future<void> _createAtRobot() async {
    final graph = context.read<GcsFieldGraphModel>();
    if (!graph.canEdit) return;
    final value = await _openNodeEditor(screenYaw: false);
    if (value == null || !mounted) return;
    try {
      final node = value.toNode(pose: FieldPose2D.zero);
      final result = await graph.saveNode(node, currentPose: true);
      if (mounted) _toast(context, result.message);
    } catch (error) {
      if (mounted) _toast(context, 'Düğüm kaydedilemedi: ${_errorText(error)}');
    }
  }

  Future<void> _createAtPixel(double pixelX, double pixelY) async {
    final graph = context.read<GcsFieldGraphModel>();
    if (!graph.canEdit) return;
    final value = await _openNodeEditor(screenYaw: true);
    if (value == null || !mounted) return;
    try {
      final result = await graph.saveNodeAtPixel(
        node: value.toNode(pose: FieldPose2D.zero),
        pixelX: pixelX,
        pixelY: pixelY,
        screenYaw: value.yawRadians,
      );
      if (!mounted) return;
      _toast(context, result.message);
    } catch (error) {
      if (mounted) _toast(context, 'Düğüm kaydedilemedi: ${_errorText(error)}');
    }
  }

  Future<void> _editNode(TaughtFieldNode projected) async {
    final graph = context.read<GcsFieldGraphModel>();
    final id = int.tryParse(projected.id);
    final existing = id == null ? null : graph.nodeById(id);
    if (existing == null || !graph.canEdit) return;
    final value = await _openNodeEditor(existing: existing, screenYaw: false);
    if (value == null || !mounted) return;
    try {
      final pose = FieldPose2D(
        x: existing.pose.x,
        y: existing.pose.y,
        theta: value.yawRadians,
      );
      final result = await graph.saveNode(
        value.toNode(pose: pose, nodeId: existing.nodeId),
        currentPose: false,
      );
      if (mounted) _toast(context, result.message);
    } catch (error) {
      if (mounted) {
        _toast(context, 'Düğüm güncellenemedi: ${_errorText(error)}');
      }
    }
  }

  Future<void> _moveNodeToRobot(TaughtFieldNode projected) async {
    final graph = context.read<GcsFieldGraphModel>();
    final id = int.tryParse(projected.id);
    final existing = id == null ? null : graph.nodeById(id);
    if (existing == null || !graph.canEdit) return;
    try {
      final result = await graph.saveNode(existing, currentPose: true);
      if (mounted) _toast(context, result.message);
    } catch (error) {
      if (mounted) _toast(context, 'Düğüm taşınamadı: ${_errorText(error)}');
    }
  }

  Future<void> _deleteNode(TaughtFieldNode projected) async {
    final graph = context.read<GcsFieldGraphModel>();
    final id = int.tryParse(projected.id);
    if (id == null || !graph.canEdit) return;
    final connectedEdges = graph.connectedEdges(id);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Düğümü sil'),
            content: Text(
              connectedEdges.isEmpty
                  ? '${projected.name} silinecek.'
                  : '${projected.name} ve bağlı ${connectedEdges.length} kenar silinecek.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  connectedEdges.isEmpty
                      ? 'Düğümü Sil'
                      : 'Düğüm ve Kenarları Sil',
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    try {
      final result = await graph.deleteNode(
        id,
        deleteConnectedEdges: connectedEdges.isNotEmpty,
      );
      if (mounted) _toast(context, result.message);
    } catch (error) {
      if (mounted) _toast(context, 'Düğüm silinemedi: ${_errorText(error)}');
    }
  }

  Future<void> _saveDemoPoint(String pointName) async {
    final mapping = context.read<GcsMappingModel>();
    if (!mapping.canSaveDemoPoint || _savingDemoPoints.contains(pointName)) {
      return;
    }
    setState(() => _savingDemoPoints.add(pointName));
    try {
      final response = await AgvService.saveDemoPoint(pointName);
      if (!mounted) return;
      final result = DemoPointSaveResult.fromServiceResponse(response);
      if (!result.success) {
        _toast(
          context,
          RosServiceResponse.failureMessage(
            response,
            fallback: '$pointName noktası kaydedilemedi',
          ),
        );
        return;
      }
      if (result.pose == null) {
        _toast(
          context,
          '$pointName noktası kaydedilemedi: servis cevabında pose yok',
        );
        return;
      }
      mapping.markDemoPointSaved(pointName, result);
      setState(() => _savedDemoPoints[pointName] = result);
      final pose = result.pose;
      final poseText = pose == null
          ? ''
          : ' (x=${pose.x.toStringAsFixed(2)}, '
              'y=${pose.y.toStringAsFixed(2)}, '
              'θ=${pose.theta.toStringAsFixed(2)})';
      _toast(
        context,
        result.message.isEmpty
            ? '$pointName noktası kaydedildi$poseText'
            : '${result.message}$poseText',
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Bad state: ', '');
      _toast(context, '$pointName noktası kaydedilemedi: $message');
    } finally {
      if (mounted) {
        setState(() => _savingDemoPoints.remove(pointName));
      }
    }
  }

  Future<void> _saveDemoRoutePoint(String targetName) async {
    final mapping = context.read<GcsMappingModel>();
    if (!mapping.canSaveDemoPoint ||
        _savingDemoRoutePoints.contains(targetName) ||
        _clearingDemoRoutes.contains(targetName)) {
      return;
    }
    setState(() => _savingDemoRoutePoints.add(targetName));
    try {
      final response = await AgvService.saveDemoRoutePoint(targetName);
      if (!mounted) return;
      if (!RosServiceResponse.demoRouteOperationSucceeded(response)) {
        _toast(
          context,
          RosServiceResponse.failureMessage(
            response,
            fallback: '$targetName rota noktası kaydedilemedi',
          ),
        );
        return;
      }
      final message = response['message']?.toString().trim() ?? '';
      _toast(
        context,
        message.isEmpty
            ? '$targetName rotasına dönüş noktası eklendi'
            : message,
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Bad state: ', '');
      _toast(context, '$targetName rota noktası kaydedilemedi: $message');
    } finally {
      if (mounted) {
        setState(() => _savingDemoRoutePoints.remove(targetName));
      }
    }
  }

  Future<void> _clearDemoRoute(String targetName) async {
    final mapping = context.read<GcsMappingModel>();
    if (!mapping.canSaveDemoPoint ||
        _savingDemoRoutePoints.contains(targetName) ||
        _clearingDemoRoutes.contains(targetName)) {
      return;
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('$targetName rotasını temizle'),
            content: Text(
              '$targetName rotasına kaydedilmiş bütün dönüş noktaları silinecek.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Rotayı Temizle'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _clearingDemoRoutes.add(targetName));
    try {
      final response = await AgvService.clearDemoRoute(targetName);
      if (!mounted) return;
      if (!RosServiceResponse.demoRouteOperationSucceeded(response)) {
        _toast(
          context,
          RosServiceResponse.failureMessage(
            response,
            fallback: '$targetName rotası temizlenemedi',
          ),
        );
        return;
      }
      final message = response['message']?.toString().trim() ?? '';
      _toast(
        context,
        message.isEmpty ? '$targetName rotası temizlendi' : message,
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Bad state: ', '');
      _toast(context, '$targetName rotası temizlenemedi: $message');
    } finally {
      if (mounted) {
        setState(() => _clearingDemoRoutes.remove(targetName));
      }
    }
  }

  /// F.5: haritalama sırasında veya lokalizasyon açıkken öğretme bağlamı.
  bool _specTeachContext(GcsMappingModel mapping) {
    if (!mapping.isConnected || !mapping.hasPreviewPng) return false;
    if (mapping.activeLocalizedField != null) return true;
    final status = mapping.liveMappingStatus;
    return status == MappingStatus.mapping;
  }

  Future<void> _openScenario(BuildContext context) async {
    final dataPoints = context.read<DataModel>().dataPoints;
    await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ScenarioPage(
          dataPoints: dataPoints,
          site: '',
          rota: '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapping = context.watch<GcsMappingModel>();
    final graph = context.watch<GcsFieldGraphModel>();
    final nodes = context.watch<GcsNodeModel>();
    final robot = mapping.visibleRobotPixel;
    final insideMap = robot?.insideMap == true;
    final specContext = _specTeachContext(mapping);
    final canCreate = graph.canEdit && specContext;
    final fieldHint = graph.selectedFieldName;

    final markers = nodes.nodes
        .map(
          (n) => MapPreviewNodeMarker(
            label: n.name,
            pixelX: n.pixelX,
            pixelY: n.pixelY,
            color: n.markerColor,
          ),
        )
        .toList(growable: true);
    final demoA = mapPreviewDemoPointMarker(
      label: 'A',
      pose: mapping.demoPointA,
      metadata: mapping.previewMetadata,
      color: const Color(0xFF29B6F6),
    );
    final demoB = mapPreviewDemoPointMarker(
      label: 'B',
      pose: mapping.demoPointB,
      metadata: mapping.previewMetadata,
      color: const Color(0xFFFF7043),
    );
    if (demoA != null) markers.add(demoA);
    if (demoB != null) markers.add(demoB);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _panelBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Düğümler',
          style: TextStyle(
            color: Colors.white,
            fontSize: 5.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (nodes.hasRouteEligibleNodes)
            TextButton(
              onPressed: () => _openScenario(context),
              child: Text(
                'Senaryoya geç',
                style: TextStyle(color: _accent, fontSize: 3.sp),
              ),
            ),
          if (fieldHint != null)
            Padding(
              padding: EdgeInsets.only(right: 2.w),
              child: Center(
                child: Text(
                  'Saha: $fieldHint',
                  style: TextStyle(color: _muted, fontSize: 3.sp),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HintBar(
            hasPreview: mapping.hasPreviewPng,
            insideMap: insideMap,
            hasRobot: robot != null,
            localized: mapping.activeLocalizedField != null,
            connected: mapping.isConnected,
            specContext: specContext,
            nodeCount: nodes.nodes.length,
            routeEligibleCount: nodes.routeEligibleNodes.length,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 7,
                  child: mapping.hasPreviewPng
                      ? MapPreviewStage(
                          pngBytes: mapping.previewPng!,
                          metadata: mapping.previewMetadata,
                          robotPixel: robot,
                          awaitingFresh: mapping.awaitingFreshPreview,
                          sourceLabel: mapping.previewSourceLabel,
                          nodeMarkers: markers,
                          onMapTap: canCreate ? _createAtPixel : null,
                        )
                      : _NoMapPlaceholder(
                          connected: mapping.isConnected,
                          localized: mapping.activeLocalizedField != null,
                        ),
                ),
                Container(
                  width: 34.w,
                  decoration: const BoxDecoration(
                    color: _panelBg,
                    border: Border(left: BorderSide(color: _borderC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DemoPointPanel(
                        enabled: mapping.canSaveDemoPoint,
                        localizationStatus: mapping.localizationStatus,
                        savingPoints: _savingDemoPoints,
                        savedPoints: _savedDemoPoints,
                        savingRoutePoints: _savingDemoRoutePoints,
                        clearingRoutes: _clearingDemoRoutes,
                        onSave: _saveDemoPoint,
                        onSaveRoutePoint: _saveDemoRoutePoint,
                        onClearRoute: _clearDemoRoute,
                      ),
                      const Divider(height: 1, color: _borderC),
                      Expanded(
                        child: _NodeListPanel(
                          nodes: nodes.nodes,
                          canEdit: graph.canEdit,
                          canMoveToRobot: insideMap && graph.canEdit,
                          onEdit: (node) => unawaited(_editNode(node)),
                          onDelete: (node) => unawaited(_deleteNode(node)),
                          onMoveToRobot: (node) =>
                              unawaited(_moveNodeToRobot(node)),
                        ),
                      ),
                      const Divider(height: 1, color: _borderC),
                      Padding(
                        padding: EdgeInsets.all(2.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!graph.hasSelectedField || !graph.graphFresh)
                              Padding(
                                padding: EdgeInsets.only(bottom: 6.h),
                                child: Text(
                                  graph.graphError ??
                                      'Kayıtlı Haritalar’dan düzenlenecek sahayı seçin.',
                                  style: TextStyle(
                                    color: _warn,
                                    fontSize: 2.8.sp,
                                  ),
                                ),
                              ),
                            SizedBox(
                              height: 40.h,
                              child: ElevatedButton(
                                onPressed: canCreate
                                    ? () => unawaited(_createAtRobot())
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _accent,
                                  disabledBackgroundColor:
                                      const Color(0xFF2A2A2A),
                                  foregroundColor: Colors.white,
                                  disabledForegroundColor: _muted,
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Robot konumundan düğüm ekle',
                                  style: TextStyle(
                                    fontSize: 2.8.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _DemoPointPanel extends StatelessWidget {
  final bool enabled;
  final LocalizationStatus? localizationStatus;
  final Set<String> savingPoints;
  final Map<String, DemoPointSaveResult> savedPoints;
  final Set<String> savingRoutePoints;
  final Set<String> clearingRoutes;
  final Future<void> Function(String pointName) onSave;
  final Future<void> Function(String targetName) onSaveRoutePoint;
  final Future<void> Function(String targetName) onClearRoute;

  const _DemoPointPanel({
    required this.enabled,
    required this.localizationStatus,
    required this.savingPoints,
    required this.savedPoints,
    required this.savingRoutePoints,
    required this.clearingRoutes,
    required this.onSave,
    required this.onSaveRoutePoint,
    required this.onClearRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(2.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Demo A/B Noktaları',
            style: TextStyle(
              color: _bright,
              fontSize: 3.2.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 0.4.h),
          Row(
            children: [
              Expanded(child: _buildButton('A')),
              SizedBox(width: 1.w),
              Expanded(child: _buildButton('B')),
            ],
          ),
          SizedBox(height: 0.8.h),
          _buildRouteControls('A'),
          SizedBox(height: 0.6.h),
          _buildRouteControls('B'),
          for (final point in const ['A', 'B'])
            if (savedPoints[point] case final result?)
              Padding(
                padding: EdgeInsets.only(top: 0.5.h),
                child: Text(
                  _resultText(point, result),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF81C784),
                    fontSize: 2.4.sp,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildButton(String point) {
    final saving = savingPoints.contains(point);
    return SizedBox(
      height: 38.h,
      child: ElevatedButton(
        onPressed: enabled && !saving ? () => unawaited(onSave(point)) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          disabledBackgroundColor: const Color(0xFF2A2A2A),
          foregroundColor: Colors.white,
          disabledForegroundColor: _muted,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 1.w),
        ),
        child: saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                '$point Noktasını Kaydet',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 2.4.sp),
              ),
      ),
    );
  }

  Widget _buildRouteControls(String target) {
    final saving = savingRoutePoints.contains(target);
    final clearing = clearingRoutes.contains(target);
    final busy = saving || clearing;
    return Row(
      children: [
        SizedBox(
          width: 5.w,
          child: Text(
            '$target Rotası',
            style: TextStyle(color: _bright, fontSize: 2.4.sp),
          ),
        ),
        SizedBox(width: 0.6.w),
        Expanded(
          child: SizedBox(
            height: 34.h,
            child: OutlinedButton.icon(
              onPressed: enabled && !busy
                  ? () => unawaited(onSaveRoutePoint(target))
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: _bright,
                disabledForegroundColor: _muted,
                side: const BorderSide(color: _borderC),
                padding: EdgeInsets.symmetric(horizontal: 0.6.w),
              ),
              icon: saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.subdirectory_arrow_left, size: 2.8.sp),
              label: Text(
                'Dönüş Noktası Ekle',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 2.1.sp),
              ),
            ),
          ),
        ),
        SizedBox(width: 0.5.w),
        IconButton(
          tooltip: '$target rotasını temizle',
          onPressed:
              enabled && !busy ? () => unawaited(onClearRoute(target)) : null,
          color: _danger,
          disabledColor: _muted,
          icon: clearing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline),
        ),
      ],
    );
  }

  String _resultText(String point, DemoPointSaveResult result) {
    final pose = result.pose;
    if (pose == null) return '$point kaydedildi';
    return '$point: x=${pose.x.toStringAsFixed(2)}, '
        'y=${pose.y.toStringAsFixed(2)}, '
        'θ=${pose.theta.toStringAsFixed(2)}';
  }
}

class _NodeListPanel extends StatelessWidget {
  final List<TaughtFieldNode> nodes;
  final bool canEdit;
  final bool canMoveToRobot;
  final void Function(TaughtFieldNode) onEdit;
  final void Function(TaughtFieldNode) onDelete;
  final void Function(TaughtFieldNode) onMoveToRobot;

  const _NodeListPanel({
    required this.nodes,
    required this.canEdit,
    required this.canMoveToRobot,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveToRobot,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
          child: Text(
            'Öğretilmiş düğümler (${nodes.length})',
            style: TextStyle(
              color: _bright,
              fontSize: 3.2.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Divider(height: 1, color: _borderC),
        Expanded(
          child: nodes.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(2.w),
                    child: Text(
                      'Henüz düğüm yok.\nRobotu noktaya götürüp oluşturun.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, fontSize: 2.8.sp),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(vertical: 0.5.h),
                  itemCount: nodes.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: _borderC),
                  itemBuilder: (context, index) {
                    final n = nodes[index];
                    return _NodeListTile(
                      node: n,
                      canEdit: canEdit,
                      canMoveToRobot: canMoveToRobot,
                      onEdit: () => onEdit(n),
                      onDelete: () => onDelete(n),
                      onMoveToRobot: () => onMoveToRobot(n),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _NodeListTile extends StatelessWidget {
  final TaughtFieldNode node;
  final bool canEdit;
  final bool canMoveToRobot;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveToRobot;

  const _NodeListTile({
    required this.node,
    required this.canEdit,
    required this.canMoveToRobot,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveToRobot,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 0.6.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 2.w,
                height: 2.w,
                decoration: BoxDecoration(
                  color: node.markerColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 1.w),
              Expanded(
                child: Text(
                  node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _bright,
                    fontSize: 3.2.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 0.2.h),
          Text(
            '${node.type.etiket} · '
            '(${node.pixelX.toStringAsFixed(0)}, ${node.pixelY.toStringAsFixed(0)})',
            style: TextStyle(color: _muted, fontSize: 2.5.sp),
          ),
          SizedBox(height: 0.4.h),
          Row(
            children: [
              _MiniAction(
                icon: Icons.edit_outlined,
                tooltip: 'Düzenle',
                onTap: canEdit ? onEdit : null,
              ),
              _MiniAction(
                icon: Icons.my_location,
                tooltip: 'Konumu robota taşı',
                onTap: canMoveToRobot ? onMoveToRobot : null,
              ),
              _MiniAction(
                icon: Icons.delete_outline,
                tooltip: 'Sil',
                color: _danger,
                onTap: canEdit ? onDelete : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  const _MiniAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: 5.w, height: 5.w),
      icon: Icon(
        icon,
        size: 4.sp,
        color: onTap == null ? const Color(0xFF555555) : (color ?? _bright),
      ),
    );
  }
}

class _HintBar extends StatelessWidget {
  final bool hasPreview;
  final bool insideMap;
  final bool hasRobot;
  final bool localized;
  final bool connected;
  final bool specContext;
  final int nodeCount;
  final int routeEligibleCount;

  const _HintBar({
    required this.hasPreview,
    required this.insideMap,
    required this.hasRobot,
    required this.localized,
    required this.connected,
    required this.specContext,
    required this.nodeCount,
    required this.routeEligibleCount,
  });

  @override
  Widget build(BuildContext context) {
    // Kopukken şerit yok; yalnız bağlı oturum durumları.
    if (!connected) return const SizedBox.shrink();

    final String text;
    final Color color;
    if (!hasPreview) {
      text = localized
          ? 'Lokalizasyon açık — harita önizlemesi bekleniyor…'
          : 'Haritalama sonrası veya lokalizasyon: Kayıtlı Haritalar → '
              'Haritayı Yükle, ya da mapping önizlemesi gelsin.';
      color = _warn;
    } else if (!hasRobot) {
      text = 'Robot pikseli bekleniyor (/map_preview/robot_pixel)…';
      color = _muted;
    } else if (!insideMap) {
      text = 'Robot harita dışında — düğüm oluşturulamaz.';
      color = _warn;
    } else {
      final ctx = localized
          ? 'Lokalizasyon'
          : (specContext ? 'Harita oturumu' : 'Önizleme');
      text = '$ctx · robot harita içinde — Yeni düğüm oluştur aktif'
          '${nodeCount > 0 ? ' · $nodeCount düğüm' : ''}'
          '${routeEligibleCount > 0 ? ' · $routeEligibleCount senaryoya uygun' : ''}';
      color = const Color(0xFF43A047);
    }

    return Container(
      width: double.infinity,
      color: _panelBg,
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
      child: Text(text, style: TextStyle(color: color, fontSize: 3.sp)),
    );
  }
}

class _NoMapPlaceholder extends StatelessWidget {
  final bool connected;
  final bool localized;

  const _NoMapPlaceholder({
    required this.connected,
    required this.localized,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0D0D0D),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hub_outlined, color: _muted, size: 12.sp),
              SizedBox(height: 1.2.h),
              Text(
                'Harita önizlemesi yok',
                style: TextStyle(
                  color: _bright,
                  fontSize: 4.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (connected) ...[
                SizedBox(height: 0.6.h),
                Text(
                  localized
                      ? 'Lokalizasyon açık — PNG karesi bekleniyor.'
                      : 'Önce Kayıtlı Haritalar’dan bir saha yükleyin '
                          'veya mapping önizlemesi gelsin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 3.2.sp),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NodeEditorValue {
  final String name;
  final FieldNodeRole role;
  final String stationId;
  final FieldLoadRule loadRule;
  final FieldApproachMode approachMode;
  final double yawRadians;
  final String metadataJson;

  const _NodeEditorValue({
    required this.name,
    required this.role,
    required this.stationId,
    required this.loadRule,
    required this.approachMode,
    required this.yawRadians,
    required this.metadataJson,
  });

  FieldNode toNode({required FieldPose2D pose, int? nodeId}) => FieldNode(
        nodeId: nodeId ?? FieldGraphId.next(),
        name: name,
        role: role,
        stationId: stationId,
        pose: pose,
        loadRule: loadRule,
        approachMode: approachMode,
        metadataJson: metadataJson,
      );
}

class _NodeEditorDialog extends StatefulWidget {
  final FieldNode? existing;
  final bool screenYaw;

  const _NodeEditorDialog({this.existing, required this.screenYaw});

  @override
  State<_NodeEditorDialog> createState() => _NodeEditorDialogState();
}

class _NodeEditorDialogState extends State<_NodeEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _stationId;
  late final TextEditingController _yawDegrees;
  late final TextEditingController _metadata;
  late FieldNodeRole _role;
  late FieldLoadRule _loadRule;
  late FieldApproachMode _approachMode;

  @override
  void initState() {
    super.initState();
    final node = widget.existing;
    _name = TextEditingController(text: node?.name ?? '');
    _stationId = TextEditingController(text: node?.stationId ?? '');
    _yawDegrees = TextEditingController(
      text: ((node?.pose.theta ?? 0) * 180 / math.pi).toStringAsFixed(1),
    );
    _metadata = TextEditingController(text: node?.metadataJson ?? '{}');
    _role = node?.role ?? FieldNodeRole.transit;
    _loadRule = node?.loadRule ?? FieldLoadRule.any;
    _approachMode = node?.approachMode ?? FieldApproachMode.navigate;
  }

  @override
  void dispose() {
    _name.dispose();
    _stationId.dispose();
    _yawDegrees.dispose();
    _metadata.dispose();
    super.dispose();
  }

  String? _metadataValidator(String? value) {
    try {
      final decoded = jsonDecode(value ?? '');
      if (decoded is! Map) return 'Metadata JSON object olmalıdır';
      return null;
    } catch (_) {
      return 'Geçerli JSON object girin';
    }
  }

  void _applyRoleDefaults(FieldNodeRole role) {
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
        case FieldNodeRole.gateQ5:
          _loadRule = FieldLoadRule.any;
          _approachMode = FieldApproachMode.trigger;
          break;
        case FieldNodeRole.qrTrigger:
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final degrees = double.parse(_yawDegrees.text.trim());
    Navigator.pop(
      context,
      _NodeEditorValue(
        name: _name.text.trim(),
        role: _role,
        stationId: _stationId.text.trim(),
        loadRule: _loadRule,
        approachMode: _approachMode,
        yawRadians: degrees * math.pi / 180,
        metadataJson: _metadata.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
            widget.existing == null ? 'Yeni saha düğümü' : 'Düğümü düzenle'),
        content: SizedBox(
          width: 520,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Düğüm adı'),
                    validator: NodeNameRules.validate,
                  ),
                  DropdownButtonFormField<FieldNodeRole>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Rol'),
                    items: [
                      for (final value in FieldNodeRole.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(value.wireName),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) _applyRoleDefaults(value);
                    },
                  ),
                  TextFormField(
                    controller: _stationId,
                    decoration: const InputDecoration(
                      labelText: 'İstasyon kimliği (station_id)',
                    ),
                  ),
                  DropdownButtonFormField<FieldLoadRule>(
                    initialValue: _loadRule,
                    decoration: const InputDecoration(labelText: 'Yük kuralı'),
                    items: [
                      for (final value in FieldLoadRule.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(value.wireName),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _loadRule = value);
                    },
                  ),
                  DropdownButtonFormField<FieldApproachMode>(
                    initialValue: _approachMode,
                    decoration:
                        const InputDecoration(labelText: 'Yaklaşma modu'),
                    items: [
                      for (final value in FieldApproachMode.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(value.wireName),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _approachMode = value);
                    },
                  ),
                  TextFormField(
                    controller: _yawDegrees,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(
                      labelText: widget.screenYaw
                          ? 'Ekran yönü (derece)'
                          : 'Map yaw (derece)',
                      helperText: widget.screenYaw
                          ? 'ROS’a screen_yaw olarak radyan gönderilir'
                          : 'ROS pose.theta alanına radyan yazılır',
                    ),
                    validator: (value) {
                      final parsed = double.tryParse(value?.trim() ?? '');
                      if (parsed == null || !parsed.isFinite) {
                        return 'Geçerli açı girin';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _metadata,
                    minLines: 1,
                    maxLines: 4,
                    decoration:
                        const InputDecoration(labelText: 'metadata_json'),
                    validator: _metadataValidator,
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
