import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/ros_bridge_client.dart';
import '../services/ros_mapping_contract.dart';

/// Saha haritalama / preview durumu (last-good + bağlantı şeridi).
///
/// Kopunca PNG / status silinmez; komut kapıları `isConnected` ile AND'lenir.
class GcsMappingModel extends ChangeNotifier {
  RosConnectionStatus connectionStatus = RosConnectionStatus.disconnected;
  String connectionMessage = '';

  MappingStatus? mappingStatus;
  String mappingMessage = '';
  bool mappingStatusStale = false;

  LocalizationStatus? localizationStatus;
  String localizationMessage = '';
  bool localizationStatusStale = true;

  DemoStatus? demoStatus;
  String demoMessage = '';
  String demoActiveTarget = '';
  DemoPointPose? demoPointA;
  DemoPointPose? demoPointB;
  String? demoPointsField;
  bool obstacleDetected = false;
  bool demoCommandInFlight = false;

  Uint8List? previewPng;
  MapPreviewMetadata? previewMetadata;
  MapPreviewRobotPixel? robotPixel;

  bool get hasPreviewPng => previewPng != null && previewPng!.isNotEmpty;

  /// Reconnect / yeniden subscribe sonrası taze frame bekleniyor.
  bool awaitingFreshPreview = false;

  /// Kullanıcının girdiği saha adı (`/mapping/start` field_name).
  String fieldName = '';

  /// `/mapping/start` çağrısı sürüyor (cevap veya STARTING status bekleniyor).
  bool startInFlight = false;

  /// Bitir/Kaydet (`/mapping/save`) uçuşta.
  bool finishInFlight = false;

  /// `/fields/list` sonucu (E.1 yenileme + E.2 ekranı).
  List<SavedFieldInfo> savedFields = const [];
  bool fieldsListLoading = false;
  String? fieldsListError;

  /// E.3 — aktif lokalizasyon sahası (null = kapalı).
  String? activeLocalizedField;
  String? pendingLocalizedField;
  bool localizationInFlight = false;
  bool localizationStartAccepted = false;

  /// Preview kaynağı doğrudan `/map_preview/robot_pixel.source` alanından gelir.
  String? get previewSourceLabel {
    final wire = robotPixel?.source.wireName;
    if (wire != null && wire.isNotEmpty && wire != 'unknown') return wire;
    if (activeLocalizedField != null) return MapPreviewSource.amcl.wireName;
    return wire;
  }

  bool _previewNotifyScheduled = false;
  Completer<void>? _mappingSavedWaiter;

  bool get isFieldNameValid => RosFieldNameRules.isValid(fieldName);

  /// Boşken hata gösterme (placeholder yeterli); yazmaya başlayınca doğrula.
  String? get fieldNameError {
    final trimmed = fieldName.trim();
    if (trimmed.isEmpty) return null;
    return RosFieldNameRules.validate(trimmed);
  }

  /// Canlı (stale olmayan) mapping status — kopuk last-good kapıları etkilemez.
  MappingStatus? get liveMappingStatus =>
      (mappingStatus != null && !mappingStatusStale) ? mappingStatus : null;

  LocalizationStatus? get liveLocalizationStatus =>
      (localizationStatus != null && !localizationStatusStale)
          ? localizationStatus
          : null;

  /// Dialog açılabilir mi? (bağlı + IDLE|ERROR; saha adı dialogda sorulur).
  bool get canPromptStartMapping {
    if (!isConnected ||
        startInFlight ||
        finishInFlight ||
        localizationInFlight ||
        localizationActive) {
      return false;
    }
    final status = liveMappingStatus;
    if (status == null) return true;
    if (status.uiLocked) return false;
    return status.canStartMapping;
  }

  /// Harita Oluştur / Yeniden Dene (bağlı + geçerli ad + IDLE|ERROR).
  bool get canStartMapping {
    if (!canPromptStartMapping || !isFieldNameValid) {
      return false;
    }
    return true;
  }

  /// MAPPING iken Bitir/Kaydet.
  bool get canFinishMapping =>
      isConnected &&
      !finishInFlight &&
      !startInFlight &&
      liveMappingStatus?.canFinishMapping == true;

