import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'models/gcs_mapping_model.dart';
import 'services/agv_service.dart';
import 'services/ros_mapping_contract.dart';

const _bg = Color(0xFF121212);
const _panelBg = Color(0xFF1A1A1A);
const _borderC = Color(0xFF333333);
const _muted = Color(0xFF9E9E9E);
const _bright = Color(0xFFE0E0E0);
const _success = Color(0xFF43A047);
const _danger = Color(0xFFE53935);

/// E.2 — Kayıtlı saha haritaları (`/fields/list`).
class SavedFieldsPage extends StatefulWidget {
  const SavedFieldsPage({super.key});

  @override
  State<SavedFieldsPage> createState() => _SavedFieldsPageState();
}

class _SavedFieldsPageState extends State<SavedFieldsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    final mapping = context.read<GcsMappingModel>();
    if (!AgvService.ros.state.value.isConnected) {
      mapping.applyFieldsListError('ROS bağlı değil — saha listesi alınamadı');
      return;
    }
    mapping.beginFieldsListLoad();
    try {
      final response = await AgvService.listFields();
      if (!mounted) return;
      if (!RosServiceResponse.fieldsListSucceeded(response)) {
        mapping
            .applyFieldsListError(RosServiceResponse.failureMessage(response));
        return;
      }
      mapping.applyFieldsList(SavedFieldInfo.fromListFieldsResponse(response));
    } catch (error) {
      if (!mounted) return;
      mapping.applyFieldsListError(_userError(error));
    }
  }

  String _userError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('bagli degil') ||
        text.contains('bağlı değil') ||
        text.contains('not connected') ||
        text.contains('timeout') ||
        text.contains('zaman asim') ||
        text.contains('servis') ||
        text.contains('service')) {
      return 'ROS hazır değil veya servis yanıt vermedi';
    }
    return RosMappingErrors.toUserMessage(error.toString());
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _loadField(SavedFieldInfo field) async {
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
    mapping.beginLocalization(field.name);
    try {
      final response =
          await AgvService.startLocalization(fieldName: field.name);
      if (!mounted) return;
      final ok = RosServiceResponse.localizationStartAccepted(response);
      final msg = response['message']?.toString().trim() ?? '';
      if (!ok) {
        mapping.endLocalizationFlight();
        _toast(
          'Harita yüklenemedi: '
          '${RosServiceResponse.failureMessage(response)}',
        );
        return;
      }
      mapping.acknowledgeLocalizationStart(field.name);
      _toast(
        'Lokalizasyon başlatılıyor (${field.name})'
        '${msg.isEmpty ? '' : ': ${RosMappingErrors.toUserMessage(msg)}'}'
        ' — LOCALIZING durumu bekleniyor',
      );
    } catch (error) {
      if (!mounted) return;
      mapping.endLocalizationFlight();
      _toast('Haritayı Yükle: ${_userError(error)}');
    }
  }

  Future<void> _stopLocalization() async {
    final mapping = context.read<GcsMappingModel>();
    if (mapping.localizationInFlight) return;
    if (!AgvService.ros.state.value.isConnected) {
      _toast('ROS hazır değil veya servis yanıt vermedi');
      return;
    }
    mapping.beginLocalization();
    try {
      final response = await AgvService.stopLocalization();
      if (!mounted) return;
      final ok = RosServiceResponse.localizationStopSucceeded(response);
      final msg = response['message']?.toString().trim() ?? '';
      if (!ok) {
        mapping.endLocalizationFlight();
        _toast(
          'Lokalizasyon durdurulamadı: '
          '${RosServiceResponse.failureMessage(response)}',
        );
        return;
      }
      mapping.acknowledgeLocalizationStop();
      _toast(
        'Lokalizasyon durduruluyor'
        '${msg.isEmpty ? '' : ': ${RosMappingErrors.toUserMessage(msg)}'}',
      );
    } catch (error) {
      if (!mounted) return;
      mapping.endLocalizationFlight();
      _toast('Lokalizasyon durdur: ${_userError(error)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapping = context.watch<GcsMappingModel>();
    final active = mapping.activeLocalizedField;

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
          if (active != null)
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
            onPressed:
                mapping.fieldsListLoading ? null : () => unawaited(_refresh()),
            icon: mapping.fieldsListLoading
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
                'Aktif lokalizasyon: $active · ${mapping.localizationStatus?.etiket ?? 'durum bekleniyor'}',
                style: TextStyle(color: _success, fontSize: 3.sp),
              ),
            ),
          Expanded(child: _buildBody(mapping)),
        ],
      ),
    );
  }

  Widget _buildBody(GcsMappingModel mapping) {
    if (mapping.fieldsListLoading && mapping.savedFields.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = mapping.fieldsListError;
    if (error != null && mapping.savedFields.isEmpty) {
      return _EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Liste alınamadı',
        subtitle: error,
        actionLabel: 'Tekrar Dene',
        onAction: () => unawaited(_refresh()),
      );
    }

    if (mapping.savedFields.isEmpty) {
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
          childAspectRatio: 1.15,
        ),
        itemCount: mapping.savedFields.length,
        itemBuilder: (context, index) {
          final field = mapping.savedFields[index];
          final isActive = mapping.activeLocalizedField == field.name;
          return _SavedFieldCard(
            field: field,
            isActive: isActive,
            busy: mapping.localizationInFlight,
            onLoad: !field.localizationReady ||
                    mapping.localizationInFlight ||
                    mapping.mappingActive
                ? null
                : () => unawaited(_loadField(field)),
          );
        },
      ),
    );
  }
}

