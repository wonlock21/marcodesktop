import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/gcs_mapping_model.dart';
import '../services/ros_mapping_contract.dart';

/// HARİTA sekmesi: durum satırı + Bitir/Kaydet (başlatma alt şeritte).
class MappingFieldBar extends StatelessWidget {
  const MappingFieldBar({
    super.key,
    required this.model,
    this.onFinishMapping,
  });

  final GcsMappingModel model;
  final VoidCallback? onFinishMapping;

  @override
  Widget build(BuildContext context) {
    final hasStatus = model.mappingStatusLine != null;
    final showFinish = model.showFinishControls;
    if (!hasStatus && !showFinish) {
      return const SizedBox.shrink();
    }

    final canFinish = model.canFinishMapping;
    final status = model.mappingStatus;
    const success = Color(0xFF2F6F4E);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 8.h),
      decoration: const BoxDecoration(
        color: Color(0xFF161616),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2A2A2A), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasStatus) ...[
            _StatusChip(
              line: model.mappingStatusLine!,
              status: status,
              stale: model.mappingStatusStale,
            ),
            if (showFinish) SizedBox(height: 6.h),
          ],
          if (showFinish)
            SizedBox(
              height: 40.h,
              width: double.infinity,
              child: FilledButton(
                onPressed: !canFinish ? null : () => onFinishMapping?.call(),
                style: FilledButton.styleFrom(
                  backgroundColor: success,
                  disabledBackgroundColor: const Color(0xFF2A2A2A),
                  disabledForegroundColor: const Color(0xFF666666),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 2.5.w),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                child: model.finishInFlight
                    ? SizedBox(
                        width: 3.5.w,
                        height: 3.5.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFAAAAAA),
                        ),
                      )
                    : Text(
                        'Haritalamayı Bitir ve Kaydet',
                        style: TextStyle(
                          fontSize: 2.4.sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.line,
    required this.status,
    required this.stale,
  });

  final String line;
  final MappingStatus? status;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      MappingStatus.idle => const Color(0xFF4A90D9),
      MappingStatus.starting || MappingStatus.stopping =>
        const Color(0xFFB7791F),
      MappingStatus.mapping => const Color(0xFF2F6F4E),
      MappingStatus.error => const Color(0xFFC53030),
      null => const Color(0xFF888888),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: stale ? 0.08 : 0.16),
        borderRadius: BorderRadius.circular(3.r),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            switch (status) {
              MappingStatus.idle => Icons.radio_button_checked,
              MappingStatus.starting || MappingStatus.stopping =>
                Icons.hourglass_top,
              MappingStatus.mapping => Icons.map,
              MappingStatus.error => Icons.error_outline,
              null => Icons.info_outline,
            },
            size: 3.2.sp,
            color: color,
          ),
          SizedBox(width: 1.2.w),
          Expanded(
            child: Text(
              line,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: stale ? const Color(0xFF999999) : color,
                fontSize: 2.6.sp,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
