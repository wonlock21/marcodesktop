import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'models/gcs_field_graph_model.dart';
import 'models/gcs_mission_model.dart';
import 'models/gcs_event_log_model.dart';
import 'raw_ros_log_page.dart';

const _bg = Color(0xFF121212);
const _panelBg = Color(0xFF1A1A1A);
const _borderC = Color(0xFF333333);
const _muted = Color(0xFF9E9E9E);
const _bright = Color(0xFFE0E0E0);
const _success = Color(0xFF43A047);
const _warning = Color(0xFFFFA726);

class ProductionMissionPage extends StatelessWidget {
  const ProductionMissionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final graph = context.watch<GcsFieldGraphModel>();
    final mission = context.watch<GcsMissionModel>();
    final events = context.watch<GcsEventLogModel>();
    final status = mission.robotStatus;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _panelBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(0.3.h),
          child: Divider(height: 0.3.h, color: _borderC),
        ),
        title: Text(
          'Görev İzleme',
          style: TextStyle(
            color: Colors.white,
            fontSize: 5.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton.icon(
            key: const Key('raw-ros-logs-button'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const RawRosLogPage(),
              ),
            ),
            icon: const Icon(Icons.terminal),
            label: const Text('Ham ROS Logları'),
          ),
          SizedBox(width: 1.w),
        ],
      ),
      body: ListView(padding: EdgeInsets.all(3.w), children: [
        Text(
            mission.statusFresh
                ? 'ROS durumu güncel'
                : 'Robot durumu eski / ROS verisi bekleniyor; komutlar kilitli',
            style: TextStyle(
              color: mission.statusFresh ? _success : _warning,
              fontSize: 3.sp,
              fontWeight: FontWeight.w600,
            )),
        SizedBox(height: 1.h),
        Text(
            'Aktif saha: ${graph.activeFresh ? graph.activeField?.fieldName ?? "—" : "güncel değil"}\nSürüm: ${graph.activeField?.packageVersion ?? "—"}\nHash: ${graph.activeField?.packageHash ?? "—"}',
            style: TextStyle(
              color: _bright,
              fontSize: 2.8.sp,
              height: 1.4,
              fontFamily: 'monospace',
            )),
        Text(
          graph.routeRuntimeReadinessKnown
              ? 'Rota yük/yön kısıtları: ${graph.routeRuntimeReady ? "Hazır" : "Hazır değil"}'
              : 'Rota yük/yön kısıtları: Durum bekleniyor',
          style: TextStyle(
            color: graph.routeRuntimeReadinessKnown && graph.routeRuntimeReady
                ? _success
                : _warning,
            fontSize: 2.7.sp,
          ),
        ),
        if (!graph.selectedFieldIsActive)
          TextButton(
              onPressed: graph.connected && graph.activeField?.active == true
                  ? () => graph.selectField(graph.activeField!.fieldName)
                  : null,
              child: Text('Aktif saha grafiğini yükle',
                  style: TextStyle(fontSize: 2.8.sp))),
        if (status != null) ...[
          _monitor(
              'Bağlantılar',
              {
                'Robot / ROS': mission.connected ? 'Bağlı' : 'Bağlı Değil',
                'PLC Bağlantısı': status.plcConnected ? 'Bağlı' : 'Bağlı Değil',
              },
              mission.statusFresh),
          _monitor(
              'Görev / Rota',
              {
                'Durum': status.missionStateLabel,
                'Açıklama': status.statusDetail,
                'Görev': status.taskId,
                'Görev Kaynağı': status.taskSourceLabel,
                'Rota': status.pickupNode.isEmpty && status.dropoffNode.isEmpty
                    ? '—'
                    : '${status.pickupNode} → ${status.dropoffNode}',
                'Süre (s)': status.missionElapsedS,
                'Duraklar': status.routeNodes,
                'Aktif durak': status.currentStopIndex,
                'Kenarlar': status.selectedRouteEdges,
                'Aktif kenar': status.currentRouteEdge,
                'Sonraki düğüm': status.nextNode,
                'Route guard': status.routeGuardState,
                'Durma nedeni': status.routeStopReason,
                'Hız limiti (m/s)': status.routeSpeedLimit,
                'Sapma (m)': status.crossTrackError
              },
              mission.statusFresh),
          _monitor(
              'Kapı Geçişi',
              {
                'Durum': status.gateActive ? 'Aktif' : 'Aktif Değil',
                'Bekleme Noktası':
                    status.gateActive && status.gateEntryNode.isNotEmpty
                        ? status.gateEntryNode
                        : '—',
                'Yön': status.gateDirectionLabel,
                'Geçiş İzni': status.gatePermissionLabel,
              },
              mission.statusFresh),
          _monitor(
              'İstasyon / Docking',
              {
                'İstasyon fazı': status.stationPhase,
                'QR': status.lastQrDetected && status.lastQrData.isNotEmpty
                    ? status.lastQrData
                    : '—',
                'Dock hedefi': status.dockingTargetStation,
                'Ayarlanan süre (s)': status.dockingConfiguredDurationS,
                'Geçen (s)': status.dockingElapsedS,
                'Kalan (s)': status.dockingRemainingS,
                'Lane kontrol aktif': status.dockingLaneControlActive,
                'Kamera geçerli': status.dockingCameraValid,
                'Durdu': status.dockingStopped,
                'Dock hatası': status.dockingErrorReason
              },
              mission.statusFresh),
          if (mission.stationTurnStatus case final turn?)
            _monitor(
                'Otomatik Dönüş Seçimi',
                {
                  'İstasyon': turn.station,
                  'Seçilen yön': turn.unavailable
                      ? 'Seçilemedi'
                      : turn.selectedDirection == 'left'
                          ? 'Sol'
                          : turn.selectedDirection == 'right'
                              ? 'Sağ'
                              : '—',
                  'Sol yay': turn.left.safe ? 'Güvenli' : 'Engelli',
                  'Sol minimum açıklık (m)': turn.left.minimumClearanceM ?? '—',
                  'Sol maksimum maliyet': turn.left.maximumCost ?? '—',
                  'Sol neden':
                      turn.left.reason.isEmpty ? '—' : turn.left.reason,
                  'Sağ yay': turn.right.safe ? 'Güvenli' : 'Engelli',
                  'Sağ minimum açıklık (m)':
                      turn.right.minimumClearanceM ?? '—',
                  'Sağ maksimum maliyet': turn.right.maximumCost ?? '—',
                  'Sağ neden':
                      turn.right.reason.isEmpty ? '—' : turn.right.reason,
                },
                mission.statusFresh),
          ExpansionTile(
              collapsedIconColor: _muted,
              iconColor: _bright,
              title: Text('Tüm RobotStatus alanları (ham ROS)',
                  style: TextStyle(
                      color: _bright,
                      fontSize: 3.sp,
                      fontWeight: FontWeight.w600)),
              children: [
                _monitor('RobotStatus', status.raw, mission.statusFresh)
              ]),
        ],
        SizedBox(height: 1.h),
        Text('Görev ve sistem olayları (yeniden eskiye)',
            style: TextStyle(
              color: _bright,
              fontSize: 3.sp,
              fontWeight: FontWeight.w600,
            )),
        for (final event in events.kayitlar)
          Card(
              color: _panelBg,
              child: ListTile(
                  title: SelectableText(event.mesaj,
                      style: TextStyle(color: _bright, fontSize: 2.8.sp)),
                  subtitle: Text(event.zaman.toIso8601String(),
                      style: TextStyle(
                          color: _muted,
                          fontSize: 2.4.sp,
                          fontFamily: 'monospace')))),
      ]),
    );
  }

  Widget _monitor(String title, Map<String, dynamic> values, bool fresh) =>
      Card(
          color: _panelBg,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: _borderC),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Padding(
              padding: EdgeInsets.all(2.5.w),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$title${fresh ? "" : " · ESKİ VERİ"}',
                        style: TextStyle(
                          color: fresh ? _bright : _warning,
                          fontSize: 3.2.sp,
                          fontWeight: FontWeight.w700,
                        )),
                    SizedBox(height: 0.7.h),
                    for (final entry in values.entries)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 0.15.h),
                        child: SelectableText(
                          '${entry.key}: ${entry.value}',
                          style: TextStyle(
                            color: fresh ? _bright : _muted,
                            fontSize: 2.7.sp,
                            height: 1.25,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                  ])));
}
