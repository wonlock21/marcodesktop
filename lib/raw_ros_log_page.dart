import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'models/gcs_event_log_model.dart';

class RawRosLogPage extends StatelessWidget {
  const RawRosLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<GcsEventLogModel>().hamRosKayitlari;
    const background = Color(0xFF121212);
    const panel = Color(0xFF1A1A1A);
    const border = Color(0xFF333333);
    const muted = Color(0xFF9E9E9E);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Ham ROS Mesajları',
          style: TextStyle(fontSize: 5.sp, fontWeight: FontWeight.w600),
        ),
      ),
      body: entries.isEmpty
          ? Center(
              child: Text(
                'Bu oturumda henüz ROS görev olayı alınmadı.',
                style: TextStyle(color: muted, fontSize: 3.sp),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.all(2.w),
              itemCount: entries.length,
              separatorBuilder: (_, __) => SizedBox(height: 0.8.h),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Container(
                  padding: EdgeInsets.all(1.5.w),
                  decoration: BoxDecoration(
                    color: panel,
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '[${entry.zamanFormatli}]',
                        style: TextStyle(
                          color: muted,
                          fontSize: 2.5.sp,
                          fontFamily: 'monospace',
                        ),
                      ),
                      SizedBox(width: 1.w),
                      Expanded(
                        child: SelectableText(
                          entry.raw,
                          style: TextStyle(
                            color: const Color(0xFFE0E0E0),
                            fontSize: 2.5.sp,
                            height: 1.35,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Mesajı kopyala',
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: entry.raw),
                        ),
                        icon: const Icon(Icons.copy, color: muted),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
