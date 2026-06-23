import 'dart:convert';
import 'package:http/http.dart' as http;

class AgvService {
  static Future<bool> checkConnection(String site) async {
    if (site.isEmpty) return false;
    try {
      final response = await http.get(Uri.parse(site));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Returns (x, y, yaw) after the server-side swap, or null on error.
  static Future<(double, double, double)?> fetchPose(
    String site, {
    double fallbackX = 0,
    double fallbackY = 0,
    double fallbackYaw = 0,
  }) async {
    if (site.isEmpty) return null;
    try {
      final resp = await http
          .get(Uri.parse('$site/pose'))
          .timeout(const Duration(seconds: 2));
      if (resp.statusCode == 200) {
        final parts = resp.body.trim().split('/');
        if (parts.length >= 3) {
          final x = double.tryParse(parts[0]) ?? fallbackX;
          final y = double.tryParse(parts[1]) ?? fallbackY;
          final yaw = double.tryParse(parts[2]) ?? fallbackYaw;
          return (y * 10, x * 10, yaw); // x/y swap — sunucu sözleşmesi
        }
      }
    } catch (_) {}
    return null;
  }

  /// Returns ({sicaklik, voltage, amper}) or null on error.
  static Future<({String sicaklik, String voltage, String amper})?>
      fetchSensorData(String site) async {
    if (site.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse('$site/s'));
      if (response.statusCode == 200) {
        final parts = response.body.split('/');
        if (parts.length >= 3) {
          return (
            sicaklik: parts[0],
            voltage: parts[1],
            amper: parts[2],
          );
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> fetchQRData(String site) async {
    if (site.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse('$site/qrliste'));
      if (response.statusCode == 200) return response.body;
    } catch (_) {}
    return null;
  }

  static Future<String?> fetchRfid(String site) async {
    if (site.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse('$site/rfid'));
      if (response.statusCode == 200) return response.body;
    } catch (_) {}
    return null;
  }

  static Future<void> veriBas(String site, String veri) async {
    if (site.isEmpty) return;
    try {
      await http.get(Uri.parse('$site/$veri'));
    } catch (_) {}
  }

  /// Tek /telemetri endpoint'inden tüm durum verisini çeker.
  ///
  /// Beklenen JSON sözleşmesi (robot tarafı):
  /// ```json
  /// {
  ///   "durum":    "idle",          // robotDurum (kRobotDurum* sabitlerinden biri)
  ///   "gorev":    "",              // görev açıklama metni
  ///   "hiz":      0.0,             // anlık hız m/s
  ///   "batarya":  75.0,            // batarya % (0–100)
  ///   "lift":     false,           // lift açık/kapalı (bool)
  ///   "plcDurum": "bagli",         // PLC haberleşme durumu
  ///   "plcMesaj": "",              // son PLC mesajı
  ///   "qrKonum":  "x:1.2,y:0.3",  // QR kamera pozisyonu
  ///   "x": 1.23, "y": 4.56, "yaw": 90.0,          // konum (opsiyonel)
  ///   "sicaklik": "25", "voltaj": "24", "akim": "1.5", // sensör (opsiyonel)
  ///   "qr": "QA1.1", "rfid": ""                    // QR/RFID (opsiyonel)
  /// }
  /// ```
  /// Robot tarafı /telemetri yoksa `null` döner; Faz 7'de fallback devreye girer.
  static Future<Map<String, dynamic>?> fetchTelemetri(String site) async {
    if (site.isEmpty) return null;
    try {
      final resp = await http
          .get(Uri.parse('$site/telemetri'))
          .timeout(const Duration(seconds: 2));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> startSendingData(
      String site, String command, Duration duration) async {
    final endTime =
        DateTime.now().millisecondsSinceEpoch + duration.inMilliseconds;
    while (DateTime.now().millisecondsSinceEpoch < endTime) {
      await veriBas(site, command);
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }
}
