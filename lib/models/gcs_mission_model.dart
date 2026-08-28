import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Görev aşaması
// ─────────────────────────────────────────────────────────────────────────────

/// Bir görevin yaşam döngüsündeki aşamalar.
///
/// Kullanıcıya gösterilen Türkçe etiketler için [GorevAsamaExt.etiket] kullanın.
/// İlerleme çubuğundaki sıra için [GorevAsamaExt.adimSirasi] kullanın.
enum GorevAsama {
  /// Henüz görev planlanmamış / robot bekleme durumunda.
  bosta,

  /// Görev sisteme alındı, hazırlık aşamasında.
  gorevAlindi,

  /// Alma noktasına yüksüz hareket ediliyor.
  yuksuzHareket,

  /// Alma noktasında yük alınıyor (lift aktif).
  yukAlma,

  /// Bırakma noktasına yüklü hareket.
  yukluHareket,

  /// Kapı geçişi için PLC/otomasyon izni bekleniyor.
  kapiIzniBekleniyor,

  /// Bırakma noktasında yük indiriliyor.
  yukBirakma,

  /// Görev başarıyla tamamlandı.
  tamamlandi,

  /// Görev yazılım hatası ile kesildi.
  hata,

  /// Fiziksel veya yazılımsal acil durdurma aktif.
  acilStop,

  // ── Geriye dönük uyumluluk için eski isimler (deprecated) ─────────────────
  /// @deprecated [yuksuzHareket] kullanın.
  almayaGidiyor,

  /// @deprecated [yukAlma] kullanın.
  yukAliniyor,

  /// @deprecated [yukluHareket] kullanın.
  birakmayadGidiyor,

  /// @deprecated [yukBirakma] kullanın.
  yukBirakiliyor,

  /// @deprecated [acilStop] veya [hata] kullanın.
  iptalEdildi,
}

extension GorevAsamaExt on GorevAsama {
  String get etiket => switch (this) {
        GorevAsama.bosta => 'Beklemede',
        GorevAsama.gorevAlindi => 'Görev Alındı',
        GorevAsama.yuksuzHareket => 'Yüksüz Hareket',
        GorevAsama.yukAlma => 'Yük Alma',
        GorevAsama.yukluHareket => 'Yüklü Hareket',
        GorevAsama.kapiIzniBekleniyor => 'Kapı İzni Bekleniyor',
        GorevAsama.yukBirakma => 'Yük Bırakma',
        GorevAsama.tamamlandi => 'Görev Tamamlandı',
        GorevAsama.hata => 'Hata',
        GorevAsama.acilStop => 'Acil Stop',
        // Eski değerler → yeni etiketlere yönlendir
        GorevAsama.almayaGidiyor => 'Yüksüz Hareket',
        GorevAsama.yukAliniyor => 'Yük Alma',
        GorevAsama.birakmayadGidiyor => 'Yüklü Hareket',
        GorevAsama.yukBirakiliyor => 'Yük Bırakma',
        GorevAsama.iptalEdildi => 'İptal Edildi',
      };

  bool get aktif =>
      this != GorevAsama.bosta &&
      this != GorevAsama.tamamlandi &&
      this != GorevAsama.hata &&
      this != GorevAsama.acilStop &&
      this != GorevAsama.iptalEdildi;

  bool get hataVeyaStop =>
      this == GorevAsama.hata || this == GorevAsama.acilStop;

  /// Bir sonraki beklenen operasyon adımı (UI özeti için).
  String get sonrakiAdim => switch (this) {
        GorevAsama.bosta => 'Görev bekleniyor',
        GorevAsama.gorevAlindi => 'Yüksüz harekete geç',
        GorevAsama.yuksuzHareket => 'Alma noktasında yük al',
        GorevAsama.yukAlma => 'Yüklü harekete geç',
        GorevAsama.yukluHareket => 'Kapı iznini bekle',
        GorevAsama.kapiIzniBekleniyor => 'Geçiş izni alındıktan sonra ilerle',
        GorevAsama.yukBirakma => 'Yükü bırak ve başlangıca dön',
        GorevAsama.tamamlandi => 'Yeni görev bekleniyor',
        GorevAsama.hata => 'Operatör müdahalesi bekleniyor',
        GorevAsama.acilStop => 'Operatör müdahalesi bekleniyor',
        // Eski değerler
        GorevAsama.almayaGidiyor => 'Alma noktasında yük al',
        GorevAsama.yukAliniyor => 'Bırakma noktasına git',
        GorevAsama.birakmayadGidiyor => 'Bırakma noktasında yük bırak',
        GorevAsama.yukBirakiliyor => 'Başlangıca dön',
        GorevAsama.iptalEdildi => 'Operatör müdahalesi gerekli',
      };

