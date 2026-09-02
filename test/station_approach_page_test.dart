import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftant_v2_bitirme/models/gcs_station_approach_model.dart';
import 'package:liftant_v2_bitirme/station_approach_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('dar Android boyutunda tek sütun taşmadan çizilir',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GcsStationApproachModel(),
        child: const MaterialApp(home: StationApproachPage()),
      ),
    );
    await tester.pump();

    expect(find.text('İstasyon Yaklaşma Ayarları'), findsOneWidget);
    expect(find.text('A1'), findsOneWidget);
    expect(find.text('Yapılandırma eksik'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
