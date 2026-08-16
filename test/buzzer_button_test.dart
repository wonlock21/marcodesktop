import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftant_v2_bitirme/widgets/control_buttons.dart';

Widget _testApp({
  required bool enabled,
  required bool active,
  required VoidCallback onPressed,
}) {
  return ScreenUtilInit(
    designSize: const Size(360, 690),
    builder: (context, child) => MaterialApp(
      home: Scaffold(
        body: NormalButton(
          text: active ? 'Buzzer Kapat' : 'Buzzer Durumu Bekleniyor',
          assignedKey: LogicalKeyboardKey.keyB,
          enabled: enabled,
          active: active,
          onPressed: onPressed,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('durum beklenirken buzzer düğmesi komut üretmez', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _testApp(
        enabled: false,
        active: false,
        onPressed: () => calls++,
      ),
    );

    await tester.tap(find.text('Buzzer Durumu Bekleniyor'));
    await tester.pump();

    expect(calls, 0);
    final label = tester.widget<Text>(
      find.text('Buzzer Durumu Bekleniyor'),
    );
    expect(label.style?.color, const Color(0xFF666666));
  });

  testWidgets('aktif buzzer düğmesi kapatma görünümü ve komutu verir',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _testApp(
        enabled: true,
        active: true,
        onPressed: () => calls++,
      ),
    );

    final label = tester.widget<Text>(find.text('Buzzer Kapat'));
    expect(label.style?.color, const Color(0xFF81C784));
    await tester.tap(find.text('Buzzer Kapat'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(calls, 1);
  });
}
