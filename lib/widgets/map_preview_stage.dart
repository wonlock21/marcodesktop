import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/map_preview_layout.dart';
import '../services/ros_mapping_contract.dart';

/// Harita üstü düğüm işaretçisi (piksel koordinat + etiket).
enum MapPreviewNodeMarkerKind { standard, cross }

class MapPreviewNodeMarker {
  final String label;
  final double pixelX;
  final double pixelY;
  final Color color;
  final MapPreviewNodeMarkerKind kind;
  final String? tapValue;

  const MapPreviewNodeMarker({
    required this.label,
    required this.pixelX,
    required this.pixelY,
    required this.color,
    this.kind = MapPreviewNodeMarkerKind.standard,
    this.tapValue,
  });
}

class MapPreviewRouteSegment {
  final Offset start;
  final Offset end;
  final bool bidirectional;
  final Color color;

  const MapPreviewRouteSegment({
    required this.start,
    required this.end,
    required this.bidirectional,
    this.color = const Color(0xFF42A5F5),
  });
}

MapPreviewNodeMarker? mapPreviewDemoPointMarker({
  required String label,
  required DemoPointPose? pose,
  required MapPreviewMetadata? metadata,
  required Color color,
}) {
  if (pose == null || metadata == null) return null;
  final pixel = metadata.mapToPixel(pose.x, pose.y);
  if (!pixel.insideMap) return null;
  return MapPreviewNodeMarker(
    label: label,
    pixelX: pixel.x,
    pixelY: pixel.y,
    color: color,
  );
}

/// Canlı `/map_preview` PNG + robot pikseli (döndürme/aynalama yok; yalnız ikon yaw).
class MapPreviewStage extends StatelessWidget {
  const MapPreviewStage({
    super.key,
    required this.pngBytes,
    this.metadata,
    this.robotPixel,
    this.awaitingFresh = false,
    this.sourceLabel,
    this.nodeMarkers = const [],
    this.routePolylinePixels = const [],
    this.routeSegments = const [],
    this.onMapTap,
    this.onNodeMarkerTap,
  });

  final Uint8List pngBytes;
  final MapPreviewMetadata? metadata;
  final MapPreviewRobotPixel? robotPixel;
  final bool awaitingFresh;
  final String? sourceLabel;
  final List<MapPreviewNodeMarker> nodeMarkers;

  /// H.1 — sıralı rota noktaları (harita pikseli).
  final List<Offset> routePolylinePixels;
  final List<MapPreviewRouteSegment> routeSegments;

  /// G.1 — harita pikseline dokunma (`insideMap` false ise çağrılmaz).
  final void Function(double pixelX, double pixelY)? onMapTap;

  /// H.1 — marker etiketine dokunma (rota seçimi).
  final void Function(String label)? onNodeMarkerTap;

