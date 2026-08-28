import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;

import '../services/camera_stream_config.dart';

enum MjpegCameraStatus {
  loading,
  connected,
  disconnected,
  error,
}

/// Windows / masaüstü uyumlu HTTP MJPEG görüntüleyici.
///
/// Widget ağaçtan çıkınca (başka sekmeye geçince) HTTP istemcisi kapanır.
class MjpegCameraView extends StatefulWidget {
  const MjpegCameraView({
    super.key,
    this.streamUri,
  });

  /// Varsayılan: [CameraStreamConfig.streamUri].
  final Uri? streamUri;

  @override
  State<MjpegCameraView> createState() => _MjpegCameraViewState();
}

class _MjpegCameraViewState extends State<MjpegCameraView> {
  static const _accent = Color(0xFF4A90D9);
  static const _muted = Color(0xFF888888);
  static const _panel = Color(0xFF0D0D0D);

  http.Client? _client;
  StreamSubscription<List<int>>? _subscription;
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  Uint8List? _frame;
  MjpegCameraStatus _status = MjpegCameraStatus.loading;
  String? _errorMessage;
  int _session = 0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_connect());
  }

  @override
  void dispose() {
    _disposed = true;
    _teardown();
    super.dispose();
  }

  void _teardown() {
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
    _buffer.clear();
  }

  Future<void> _reconnect() async {
    if (_disposed) return;
    setState(() {
      _status = MjpegCameraStatus.loading;
      _errorMessage = null;
      _frame = null;
    });
    await _connect();
  }

  Future<void> _connect() async {
    _teardown();
    final session = ++_session;
    if (!_disposed && mounted) {
      setState(() {
        _status = MjpegCameraStatus.loading;
        _errorMessage = null;
      });
    }

    final client = http.Client();
    _client = client;

    try {
      // queryParameters ile kurulan Uri topic'i %2F yapar; web_video_server
      // bunu kabul etmez. Uri.parse(ham string) slash'ı korur.
      final uri = widget.streamUri ?? CameraStreamConfig.streamUri;
      final request = http.Request('GET', uri)
        ..headers['Accept'] = 'multipart/x-mixed-replace,*/*';
      final response = await client.send(request).timeout(
            const Duration(seconds: 8),
            onTimeout: () =>
                throw TimeoutException('Kamera bağlantı zaman aşımı'),
          );

      if (_disposed || session != _session) {
        client.close();
        return;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }

      _subscription = response.stream.listen(
        (chunk) => _onChunk(chunk, session),
        onError: (Object error, StackTrace _) {
          if (_disposed || session != _session) return;
          _fail(error.toString(), status: MjpegCameraStatus.error);
        },
        onDone: () {
          if (_disposed || session != _session) return;
          if (_frame == null) {
            _fail(
              'Sunucu yayın göndermedi (topic URL encode?)',
              status: MjpegCameraStatus.error,
            );
          } else {
            _fail('Yayın sonlandı', status: MjpegCameraStatus.disconnected);
          }
        },
        cancelOnError: true,
      );
    } catch (error) {
      if (_disposed || session != _session) {
        client.close();
        return;
      }
      _fail(error.toString(), status: MjpegCameraStatus.error);
    }
  }

  void _fail(String raw, {required MjpegCameraStatus status}) {
    _teardown();
    if (!mounted || _disposed) return;
    final message = _userMessage(raw);
    setState(() {
      _status = status;
      _errorMessage = message;
    });
  }

  String _userMessage(String raw) {
    final t = raw.toLowerCase();
    if (t.contains('timeout') || t.contains('zaman')) {
      return 'Bağlantı zaman aşımı — ${CameraStreamConfig.displayEndpoint}';
    }
    if (t.contains('socket') ||
        t.contains('connection') ||
        t.contains('failed host') ||
        t.contains('network is unreachable') ||
        t.contains('bağlan')) {
      return 'Kameraya ulaşılamadı — ${CameraStreamConfig.displayEndpoint}';
    }
    if (t.contains('http ')) {
      return 'Sunucu yanıtı hatalı: $raw';
    }
    if (t.contains('yayın sonlandı')) {
      return 'Kamera yayını kesildi';
    }
    return raw.length > 120 ? '${raw.substring(0, 117)}…' : raw;
  }

  void _onChunk(List<int> chunk, int session) {
    if (_disposed || session != _session) return;
    _buffer.add(chunk);
    _extractFrames(session);
  }

  void _extractFrames(int session) {
    var data = _buffer.takeBytes();
    while (true) {
      final start = _indexOfJpegSoi(data);
      if (start < 0) {
        // SOI yok; taşmayı sınırla.
        if (data.length > 2 * 1024 * 1024) {
          data = data.sublist(data.length - 64);
        }
        _buffer.add(data);
        return;
      }
      if (start > 0) {
        data = data.sublist(start);
      }
      final end = _indexOfJpegEoi(data);
      if (end < 0) {
        _buffer.add(data);
        return;
      }
      final frame = Uint8List.fromList(data.sublist(0, end + 2));
      data = data.sublist(end + 2);
      _publishFrame(frame, session);
    }
  }

  void _publishFrame(Uint8List frame, int session) {
    if (_disposed || session != _session || !mounted) return;
    setState(() {
      _frame = frame;
      _status = MjpegCameraStatus.connected;
      _errorMessage = null;
    });
  }

  static int _indexOfJpegSoi(List<int> data) {
    for (var i = 0; i < data.length - 1; i++) {
      if (data[i] == 0xFF && data[i + 1] == 0xD8) return i;
    }
    return -1;
  }

  static int _indexOfJpegEoi(List<int> data) {
    // SOI'den sonra ara (en az 2 bayt atla).
    for (var i = 2; i < data.length - 1; i++) {
      if (data[i] == 0xFF && data[i + 1] == 0xD9) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusBar(
            status: _status,
            endpoint: CameraStreamConfig.displayEndpoint,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final frame = _frame;
    if (frame != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: _panel,
            child: Image.memory(
              frame,
              gaplessPlayback: true,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
          if (_status == MjpegCameraStatus.disconnected ||
              _status == MjpegCameraStatus.error)
            _OverlayMessage(
              icon: Icons.videocam_off_outlined,
              title: _status == MjpegCameraStatus.disconnected
                  ? 'Bağlantı kesildi'
                  : 'Kamera hatası',
              subtitle: _errorMessage ?? '',
              actionLabel: 'Yeniden bağlan',
              onAction: () => unawaited(_reconnect()),
            ),
        ],
      );
    }

    switch (_status) {
      case MjpegCameraStatus.loading:
        return _OverlayMessage(
          icon: Icons.videocam_outlined,
          title: 'Yükleniyor…',
          subtitle: 'MJPEG: ${CameraStreamConfig.displayEndpoint}',
          showSpinner: true,
        );
      case MjpegCameraStatus.disconnected:
      case MjpegCameraStatus.error:
        return _OverlayMessage(
          icon: Icons.videocam_off_outlined,
          title: _status == MjpegCameraStatus.disconnected
              ? 'Bağlantı kesildi'
              : 'Kamera hatası',
          subtitle: _errorMessage ?? 'Yayına bağlanılamadı',
          actionLabel: 'Yeniden bağlan',
          onAction: () => unawaited(_reconnect()),
        );
      case MjpegCameraStatus.connected:
        return const SizedBox.shrink();
    }
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.status,
    required this.endpoint,
  });

  final MjpegCameraStatus status;
  final String endpoint;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      MjpegCameraStatus.loading => ('Yükleniyor', const Color(0xFFB7791F)),
      MjpegCameraStatus.connected => ('Bağlı', const Color(0xFF2F6F4E)),
      MjpegCameraStatus.disconnected => (
          'Bağlantı kesildi',
          const Color(0xFFC53030)
        ),
      MjpegCameraStatus.error => ('Hata', const Color(0xFFC53030)),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 6.h),
      decoration: const BoxDecoration(
        color: Color(0xFF161616),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2A2A2A), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 1.2.w),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 2.6.sp,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 1.5.w),
          Expanded(
            child: Text(
              'KAMERA · $endpoint · ${CameraStreamConfig.topic}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF666666),
                fontSize: 2.4.sp,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayMessage extends StatelessWidget {
  const _OverlayMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.showSpinner = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xCC0D0D0D),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSpinner)
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: const Color(0xFF4A90D9).withValues(alpha: 0.8),
                ),
              )
            else
              Icon(icon, size: 10.w, color: const Color(0xFF2A2A2A)),
            SizedBox(height: 2.h),
            Text(
              title,
              style: TextStyle(
                color: const Color(0xFFAAAAAA),
                fontSize: 3.2.sp,
                fontFamily: 'monospace',
              ),
            ),
            if (subtitle.trim().isNotEmpty) ...[
              SizedBox(height: 0.8.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _MjpegCameraViewState._muted,
                    fontSize: 2.6.sp,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: 2.h),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: _MjpegCameraViewState._accent,
                  foregroundColor: Colors.white,
                  padding:
                      EdgeInsets.symmetric(horizontal: 3.w, vertical: 10.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    fontSize: 2.6.sp,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
