import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/field_graph_models.dart';
import 'models/gcs_field_graph_model.dart';
import 'models/gcs_mission_model.dart';
import 'models/gcs_event_log_model.dart';

class ProductionMissionPage extends StatefulWidget {
  const ProductionMissionPage({super.key});
  @override
  State<ProductionMissionPage> createState() => _ProductionMissionPageState();
}

class _ProductionMissionPageState extends State<ProductionMissionPage> {
  int? pickup;
  int? dropoff;
  bool returnHome = true;
  String? selectionField;
  Future<void> command(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final graph = context.watch<GcsFieldGraphModel>();
    final mission = context.watch<GcsMissionModel>();
    final events = context.watch<GcsEventLogModel>();
    final pickups =
        graph.nodes.where((n) => n.role == FieldNodeRole.pickupDock).toList();
    final dropoffs =
        graph.nodes.where((n) => n.role == FieldNodeRole.dropoffDock).toList();
    if (selectionField != graph.selectedFieldName) {
      pickup = dropoff = null;
      selectionField = graph.selectedFieldName;
    }
    if (!pickups.any((n) => n.nodeId == pickup)) pickup = null;
    if (!dropoffs.any((n) => n.nodeId == dropoff)) dropoff = null;
    // Selection is a local draft operation, including while disconnected.
    final editable = graph.nodes.isNotEmpty;
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
                child: Column(children: [
                  DropdownButtonFormField<int>(
                      key: ValueKey('pickup-$selectionField-$pickup'),
                      initialValue: pickup,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Pickup / alma dock'),
                      items: [
                        for (final n in pickups)
                          DropdownMenuItem(
                              value: n.nodeId,
                              child: Text('${n.stationId} · ${n.name}'))
                      ],
                      onChanged:
                          editable ? (v) => setState(() => pickup = v) : null),
                  DropdownButtonFormField<int>(
                      key: ValueKey('dropoff-$selectionField-$dropoff'),
                      initialValue: dropoff,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Dropoff / bırakma dock'),
                      items: [
                        for (final n in dropoffs)
                          DropdownMenuItem(
                              value: n.nodeId,
                              child: Text('${n.stationId} · ${n.name}'))
                      ],
                      onChanged:
                          editable ? (v) => setState(() => dropoff = v) : null),
                  SwitchListTile(
                      title: const Text('Görev sonunda başlangıca dön'),
                      value: returnHome,
                      onChanged: editable
                          ? (v) => setState(() => returnHome = v)
                          : null),
                  if (mission.submitBlockReason(graph) case final reason?)
                    Text('Gönderme: $reason'),
                  if (mission.startBlockReason case final reason?)
                    Text('Başlatma: $reason'),
                  Wrap(spacing: 12, runSpacing: 8, children: [
                    FilledButton(
                        key: const Key('mission-submit'),
                        onPressed: editable &&
                                pickup != null &&
                                dropoff != null &&
                                mission.submitBlockReason(graph) == null
                            ? () => command(() => mission.submit(
                                graph: graph,
                                stops: [
                                  graph.nodeById(pickup!)!,
                                  graph.nodeById(dropoff!)!
                                ],
                                returnHome: returnHome))
                            : null,
                        child: const Text('Görevi Hazırla / Submit')),
                    FilledButton(
                        key: const Key('mission-start'),
                        onPressed: mission.readyToStart
                            ? () => command(mission.start)
                            : null,
                        child: const Text('Başlat / Start')),
                    OutlinedButton(
                        onPressed: mission.connected &&
                                mission.statusFresh &&
                                !mission.commandPending
                            ? () => command(mission.cancel)
                            : null,
                        child: const Text('Görevi İptal Et')),
                    OutlinedButton(
                        onPressed: mission.connected &&
                                mission.statusFresh &&
                                !mission.commandPending
                            ? () => command(mission.resetSafety)
                            : null,
                        child: const Text('Safety Reset')),
                    FilledButton(
                        onPressed:
                            mission.connected && !mission.emergencyPending
                                ? () => command(mission.emergencyStop)
                                : null,
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade800),
                        child: const Text('Yazılımsal Acil Durdurma')),
                  ]),
                  const Text(
                      'Yazılımsal acil durdurma fiziksel acil durdurma butonunun yerine geçmez.'),
                  if (mission.commandMessage.isNotEmpty)
                    Text(mission.commandMessage),
                  if (mission.readyToStart)
                    const Text('Görev hazır — başlatma komutu bekleniyor'),
                  if (mission.commandPending)
                    Text('İstek bekleniyor: ${mission.pendingCommand}'),
                ]))),
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
