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

  /// 5 — harita dosyaları kaydediliyor
  saving,

  /// 6 — harita kaydedildi
  saved,
}

/// `/localization/status` sayısal kodları.
enum LocalizationStatus {
  idle,
  starting,
  waitingInitialPose,
  localizing,
  stopping,
  error,
  initializing,
}

extension LocalizationStatusExt on LocalizationStatus {
  int get code => index;

  String get etiket => switch (this) {
        LocalizationStatus.idle => 'Hazır',
        LocalizationStatus.starting => 'Başlatılıyor',
        LocalizationStatus.waitingInitialPose => 'İlk poz bekleniyor',
        LocalizationStatus.localizing => 'Lokalizasyon çalışıyor',
        LocalizationStatus.stopping => 'Durduruluyor',
        LocalizationStatus.error => 'Hata',
        LocalizationStatus.initializing => 'Başlangıç pozu uygulanıyor',
      };

  static LocalizationStatus fromCode(int? code) {
    if (code == null || code < 0 || code >= LocalizationStatus.values.length) {
      return LocalizationStatus.error;
    }
    return LocalizationStatus.values[code];
  }
}

extension MappingStatusExt on MappingStatus {
  int get code => index;

  String get etiket => switch (this) {
        MappingStatus.idle => 'Hazır',
        MappingStatus.starting => 'Başlatılıyor',
        MappingStatus.mapping => 'Haritalama çalışıyor',
        MappingStatus.stopping => 'Durduruluyor',
        MappingStatus.error => 'Hata',
        MappingStatus.saving => 'Kaydediliyor',
        MappingStatus.saved => 'Kaydedildi',
      };

  /// Manuel sürüş yalnız mapping sırasında.
  bool get manualDriveAllowed => this == MappingStatus.mapping;

  /// Kullanıcı “Harita Oluştur” basabilir mi?
  bool get canStartMapping =>
      this == MappingStatus.idle ||
      this == MappingStatus.error ||
      this == MappingStatus.saved;

  /// “Bitir / Kaydet” aktif mi?
  bool get canFinishMapping => this == MappingStatus.mapping;

  /// UI kilitli (yükleniyor) mi?
  bool get uiLocked =>
      this == MappingStatus.starting ||
      this == MappingStatus.stopping ||
      this == MappingStatus.saving;

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
  static const localizationStatus = '/localization/status';

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

  /// `mapping_manager.py` tarafından `std_srvs.srv.Trigger` ile sunulur.
  static const stopMappingSrv = 'std_srvs/srv/Trigger';

  static const mappingStatusMsg = 'marco_msgs/msg/MappingStatus';
  static const compressedImageMsg = 'sensor_msgs/msg/CompressedImage';
  static const mapPreviewMetadataMsg = 'nav_msgs/msg/MapMetaData';

  /// ROS wire adı (güncel): `MapPixelPose`.
  static const mapPreviewRobotPixelMsg = 'marco_msgs/msg/MapPixelPose';
  static const twistMsg = 'geometry_msgs/msg/Twist';

