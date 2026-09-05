import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:liftant_v2_bitirme/widgets/control_buttons.dart';

void main() {
  testWidgets('text input in a dialog does not trigger global button shortcuts',
      (tester) async {
    var ledCalls = 0;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  NormalButton(
                    text: 'Led',
                    assignedKey: LogicalKeyboardKey.keyL,
                    onPressed: () => ledCalls++,
                  ),
                  FilledButton(
                    key: const Key('open-text-dialog'),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const AlertDialog(
                        content: TextField(
                          key: Key('dialog-text-field'),
                          autofocus: true,
                        ),
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-text-dialog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dialog-text-field')));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.pump();

    expect(ledCalls, 0);
  });
}
