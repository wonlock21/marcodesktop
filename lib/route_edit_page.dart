import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'models/field_graph_models.dart';
import 'models/gcs_field_graph_model.dart';
import 'models/gcs_mapping_model.dart';
import 'widgets/map_preview_stage.dart';

const _bg = Color(0xFF121212);
const _panelBg = Color(0xFF1A1A1A);
const _borderC = Color(0xFF333333);
const _muted = Color(0xFF9E9E9E);
const _bright = Color(0xFFE0E0E0);
const _accent = Color(0xFF42A5F5);
const _success = Color(0xFF43A047);
const _warning = Color(0xFFFFA726);
const _danger = Color(0xFFE53935);

class RouteEditPage extends StatefulWidget {
  const RouteEditPage({super.key});

  @override
  State<RouteEditPage> createState() => _RouteEditPageState();
}

class _RouteEditPageState extends State<RouteEditPage> {
  String _errorText(Object error) =>
      error.toString().replaceFirst('Bad state: ', '').trim();

  void _toast(String message) {
    if (!mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  Future<void> _editEdge([FieldEdge? existing]) async {
    final graph = context.read<GcsFieldGraphModel>();
    if (!graph.canEdit || graph.nodes.length < 2) return;
    final edge = await showDialog<FieldEdge>(
      context: context,
      builder: (_) => _EdgeEditorDialog(nodes: graph.nodes, existing: existing),
    );
    if (edge == null || !mounted) return;
    try {
      final result = await graph.saveEdge(edge);
      if (mounted) _toast(result.message);
    } catch (error) {
      _toast('Kenar kaydedilemedi: ${_errorText(error)}');
    }
  }

  Future<void> _deleteEdge(FieldEdge edge) async {
    final graph = context.read<GcsFieldGraphModel>();
    if (!graph.canEdit) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Kenarı sil'),
            content: Text('Edge ${edge.edgeId} kalıcı grafikten silinecek.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Sil'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    try {
      final result = await graph.deleteEdge(edge.edgeId);
      if (mounted) _toast(result.message);
    } catch (error) {
      _toast('Kenar silinemedi: ${_errorText(error)}');
    }
  }

  Future<void> _validate() async {
    final graph = context.read<GcsFieldGraphModel>();
    try {
      final result = await graph.validateSelected();
      if (!mounted) return;
      _toast(
        result.success && result.status.state == FieldPackageState.valid
            ? 'Saha doğrulandı: ${_shortHash(result.status.packageHash)}'
            : result.message,
      );
    } catch (error) {
      _toast('Doğrulama başarısız: ${_errorText(error)}');
    }
  }

  Future<void> _activate() async {
    final graph = context.read<GcsFieldGraphModel>();
    try {
      final result = await graph.activateSelected();
      if (mounted) _toast(result.message);
    } catch (error) {
      _toast('Aktivasyon başarısız: ${_errorText(error)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final graph = context.watch<GcsFieldGraphModel>();
    final mapping = context.watch<GcsMappingModel>();
    final metadata = mapping.previewMetadata;

    final markers = <MapPreviewNodeMarker>[];
    if (metadata != null) {
      for (final node in graph.nodes) {
        final pixel = metadata.mapToPixel(node.pose.x, node.pose.y);
        if (!pixel.insideMap) continue;
        markers.add(MapPreviewNodeMarker(
          label: node.name,
          pixelX: pixel.x,
          pixelY: pixel.y,
          color: _nodeColor(node.role),
        ));
      }
    }
    final segments = <MapPreviewRouteSegment>[];
    if (metadata != null) {
      for (final edge in graph.edges) {
        final start = graph.nodeById(edge.startNodeId);
        final end = graph.nodeById(edge.endNodeId);
        if (start == null || end == null) continue;
        final startPixel = metadata.mapToPixel(start.pose.x, start.pose.y);
        final endPixel = metadata.mapToPixel(end.pose.x, end.pose.y);
        if (!startPixel.insideMap || !endPixel.insideMap) continue;
        segments.add(MapPreviewRouteSegment(
          start: Offset(startPixel.x, startPixel.y),
          end: Offset(endPixel.x, endPixel.y),
          bidirectional: edge.bidirectional,
          color: edge.loadRule == FieldLoadRule.loaded ? _warning : _accent,
        ));
      }
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _panelBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Saha Rotası',
          style: TextStyle(
            color: Colors.white,
            fontSize: 5.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton.icon(
              onPressed: graph.graphFresh
                  ? () => Navigator.pushNamed(context, 'station-config-page')
                  : null,
              icon: const Icon(Icons.qr_code),
              label: const Text('İstasyon / QR')),
          if (graph.selectedFieldName case final field?)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 1.w),
                child: Text(
                  '$field${graph.selectedFieldIsActive ? ' · AKTİF/SALT OKUNUR' : ''}',
                  style: TextStyle(
                    color: graph.selectedFieldIsActive ? _success : _muted,
                    fontSize: 2.8.sp,
                  ),
                ),
              ),
            ),
          TextButton.icon(
            onPressed: graph.canEdit && graph.nodes.length >= 2
                ? () => unawaited(_editEdge())
                : null,
            icon: const Icon(Icons.add_road),
            label: const Text('Kenar Ekle'),
          ),
          TextButton.icon(
            onPressed: graph.canEdit ? () => unawaited(_validate()) : null,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Doğrula'),
          ),
          TextButton.icon(
            onPressed: graph.canActivate ? () => unawaited(_activate()) : null,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Aktifleştir'),
          ),
          SizedBox(width: 1.w),
        ],
      ),
      body: !graph.hasSelectedField
          ? _NoField(
              onSelect: () => Navigator.pushNamed(context, 'saved-fields-page'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FieldValidationPanel(graph: graph),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 7,
                        child: mapping.hasPreviewPng
                            ? MapPreviewStage(
                                pngBytes: mapping.previewPng!,
                                metadata: metadata,
                                robotPixel: mapping.visibleRobotPixel,
                                awaitingFresh: mapping.awaitingFreshPreview,
                                sourceLabel: mapping.previewSourceLabel,
                                nodeMarkers: markers,
                                routeSegments: segments,
                              )
                            : Center(
                                child: Text(
                                  'Harita önizlemesi bekleniyor.\nKenarlar backend grafiğinde kayıtlıdır.',
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(color: _muted, fontSize: 3.sp),
                                ),
                              ),
                      ),
                      SizedBox(
                        width: 38.w,
                        child: _EdgePanel(
                          graph: graph,
                          onEdit: (edge) => unawaited(_editEdge(edge)),
                          onDelete: (edge) => unawaited(_deleteEdge(edge)),
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

class FieldValidationPanel extends StatelessWidget {
  final GcsFieldGraphModel graph;
  const FieldValidationPanel({super.key, required this.graph});

  @override
  Widget build(BuildContext context) {
    final status = graph.packageStatus;
    final messages = <String>[
      if (graph.graphError != null) graph.graphError!,
      if (status != null) ...status.errors.map((value) => 'HATA: $value'),
      if (status != null) ...status.warnings.map((value) => 'UYARI: $value'),
    ];
    final state = !graph.connected
        ? 'Bağlantı yok / veri eski'
        : graph.graphLoading
            ? 'Grafik yükleniyor'
            : status == null
                ? 'Paket durumu bekleniyor'
                : '${status.state.name.toUpperCase()} · ${status.nodeCount} düğüm · ${status.edgeCount} kenar';
    final color = status?.errors.isNotEmpty == true || graph.graphError != null
        ? _danger
        : graph.validationCurrent
            ? _success
            : _warning;
    return Container(
      color: color.withAlpha(20),
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.7.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$state${status?.packageHash.isNotEmpty == true ? ' · ${status!.packageHash}' : ''}',
            style: TextStyle(color: color, fontSize: 2.8.sp),
          ),
          if (messages.isNotEmpty)
            ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      for (final message in messages)
                        SelectableText(message,
                            style: TextStyle(color: color, fontSize: 2.5.sp)),
                    ]))),
          if (!graph.canActivate && graph.validationCurrent)
            Text(
              _activationBlockReason(graph),
              style: TextStyle(color: _warning, fontSize: 2.4.sp),
            ),
        ],
      ),
    );
  }
}

