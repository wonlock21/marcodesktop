import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

enum RobotMissionState {
  idle(0, 'Boşta'),
  accepted(1, 'Görev alındı'),
  movingUnloaded(2, 'Yüksüz hareket'),
  movingLoaded(3, 'Yüklü hareket'),
  waitingPlc(4, 'PLC bekleniyor'),
  returningHome(5, 'Başlangıca dönüyor'),
  error(6, 'Hata'),
  estop(7, 'E-stop');

  final int code;
  final String label;

  const RobotMissionState(this.code, this.label);

  static RobotMissionState fromCode(dynamic value) {
    final code = value is num ? value.toInt() : -1;
    return values.firstWhere(
      (state) => state.code == code,
      orElse: () => RobotMissionState.error,
    );
  }

  bool get active => code >= 1 && code <= 5;
}

@immutable
class RobotTelemetryPose {
  final double x;
  final double y;
  final double yaw;

  const RobotTelemetryPose({
    required this.x,
    required this.y,
    required this.yaw,
  });

  static const zero = RobotTelemetryPose(x: 0, y: 0, yaw: 0);
}

/// `/robot_status` için PC ve Android'de ortak kullanılan canlı görünüm.
///
/// Son değerler teşhis amacıyla bellekte tutulabilir; [fresh] false iken UI
/// bunları canlı veya güvenli veri olarak göstermemelidir.
class GcsRobotTelemetryModel extends ChangeNotifier {
  bool fresh = false;
  DateTime? receivedAt;

  RobotMissionState missionState = RobotMissionState.idle;
  double missionElapsedS = 0;
  String statusDetail = '';
  bool estopActive = false;
  RobotTelemetryPose pose = RobotTelemetryPose.zero;
  bool localizationValid = false;
  double positionCovariance = double.infinity;
  String currentRouteEdge = '';
  String nextNode = '';
  double crossTrackError = double.nan;
  bool obstacleDetected = false;
  double linearSpeed = double.nan;
  double batteryVoltage = double.nan;
  double batteryCurrent = double.nan;
  double batteryTemperature = double.nan;

  String taskId = '';
  String taskSource = '';
  String pickupNode = '';
  String dropoffNode = '';
  List<String> routeNodes = const [];
  int currentStopIndex = 0;
  bool returnHome = false;

  bool plcConnected = false;
  bool gatePermissionGranted = false;

  /// Araçta fiziksel mod switch'i olmadığı için yalnız teşhis amacıyla tutulur.
  /// Manuel sürüş yetkilendirmesinde kullanılmaz.
  bool manualModeHardwareSignal = false;

  bool activeFieldReady = false;
  String activeFieldName = '';
  String activeFieldVersion = '';
  String activeFieldHash = '';

  String lastQrData = '';
  bool lastQrDetected = false;
  double lastQrPoseX = double.nan;
  double lastQrPoseY = double.nan;
  double lastQrPoseTheta = double.nan;
  double lastQrConfidence = double.nan;
  String lastQrCameraFrame = '';
  double lastQrAgeS = double.nan;

  String stationPhase = 'IDLE';
  bool qrTriggerArmed = false;
  String expectedQrId = '';
  String qrTargetStation = '';
  String lastQrRejectReason = '';
  String dockingTargetStation = '';
  double dockingConfiguredDurationS = double.nan;
  double dockingElapsedS = double.nan;
  double dockingRemainingS = double.nan;
  bool dockingLaneControlActive = false;
  bool dockingCameraValid = false;
  bool dockingStopped = false;
  String dockingErrorReason = '';

  bool safetyStateFresh = false;
  String safetyStateRaw = '';
  String safetyStateSummary = '';

