import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ——— kalibrasyon sabitleri ———
const Offset kOriginPx = Offset(120.0, 260.0);
const double kPixelsPerMeter = 20.0;
const double kHeadingOffset = 7.6;
const double kIconSize = 24.0;

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
      final resp =
          await http.get(Uri.parse(_url)).timeout(widget.timeout);

      if (resp.statusCode == 200) {
        Uint8List? bytes;
        final headers =
            resp.headers.map((k, v) => MapEntry(k.toLowerCase(), v));
        final ct = (headers['content-type'] ?? '').toLowerCase();

        if (ct.startsWith('image/')) {
          if (resp.bodyBytes.isNotEmpty) bytes = resp.bodyBytes;
        }

        bytes ??= _sniffBinaryImage(resp.bodyBytes);

        if (bytes == null && ct.contains('application/json')) {
          final obj = jsonDecode(utf8.decode(resp.bodyBytes));
          if (obj is Map) {
            final String b64 =
                (obj['data'] as String?) ?? (obj['image'] as String? ?? '');
            if (b64.isNotEmpty) bytes = base64Decode(_stripDataUrlPrefix(b64));
          }
        }

        if (bytes == null && ct.contains('text/html')) {
          final html = _tryDecodeUtf8Lossy(resp.bodyBytes);
          final dataUrl = _extractDataImageUrl(html);
          if (dataUrl != null) {
            bytes = base64Decode(_stripDataUrlPrefix(dataUrl));
          } else {
            final imgSrc = _extractFirstImgSrc(html);
            if (imgSrc != null) {
              final resolved = _resolveUrl(Uri.parse(_url), imgSrc);
              _debug('HTML içinden img src bulundu: $resolved');
              final imgResp =
                  await http.get(resolved).timeout(widget.timeout);
              if (imgResp.statusCode == 200) {
                final ct2 =
                    (imgResp.headers['content-type'] ?? '').toLowerCase();
                if (ct2.startsWith('image/')) {
                  if (imgResp.bodyBytes.isNotEmpty) bytes = imgResp.bodyBytes;
                }
                bytes ??= _sniffBinaryImage(imgResp.bodyBytes);
                if (bytes == null && ct2.contains('application/json')) {
                  final obj2 = jsonDecode(utf8.decode(imgResp.bodyBytes));
                  if (obj2 is Map) {
                    final String b64 = (obj2['data'] as String?) ??
                        (obj2['image'] as String? ?? '');
                    if (b64.isNotEmpty) {
                      bytes = base64Decode(_stripDataUrlPrefix(b64));
                    }
                  }
                }
                if (bytes == null) {
                  final bodyStr2 =
                      _tryDecodeUtf8Lossy(imgResp.bodyBytes).trim();
                  if (_looksLikeBase64(bodyStr2)) {
                    bytes = base64Decode(_stripDataUrlPrefix(bodyStr2));
                  }
                }
              } else {
                _debug('img src HTTP ${imgResp.statusCode}');
              }
            } else {
              _debug(
                  'HTML geldi ama IMG tag bulunamadı. Head: ${html.substring(0, html.length.clamp(0, 200))}');
            }
          }
        }

        if (bytes == null) {
          final bodyStr = _tryDecodeUtf8Lossy(resp.bodyBytes).trim();
          if (_looksLikeBase64(bodyStr)) {
            try {
              bytes = base64Decode(_stripDataUrlPrefix(bodyStr));
            } catch (e) {
              _debug('Base64 decode hatası: $e');
            }
          }
        }

        if (bytes != null && bytes.isNotEmpty && mounted) {
          setState(() {
            _frame = bytes;
            _mapReady = true;
            _lastError = null;
          });
        } else {
          _noteError(
              '200 aldı ama görüntü çözülemedi (ct="$ct", len=${resp.bodyBytes.length}).');
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

  String? _extractFirstImgSrc(String html) {
    final r = RegExp(r'''<img[^>]+src=["']([^"']+)["']''', caseSensitive: false);
    return r.firstMatch(html)?.group(1);
  }

  String? _extractDataImageUrl(String html) {
    final r = RegExp(
        r'data:image\/[a-zA-Z0-9.+-]+;base64,[A-Za-z0-9+\/=\r\n]+',
        caseSensitive: false);
    return r.firstMatch(html)?.group(0);
  }

  Uri _resolveUrl(Uri base, String href) {
    if (href.startsWith('http://') || href.startsWith('https://')) {
      return Uri.parse(href);
    }
    if (href.startsWith('//')) return Uri.parse('${base.scheme}:$href');
    if (href.startsWith('/')) {
      return Uri.parse(
          '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}$href');
    }
    final b = base.toString();
    final withoutFile =
        b.endsWith('/') ? b : b.substring(0, b.lastIndexOf('/') + 1);
    return Uri.parse('$withoutFile$href');
  }

  Uint8List? _sniffBinaryImage(Uint8List data) {
    if (data.length < 12) return null;
    if (data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF) return data;
    const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (List.generate(8, (i) => data[i] == png[i]).every((ok) => ok)) {
      return data;
    }
    final riff = utf8.encode('RIFF');
    final webp = utf8.encode('WEBP');
    if (_startsWith(data, riff) && _containsAt(data, webp, 8)) return data;
    return null;
  }

  bool _startsWith(Uint8List d, List<int> sig) {
    if (d.length < sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (d[i] != sig[i]) return false;
    }
    return true;
  }

  bool _containsAt(Uint8List d, List<int> sig, int offset) {
    if (d.length < offset + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (d[offset + i] != sig[i]) return false;
    }
    return true;
  }

  String _stripDataUrlPrefix(String s) {
    final i = s.indexOf(',');
    return s.startsWith('data:') && i != -1 ? s.substring(i + 1) : s;
  }

  String _tryDecodeUtf8Lossy(Uint8List data) {
    try {
      return utf8.decode(data);
    } catch (_) {
      return const AsciiDecoder(allowInvalid: true).convert(data);
    }
  }

  bool _looksLikeBase64(String s) {
    final cleaned =
        _stripDataUrlPrefix(s).replaceAll('\n', '').replaceAll('\r', '');
    if (cleaned.length < 16) return false;
    return RegExp(r'^[A-Za-z0-9+/=]+$')
        .hasMatch(cleaned.substring(0, cleaned.length.clamp(0, 256)));
  }

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
                  text: _lastError == null
                      ? 'Harita yükleniyor...'
                      : _lastError!)
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
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 8),
        Text(text, style: const TextStyle(color: Colors.grey)),
      ]),
    );
  }
}
