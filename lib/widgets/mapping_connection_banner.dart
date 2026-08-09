import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/gcs_mapping_model.dart';
import '../services/ros_bridge_client.dart';

/// HARİTA alanı üstü: Bağlı / Bağlanıyor / Kopuk + reconnect yenileme metni.
class MappingConnectionBanner extends StatelessWidget {
  const MappingConnectionBanner({super.key, required this.model});

  final GcsMappingModel model;

  @override
  Widget build(BuildContext context) {
    final accent = model.bannerColor;
    final icon = switch (model.connectionStatus) {
      RosConnectionStatus.connected =>
        model.awaitingFreshPreview
            ? Icons.sync
            : Icons.check_circle_outline,
      RosConnectionStatus.connecting ||
      RosConnectionStatus.reconnecting =>
        Icons.hourglass_top,
      RosConnectionStatus.error ||
      RosConnectionStatus.disconnected =>
        Icons.link_off,
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.7.h),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        border: Border(
          bottom: BorderSide(color: accent.withValues(alpha: 0.55), width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 3.8.sp, color: accent),
          SizedBox(width: 1.5.w),
          Text(
            model.bannerTitle,
            style: TextStyle(
              color: accent,
              fontSize: 3.2.sp,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              model.bannerSubtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFB0B0B0),
                fontSize: 2.8.sp,
                fontFamily: 'monospace',
              ),
            ),
          ),
          if (model.mappingStatusStale && !model.isConnected)
            Text(
              'SON HARİTA',
              style: TextStyle(
                color: const Color(0xFF888888),
                fontSize: 2.4.sp,
                fontFamily: 'monospace',
                letterSpacing: 0.8,
              ),
            ),
        ],
      ),
    );
  }
}
