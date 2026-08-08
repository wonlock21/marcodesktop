import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/gcs_map_model.dart';
import '../services/ros_gcs_contract.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GcsMapView — interaktif harita widget'ı
// ─────────────────────────────────────────────────────────────────────────────

/// Fabrika katı haritasını çizen, pan + scroll-zoom destekli widget.
///
/// [data] immutable veri anlık görüntüsüdür; her build çağrısında
/// yeni bir nesne geçirildiğinde harita otomatik yenilenir.
///
/// **Koordinat sistemi:**
/// - Dünya: metre (Y+ yukarı, matematiksel koordinatlar)
/// - Canvas: piksel (Y+ aşağı, ekran koordinatları)
/// - `_w2c(x, y, size)` dönüşümü uygular.
class GcsMapView extends StatefulWidget {
  final GcsMapData data;

  const GcsMapView({super.key, required this.data});

  @override
  State<GcsMapView> createState() => _GcsMapViewState();
}

class _GcsMapViewState extends State<GcsMapView> {
  /// Piksel / metre oran — başlangıç yakınlaştırma.
  double _scale = 45.0;

  /// Haritanın canvas içindeki kaydırma miktarı (piksel).
  Offset _pan = Offset.zero;

  // ── Pan yardımcısı ───────────────────────────────────────────────────────
  void _onPanUpdate(DragUpdateDetails d) =>
      setState(() => _pan += d.delta);

  // ── Scroll zoom ──────────────────────────────────────────────────────────
  void _onScroll(PointerScrollEvent e) {
    setState(() {
      final factor = e.scrollDelta.dy > 0 ? 0.88 : 1.14;
      _scale = (_scale * factor).clamp(12.0, 220.0);
    });
  }