class _EdgePanel extends StatelessWidget {
  final GcsFieldGraphModel graph;
  final void Function(FieldEdge) onEdit;
  final void Function(FieldEdge) onDelete;

  const _EdgePanel({
    required this.graph,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: _panelBg,
          border: Border(left: BorderSide(color: _borderC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.all(1.5.w),
              child: Text(
                'Kenarlar (${graph.edges.length})',
                style: TextStyle(
                  color: _bright,
                  fontSize: 3.2.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1, color: _borderC),
            Expanded(
              child: graph.edges.isEmpty
                  ? Center(
                      child: Text(
                        graph.nodes.length < 2
                            ? 'Önce en az iki düğüm ekleyin.'
                            : 'Henüz kenar yok.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _muted, fontSize: 2.7.sp),
                      ),
                    )
                  : ListView.separated(
                      itemCount: graph.edges.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: _borderC),
                      itemBuilder: (context, index) {
                        final edge = graph.edges[index];
                        final start = graph.nodeById(edge.startNodeId)?.name ??
                            edge.startNodeId.toString();
                        final end = graph.nodeById(edge.endNodeId)?.name ??
                            edge.endNodeId.toString();
                        return ListTile(
                          dense: true,
                          title: Text(
                            '$start ${edge.bidirectional ? '↔' : '→'} $end',
                            style: TextStyle(color: _bright, fontSize: 2.9.sp),
                          ),
                          subtitle: Text(
                            '${edge.maxSpeed.toStringAsFixed(2)} m/s · ${edge.loadRule.wireName} · ${edge.movementDirection.wireName}'
                            '${edge.gateEvent.isEmpty ? '' : ' · ${edge.gateEvent}'}',
                            style: TextStyle(color: _muted, fontSize: 2.3.sp),
                          ),
                          onTap: graph.canEdit ? () => onEdit(edge) : null,
                          trailing: IconButton(
                            tooltip: 'Sil',
                            onPressed:
                                graph.canEdit ? () => onDelete(edge) : null,
                            icon: Icon(Icons.delete_outline,
                                color: _danger, size: 4.sp),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
}

class _EdgeEditorDialog extends StatefulWidget {
  final List<FieldNode> nodes;
  final FieldEdge? existing;

  const _EdgeEditorDialog({required this.nodes, this.existing});

  @override
  State<_EdgeEditorDialog> createState() => _EdgeEditorDialogState();
}

class _EdgeEditorDialogState extends State<_EdgeEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late int _startNodeId;
  late int _endNodeId;
  late bool _bidirectional;
  late FieldLoadRule _loadRule;
  late FieldMovementDirection _direction;
  late final TextEditingController _cost;
  late final TextEditingController _speed;
  late final TextEditingController _gateEvent;
  late final TextEditingController _metadata;

  @override
  void initState() {
    super.initState();
    final edge = widget.existing;
    _startNodeId = edge?.startNodeId ?? widget.nodes.first.nodeId;
    _endNodeId = edge?.endNodeId ?? widget.nodes[1].nodeId;
    _bidirectional = edge?.bidirectional ?? false;
    _loadRule = edge?.loadRule ?? FieldLoadRule.any;
    _direction = edge?.movementDirection ?? FieldMovementDirection.forward;
    _cost = TextEditingController(text: (edge?.cost ?? 1).toString());
    _speed = TextEditingController(text: (edge?.maxSpeed ?? 0.2).toString());
    _gateEvent = TextEditingController(text: edge?.gateEvent ?? '');
    _metadata = TextEditingController(text: edge?.metadataJson ?? '{}');
  }

  @override
  void dispose() {
    _cost.dispose();
    _speed.dispose();
    _gateEvent.dispose();
    _metadata.dispose();
    super.dispose();
  }

  FieldNode? _node(int id) {
    for (final node in widget.nodes) {
      if (node.nodeId == id) return node;
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final edge = FieldEdge(
      edgeId: widget.existing?.edgeId ?? FieldGraphId.next(),
      startNodeId: _startNodeId,
      endNodeId: _endNodeId,
      bidirectional: _bidirectional,
      cost: double.parse(_cost.text.trim()),
      maxSpeed: double.parse(_speed.text.trim()),
      loadRule: _loadRule,
      movementDirection: _direction,
      gateEvent: _gateEvent.text.trim(),
      metadataJson: _metadata.text.trim(),
    );
    final errors = edge.validationErrors(nodes: widget.nodes);
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errors.join('\n'))),
      );
      return;
    }
    Navigator.pop(context, edge);
  }

  String? _numberValidator(String? value, {required bool speed}) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || !parsed.isFinite) return 'Geçerli sayı girin';
    if (speed && (parsed < 0.05 || parsed > 0.50)) {
      return '0.05..0.50 m/s olmalı';
    }
    if (!speed && parsed <= 0) return '0’dan büyük olmalı';
    return null;
  }

  String? _metadataValidator(String? value) {
    try {
      if (jsonDecode(value ?? '') is! Map) return 'JSON object olmalı';
      return null;
    } catch (_) {
      return 'Geçerli JSON object girin';
    }
  }

  @override
  Widget build(BuildContext context) {
    final expectedGate =
        gateEventForRoles(_node(_startNodeId)?.role, _node(_endNodeId)?.role);
    return AlertDialog(
      title: Text(widget.existing == null ? 'Yeni kenar' : 'Kenarı düzenle'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _startNodeId,
                  decoration: const InputDecoration(labelText: 'Başlangıç'),
                  items: [
                    for (final node in widget.nodes)
                      DropdownMenuItem(
                          value: node.nodeId, child: Text(node.name)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _startNodeId = value);
                  },
                ),
                DropdownButtonFormField<int>(
                  initialValue: _endNodeId,
                  decoration: const InputDecoration(labelText: 'Bitiş'),
                  items: [
                    for (final node in widget.nodes)
                      DropdownMenuItem(
                          value: node.nodeId, child: Text(node.name)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _endNodeId = value);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Çift yönlü'),
                  value: _bidirectional,
                  onChanged: (value) => setState(() => _bidirectional = value),
                ),
                TextFormField(
                  controller: _cost,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Maliyet'),
                  validator: (value) => _numberValidator(value, speed: false),
                ),
                TextFormField(
                  controller: _speed,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Azami hız (m/s)'),
                  validator: (value) => _numberValidator(value, speed: true),
                ),
                DropdownButtonFormField<FieldLoadRule>(
                  initialValue: _loadRule,
                  decoration: const InputDecoration(labelText: 'Yük kuralı'),
                  items: [
                    for (final value in FieldLoadRule.values)
                      DropdownMenuItem(
                          value: value, child: Text(value.wireName)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _loadRule = value;
                      if (value == FieldLoadRule.loaded) {
                        _direction = FieldMovementDirection.reverse;
                      }
                    });
                  },
                ),
                DropdownButtonFormField<FieldMovementDirection>(
                  initialValue: _direction,
                  decoration: const InputDecoration(labelText: 'Hareket yönü'),
                  items: [
                    for (final value in FieldMovementDirection.values)
                      DropdownMenuItem(
                          value: value, child: Text(value.wireName)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _direction = value);
                  },
                ),
                TextFormField(
                  controller: _gateEvent,
                  decoration: InputDecoration(
                    labelText: 'Kapı olayı (gate_event)',
                    helperText: expectedGate == null
                        ? 'Opsiyonel'
                        : 'Yönlü crossing: $expectedGate',
                  ),
                  validator: (value) =>
                      expectedGate != null && value?.trim() != expectedGate
                          ? 'Bu yön için $expectedGate gerekli'
                          : null,
                ),
                TextFormField(
                  controller: _metadata,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'metadata_json'),
                  validator: _metadataValidator,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Kaydet')),
      ],
    );
  }
}

class _NoField extends StatelessWidget {
  final VoidCallback onSelect;
  const _NoField({required this.onSelect});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_outlined, color: _muted, size: 10.sp),
            SizedBox(height: 1.h),
            Text(
              'Önce düzenlenecek sahayı seçin.',
              style: TextStyle(color: _bright, fontSize: 3.5.sp),
            ),
            OutlinedButton(
                onPressed: onSelect, child: const Text('Kayıtlı Haritalar')),
          ],
        ),
      );
}

