import 'package:flutter/material.dart';

import '../models/gcs_robot_telemetry_model.dart';

class StationApproachStatusCard extends StatelessWidget {
  const StationApproachStatusCard({
    super.key,
    required this.telemetry,
  });

  final GcsRobotTelemetryModel telemetry;

  static const _panel = Color(0xFF171717);
  static const _border = Color(0xFF333333);
  static const _muted = Color(0xFF8B8B8B);
  static const _bright = Color(0xFFE5E5E5);
  static const _accent = Color(0xFF42A5F5);
  static const _success = Color(0xFF43A047);
  static const _warning = Color(0xFFFFA726);
  static const _danger = Color(0xFFEF5350);

  @override
  Widget build(BuildContext context) {
    final fresh = telemetry.fresh;
    final ready = telemetry.stationOperationReady;
    final warning = telemetry.stationWarning;
    final target = telemetry.dockingTargetStation.isNotEmpty
        ? telemetry.dockingTargetStation
        : telemetry.qrTargetStation;
    final idle = telemetry.stationPhase == 'IDLE';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                ready ? Icons.check_circle : Icons.precision_manufacturing,
                color: !fresh
                    ? _muted
                    : ready
                        ? _success
                        : _accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'İSTASYONA YAKLAŞMA DURUMU',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            fresh ? telemetry.stationPhaseLabel : 'Beklemede',
            style: TextStyle(
              color: !fresh
                  ? _muted
                  : ready
                      ? _success
                      : _bright,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _rows([
            ('Aktif saha', fresh ? _text(telemetry.activeFieldName) : '--'),
            ('Hedef istasyon', fresh ? _text(target) : '--'),
            ('Beklenen QR', fresh ? _text(telemetry.expectedQrId) : '--'),
            ('Son QR', fresh ? _text(telemetry.lastQrData) : '--'),
            (
              'QR tetikleme',
              fresh ? (telemetry.qrTriggerArmed ? 'Kurulu' : 'Kapalı') : '--'
            ),
            (
              'Line kontrol',
              fresh && !idle
                  ? (telemetry.dockingLaneControlActive ? 'Aktif' : 'Pasif')
                  : '--'
            ),
            (
              'Arka kamera',
              fresh && !idle
                  ? (telemetry.dockingCameraValid ? 'Geçerli' : 'Geçersiz')
                  : '--'
            ),
            (
              'Araç',
              fresh && !idle
                  ? (telemetry.dockingStopped ? 'Durdu' : 'Hareket ediyor')
                  : '--'
            ),
            (
              'Doğrusal hız',
              fresh && telemetry.linearSpeed.isFinite
                  ? '${telemetry.linearSpeed.toStringAsFixed(2)} m/s'
                  : '--'
            ),
          ]),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _timeValue(
                  'Ayar',
                  fresh ? telemetry.dockingConfiguredDurationS : double.nan,
                ),
              ),
              Expanded(
                child: _timeValue(
                  'Geçen',
                  fresh ? telemetry.dockingElapsedS : double.nan,
                ),
              ),
              Expanded(
                child: _timeValue(
                  'Kalan',
                  fresh ? telemetry.dockingRemainingS : double.nan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: fresh ? telemetry.dockingProgress : 0,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            backgroundColor: const Color(0xFF292929),
            valueColor: AlwaysStoppedAnimation<Color>(
              ready ? _success : _accent,
            ),
          ),
          if (warning != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: (telemetry.estopActive ? _danger : _warning)
                    .withValues(alpha: 0.12),
                border: Border.all(
                  color: telemetry.estopActive ? _danger : _warning,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                warning,
                style: TextStyle(
                  color: telemetry.estopActive ? _danger : _warning,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rows(List<(String, String)> values) => Column(
        children: [
          for (final item in values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.$1,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      item.$2,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _bright,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );

  Widget _timeValue(String label, double value) => Column(
        children: [
          Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value.isFinite ? '${value.toStringAsFixed(1)} s' : '--',
            style: const TextStyle(
              color: _bright,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      );

  static String _text(String value) => value.trim().isEmpty ? '--' : value;
}
