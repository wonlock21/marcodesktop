import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/gcs_station_approach_model.dart';
import 'models/station_approach_models.dart';

class StationApproachPage extends StatefulWidget {
  const StationApproachPage({super.key});

  @override
  State<StationApproachPage> createState() => _StationApproachPageState();
}

class _StationApproachPageState extends State<StationApproachPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<GcsStationApproachModel>().refresh());
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<GcsStationApproachModel>();
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF191919),
        foregroundColor: Colors.white,
        title: const Text('İstasyon Yaklaşma Ayarları'),
        actions: [
          IconButton(
            tooltip: 'ROS verisini yenile',
            onPressed: model.canLoad && !model.loading
                ? () => unawaited(model.refresh())
                : null,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(model: model),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final android =
                    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
                final columns = android
                    ? 1
                    : constraints.maxWidth >= 1350
                        ? 3
                        : constraints.maxWidth >= 780
                            ? 2
                            : 1;
                const gap = 14.0;
                final cardWidth =
                    (constraints.maxWidth - 32 - gap * (columns - 1)) / columns;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final stationId
                          in GcsStationApproachModel.expectedStationIds)
                        SizedBox(
                          width: cardWidth,
                          child: _StationConfigCard(
                            key:
                                ValueKey('${model.loadedFieldName}:$stationId'),
                            stationId: stationId,
                            config: model.configs[stationId],
                            enabled: model.canEdit,
                            saving: model.isSaving(stationId),
                            backendError: model.cardError(stationId),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.model});

  final GcsStationApproachModel model;

  @override
  Widget build(BuildContext context) {
    final (text, color) = !model.connected
        ? ('ROS bağlantısı yok', Colors.redAccent)
        : !model.activeFieldReady || model.activeFieldName.isEmpty
            ? ('Aktif saha hazır değil', Colors.orangeAccent)
            : model.loading
                ? ('İstasyon ayarları yükleniyor…', Colors.lightBlueAccent)
                : !model.fresh
                    ? ('İstasyon ayarları güncel değil', Colors.orangeAccent)
                    : ('ROS verisi güncel', Colors.greenAccent);
    return Container(
      color: const Color(0xFF161616),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Wrap(
        spacing: 22,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _HeaderValue(label: 'DURUM', value: text, color: color),
          _HeaderValue(
            label: 'AKTİF SAHA',
            value: model.activeFieldName.isEmpty ? '--' : model.activeFieldName,
          ),
          _HeaderValue(
            label: 'SÜRÜM',
            value: model.activeFieldVersion.isEmpty
                ? '--'
                : model.activeFieldVersion,
          ),
          _HeaderValue(
            label: 'PAKET HASH',
            value: model.packageHash.isNotEmpty
                ? model.packageHash
                : model.activeFieldHash.isEmpty
                    ? '--'
                    : model.activeFieldHash,
          ),
          if (model.errorMessage.isNotEmpty)
            Text(
              model.errorMessage,
              style: const TextStyle(color: Colors.redAccent),
            ),
        ],
      ),
    );
  }
}

class _HeaderValue extends StatelessWidget {
  const _HeaderValue({
    required this.label,
    required this.value,
    this.color = Colors.white,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
}

class _StationConfigCard extends StatefulWidget {
  const _StationConfigCard({
    super.key,
    required this.stationId,
    required this.config,
    required this.enabled,
    required this.saving,
    required this.backendError,
  });

  final String stationId;
  final StationApproachConfig? config;
  final bool enabled;
  final bool saving;
  final String? backendError;

  @override
  State<_StationConfigCard> createState() => _StationConfigCardState();
}

class _StationConfigCardState extends State<_StationConfigCard> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _qrController;
  late final TextEditingController _yawController;
  late final TextEditingController _durationController;
  StationTurnDirection _turnDirection = StationTurnDirection.left;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _qrController = TextEditingController();
    _yawController = TextEditingController();
    _durationController = TextEditingController();
    _applyConfig(widget.config);
  }

