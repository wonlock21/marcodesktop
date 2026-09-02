import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/gcs_connection_model.dart';
import 'models/gcs_field_graph_model.dart';
import 'models/gcs_mapping_model.dart';
import 'models/gcs_robot_telemetry_model.dart';
import 'services/ros_mapping_contract.dart';

const _bg = Color(0xFF121212);
const _panelBg = Color(0xFF1A1A1A);
const _borderC = Color(0xFF333333);
const _muted = Color(0xFF9E9E9E);
const _bright = Color(0xFFE0E0E0);
const _accent = Color(0xFF42A5F5);
const _success = Color(0xFF43A047);
const _danger = Color(0xFFE53935);

class DataPage extends StatelessWidget {
  final String site;

  const DataPage({super.key, required this.site});

  String _text(String value) => value.trim().isEmpty ? '--' : value.trim();

  String _number(double value, {String unit = '', int digits = 2}) =>
      value.isFinite ? '${value.toStringAsFixed(digits)}$unit' : '--';

  String _yesNo(bool value) => value ? 'Evet' : 'Hayır';

  String _elapsed(double seconds) {
    if (!seconds.isFinite || seconds < 0) return '--';
    final total = seconds.floor();
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final remaining = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$remaining (${seconds.toStringAsFixed(1)} s)';
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = context.watch<GcsRobotTelemetryModel>();
    final connection = context.watch<GcsConnectionModel>();
    final mapping = context.watch<GcsMappingModel>();
    final fields = context.watch<GcsFieldGraphModel>();
    final live = telemetry.fresh && connection.robotBaglanti.aktif;

    String liveText(String value) => live ? _text(value) : '--';
    String liveNumber(double value, {String unit = '', int digits = 2}) =>
        live ? _number(value, unit: unit, digits: digits) : '--';
    String liveBool(bool value) => live ? _yesNo(value) : '--';

    final mappingStatus = mapping.liveMappingStatus;
    final localizationStatus = mapping.liveLocalizationStatus;
    final package = fields.packageStatusFresh ? fields.packageStatus : null;
    final active = fields.activeFresh ? fields.activeField : null;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _panelBg,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('ROS TELEMETRİ VE DURUMLAR'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FreshnessBanner(
              fresh: live,
              address: site,
              receivedAt: telemetry.receivedAt,
            ),
            const SizedBox(height: 12),
            _DataSection(
              title: 'GÖREV',
              items: [
                _DataItem(
                  'mission_state',
                  live
                      ? '${telemetry.missionState.code} · ${telemetry.missionState.label}'
                      : '--',
                ),
                _DataItem(
                  'mission_elapsed_s',
                  live ? _elapsed(telemetry.missionElapsedS) : '--',
                ),
                _DataItem('status_detail', liveText(telemetry.statusDetail)),
                _DataItem('task_id', liveText(telemetry.taskId)),
                _DataItem('task_source', liveText(telemetry.taskSource)),
                _DataItem('pickup_node', liveText(telemetry.pickupNode)),
                _DataItem('dropoff_node', liveText(telemetry.dropoffNode)),
                _DataItem(
                  'route_nodes',
                  live && telemetry.routeNodes.isNotEmpty
                      ? telemetry.routeNodes.join(' → ')
                      : '--',
                ),
                _DataItem(
                  'current_stop_index',
                  live ? telemetry.currentStopIndex.toString() : '--',
                ),
                _DataItem('return_home', liveBool(telemetry.returnHome)),
              ],
            ),
            _DataSection(
              title: 'KONUM VE NAVİGASYON',
              items: [
                _DataItem('pose.x', liveNumber(telemetry.pose.x, unit: ' m')),
                _DataItem('pose.y', liveNumber(telemetry.pose.y, unit: ' m')),
                _DataItem(
                  'pose.yaw',
                  liveNumber(telemetry.pose.yaw, unit: ' rad', digits: 3),
                ),
                _DataItem(
                  'localization_valid',
                  liveBool(telemetry.localizationValid),
                ),
                _DataItem(
                  'position_covariance',
                  liveNumber(telemetry.positionCovariance, digits: 5),
                ),
                _DataItem(
                  'current_route_edge',
                  liveText(telemetry.currentRouteEdge),
                ),
                _DataItem('next_node', liveText(telemetry.nextNode)),
                _DataItem(
                  'cross_track_error',
                  liveNumber(telemetry.crossTrackError, unit: ' m', digits: 3),
                ),
                _DataItem(
                  'obstacle_detected',
                  liveBool(telemetry.obstacleDetected),
                  color: live && telemetry.obstacleDetected ? _danger : null,
                ),
                _DataItem(
                  'linear_speed',
                  liveNumber(telemetry.linearSpeed, unit: ' m/s'),
                ),
              ],
            ),
            _DataSection(
              title: 'GÜÇ VE GÜVENLİK',
              items: [
                _DataItem(
                  'battery_voltage',
                  liveNumber(telemetry.batteryVoltage, unit: ' V'),
                ),
                _DataItem(
                  'battery_current',
                  liveNumber(telemetry.batteryCurrent, unit: ' A'),
                ),
                _DataItem(
                  'battery_temperature',
                  liveNumber(telemetry.batteryTemperature, unit: ' °C'),
                ),
                _DataItem(
                  'estop_active',
                  liveBool(telemetry.estopActive),
                  color: live && telemetry.estopActive ? _danger : null,
                ),
                _DataItem(
                  '/safety/state',
                  telemetry.safetyStateFresh && live
                      ? _text(telemetry.safetyStateSummary)
                      : '--',
                ),
                const _DataItem(
                  'manual_mode_enabled',
                  'Donanım bekleniyor · yetkilendirmede kullanılmıyor',
                ),
              ],
            ),
            _DataSection(
              title: 'QR',
              items: [
                _DataItem('last_qr_data', liveText(telemetry.lastQrData)),
                _DataItem(
                  'last_qr_detected',
                  liveBool(telemetry.lastQrDetected),
                ),
                _DataItem(
                  'last_qr_pose_in_camera.x',
                  liveNumber(telemetry.lastQrPoseX, unit: ' m', digits: 3),
                ),
                _DataItem(
                  'last_qr_pose_in_camera.y',
                  liveNumber(telemetry.lastQrPoseY, unit: ' m', digits: 3),
                ),
                _DataItem(
                  'last_qr_pose_in_camera.theta',
                  liveNumber(telemetry.lastQrPoseTheta,
                      unit: ' rad', digits: 3),
                ),
                _DataItem(
                  'last_qr_confidence',
                  liveNumber(telemetry.lastQrConfidence, digits: 3),
                ),
                _DataItem(
                  'last_qr_camera_frame',
                  liveText(telemetry.lastQrCameraFrame),
                ),
                _DataItem(
                  'last_qr_age_s',
                  liveNumber(telemetry.lastQrAgeS, unit: ' s', digits: 2),
                ),
              ],
            ),
            _DataSection(
              title: 'PLC VE AKTİF SAHA',
              items: [
                _DataItem(
                  'plc_connected',
                  liveBool(telemetry.plcConnected),
                  color: live && telemetry.plcConnected ? _success : null,
                ),
                _DataItem(
                  'gate_permission_granted',
                  liveBool(telemetry.gatePermissionGranted),
                ),
                const _DataItem(
                  'PLC RX/TX geçmişi',
                  'PLC ayrıntılı mesaj geçmişi henüz bağlı değil',
                ),
                _DataItem(
                  'active_field_ready',
                  liveBool(telemetry.activeFieldReady),
                ),
                _DataItem(
                  'active_field_name',
                  liveText(telemetry.activeFieldName),
                ),
                _DataItem(
                  'active_field_version',
                  liveText(telemetry.activeFieldVersion),
                ),
                _DataItem(
                  'active_field_hash',
                  liveText(telemetry.activeFieldHash),
                ),
              ],
            ),
            _DataSection(
              title: 'EK ROS DURUMLARI',
              items: [
                _DataItem(
                  '/mapping/status',
                  mappingStatus == null
                      ? '-- (bayat veya bekleniyor)'
                      : '${mappingStatus.etiket}${mapping.mappingMessage.isEmpty ? '' : ' · ${mapping.mappingMessage}'}',
                ),
                _DataItem(
                  '/localization/status',
                  localizationStatus == null
                      ? '-- (bayat veya bekleniyor)'
                      : '${localizationStatus.etiket}${mapping.localizationMessage.isEmpty ? '' : ' · ${mapping.localizationMessage}'}',
                ),
                _DataItem(
                  '/fields/package_status',
                  package == null
                      ? '-- (bayat veya bekleniyor)'
                      : '${package.state.name.toUpperCase()} · ${package.fieldName} · ${package.nodeCount} node / ${package.edgeCount} edge',
                ),
                _DataItem(
                  '/fields/active',
                  active == null
                      ? '-- (bayat veya bekleniyor)'
                      : active.active
                          ? '${active.fieldName} · ${active.packageVersion} · ${active.packageHash}'
                          : 'Aktif saha yok',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

@immutable
class _DataItem {
  final String label;
  final String value;
  final Color? color;

  const _DataItem(this.label, this.value, {this.color});
}

class _DataSection extends StatelessWidget {
  final String title;
  final List<_DataItem> items;

  const _DataSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _panelBg,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: _borderC),
        borderRadius: BorderRadius.circular(6),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _accent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1000
                    ? 4
                    : constraints.maxWidth >= 650
                        ? 3
                        : constraints.maxWidth >= 420
                            ? 2
                            : 1;
                final width =
                    (constraints.maxWidth - ((columns - 1) * 8)) / columns;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in items)
                      SizedBox(
                        width: width,
                        child: _ValueTile(item: item),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueTile extends StatelessWidget {
  final _DataItem item;

  const _ValueTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _bg,
        border: Border.all(color: _borderC),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 5),
          SelectableText(
            item.value,
            style: TextStyle(
              color: item.color ?? _bright,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FreshnessBanner extends StatelessWidget {
  final bool fresh;
  final String address;
  final DateTime? receivedAt;

  const _FreshnessBanner({
    required this.fresh,
    required this.address,
    required this.receivedAt,
  });

  @override
  Widget build(BuildContext context) {
    final color = fresh ? _success : _danger;
    final time = receivedAt == null
        ? '--'
        : '${receivedAt!.hour.toString().padLeft(2, '0')}:'
            '${receivedAt!.minute.toString().padLeft(2, '0')}:'
            '${receivedAt!.second.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(fresh ? Icons.check_circle : Icons.warning_amber, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fresh
                  ? 'Canlı telemetri · $address · son mesaj $time'
                  : 'Bağlantı/telemetri bayat · eski değerler gizlendi',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