  bool get startControlsLocked =>
      startInFlight ||
      finishInFlight ||
      (isConnected && (liveMappingStatus?.uiLocked ?? false));

  bool get isMappingError => liveMappingStatus == MappingStatus.error;

  bool get showFinishControls =>
      liveMappingStatus == MappingStatus.mapping || finishInFlight;

  String get startButtonLabel =>
      isMappingError ? 'Yeniden Dene' : 'Harita Oluştur';

  /// Ekranda gösterilecek mapping satırı (status + ROS message).
  String? get mappingStatusLine {
    final status = mappingStatus;
    if (status == null) return null;
    final stale = mappingStatusStale ? ' (eski)' : '';
    final msg = mappingMessage.trim();
    if (msg.isEmpty) return '${status.etiket}$stale';
    return '${status.etiket}$stale — $msg';
  }

  void setFieldName(String value) {
    if (fieldName == value) return;
    fieldName = value;
    notifyListeners();
  }

  void beginStartMapping() {
    if (startInFlight) return;
    startInFlight = true;
    notifyListeners();
  }

  void endStartMapping() {
    if (!startInFlight) return;
    startInFlight = false;
    notifyListeners();
  }

  void beginFinishMapping() {
    if (finishInFlight) return;
    finishInFlight = true;
    notifyListeners();
  }

  void endFinishMapping() {
    if (!finishInFlight) return;
    finishInFlight = false;
    notifyListeners();
  }

  void beginFieldsListLoad() {
    fieldsListLoading = true;
    fieldsListError = null;
    notifyListeners();
  }

  void applyFieldsList(List<SavedFieldInfo> fields) {
    savedFields = List.unmodifiable(fields);
    fieldsListLoading = false;
    fieldsListError = null;
    notifyListeners();
  }

  void applyFieldsListError(String message) {
    fieldsListLoading = false;
    fieldsListError = message;
    notifyListeners();
  }

  bool get localizationActive =>
      localizationStatus != null &&
      localizationStatus != LocalizationStatus.idle &&
      localizationStatus != LocalizationStatus.error;

  bool get localizationReady =>
      isConnected &&
      !localizationInFlight &&
      localizationStartAccepted &&
      localizationStatus == LocalizationStatus.localizing;

  bool get canSaveDemoPoint => localizationReady;

  /// Harita üzerinde kullanılabilecek robot pozu.
  ///
  /// Mapping sırasında yalnız SLAM, kayıtlı harita lokalizasyonunda ise yalnız
  /// LOCALIZING=3 durumundaki AMCL pozu kabul edilir. Böylece mapping bittikten
  /// sonra son `slam_toolbox` değeri ekranda donmuş bir robot gibi gösterilmez.
  MapPreviewRobotPixel? get visibleRobotPixel {
    final pixel = robotPixel;
    if (pixel == null || !pixel.insideMap) return null;
    if (!isConnected) return null;
    if (liveMappingStatus == MappingStatus.mapping) {
      return pixel.source == MapPreviewSource.slam_toolbox ? pixel : null;
    }
    if (localizationReady) {
      return pixel.source == MapPreviewSource.amcl ? pixel : null;
    }
    return null;
  }

  bool get demoPointsReady =>
      demoPointA != null &&
      demoPointB != null &&
      demoPointsField != null &&
      demoPointsField == activeLocalizedField;

  bool get demoRunning => demoStatus?.isRunning == true;

  bool get canStartDemo =>
      localizationReady &&
      demoPointsReady &&
      !demoRunning &&
      !demoCommandInFlight;

  bool get canContinueDemo =>
      isConnected &&
      demoStatus == DemoStatus.waitingLoad &&
      !obstacleDetected &&
      !demoCommandInFlight;

  bool get canCancelDemo => isConnected && demoRunning && !demoCommandInFlight;

  String get demoStatusLine {
    if (obstacleDetected) return 'Engel algılandı, araç bekliyor';
    final message = demoMessage.trim();
    if (message.isNotEmpty) return message;
    return demoStatus?.etiket ?? 'Demo durumu bekleniyor';
  }

  void markDemoPointSaved(String pointName, DemoPointSaveResult result) {
    if (!result.success || result.pose == null) return;
    final normalized = pointName.trim().toUpperCase();
    if (normalized == 'A') demoPointA = result.pose;
    if (normalized == 'B') demoPointB = result.pose;
    demoPointsField = activeLocalizedField;
    notifyListeners();
  }

