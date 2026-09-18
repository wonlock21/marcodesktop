import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/field_graph_models.dart';
import 'ros_bridge_client.dart';

class AgvService {
  static final RosBridgeClient ros = RosBridgeClient();

  static Future<void> connectRos(String address) => ros.connect(address);

  static Future<void> disconnectRos() => ros.disconnect();

  static Future<Map<String, dynamic>> startMission() => ros.startMission();

  static Future<Map<String, dynamic>> resumeMission() => ros.resumeMission();

  static Future<Map<String, dynamic>> submitManualTask({
    required String taskId,
    required String pickupNode,
    required String dropoffNode,
  }) =>
      ros.submitManualTask(
        taskId: taskId,
        pickupNode: pickupNode,
        dropoffNode: dropoffNode,
      );

  static Future<Map<String, dynamic>> submitMission({
    required String taskId,
    required List<String> routeNodes,
    bool returnHome = true,
  }) =>
      ros.submitMission(
        taskId: taskId,
        routeNodes: routeNodes,
        returnHome: returnHome,
      );

  static Future<Map<String, dynamic>> cancelMission() => ros.cancelMission();

  static Future<Map<String, dynamic>> resetMissionSafety() =>
      ros.resetMissionSafety();

  static Future<Map<String, dynamic>> emergencyStop() => ros.emergencyStop();

  static Future<Map<String, dynamic>> startMapping(
          {required String fieldName}) =>
      ros.startMapping(fieldName: fieldName);

  static Future<Map<String, dynamic>> stopMapping() => ros.stopMapping();

  static Future<Map<String, dynamic>> saveMapping([
    Map<String, dynamic> args = const {},
  ]) =>
      ros.saveMapping(args);

  static Future<Map<String, dynamic>> listFields() => ros.listFields();

  static Future<Map<String, dynamic>> getFieldGraph(String fieldName) =>
      ros.getFieldGraph(fieldName);

  static Future<Map<String, dynamic>> saveFieldNode({
    required String fieldName,
    required FieldNode node,
  }) =>
      ros.saveFieldNode(fieldName: fieldName, node: node);

  static Future<Map<String, dynamic>> saveCurrentPoseNode({
    required String fieldName,
    required FieldNode node,
  }) =>
      ros.saveCurrentPoseNode(fieldName: fieldName, node: node);

  static Future<Map<String, dynamic>> deleteFieldNode({
    required String fieldName,
    required int nodeId,
    required bool deleteConnectedEdges,
  }) =>
      ros.deleteFieldNode(
        fieldName: fieldName,
        nodeId: nodeId,
        deleteConnectedEdges: deleteConnectedEdges,
      );

  static Future<Map<String, dynamic>> saveFieldEdge({
    required String fieldName,
    required FieldEdge edge,
  }) =>
      ros.saveFieldEdge(fieldName: fieldName, edge: edge);

  static Future<Map<String, dynamic>> deleteFieldEdge({
    required String fieldName,
    required int edgeId,
  }) =>
      ros.deleteFieldEdge(fieldName: fieldName, edgeId: edgeId);

  static Future<Map<String, dynamic>> pixelToMap({
    required String fieldName,
    required double pixelX,
    required double pixelY,
    required double screenYaw,
  }) =>
      ros.pixelToMap(
        fieldName: fieldName,
        pixelX: pixelX,
        pixelY: pixelY,
        screenYaw: screenYaw,
      );

  static Future<Map<String, dynamic>> validateField(String fieldName) =>
      ros.validateField(fieldName);

  static Future<Map<String, dynamic>> activateField({
    required String fieldName,
    required String expectedHash,
  }) =>
      ros.activateField(fieldName: fieldName, expectedHash: expectedHash);

  static Future<Map<String, dynamic>> deactivateField({
    required String fieldName,
    required String expectedHash,
  }) =>
      ros.deactivateField(fieldName: fieldName, expectedHash: expectedHash);

