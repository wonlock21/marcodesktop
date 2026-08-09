/// MarCO saha haritalama / lokalizasyon / istasyon / rota ROS sözleşmesi.
///
/// Topic ve servis adları widget veya sayfa koduna yazılmaz; tek kaynak burasıdır.
/// ROS tarafında isim değişince yalnızca bu dosya güncellenir.
library;

import 'dart:convert';
import 'dart:typed_data';

// ─────────────────────────────────────────────────────────────────────────────
// Mapping durum makinesi (/mapping/status)
// ─────────────────────────────────────────────────────────────────────────────

/// `/mapping/status` sayısal kodları.
enum MappingStatus {
  /// 0 — hazır
  idle,

  /// 1 — haritalama başlatılıyor
  starting,

  /// 2 — haritalama çalışıyor (manuel sürüş açılabilir)
  mapping,

  /// 3 — durduruluyor
  stopping,

  /// 4 — hata
  error,
}

extension MappingStatusExt on MappingStatus {
  int get code => index;

  String get etiket => switch (this) {
        MappingStatus.idle => 'Hazır',
        MappingStatus.starting => 'Başlatılıyor',
        MappingStatus.mapping => 'Haritalama çalışıyor',
        MappingStatus.stopping => 'Durduruluyor',
        MappingStatus.error => 'Hata',
      };

  /// Manuel sürüş yalnız mapping sırasında.
  bool get manualDriveAllowed => this == MappingStatus.mapping;

  /// Kullanıcı “Harita Oluştur” basabilir mi?
  bool get canStartMapping =>
      this == MappingStatus.idle || this == MappingStatus.error;

  /// “Bitir / Kaydet” aktif mi?
  bool get canFinishMapping => this == MappingStatus.mapping;

  /// UI kilitli (yükleniyor) mi?
  bool get uiLocked =>
      this == MappingStatus.starting || this == MappingStatus.stopping;

  static MappingStatus fromCode(int? code) {
    if (code == null || code < 0 || code >= MappingStatus.values.length) {
      return MappingStatus.error;
    }
    return MappingStatus.values[code];
  }
}

/// Harita önizleme kaynağı (`/map_preview/metadata` içindeki `source`).
/// Enum adları ROS wire string ile aynı (`asNameMap` için).
enum MapPreviewSource {
  unknown,
  // ROS wire: "slam_toolbox" — asNameMap anahtarı birebir eşleşsin.
  // ignore: constant_identifier_names
  slam_toolbox,
  amcl,
}

extension MapPreviewSourceExt on MapPreviewSource {
  String get wireName => name;

  static MapPreviewSource fromWire(String? raw) =>
      MapPreviewSource.values.asNameMap()[raw?.trim().toLowerCase()] ??
      MapPreviewSource.unknown;
}

// ─────────────────────────────────────────────────────────────────────────────
// Düğüm / istasyon türleri (öğretme + dokunarak ekleme)
// ─────────────────────────────────────────────────────────────────────────────

enum FieldNodeType {
  alma,
  birakma,
  baslangic,
  sarj,
  kapi,
  qr,
}

extension FieldNodeTypeExt on FieldNodeType {
  String get etiket => switch (this) {
        FieldNodeType.alma => 'Alma Noktası',
        FieldNodeType.birakma => 'Bırakma Noktası',
        FieldNodeType.baslangic => 'Başlangıç',
        FieldNodeType.sarj => 'Şarj İstasyonu',
        FieldNodeType.kapi => 'Kapı Kontrol',
        FieldNodeType.qr => 'QR Noktası',
      };