  void applyRobotStatus(Map<String, dynamic> status) {
    if (status.isEmpty) {
      markRobotStatusStale();
      return;
    }

    fresh = true;
    receivedAt = DateTime.now();
    missionState = RobotMissionState.fromCode(status['mission_state']);
    missionElapsedS = _number(status['mission_elapsed_s']);
    statusDetail = _string(status['status_detail']);
    estopActive = status['estop_active'] == true;
    pose = _pose(status['pose']);
    localizationValid = status['localization_valid'] == true;
    positionCovariance = _number(
      status['position_covariance'],
      double.infinity,
    );
    currentRouteEdge = _string(status['current_route_edge']);
    nextNode = _string(status['next_node']);
    crossTrackError = _number(status['cross_track_error'], double.nan);
    obstacleDetected = status['obstacle_detected'] == true;
    linearSpeed = _number(status['linear_speed'], double.nan);
    batteryVoltage = _number(status['battery_voltage'], double.nan);
    batteryCurrent = _number(status['battery_current'], double.nan);
    batteryTemperature = _number(status['battery_temperature'], double.nan);

    taskId = _string(status['task_id']);
    taskSource = _string(status['task_source']);
    pickupNode = _string(status['pickup_node']);
    dropoffNode = _string(status['dropoff_node']);
    final rawRoute = status['route_nodes'];
    routeNodes = rawRoute is List
        ? List.unmodifiable(rawRoute.map((node) => node.toString()))
        : const [];
    currentStopIndex = status['current_stop_index'] is num
        ? (status['current_stop_index'] as num).toInt()
        : 0;
    returnHome = status['return_home'] == true;

    plcConnected = status['plc_connected'] == true;
    gatePermissionGranted = status['gate_permission_granted'] == true;
    manualModeHardwareSignal = status['manual_mode_enabled'] == true;
    activeFieldReady = status['active_field_ready'] == true;
    activeFieldName = _string(status['active_field_name']);
    activeFieldVersion = _string(status['active_field_version']);
    activeFieldHash = _string(status['active_field_hash']);

    lastQrData = _string(status['last_qr_data']);
    lastQrDetected = status['last_qr_detected'] == true;
    final qrPose = status['last_qr_pose_in_camera'];
    if (qrPose is Map) {
      lastQrPoseX = _number(qrPose['x'], double.nan);
      lastQrPoseY = _number(qrPose['y'], double.nan);
      lastQrPoseTheta = _number(qrPose['theta'], double.nan);
    } else {
      lastQrPoseX = double.nan;
      lastQrPoseY = double.nan;
      lastQrPoseTheta = double.nan;
    }
    lastQrConfidence = _number(status['last_qr_confidence'], double.nan);
    lastQrCameraFrame = _string(status['last_qr_camera_frame']);
    lastQrAgeS = _number(status['last_qr_age_s'], double.nan);

    stationPhase = _string(status['station_phase']);
    if (stationPhase.isEmpty) stationPhase = 'IDLE';
    qrTriggerArmed = status['qr_trigger_armed'] == true;
    expectedQrId = _string(status['expected_qr_id']);
    qrTargetStation = _string(status['qr_target_station']);
    lastQrRejectReason = _string(status['last_qr_reject_reason']);
    dockingTargetStation = _string(status['docking_target_station']);
    dockingConfiguredDurationS = _number(
      status['docking_configured_duration_s'],
      double.nan,
    );
    dockingElapsedS = _number(status['docking_elapsed_s'], double.nan);
    dockingRemainingS = _number(status['docking_remaining_s'], double.nan);
    dockingLaneControlActive = status['docking_lane_control_active'] == true;
    dockingCameraValid = status['docking_camera_valid'] == true;
    dockingStopped = status['docking_stopped'] == true;
    dockingErrorReason = _string(status['docking_error_reason']);
    notifyListeners();
  }

  String get stationPhaseLabel => switch (stationPhase) {
        'IDLE' => 'Beklemede',
        'APPROACHING_STATION' => 'İstasyona yaklaşıyor',
        'QR_VERIFIED' => 'Hedef QR doğrulandı',
        'TURNING_180' => '180° dönüş yapılıyor',
        'LINE_FOLLOW_READY' => 'Geri şerit takibine hazır',
        'LINE_FOLLOW_DOCKING' => 'Geri şerit takibi aktif',
        'PICKUP_READY' => 'Yük almaya hazır',
        'DROPOFF_READY' => 'Yük bırakmaya hazır',
        'EXITING_STATION' => 'İstasyondan ileri çıkıyor',
        _ => stationPhase,
      };

