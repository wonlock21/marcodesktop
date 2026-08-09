import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'ros_gcs_contract.dart';

/// Isolate çıktısı: metadata her zaman (mümkünse); frame yalnız data tam ise.
class OccupancyParseResult {
  final OccupancyGridMetadata? metadata;
  final OccupancyGridFrame? frame;

  const OccupancyParseResult({this.metadata, this.frame});
}

/// Isolate'e gönderilebilir OccupancyGrid → RGBA paketı.
class OccupancyRgbaPayload {
  final int width;
  final int height;
  final double resolution;
  final double originX;
  final double originY;
  final double originYaw;
  final Uint8List rgba;

  const OccupancyRgbaPayload({
    required this.width,
    required this.height,
    required this.resolution,
    required this.originX,
    required this.originY,
    required this.originYaw,
    required this.rgba,
  });

  OccupancyGridMetadata get metadata => OccupancyGridMetadata(
        resolution: resolution,
        width: width,
        height: height,
        originX: originX,
        originY: originY,
        originYaw: originYaw,
      );
}

/// Top-level: rosbridge OccupancyGrid `msg` map → frame (compute uyumlu).
OccupancyGridFrame? occupancyMessageToFrame(Map<String, dynamic> message) {
  try {
    final frame = OccupancyGridFrame.fromRosMessage(message);
    return frame.isComplete ? frame : null;
  } catch (_) {
    return null;
  }
}

/// Top-level: ham rosbridge publish envelope string → parse (UI thread yok).
///
/// Ana isolate'de `jsonDecode` yapılmaz; büyük `/map` JSON'u burada açılır.
OccupancyParseResult occupancyEnvelopeToResult(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const OccupancyParseResult();
    final msg = decoded['msg'];
    if (msg is! Map) return const OccupancyParseResult();
    final message = Map<String, dynamic>.from(msg);

    OccupancyGridMetadata? metadata;
    try {
      metadata = OccupancyGridMetadata.fromRosMessage(message);
    } catch (_) {
      return const OccupancyParseResult();
    }

    OccupancyGridFrame? frame;
    try {
      final parsed = OccupancyGridFrame.fromRosMessage(message);
      if (parsed.isComplete) frame = parsed;
    } catch (_) {
      // Metadata geçerli, data eksik/bozuk olabilir.
    }
    return OccupancyParseResult(metadata: metadata, frame: frame);
  } catch (_) {
    return const OccupancyParseResult();
  }
}

Future<OccupancyParseResult> parseOccupancyEnvelopeInIsolate(String raw) =>
    compute(occupancyEnvelopeToResult, raw);

Future<OccupancyGridFrame?> parseOccupancyInIsolate(
  Map<String, dynamic> message,
) =>
    compute(occupancyMessageToFrame, message);

/// Frame → RGBA (ana isolate veya compute içinde).
OccupancyRgbaPayload frameToRgbaPayload(OccupancyGridFrame frame) {
  final meta = frame.metadata;
  final rgba = Uint8List(meta.width * meta.height * 4);
  for (var j = 0; j < meta.height; j++) {
    final imageRow = meta.height - 1 - j;
    for (var i = 0; i < meta.width; i++) {
      final occ = frame.data[j * meta.width + i];
      final gray = OccupancyGridMetadata.occupancyToGray(occ);
      final offset = (imageRow * meta.width + i) * 4;
      rgba[offset] = gray;
      rgba[offset + 1] = gray;
      rgba[offset + 2] = gray;
      rgba[offset + 3] = 0xFF;
    }
  }
  return OccupancyRgbaPayload(
    width: meta.width,
    height: meta.height,
    resolution: meta.resolution,
    originX: meta.originX,
    originY: meta.originY,
    originYaw: meta.originYaw,
    rgba: rgba,
  );
}

Future<ui.Image> rgbaPayloadToImage(OccupancyRgbaPayload payload) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    payload.rgba,
    payload.width,
    payload.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

/// Frame → ui.Image (boyut büyükse renkleme compute'da).
Future<ui.Image> occupancyFrameToImage(OccupancyGridFrame frame) async {
  final cells = frame.metadata.width * frame.metadata.height;
  final OccupancyRgbaPayload payload;
  if (cells > 250000) {
    payload = await compute(frameToRgbaPayload, frame);
  } else {
    payload = frameToRgbaPayload(frame);
  }
  return rgbaPayloadToImage(payload);
}
