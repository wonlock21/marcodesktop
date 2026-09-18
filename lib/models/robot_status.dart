/// Wire snapshot of marco_msgs/msg/RobotStatus used by the production GUI.
/// Missing/wrong-typed data remains unknown; it never grants command authority.
class RobotStatus {
  final Map<String, dynamic> raw;
  RobotStatus.fromRosJson(Map<String, dynamic> json)
      : raw = Map.unmodifiable(json);
  bool get valid =>
      raw['mission_state'] is int &&
      (raw['mission_state'] as int) >= 0 &&
      (raw['mission_state'] as int) <= 7 &&
      raw['linear_speed'] is num &&
      (raw['linear_speed'] as num).isFinite &&
      raw['task_id'] is String &&
      raw['task_source'] is String &&
      raw['estop_active'] is bool;
  String _string(String key) => raw[key] is String ? raw[key] as String : '';
  bool _bool(String key) => raw[key] == true;
  int _int(String key) => raw[key] is int ? raw[key] as int : 0;
  double _number(String key) =>
      raw[key] is num ? (raw[key] as num).toDouble() : double.nan;
  Map<String, dynamic> _map(String key) => raw[key] is Map
      ? Map<String, dynamic>.unmodifiable(raw[key] as Map)
      : const {};
  Map<String, dynamic> get header => _map('header');
  int get missionState => _int('mission_state');
  double get missionElapsedS => _number('mission_elapsed_s');
  String get statusDetail => _string('status_detail');
  bool get manualModeEnabled => _bool('manual_mode_enabled');
  bool get estopActive => _bool('estop_active');
  Map<String, dynamic> get pose => _map('pose');
  bool get localizationValid => _bool('localization_valid');
  double get positionCovariance => _number('position_covariance');
  String get currentRouteEdge => _string('current_route_edge');
  String get nextNode => _string('next_node');
  double get crossTrackError => _number('cross_track_error');
  double get routeSpeedLimit => _number('route_speed_limit');
  String get routeGuardState => _string('route_guard_state');
  String get routeStopReason => _string('route_stop_reason');
  List<int> get selectedRouteEdges => raw['selected_route_edges'] is List
      ? List.unmodifiable(
          (raw['selected_route_edges'] as List).whereType<int>())
      : const [];
  bool get obstacleDetected => _bool('obstacle_detected');
  double get linearSpeed => _number('linear_speed');
  double get batteryVoltage => _number('battery_voltage');
  double get batteryCurrent => _number('battery_current');
  double get batteryTemperature => _number('battery_temperature');
  String get taskId => _string('task_id');
  String get taskSource => _string('task_source');
  bool get missionResumable => _bool('mission_resumable');
  String get pickupNode => _string('pickup_node');
  String get dropoffNode => _string('dropoff_node');
  List<String> get routeNodes => raw['route_nodes'] is List
      ? List.unmodifiable((raw['route_nodes'] as List).whereType<String>())
      : const [];
  int get currentStopIndex => _int('current_stop_index');
  bool get returnHome => _bool('return_home');
  String get lastQrData => _string('last_qr_data');
  bool get lastQrDetected => _bool('last_qr_detected');
  Map<String, dynamic> get lastQrPoseInCamera => _map('last_qr_pose_in_camera');
  double get lastQrConfidence => _number('last_qr_confidence');
  String get lastQrCameraFrame => _string('last_qr_camera_frame');
  double get lastQrAgeS => _number('last_qr_age_s');
  bool get qrTriggerArmed => _bool('qr_trigger_armed');
  String get expectedQrId => _string('expected_qr_id');
  String get qrTargetStation => _string('qr_target_station');
  String get lastQrRejectReason => _string('last_qr_reject_reason');
  bool get plcConnected => _bool('plc_connected');
  bool get gatePermissionGranted => _bool('gate_permission_granted');
  String get gateEntryNode => _string('gate_entry_node');
  String get gateDirection => _string('gate_direction');
  String get gateCrossingId => _string('gate_crossing_id');
  String get stationPhase => _string('station_phase');
  String get dockingTargetStation => _string('docking_target_station');
  double get dockingConfiguredDurationS =>
      _number('docking_configured_duration_s');
  double get dockingElapsedS => _number('docking_elapsed_s');
  double get dockingRemainingS => _number('docking_remaining_s');
  bool get dockingLaneControlActive => _bool('docking_lane_control_active');
  bool get dockingCameraValid => _bool('docking_camera_valid');
  bool get dockingStopped => _bool('docking_stopped');
  String get dockingErrorReason => _string('docking_error_reason');
  bool get activeFieldReady => _bool('active_field_ready');
  String get activeFieldName => _string('active_field_name');
  String get activeFieldVersion => _string('active_field_version');
  String get activeFieldHash => _string('active_field_hash');

  /// Operator-facing labels derived only from `/robot_status` wire values.
  String get missionStateLabel => switch (missionState) {
        0 => 'Göreve Hazır',
        1 => 'Görev Alındı / İşleniyor',
        2 => 'Yüksüz Hareket',
        3 => 'Yüklü Hareket',
        4 => 'Fabrika Otomasyon Sistemi İzni Bekleniyor',
        5 => 'Başlangıç Noktasına Dönüyor',
        6 => 'Hata',
        7 => 'Acil Stop',
        _ => 'Bilinmeyen Durum',
      };

  String get taskSourceLabel => switch (taskSource) {
        'plc' => 'PLC',
        'mock_plc' => 'Test PLC',
        'gui' => 'GUI',
        '' => '',
        _ => taskSource,
      };

  bool get gateActive =>
      missionState == 4 ||
      gatePermissionGranted ||
      gateEntryNode.isNotEmpty ||
      gateDirection.isNotEmpty;

  String get gateDirectionLabel => switch (gateDirection) {
        'outbound' => 'Gidiş',
        'return' => 'Dönüş',
        _ => '-',
      };

  String get gatePermissionLabel {
    if (!gateActive) return 'Aktif Değil';
    return gatePermissionGranted ? 'Verildi' : 'Bekleniyor';
  }
}
