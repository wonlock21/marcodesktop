import 'package:flutter_test/flutter_test.dart';
import 'package:liftant_v2_bitirme/services/camera_stream_config.dart';

void main() {
  test('Robot adresi camera HTTP 8080 endpointine çevrilir; topic korunur', () {
    for (final host in ['robot.local', '192.168.4.3']) {
      final uri = CameraStreamConfig.forRobot('ws://$host:9090');
      expect(
        uri.toString(),
        'http://$host:8080/stream?topic=/camera/image_raw'
        '&type=ros_compressed&qos_profile=sensor_data',
      );
      expect(uri.toString(), isNot(contains('%2F')));
    }
    expect(CameraStreamConfig.forRobot('ws://[::1]:9090').host, '::1');
  });

  test('Şerit takip kamerası robot adresindeki aynı HTTP sunucusunu kullanır',
      () {
    const host = 'robot.local';
    final uri = CameraStreamConfig.forRobot(
      'ws://$host:9090',
      topic: CameraStreamConfig.laneTrackingTopic,
    );

    expect(
      uri.toString(),
      'http://$host:8080/stream?topic=/lane_tracking/debug'
      '&type=ros_compressed&qos_profile=sensor_data',
    );
  });
}
