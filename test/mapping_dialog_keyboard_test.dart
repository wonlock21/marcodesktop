import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftant_v2_bitirme/widgets/control_buttons.dart';
import 'package:liftant_v2_bitirme/widgets/mapping_field_name_dialog.dart';

void main() {
  testWidgets('saha adı dialogu Escape ile hatasız kapanır', (tester) async {
    String? result = 'not-closed';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showMappingFieldNameDialog(
                  context: context,
                  initialValue: 'saha_01',
                );
              },
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    expect(find.text('Saha adı'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Saha adı'), findsNothing);
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('metin alanında L yazılırken LED kısayolu çalışmaz',
      (tester) async {
    var ledCommands = 0;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, child) => MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const TextField(key: ValueKey('field')),
                NormalButton(
                  text: 'Led',
                  assignedKey: LogicalKeyboardKey.keyL,
                  onPressed: () => ledCommands++,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('field')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.pump();

    expect(ledCommands, 0);
    expect(tester.takeException(), isNull);
  });
}
