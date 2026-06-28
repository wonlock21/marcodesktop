// ignore_for_file: avoid_print

import '../models/agv_sensor_model.dart';
import '../models/gcs_alarm_model.dart';
import '../models/gcs_connection_model.dart';
import '../models/gcs_event_log_model.dart';
import '../models/gcs_mission_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sabit mock değerler — gerçek cihaz yokken UI testi / rapor ekranları için.
// Bu dosya YALNIZCA admin/demo modunda kullanılır; production'da dokunulmaz.
//
// Senaryo: AGV, A2 istasyonundan yük alıp B3'e taşıyor.
// ─────────────────────────────────────────────────────────────────────────────

abstract final class GcsMockData {
  // ── Bağlantı ────────────────────────────────────────────────────────────

  static const ConnDurum mockSistem    = ConnDurum.bagli;
  static const ConnDurum mockRobot     = ConnDurum.bagli;
  static const ConnDurum mockPlc       = ConnDurum.bagli;
  static const ConnDurum mockStm32     = ConnDurum.bagli;
  static const ConnDurum mockBluetooth = ConnDurum.bagli;

  // ── Görev ────────────────────────────────────────────────────────────────

  static const String mockGorevId      = 'MSN-0042';
  static const String mockAlmaNoktasi  = 'A2';
  static const String mockBirakNoktasi = 'B3';
  static const GorevAsama mockAsama    = GorevAsama.yukluHareket;
  static const Duration mockSure       = Duration(minutes: 4, seconds: 17);

  // ── Otomasyon ────────────────────────────────────────────────────────────

  static const bool   mockKapiIzni         = true;
  static const String mockOtomasyonMesaj   = 'Kapı açıldı, geçiş serbest';
  static const String mockGonderilenMesaj  = 'GEÇİŞ_İZİN_İSTE';
  static const bool   mockLiftKaldirildi   = true;

  // ── Telemetri (AgvSensorModel senkron alanları) ──────────────────────────

  static const String mockSicaklik     = '38.2';
  static const String mockVoltage      = '24.6';
  static const String mockAmper        = '1.8';
  static const String mockSonQR        = 'QA2.1';
  static const double mockCurrX        = 3.2;
  static const double mockCurrY        = 2.1;
  static const double mockCurrYaw      = 0.45;
  static const String mockRobotDurum   = kRobotDurumYukluHareket;
  static const String mockGorevDurum   = 'A2 → B3 yük taşınıyor';
  static const bool   mockLiftAcik     = true;
  static const double mockAnlikHiz     = 0.85;
  static const double mockBataryaYuzde = 78.0;
  static const String mockPlcDurum     = 'bağlı';
  static const String mockPlcSonMesaj  = 'Kapı açıldı, geçebilirsin';
  static const String mockQrKonum      = 'x:0.12, y:-0.05, z:0.80';
  static const String mockQrDogrulama  = 'Geçerli';
  static const String mockKonumDogrulama = 'Onaylandı';
  static const String mockKonumHatasi  = '0.04 m';
  static const String mockYonHatasi    = '2.1°';

  // ── Manuel güvenlik ──────────────────────────────────────────────────────

  static const bool mockFizikselManuelMod   = false; // Otomatik modda
  static const bool mockUzaktanKontrolAktif = false; // Otomatik modda kilitli

  // ── Aktif alarmlar ────────────────────────────────────────────────────────
  //
  // Final senaryo: tüm sistemler normal — aktif alarm yok.

  static const List<AlarmTur> mockAktifAlarmlar = [];

  // ─────────────────────────────────────────────────────────────────────────
  // Uygulayıcı metodlar — her model için ayrı, null-safe
  // ─────────────────────────────────────────────────────────────────────────

  /// Tüm modellere mock veri uygular.
  ///
  /// Hangi modelin mevcut olduğunu kontrol etmez; uygulanacak modeli
  /// çağıran taraf geçer (Provider veya test ortamı).
  static void applyAll({
    required AgvSensorModel    agvModel,
    required GcsConnectionModel connModel,
    required GcsMissionModel   missionModel,
    required GcsAlarmModel     alarmModel,
    GcsEventLogModel?          eventLogModel,
  }) {
    applyToAgv(agvModel);
    applyToConnection(connModel);
    applyToMission(missionModel);
    applyToAlarms(alarmModel);
    eventLogModel?.demoYukle();
    print('[GcsMockData] Tüm mock veriler yüklendi. Senaryo: $mockGorevDurum');
  }

  /// [AgvSensorModel]'e telemetri mock verisi uygular.
  ///
  /// `AgvSensorModel.loadDemoData()` ile birebir aynı sonuç üretir;
  /// bu metot gelecekte `loadDemoData()` yerine geçecek referans noktasıdır.
  static void applyToAgv(AgvSensorModel m) {
    m
      ..sicaklik     = mockSicaklik
      ..voltage      = mockVoltage
      ..amper        = mockAmper
      ..sonQR        = mockSonQR
      ..currX        = mockCurrX
      ..currY        = mockCurrY
      ..currYaw      = mockCurrYaw
      ..robotDurum   = mockRobotDurum
      ..gorevDurum   = mockGorevDurum
      ..liftAcik     = mockLiftAcik
      ..anlikHiz     = mockAnlikHiz
      ..bataryaYuzde = mockBataryaYuzde
      ..plcDurum     = mockPlcDurum
      ..plcSonMesaj  = mockPlcSonMesaj
      ..qrKonum      = mockQrKonum
      ..qrDogrulama  = mockQrDogrulama
      ..konumDogrulamaSonucu = mockKonumDogrulama
      ..konumHatasi  = mockKonumHatasi
      ..yonHatasi    = mockYonHatasi;
    // notifyListeners() AgvSensorModel.loadDemoData() içinde çağrılır;
    // burada doğrudan alan atanıyor, dışarıdan notify gerekirse loadDemoData() çağrılmalı.
  }

  /// [GcsConnectionModel]'e mock bağlantı verisi uygular.
  static void applyToConnection(GcsConnectionModel m) {
    m.topluGuncelle(
      sistem:         mockSistem,
      robot:          mockRobot,
      plc:            mockPlc,
      stm32:          mockStm32,
      bt:             mockBluetooth,
      manuelMod:      mockFizikselManuelMod,
      uzaktanKontrol: mockUzaktanKontrolAktif,
    );
  }

  /// [GcsMissionModel]'e mock görev verisi uygular.
  static void applyToMission(GcsMissionModel m) {
    m.topluGuncelle(
      gorevId:           mockGorevId,
      almaNoktasi:       mockAlmaNoktasi,
      birakNoktasi:      mockBirakNoktasi,
      asama:             mockAsama,
      gorevSuresi:       mockSure,
      kapiIzni:          mockKapiIzni,
      sonOtomasyonMesaj: mockOtomasyonMesaj,
      sonGonderilenMesaj: mockGonderilenMesaj,
      liftKaldirildi:    mockLiftKaldirildi,
    );
  }

  /// [GcsAlarmModel]'e mock alarm verisi uygular.
  static void applyToAlarms(GcsAlarmModel m) {
    m.clearAll();
    for (final tur in mockAktifAlarmlar) {
      m.setAlarm(tur, mesaj: '[MOCK] Demo alarm');
    }
  }
}