  /// İlerleme çubuğundaki index (0–6). -1 = hata/stop/bosta.
  int get adimSirasi => switch (this) {
        GorevAsama.gorevAlindi => 0,
        GorevAsama.yuksuzHareket => 1,
        GorevAsama.almayaGidiyor => 1,
        GorevAsama.yukAlma => 2,
        GorevAsama.yukAliniyor => 2,
        GorevAsama.yukluHareket => 3,
        GorevAsama.birakmayadGidiyor => 3,
        GorevAsama.kapiIzniBekleniyor => 4,
        GorevAsama.yukBirakma => 5,
        GorevAsama.yukBirakiliyor => 5,
        GorevAsama.tamamlandi => 6,
        _ => -1,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

/// **2. Görev bilgileri** ve **4. Otomasyon bilgileri** verilerini
/// merkezi olarak tutar.
///
/// Telemetri (hız, voltaj, QR…) [AgvSensorModel] sorumluluğundadır;
/// bu model yalnızca görev planı ve fabrika otomasyon katmanını yönetir.
class GcsMissionModel extends ChangeNotifier {
  // ── 2. Görev bilgileri ───────────────────────────────────────────────────

  /// Unique görev tanımlayıcısı (örn. "MSN-0042").
  /// Görev yoksa boş string.
  String gorevId = '';

  /// plc | mock_plc | gui
  String gorevKaynagi = '';

  /// Alma noktası kodu (örn. "A2", "QA2.1").
  String almaNoktasi = '';

  /// Bırakma noktası kodu (örn. "B3", "QB3.1").
  String birakNoktasi = '';

  /// Çok duraklı görevin ROS düğümleri, seçim sırasıyla.
  List<String> rotaDugumleri = const [];
  int aktifDurakIndeksi = 0;
  bool baslangicaDon = true;

  /// Görev yaşam döngüsünde bulunulan aşama.
  GorevAsama asama = GorevAsama.bosta;

  /// Görev başlangıcından bu yana geçen süre.
  /// Görev yokken [Duration.zero].
  Duration gorevSuresi = Duration.zero;

  // ── 4. Otomasyon bilgileri ───────────────────────────────────────────────

  /// PLC'den alınan kapı geçiş izni: `true` = geçiş serbest.
  bool kapiIzni = false;

  /// Fabrika otomasyon sisteminden gelen son durum mesajı.
  String sonOtomasyonMesaj = '';

  /// GCS → PLC/fabrika otomasyonuna gönderilen son mesaj.
  String sonGonderilenMesaj = '';

  /// Lift (fork) mekanik durumu: `true` = kaldırılmış / yük var.
  bool liftKaldirildi = false;

  // ── Görev güncelleyicileri ─────────────────────────────────────────────

  /// Yeni bir görevi başlatır ve tüm alanları sıfırlar.
  void gorevBaslat({
    required String id,
    required String almaNoktasi,
    required String birakNoktasi,
  }) {
    gorevId = id;
    this.almaNoktasi = almaNoktasi;
    this.birakNoktasi = birakNoktasi;
    asama = GorevAsama.almayaGidiyor;
    gorevSuresi = Duration.zero;
    notifyListeners();
  }

  /// Görev aşamasını ilerletir.
  void asamaGuncelle(GorevAsama yeniAsama) {
    asama = yeniAsama;
    notifyListeners();
  }

  /// Geçen süreyi günceller (her saniye çağrılır).
  void sureyiArtir(Duration delta) {
    if (asama.aktif) {
      gorevSuresi += delta;
      notifyListeners();
    }
  }

  /// Aktif görevi sonlandırır.
  ///
  /// [hata] true → Hata durumu; [acilStop] true → Acil Stop; aksi → Tamamlandı.
  void goreviBitir({bool hata = false, bool acilStop = false}) {
    if (acilStop) {
      asama = GorevAsama.acilStop;
    } else if (hata) {
      asama = GorevAsama.hata;
    } else {
      asama = GorevAsama.tamamlandi;
    }
    notifyListeners();
  }

  // ── Otomasyon güncelleyicileri ────────────────────────────────────────────

  void setKapiIzni(bool izin) {
    kapiIzni = izin;
    notifyListeners();
  }

  void setSonOtomasyonMesaj(String mesaj) {
    sonOtomasyonMesaj = mesaj;
    notifyListeners();
  }

  void setSonGonderilenMesaj(String mesaj) {
    sonGonderilenMesaj = mesaj;
    notifyListeners();
  }

  void setLiftDurum(bool kaldirildi) {
    liftKaldirildi = kaldirildi;
    notifyListeners();
  }

  /// Otomasyon verilerini toplu günceller (tek notifyListeners çağrısı).
  void otomasyonGuncelle({
    bool? kapiIzni,
    String? otomasyonMesaj,
    bool? liftKaldirildi,
  }) {
    if (kapiIzni != null) this.kapiIzni = kapiIzni;
    if (otomasyonMesaj != null) sonOtomasyonMesaj = otomasyonMesaj;
    if (liftKaldirildi != null) this.liftKaldirildi = liftKaldirildi;
    notifyListeners();
  }

  /// Tüm görev ve otomasyon alanlarını tek seferde günceller.
  ///
  /// ROS durum mesajı gibi dış kaynaklı veri yüklemesi için
  /// tasarlanmıştır; tek notifyListeners çağrısı gerçekleşir.
  void topluGuncelle({
    String? gorevId,
    String? gorevKaynagi,
    String? almaNoktasi,
    String? birakNoktasi,
    List<String>? rotaDugumleri,
    int? aktifDurakIndeksi,
    bool? baslangicaDon,
    GorevAsama? asama,
    Duration? gorevSuresi,
    bool? kapiIzni,
    String? sonOtomasyonMesaj,
    String? sonGonderilenMesaj,
    bool? liftKaldirildi,
  }) {
    if (gorevId != null) this.gorevId = gorevId;
    if (gorevKaynagi != null) this.gorevKaynagi = gorevKaynagi;
    if (almaNoktasi != null) this.almaNoktasi = almaNoktasi;
    if (birakNoktasi != null) this.birakNoktasi = birakNoktasi;
    if (rotaDugumleri != null) {
      this.rotaDugumleri = List.unmodifiable(rotaDugumleri);
    }
    if (aktifDurakIndeksi != null) this.aktifDurakIndeksi = aktifDurakIndeksi;
    if (baslangicaDon != null) this.baslangicaDon = baslangicaDon;
    if (asama != null) this.asama = asama;
    if (gorevSuresi != null) this.gorevSuresi = gorevSuresi;
    if (kapiIzni != null) this.kapiIzni = kapiIzni;
    if (sonOtomasyonMesaj != null) this.sonOtomasyonMesaj = sonOtomasyonMesaj;
    if (sonGonderilenMesaj != null) {
      this.sonGonderilenMesaj = sonGonderilenMesaj;
    }
    if (liftKaldirildi != null) this.liftKaldirildi = liftKaldirildi;
    notifyListeners();
  }

  // ── Kolaylık getter'ları ──────────────────────────────────────────────────

  /// Görev aktif mi?
  bool get gorevAktif => asama.aktif;

  /// Görev süresini MM:SS formatında döner.
  String get gorevSuresiFormatli {
    final m = gorevSuresi.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = gorevSuresi.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Kısa özet (log / debug için).
  String get ozet =>
      gorevId.isEmpty ? 'Görev yok' : '$gorevId | ${asama.etiket}';
}
