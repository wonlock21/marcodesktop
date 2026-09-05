import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/gcs_field_graph_model.dart';
import 'models/gcs_mission_model.dart';
import 'models/gcs_event_log_model.dart';

class ProductionMissionPage extends StatelessWidget {
  const ProductionMissionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final graph = context.watch<GcsFieldGraphModel>();
    final mission = context.watch<GcsMissionModel>();
    final events = context.watch<GcsEventLogModel>();
    final status = mission.robotStatus;
    return Scaffold(
      appBar: AppBar(title: const Text('Görev İzleme')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(
            mission.statusFresh
                ? 'ROS durumu güncel'
                : 'Robot durumu eski / ROS verisi bekleniyor; komutlar kilitli',
            style: TextStyle(
                color:
                    mission.statusFresh ? Colors.greenAccent : Colors.orange)),
        Text(
            'Aktif saha: ${graph.activeFresh ? graph.activeField?.fieldName ?? "—" : "güncel değil"}\nSürüm: ${graph.activeField?.packageVersion ?? "—"}\nHash: ${graph.activeField?.packageHash ?? "—"}',
            style: const TextStyle(color: Colors.white)),
        if (!graph.selectedFieldIsActive)
          TextButton(
              onPressed: graph.connected && graph.activeField?.active == true
                  ? () => graph.selectField(graph.activeField!.fieldName)
                  : null,
              child: const Text('Aktif saha grafiğini yükle')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bu ekran yalnız çalışan görevi izler.'),
                const Text(
                    'Rota Senaryo ekranında hazırlanır; görev Ana Ekrandan başlatılır veya iptal edilir.'),
                if (mission.commandMessage.isNotEmpty)
                  Text(mission.commandMessage),
                if (mission.commandPending)
                  Text('İstek bekleniyor: ${mission.pendingCommand}'),
              ],
            ),
          ),
        ),
        const Text(
            'PLC entegrasyonu bekleniyor · Fiziksel mod anahtarı: donanım bekleniyor',
            style: TextStyle(color: Colors.orange)),
        if (status != null) ...[
          _monitor(
              'Görev / Rota',
              {
                'Durum': '${mission.asama.etiket} (${status.missionState})',
                'Açıklama': status.statusDetail,
                'Görev': status.taskId,
                'Kaynak': status.taskSource,
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
              'Gate',
              {
                'İzin bekleniyor': status.missionState == 4,
                'İzin verildi': status.gatePermissionGranted,
                'Yön': status.gateDirection,
                'Giriş düğümü': status.gateEntryNode,
                'Crossing ID': status.gateCrossingId
              },
              mission.statusFresh),
          _monitor(
              'QR / Docking',
              {
                'İstasyon fazı': status.stationPhase,
                'Hedef': status.qrTargetStation,
                'Beklenen QR': status.expectedQrId,
                'QR armed': status.qrTriggerArmed,
                'Son QR': status.lastQrData,
                'QR reddi': status.lastQrRejectReason,
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
          ExpansionTile(
              title: const Text('Tüm RobotStatus alanları (ham ROS)',
                  style: TextStyle(color: Colors.white)),
              children: [
                _monitor('RobotStatus', status.raw, mission.statusFresh)
              ]),
        ],
        const Text(
            'Mission / gate / junction / station olayları (yeniden eskiye)',
            style: TextStyle(color: Colors.white)),
        for (final event in events.kayitlar)
          Card(
              child: ListTile(
                  title: SelectableText(event.mesaj),
                  subtitle: Text(event.zaman.toIso8601String()))),
      ]),
    );
  }

  Widget _monitor(String title, Map<String, dynamic> values, bool fresh) =>
      Card(
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$title${fresh ? "" : " · ESKİ VERİ"}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    for (final entry in values.entries)
                      SelectableText('${entry.key}: ${entry.value}'),
                  ])));
}
