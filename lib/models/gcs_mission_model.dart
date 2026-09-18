import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/agv_service.dart';
import '../services/ros_bridge_client.dart';
import '../services/ros_mapping_contract.dart';
import 'gcs_field_graph_model.dart';
import 'field_graph_models.dart';
import 'robot_status.dart';

class StationTurnArcStatus {
  final bool safe;
  final double? minimumClearanceM;
  final int? maximumCost;
  final String reason;

  const StationTurnArcStatus({
    required this.safe,
    this.minimumClearanceM,
    this.maximumCost,
    required this.reason,
  });

  factory StationTurnArcStatus.fromEvent(dynamic raw) {
    final map =
        raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    final clearance = map['minimum_clearance_m'];
    final maximumCost = map['maximum_cost'];
    return StationTurnArcStatus(
      safe: map['safe'] == true,
      minimumClearanceM:
          clearance is num && clearance.isFinite ? clearance.toDouble() : null,
      maximumCost: maximumCost is int ? maximumCost : null,
      reason: map['reason']?.toString() ?? '',
    );
  }
}

class StationTurnRuntimeStatus {
  final String station;
  final String? selectedDirection;
  final StationTurnArcStatus left;
  final StationTurnArcStatus right;
  final bool unavailable;

  const StationTurnRuntimeStatus({
    required this.station,
    required this.selectedDirection,
    required this.left,
    required this.right,
    required this.unavailable,
  });
}

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
  baslangicaDonuyor,

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
        GorevAsama.baslangicaDonuyor => 'Başlangıç Noktasına Dönüyor',
        GorevAsama.bosta => 'Göreve Hazır',
        GorevAsama.gorevAlindi => 'Görev Alındı / İşleniyor',
        GorevAsama.yuksuzHareket => 'Yüksüz Hareket',
        GorevAsama.yukAlma => 'Yük Alma',
        GorevAsama.yukluHareket => 'Yüklü Hareket',
        GorevAsama.kapiIzniBekleniyor =>
          'Fabrika Otomasyon Sistemi İzni Bekleniyor',
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
        GorevAsama.baslangicaDonuyor => 'WAIT noktasına dönüş sürüyor',
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
  GcsMissionModel({RosBridgeClient? client})
      : _client = client ?? AgvService.ros;
  final RosBridgeClient _client;
  RobotStatus? robotStatus;
  bool statusFresh = false;
  bool connected = false;
  String? pendingCommand;
  bool emergencyPending = false;
  String commandMessage = '';
  String? _preparedTaskId;
  String? _submittedTaskId;
  String? _startedTaskId;
  int _connectionEpoch = 0;
  StationTurnRuntimeStatus? stationTurnStatus;

  bool get commandPending => pendingCommand != null;
  bool get canResume =>
      connected &&
      statusFresh &&
      !commandPending &&
      robotStatus?.missionResumable == true;
  bool get canSubmit =>
      connected &&
      statusFresh &&
      !commandPending &&
      _submittedTaskId == null &&
      _preparedTaskId == null &&
      (robotStatus?.missionState == 0 || robotStatus?.missionState == 6);

  bool get readyToStart =>
      connected &&
      statusFresh &&
      !commandPending &&
      robotStatus?.missionState == 1 &&
      robotStatus?.taskSource == 'gui' &&
      robotStatus?.taskId == _preparedTaskId &&
      _preparedTaskId != _startedTaskId &&
      robotStatus?.localizationValid == true &&
      robotStatus?.activeFieldReady == true &&
      robotStatus?.estopActive == false &&
      robotStatus?.obstacleDetected == false;

  bool get canCancel {
    final state = robotStatus?.missionState;
    return connected &&
        statusFresh &&
        !commandPending &&
        state != null &&
        state >= 1 &&
        state <= 5;
  }

  bool get canResetError =>
      connected &&
      statusFresh &&
      !commandPending &&
      robotStatus?.missionState == 6 &&
      robotStatus?.estopActive == false;

  /// Explain command locks; local scenario editing does not use these gates.
  String? submitBlockReason(GcsFieldGraphModel graph) {
    if (!connected) {
      return 'ROS bağlantısı yok. Senaryo hazırlayabilir ve cihazda kaydedebilirsiniz; göndermek için bağlanın.';
    }
    if (!statusFresh) return 'Güncel robot durumu bekleniyor.';
    if (commandPending) return 'ROS yanıtı bekleniyor: $pendingCommand';
    if (!canSubmit) {
      return 'ROS üzerinde hazırlanmış veya çalışan görev var; önce onu başlatın ya da iptal edin.';
    }
    if (!graph.hasSelectedField) {
      return 'Önce Kayıtlı Haritalar’dan saha seçin.';
    }
    if (!graph.graphFresh) {
      return 'Seçili saha grafiği güncel değil; yeniden yükleyin.';
    }
    if (!graph.activeFresh) return 'ROS aktif saha bilgisi bekleniyor.';
    if (!graph.selectedFieldIsActive ||
        graph.activeField?.fieldName != graph.selectedFieldName) {
      return 'Seçili saha aktif değil; saha rotasını doğrulayıp aktifleştirin.';
    }
    if (graph.packageStatus?.packageHash != graph.activeField?.packageHash ||
        robotStatus?.activeFieldHash != graph.activeField?.packageHash) {
      return 'Robot ve saha paketi hash bilgileri eşleşmiyor; saha durumunu yenileyin.';
    }
    if (robotStatus?.activeFieldReady != true) {
      return 'Robot aktif saha paketini henüz hazır olarak bildirmedi.';
    }
    if (!graph.routeRuntimeReadinessKnown) {
      return 'Rota yük/yön kısıtları durumu bekleniyor.';
    }
    if (!graph.routeRuntimeReady) {
      return 'Rota yük/yön kısıtları çalışma sistemi hazır değil.';
    }
    return null;
  }

  String? get startBlockReason {
    if (readyToStart) return null;
    if (!connected) return 'ROS bağlantısı yok.';
    if (!statusFresh) return 'Güncel robot durumu bekleniyor.';
    if (commandPending) return 'ROS yanıtı bekleniyor: $pendingCommand';
    if (robotStatus?.estopActive == true) return 'Acil durdurma aktif.';
    if (robotStatus?.obstacleDetected == true) return 'Engel algılandı.';
    if (robotStatus?.localizationValid != true) {
      return 'Lokalizasyon geçerli değil.';
    }
    if (robotStatus?.activeFieldReady != true) {
      return 'Aktif saha robotta hazır değil.';
    }
    return 'Önce Görevi Hazırla / Submit ile gönderin ve ROS hazır görevini bekleyin.';
  }

  void applyConnection(bool value) {
    if (connected == value) return;
    connected = value;
    _connectionEpoch++;
    if (!value) {
      statusFresh = false;
      _preparedTaskId = null;
      _submittedTaskId = null;
      _startedTaskId = null;
      stationTurnStatus = null;
    }
    notifyListeners();
  }

  void applyStatus(Map<String, dynamic> raw) {
    if (raw.isEmpty) {
      statusFresh = false;
      notifyListeners();
      return;
    }
    robotStatus = RobotStatus.fromRosJson(raw);
    statusFresh = connected && robotStatus!.valid;
    final status = robotStatus!;
    if (status.taskId == _submittedTaskId && status.missionState != 1) {
      _submittedTaskId = null;
    }
    // ROS has no explicit queued flag in RobotStatus. Its queued detail and
    // TASK_RECEIVED/GUI tuple are the recovery evidence after reconnect.
    if (statusFresh &&
        status.missionState == 1 &&
        status.taskSource == 'gui' &&
        status.statusDetail == 'gorev kabul edildi' &&
        status.missionElapsedS == 0) {
      _preparedTaskId = status.taskId;
    }
    if (status.missionState != 1) _preparedTaskId = null;
    if (status.missionElapsedS.isFinite) {
      gorevSuresi =
          Duration(milliseconds: (status.missionElapsedS * 1000).round());
    }
    notifyListeners();
  }

  void applyEvent(String raw) {
    try {
      final event = jsonDecode(raw);
      if (event is! Map) return;
      if (event['event'] == 'mission_started') {
        _startedTaskId = event['task_id']?.toString();
        _preparedTaskId = null;
        stationTurnStatus = null;
      }
      if (event['event'] == 'mission_complete' && event['task_id'] == gorevId) {
        asama =
            event['success'] == true ? GorevAsama.tamamlandi : GorevAsama.hata;
      }
      final eventName = event['event']?.toString();
      if (eventName == 'station_turn_direction_selected' ||
          eventName == 'station_turn_direction_unavailable') {
        final selected = event['selected_direction']?.toString();
        stationTurnStatus = StationTurnRuntimeStatus(
          station: event['station']?.toString() ?? '',
          selectedDirection:
              selected == 'left' || selected == 'right' ? selected : null,
          left: StationTurnArcStatus.fromEvent(event['left']),
          right: StationTurnArcStatus.fromEvent(event['right']),
          unavailable: eventName == 'station_turn_direction_unavailable',
        );
      }
      notifyListeners();
    } catch (_) {/* Generic event log preserves non-JSON and future events. */}
  }

  Future<void> submit(
      {required GcsFieldGraphModel graph,
      required List<FieldNode> stops,
      required bool returnHome}) async {
    final blocked = submitBlockReason(graph);
    if (blocked != null) throw StateError(blocked);
    if (stops.length < 2 || stops.length.isOdd) {
      throw StateError('Alma/bırakma çiftleri seçin');
    }
    for (var i = 0; i < stops.length; i++) {
      final canonical = graph.nodeById(stops[i].nodeId);
      if (canonical == null ||
          canonical.name != stops[i].name ||
          canonical.role !=
              (i.isEven
                  ? FieldNodeRole.pickupDock
                  : FieldNodeRole.dropoffDock)) {
        throw StateError('Durak aktif saha grafiğinde uygun dock değil');
      }
    }
    final taskId = 'gui_${DateTime.now().microsecondsSinceEpoch}';
    await _command(
        'submit',
        () => _client.submitMission(
            taskId: taskId,
            routeNodes: stops.map((n) => n.name).toList(),
            returnHome: returnHome), onAccepted: () {
      _submittedTaskId = taskId;
      _preparedTaskId = taskId;
      commandMessage =
          'Görev hazır; ROS durumunu doğruladıktan sonra Başlat düğmesine basın';
    });
  }

  Future<void> start() async {
    if (!readyToStart) {
      throw StateError(
          'ROS üzerinde başlatılabilir hazır GUI görevi yok veya durum güncel değil');
    }
    final task = _preparedTaskId;
    await _command('start', _client.startMission, onAccepted: () {
      _startedTaskId = task;
      _preparedTaskId = null;
    });
  }

  Future<void> resume() async {
    if (!canResume) {
      throw StateError('Görev şu anda devam ettirilemez');
    }
    try {
      await _command('resume', _client.resumeMission);
    } on TimeoutException {
      commandMessage = 'Göreve devam servisine ulaşılamadı.';
      notifyListeners();
      throw StateError(commandMessage);
    }
  }

  Future<void> cancel() => _command('cancel', _client.cancelMission);
  Future<void> resetSafety() =>
      _command('reset_safety', _client.resetMissionSafety);
  Future<void> emergencyStop() =>
      _command('emergency_stop', _client.emergencyStop, trigger: true);

  Future<void> _command(
      String name, Future<Map<String, dynamic>> Function() call,
      {bool trigger = false, VoidCallback? onAccepted}) async {
    if (!connected) throw StateError('ROS bağlantısı yok');
    if (trigger ? emergencyPending : commandPending) {
      throw StateError('İşlem zaten sürüyor');
    }
    if (!trigger && !statusFresh) throw StateError('Robot durumu güncel değil');
    final epoch = _connectionEpoch;
    if (trigger) {
      emergencyPending = true;
    } else {
      pendingCommand = name;
    }
    notifyListeners();
    try {
      final response = await call();
      if (epoch != _connectionEpoch || !connected) {
        throw StateError('Bağlantı değişti; ROS durumu yeniden doğrulanmalı');
      }
      if (response[trigger ? 'success' : 'accepted'] != true) {
        throw StateError(RosServiceResponse.failureMessage(response,
            fallback: '$name reddedildi'));
      }
      commandMessage = response['message']?.toString() ?? '';
      onAccepted?.call();
    } catch (error) {
      commandMessage = '$name başarısız: $error';
      rethrow;
    } finally {
      if (trigger) {
        emergencyPending = false;
      } else {
        pendingCommand = null;
      }
      notifyListeners();
    }
  }

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
