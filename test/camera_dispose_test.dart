import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:liftant_v2_bitirme/widgets/mjpeg_camera_view.dart';

class CameraClient extends http.BaseClient {
  bool closed = false;
  bool cancelled = false;
  late final frames =
      StreamController<List<int>>(onCancel: () => cancelled = true);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(frames.stream, 200);
  @override
  void close() {
    closed = true;
  }
}

void main() {
  testWidgets('camera removal cancels HTTP stream, client and frame timeout',
      (tester) async {
    final client = CameraClient();
    await tester.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
            home: Scaffold(
                body: MjpegCameraView(
                    streamUri: Uri.parse(
                        'http://robot:8080/stream?topic=/camera/image_raw'),
                    clientFactory: () => client)))));
    await tester.pump();
    expect(client.closed, false);
    await tester.pumpWidget(const SizedBox());
    expect(client.closed, true);
    expect(client.cancelled, true);
    unawaited(client.frames.close());
    await tester.pump();
  });
  testWidgets('camera address change releases old HTTP connection',
      (tester) async {
    final first = CameraClient();
    final second = CameraClient();
    Widget screen(String host, CameraClient client) => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
            home: Scaffold(
                body: MjpegCameraView(
                    streamUri: Uri.parse(
                        'http://$host:8080/stream?topic=/camera/image_raw'),
                    clientFactory: () => client))));
    await tester.pumpWidget(screen('robot1', first));
    await tester.pump();
    await tester.pumpWidget(screen('robot2', second));
    await tester.pump();
    expect(first.closed, true);
    expect(first.cancelled, true);
    expect(second.closed, false);
    await tester.pumpWidget(const SizedBox());
    unawaited(first.frames.close());
    unawaited(second.frames.close());
    await tester.pump();
  });
}
