import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'models/gcs_mapping_model.dart';
import 'models/gcs_node_model.dart';
import 'models/gcs_route_model.dart';
import 'services/ros_mapping_contract.dart';
import 'widgets/map_preview_stage.dart';

const _bg = Color(0xFF121212);
const _panelBg = Color(0xFF1A1A1A);
const _borderC = Color(0xFF333333);
const _muted = Color(0xFF9E9E9E);
const _bright = Color(0xFFE0E0E0);
const _accent = Color(0xFF42A5F5);
const _danger = Color(0xFFE53935);

/// H.1/H.2 — öğretilmiş düğümlerden sıralı rota; yerel draft + `/routes/*` stub.
class RouteEditPage extends StatelessWidget {
  const RouteEditPage({super.key});

  static const _backendReason =
      'Rota kaydetme/listeleme için ROS backend servisi yok. '
      'Görev senaryosunda gerçek graph düğümlerini doğrudan seçin.';

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _selectByLabel(BuildContext context, String label) {
    final nodes = context.read<GcsNodeModel>();
    final route = context.read<GcsRouteModel>();
    TaughtFieldNode? match;
    for (final n in nodes.nodes) {
      if (n.name == label) {
        match = n;
        break;
      }
    }
    if (match == null) return;
    route.appendNode(match.id);
  }

  @override
  Widget build(BuildContext context) {
    final mapping = context.watch<GcsMappingModel>();
    final nodes = context.watch<GcsNodeModel>();
    final route = context.watch<GcsRouteModel>();
    final selected = route.selectedNodes(nodes);
    final polyline =
        selected.map((n) => Offset(n.pixelX, n.pixelY)).toList(growable: false);

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
          'Rota',
          style: TextStyle(
            color: Colors.white,
            fontSize: 5.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _toast(context, _backendReason),
            child: Text(
              'Backend yok',
              style: TextStyle(
                color: route.hasSelection ? _accent : _muted,
                fontSize: 3.sp,
              ),
            ),
          ),
          SizedBox(width: 1.w),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SelectionStrip(
            selected: selected,
            onUndo: route.hasSelection ? route.undoLast : null,
            onClear: route.hasSelection ? route.clearSelection : null,
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
                          robotPixel: mapping.visibleRobotPixel,
                          awaitingFresh: mapping.awaitingFreshPreview,
                          sourceLabel: mapping.previewSourceLabel,
                          nodeMarkers: markers,
                          routePolylinePixels: polyline,
                          onNodeMarkerTap: (label) =>
                              _selectByLabel(context, label),
                        )
                      : Center(
                          child: Padding(
                            padding: EdgeInsets.all(4.w),
                            child: Text(
                              'Harita önizlemesi yok.\n'
                              'Düğümler öğrettikten / lokalizasyon sonrası rota çizin.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _muted, fontSize: 3.2.sp),
                            ),
                          ),
                        ),
                ),
                Container(
                  width: 34.w,
                  decoration: const BoxDecoration(
                    color: _panelBg,
                    border: Border(left: BorderSide(color: _borderC)),
                  ),
                  child: _SidePanel(
                    nodes: nodes.nodes,
                    saved: route.savedRoutes,
                    onPickNode: (n) => route.appendNode(n.id),
                    onLoadSaved: route.loadSelection,
                    onDeleteSaved: (_) => _toast(context, _backendReason),
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

class _SelectionStrip extends StatelessWidget {
  final List<TaughtFieldNode> selected;
  final VoidCallback? onUndo;
  final VoidCallback? onClear;

  const _SelectionStrip({
    required this.selected,
    required this.onUndo,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _panelBg,
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.8.h),
      child: Row(
        children: [
          Text(
            'Sıra:',
            style: TextStyle(color: _muted, fontSize: 2.8.sp),
          ),
          SizedBox(width: 1.5.w),
          Expanded(
            child: selected.isEmpty
                ? Text(
                    'Düğüm seçin (harita marker veya sağ liste)',
                    style: TextStyle(color: _muted, fontSize: 2.8.sp),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < selected.length; i++) ...[
                          if (i > 0)
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 0.6.w),
                              child: Icon(Icons.arrow_forward,
                                  size: 3.sp, color: _muted),
                            ),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            backgroundColor:
                                selected[i].markerColor.withAlpha(40),
                            side: BorderSide(color: selected[i].markerColor),
                            label: Text(
                              '${i + 1}.${selected[i].name}',
                              style: TextStyle(
                                color: _bright,
                                fontSize: 2.6.sp,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          IconButton(
            tooltip: 'Geri al',
            onPressed: onUndo,
            icon: Icon(Icons.undo,
                color: onUndo == null ? _muted : _bright, size: 4.5.sp),
          ),
          IconButton(
            tooltip: 'Temizle',
            onPressed: onClear,
            icon: Icon(Icons.clear_all,
                color: onClear == null ? _muted : _danger, size: 4.5.sp),
          ),
        ],
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  final List<TaughtFieldNode> nodes;
  final List<SavedRouteDraft> saved;
  final void Function(TaughtFieldNode) onPickNode;
  final void Function(SavedRouteDraft) onLoadSaved;
  final void Function(SavedRouteDraft) onDeleteSaved;

  const _SidePanel({
    required this.nodes,
    required this.saved,
    required this.onPickNode,
    required this.onLoadSaved,
    required this.onDeleteSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.all(2.w),
          child: Text(
            'Düğümler (GcsNodeModel)',
            style: TextStyle(
              color: _bright,
              fontSize: 3.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Divider(height: 1, color: _borderC),
        Expanded(
          flex: 3,
          child: nodes.isEmpty
              ? Center(
                  child: Text(
                    'Öğretilmiş düğüm yok.\nDÜĞÜMLER sayfasından ekleyin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 2.6.sp),
                  ),
                )
              : ListView.builder(
                  itemCount: nodes.length,
                  itemBuilder: (context, i) {
                    final n = nodes[i];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 1.2.w,
                        backgroundColor: n.markerColor,
                      ),
                      title: Text(
                        n.name,
                        style: TextStyle(color: _bright, fontSize: 3.sp),
                      ),
                      subtitle: Text(
                        n.type.etiket,
                        style: TextStyle(color: _muted, fontSize: 2.4.sp),
                      ),
                      onTap: () => onPickNode(n),
                    );
                  },
                ),
        ),
        const Divider(height: 1, color: _borderC),
        Padding(
          padding: EdgeInsets.all(2.w),
          child: Text(
            'Kayıtlı rotalar (${saved.length})',
            style: TextStyle(
              color: _bright,
              fontSize: 3.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: saved.isEmpty
              ? Center(
                  child: Text(
                    'Henüz kayıt yok',
                    style: TextStyle(color: _muted, fontSize: 2.6.sp),
                  ),
                )
              : ListView.builder(
                  itemCount: saved.length,
                  itemBuilder: (context, i) {
                    final d = saved[i];
                    return ListTile(
                      dense: true,
                      title: Text(
                        d.name,
                        style: TextStyle(color: _bright, fontSize: 2.8.sp),
                      ),
                      subtitle: Text(
                        d.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _muted, fontSize: 2.3.sp),
                      ),
                      onTap: () => onLoadSaved(d),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: _danger, size: 4.sp),
                        onPressed: () => onDeleteSaved(d),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