  @override
  void didUpdateWidget(covariant _StationConfigCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.config, widget.config)) {
      _applyConfig(widget.config);
    }
  }

  void _applyConfig(StationApproachConfig? config) {
    if (config == null) return;
    _qrController.text = config.approachQrId;
    _yawController.text = _formatNumber(config.dockHeadingYaw);
    _durationController.text = _formatNumber(config.lineFollowDurationS);
    _turnDirection = config.turnDirection;
    _localError = null;
  }

  @override
  void dispose() {
    _qrController.dispose();
    _yawController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border.all(color: const Color(0xFF333333)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: config == null
          ? _MissingStation(stationId: widget.stationId)
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: widget.stationId.startsWith('A')
                            ? const Color(0xFF174E75)
                            : const Color(0xFF245C35),
                        child: Text(
                          widget.stationId,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'İSTASYON DÜĞÜMÜ',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            SelectableText(
                              config.stationNodeId.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _field(
                    controller: _qrController,
                    label: 'Yaklaşma QR kimliği',
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'QR kimliği boş olamaz'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _yawController,
                    label: 'Yanaşma açısı (radyan)',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (value) =>
                        parseLocalizedDouble(value ?? '') == null
                            ? 'Geçerli bir sayı girin'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<StationTurnDirection>(
                    initialValue: _turnDirection,
                    dropdownColor: const Color(0xFF222222),
                    decoration: _decoration('180° dönüş yönü'),
                    items: StationTurnDirection.values
                        .map(
                          (direction) => DropdownMenuItem(
                            value: direction,
                            child: Text(direction.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: widget.enabled && !widget.saving
                        ? (value) {
                            if (value != null) {
                              setState(() => _turnDirection = value);
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _durationController,
                    label: 'Geri şerit takip süresi (s)',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      final parsed = parseLocalizedDouble(value ?? '');
                      if (parsed == null) return 'Geçerli bir sayı girin';
                      if (parsed < 0.1 || parsed > 120) {
                        return '0,1–120 saniye arasında olmalı';
                      }
                      return null;
                    },
                  ),
                  if ((_localError ?? widget.backendError)?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _localError ?? widget.backendError!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: widget.enabled && !widget.saving
                        ? () => _save(config)
                        : null,
                    icon: widget.saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(widget.saving ? 'Kaydediliyor…' : 'Kaydet'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
  }) =>
      TextFormField(
        controller: controller,
        enabled: widget.enabled && !widget.saving,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: _decoration(label),
        validator: validator,
      );

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        filled: true,
        fillColor: const Color(0xFF131313),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF3A3A3A)),
        ),
        disabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF282828)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.lightBlueAccent),
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.redAccent),
        ),
      );

  Future<void> _save(StationApproachConfig original) async {
    setState(() => _localError = null);
    if (_formKey.currentState?.validate() != true) return;
    final yaw = parseLocalizedDouble(_yawController.text);
    final duration = parseLocalizedDouble(_durationController.text);
    if (yaw == null || duration == null) return;
    final config = original.copyWith(
      approachQrId: _qrController.text.trim(),
      dockHeadingYaw: yaw,
      turnDirection: _turnDirection,
      lineFollowDurationS: duration,
    );
    final saved = await context.read<GcsStationApproachModel>().save(config);
    if (!mounted) return;
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.stationId} ayarı kaydedildi')),
      );
    }
  }

  static String _formatNumber(double value) {
    final text = value.toStringAsFixed(6);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

class _MissingStation extends StatelessWidget {
  const _MissingStation({required this.stationId});

  final String stationId;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 190,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              stationId,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Icon(Icons.warning_amber, color: Colors.orangeAccent),
            const SizedBox(height: 8),
            const Text(
              'Yapılandırma eksik',
              style: TextStyle(color: Colors.orangeAccent),
            ),
            const SizedBox(height: 4),
            const Text(
              'ROS bu istasyon için ayar döndürmedi. Kayıt kapalı.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
}
