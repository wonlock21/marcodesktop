import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/field_graph_models.dart';
import 'models/gcs_field_graph_model.dart';
import 'services/angles.dart';

class StationConfigPage extends StatelessWidget {
  const StationConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    final graph = context.watch<GcsFieldGraphModel>();
    final docks = graph.nodes.where((n) =>
        n.role == FieldNodeRole.pickupDock ||
        n.role == FieldNodeRole.dropoffDock);
    return Scaffold(
      appBar: AppBar(title: const Text('İstasyon / QR Ayarları')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(
            '${graph.selectedFieldName ?? "Saha seçilmedi"}${graph.selectedFieldIsActive ? " · AKTİF / SALT OKUNUR" : ""}',
            style: const TextStyle(color: Colors.white)),
        const Text(
            'İstasyonlar saha grafiğindeki dock rollerinden gelir. Approach ve dock aynı station_id değerini kullanmalı. Hareketi ROS yönetir.',
            style: TextStyle(color: Colors.white70)),
        if (graph.stationConfigsError != null)
          Text(graph.stationConfigsError!,
              style: const TextStyle(color: Colors.orange)),
        if (!graph.graphFresh)
          const Text('ROS grafiği güncel değil',
              style: TextStyle(color: Colors.orange)),
        if (docks.isEmpty)
          const Text('Önce alma/bırakma dock düğümlerini oluşturun.',
              style: TextStyle(color: Colors.white)),
        for (final dock in docks)
          Builder(builder: (context) {
            final matching = graph.stationConfigs
                .where((c) => c.stationNodeId == dock.nodeId);
            final config = matching.isEmpty ? null : matching.first;
            return Card(
                child: ListTile(
              title: Text('${dock.stationId} · ${dock.name}'),
              subtitle: Text(config == null
                  ? 'Yaklaşım ayarı kaydedilmemiş'
                  : 'QR: ${config.approachQrId} · Şerit takip: ${config.lineFollowDurationS} s\n'
                      'Docking yönü: ${radiansToDegrees(config.dockHeadingYaw).toStringAsFixed(1)}° (rota geometrisi) · Dönüş: Otomatik'),
              trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'İstasyon ayarını düzenle',
                  onPressed: graph.canEdit
                      ? () => showDialog<void>(
                          context: context,
                          builder: (_) => _StationDialog(
                              dock: dock, config: config, graph: graph))
                      : null),
            ));
          }),
      ]),
    );
  }
}

class _StationDialog extends StatefulWidget {
  const _StationDialog(
      {required this.dock, required this.config, required this.graph});
  final FieldNode dock;
  final StationApproachConfig? config;
  final GcsFieldGraphModel graph;
  @override
  State<_StationDialog> createState() => _StationDialogState();
}

class _StationDialogState extends State<_StationDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController qr;
  late final TextEditingController duration;
  bool pending = false;
  String? error;
  @override
  void initState() {
    super.initState();
    qr = TextEditingController(text: widget.config?.approachQrId ?? '');
    duration = TextEditingController(
        text: widget.config?.lineFollowDurationS.toString() ?? '');
  }

  @override
  void dispose() {
    qr.dispose();
    duration.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (pending || !form.currentState!.validate()) return;
    setState(() {
      pending = true;
      error = null;
    });
    try {
      await widget.graph.saveStationConfig(StationApproachConfig(
          stationId: widget.dock.stationId,
          stationNodeId: widget.dock.nodeId,
          approachQrId: qr.text.trim(),
          dockHeadingYaw: widget.config?.dockHeadingYaw ?? 0.0,
          turnDirection: 'auto',
          lineFollowDurationS: double.parse(duration.text.trim())));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${widget.dock.stationId} / ${widget.dock.name}'),
        content: SizedBox(
            width: 460,
            child: Form(
                key: form,
                child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                      key: const Key('station-approach-qr-field'),
                      controller: qr,
                      enabled: !pending,
                      decoration: const InputDecoration(
                          labelText: 'Yaklaşım QR kimliği'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty || v.trim().length > 64
                              ? '1–64 karakter gerekli'
                              : null),
                  TextFormField(
                      key: const Key('station-line-follow-duration-field'),
                      controller: duration,
                      enabled: !pending,
                      decoration: const InputDecoration(
                          labelText: 'Geri şerit takip süresi (s)'),
                      validator: (v) {
                        final n = double.tryParse(v?.trim() ?? '');
                        return n == null || !n.isFinite || n < 0.1 || n > 120
                            ? '0.1–120.0 s gerekli'
                            : null;
                      }),
                  const SizedBox(height: 12),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Gelişmiş / Debug'),
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Hesaplanan docking yönü'),
                        subtitle: Text(widget.config == null
                            ? 'Henüz ROS tarafından hesaplanmadı'
                            : '${radiansToDegrees(widget.config!.dockHeadingYaw).toStringAsFixed(1)}° '
                                '(${widget.config!.dockHeadingYaw.toStringAsFixed(3)} rad)'),
                      ),
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Dönüş seçimi'),
                        subtitle: Text('Otomatik'),
                      ),
                    ],
                  ),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                ])))),
        actions: [
          TextButton(
              onPressed: pending ? null : () => Navigator.pop(context),
              child: const Text('Vazgeç')),
          FilledButton(
              key: const Key('station-config-save-button'),
              onPressed: pending ? null : save,
              child: Text(pending ? 'Kaydediliyor…' : 'ROS’a Kaydet'))
        ],
      );
}
