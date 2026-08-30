import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'models/field_graph_models.dart';
import 'models/gcs_field_graph_model.dart';
import 'models/gcs_mapping_model.dart';
import 'services/agv_service.dart';
import 'services/ros_mapping_contract.dart';

const _bg = Color(0xFF121212);
const _panelBg = Color(0xFF1A1A1A);
const _borderC = Color(0xFF333333);
const _muted = Color(0xFF9E9E9E);
const _bright = Color(0xFFE0E0E0);
const _success = Color(0xFF43A047);
const _accent = Color(0xFF42A5F5);
const _danger = Color(0xFFE53935);
const _warning = Color(0xFFFFA726);

class SavedFieldsPage extends StatefulWidget {
  const SavedFieldsPage({super.key});

  @override
  State<SavedFieldsPage> createState() => _SavedFieldsPageState();
}

class _SavedFieldsPageState extends State<SavedFieldsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_refresh()));
  }

  Future<void> _refresh() async {
    final graph = context.read<GcsFieldGraphModel>();
    if (!graph.connected) {
      _toast('ROS bağlı değil — saha listesi alınamadı');
      return;
    }
    await graph.refreshFields();
  }

  String _userError(Object error) =>
      error.toString().replaceFirst('Bad state: ', '').trim();

  void _toast(String message) {
    if (!mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  Future<void> _loadField(FieldInfo field) async {
    final mapping = context.read<GcsMappingModel>();
    if (!field.localizationReady ||
        mapping.localizationInFlight ||
        mapping.mappingActive) {
      return;
    }
    if (!AgvService.ros.state.value.isConnected) {
      _toast('ROS hazır değil veya servis yanıt vermedi');
      return;
    }
    mapping.beginLocalization(field.fieldName);
    try {
      final response =
          await AgvService.startLocalization(fieldName: field.fieldName);
      if (!mounted) return;
      if (!RosServiceResponse.localizationStartAccepted(response)) {
        mapping.endLocalizationFlight();
        _toast(
          'Lokalizasyon başlatılamadı: '
          '${RosServiceResponse.failureMessage(response)}',
        );
        return;
      }
      mapping.acknowledgeLocalizationStart(field.fieldName);
      _toast('Lokalizasyon başlatılıyor (${field.fieldName})');
    } catch (error) {
      if (!mounted) return;
      mapping.endLocalizationFlight();
      _toast('Lokalizasyonu Başlat: ${_userError(error)}');
    }
  }

  Future<void> _stopLocalization() async {
    final mapping = context.read<GcsMappingModel>();
    if (mapping.localizationInFlight ||
        !AgvService.ros.state.value.isConnected) {
      return;
    }
    mapping.beginLocalization();
    try {
      final response = await AgvService.stopLocalization();
      if (!mounted) return;
      if (!RosServiceResponse.localizationStopSucceeded(response)) {
        mapping.endLocalizationFlight();
        _toast(
          'Lokalizasyon durdurulamadı: '
          '${RosServiceResponse.failureMessage(response)}',
        );
        return;
      }
      mapping.acknowledgeLocalizationStop();
      _toast('Lokalizasyon durduruluyor');
    } catch (error) {
      if (!mounted) return;
      mapping.endLocalizationFlight();
      _toast('Lokalizasyon durdur: ${_userError(error)}');
    }
  }

  Future<void> _openGraph(FieldInfo field, String routeName) async {
    final graph = context.read<GcsFieldGraphModel>();
    await graph.selectField(field.fieldName);
    if (!mounted) return;
    if (graph.graphError != null) {
      _toast(graph.graphError!);
      return;
    }
    await Navigator.pushNamed(context, routeName);
  }

  Future<void> _archive(FieldInfo field) async {
    if (field.active) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Sahayı arşivle'),
            content: Text(
              '${field.fieldName} aktif listeden kaldırılacak. Bu işlem gerçek silme değildir.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Arşivle'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    final graph = context.read<GcsFieldGraphModel>();
    try {
      await graph.selectField(field.fieldName);
      final message = await graph.archiveSelected();
      if (mounted) _toast(message);
    } catch (error) {
      _toast('Arşivleme başarısız: ${_userError(error)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapping = context.watch<GcsMappingModel>();
    final graph = context.watch<GcsFieldGraphModel>();
    final localized = mapping.activeLocalizedField;
    final active = graph.activeFresh && graph.activeField?.active == true
        ? graph.activeField
        : null;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _panelBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Kayıtlı Haritalar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 5.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (localized != null)
            TextButton(
              onPressed: mapping.localizationInFlight
                  ? null
                  : () => unawaited(_stopLocalization()),
              child: Text(
                'Lokalizasyonu Durdur',
                style: TextStyle(color: _danger, fontSize: 3.sp),
              ),
            ),
          IconButton(
            tooltip: 'Yenile',
            onPressed: graph.fieldsLoading ? null : () => unawaited(_refresh()),
            icon: graph.fieldsLoading
                ? SizedBox(
                    width: 4.w,
                    height: 4.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.refresh, color: _bright, size: 5.sp),
          ),
          SizedBox(width: 2.w),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (active != null)
            Container(
              color: const Color(0xFF1E2A1E),
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
              child: Text(
                'Aktif saha: ${active.fieldName} · sürüm ${active.packageVersion} · hash ${_shortHash(active.packageHash)}',
                style: TextStyle(color: _success, fontSize: 3.sp),
              ),
            ),
          if (!graph.activeFresh && graph.connected)
            const _InfoBar(
              text: 'Aktif saha bilgisi eşitleniyor…',
              color: _warning,
            ),
          if (graph.fieldsError != null)
            _InfoBar(text: graph.fieldsError!, color: _danger),
          if (localized != null)
            _InfoBar(
              text:
                  'Aktif lokalizasyon: $localized · ${mapping.localizationStatus?.etiket ?? 'durum bekleniyor'}',
              color: _success,
            ),
          Expanded(child: _buildBody(graph, mapping)),
        ],
      ),
    );
  }

  Widget _buildBody(
    GcsFieldGraphModel graph,
    GcsMappingModel mapping,
  ) {
    if (!graph.connected && graph.fields.isEmpty) {
      return const _EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'ROS bağlı değil',
        subtitle: 'Saha bilgileri güncel değil; bağlantıyı yeniden kurun.',
        actionLabel: null,
        onAction: null,
      );
    }
    if (graph.fieldsLoading && graph.fields.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (graph.fieldsError != null && graph.fields.isEmpty) {
      return _EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Saha listesi servisi kullanılamıyor',
        subtitle: graph.fieldsError!,
        actionLabel: 'Tekrar Dene',
        onAction: () => unawaited(_refresh()),
      );
    }
    if (graph.fields.isEmpty) {
      return _EmptyState(
        icon: Icons.map_outlined,
        title: 'Kayıtlı harita yok',
        subtitle:
            'Haritalamayı bitirip kaydettiğiniz sahalar burada listelenir.',
        actionLabel: 'Yenile',
        onAction: () => unawaited(_refresh()),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: GridView.builder(
        padding: EdgeInsets.all(3.w),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 2.h,
          crossAxisSpacing: 2.w,
          childAspectRatio: 1.05,
        ),
        itemCount: graph.fields.length,
        itemBuilder: (context, index) {
          final field = graph.fields[index];
          return _SavedFieldCard(
            field: field,
            localized: mapping.activeLocalizedField == field.fieldName,
            busy: mapping.localizationInFlight || graph.busy,
            onLocalization: !field.localizationReady ||
                    mapping.localizationInFlight ||
                    mapping.mappingActive
                ? null
                : () => unawaited(_loadField(field)),
            onNodes: () => unawaited(_openGraph(field, 'node-teach-page')),
            onRoute: () => unawaited(_openGraph(field, 'route-edit-page')),
            onArchive: field.active ? null : () => unawaited(_archive(field)),
          );
        },
      ),
    );
  }
}