  /// ROS / yerel wire adı (ileride stations servisi).
  String get wireName => switch (this) {
        FieldNodeType.alma => 'pickup',
        FieldNodeType.birakma => 'dropoff',
        FieldNodeType.baslangic => 'start',
        FieldNodeType.sarj => 'charge',
        FieldNodeType.kapi => 'gate',
        FieldNodeType.qr => 'qr',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Topic / servis sabitleri
// ─────────────────────────────────────────────────────────────────────────────

/// Çalışan ve planlanan ROS arayüz adları.
abstract final class RosMappingTopics {
  // ── Çalışan (ROS tarafı hazır) ───────────────────────────────────────────

  static const mappingStart = '/mapping/start';
  static const mappingStop = '/mapping/stop';
  static const mappingStatus = '/mapping/status';

  static const mapPreviewCompressed = '/map_preview/compressed';
  static const mapPreviewMetadata = '/map_preview/metadata';
  static const mapPreviewRobotPixel = '/map_preview/robot_pixel';

  static const cmdVelManual = '/cmd_vel_manual';

  static const mappingSave = '/mapping/save';
  static const fieldsList = '/fields/list';

  static const localizationStart = '/localization/start';
  static const localizationStop = '/localization/stop';

  static const stationsAdd = '/stations/add';
  static const stationsUpdate = '/stations/update';
  static const stationsDelete = '/stations/delete';
  static const stationsList = '/stations/list';

  static const routesSave = '/routes/save';
  static const routesList = '/routes/list';
  static const routesDelete = '/routes/delete';
}

/// rosbridge `type` alanları (SRV / MSG).
abstract final class RosMappingTypes {
  // ── Çalışan ──────────────────────────────────────────────────────────────

  static const startMappingSrv = 'marco_msgs/srv/StartMapping';

  /// Tip adı ROS ile teyit edilecek; şimdilik Trigger varsayımı.
  static const stopMappingSrv = 'std_srvs/srv/Trigger';

  static const mappingStatusMsg = 'marco_msgs/msg/MappingStatus';
  static const compressedImageMsg = 'sensor_msgs/msg/CompressedImage';
  static const mapPreviewMetadataMsg = 'marco_msgs/msg/MapPreviewMetadata';
  /// ROS wire adı (güncel): `MapPixelPose`.
  static const mapPreviewRobotPixelMsg = 'marco_msgs/msg/MapPixelPose';
  static const twistMsg = 'geometry_msgs/msg/Twist';

  // ── Yakında (isimler hazır; tip ROS gelince netleşir) ─────────────────────

  static const saveMappingSrv = 'marco_msgs/srv/SaveMapping';
  static const listFieldsSrv = 'marco_msgs/srv/ListFields';
  static const startLocalizationSrv = 'marco_msgs/srv/StartLocalization';
  static const stopLocalizationSrv = 'marco_msgs/srv/StopLocalization';

  static const addStationSrv = 'marco_msgs/srv/AddStation';
  static const updateStationSrv = 'marco_msgs/srv/UpdateStation';
  static const deleteStationSrv = 'marco_msgs/srv/DeleteStation';
  static const listStationsSrv = 'marco_msgs/srv/ListStations';

  static const saveRouteSrv = 'marco_msgs/srv/SaveRoute';
  static const listRoutesSrv = 'marco_msgs/srv/ListRoutes';
  static const deleteRouteSrv = 'marco_msgs/srv/DeleteRoute';
}

// ─────────────────────────────────────────────────────────────────────────────
// Manuel sürüş (mapping ekranı)
//
// GCS `/cmd_vel_manual` üzerine birimsiz yön/ölçek komutu basar (−1…+1).
// Gerçek m/s ve rad/s tavanı STM32 / firmware tarafındadır; burada clamp yok.
// ─────────────────────────────────────────────────────────────────────────────

abstract final class RosManualDriveLimits {
  /// Twist `linear.x` / `angular.z` komut ölçeği (birimsiz, m/s değil).
  static const double commandScaleMin = -1.0;
  static const double commandScaleMax = 1.0;

  /// UI hız kademesi (0…4) → komut büyüklüğü 0.2…1.0.
  static const int speedStepMin = 0;
  static const int speedStepMax = 4;

  /// Joystick heartbeat hedef aralığı (ms) — 10–20 Hz ⇒ 50–100 ms.
  static const int heartbeatMinMs = 50;
  static const int heartbeatMaxMs = 100;
  static const int heartbeatDefaultMs = 100;

  static double clampCommandScale(double value) =>
      value.clamp(commandScaleMin, commandScaleMax).toDouble();

  /// Slider kademesi → yayınlanacak komut büyüklüğü (işaret UI’da verilir).
  static double scaleFromSpeedStep(int step) {
    final s = step.clamp(speedStepMin, speedStepMax);
    return (s + 1) / (speedStepMax + 1);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Saha adı / düğüm adı validasyonu
// ─────────────────────────────────────────────────────────────────────────────

abstract final class RosFieldNameRules {
  /// Yalnız harf, rakam, `_`, `-`
  static final RegExp pattern = RegExp(r'^[A-Za-z0-9_-]+$');

  static bool isValid(String value) {
    final v = value.trim();
    return v.isNotEmpty && pattern.hasMatch(v);
  }

  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Saha adı boş olamaz';
    }
    if (!pattern.hasMatch(value.trim())) {
      return 'Yalnız harf, rakam, _ ve - kullanılabilir';
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bilinen hata kodları / kullanıcı mesajları
// ─────────────────────────────────────────────────────────────────────────────

/// ROS `message` / hata metninden UI metnine eşleme.
abstract final class RosMappingErrors {
  static const lidarNotFound = 'LiDAR bulunamadı';
  static const stm32NotFound = 'STM32 bulunamadı';
  static const mapNotProduced = 'Harita üretilemedi';
  static const rosDisconnected = 'ROS bağlantısı koptu';
  static const mappingAlreadyRunning = 'Haritalama zaten çalışıyor';
  static const mapSaveFailed = 'Harita kaydedilemedi';
  static const localizationStartFailed = 'Lokalizasyon başlatılamadı';

  /// Tek seferlik sabit tablo — her çağrıda yeniden allocate edilmez.
  static const Map<String, String> _messageTable = {
    'lidar_not_found': lidarNotFound,
    'lidar not found': lidarNotFound,
    'lidar bulunamadı': lidarNotFound,
    'stm32_not_found': stm32NotFound,
    'stm32 not found': stm32NotFound,
    'stm32 bulunamadı': stm32NotFound,
    'map_not_produced': mapNotProduced,
    'map not produced': mapNotProduced,
    'harita üretilemedi': mapNotProduced,
    'ros_disconnected': rosDisconnected,
    'ros disconnected': rosDisconnected,
    'ros bağlantısı koptu': rosDisconnected,
    'mapping_already_running': mappingAlreadyRunning,
    'mapping already running': mappingAlreadyRunning,
    'haritalama zaten çalışıyor': mappingAlreadyRunning,
    'map_save_failed': mapSaveFailed,
    'map save failed': mapSaveFailed,
    'harita kaydedilemedi': mapSaveFailed,
    'localization_start_failed': localizationStartFailed,
    'localization start failed': localizationStartFailed,
    'lokalizasyon başlatılamadı': localizationStartFailed,
  };

  /// Wire / ham metin → Türkçe UI (bilinmeyenler olduğu gibi döner).
  static String toUserMessage(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Bilinmeyen hata';
    final key = raw.trim().toLowerCase();
    return _messageTable[key] ?? raw.trim();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wire mesaj modelleri (parse)
// ─────────────────────────────────────────────────────────────────────────────

/// Mapping/lokalizasyon servisleri için açık başarı onayı.
///
/// Rosbridge'in servis seviyesinde `result: true` döndürmesi yalnızca çağrının
/// işlendiğini gösterir. Uygulama işlemi ancak response içinde `success: true`
/// veya `accepted: true` varsa başarılı sayar; boş `{}` onay değildir.
abstract final class RosServiceResponse {
  static bool isConfirmedSuccess(Map<String, dynamic> response) =>
      response['success'] == true || response['accepted'] == true;

  static String failureMessage(
    Map<String, dynamic> response, {
    String fallback = 'ROS servisi işlemi onaylamadı',
  }) {
    final raw = response['message']?.toString().trim() ?? '';
    if (raw.isNotEmpty) return RosMappingErrors.toUserMessage(raw);
    if (response.isEmpty) return 'ROS servisi boş cevap döndürdü';
    return fallback;
  }
}

/// `/mapping/status` anlık görüntüsü.
class MappingStatusSnapshot {
  final MappingStatus status;
  final String message;

  const MappingStatusSnapshot({
    required this.status,
    this.message = '',
  });

  factory MappingStatusSnapshot.fromRosMessage(Map<String, dynamic> msg) {
    final code = (msg['status'] as num?)?.toInt() ??
        (msg['state'] as num?)?.toInt() ??
        (msg['code'] as num?)?.toInt();
    final rawMessage = msg['message']?.toString().trim() ?? '';
    return MappingStatusSnapshot(
      status: MappingStatusExt.fromCode(code),
      message:
          rawMessage.isEmpty ? '' : RosMappingErrors.toUserMessage(rawMessage),
    );
  }
}

/// `/map_preview/metadata` anlık görüntüsü.
class MapPreviewMetadata {
  final int width;
  final int height;
  final double resolution;
  final double originX;
  final double originY;
  final double originYaw;
  final MapPreviewSource source;

  const MapPreviewMetadata({
    required this.width,
    required this.height,
    required this.resolution,
    required this.originX,
    required this.originY,
    this.originYaw = 0,
    this.source = MapPreviewSource.unknown,
  });

  factory MapPreviewMetadata.fromRosMessage(Map<String, dynamic> msg) {
    final width = (msg['width'] as num?)?.toInt();
    final height = (msg['height'] as num?)?.toInt();
    final resolution = (msg['resolution'] as num?)?.toDouble();
    if (width == null ||
        width <= 0 ||
        height == null ||
        height <= 0 ||
        resolution == null ||
        !resolution.isFinite ||
        resolution <= 0) {
      throw const FormatException('MapPreviewMetadata alanları geçersiz');
    }

    var originX = (msg['origin_x'] as num?)?.toDouble();
    var originY = (msg['origin_y'] as num?)?.toDouble();
    var originYaw = (msg['origin_yaw'] as num?)?.toDouble() ?? 0;
    final rawOrigin = msg['origin'];
    if (rawOrigin is Map) {
      final origin = Map<String, dynamic>.from(rawOrigin);
      originX ??= (origin['x'] as num?)?.toDouble() ??
          (origin['position'] is Map
              ? ((origin['position'] as Map)['x'] as num?)?.toDouble()
              : null);
      originY ??= (origin['y'] as num?)?.toDouble() ??
          (origin['position'] is Map
              ? ((origin['position'] as Map)['y'] as num?)?.toDouble()
              : null);
      originYaw = (origin['yaw'] as num?)?.toDouble() ?? originYaw;
    }
    originX ??= 0;
    originY ??= 0;

    return MapPreviewMetadata(
      width: width,
      height: height,
      resolution: resolution,
      originX: originX,
      originY: originY,
      originYaw: originYaw,
      source: MapPreviewSourceExt.fromWire(msg['source']?.toString()),
    );
  }
}

/// `/map_preview/robot_pixel` anlık görüntüsü.
class MapPreviewRobotPixel {
  final double pixelX;
  final double pixelY;
  final double screenYaw;
  final bool insideMap;

  const MapPreviewRobotPixel({
    required this.pixelX,
    required this.pixelY,
    required this.screenYaw,
    required this.insideMap,
  });

  factory MapPreviewRobotPixel.fromRosMessage(Map<String, dynamic> msg) {
    final px = (msg['pixel_x'] as num?)?.toDouble() ??
        (msg['x'] as num?)?.toDouble();
    final py = (msg['pixel_y'] as num?)?.toDouble() ??
        (msg['y'] as num?)?.toDouble();
    if (px == null || py == null || !px.isFinite || !py.isFinite) {
      throw const FormatException('MapPixelPose alanları geçersiz');
    }
    return MapPreviewRobotPixel(
      pixelX: px,
      pixelY: py,
      screenYaw: (msg['screen_yaw'] as num?)?.toDouble() ??
          (msg['yaw'] as num?)?.toDouble() ??
          0,
      insideMap: msg['inside_map'] == true || msg['inside'] == true,
    );
  }
}

/// `sensor_msgs/CompressedImage.data` → PNG baytları.
abstract final class RosCompressedImageCodec {
  static Uint8List? decodeData(dynamic data) {
    if (data == null) return null;
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) return null;
      try {
        return base64Decode(trimmed);
      } catch (_) {
        return null;
      }
    }
    if (data is Uint8List) return data;
    if (data is List) {
      try {
        return Uint8List.fromList(
          data.map((e) => (e as num).toInt()).toList(growable: false),
        );
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