class _SavedFieldCard extends StatelessWidget {
  final SavedFieldInfo field;
  final bool isActive;
  final bool busy;
  final VoidCallback? onLoad;

  const _SavedFieldCard({
    required this.field,
    required this.isActive,
    required this.busy,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    final ready = field.localizationReady;
    final statusColor = field.isFaulty
        ? _danger
        : ready
            ? _success
            : _muted;
    final statusLabel = ready ? 'Lokalizasyona Hazır' : 'Hazır Değil';

    return Container(
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(
          color: isActive ? _success : _borderC,
          width: isActive ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(2.r),
      ),
      padding: EdgeInsets.all(2.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _Thumbnail(hint: field.thumbnailHint)),
          SizedBox(height: 0.8.h),
          Text(
            field.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _bright,
              fontSize: 4.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 0.3.h),
          Row(
            children: [
              Container(
                width: 1.2.w,
                height: 1.2.w,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 1.w),
              Text(
                statusLabel,
                style: TextStyle(color: statusColor, fontSize: 3.sp),
              ),
              const Spacer(),
              Text(
                field.createdAt?.trim().isNotEmpty == true
                    ? field.createdAt!
                    : 'Tarih yok',
                style: TextStyle(color: _muted, fontSize: 2.8.sp),
              ),
            ],
          ),
          SizedBox(height: 0.6.h),
          SizedBox(
            height: 3.2.h,
            child: TextButton(
              onPressed: onLoad,
              style: TextButton.styleFrom(
                backgroundColor: isActive
                    ? const Color(0xFF1E3A1E)
                    : const Color(0xFF2A2A2A),
                foregroundColor: onLoad == null ? _muted : _bright,
                disabledForegroundColor: _muted,
                side: BorderSide(color: isActive ? _success : _borderC),
                padding: EdgeInsets.zero,
              ),
              child: busy && isActive
                  ? SizedBox(
                      width: 3.w,
                      height: 3.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      isActive ? 'Yüklü' : 'Haritayı Yükle',
                      style: TextStyle(fontSize: 2.8.sp),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? hint;

  const _Thumbnail({this.hint});

  @override
  Widget build(BuildContext context) {
    final bytes = _tryDecode(hint);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _bg,
        border: Border.all(color: _borderC),
        borderRadius: BorderRadius.circular(1.5.r),
      ),
      child: bytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(1.5.r),
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _placeholder(),
              ),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, color: _muted, size: 8.sp),
          SizedBox(height: 0.5.h),
          Text(
            'Önizleme yok',
            style: TextStyle(color: _muted, fontSize: 2.8.sp),
          ),
        ],
      ),
    );
  }

  static Uint8List? _tryDecode(String? hint) {
    if (hint == null) return null;
    final trimmed = hint.trim();
    if (trimmed.isEmpty || trimmed.length < 32) return null;
    try {
      final raw = trimmed.contains(',')
          ? trimmed.substring(trimmed.indexOf(',') + 1)
          : trimmed;
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _muted, size: 12.sp),
            SizedBox(height: 1.5.h),
            Text(
              title,
              style: TextStyle(
                color: _bright,
                fontSize: 4.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 0.8.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 3.2.sp),
            ),
            SizedBox(height: 2.h),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: _bright,
                side: const BorderSide(color: _borderC),
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
