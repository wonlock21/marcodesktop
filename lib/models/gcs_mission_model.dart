import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Görev aşaması
// ─────────────────────────────────────────────────────────────────────────────

/// Bir görevin yaşam döngüsündeki aşamalar.
enum GorevAsama {
  /// Henüz görev planlanmamış / robot bekleme durumunda.
  bosta,

  /// Alma noktasına hareket ediliyor.
  almayaGidiyor,

  /// Alma noktasında yük alınıyor (lift aktif).
  yukAliniyor,

  /// Bırakma noktasına yüklü hareket.
  birakmayadGidiyor,

  /// Bırakma noktasında yük indiriliyor.
  yukBirakiliyor,

  /// Görev başarıyla tamamlandı, robota geri dönüş.
  tamamlandi,

  /// Görev hata veya acil stop ile kesildi.
  iptalEdildi,
}

extension GorevAsamaExt on GorevAsama {
  String get etiket => switch (this) {
        GorevAsama.bosta            => 'Boşta',
        GorevAsama.almayaGidiyor    => 'Alma Noktasına Gidiyor',
        GorevAsama.yukAliniyor      => 'Yük Alınıyor',
        GorevAsama.birakmayadGidiyor => 'Bırakma Noktasına Gidiyor',
        GorevAsama.yukBirakiliyor   => 'Yük Bırakılıyor',
        GorevAsama.tamamlandi       => 'Tamamlandı',
        GorevAsama.iptalEdildi      => 'İptal Edildi',
      };

  bool get aktif =>
      this != GorevAsama.bosta &&
      this != GorevAsama.tamamlandi &&
      this != GorevAsama.iptalEdildi;
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

  /// Alma noktası kodu (örn. "A2", "QA2.1").
  String almaNoktasi = '';

  /// Bırakma noktası kodu (örn. "B3", "QB3.1").
  String birakNoktasi = '';

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

  /// Lift (fork) mekanik durumu: `true` = kaldırılmış / yük var.
  bool liftKaldirildi = false;

  // ── Görev güncelleyicileri ─────────────────────────────────────────────

  /// Yeni bir görevi başlatır ve tüm alanları sıfırlar.
  void gorevBaslat({
    required String id,
    required String almaNoktasi,
    required String birakNoktasi,
  }) {
    gorevId         = id;
    this.almaNoktasi  = almaNoktasi;
    this.birakNoktasi = birakNoktasi;
    asama           = GorevAsama.almayaGidiyor;
    gorevSuresi     = Duration.zero;
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

  /// Aktif görevi sıfırlar.
  void goreviBitir({bool iptal = false}) {
    asama = iptal ? GorevAsama.iptalEdildi : GorevAsama.tamamlandi;
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

  void setLiftDurum(bool kaldirildi) {
    liftKaldirildi = kaldirildi;
    notifyListeners();
  }

  /// Otomasyon verilerini toplu günceller (tek notifyListeners çağrısı).
  void otomasyonGuncelle({
    bool?   kapiIzni,
    String? otomasyonMesaj,
    bool?   liftKaldirildi,
  }) {
    if (kapiIzni       != null) this.kapiIzni           = kapiIzni;
    if (otomasyonMesaj != null) sonOtomasyonMesaj        = otomasyonMesaj;
    if (liftKaldirildi != null) this.liftKaldirildi      = liftKaldirildi;
    notifyListeners();
  }

  /// Tüm görev ve otomasyon alanlarını tek seferde günceller.
  ///
  /// [GcsMockData.applyToMission] gibi dış kaynaklı veri yüklemesi için
  /// tasarlanmıştır; tek notifyListeners çağrısı gerçekleşir.
  void topluGuncelle({
    String?     gorevId,
    String?     almaNoktasi,
    String?     birakNoktasi,
    GorevAsama? asama,
    Duration?   gorevSuresi,
    bool?       kapiIzni,
    String?     sonOtomasyonMesaj,
    bool?       liftKaldirildi,
  }) {
    if (gorevId            != null) this.gorevId            = gorevId;
    if (almaNoktasi        != null) this.almaNoktasi        = almaNoktasi;
    if (birakNoktasi       != null) this.birakNoktasi       = birakNoktasi;
    if (asama              != null) this.asama              = asama;
    if (gorevSuresi        != null) this.gorevSuresi        = gorevSuresi;
    if (kapiIzni           != null) this.kapiIzni           = kapiIzni;
    if (sonOtomasyonMesaj  != null) this.sonOtomasyonMesaj  = sonOtomasyonMesaj;
    if (liftKaldirildi     != null) this.liftKaldirildi     = liftKaldirildi;
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