  void applyDemoStatus(DemoStatusSnapshot? snap) {
    if (snap == null) return;
    demoStatus = snap.status;
    demoMessage = snap.message;
    demoActiveTarget = snap.activeTarget;
    if (snap.status != DemoStatus.idle) {
      demoPointA = snap.pointA;
      demoPointB = snap.pointB;
      demoPointsField ??= activeLocalizedField;
    }
    demoCommandInFlight = false;
    notifyListeners();
  }

  void applyObstacleDetected(bool? detected) {
    if (detected == null || obstacleDetected == detected) return;
    obstacleDetected = detected;
    notifyListeners();
  }

  void beginDemoCommand() {
    if (demoCommandInFlight) return;
    demoCommandInFlight = true;
    notifyListeners();
  }

  void endDemoCommand() {
    if (!demoCommandInFlight) return;
    demoCommandInFlight = false;
    notifyListeners();
  }

  bool get mappingActive =>
      liveMappingStatus == MappingStatus.starting ||
      liveMappingStatus == MappingStatus.mapping ||
      liveMappingStatus == MappingStatus.saving ||
      liveMappingStatus == MappingStatus.stopping;

  void beginLocalization([String? fieldName]) {
    if (localizationInFlight) return;
    localizationInFlight = true;
    robotPixel = null;
    if (fieldName != null && fieldName.trim().isNotEmpty) {
      localizationStartAccepted = false;
      localizationStatus = null;
      localizationMessage = '';
      activeLocalizedField = null;
      pendingLocalizedField = fieldName.trim();
      if (demoPointsField != pendingLocalizedField) {
        demoPointA = null;
        demoPointB = null;
        demoPointsField = null;
      }
    }
    notifyListeners();
  }

  void endLocalizationFlight() {
    if (!localizationInFlight) return;
    localizationInFlight = false;
    localizationStartAccepted = false;
    pendingLocalizedField = null;
    notifyListeners();
  }

  void acknowledgeLocalizationStart(String fieldName) {
    localizationStartAccepted = true;
    if (localizationStatus != LocalizationStatus.localizing) {
      pendingLocalizedField ??= fieldName.trim();
    } else {
      localizationInFlight = false;
    }
    awaitingFreshPreview = true;
    notifyListeners();
  }

  void acknowledgeLocalizationStop() {
    localizationInFlight = localizationStatus != LocalizationStatus.idle;
    notifyListeners();
  }

  void applyLocalizationStatus(LocalizationStatusSnapshot? snap) {
    if (snap == null) {
      localizationStatusStale = true;
      notifyListeners();
      return;
    }
    localizationStatus = snap.status;
    localizationMessage = snap.message;
    localizationStatusStale = false;
    final statusField = snap.fieldName.trim();
    switch (snap.status) {
      case LocalizationStatus.starting:
      case LocalizationStatus.waitingInitialPose:
      case LocalizationStatus.initializing:
        localizationInFlight = true;
        if (statusField.isNotEmpty) pendingLocalizedField = statusField;
        break;
      case LocalizationStatus.localizing:
        activeLocalizedField =
            statusField.isNotEmpty ? statusField : pendingLocalizedField;
        pendingLocalizedField = null;
        localizationInFlight = !localizationStartAccepted;
        awaitingFreshPreview = true;
        break;
      case LocalizationStatus.stopping:
        localizationInFlight = true;
        break;
      case LocalizationStatus.idle:
        localizationStartAccepted = false;
        activeLocalizedField = null;
        pendingLocalizedField = null;
        localizationInFlight = false;
        break;
      case LocalizationStatus.error:
        localizationStartAccepted = false;
        activeLocalizedField = null;
        pendingLocalizedField = null;
        localizationInFlight = false;
        break;
    }
    notifyListeners();
  }

  /// Aynı event-loop turunda gelen preview güncellemelerini tek rebuild'e sıkıştır.
  void _schedulePreviewNotify() {
    if (_previewNotifyScheduled) return;
    _previewNotifyScheduled = true;
    scheduleMicrotask(() {
      _previewNotifyScheduled = false;
      notifyListeners();
    });
  }