Color _nodeColor(FieldNodeRole role) => switch (role) {
      FieldNodeRole.pickupApproach || FieldNodeRole.pickupDock => _accent,
      FieldNodeRole.dropoffApproach || FieldNodeRole.dropoffDock => _danger,
      FieldNodeRole.gateQ5 || FieldNodeRole.gateQ6 => Colors.purple,
      FieldNodeRole.qrTrigger => Colors.cyan,
      FieldNodeRole.wait => _success,
      FieldNodeRole.transit => _muted,
    };

String _activationBlockReason(GcsFieldGraphModel graph) {
  if (!graph.activeFresh) return 'Aktif saha bilgisi güncel değil';
  if (!graph.robotStatusFresh) return 'RobotStatus güncel değil';
  if (graph.mappingActive) return 'Haritalama sürerken aktivasyon kapalı';
  if (graph.missionActive) return 'Görev sürerken aktivasyon kapalı';
  if (graph.vehicleMoving) return 'Araç hareket ederken aktivasyon kapalı';
  if (graph.selectedFieldIsActive) return 'Saha zaten aktif ve salt okunur';
  return 'Grafik değişti; yeniden doğrulayın';
}

String _shortHash(String value) =>
    value.length <= 12 ? value : '${value.substring(0, 12)}…';
