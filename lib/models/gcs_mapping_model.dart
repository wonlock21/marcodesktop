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

  /// Bitir/Kaydet (stop+save) uçuşta.
  bool finishInFlight = false;

  /// `/fields/list` sonucu (E.1 yenileme + E.2 ekranı).
  List<SavedFieldInfo> savedFields = const [];
  bool fieldsListLoading = false;
  String? fieldsListError;

  /// E.3 — aktif lokalizasyon sahası (null = kapalı).
  String? activeLocalizedField;
  bool localizationInFlight = false;

  /// Preview etiketi: ROS metadata yoksa lokalizasyon açıkken `amcl`.
  String? get previewSourceLabel {
    final wire = previewMetadata?.source.wireName;
    if (wire != null && wire.isNotEmpty && wire != 'unknown') return wire;
    if (activeLocalizedField != null) return MapPreviewSource.amcl.wireName;
    return wire;
  }

  bool _previewNotifyScheduled = false;
  Completer<void>? _mappingIdleWaiter;

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

  /// Dialog açılabilir mi? (bağlı + IDLE|ERROR; saha adı dialogda sorulur).
  bool get canPromptStartMapping {
    if (!isConnected || startInFlight || finishInFlight) {
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

  void beginLocalization() {
    if (localizationInFlight) return;
    localizationInFlight = true;
    notifyListeners();
  }

  void endLocalizationFlight() {
    if (!localizationInFlight) return;
    localizationInFlight = false;
    notifyListeners();
  }

  void applyLocalizationStarted(String fieldName) {
    activeLocalizedField = fieldName.trim();
    localizationInFlight = false;
    awaitingFreshPreview = true;
    notifyListeners();
  }

  void applyLocalizationStopped() {
    activeLocalizedField = null;
    localizationInFlight = false;
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
    if (!state.isConnected && wasConnected) {
      // Status'u ERROR'a çekme; last-good stale işaretle.
      mappingStatusStale = true;
      final waiter = _mappingIdleWaiter;
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
    notifyListeners();
  }

  void applyMappingStatus(MappingStatusSnapshot? snap) {
    if (snap == null) return;
    mappingStatus = snap.status;
    mappingMessage = snap.message;
    mappingStatusStale = false;
    // Status geldiyse start uçuş kilidini bırak (durum makinesi devralır).
    if (startInFlight) startInFlight = false;
    // IDLE yalnızca save aşamasını başlatır; finish kilidi save ve saha
    // yenilemesi tamamlanana kadar controller tarafından açık tutulur.
    if (finishInFlight && snap.status == MappingStatus.error) {
      finishInFlight = false;
    }
    final waiter = _mappingIdleWaiter;
    if (waiter != null && !waiter.isCompleted) {
      if (snap.status == MappingStatus.idle) {
        waiter.complete();
      } else if (snap.status == MappingStatus.error) {
        waiter.completeError(
          StateError(
            snap.message.trim().isEmpty
                ? 'Haritalama durdurulurken ROS hata durumuna geçti'
                : snap.message,
          ),
        );
      }
    }
    notifyListeners();
  }

  /// `/mapping/stop` kabul edildikten sonra gerçek IDLE durumunu bekler.
  /// Save, STOPPING veya MAPPING devam ederken çağrılmaz.
  Future<void> waitUntilMappingIdle({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (!isConnected) {
      throw StateError('ROS bağlı değil; harita kaydedilmedi');
    }
    final status = liveMappingStatus;
    if (status == MappingStatus.idle) return;
    if (status == MappingStatus.error) {
      throw StateError(
        mappingMessage.trim().isEmpty
            ? 'Haritalama hata durumunda; harita kaydedilmedi'
            : mappingMessage,
      );
    }

    final waiter = Completer<void>();
    _mappingIdleWaiter = waiter;
    try {
      await waiter.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'Haritalama IDLE durumuna geçmedi; harita kaydedilmedi',
          timeout,
        ),
      );
    } finally {
      if (identical(_mappingIdleWaiter, waiter)) {
        _mappingIdleWaiter = null;
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
    notifyListeners();
  }
}

/// Kayıtlı saha özeti (`/fields/list` wire → UI).
class SavedFieldInfo {
  final String name;
  final String status;
  final String? createdAt;
  final String? thumbnailHint;

  const SavedFieldInfo({
    required this.name,
    this.status = 'hazir',
    this.createdAt,
    this.thumbnailHint,
  });

  bool get isReady => status == 'hazir' || status == 'ready';
  bool get isFaulty =>
      status == 'hatali' || status == 'error' || status == 'faulty';

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
          status: (map['status'] ?? map['state'] ?? 'hazir').toString(),
          createdAt: map['created_at']?.toString() ?? map['date']?.toString(),
          thumbnailHint: map['thumbnail']?.toString(),
        ));
      }
    }
    return out;
  }
}