  bool get isConnected => connectionStatus == RosConnectionStatus.connected;

  bool get isConnecting =>
      connectionStatus == RosConnectionStatus.connecting ||
      connectionStatus == RosConnectionStatus.reconnecting;

  /// start/stop/save / manuel sürüş — kopukken kilitli.
  bool get commandsLocked => !isConnected;

  String get bannerTitle => switch (connectionStatus) {
        RosConnectionStatus.connected => 'Bağlı',
        RosConnectionStatus.connecting => 'Bağlanıyor',
        RosConnectionStatus.reconnecting => 'Yeniden bağlanıyor',
        RosConnectionStatus.error => 'Kopuk',
        RosConnectionStatus.disconnected => 'Kopuk',
      };

  String get bannerSubtitle {
    if (isConnected && awaitingFreshPreview) {
      return 'Bağlandı — harita güncelleniyor…';
    }
    // Bağlıyken mapping status/message öncelikli (B.4).
    final statusLine = mappingStatusLine;
    if (isConnected && statusLine != null) return statusLine;
    if (!isConnected && statusLine != null) {
      return statusLine;
    }
    if (connectionMessage.trim().isNotEmpty) {
      return connectionMessage.trim();
    }
    return switch (connectionStatus) {
      RosConnectionStatus.connected => 'ROS hazır',
      RosConnectionStatus.connecting => 'ROS bağlantısı kuruluyor',
      RosConnectionStatus.reconnecting => 'ROS yeniden bağlanıyor',
      RosConnectionStatus.error => 'ROS bağlantısı yok',
      RosConnectionStatus.disconnected => 'ROS bağlı değil',
    };
  }

  Color get bannerColor => switch (connectionStatus) {
        RosConnectionStatus.connected => awaitingFreshPreview
            ? const Color(0xFF2B6CB0)
            : const Color(0xFF2F6F4E),
        RosConnectionStatus.connecting ||
        RosConnectionStatus.reconnecting =>
          const Color(0xFFB7791F),
        RosConnectionStatus.error ||
        RosConnectionStatus.disconnected =>
          const Color(0xFF9B2C2C),
      };

  void applyConnectionState(RosConnectionState state) {
    final wasConnected = isConnected;
    connectionStatus = state.status;
    connectionMessage = state.message;
    if (!state.isConnected) {
      // Status'u ERROR'a çekme; last-good stale işaretle.
      mappingStatusStale = true;
      localizationStatusStale = true;
    }
    if (!state.isConnected && wasConnected) {
      final waiter = _mappingSavedWaiter;
      if (waiter != null && !waiter.isCompleted) {
        waiter.completeError(
          StateError('ROS bağlantısı kesildi; harita kaydedilmedi'),
        );
      }
    }
    notifyListeners();
  }

  void onSubscriptionsReady() {
    awaitingFreshPreview = true;
    mappingStatusStale = true;
    localizationStatusStale = true;
    notifyListeners();
  }

  void applyMappingStatus(MappingStatusSnapshot? snap) {
    if (snap == null) {
      mappingStatusStale = true;
      notifyListeners();
      return;
    }
    mappingStatus = snap.status;
    mappingMessage = snap.message;
    mappingStatusStale = false;
    // Status geldiyse start uçuş kilidini bırak (durum makinesi devralır).
    if (startInFlight) startInFlight = false;
    if (finishInFlight && snap.status == MappingStatus.error) {
      finishInFlight = false;
    }
    final waiter = _mappingSavedWaiter;
    if (waiter != null && !waiter.isCompleted) {
      if (snap.status == MappingStatus.saved) {
        waiter.complete();
      } else if (snap.status == MappingStatus.error) {
        waiter.completeError(
          StateError(
            snap.message.trim().isEmpty
                ? 'Harita kaydedilirken ROS hata durumuna geçti'
                : snap.message,
          ),
        );
      }
    }
    notifyListeners();
  }

