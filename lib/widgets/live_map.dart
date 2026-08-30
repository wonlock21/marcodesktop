import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ——— kalibrasyon sabitleri ———
const Offset kOriginPx = Offset(120.0, 260.0);
const double kPixelsPerMeter = 20.0;
const double kHeadingOffset = 7.6;
const double kIconSize = 24.0;

// ═══════════════════════════════════════════════════════════════════════
// Isolate-uyumlu top-level tipler ve fonksiyonlar
// (compute() çağrıları için — sınıf dışı, closure değil)
// ═══════════════════════════════════════════════════════════════════════

/// `compute()` çağrısına gönderilecek veri paketi.
/// Yalnızca Isolate'e gönderilebilir (sendable) tipler içerir.
class _ParseInput {
  final Uint8List bodyBytes;
  final String contentType;
  const _ParseInput(this.bodyBytes, this.contentType);
}

/// Ayrı Isolate'te çalışan ağır parse fonksiyonu.
/// HTTP isteği YAPAMAZ — yalnızca CPU işlemi.
///
/// Kapsadığı durumlar:
///   1. Doğrudan binary image (JPEG/PNG/WebP magic bytes ile sniff)
///   2. application/json → "data"/"image" key'i altında base64
///   3. text/html → inline data:image/... URL (ek HTTP isteği gerektirmez)
///   4. Ham base64 string (tüm body)
///
/// HTML içinde <img src="..."> durumu ek HTTP isteği gerektirdiğinden
/// bu fonksiyon null döndürür; _tick() ana Isolate'te fallback çalıştırır.
Uint8List? _parseResponseInIsolate(_ParseInput input) {
  final bytes = input.bodyBytes;
  final ct = input.contentType;

  // 1) Content-Type'a göre doğrudan binary
  if (ct.startsWith('image/') && bytes.isNotEmpty) {
    return _sniffOrPassthrough(bytes);
  }

  // 2) Magic-byte sniff (Content-Type güvenilmez sunucularda)
  final sniffed = _sniffBinaryStatic(bytes);
  if (sniffed != null) return sniffed;

  // 3) JSON içinde base64
  if (ct.contains('application/json')) {
    try {
      final obj = jsonDecode(utf8.decode(bytes));
      if (obj is Map) {
        final b64 = (obj['data'] as String?) ?? (obj['image'] as String? ?? '');
        if (b64.isNotEmpty) return base64Decode(_stripPrefixStatic(b64));
      }
    } catch (_) {}
  }

  // 4) HTML — yalnızca inline data: URL (ek HTTP gerektirmez)
  if (ct.contains('text/html')) {
    final html = _lossyString(bytes);
    final m = RegExp(
      r'data:image/[^;]+;base64,([A-Za-z0-9+/=\r\n]+)',
      caseSensitive: false,
    ).firstMatch(html);
    if (m != null) {
      try {
        final clean = m.group(1)!.replaceAll(RegExp(r'\s'), '');
        return base64Decode(clean);
      } catch (_) {}
    }
    // <img src="..."> fallback → null döndür, _tick() ek HTTP yapacak
    return null;
  }

  // 5) Ham base64 string
  final bodyStr = _lossyString(bytes).trim();
  if (_looksLikeBase64Static(bodyStr)) {
    try {
      return base64Decode(_stripPrefixStatic(bodyStr));
    } catch (_) {}
  }

  return null;
}

// ─── Yardımcı top-level fonksiyonlar ──────────────────────────────────

Uint8List? _sniffOrPassthrough(Uint8List data) =>
    _sniffBinaryStatic(data) ?? data;

Uint8List? _sniffBinaryStatic(Uint8List data) {
  if (data.length < 12) return null;
  // JPEG
  if (data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF) return data;
  // PNG
  const pngSig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (List.generate(8, (i) => data[i] == pngSig[i]).every((ok) => ok)) {
    return data;
  }
  // WebP (RIFF....WEBP)
  bool match(int offset, List<int> sig) {
    if (data.length < offset + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (data[offset + i] != sig[i]) return false;
    }
    return true;
  }

  const riff = [0x52, 0x49, 0x46, 0x46];
  const webp = [0x57, 0x45, 0x42, 0x50];
  if (match(0, riff) && match(8, webp)) return data;
  return null;
}

String _lossyString(Uint8List data) {
  try {
    return utf8.decode(data);
  } catch (_) {
    return const AsciiDecoder(allowInvalid: true).convert(data);
  }
}

bool _looksLikeBase64Static(String s) {
  final cleaned =
      _stripPrefixStatic(s).replaceAll('\n', '').replaceAll('\r', '');
  if (cleaned.length < 16) return false;
  return RegExp(r'^[A-Za-z0-9+/=]+$')
      .hasMatch(cleaned.substring(0, cleaned.length.clamp(0, 256)));
}

String _stripPrefixStatic(String s) {
  final i = s.indexOf(',');
  return s.startsWith('data:') && i != -1 ? s.substring(i + 1) : s;
}

// ═══════════════════════════════════════════════════════════════════════

class Pose {
  final double x, y, yaw;
  const Pose(this.x, this.y, this.yaw);
}

class LiveMapFixedUrl extends StatefulWidget {
  final String site;
  final String imagePath;
  final Pose Function() poseFn;
  final Duration interval;
  final Duration timeout;

  const LiveMapFixedUrl({
    super.key,
    required this.site,
    required this.poseFn,
    this.imagePath = '/get_image',
    this.interval = const Duration(milliseconds: 500),
    this.timeout = const Duration(seconds: 8),
  });

  @override
  State<LiveMapFixedUrl> createState() => _LiveMapFixedUrlState();
}

