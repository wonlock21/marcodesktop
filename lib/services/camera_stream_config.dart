/// HTTP MJPEG kamera yayını — tek yapılandırma noktası.
///
/// Rosbridge üzerinden görüntü alınmaz; Orange Pi üzerindeki
/// `web_video_server` doğrudan HTTP ile kullanılır.
abstract final class CameraStreamConfig {
  static const String host = '100.76.148.66';
  static const int port = 8080;
  static const String topic = '/camera/image_raw';

  /// `web_video_server` topic içindeki `/` karakterinin `%2F` olmasını
  /// istemez; `Uri(queryParameters: …)` bunu bozduğu için elle birleştirilir.
  /// Örnek: `http://host:8080/stream?topic=/camera/image_raw`
  static String get streamUrl => 'http://$host:$port/stream?topic=$topic';

  static Uri get streamUri => Uri.parse(streamUrl);

  static String get displayEndpoint => '$host:$port';
}
