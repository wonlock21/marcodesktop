import 'package:flutter_test/flutter_test.dart';
import 'package:liftant_v2_bitirme/services/camera_stream_config.dart';

void main() {
  test('CameraStreamConfig topic slash encode etmeden /stream üretir', () {
    expect(
      CameraStreamConfig.streamUrl,
      'http://100.76.148.66:8080/stream?topic=/camera/image_raw',
    );
    expect(
        CameraStreamConfig.streamUri.toString(), CameraStreamConfig.streamUrl);
    // Uri.parse sonrası toString bazen encode edebilir; istek string'i ham olmalı.
    expect(CameraStreamConfig.streamUrl.contains('%2F'), isFalse);
    expect(CameraStreamConfig.streamUrl.contains('topic=/camera/'), isTrue);
  });
}
