import 'ros_bridge_client.dart';

/// HTTP camera viewer uses the same robot host, its own port and endpoint.
abstract final class CameraStreamConfig {
  static const int port = 8080;
  static const String topic = '/camera/image_raw';
  static Uri forRobot(String address) {
    final host = RosBridgeClient.normalizeAddress(address).host;
    final authority = host.contains(':') ? '[$host]' : host;
    return Uri.parse('http://$authority:$port/stream?topic=$topic');
  }
}