  static const saveMappingSrv = 'marco_msgs/srv/SaveMapping';
  static const listFieldsSrv = 'marco_msgs/srv/ListFields';
  static const startLocalizationSrv = 'marco_msgs/srv/StartLocalization';
  static const stopLocalizationSrv = 'std_srvs/srv/Trigger';
  static const localizationStatusMsg = 'marco_msgs/msg/LocalizationStatus';

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
    return v.isNotEmpty && v.length <= 64 && pattern.hasMatch(v);
  }

  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Saha adı boş olamaz';
    }
    if (value.trim().length > 64) {
      return 'Saha adı en fazla 64 karakter olabilir';
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

/// Mapping/lokalizasyon servisleri için tipe özgü başarı onayı.
///
/// Rosbridge'in servis seviyesinde `result: true` döndürmesi yalnızca çağrının
/// işlendiğini gösterir. Her servis yalnız kendi `.srv` response alanıyla
/// doğrulanır; boş `{}` veya başka servise ait başarı alanı onay değildir.
abstract final class RosServiceResponse {
  static bool mappingStartAccepted(Map<String, dynamic> response) =>
      response['accepted'] == true;

  static bool mappingStopSucceeded(Map<String, dynamic> response) =>
      response['success'] == true;

  static bool mappingSaveSucceeded(Map<String, dynamic> response) =>
      response['success'] == true;

  static bool fieldsListSucceeded(Map<String, dynamic> response) =>
      response['success'] == true;

  static bool localizationStartAccepted(Map<String, dynamic> response) =>
      response['accepted'] == true;

  static bool localizationStopSucceeded(Map<String, dynamic> response) =>
      response['success'] == true;

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

typedef RosServiceCall = Future<Map<String, dynamic>> Function();

/// Aktif SLAM çalışırken `/mapping/save` çağrısını doğrular.
abstract final class RosMappingWorkflow {
  static Future<Map<String, dynamic>> saveActiveMapping({
    required RosServiceCall save,
  }) async {
    final saveResponse = await save();
    if (!RosServiceResponse.mappingSaveSucceeded(saveResponse)) {
      throw StateError(
        'Harita kaydı başarısız: '
        '${RosServiceResponse.failureMessage(saveResponse)}',
      );
    }
    return saveResponse;
  }
}

/// `/localization/status` anlık görüntüsü.
class LocalizationStatusSnapshot {
  final LocalizationStatus status;
  final String fieldName;
  final String message;
  final String mapYaml;

  const LocalizationStatusSnapshot({
    required this.status,
    this.fieldName = '',
    this.message = '',
    this.mapYaml = '',
  });

  factory LocalizationStatusSnapshot.fromRosMessage(
    Map<String, dynamic> msg,
  ) {
    final code = (msg['state'] as num?)?.toInt();
    return LocalizationStatusSnapshot(
      status: LocalizationStatusExt.fromCode(code),
      fieldName: msg['field_name']?.toString().trim() ?? '',
      message: msg['message']?.toString().trim() ?? '',
      mapYaml: msg['map_yaml']?.toString().trim() ?? '',
    );
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

  const MapPreviewMetadata({
    required this.width,
    required this.height,
    required this.resolution,
    required this.originX,
    required this.originY,
    this.originYaw = 0,
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
    );
  }
}

/// `/map_preview/robot_pixel` anlık görüntüsü.
class MapPreviewRobotPixel {
  final double pixelX;
  final double pixelY;
  final double screenYaw;
  final int mapWidth;
  final int mapHeight;
  final bool insideMap;
  final MapPreviewSource source;

  const MapPreviewRobotPixel({
    required this.pixelX,
    required this.pixelY,
    required this.screenYaw,
    required this.mapWidth,
    required this.mapHeight,
    required this.insideMap,
    required this.source,
  });

  factory MapPreviewRobotPixel.fromRosMessage(Map<String, dynamic> msg) {
    final px =
        (msg['pixel_x'] as num?)?.toDouble() ?? (msg['x'] as num?)?.toDouble();
    final py =
        (msg['pixel_y'] as num?)?.toDouble() ?? (msg['y'] as num?)?.toDouble();
    final mapWidth = (msg['map_width'] as num?)?.toInt();
    final mapHeight = (msg['map_height'] as num?)?.toInt();
    if (px == null ||
        py == null ||
        !px.isFinite ||
        !py.isFinite ||
        mapWidth == null ||
        mapWidth <= 0 ||
        mapHeight == null ||
        mapHeight <= 0) {
      throw const FormatException('MapPixelPose alanları geçersiz');
    }
    return MapPreviewRobotPixel(
      pixelX: px,
      pixelY: py,
      screenYaw: (msg['screen_yaw'] as num?)?.toDouble() ??
          (msg['yaw'] as num?)?.toDouble() ??
          0,
      mapWidth: mapWidth,
      mapHeight: mapHeight,
      insideMap: msg['inside_map'] == true || msg['inside'] == true,
      source: MapPreviewSourceExt.fromWire(msg['source']?.toString()),
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
