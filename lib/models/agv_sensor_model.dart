import 'package:flutter/foundation.dart';

/// 8 zorunlu robot durumu (2026 şartname §3.1.1 madde 10a–h).
/// Robot tarafı bu string'lerden birini /telemetri "durum" alanında gönderir.
const kRobotDurumIdle = 'idle';
const kRobotDurumGorevIsleniyor = 'gorevIsleniyor';
const kRobotDurumYuksuzHareket = 'yuksuzHareket';
const kRobotDurumYukluHareket = 'yukluHareket';
const kRobotDurumKapiBekle = 'kapiBekle';
const kRobotDurumBaslangicaDon = 'baslangicaDon';
const kRobotDurumHata = 'hata';
const kRobotDurumAcilStop = 'acilStop';

class AgvSensorModel extends ChangeNotifier {
  // ── Mevcut alanlar (korunuyor) ────────────────────────────────────────
  String sicaklik = "";
  String voltage = "";
  String amper = "";
  String isCharging = "Çalışıyor";
  String sonQR = "null";
  double currX = 0.0;
  double currY = 0.0;
  double currYaw = 0.0;

  bool lokalizasyonGecerli = false;
  double pozisyonKovaryansi = double.infinity;
  String aktifRotaEdge = '';
  String sonrakiNode = '';
  double rotaSapmasi = double.nan;
  bool engelAlgilandi = false;
  bool estopAktif = false;

  // ── 2026 Şartname — zorunlu UI alanları ──────────────────────────────
  /// Robot anlık durum (8 sabit: kRobotDurum*).
  String robotDurum = kRobotDurumIdle;

  /// Görev açıklama/durum metni (örn. "A2 → B3 taşınıyor").
  String gorevDurum = "";

  /// Lift (fork) açık mı / yük var mı.
  bool liftAcik = false;

  /// Anlık hız — m/s.
  double anlikHiz = 0.0;

  /// Batarya seviyesi — 0.0–100.0 (%).
  double bataryaYuzde = 0.0;

  /// Fabrika otomasyon (PLC) haberleşme durumu.
  String plcDurum = "bağlantı yok";

  /// Fabrika otomasyon sisteminden alınan son mesaj.
  String plcSonMesaj = "";

  /// QR kodun kameraya göre pozisyonu (örn. "x:0.12,y:-0.05,z:0.80").
  String qrKonum = "";

  /// QR doğrulama durumu (örn. "Geçerli", "Hatalı").
  String qrDogrulama = "";

  /// Konum doğrulama sonucu (örn. "Onaylandı", "Sapma").
  String konumDogrulamaSonucu = "";

  /// Konum hatası — metre cinsinden metin (örn. "0.04 m").
  String konumHatasi = "";

  /// Yön hatası — derece cinsinden metin (örn. "2.1°").
  String yonHatasi = "";

  // ── Mevcut update metodları (imza değişmedi) ─────────────────────────

  void updateSensor({
    required String sicaklik,
    required String voltage,
    required String amper,
  }) {
    this.sicaklik = sicaklik;
    this.voltage = voltage;
    this.amper = amper;
    _updateChargingStatus();
    notifyListeners();
  }

  void updatePose(double x, double y, double yaw) {
    currX = x;
    currY = y;
    currYaw = yaw;
    notifyListeners();
  }

  void updateQR(String qr) {
    sonQR = qr;
    notifyListeners();
  }

  // ── Yeni update metodları (2026 şartname) ────────────────────────────

  void updateRobotDurum(String durum) {
    robotDurum = durum;
    notifyListeners();
  }

  void updateGorev(String durum) {
    gorevDurum = durum;
    notifyListeners();
  }

  void updateLift({required bool acik, double? hiz}) {
    liftAcik = acik;
    if (hiz != null) anlikHiz = hiz;
    notifyListeners();
  }

  void updateBatarya(double yuzde) {
    bataryaYuzde = yuzde.clamp(0.0, 100.0);
    notifyListeners();
  }

  void updatePowerTelemetry({
    required double linearSpeed,
    required double voltage,
    required double current,
    required double temperature,
  }) {
    if (linearSpeed.isFinite) anlikHiz = linearSpeed;
    if (voltage.isFinite) this.voltage = voltage.toStringAsFixed(2);
    if (current.isFinite) amper = current.toStringAsFixed(2);
    if (temperature.isFinite) sicaklik = temperature.toStringAsFixed(1);
    _updateChargingStatus();
    notifyListeners();
  }

  void updatePlc({required String durum, String mesaj = ""}) {
    plcDurum = durum;
    if (mesaj.isNotEmpty) plcSonMesaj = mesaj;
    notifyListeners();
  }

  void updateQrKonum(String konum) {
    qrKonum = konum;
    notifyListeners();
  }

  /// /robot_status alanlarini tek bildirimle mevcut ekran modeline uygular.
  void updateRobotStatus({
    required double x,
    required double y,
    required double yaw,
    required bool localizationValid,
    required double positionCovariance,
    required String currentRouteEdge,
    required String nextNode,
    required double crossTrackError,
    required bool obstacleDetected,
    required String lastQrData,
    required bool plcConnected,
    required bool estopActive,
  }) {
    currX = x;
    currY = y;
    currYaw = yaw;
    lokalizasyonGecerli = localizationValid;
    pozisyonKovaryansi = positionCovariance;
    aktifRotaEdge = currentRouteEdge;
    sonrakiNode = nextNode;
    rotaSapmasi = crossTrackError;
    engelAlgilandi = obstacleDetected;
    if (lastQrData.isNotEmpty) sonQR = lastQrData;
    plcDurum = plcConnected ? 'bağlı' : 'bağlantı yok';
    estopAktif = estopActive;
    notifyListeners();
  }

  // ── GEÇİCİ: Admin/demo modu için örnek veri ──────────────────────────
  /// TODO(kaldır): Admin modu kaldırılınca bu metot da silinmeli.
  /// Rapor ekran görüntüleri için gerçekçi örnek değerler basar.
  void loadDemoData() {
    sicaklik = "36.5";
    voltage = "24.6";
    amper = "1.8";
    sonQR = "QA2.1";
    currX = 3.2;
    currY = 2.1;
    currYaw = 0.45;
    robotDurum = kRobotDurumYukluHareket;
    gorevDurum = "A2 → B3 yük taşınıyor";
    liftAcik = true;
    anlikHiz = 0.85;
    bataryaYuzde = 78.0;
    plcDurum = "bağlı";
    plcSonMesaj = "Kapı açıldı, geçebilirsin";
    qrKonum = "x:0.12, y:-0.05, z:0.80";
    qrDogrulama = "Geçerli";
    konumDogrulamaSonucu = "Onaylandı";
    konumHatasi = "0.04 m";
    yonHatasi = "2.1°";
    _updateChargingStatus();
    notifyListeners();
  }

  // ── İç yardımcı ──────────────────────────────────────────────────────

  void _updateChargingStatus() {
    final val = double.tryParse(amper);
    if (val != null) {
      isCharging = val >= 1.0 ? "Şarj Doluyor" : "Çalışıyor";
    } else {
      isCharging = amper.isEmpty ? "Bağlantı Yok" : "Çalışıyor";
    }
  }
}
