import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Alarm türleri
// ─────────────────────────────────────────────────────────────────────────────

/// Sistemde tanımlı tüm alarm/hata kodu türleri.
///
/// Dart identifier kuralı gereği Türkçe karakter kullanılmamıştır;
/// görüntüleme metinleri [AlarmTurExt.etiket] üzerinden sağlanır.
enum AlarmTur {
  /// 1  — Sistem genelinde aktif alarm yok (bilgi / temiz durum).
  temiz,

  /// 2  — Acil stop aktif (fiziksel güvenlik düğmesi veya yazılım).
  acilStop,

  /// 3  — PLC bağlantı hatası.
  plcBaglantiHata,

  /// 4  — Robot bağlantı hatası.
  robotBaglantiHata,

  /// 5  — STM32 alt kontrol haberleşme hatası.
  stm32HaberlesmeHata,

  /// 6  — Düşük batarya uyarısı.
  dusukBatarya,

  /// 7  — QR okuma hatası.
  qrOkumaHata,

  /// 8  — Limit switch tetiklendi.
  limitSwitchHata,

  /// 9  — Güvenlik sensörü uyarısı (engel / alan ihlali).
  guvenlikSensorUyari,

  /// 10 — Motor sürücü hatası.
  motorSurucuHata,
}

extension AlarmTurExt on AlarmTur {
  /// Kullanıcıya gösterilen kısa Türkçe açıklama.
  String get etiket => switch (this) {
        AlarmTur.temiz              => 'Alarm Yok',
        AlarmTur.acilStop           => 'Acil Stop Aktif',
        AlarmTur.plcBaglantiHata    => 'PLC Bağlantı Hatası',
        AlarmTur.robotBaglantiHata  => 'Robot Bağlantı Hatası',
        AlarmTur.stm32HaberlesmeHata => 'STM32 Haberleşme Hatası',
        AlarmTur.dusukBatarya       => 'Düşük Batarya',
        AlarmTur.qrOkumaHata        => 'QR Okuma Hatası',
        AlarmTur.limitSwitchHata    => 'Limit Switch Hatası',
        AlarmTur.guvenlikSensorUyari => 'Güvenlik Sensörü Uyarısı',
        AlarmTur.motorSurucuHata    => 'Motor Sürücü Hatası',
      };

  /// İkon — UI'da hızlı gösterim için.
  IconData get ikon => switch (this) {
        AlarmTur.temiz               => Icons.check_circle_outline,
        AlarmTur.acilStop            => Icons.dangerous,
        AlarmTur.plcBaglantiHata     => Icons.cable_outlined,
        AlarmTur.robotBaglantiHata   => Icons.wifi_off,
        AlarmTur.stm32HaberlesmeHata => Icons.memory_outlined,
        AlarmTur.dusukBatarya        => Icons.battery_alert,
        AlarmTur.qrOkumaHata         => Icons.qr_code_scanner,
        AlarmTur.limitSwitchHata     => Icons.sensor_occupied,
        AlarmTur.guvenlikSensorUyari => Icons.warning_amber,
        AlarmTur.motorSurucuHata     => Icons.settings_backup_restore,
      };

  /// Renk — kritik / uyarı / bilgi sınıflandırması.
  Color get renk => switch (this) {
        AlarmTur.temiz               => const Color(0xFF4CAF50),  // yeşil
        AlarmTur.acilStop            => const Color(0xFFF44336),  // kırmızı
        AlarmTur.plcBaglantiHata     => const Color(0xFFFF5722),
        AlarmTur.robotBaglantiHata   => const Color(0xFFFF5722),
        AlarmTur.stm32HaberlesmeHata => const Color(0xFFFF9800),  // turuncu
        AlarmTur.dusukBatarya        => const Color(0xFFFF9800),
        AlarmTur.qrOkumaHata         => const Color(0xFFFFEB3B),  // sarı
        AlarmTur.limitSwitchHata     => const Color(0xFFFF9800),
        AlarmTur.guvenlikSensorUyari => const Color(0xFFFF9800),
        AlarmTur.motorSurucuHata     => const Color(0xFFF44336),
      };

  /// Kritik seviye (true = sistem durdurulmalı).
  bool get kritik =>
      this == AlarmTur.acilStop || this == AlarmTur.motorSurucuHata;
}