class _InfoBar extends StatelessWidget {
  final String text;
  final Color color;

  const _InfoBar({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        color: color.withAlpha(24),
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.7.h),
        child: Text(text, style: TextStyle(color: color, fontSize: 3.sp)),
      );
}

class _SavedFieldCard extends StatelessWidget {
  final FieldInfo field;
  final bool localized;
  final bool busy;
  final VoidCallback? onLocalization;
  final VoidCallback onNodes;
  final VoidCallback onRoute;
  final VoidCallback? onArchive;

  const _SavedFieldCard({
    required this.field,
    required this.localized,
    required this.busy,
    required this.onLocalization,
    required this.onNodes,
    required this.onRoute,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final faulty = !field.mapReady || !field.initialPoseReady;
    final statusColor = faulty ? _danger : _success;
    return Container(
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(
          color: field.active ? _success : _borderC,
          width: field.active ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(2.r),
      ),
      padding: EdgeInsets.all(2.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _Thumbnail(hint: field.previewPng)),
          SizedBox(height: 0.7.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  field.fieldName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _bright,
                    fontSize: 3.8.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (field.active)
                Text('AKTİF',
                    style: TextStyle(color: _success, fontSize: 2.5.sp)),
            ],
          ),
          Text(
            '${field.routeReady ? 'Rota hazır' : 'Rota eksik'} · '
            '${field.validationPassed ? 'Doğrulandı' : 'Doğrulanmadı'} · '
            '${field.packageVersion.isEmpty ? 'sürüm yok' : field.packageVersion}',
            style: TextStyle(color: statusColor, fontSize: 2.5.sp),
          ),
          Text(
            field.packageHash.isEmpty
                ? (field.message.isEmpty ? 'Hash yok' : field.message)
                : 'Hash ${_shortHash(field.packageHash)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _muted, fontSize: 2.3.sp),
          ),
          SizedBox(height: 0.5.h),
          Wrap(
            spacing: 0.7.w,
            runSpacing: 0.4.h,
            children: [
              _CardAction(
                label: localized ? 'Lokalizasyon Aktif' : 'Lokalizasyon',
                onPressed: onLocalization,
              ),
              _CardAction(label: 'Düğümler', onPressed: busy ? null : onNodes),
              _CardAction(label: 'Rota', onPressed: busy ? null : onRoute),
              if (!field.active)
                _CardAction(
                  label: 'Arşivle',
                  color: _danger,
                  onPressed: busy ? null : onArchive,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  const _CardAction({
    required this.label,
    required this.onPressed,
    this.color = _accent,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          padding: EdgeInsets.symmetric(horizontal: 1.2.w),
          minimumSize: Size(0, 30.h),
          side: BorderSide(color: onPressed == null ? _borderC : color),
        ),
        child: Text(label, style: TextStyle(fontSize: 2.4.sp)),
      );
}

class _Thumbnail extends StatelessWidget {
  final String? hint;
  const _Thumbnail({this.hint});

  @override
  Widget build(BuildContext context) {
    final value = hint?.trim() ?? '';
    return Container(
      color: const Color(0xFF101010),
      alignment: Alignment.center,
      // preview_png Orange Pi üzerindeki tanı yoludur; yerel dosya değildir.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, color: _muted, size: 7.sp),
          SizedBox(height: 0.5.h),
          Text(
            value.isEmpty ? 'Önizleme yok' : 'Önizleme robotta',
            style: TextStyle(color: _muted, fontSize: 2.5.sp),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _muted, size: 10.sp),
            SizedBox(height: 1.h),
            Text(title, style: TextStyle(color: _bright, fontSize: 4.sp)),
            SizedBox(height: 0.5.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 3.sp),
            ),
            if (actionLabel != null) ...[
              SizedBox(height: 1.h),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      );
}

String _shortHash(String value) =>
    value.length <= 12 ? value : '${value.substring(0, 12)}…';