class _LiveMapFixedUrlState extends State<LiveMapFixedUrl> {
  Timer? _timer;
  bool _mapReady = false;
  Uint8List? _frame;
  bool _fetching = false;
  String? _lastError;

  String get _url {
    final p = widget.imagePath;
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    final base = widget.site.endsWith('/')
        ? widget.site.substring(0, widget.site.length - 1)
        : widget.site;
    final tail = p.startsWith('/') ? p : '/$p';
    return '$base$tail';
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant LiveMapFixedUrl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.site != widget.site ||
        oldWidget.interval != widget.interval ||
        oldWidget.imagePath != widget.imagePath) {
      _stop();
      setState(() {
        _mapReady = false;
        _frame = null;
        _lastError = null;
      });
      _start();
    }
  }

  void _start() {
    if (widget.site.isEmpty) return;
    _tick();
    _timer = Timer.periodic(widget.interval, (_) => _tick());
  }

  Future<void> _tick() async {
    if (_fetching || widget.site.isEmpty) return;
    _fetching = true;
    try {
      final resp = await http.get(Uri.parse(_url)).timeout(widget.timeout);

      if (resp.statusCode == 200) {
        final ct = (resp.headers['content-type'] ?? '').toLowerCase();

        // ── Ağır parse → ayrı Isolate ─────────────────────────────────
        Uint8List? bytes = await compute(
          _parseResponseInIsolate,
          _ParseInput(resp.bodyBytes, ct),
        );
        // ──────────────────────────────────────────────────────────────

        // HTML→<img src> fallback: ek HTTP isteği ana Isolate'te yapılır,
        // ardından gelen bytes yine compute() ile parse edilir.
        if (bytes == null && ct.contains('text/html')) {
          final html = _lossyString(resp.bodyBytes);
          final imgSrc = _extractFirstImgSrc(html);
          if (imgSrc != null) {
            _debug('HTML img src bulundu: $imgSrc');
            final resolved = _resolveUrl(Uri.parse(_url), imgSrc);
            final imgResp = await http.get(resolved).timeout(widget.timeout);
            if (imgResp.statusCode == 200) {
              final ct2 = (imgResp.headers['content-type'] ?? '').toLowerCase();
              bytes = await compute(
                _parseResponseInIsolate,
                _ParseInput(imgResp.bodyBytes, ct2),
              );
            } else {
              _debug('img src HTTP ${imgResp.statusCode}');
            }
          } else {
            _debug('HTML geldi ama IMG tag bulunamadı. '
                'Head: ${html.substring(0, html.length.clamp(0, 200))}');
          }
        }

        if (bytes != null && bytes.isNotEmpty && mounted) {
          setState(() {
            _frame = bytes;
            _mapReady = true;
            _lastError = null;
          });
        } else {
          _noteError('200 aldı ama görüntü çözülemedi (ct="$ct", '
              'len=${resp.bodyBytes.length}).');
        }
      } else {
        _noteError('HTTP ${resp.statusCode} – ${resp.reasonPhrase ?? ''}');
      }
    } catch (e) {
      _noteError('İstek hatası: $e');
    } finally {
      _fetching = false;
    }
  }

  // ─── HTML fallback yardımcıları (ana Isolate'te kalır) ───────────────

  String? _extractFirstImgSrc(String html) {
    final r =
        RegExp(r'''<img[^>]+src=["']([^"']+)["']''', caseSensitive: false);
    return r.firstMatch(html)?.group(1);
  }

  Uri _resolveUrl(Uri base, String href) {
    if (href.startsWith('http://') || href.startsWith('https://')) {
      return Uri.parse(href);
    }
    if (href.startsWith('//')) return Uri.parse('${base.scheme}:$href');
    if (href.startsWith('/')) {
      return Uri.parse('${base.scheme}://${base.host}'
          '${base.hasPort ? ':${base.port}' : ''}$href');
    }
    final b = base.toString();
    final withoutFile =
        b.endsWith('/') ? b : b.substring(0, b.lastIndexOf('/') + 1);
    return Uri.parse('$withoutFile$href');
  }

  // ─── Genel yardımcılar ────────────────────────────────────────────────

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _noteError(String msg) {
    _debug(msg);
    if (!mounted) return;
    setState(() => _lastError = msg);
  }

  void _debug(String msg) {
    debugPrint('[LiveMap] $msg  url=$_url');
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.site.isEmpty) {
      return const _StatusPane(text: 'Bağlantı bekleniyor...');
    }

    final pose = widget.poseFn();
    final px = kOriginPx.dx + pose.x * kPixelsPerMeter;
    final py = kOriginPx.dy - pose.y * kPixelsPerMeter;
    final theta = -pose.yaw + kHeadingOffset;

    return Stack(
      children: [
        Positioned.fill(
          child: (_frame == null)
              ? _StatusPane(
                  text:
                      _lastError == null ? 'Harita yükleniyor...' : _lastError!)
              : Image.memory(
                  _frame!,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.low,
                  fit: BoxFit.fill,
                ),
        ),
        if (_mapReady)
          Positioned(
            left: px - kIconSize / 2,
            top: py - kIconSize / 2,
            width: kIconSize,
            height: kIconSize,
            child: Transform.rotate(
              angle: theta,
              child: const Icon(Icons.navigation,
                  color: Colors.redAccent, size: kIconSize),
            ),
          ),
      ],
    );
  }
}

class _StatusPane extends StatelessWidget {
  final String text;
  const _StatusPane({required this.text});

  @override
  Widget build(BuildContext context) {
    // Opak arka plan: grid çizgilerinin metin üzerine binmesini önler.
    return ColoredBox(
      color: const Color(0xFF0D0D0D),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Colors.grey)),
        ]),
      ),
    );
  }
}
