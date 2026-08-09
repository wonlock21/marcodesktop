import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'data_model.dart';
import 'models/gcs_mapping_model.dart';
import 'models/gcs_node_model.dart';
import 'scenerio_page.dart';
import 'services/agv_service.dart';
import 'services/ros_mapping_contract.dart';
import 'widgets/map_preview_stage.dart';
import 'widgets/node_editor_dialog.dart';

const _bg = Color(0xFF121212);
const _panelBg = Color(0xFF1A1A1A);
const _borderC = Color(0xFF333333);
const _muted = Color(0xFF9E9E9E);
const _bright = Color(0xFFE0E0E0);
const _warn = Color(0xFFB7791F);
const _accent = Color(0xFF42A5F5);
const _danger = Color(0xFFE53935);

/// Düğüm öğretme: yalnızca robot konumuna (pixel X/Y) basılır.
class NodeTeachPage extends StatelessWidget {
  const NodeTeachPage({super.key});

  String _fieldName(GcsMappingModel mapping) {
    if (mapping.activeLocalizedField?.trim().isNotEmpty == true) {
      return mapping.activeLocalizedField!.trim();
    }
    return mapping.fieldName.trim();
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _softSyncAdd(BuildContext context, TaughtFieldNode node) async {
    if (!AgvService.ros.state.value.isConnected) return;
    try {
      await AgvService.addStation(
        name: node.name,
        type: node.type.wireName,
        pixelX: node.pixelX,
        pixelY: node.pixelY,
        screenYaw: node.screenYaw,
        fieldName: node.fieldName,
      );
    } catch (_) {
      if (!context.mounted) return;
      _toast(context, 'Yerel kaydedildi — ROS /stations henüz hazır değil');
    }
  }

  Future<void> _softSyncUpdate(TaughtFieldNode node) async {
    if (!AgvService.ros.state.value.isConnected) return;
    try {
      await AgvService.updateStation(
        name: node.name,
        type: node.type.wireName,
        pixelX: node.pixelX,
        pixelY: node.pixelY,
        screenYaw: node.screenYaw,
        fieldName: node.fieldName,
      );
    } catch (_) {
      /* yerel öncelikli */
    }
  }

  Future<void> _softSyncDelete(String name) async {
    if (!AgvService.ros.state.value.isConnected) return;
    try {
      await AgvService.deleteStation(name: name);
    } catch (_) {
      /* yerel öncelikli */
    }
  }

  Future<void> _createNode(BuildContext context) async {
    final mapping = context.read<GcsMappingModel>();
    final nodes = context.read<GcsNodeModel>();
    final robot = mapping.robotPixel;
    if (robot == null || !robot.insideMap || !mapping.hasPreviewPng) return;

    final draft = await NodeEditorDialog.show(
      context,
      title: 'Yeni düğüm oluştur',
      validateName: nodes.validateNewName,
    );
    if (draft == null || !context.mounted) return;

    final added = nodes.addNode(
      name: draft.name,
      type: draft.type,
      pixelX: robot.pixelX,
      pixelY: robot.pixelY,
      screenYaw: robot.screenYaw,
      fieldName: _fieldName(mapping),
    );
    if (added == null) {
      _toast(context, 'Düğüm eklenemedi — ad geçersiz veya tekrarlı');
      return;
    }
    _toast(
      context,
      'Düğüm eklendi: ${draft.name} '
      '(${robot.pixelX.toStringAsFixed(0)}, ${robot.pixelY.toStringAsFixed(0)})',
    );
    unawaited(_softSyncAdd(context, added));
  }

  Future<void> _editNode(BuildContext context, TaughtFieldNode node) async {
    final nodes = context.read<GcsNodeModel>();
    final draft = await NodeEditorDialog.show(
      context,
      title: 'Düğümü düzenle',
      initialName: node.name,
      initialType: node.type,
      validateName: (v) => nodes.validateName(v, exceptId: node.id),
    );
    if (draft == null || !context.mounted) return;
    final ok = nodes.updateMeta(
      id: node.id,
      name: draft.name,
      type: draft.type,
    );
    if (!ok) {
      _toast(context, 'Güncellenemedi — ad geçersiz/tekrarlı');
      return;
    }
    _toast(context, 'Güncellendi: ${draft.name}');
    final updated = nodes.byId(node.id);
    if (updated != null) unawaited(_softSyncUpdate(updated));
  }

  Future<void> _deleteNode(BuildContext context, TaughtFieldNode node) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panelBg,
        title: Text(
          'Düğümü sil',
          style: TextStyle(color: _bright, fontSize: 4.5.sp),
        ),
        content: Text(
          '"${node.name}" silinsin mi?',
          style: TextStyle(color: _muted, fontSize: 3.2.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal', style: TextStyle(color: _muted, fontSize: 3.sp)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sil', style: TextStyle(color: _danger, fontSize: 3.sp)),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final name = node.name;
    context.read<GcsNodeModel>().remove(node.id);
    _toast(context, 'Silindi: $name');
    unawaited(_softSyncDelete(name));
  }

  void _moveToRobot(BuildContext context, TaughtFieldNode node) {
    final mapping = context.read<GcsMappingModel>();
    final robot = mapping.robotPixel;
    if (robot == null || !robot.insideMap) {
      _toast(context, 'Robot harita içinde değil — konum güncellenemedi');
      return;
    }
    final ok = context.read<GcsNodeModel>().moveToRobot(
          id: node.id,
          pixelX: robot.pixelX,
          pixelY: robot.pixelY,
          screenYaw: robot.screenYaw,
        );
    if (!ok) {
      _toast(context, 'Konum güncellenemedi');
      return;
    }
    _toast(context, '${node.name} konumu robota taşındı');
    final updated = context.read<GcsNodeModel>().byId(node.id);
    if (updated != null) unawaited(_softSyncUpdate(updated));
  }

  /// F.5: haritalama sırasında veya lokalizasyon açıkken öğretme bağlamı.
  bool _specTeachContext(GcsMappingModel mapping) {
    if (!mapping.isConnected || !mapping.hasPreviewPng) return false;
    if (mapping.activeLocalizedField != null) return true;
    final status = mapping.liveMappingStatus;
    return status == MappingStatus.mapping || status == MappingStatus.idle;
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
    final nodes = context.watch<GcsNodeModel>();
    final robot = mapping.robotPixel;
    final insideMap = robot?.insideMap == true;
    final specContext = _specTeachContext(mapping);
    final canCreate =
        mapping.isConnected && mapping.hasPreviewPng && insideMap;
    final fieldHint = _fieldName(mapping).isEmpty ? null : _fieldName(mapping);

    final markers = nodes.nodes
        .map(
          (n) => MapPreviewNodeMarker(
            label: n.name,
            pixelX: n.pixelX,
            pixelY: n.pixelY,
            color: n.markerColor,
          ),
        )
        .toList(growable: false);

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
                          robotPixel: mapping.robotPixel,
                          awaitingFresh: mapping.awaitingFreshPreview,
                          sourceLabel: mapping.previewSourceLabel,
                          nodeMarkers: markers,
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
                      Expanded(
                        child: _NodeListPanel(
                          nodes: nodes.nodes,
                          canMoveToRobot: insideMap,
                          onEdit: (n) => _editNode(context, n),
                          onDelete: (n) => _deleteNode(context, n),
                          onMoveToRobot: (n) => _moveToRobot(context, n),
                        ),
                      ),
                      const Divider(height: 1, color: _borderC),
                      Padding(
                        padding: EdgeInsets.all(2.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (mapping.isConnected && !canCreate)
                              Padding(
                                padding: EdgeInsets.only(bottom: 6.h),
                                child: Text(
                                  !mapping.hasPreviewPng
                                      ? 'Harita önizlemesi yok'
                                      : robot == null
                                          ? 'Robot konumu bekleniyor…'
                                          : 'Robot harita dışında',
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
                                    ? () => _createNode(context)
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
                                  'Yeni düğüm oluştur',
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

class _NodeListPanel extends StatelessWidget {
  final List<TaughtFieldNode> nodes;
  final bool canMoveToRobot;
  final void Function(TaughtFieldNode) onEdit;
  final void Function(TaughtFieldNode) onDelete;
  final void Function(TaughtFieldNode) onMoveToRobot;

  const _NodeListPanel({
    required this.nodes,
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
  final bool canMoveToRobot;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveToRobot;

  const _NodeListTile({
    required this.node,
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
                onTap: onEdit,
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
                onTap: onDelete,
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
