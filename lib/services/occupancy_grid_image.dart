import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'ros_gcs_contract.dart';

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

/// Top-level: rosbridge OccupancyGrid JSON → frame (compute uyumlu).
OccupancyGridFrame? occupancyMessageToFrame(Map<String, dynamic> message) {
  try {
    final frame = OccupancyGridFrame.fromRosMessage(message);
    return frame.isComplete ? frame : null;
  } catch (_) {
    return null;
  }
}

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
