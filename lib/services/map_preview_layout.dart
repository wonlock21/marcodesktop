import 'dart:ui';

/// `BoxFit.contain` ile aynı scale + letterbox offset.
({double scale, Offset offset}) mapPreviewLayout(
  Size view,
  int mapW,
  int mapH,
) {
  if (view.width <= 0 || view.height <= 0 || mapW <= 0 || mapH <= 0) {
    return (scale: 1, offset: Offset.zero);
  }
  final scaleX = view.width / mapW;
  final scaleY = view.height / mapH;
  final scale = scaleX < scaleY ? scaleX : scaleY;
  final drawnW = mapW * scale;
  final drawnH = mapH * scale;
  final offset = Offset(
    (view.width - drawnW) / 2,
    (view.height - drawnH) / 2,
  );
  return (scale: scale, offset: offset);
}

/// View dokunması → harita pikseli (`BoxFit.contain` tersi). G.1
({double pixelX, double pixelY, bool insideMap}) mapPreviewViewToPixel(
  Offset local,
  Size view,
  int mapW,
  int mapH,
) {
  final layout = mapPreviewLayout(view, mapW, mapH);
  if (layout.scale <= 0) {
    return (pixelX: 0, pixelY: 0, insideMap: false);
  }
  final px = (local.dx - layout.offset.dx) / layout.scale;
  final py = (local.dy - layout.offset.dy) / layout.scale;
  final inside = px >= 0 && py >= 0 && px < mapW && py < mapH;
  return (pixelX: px, pixelY: py, insideMap: inside);
}