  /// `/mapping/save` cevabından sonra gerçek `SAVED` durumunu bekler.
  Future<void> waitUntilMappingSaved({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!isConnected) {
      throw StateError('ROS bağlı değil; harita kaydedilmedi');
    }
    final status = liveMappingStatus;
    if (status == MappingStatus.saved) return;
    if (status == MappingStatus.error) {
      throw StateError(
        mappingMessage.trim().isEmpty
            ? 'Haritalama hata durumunda; harita kaydedilmedi'
            : mappingMessage,
      );
    }

    final waiter = Completer<void>();
    _mappingSavedWaiter = waiter;
    try {
      await waiter.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'Haritalama SAVED durumuna geçmedi',
          timeout,
        ),
      );
    } finally {
      if (identical(_mappingSavedWaiter, waiter)) {
        _mappingSavedWaiter = null;
      }
    }
  }

  void applyPreviewImage(Uint8List? bytes) {
    if (bytes == null) return;
    previewPng = bytes;
    awaitingFreshPreview = false;
    _schedulePreviewNotify();
  }

  void applyPreviewMetadata(MapPreviewMetadata? meta) {
    if (meta == null) return;
    previewMetadata = meta;
    _schedulePreviewNotify();
  }

  void applyRobotPixel(MapPreviewRobotPixel? pixel) {
    if (pixel == null) return;
    robotPixel = pixel;
    _schedulePreviewNotify();
  }

  /// OccupancyGrid veya preview taze geldiğinde (reconnect sonrası).
  void markFreshMapArrived() {
    if (!awaitingFreshPreview) return;
    awaitingFreshPreview = false;
    _schedulePreviewNotify();
  }

  /// Yalnız yeni adrese bilinçli bağlanış / dispose.
  void clearPreviewForNewSession() {
    previewPng = null;
    previewMetadata = null;
    robotPixel = null;
    mappingStatus = null;
    mappingMessage = '';
    mappingStatusStale = false;
    awaitingFreshPreview = false;
    startInFlight = false;
    finishInFlight = false;
    localizationStatus = null;
    localizationMessage = '';
    localizationStatusStale = true;
    activeLocalizedField = null;
    pendingLocalizedField = null;
    localizationInFlight = false;
    localizationStartAccepted = false;
    demoStatus = null;
    demoMessage = '';
    demoActiveTarget = '';
    demoPointA = null;
    demoPointB = null;
    demoPointsField = null;
    obstacleDetected = false;
    demoCommandInFlight = false;
    notifyListeners();
  }
}

/// Kayıtlı saha özeti (`/fields/list` wire → UI).
class SavedFieldInfo {
  final String name;
  final String fieldDirectory;
  final String mapYaml;
  final String previewPng;
  final String? createdAt;
  final bool mapReady;
  final bool initialPoseReady;
  final bool localizationReady;
  final String message;

  const SavedFieldInfo({
    required this.name,
    this.fieldDirectory = '',
    this.mapYaml = '',
    this.previewPng = '',
    this.createdAt,
    this.mapReady = false,
    this.initialPoseReady = false,
    this.localizationReady = false,
    this.message = '',
  });

  bool get isReady => localizationReady;
  bool get isFaulty => !mapReady || !initialPoseReady || !localizationReady;
  String get status => localizationReady ? 'hazir' : 'hazir_degil';
  String? get thumbnailHint => previewPng.isEmpty ? null : previewPng;

  static List<SavedFieldInfo> fromListFieldsResponse(
    Map<String, dynamic> response,
  ) {
    final raw =
        response['fields'] ?? response['field_names'] ?? response['data'];
    if (raw is! List) return const [];
    final out = <SavedFieldInfo>[];
    for (final item in raw) {
      if (item is String) {
        final name = item.trim();
        if (name.isNotEmpty) {
          out.add(SavedFieldInfo(name: name));
        }
        continue;
      }
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final name =
            (map['name'] ?? map['field_name'] ?? map['id'])?.toString().trim();
        if (name == null || name.isEmpty) continue;
        out.add(SavedFieldInfo(
          name: name,
          fieldDirectory: map['field_directory']?.toString() ?? '',
          mapYaml: map['map_yaml']?.toString() ?? '',
          previewPng: map['preview_png']?.toString() ?? '',
          createdAt: map['created_at']?.toString() ?? map['date']?.toString(),
          mapReady: map['map_ready'] == true,
          initialPoseReady: map['initial_pose_ready'] == true,
          localizationReady: map['localization_ready'] == true,
          message: map['message']?.toString() ?? '',
        ));
      }
    }
    return out;
  }
}