// ─────────────────────────────────────────────────────────────────────────────
// Aktif alarm kaydı
// ─────────────────────────────────────────────────────────────────────────────

/// Tek bir aktif alarmın anlık görüntüsü.
class AlarmKaydi {
  final AlarmTur   tur;
  final String     mesaj;
  final DateTime   zaman;

  const AlarmKaydi({
    required this.tur,
    this.mesaj = '',
    required this.zaman,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

/// **6. Alarm ve hata durumları** verilerini merkezi olarak tutar.
///
/// Set tabanlı yapı: her [AlarmTur] en fazla bir kez aktif olabilir.
/// Ekleme/kaldırma O(1)'dir; listener sayısına göre ölçeklenir.
class GcsAlarmModel extends ChangeNotifier {
  /// Aktif alarm kayıtları — anahtar [AlarmTur], değer [AlarmKaydi].
  final Map<AlarmTur, AlarmKaydi> _aktifAlarmlar = {};

  // ── Okuma ────────────────────────────────────────────────────────────────

  /// Aktif alarm yok mu?
  bool get temiz => _aktifAlarmlar.isEmpty;

  /// Tüm aktif alarmların listesi (kopyalanmış).
  List<AlarmKaydi> get aktifAlarmlar =>
      List.unmodifiable(_aktifAlarmlar.values.toList());

  /// Belirtilen alarm aktif mi?
  bool isAktif(AlarmTur tur) => _aktifAlarmlar.containsKey(tur);

  /// Kritik seviyede alarm var mı? (sistem durdurulmalı)
  bool get kritikAlarmVar =>
      _aktifAlarmlar.keys.any((t) => t.kritik);

  /// Robot güvenli duruş modunda mı? (acil stop veya kritik alarm).
  bool get guvenliDurusAktif =>
      isAktif(AlarmTur.acilStop) || kritikAlarmVar;

  /// En yüksek öncelikli alarmı döner (acilStop > motor > diğerleri).
  AlarmTur? get enKritik {
    if (_aktifAlarmlar.isEmpty) return null;
    final kritikler = _aktifAlarmlar.keys.where((t) => t.kritik).toList();
    if (kritikler.isNotEmpty) return kritikler.first;
    return _aktifAlarmlar.keys.first;
  }

  // ── Yazma ─────────────────────────────────────────────────────────────────

  /// Alarmı aktif hale getirir.
  ///
  /// Aynı [tur] zaten aktifse mesajı ve zamanı günceller.
  void setAlarm(AlarmTur tur, {String mesaj = ''}) {
    _aktifAlarmlar[tur] = AlarmKaydi(
      tur: tur,
      mesaj: mesaj,
      zaman: DateTime.now(),
    );
    notifyListeners();
  }

  /// Alarmı temizler.
  void clearAlarm(AlarmTur tur) {
    if (_aktifAlarmlar.remove(tur) != null) {
      notifyListeners();
    }
  }

  /// Tüm alarmları tek seferde temizler.
  void clearAll() {
    if (_aktifAlarmlar.isNotEmpty) {
      _aktifAlarmlar.clear();
      notifyListeners();
    }
  }

  /// Birden fazla alarmı toplu günceller (tek notifyListeners çağrısı).
  ///
  /// [aktifOlanlar] listesindeki alarmlar eklenir,
  /// [pasifOlanlar] listesindeki alarmlar kaldırılır.
  void topluGuncelle({
    List<AlarmTur>  aktifOlanlar = const [],
    List<AlarmTur>  pasifOlanlar = const [],
  }) {
    for (final tur in aktifOlanlar) {
      _aktifAlarmlar.putIfAbsent(
        tur,
        () => AlarmKaydi(tur: tur, zaman: DateTime.now()),
      );
    }
    for (final tur in pasifOlanlar) {
      _aktifAlarmlar.remove(tur);
    }
    notifyListeners();
  }

  // ── Debug / log ───────────────────────────────────────────────────────────

  @override
  String toString() {
    if (temiz) return 'GcsAlarmModel(temiz)';
    return 'GcsAlarmModel(aktif: ${_aktifAlarmlar.keys.map((t) => t.etiket).join(", ")})';
  }
}