  // ── Zoom butonları ───────────────────────────────────────────────────────
  void _zoomIn()  => setState(() => _scale = (_scale * 1.2).clamp(12.0, 220.0));
  void _zoomOut() => setState(() => _scale = (_scale / 1.2).clamp(12.0, 220.0));
  void _resetView() => setState(() { _scale = 45.0; _pan = Offset.zero; });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0D0D0D);

    return Stack(
      children: [
        // ── Harita çizim alanı ────────────────────────────────────────────
        Positioned.fill(
          child: ColoredBox(
            color: bg,
            child: GestureDetector(
              onPanUpdate: _onPanUpdate,
              child: Listener(
                onPointerSignal: (e) {
                  if (e is PointerScrollEvent) _onScroll(e);
                },
                child: CustomPaint(
                  painter: _MapPainter(
                    data:  widget.data,
                    scale: _scale,
                    pan:   _pan,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),

        // ── Sol üst: lejant ───────────────────────────────────────────────
        Positioned(
          left: 2.w,
          top:  2.h,
          child: _Legend(),
        ),

        // ── Sağ üst: zoom kontrolleri ─────────────────────────────────────
        Positioned(
          right: 2.w,
          top:   2.h,
          child: Column(
            children: [
              _MapIconBtn(Icons.add,        _zoomIn),
              SizedBox(height: 0.8.h),
              _MapIconBtn(Icons.remove,     _zoomOut),
              SizedBox(height: 0.8.h),
              _MapIconBtn(Icons.center_focus_strong, _resetView),
            ],
          ),
        ),

        // ── Sol alt: koordinat göstergesi ─────────────────────────────────
        Positioned(
          left:   2.w,
          bottom: 1.5.h,
          child: Text(
            'X: ${widget.data.robotX.toStringAsFixed(2)} m  '
            'Y: ${widget.data.robotY.toStringAsFixed(2)} m  '
            'YAW: ${(widget.data.robotYaw * 57.2958).toStringAsFixed(1)}°',
            style: TextStyle(
              color: const Color(0xFF4A4A4A),
              fontSize: 2.5.sp,
              fontFamily: 'monospace',
            ),
          ),
        ),

        // ── Sağ alt: ölçek çubuğu ─────────────────────────────────────────
        Positioned(
          right:  3.w,
          bottom: 1.5.h,
          child: _ScaleBar(pixelsPerMeter: _scale),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainter
// ─────────────────────────────────────────────────────────────────────────────

class _MapPainter extends CustomPainter {
  final GcsMapData data;
  final double     scale; // piksel / metre
  final Offset     pan;   // canvas kaydırma

  const _MapPainter({
    required this.data,
    required this.scale,
    required this.pan,
  });

  // ── Koordinat dönüşümleri ──────────────────────────────────────────────────

  /// Dünya koordinatını (metre) canvas pikseliyle çevirir.
  Offset _w2c(double wx, double wy, Size size) => Offset(
        size.width  / 2 + pan.dx + wx * scale,
        size.height / 2 + pan.dy - wy * scale,
      );

  // ── Ana paint ─────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final hasOccupancy =
        data.occupancyImage != null && data.mapMeta != null;
    if (hasOccupancy) {
      _paintOccupancy(canvas, size, data.occupancyImage!, data.mapMeta!);
    } else {
      _paintGrid(canvas, size);
      _paintWaitingHint(canvas, size);
    }
    for (final z in data.zones)  { _paintZone(canvas, size, z);  }
    for (final r in data.routes) { _paintRoute(canvas, size, r); }
    for (final p in data.points) {
      if (p.type != MapPointType.qrNoktasi) _paintPoint(canvas, size, p);
    }
    // QR en üstte
    for (final p in data.points) {
      if (p.type == MapPointType.qrNoktasi) _paintPoint(canvas, size, p);
    }
    _paintRobot(canvas, size);
  }

  /// OccupancyGrid görüntüsünü map origin/yaw/resolution ile çizer.
  void _paintOccupancy(
    Canvas canvas,
    Size size,
    ui.Image image,
    OccupancyGridMetadata meta,
  ) {
    final wM = meta.mapWidthMeters;
    final hM = meta.mapHeightMeters;
    final origin = _w2c(meta.originX, meta.originY, size);

    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    // Dünya: +x sağ, +y yukarı → ekran: +x sağ, +y aşağı
    canvas.rotate(-meta.originYaw);
    canvas.scale(scale, -scale);
    // Image satır 0 üstte (= map +y). Alt-sol origin olacak şekilde çevir.
    canvas.translate(0, hM);
    canvas.scale(1, -1);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, meta.width.toDouble(), meta.height.toDouble()),
      Rect.fromLTWH(0, 0, wM, hM),
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
    canvas.restore();
  }

  void _paintWaitingHint(Canvas canvas, Size size) {
    _paintText(
      canvas,
      '/map bekleniyor',
      Offset(size.width / 2, size.height / 2),
      const TextStyle(
        color: Color(0xFF616161),
        fontSize: 14,
        fontFamily: 'monospace',
      ),
    );
  }

  // ── Grid ─────────────────────────────────────────────────────────────────

  void _paintGrid(Canvas canvas, Size size) {
    final thin  = Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = 0.5;
    final thick = Paint()..color = const Color(0xFF242424)..strokeWidth = 0.8;

    final ox = size.width  / 2 + pan.dx;
    final oy = size.height / 2 + pan.dy;

    for (var wx = -20.0; wx <= 20.0; wx += 1.0) {
      final x = ox + wx * scale;
      if (x < 0 || x > size.width) continue;
      canvas.drawLine(
        Offset(x, 0), Offset(x, size.height),
        (wx % 5 == 0) ? thick : thin,
      );
    }
    for (var wy = -20.0; wy <= 20.0; wy += 1.0) {
      final y = oy - wy * scale;
      if (y < 0 || y > size.height) continue;
      canvas.drawLine(
        Offset(0, y), Offset(size.width, y),
        (wy % 5 == 0) ? thick : thin,
      );
    }

    // Eksen çizgileri
    final axis = Paint()..color = const Color(0xFF2E2E2E)..strokeWidth = 1.0;
    if (ox >= 0 && ox <= size.width) {
      canvas.drawLine(Offset(ox, 0), Offset(ox, size.height), axis);
    }
    if (oy >= 0 && oy <= size.height) {
      canvas.drawLine(Offset(0, oy), Offset(size.width, oy), axis);
    }

    // Koordinat etiketleri (5 m aralıkla)
    for (var wx = -20.0; wx <= 20.0; wx += 5.0) {
      for (var wy = -20.0; wy <= 20.0; wy += 5.0) {
        final x = ox + wx * scale;
        final y = oy - wy * scale;
        if (x < 4 || x > size.width - 4 || y < 4 || y > size.height - 4) continue;
        _paintText(
          canvas,
          '${wx.toInt()},${wy.toInt()}',
          Offset(x + 2, y - 8),
          const TextStyle(color: Color(0xFF2A2A2A), fontSize: 7, fontFamily: 'monospace'),
          centered: false,
        );
      }
    }
  }

  // ── Bölgeler ───────────────────────────────────────────────────────────────

  void _paintZone(Canvas canvas, Size size, MapZone zone) {
    final center = _w2c(zone.center.dx, zone.center.dy, size);
    final r      = zone.radius * scale;

    final fillColor   = zone.isEngel ? const Color(0x40F44336) : const Color(0x30FFEB3B);
    final strokeColor = zone.isEngel ? const Color(0x80F44336) : const Color(0x80FFEB3B);

    canvas.drawCircle(center, r, Paint()..color = fillColor..style = PaintingStyle.fill);
    canvas.drawCircle(center, r, Paint()..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = 1.2);

    _paintText(canvas, zone.label,
        center.translate(0, r + 8),
        TextStyle(color: strokeColor, fontSize: 8));
  }

  // ── Rota ───────────────────────────────────────────────────────────────────

  void _paintRoute(Canvas canvas, Size size, MapRoute route) {
    if (route.waypoints.length < 2) return;

    final paint = Paint()
      ..color = const Color(0x501565C0)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final first = _w2c(route.waypoints.first.dx, route.waypoints.first.dy, size);
    path.moveTo(first.dx, first.dy);

    for (var i = 1; i < route.waypoints.length; i++) {
      final p = _w2c(route.waypoints[i].dx, route.waypoints[i].dy, size);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);

    // Ok uçları
    for (var i = 0; i < route.waypoints.length - 1; i++) {
      final from = _w2c(route.waypoints[i].dx,     route.waypoints[i].dy,     size);
      final to   = _w2c(route.waypoints[i + 1].dx, route.waypoints[i + 1].dy, size);
      _paintArrow(canvas, from, to, const Color(0x701565C0));
    }
  }

  void _paintArrow(Canvas canvas, Offset from, Offset to, Color color) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return;
    final ndx = dx / len;
    final ndy = dy / len;
    final mid = Offset.lerp(from, to, 0.55)!;
    const as = 7.0;
    final perp = Offset(-ndy, ndx);
    final arrowPath = Path()
      ..moveTo(mid.dx + ndx * as, mid.dy + ndy * as)
      ..lineTo(mid.dx - ndx * as * 0.5 + perp.dx * as * 0.55,
               mid.dy - ndy * as * 0.5 + perp.dy * as * 0.55)
      ..lineTo(mid.dx - ndx * as * 0.5 - perp.dx * as * 0.55,
               mid.dy - ndy * as * 0.5 - perp.dy * as * 0.55)
      ..close();
    canvas.drawPath(arrowPath, Paint()..color = color..style = PaintingStyle.fill);
  }

  // ── Nokta ─────────────────────────────────────────────────────────────────

  void _paintPoint(Canvas canvas, Size size, MapPoint point) {
    final pos = _w2c(point.x, point.y, size);

    switch (point.type) {
      case MapPointType.almaNoktasi:
        _drawDiamond(canvas, pos, point.aktif ? 11 : 8,
            const Color(0xFF1565C0), point.aktif ? const Color(0xFF42A5F5) : const Color(0xFF1E88E5));
      case MapPointType.birakNoktasi:
        _drawDiamond(canvas, pos, point.aktif ? 11 : 8,
            const Color(0xFFBF360C), point.aktif ? const Color(0xFFFF8A65) : const Color(0xFFE64A19));
      case MapPointType.beklemeNoktasi:
        _drawCircleMarker(canvas, pos, 7, const Color(0xFF212121), const Color(0xFF757575));
      case MapPointType.kapiKontrol:
        _drawRectMarker(canvas, pos, const Color(0xFF4A148C), const Color(0xFFBA68C8));
      case MapPointType.sarjIstasyonu:
        _drawCircleMarker(canvas, pos, 8, const Color(0xFF004D40), const Color(0xFF00BCD4));
        _paintText(canvas, '⚡', pos.translate(0, -16),
            const TextStyle(color: Color(0xFF00BCD4), fontSize: 8));
      case MapPointType.qrNoktasi:
        _drawQrMarker(canvas, pos, const Color(0xFFFDD835));
      case MapPointType.engel:
        _drawCircleMarker(canvas, pos, 8, const Color(0x40F44336), const Color(0xFFEF5350));
      case MapPointType.guvenliDurus:
        _drawCircleMarker(canvas, pos, 8, const Color(0x30FFEB3B), const Color(0xFFFFEB3B));
    }

    _paintText(
      canvas,
      point.label,
      pos.translate(0, 14),
      TextStyle(
        color: point.aktif ? const Color(0xFFE0E0E0) : const Color(0xFF757575),
        fontSize: 8,
        fontFamily: 'monospace',
        fontWeight: point.aktif ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  // ── Robot ─────────────────────────────────────────────────────────────────

  void _paintRobot(Canvas canvas, Size size) {
    final pos = _w2c(data.robotX, data.robotY, size);

    // Gövde (dolgu + çerçeve)
    canvas.drawCircle(pos, 13, Paint()..color = const Color(0x7043A047)..style = PaintingStyle.fill);
    canvas.drawCircle(pos, 13, Paint()..color = const Color(0xFF43A047)..style = PaintingStyle.stroke..strokeWidth = 1.8);

    // Yön oku
    final yaw = data.robotYaw;
    final dx  = math.cos(yaw) * 22;
    final dy  = -math.sin(yaw) * 22; // y-flip
    final arrowEnd = pos.translate(dx, dy);

    canvas.drawLine(pos, arrowEnd, Paint()
      ..color = const Color(0xFF69F0AE)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round);

    // Ok ucu
    final perp = Offset(-math.sin(yaw), -math.cos(yaw)) * 5.5;
    final base = arrowEnd.translate(-dx * 0.35, -dy * 0.35);
    final arrowPath = Path()
      ..moveTo(arrowEnd.dx, arrowEnd.dy)
      ..lineTo(base.dx + perp.dx, base.dy + perp.dy)
      ..lineTo(base.dx - perp.dx, base.dy - perp.dy)
      ..close();
    canvas.drawPath(arrowPath, Paint()..color = const Color(0xFF69F0AE)..style = PaintingStyle.fill);

    // Robot etiketi
    _paintText(canvas, 'ROBOT', pos.translate(0, 20),
        const TextStyle(
          color: Color(0xFF69F0AE),
          fontSize: 8,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ));
  }

  // ── Şekil yardımcıları ───────────────────────────────────────────────────

  void _drawDiamond(Canvas canvas, Offset c, double s, Color fill, Color stroke) {
    final path = Path()
      ..moveTo(c.dx,     c.dy - s)
      ..lineTo(c.dx + s, c.dy    )
      ..lineTo(c.dx,     c.dy + s)
      ..lineTo(c.dx - s, c.dy    )
      ..close();
    canvas.drawPath(path, Paint()..color = fill.withValues(alpha: 0.75)..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()..color = stroke..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  void _drawCircleMarker(Canvas canvas, Offset c, double r, Color fill, Color stroke) {
    canvas.drawCircle(c, r, Paint()..color = fill..style = PaintingStyle.fill);
    canvas.drawCircle(c, r, Paint()..color = stroke..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  void _drawRectMarker(Canvas canvas, Offset c, Color fill, Color stroke) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: 20, height: 13),
      const Radius.circular(2),
    );
    canvas.drawRRect(rrect, Paint()..color = fill.withValues(alpha: 0.75)..style = PaintingStyle.fill);
    canvas.drawRRect(rrect, Paint()..color = stroke..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  void _drawQrMarker(Canvas canvas, Offset c, Color color) {
    canvas.drawRect(
      Rect.fromCenter(center: c, width: 14, height: 14),
      Paint()..color = color.withValues(alpha: 0.25)..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      Rect.fromCenter(center: c, width: 14, height: 14),
      Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );
    canvas.drawRect(
      Rect.fromCenter(center: c, width: 5, height: 5),
      Paint()..color = color..style = PaintingStyle.fill,
    );
  }

  void _paintText(Canvas canvas, String text, Offset pos, TextStyle style,
      {bool centered = true}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    tp.paint(
      canvas,
      centered ? pos.translate(-tp.width / 2, -tp.height / 2) : pos,
    );
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.scale != scale ||
      old.pan != pan ||
      old.data.robotX != data.robotX ||
      old.data.robotY != data.robotY ||
      old.data.robotYaw != data.robotYaw ||
      old.data.points != data.points ||
      old.data.routes != data.routes ||
      old.data.zones != data.zones ||
      !identical(old.data.occupancyImage, data.occupancyImage) ||
      old.data.mapMeta != data.mapMeta;
}

// ─────────────────────────────────────────────────────────────────────────────
// Yardımcı widget'lar
// ─────────────────────────────────────────────────────────────────────────────

/// Kompakt lejant — haritanın sol üst köşesinde gösterilir.
class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      (_LegendEntry(color: Color(0xFF1E88E5), label: 'Alma')),
      (_LegendEntry(color: Color(0xFFE64A19), label: 'Bırakma')),
      (_LegendEntry(color: Color(0xFF757575), label: 'Bekleme')),
      (_LegendEntry(color: Color(0xFFBA68C8), label: 'Kapı')),
      (_LegendEntry(color: Color(0xFF00BCD4), label: 'Şarj')),
      (_LegendEntry(color: Color(0xFFFDD835), label: 'QR')),
      (_LegendEntry(color: Color(0xFFEF5350), label: 'Engel')),
      (_LegendEntry(color: Color(0xFF43A047), label: 'Robot')),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xCC0D0D0D),
        border: Border.all(color: const Color(0xFF2A2A2A)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((e) => e).toList(),
      ),
    );
  }
}

class _LegendEntry extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendEntry({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9E9E9E), fontSize: 9, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

/// Harita üzerindeki küçük yuvarlak ikon butonu.
class _MapIconBtn extends StatelessWidget {
  final IconData    icon;
  final VoidCallback onTap;
  const _MapIconBtn(this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: const Color(0xCC1A1A1A),
          border: Border.all(color: const Color(0xFF333333)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, color: const Color(0xFF9E9E9E), size: 14),
      ),
    );
  }
}

/// Piksel/metre oranına göre ölçek çubuğu.
class _ScaleBar extends StatelessWidget {
  final double pixelsPerMeter;
  const _ScaleBar({required this.pixelsPerMeter});

  @override
  Widget build(BuildContext context) {
    final barW = pixelsPerMeter * 2; // 2 m uzunluğunda çubuk
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: barW,
          height: 2,
          color: const Color(0xFF616161),
        ),
        const SizedBox(height: 2),
        const Text(
          '2 m',
          style: TextStyle(
              color: Color(0xFF616161), fontSize: 8, fontFamily: 'monospace'),
        ),
      ],
    );
  }
}