  @override
  Widget build(BuildContext context) {
    final mapW = robotPixel?.mapWidth ?? metadata?.width;
    final mapH = robotPixel?.mapHeight ?? metadata?.height;

    return ColoredBox(
      color: const Color(0xFF0D0D0D),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final view = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: onMapTap == null || mapW == null || mapH == null
                ? null
                : (details) {
                    final hit = mapPreviewViewToPixel(
                      details.localPosition,
                      view,
                      mapW,
                      mapH,
                    );
                    if (!hit.insideMap) return;
                    onMapTap!(hit.pixelX, hit.pixelY);
                  },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  pngBytes,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      'PNG çözülemedi',
                      style: TextStyle(
                        color: const Color(0xFF888888),
                        fontSize: 3.sp,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
                if (mapW != null &&
                    mapH != null &&
                    routePolylinePixels.length >= 2)
                  CustomPaint(
                    size: view,
                    painter: _RoutePolylinePainter(
                      view: view,
                      mapW: mapW,
                      mapH: mapH,
                      pixels: routePolylinePixels,
                    ),
                  ),
                if (mapW != null && mapH != null && routeSegments.isNotEmpty)
                  CustomPaint(
                    size: view,
                    painter: _EdgeSegmentsPainter(
                      view: view,
                      mapW: mapW,
                      mapH: mapH,
                      segments: routeSegments,
                    ),
                  ),
                if (mapW != null && mapH != null && nodeMarkers.isNotEmpty)
                  ...nodeMarkers.map(
                    (m) => _NodeMarkerOverlay(
                      view: view,
                      mapW: mapW,
                      mapH: mapH,
                      marker: m,
                      onTap: onNodeMarkerTap == null
                          ? null
                          : () => onNodeMarkerTap!(m.tapValue ?? m.label),
                    ),
                  ),
                if (mapW != null &&
                    mapH != null &&
                    robotPixel != null &&
                    robotPixel!.insideMap)
                  _RobotOverlay(
                    view: view,
                    mapW: mapW,
                    mapH: mapH,
                    robot: robotPixel!,
                  ),
                if (robotPixel != null && !robotPixel!.insideMap)
                  Positioned(
                    left: 2.w,
                    bottom: 1.h,
                    child: Text(
                      'Robot harita dışında',
                      style: TextStyle(
                        color: const Color(0xFFB7791F),
                        fontSize: 2.4.sp,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                if (sourceLabel != null && sourceLabel!.isNotEmpty)
                  Positioned(
                    right: 2.w,
                    top: 1.h,
                    child: Text(
                      sourceLabel!,
                      style: TextStyle(
                        color: const Color(0xFF666666),
                        fontSize: 2.2.sp,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                if (awaitingFresh)
                  Positioned(
                    left: 2.w,
                    top: 1.h,
                    child: Text(
                      'Harita güncelleniyor…',
                      style: TextStyle(
                        color: const Color(0xFF4A90D9),
                        fontSize: 2.4.sp,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RoutePolylinePainter extends CustomPainter {
  final Size view;
  final int mapW;
  final int mapH;
  final List<Offset> pixels;

  const _RoutePolylinePainter({
    required this.view,
    required this.mapW,
    required this.mapH,
    required this.pixels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pixels.length < 2) return;
    final layout = mapPreviewLayout(view, mapW, mapH);
    final path = Path();
    for (var i = 0; i < pixels.length; i++) {
      final p = Offset(
        layout.offset.dx + pixels[i].dx * layout.scale,
        layout.offset.dy + pixels[i].dy * layout.scale,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    final paint = Paint()
      ..color = const Color(0xFF42A5F5)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RoutePolylinePainter old) =>
      old.pixels != pixels || old.mapW != mapW || old.mapH != mapH;
}

class _EdgeSegmentsPainter extends CustomPainter {
  final Size view;
  final int mapW;
  final int mapH;
  final List<MapPreviewRouteSegment> segments;

  const _EdgeSegmentsPainter({
    required this.view,
    required this.mapW,
    required this.mapH,
    required this.segments,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final layout = mapPreviewLayout(view, mapW, mapH);
    Offset viewPoint(Offset pixel) => Offset(
          layout.offset.dx + pixel.dx * layout.scale,
          layout.offset.dy + pixel.dy * layout.scale,
        );

    for (final segment in segments) {
      final start = viewPoint(segment.start);
      final end = viewPoint(segment.end);
      final paint = Paint()
        ..color = segment.color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start, end, paint);
      _drawArrow(canvas, paint, start, end);
      if (segment.bidirectional) _drawArrow(canvas, paint, end, start);
    }
  }

  void _drawArrow(Canvas canvas, Paint paint, Offset start, Offset end) {
    final delta = end - start;
    if (delta.distance < 12) return;
    final angle = math.atan2(delta.dy, delta.dx);
    final tip = Offset(
      start.dx + delta.dx * 0.62,
      start.dy + delta.dy * 0.62,
    );
    const length = 9.0;
    final left = Offset(
      tip.dx - length * math.cos(angle - math.pi / 6),
      tip.dy - length * math.sin(angle - math.pi / 6),
    );
    final right = Offset(
      tip.dx - length * math.cos(angle + math.pi / 6),
      tip.dy - length * math.sin(angle + math.pi / 6),
    );
    final path = Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(right.dx, right.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EdgeSegmentsPainter old) =>
      old.segments != segments || old.mapW != mapW || old.mapH != mapH;
}

class _NodeMarkerOverlay extends StatelessWidget {
  const _NodeMarkerOverlay({
    required this.view,
    required this.mapW,
    required this.mapH,
    required this.marker,
    this.onTap,
  });

  final Size view;
  final int mapW;
  final int mapH;
  final MapPreviewNodeMarker marker;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final layout = mapPreviewLayout(view, mapW, mapH);
    final cx = layout.offset.dx + marker.pixelX * layout.scale;
    final cy = layout.offset.dy + marker.pixelY * layout.scale;

    if (marker.kind == MapPreviewNodeMarkerKind.cross) {
      return _buildCrossMarker(cx, cy);
    }

    const size = 22.0;

    return Positioned(
      left: cx - size / 2,
      top: cy - size - 4,
      width: size + 36,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: marker.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 3),
                ],
              ),
            ),
            Text(
              marker.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: marker.color,
                fontSize: 2.4.sp,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                shadows: const [
                  Shadow(color: Colors.black87, blurRadius: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrossMarker(double cx, double cy) {
    const hitSize = 30.0;
    const crossSize = 13.0;

    return Positioned(
      left: cx - hitSize / 2,
      top: cy - hitSize / 2,
      width: hitSize,
      height: hitSize,
      child: Tooltip(
        message: marker.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: hitSize - 4,
                left: -45,
                width: hitSize + 90,
                child: IgnorePointer(
                  child: Text(
                    marker.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: marker.color,
                      fontSize: 2.2.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 3),
                      ],
                    ),
                  ),
                ),
              ),
              CustomPaint(
                size: const Size.square(crossSize),
                painter: _CrossMarkerPainter(color: marker.color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CrossMarkerPainter extends CustomPainter {
  const _CrossMarkerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final half = size.shortestSide / 2;
    final shadow = Paint()
      ..color = Colors.black87
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final firstStart = center.translate(-half, -half);
    final firstEnd = center.translate(half, half);
    final secondStart = center.translate(-half, half);
    final secondEnd = center.translate(half, -half);
    canvas
      ..drawLine(firstStart, firstEnd, shadow)
      ..drawLine(secondStart, secondEnd, shadow)
      ..drawLine(firstStart, firstEnd, paint)
      ..drawLine(secondStart, secondEnd, paint);
  }

  @override
  bool shouldRepaint(covariant _CrossMarkerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _RobotOverlay extends StatelessWidget {
  const _RobotOverlay({
    required this.view,
    required this.mapW,
    required this.mapH,
    required this.robot,
  });

  final Size view;
  final int mapW;
  final int mapH;
  final MapPreviewRobotPixel robot;

  @override
  Widget build(BuildContext context) {
    final layout = mapPreviewLayout(view, mapW, mapH);
    // PNG satır 0 üstte; pixel_x/y görüntü pikseli.
    final cx = layout.offset.dx + robot.pixelX * layout.scale;
    final cy = layout.offset.dy + robot.pixelY * layout.scale;
    const iconSize = 28.0;

    // screen_yaw: radyan, saat yönü pozitif → Flutter Transform saat yönü = pozitif.
    return Positioned(
      left: cx - iconSize / 2,
      top: cy - iconSize / 2,
      width: iconSize,
      height: iconSize,
      child: Transform.rotate(
        angle: robot.screenYaw + math.pi / 2,
        child: const Icon(
          Icons.navigation,
          size: iconSize,
          color: Color(0xFF4ADE80),
          shadows: [
            Shadow(color: Colors.black54, blurRadius: 4),
          ],
        ),
      ),
    );
  }
}
