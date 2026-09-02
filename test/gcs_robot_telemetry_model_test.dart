import 'package:flutter_test/flutter_test.dart';
import 'package:liftant_v2_bitirme/models/gcs_robot_telemetry_model.dart';

void main() {
  test('RobotStatus alanlarını tek canlı modelde ayrıştırır', () {
    final model = GcsRobotTelemetryModel();

    model.applyRobotStatus({
      'mission_state': 5,
      'mission_elapsed_s': 72.5,
      'status_detail': 'Başlangıca dönülüyor',
      'estop_active': false,
      'pose': {
        'pose': {
          'pose': {
            'position': {'x': 1.25, 'y': -2.5},
            'orientation': {'x': 0, 'y': 0, 'z': 0, 'w': 1},
          },
        },
      },
      'localization_valid': true,
      'position_covariance': 0.02,
      'current_route_edge': 'E12',
      'next_node': 'B1',
      'cross_track_error': 0.03,
      'obstacle_detected': false,
      'linear_speed': 0.21,
      'battery_voltage': 25.1,
      'battery_current': 3.4,
      'battery_temperature': 31.2,
      'task_id': 'T-7',
      'task_source': 'plc',
      'pickup_node': 'A1',
      'dropoff_node': 'B1',
      'route_nodes': ['S1', 'A1', 'B1'],
      'current_stop_index': 2,
      'return_home': true,
      'plc_connected': true,
      'gate_permission_granted': true,
      'manual_mode_enabled': false,
      'active_field_ready': true,
      'active_field_name': 'saha_01',
      'active_field_version': 'v4',
      'active_field_hash': 'abc123',
      'last_qr_data': 'QA1.1',
      'last_qr_detected': true,
      'last_qr_pose_in_camera': {'x': 0.1, 'y': -0.2, 'theta': 0.3},
      'last_qr_confidence': 0.96,
      'last_qr_camera_frame': 'camera_link',
      'last_qr_age_s': 0.2,
      'station_phase': 'LINE_FOLLOW_DOCKING',
      'qr_trigger_armed': true,
      'expected_qr_id': 'QA1.1',
      'qr_target_station': 'A1',
      'last_qr_reject_reason': '',
      'docking_target_station': 'A1',
      'docking_configured_duration_s': 8.0,
      'docking_elapsed_s': 3.0,
      'docking_remaining_s': 5.0,
      'docking_lane_control_active': true,
      'docking_camera_valid': true,
      'docking_stopped': false,
      'docking_error_reason': '',
    });

    expect(model.fresh, isTrue);
    expect(model.missionState, RobotMissionState.returningHome);
    expect(model.missionState.label, 'Başlangıca dönüyor');
    expect(model.missionElapsedS, 72.5);
    expect(model.pose.x, 1.25);
    expect(model.pose.y, -2.5);
    expect(model.routeNodes, ['S1', 'A1', 'B1']);
    expect(model.plcConnected, isTrue);
    expect(model.activeFieldHash, 'abc123');
    expect(model.lastQrPoseTheta, 0.3);
    expect(model.lastQrCameraFrame, 'camera_link');
    expect(model.manualModeHardwareSignal, isFalse);
    expect(model.stationPhaseLabel, 'Geri şerit takibi aktif');
    expect(model.dockingProgress, closeTo(0.375, 1e-9));
    expect(model.stationWarning, isNull);
  });

  test('istasyon uyarı önceliği ve tamamlanma fazı ROS durumuna bağlıdır', () {
    final model = GcsRobotTelemetryModel()
      ..applyRobotStatus({
        'station_phase': 'LINE_FOLLOW_DOCKING',
        'estop_active': true,
        'obstacle_detected': true,
        'localization_valid': false,
        'docking_camera_valid': false,
        'docking_lane_control_active': false,
        'docking_stopped': true,
        'docking_error_reason': 'dock hata',
        'last_qr_reject_reason': 'qr red',
      });

    expect(model.stationWarning, 'Acil Duruş');
    expect(model.stationOperationReady, isFalse);

    model.applyRobotStatus({
      'station_phase': 'PICKUP_READY',
      'localization_valid': true,
      'docking_stopped': false,
    });
    expect(model.stationOperationReady, isTrue);

    model.applyRobotStatus({
      'station_phase': 'IDLE',
      'localization_valid': true,
      'docking_camera_valid': false,
      'docking_lane_control_active': false,
    });
    expect(model.stationWarning, isNull);
  });

  test('yanaşma ilerlemesi ROS sürelerinden hesaplanır ve sınırlandırılır', () {
    final model = GcsRobotTelemetryModel()
      ..applyRobotStatus({
        'station_phase': 'LINE_FOLLOW_DOCKING',
        'localization_valid': true,
        'docking_configured_duration_s': 4.0,
        'docking_elapsed_s': 7.0,
        'docking_camera_valid': true,
        'docking_lane_control_active': true,
      });
    expect(model.dockingProgress, 1.0);

    model.applyRobotStatus(const {});
    expect(model.dockingProgress, 0.0);
    expect(model.stationWarning, isNull);
  });

  test('boş durum telemetriyi bayat işaretler', () {
    final model = GcsRobotTelemetryModel()
      ..applyRobotStatus({
        'mission_state': 2,
        'pose': {'x': 3, 'y': 4, 'theta': 1},
      });

    model.applyRobotStatus(const {});

    expect(model.fresh, isFalse);
    expect(model.pose.x, 3);
    expect(model.missionState, RobotMissionState.movingUnloaded);
  });

  test('mission/safety JSON metnini kullanıcı özetine çevirir', () {
    expect(
      GcsRobotTelemetryModel.summarizeJsonMessage(
        '{"event":"OBSTACLE","message":"Araç durdu","reason":"lidar"}',
      ),
      'Araç durdu · OBSTACLE · lidar',
    );

    final model = GcsRobotTelemetryModel()
      ..applySafetyState('{"state":"SAFE","detail":"Alan temiz"}');
    expect(model.safetyStateFresh, isTrue);
    expect(model.safetyStateSummary, 'Alan temiz · SAFE');

    model.applySafetyState(null);
    expect(model.safetyStateFresh, isFalse);
    expect(model.safetyStateRaw, isEmpty);
  });
}