  static Future<Map<String, dynamic>> archiveField(String fieldName) =>
      ros.archiveField(fieldName);

  static Future<Map<String, dynamic>> getActiveField() => ros.getActiveField();

  static Future<Map<String, dynamic>> startLocalization({
    required String fieldName,
  }) =>
      ros.startLocalization(fieldName: fieldName);

  static Future<Map<String, dynamic>> stopLocalization() =>
      ros.stopLocalization();

  static Future<Map<String, dynamic>> setBuzzerEnabled(bool enabled) =>
      ros.setBuzzerEnabled(enabled);

  static Future<Map<String, dynamic>> saveDemoPoint(String pointName) =>
      ros.saveDemoPoint(pointName);

  static Future<Map<String, dynamic>> saveDemoRoutePoint(String targetName) =>
      ros.saveDemoRoutePoint(targetName);

  static Future<Map<String, dynamic>> clearDemoRoute(String targetName) =>
      ros.clearDemoRoute(targetName);

  static Future<Map<String, dynamic>> startSavedDemo() => ros.startSavedDemo();

  static Future<Map<String, dynamic>> continueDemo() => ros.continueDemo();

  static Future<Map<String, dynamic>> cancelDemo() => ros.cancelDemo();

  static bool prepareSavedDemoStart() => ros.prepareSavedDemoStart();

  // ── G.2 stations stubs ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> addStation({
    required String name,
    required String type,
    required double pixelX,
    required double pixelY,
    required double screenYaw,
    required String fieldName,
  }) =>
      ros.addStation(
        name: name,
        type: type,
        pixelX: pixelX,
        pixelY: pixelY,
        screenYaw: screenYaw,
        fieldName: fieldName,
      );

  static Future<Map<String, dynamic>> updateStation({
    required String name,
    required String type,
    required double pixelX,
    required double pixelY,
    required double screenYaw,
    required String fieldName,
  }) =>
      ros.updateStation(
        name: name,
        type: type,
        pixelX: pixelX,
        pixelY: pixelY,
        screenYaw: screenYaw,
        fieldName: fieldName,
      );

  static Future<Map<String, dynamic>> deleteStation({required String name}) =>
      ros.deleteStation(name: name);

  static Future<Map<String, dynamic>> listStations([
    Map<String, dynamic> args = const {},
  ]) =>
      ros.listStations(args);

  // ── H.2 routes stubs ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> saveRoute({
    required String name,
    required List<String> nodeNames,
  }) =>
      ros.saveRoute(name: name, nodeNames: nodeNames);

  static Future<Map<String, dynamic>> listRoutes([
    Map<String, dynamic> args = const {},
  ]) =>
      ros.listRoutes(args);

  static Future<Map<String, dynamic>> deleteRoute({required String name}) =>
      ros.deleteRoute(name: name);

  /// Birimsiz yön/ölçek komutu (`/cmd_vel_manual`). Gerçek hız STM32’de.
  static bool publishManual(double linearX, double angularZ) =>
      ros.publishManualTwist(linearX, angularZ);

  static void stopManual() => ros.stopManual();

  /// Güncel ROS kaynaklarında genel string donanım komut topic'i yoktur.
  static bool sendHardwareCommand(String command) =>
      ros.publishHardwareCommand(command);

  /// Güncel ROS kaynaklarında LED komut arayüzü yoktur.
  static bool setLed() => false;

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

  /// Belirtilen komutu süre boyunca 50ms aralıklarla ROS üzerinden gönderir.
  static Future<void> startSendingData(String command, Duration duration) {
    final endMs =
        DateTime.now().millisecondsSinceEpoch + duration.inMilliseconds;
    final completer = Completer<void>();
    Timer? t;
    t = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (DateTime.now().millisecondsSinceEpoch >= endMs) {
        t?.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }
      sendHardwareCommand(command);
    });
    return completer.future;
  }
}
