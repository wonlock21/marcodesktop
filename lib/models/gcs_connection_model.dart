import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Bağlantı alt sistemi durumu
// ─────────────────────────────────────────────────────────────────────────────

/// Her bağlantı kanalı için 3 katmanlı durum.
enum ConnDurum {
  /// Bağlantı kurulmamış / kapalı.
  cevrimdisi,

  /// Bağlanma denemesi devam ediyor.
  baglaniyor,

  /// Bağlantı aktif ve sağlıklı.
  bagli,
}

extension ConnDurumExt on ConnDurum {
  String get etiket => switch (this) {
        ConnDurum.cevrimdisi => 'Çevrimdışı',
        ConnDurum.baglaniyor => 'Bağlanıyor',
        ConnDurum.bagli      => 'Bağlı',
      };

  bool get aktif => this == ConnDurum.bagli;
}

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

/// **1. Bağlantı durumları** ve **5. Manuel kontrol güvenliği** verilerini
/// merkezi olarak tutar.
///
/// Tüm `update*` metodları atomik: notifyListeners() çağrısı sonunda
/// yalnızca bir kez gerçekleşir.
class GcsConnectionModel extends ChangeNotifier {
  // ── 1. Bağlantı kanalları ────────────────────────────────────────────────

  /// Genel sistem bağlantısı (GCS ↔ ağ / sunucu ping).
  ConnDurum sistemBaglanti = ConnDurum.cevrimdisi;

  /// Robot (Raspberry Pi) HTTP bağlantısı.
  ConnDurum robotBaglanti = ConnDurum.cevrimdisi;

  /// PLC / fabrika otomasyon haberleşmesi.
  ConnDurum plcBaglanti = ConnDurum.cevrimdisi;

  /// STM32 / alt kontrol kartı haberleşmesi.
  ConnDurum stm32Baglanti = ConnDurum.cevrimdisi;

  /// Bluetooth bağlantısı (yedek/manuel kontrol).
  ConnDurum bluetooth = ConnDurum.cevrimdisi;

  // ── 5. Manuel kontrol güvenliği ──────────────────────────────────────────

  /// Fiziksel mod anahtarı: `true` = Manuel, `false` = Otomatik.
  bool fizikselManuelMod = true;

  /// Uzaktan kontrol yetkisi: `true` = Aktif, `false` = Kilitli.
  bool uzaktanKontrolAktif = true;

  // ── Tekil güncelleyiciler ─────────────────────────────────────────────────

  void updateSistem(ConnDurum d) {
    sistemBaglanti = d;
    notifyListeners();
  }

  void updateRobot(ConnDurum d) {
    robotBaglanti = d;
    notifyListeners();
  }

  void updatePlc(ConnDurum d) {
    plcBaglanti = d;
    notifyListeners();
  }

  void updateStm32(ConnDurum d) {
    stm32Baglanti = d;
    notifyListeners();
  }

  void updateBluetooth(ConnDurum d) {
    bluetooth = d;
    notifyListeners();
  }

  void setManuelMod(bool manuel) {
    fizikselManuelMod = manuel;
    notifyListeners();
  }

  void setUzaktanKontrol(bool aktif) {
    uzaktanKontrolAktif = aktif;
    notifyListeners();
  }

  // ── Toplu güncelleme (tek notifyListeners çağrısıyla) ─────────────────────

  /// Birden fazla kanalı aynı anda günceller.
  ///
  /// Belirtilmeyen kanallar değişmez.
  void topluGuncelle({
    ConnDurum? sistem,
    ConnDurum? robot,
    ConnDurum? plc,
    ConnDurum? stm32,
    ConnDurum? bt,
    bool? manuelMod,
    bool? uzaktanKontrol,
  }) {
    if (sistem        != null) sistemBaglanti      = sistem;
    if (robot         != null) robotBaglanti       = robot;
    if (plc           != null) plcBaglanti         = plc;
    if (stm32         != null) stm32Baglanti       = stm32;
    if (bt            != null) bluetooth           = bt;
    if (manuelMod     != null) fizikselManuelMod   = manuelMod;
    if (uzaktanKontrol != null) uzaktanKontrolAktif = uzaktanKontrol;
    notifyListeners();
  }

  // ── Kolaylık getter'ları ──────────────────────────────────────────────────

  /// Tüm temel kanallar bağlı mı?
  bool get tamamenBagli =>
      sistemBaglanti.aktif && robotBaglanti.aktif;

  /// GCS bağlantı durumunu tek cümleyle özetler.
  String get ozet {
    if (tamamenBagli) { return 'Sistem Bağlı'; }
    if (sistemBaglanti == ConnDurum.baglaniyor ||
        robotBaglanti  == ConnDurum.baglaniyor) { return 'Bağlanıyor...'; }
    return 'Bağlantı Yok';
  }
}
