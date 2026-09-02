import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftant_v2_bitirme/widgets/control_buttons.dart';

void main() {
  testWidgets('basılı manuel düğme dispose olurken sıfır/release üretir',
      (tester) async {
    var pressed = 0;
    var released = 0;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: ControlButton(
                assignedKey: LogicalKeyboardKey.keyW,
                onPressed: () => pressed++,
                onReleased: () => released++,
                child: const Icon(Icons.arrow_upward),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ControlButton)),
    );
    await tester.pump();
    expect(pressed, 1);
    expect(released, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(released, 1);
    await gesture.removePointer();
  });
}
