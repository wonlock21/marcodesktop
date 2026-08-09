import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:liftant_v2_bitirme/services/map_preview_layout.dart';

void main() {
  group('mapPreviewViewToPixel', () {
    test('contain merkez dokunuşu harita ortasına düşer', () {
      const view = Size(200, 100);
      const mapW = 100;
      const mapH = 100;
      // contain: scale=1, letterbox x=50
      final hit = mapPreviewViewToPixel(const Offset(100, 50), view, mapW, mapH);
      expect(hit.insideMap, isTrue);
      expect(hit.pixelX, closeTo(50, 0.01));
      expect(hit.pixelY, closeTo(50, 0.01));
    });

    test('letterbox dışı insideMap=false', () {
      const view = Size(200, 100);
      final hit = mapPreviewViewToPixel(const Offset(10, 50), view, 100, 100);
      expect(hit.insideMap, isFalse);
    });
  });
}
