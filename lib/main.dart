import 'connection_page.dart';
import 'controller_page.dart';
import 'data_model.dart';
import 'data_page.dart';
import 'map_page.dart';
import 'parameter.dart';
import 'models/agv_sensor_model.dart';
import 'models/gcs_connection_model.dart';
import 'models/gcs_mission_model.dart';
import 'models/gcs_event_log_model.dart';
import 'models/gcs_alarm_model.dart';
import 'parameter_model.dart';
import 'qr_page.dart';
import 'vehicle_3d_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

var kColorScheme = ColorScheme.fromSeed(
  seedColor: const Color.fromARGB(255, 6, 6, 6),
);

void main() {
  runApp(
    MultiProvider(
      providers: [
        // ── Mevcut modeller (değişmedi) ──────────────────────────────────
        ChangeNotifierProvider(create: (_) => DataModel()),
        ChangeNotifierProvider(create: (_) => ParameterModel()),
        ChangeNotifierProvider(create: (_) => AgvSensorModel()),
        // ── Yeni GCS modeller ─────────────────────────────────────────────
        ChangeNotifierProvider(create: (_) => GcsConnectionModel()),
        ChangeNotifierProvider(create: (_) => GcsMissionModel()),
        ChangeNotifierProvider(create: (_) => GcsAlarmModel()),
        ChangeNotifierProvider(create: (_) => GcsEventLogModel()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: false,
      builder: (context, child) {
        return MaterialApp(
          theme: ThemeData().copyWith(
            colorScheme: kColorScheme,
            appBarTheme: const AppBarTheme().copyWith(
              backgroundColor: const Color.fromRGBO(97, 97, 97, 1),
              foregroundColor: const Color.fromARGB(255, 255, 255, 255),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
                elevation: 15,
                side: const BorderSide(color: Colors.black87),
                backgroundColor: const Color.fromARGB(255, 6, 6, 6),
                foregroundColor: Colors.white,
              ),
            ),
            iconTheme: const IconThemeData(
              color: Color.fromARGB(255, 6, 6, 6),
              size: 28,
            ),
            primaryIconTheme: const IconThemeData(
              color: Color.fromARGB(255, 6, 6, 6),
              size: 24,
            ),
            buttonTheme: const ButtonThemeData().copyWith(
              buttonColor: const Color.fromARGB(255, 6, 6, 6),
            ),
            scaffoldBackgroundColor: const Color.fromARGB(255, 41, 41, 41),
            textTheme: ThemeData().textTheme.copyWith(
                  titleLarge: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 6, 6, 6),
                    fontSize: 16,
                  ),
                ),
          ),
          debugShowCheckedModeBanner: false,
          initialRoute: 'controller-page',
          routes: {
            'controller-page': (context) => const ControllerPage(),
            'connection-page': (context) => const ConnectionPage(),
            '3d-page': (context) => const Vehicle3DPage(),
            'map-page': (context) => const MapPage(),
            'QR-page': (context) => const QRPage(),
            'data-page': (context) => const DataPage(
                  site: '',
                ),
            'parameter-page': (context) => const ParameterPage()
          },
        );
      },
    );
  }
}