  bool get stationOperationReady =>
      fresh &&
      (stationPhase == 'PICKUP_READY' || stationPhase == 'DROPOFF_READY');

  bool get isDockingPhase => fresh && stationPhase == 'LINE_FOLLOW_DOCKING';

  double get dockingProgress {
    if (!fresh ||
        !dockingConfiguredDurationS.isFinite ||
        dockingConfiguredDurationS <= 0 ||
        !dockingElapsedS.isFinite) {
      return 0;
    }
    return (dockingElapsedS / dockingConfiguredDurationS).clamp(0.0, 1.0);
  }

  String? get stationWarning {
    // Bağlantı/telemetri durumu ana durum alanlarında zaten gösteriliyor.
    // İstasyon kartında aynı uyarıyı tekrar üretme.
    if (!fresh) return null;
    if (estopActive) return 'Acil Duruş';
    if (obstacleDetected) return 'Engel Algılandı';
    if (!localizationValid) return 'Lokalizasyon geçersiz';
    if (isDockingPhase && !dockingCameraValid) {
      return 'Arka kamera verisi geçersiz';
    }
    if (isDockingPhase && !dockingLaneControlActive) {
      return 'Yanaşma şerit kontrolü aktif değil';
    }
    if (dockingErrorReason.isNotEmpty) return dockingErrorReason;
    if (lastQrRejectReason.isNotEmpty) return lastQrRejectReason;
    return null;
  }

  void markRobotStatusStale() {
    if (!fresh) return;
    fresh = false;
    notifyListeners();
  }

  void applySafetyState(String? payload) {
    if (payload == null) {
      if (!safetyStateFresh && safetyStateRaw.isEmpty) return;
      safetyStateFresh = false;
      safetyStateRaw = '';
      safetyStateSummary = '';
      notifyListeners();
      return;
    }
    safetyStateFresh = true;
    safetyStateRaw = payload;
    safetyStateSummary = summarizeJsonMessage(payload);
    notifyListeners();
  }

  static String summarizeJsonMessage(String payload) {
    final text = payload.trim();
    if (text.isEmpty) return '';
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return text;
      const preferred = [
        'message',
        'detail',
        'status_detail',
        'event',
        'type',
        'state',
        'reason',
      ];
      final parts = <String>[];
      for (final key in preferred) {
        final value = decoded[key];
        if (value == null || value.toString().trim().isEmpty) continue;
        final item = value.toString().trim();
        if (!parts.contains(item)) parts.add(item);
      }
      return parts.isEmpty ? text : parts.join(' · ');
    } catch (_) {
      return text;
    }
  }

  static double _number(dynamic value, [double fallback = 0]) =>
      value is num ? value.toDouble() : fallback;

  static String _string(dynamic value) => value?.toString().trim() ?? '';

  static RobotTelemetryPose _pose(dynamic raw) {
    if (raw is! Map) return RobotTelemetryPose.zero;
    Map<dynamic, dynamic> pose = raw;
    final firstPose = pose['pose'];
    if (firstPose is Map) pose = firstPose;
    final secondPose = pose['pose'];
    if (secondPose is Map) pose = secondPose;

    if (pose['x'] is num && pose['y'] is num) {
      return RobotTelemetryPose(
        x: _number(pose['x']),
        y: _number(pose['y']),
        yaw: _number(pose['theta']),
      );
    }

    final position = pose['position'];
    final orientation = pose['orientation'];
    if (position is! Map) return RobotTelemetryPose.zero;
    final qx = orientation is Map ? _number(orientation['x']) : 0.0;
    final qy = orientation is Map ? _number(orientation['y']) : 0.0;
    final qz = orientation is Map ? _number(orientation['z']) : 0.0;
    final qw = orientation is Map ? _number(orientation['w'], 1) : 1.0;
    final yaw = math.atan2(
      2 * (qw * qz + qx * qy),
      1 - 2 * (qy * qy + qz * qz),
    );
    return RobotTelemetryPose(
      x: _number(position['x']),
      y: _number(position['y']),
      yaw: yaw,
    );
  }
}
