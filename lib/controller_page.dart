import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data_model.dart';
import 'data_page.dart';
import 'models/agv_sensor_model.dart';
import 'models/gcs_alarm_model.dart';
import 'models/gcs_connection_model.dart';
import 'models/gcs_event_log_model.dart';
import 'models/gcs_map_model.dart';
import 'models/gcs_mapping_model.dart';
import 'models/gcs_mission_model.dart';
import 'models/gcs_node_model.dart';
import 'parameter_model.dart';
import 'scenerio_page.dart';
import 'services/agv_service.dart';
import 'services/occupancy_grid_image.dart';
import 'services/ros_bridge_client.dart';
import 'services/ros_gcs_contract.dart';
import 'services/ros_mapping_contract.dart';
import 'widgets/control_buttons.dart';
import 'widgets/gcs_map_view.dart';
import 'widgets/map_preview_stage.dart';
import 'widgets/mapping_connection_banner.dart';
import 'widgets/mapping_field_bar.dart';
import 'widgets/mjpeg_camera_view.dart';

class ControllerPage extends StatefulWidget {
  const ControllerPage({super.key});

  @override
  State<ControllerPage> createState() {
    return _ControllerPageState();
  }
}

class _ControllerPageState extends State<ControllerPage>
    with WidgetsBindingObserver {
  int speed = 0;
  String _site = '';
  bool isConnected = false;
  String nextQR = "null";
  String _scenarioData = "";
  final FocusNode _focusNode = FocusNode();
  late ParameterModel parameterModel;
  late AgvSensorModel _agvModel;
  OccupancyGridMetadata? _mapMetadata;
  ui.Image? _occupancyImage;
  int _occupancyImageGeneration = 0;

  /// Nokta/rota dönüşümü cache — robot pose her tick'te yeniden hesaplanmaz.
  List<MapPoint> _cachedMapPoints = const [];
  List<MapRoute> _cachedMapRoutes = const [];
  int? _cachedMapStaticKey;

  // Orta alan sekme indeksi: 0=Harita 1=Kamera 2=LiDAR 3=3D
  int _selectedWorkTab = 0;

  // Bağlantı paneli durumu ve IP giriş kontrolcüsü
  bool isConnectionPanelOpen = false;
  final TextEditingController _ipController = TextEditingController();
  String _lastRosStateLog = '';
  bool? _buzzerEnabled;
  bool _buzzerCommandInFlight = false;
  bool? _pendingBuzzerTarget;
  bool _buzzerServiceAccepted = false;
  bool? _pendingBuzzerObservedState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _agvModel = Provider.of<AgvSensorModel>(context, listen: false);
    parameterModel = Provider.of<ParameterModel>(context, listen: false);
    Provider.of<DataModel>(context, listen: false).loadDataPoints();
    parameterModel.loadParameters();
    _ipController.text = 'ws://localhost:9090';
    unawaited(_loadLastRosAddress());
    AgvService.ros.onRobotStatus = _applyRobotStatus;
    AgvService.ros.onMissionEvent = _onMissionEvent;
    AgvService.ros.onMapMetadata = _onMapMetadata;
    AgvService.ros.onMapFrame = _onMapFrame;
    AgvService.ros.onMappingStatus = _onMappingStatus;
    AgvService.ros.onLocalizationStatus = _onLocalizationStatus;
    AgvService.ros.onDemoStatus = _onDemoStatus;
    AgvService.ros.onObstacleDetected = _onObstacleDetected;
    AgvService.ros.onBuzzerState = _onBuzzerState;
    AgvService.ros.onMapPreviewImage = _onMapPreviewImage;
    AgvService.ros.onMapPreviewMetadata = _onMapPreviewMetadata;
    AgvService.ros.onMapPreviewRobotPixel = _onMapPreviewRobotPixel;
    AgvService.ros.onMappingSubscriptionsReady = _onMappingSubscriptionsReady;
    AgvService.ros.state.addListener(_onRosConnectionState);
    // Build bitmeden notifyListeners yasak — ilk durumu sonraki frame'de bas.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mappingModel.applyConnectionState(AgvService.ros.state.value);
    });
  }

  double _number(dynamic value, [double fallback = 0]) =>
      value is num ? value.toDouble() : fallback;

  void _applyRobotStatus(Map<String, dynamic> status) {
    if (!mounted) return;
    final poseStamped = status['pose'];
    final poseWithCovariance = poseStamped is Map ? poseStamped['pose'] : null;
    final pose = poseWithCovariance is Map ? poseWithCovariance['pose'] : null;
    final position = pose is Map ? pose['position'] : null;
    final orientation = pose is Map ? pose['orientation'] : null;
    final x = position is Map ? _number(position['x']) : 0.0;
    final y = position is Map ? _number(position['y']) : 0.0;
    final qx = orientation is Map ? _number(orientation['x']) : 0.0;
    final qy = orientation is Map ? _number(orientation['y']) : 0.0;
    final qz = orientation is Map ? _number(orientation['z']) : 0.0;
    final qw = orientation is Map ? _number(orientation['w'], 1) : 1.0;
    final yaw = math.atan2(
      2 * (qw * qz + qx * qy),
      1 - 2 * (qy * qy + qz * qz),
    );
    final missionState = (status['mission_state'] as num?)?.toInt() ?? 0;
    final hardwareManualMode = status['manual_mode_enabled'] == true;
    final estop = status['estop_active'] == true;
    final obstacle = status['obstacle_detected'] == true;
    final plcConnected = status['plc_connected'] == true;
    final qr = status['last_qr_data']?.toString() ?? '';

    _agvModel
      ..updateRobotDurum(switch (missionState) {
        1 => kRobotDurumGorevIsleniyor,
        2 => kRobotDurumYuksuzHareket,
        3 => kRobotDurumYukluHareket,
        4 => kRobotDurumKapiBekle,
        5 => kRobotDurumBaslangicaDon,
        6 => kRobotDurumHata,
        7 => kRobotDurumAcilStop,
        _ => kRobotDurumIdle,
      })
      ..updateRobotStatus(
        x: x,
        y: y,
        yaw: yaw,
        localizationValid: status['localization_valid'] == true,
        positionCovariance:
            _number(status['position_covariance'], double.infinity),
        currentRouteEdge: status['current_route_edge']?.toString() ?? '',
        nextNode: status['next_node']?.toString() ?? '',
        crossTrackError: _number(status['cross_track_error'], double.nan),
        obstacleDetected: obstacle,
        lastQrData: qr,
        plcConnected: plcConnected,
        estopActive: estop,
      )
      ..updatePowerTelemetry(
        linearSpeed: _number(status['linear_speed'], double.nan),
        voltage: _number(status['battery_voltage'], double.nan),
        current: _number(status['battery_current'], double.nan),
        temperature: _number(status['battery_temperature'], double.nan),
      );

    final mission = Provider.of<GcsMissionModel>(context, listen: false);
    final rawRoute = status['route_nodes'];
    mission.topluGuncelle(
      gorevId: status['task_id']?.toString() ?? '',
      gorevKaynagi: status['task_source']?.toString() ?? '',
      almaNoktasi: status['pickup_node']?.toString() ?? '',
      birakNoktasi: status['dropoff_node']?.toString() ?? '',
      rotaDugumleri: rawRoute is List
          ? rawRoute.map((node) => node.toString()).toList()
          : const <String>[],
      aktifDurakIndeksi: (status['current_stop_index'] as num?)?.toInt() ?? 0,
      baslangicaDon: status['return_home'] != false,
      asama: switch (missionState) {
        1 => GorevAsama.gorevAlindi,
        2 => GorevAsama.yuksuzHareket,
        3 => GorevAsama.yukluHareket,
        4 => GorevAsama.kapiIzniBekleniyor,
        5 => GorevAsama.tamamlandi,
        6 => GorevAsama.hata,
        7 => GorevAsama.acilStop,
        _ => GorevAsama.bosta,
      },
      kapiIzni: status['gate_permission_granted'] == true,
    );
    _connModel.topluGuncelle(
      sistem: ConnDurum.bagli,
      robot: ConnDurum.bagli,
      plc: plcConnected ? ConnDurum.bagli : ConnDurum.cevrimdisi,
      manuelMod: hardwareManualMode,
      uzaktanKontrol: hardwareManualMode,
    );
    final alarms = Provider.of<GcsAlarmModel>(context, listen: false);
    alarms.topluGuncelle(
      aktifOlanlar: [
        if (estop) AlarmTur.acilStop,
        if (obstacle) AlarmTur.guvenlikSensorUyari,
      ],
      pasifOlanlar: [
        if (!estop) AlarmTur.acilStop,
        if (!obstacle) AlarmTur.guvenlikSensorUyari,
      ],
    );
    setState(() {
      isConnected = true;
    });
  }

  void _onMissionEvent(String event) {
    if (!mounted) return;
    Provider.of<GcsEventLogModel>(context, listen: false).ekle(event);
  }

  /// I.1 — Türkçe hata: olay günlüğü + SnackBar.
  void _showUserError(String message) {
    final text = RosMappingErrors.toUserMessage(message);
    _onMissionEvent(text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: const Color(0xFFB71C1C),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _onMapMetadata(OccupancyGridMetadata? metadata) {
    if (!mounted) return;
    // null: yalnız bilinçli yeni oturum temizliği (geçici kopmada client null göndermez).
    if (metadata == null) {
      _disposeOccupancyImage();
      setState(() {
        _mapMetadata = null;
        _occupancyImage = null;
        _cachedMapStaticKey = null;
        _cachedMapPoints = const [];
        _cachedMapRoutes = const [];
      });
      return;
    }
    final previous = _mapMetadata;
    final geometryChanged =
        previous == null || !previous.sameGeometry(metadata);
    if (geometryChanged) {
      _occupancyImageGeneration++;
      _disposeOccupancyImage();
    }
    setState(() {
      _mapMetadata = metadata;
      if (geometryChanged) _occupancyImage = null;
    });
    _mappingModel.markFreshMapArrived();
    if (geometryChanged) {
      _onMissionEvent(
        'Harita metadata: ${metadata.width}×${metadata.height}, '
        '${metadata.resolution} m/hücre, '
        'origin=(${metadata.originX}, ${metadata.originY}, '
        '${metadata.originYaw})',
      );
    }
  }

  void _onMapFrame(OccupancyGridFrame? frame) {
    if (!mounted) return;
    if (frame == null) {
      // Geçici kopmada last-good occupancy görüntüsünü tut.
      return;
    }
    final generation = ++_occupancyImageGeneration;
    final meta = frame.metadata;
    final geometryChanged =
        _mapMetadata == null || !_mapMetadata!.sameGeometry(meta);
    unawaited(() async {
      try {
        final image = await occupancyFrameToImage(frame);
        if (!mounted || generation != _occupancyImageGeneration) {
          image.dispose();
          return;
        }
        _disposeOccupancyImage();
        setState(() {
          _mapMetadata = meta;
          _occupancyImage = image;
        });
        _mappingModel.markFreshMapArrived();
        if (geometryChanged) {
          _onMissionEvent(
            'OccupancyGrid görüntü: ${meta.width}×${meta.height}',
          );
        }
      } catch (error) {
        debugPrint('OccupancyGrid görüntü hatası: $error');
      }
    }());
  }

  void _onMappingStatus(MappingStatusSnapshot? status) {
    if (!mounted) return;
    final previous = _mappingModel.mappingStatus;
    final previousMsg = _mappingModel.mappingMessage;
    _mappingModel.applyMappingStatus(status);
    if (status == null) return;
    if (previous != status.status || previousMsg != status.message) {
      final line = _mappingModel.mappingStatusLine;
      if (line != null) _onMissionEvent('Mapping: $line');
      // I.1: ERROR → SnackBar; Yeniden Dene butonu startButtonLabel ile açık.
      if (status.status == MappingStatus.error) {
        final msg = status.message.trim().isEmpty
            ? 'Haritalama hatası — Yeniden Dene ile tekrar deneyin'
            : status.message;
        _showUserError(msg);
      }
    }
  }

  void _onLocalizationStatus(LocalizationStatusSnapshot? status) {
    if (!mounted) return;
    final previous = _mappingModel.localizationStatus;
    _mappingModel.applyLocalizationStatus(status);
    if (status == null || previous == status.status) return;
    final message = status.message.trim();
    _onMissionEvent(
      'Lokalizasyon: ${status.status.etiket}'
      '${message.isEmpty ? '' : ' — ${RosMappingErrors.toUserMessage(message)}'}',
    );
    if (status.status == LocalizationStatus.error) {
      _showUserError(
        message.isEmpty ? 'Lokalizasyon hatası' : message,
      );
    }
  }

  void _onDemoStatus(DemoStatusSnapshot? status) {
    if (!mounted) return;
    final previous = _mappingModel.demoStatus;
    final previousMessage = _mappingModel.demoMessage;
    _mappingModel.applyDemoStatus(status);
    if (status == null ||
        (previous == status.status && previousMessage == status.message)) {
      return;
    }
    _onMissionEvent(
        'Demo: ${status.message.isNotEmpty ? status.message : status.status.etiket}');
    if (status.status == DemoStatus.error) {
      _showUserError(
        status.message.isEmpty ? 'Demo hata durumuna geçti' : status.message,
      );
    }
  }

  void _onObstacleDetected(bool? detected) {
    if (!mounted || detected == null) return;
    final previous = _mappingModel.obstacleDetected;
    _mappingModel.applyObstacleDetected(detected);
    if (detected && !previous) {
      _onMissionEvent('Engel algılandı, araç bekliyor');
    } else if (!detected && previous) {
      _onMissionEvent('Engel kalktı; ROS hareketi otomatik sürdürecek');
    }
  }

  void _onBuzzerState(bool? enabled) {
    if (!mounted) return;
    if (enabled != null &&
        _pendingBuzzerTarget == enabled &&
        !_buzzerServiceAccepted) {
      _pendingBuzzerObservedState = enabled;
      return;
    }
    final previous = _buzzerEnabled;
    setState(() {
      _buzzerEnabled = enabled;
      if (enabled == null) {
        _buzzerCommandInFlight = false;
        _pendingBuzzerTarget = null;
        _buzzerServiceAccepted = false;
        _pendingBuzzerObservedState = null;
      } else if (_pendingBuzzerTarget == enabled && _buzzerServiceAccepted) {
        _buzzerCommandInFlight = false;
        _pendingBuzzerTarget = null;
        _buzzerServiceAccepted = false;
        _pendingBuzzerObservedState = null;
      }
    });
    if (enabled != null && previous != enabled) {
      _onMissionEvent('Buzzer: ${enabled ? 'Açık' : 'Kapalı'}');
    }
  }

  Future<void> _toggleBuzzer() async {
    if (_buzzerCommandInFlight) return;
    if (!AgvService.ros.state.value.isConnected) {
      _showUserError('Buzzer komutu gönderilemedi: ROS bağlı değil');
      return;
    }
    final current = _buzzerEnabled;
    if (current == null) {
      _showUserError('Buzzer durumu bekleniyor (/buzzer/state)');
      return;
    }

    final target = !current;
    setState(() {
      _buzzerCommandInFlight = true;
      _pendingBuzzerTarget = target;
      _buzzerServiceAccepted = false;
      _pendingBuzzerObservedState = null;
    });
    try {
      final response = await AgvService.setBuzzerEnabled(target);
      if (!mounted) return;
      if (response['success'] != true) {
        throw StateError(
          RosServiceResponse.failureMessage(
            response,
            fallback: 'Buzzer komutu reddedildi',
          ),
        );
      }
      final observedTarget = _pendingBuzzerObservedState == target;
      final previous = _buzzerEnabled;
      setState(() {
        _buzzerServiceAccepted = true;
        if (observedTarget) {
          _buzzerEnabled = target;
          _buzzerCommandInFlight = false;
          _pendingBuzzerTarget = null;
          _buzzerServiceAccepted = false;
          _pendingBuzzerObservedState = null;
        }
      });
      if (observedTarget && previous != target) {
        _onMissionEvent('Buzzer: ${target ? 'Açık' : 'Kapalı'}');
      }
      final message = response['message']?.toString().trim() ?? '';
      _onMissionEvent(
        message.isEmpty
            ? 'Buzzer ${target ? 'açma' : 'kapatma'} komutu kabul edildi; durum bekleniyor'
            : message,
      );
      // Görsel durum yalnız /buzzer/state hedef değeri yayınlayınca değişir.
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (_pendingBuzzerTarget == target) {
          _buzzerCommandInFlight = false;
          _pendingBuzzerTarget = null;
          _buzzerServiceAccepted = false;
          _pendingBuzzerObservedState = null;
        }
      });
      final userError = _rosServiceUserError(error).replaceFirst(
        'Bad state: ',
        '',
      );
      _showUserError(
        'Buzzer komutu gönderilemedi: $userError',
      );
    }
  }

  Future<void> _startSavedDemo() async {
    final mapping = _mappingModel;
    if (!mapping.isConnected) {
      _showUserError('ROS bağlı değil');
      return;
    }
    if (mapping.localizationStatus != LocalizationStatus.localizing) {
      _showUserError('Demodan önce lokalizasyon LOCALIZING olmalı');
      return;
    }
    if (!mapping.demoPointsReady) {
      _showUserError('Demodan önce A ve B noktalarını kaydedin');
      return;
    }
    if (mapping.demoRunning || mapping.demoCommandInFlight) return;

    mapping.beginDemoCommand();
    try {
      if (!AgvService.prepareSavedDemoStart()) {
        throw StateError('ROS bağlı değil; otonom moda geçilemedi');
      }
      _connModel.topluGuncelle(
        manuelMod: false,
        uzaktanKontrol: false,
      );
      final response = await AgvService.startSavedDemo();
      if (!RosServiceResponse.triggerSucceeded(response)) {
        throw StateError(RosServiceResponse.failureMessage(
          response,
          fallback: 'Demo başlatılamadı',
        ));
      }
      _onMissionEvent(
        response['message']?.toString().trim().isNotEmpty == true
            ? response['message'].toString()
            : 'Demo başlatıldı',
      );
    } catch (error) {
      _showUserError('Demo başlatılamadı: ${_rosServiceUserError(error)}');
    } finally {
      mapping.endDemoCommand();
    }
  }

  Future<bool> _confirmDemoAreaClear() async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Hareket alanı güvenli mi?'),
            content: const Text(
              'Kullanıcının ve yükü yerleştiren kişinin aracın hareket '
              'alanından çekildiğini doğrulayın.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Alan Boş — Devam Et'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _continueDemo() async {
    final mapping = _mappingModel;
    if (mapping.demoStatus != DemoStatus.waitingLoad) {
      _showUserError('Demo şu anda yük onayı beklemiyor');
      return;
    }
    if (mapping.obstacleDetected) {
      _showUserError('Engel algılandı; devam komutu gönderilemez');
      return;
    }
    if (!await _confirmDemoAreaClear() || !mounted) return;
    if (!mapping.canContinueDemo) return;

    mapping.beginDemoCommand();
    try {
      final response = await AgvService.continueDemo();
      if (!RosServiceResponse.triggerSucceeded(response)) {
        throw StateError(RosServiceResponse.failureMessage(
          response,
          fallback: 'Demo devam ettirilemedi',
        ));
      }
      _onMissionEvent(
        response['message']?.toString().trim().isNotEmpty == true
            ? response['message'].toString()
            : 'Yük onayı alındı; araç B’ye hareket ediyor',
      );
    } catch (error) {
      _showUserError('Demo devam ettirilemedi: ${_rosServiceUserError(error)}');
    } finally {
      mapping.endDemoCommand();
    }
  }

  Future<void> _cancelDemo() async {
    final mapping = _mappingModel;
    if (!mapping.canCancelDemo) return;
    mapping.beginDemoCommand();
    try {
      final response = await AgvService.cancelDemo();
      if (!RosServiceResponse.triggerSucceeded(response)) {
        throw StateError(RosServiceResponse.failureMessage(
          response,
          fallback: 'Demo iptal edilemedi',
        ));
      }
      _onMissionEvent(
        response['message']?.toString().trim().isNotEmpty == true
            ? response['message'].toString()
            : 'Demo iptal edildi',
      );
    } catch (error) {
      _showUserError('Demo iptal edilemedi: ${_rosServiceUserError(error)}');
    } finally {
      mapping.endDemoCommand();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause / arka plan / detach: dead-man — hız sıfır.
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        AgvService.stopManual();
        break;
      case AppLifecycleState.resumed:
        break;
    }
  }

  void _onMapPreviewImage(Uint8List? bytes) {
    if (!mounted) return;
    _mappingModel.applyPreviewImage(bytes);
  }

  void _onMapPreviewMetadata(MapPreviewMetadata? metadata) {
    if (!mounted) return;
    _mappingModel.applyPreviewMetadata(metadata);
  }

  void _onMapPreviewRobotPixel(MapPreviewRobotPixel? pixel) {
    if (!mounted) return;
    _mappingModel.applyRobotPixel(pixel);
  }

  void _onMappingSubscriptionsReady() {
    if (!mounted) return;
    _mappingModel.onSubscriptionsReady();
  }

  Future<void> _promptAndStartMapping() async {
    final mapping = _mappingModel;
    if (!mapping.isConnected) {
      _showUserError('ROS bağlı değil');
      return;
    }
    if (!mapping.canPromptStartMapping) {
      _showUserError('Haritalama şu an başlatılamaz');
      return;
    }

    final nameController = TextEditingController(
      text: mapping.fieldName.trim().isEmpty
          ? 'saha_01'
          : mapping.fieldName.trim(),
    );
    final fieldName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          'Saha adı',
          style: TextStyle(
            color: Colors.white,
            fontSize: 3.sp,
            fontFamily: 'monospace',
          ),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: TextStyle(
            color: Colors.white,
            fontSize: 2.8.sp,
            fontFamily: 'monospace',
          ),
          cursorColor: const Color(0xFF4A90D9),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
          ],
          decoration: InputDecoration(
            hintText: 'saha_01',
            hintStyle: const TextStyle(color: Color(0xFF555555)),
            helperText: 'Yalnız harf, rakam, _ ve -',
            helperStyle:
                TextStyle(color: const Color(0xFF666666), fontSize: 2.2.sp),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF333333)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF4A90D9)),
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'İptal',
              style:
                  TextStyle(color: const Color(0xFF888888), fontSize: 2.6.sp),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: Text(
              'Başlat',
              style:
                  TextStyle(color: const Color(0xFF4A90D9), fontSize: 2.6.sp),
            ),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (!mounted || fieldName == null) return;

    final validationError = RosFieldNameRules.validate(fieldName);
    if (validationError != null) {
      _showUserError(validationError);
      return;
    }

    mapping.setFieldName(fieldName);
    await _startMapping();
  }

  Future<void> _startMapping() async {
    final mapping = _mappingModel;
    if (!mapping.canStartMapping) return;
    final fieldName = mapping.fieldName.trim();
    mapping.beginStartMapping();
    try {
      final response = await AgvService.startMapping(fieldName: fieldName);
      if (!mounted) return;
      final success = RosServiceResponse.mappingStartAccepted(response);
      final rawMsg = response['message']?.toString().trim() ?? '';
      final message = rawMsg.isEmpty
          ? (success ? 'OK' : 'Bilinmeyen hata')
          : RosMappingErrors.toUserMessage(rawMsg);
      if (success) {
        _onMissionEvent('Haritalama başlatıldı ($fieldName): $message');
      } else {
        mapping.endStartMapping();
        _showUserError('Haritalama başlatılamadı: $message');
      }
    } catch (error) {
      if (!mounted) return;
      mapping.endStartMapping();
      _showUserError(
        'Haritalama başlatma hatası: ${_rosServiceUserError(error)}',
      );
    }
  }

  String _rosServiceUserError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('bagli degil') ||
        text.contains('bağlı değil') ||
        text.contains('not connected') ||
        text.contains('timeout') ||
        text.contains('zaman asim') ||
        text.contains('servis') ||
        text.contains('service')) {
      return 'ROS hazır değil veya servis yanıt vermedi';
    }
    return RosMappingErrors.toUserMessage(error.toString());
  }

  Future<void> _refreshSavedFields() async {
    final mapping = _mappingModel;
    if (!AgvService.ros.state.value.isConnected) {
      mapping.applyFieldsListError('ROS bağlı değil — saha listesi alınamadı');
      return;
    }
    mapping.beginFieldsListLoad();
    try {
      final response = await AgvService.listFields();
      if (!mounted) return;
      if (!RosServiceResponse.fieldsListSucceeded(response)) {
        throw StateError(RosServiceResponse.failureMessage(response));
      }
      final fields = SavedFieldInfo.fromListFieldsResponse(response);
      mapping.applyFieldsList(fields);
      _onMissionEvent(
        fields.isEmpty
            ? 'Saha listesi yenilendi (kayıt yok)'
            : 'Saha listesi yenilendi (${fields.length})',
      );
    } catch (error) {
      if (!mounted) return;
      final msg = _rosServiceUserError(error);
      mapping.applyFieldsListError(msg);
      _onMissionEvent('Saha listesi alınamadı: $msg');
    }
  }

  Future<void> _finishAndSaveMapping() async {
    final mapping = _mappingModel;
    if (!mapping.canFinishMapping) return;
    final fieldName = mapping.fieldName.trim();
    mapping.beginFinishMapping();
    try {
      final save = await RosMappingWorkflow.saveActiveMapping(
        save: AgvService.saveMapping,
      );
      if (!mounted) return;
      await mapping.waitUntilMappingSaved();
      if (!mounted) return;
      final saveMsg = save['message']?.toString().trim() ?? '';
      _onMissionEvent(
        'Harita kaydedildi'
        '${fieldName.isEmpty ? '' : ' ($fieldName)'}'
        '${saveMsg.isEmpty ? '' : ': ${RosMappingErrors.toUserMessage(saveMsg)}'}',
      );

      await _refreshSavedFields();
      if (!mounted) return;
      // Status IDLE gelmezse UI kilidi takılı kalmasın.
      mapping.endFinishMapping();
    } catch (error) {
      if (!mounted) return;
      mapping.endFinishMapping();
      _onMissionEvent('Bitir/Kaydet: ${_rosServiceUserError(error)}');
    }
  }

  Future<void> _cancelMappingWithoutSave() async {
    final mapping = _mappingModel;
    if (!mapping.canFinishMapping) return;
    mapping.beginFinishMapping();
    try {
      final response = await AgvService.stopMapping();
      if (!mounted) return;
      if (!RosServiceResponse.mappingStopSucceeded(response)) {
        throw StateError(RosServiceResponse.failureMessage(response));
      }
      final message = response['message']?.toString().trim() ?? '';
      _onMissionEvent(
        'Haritalama kaydedilmeden iptal edildi'
        '${message.isEmpty ? '' : ': ${RosMappingErrors.toUserMessage(message)}'}',
      );
      mapping.endFinishMapping();
    } catch (error) {
      if (!mounted) return;
      mapping.endFinishMapping();
      _showUserError(
          'Haritalama iptal edilemedi: ${_rosServiceUserError(error)}');
    }
  }

  void _disposeOccupancyImage() {
    _occupancyImage?.dispose();
    _occupancyImage = null;
  }

  void _onRosConnectionState() {
    if (!mounted) return;
    final rosState = AgvService.ros.state.value;
    _mappingModel.applyConnectionState(rosState);
    final durum = switch (rosState.status) {
      RosConnectionStatus.connected => ConnDurum.bagli,
      RosConnectionStatus.connecting ||
      RosConnectionStatus.reconnecting =>
        ConnDurum.baglaniyor,
      RosConnectionStatus.error => ConnDurum.hata,
      RosConnectionStatus.disconnected => ConnDurum.cevrimdisi,
    };
    setState(() {
      isConnected = rosState.isConnected;
      if (!rosState.isConnected) {
        _buzzerEnabled = null;
        _buzzerCommandInFlight = false;
        _pendingBuzzerTarget = null;
        _buzzerServiceAccepted = false;
        _pendingBuzzerObservedState = null;
      }
    });
    // PLC durumu yalnızca robot /robot_status üzerinden gelir.
    // WiFi/ROS kopunca eski "PLC Bağlı" bilgisini tutma.
    if (rosState.isConnected) {
      _connModel.topluGuncelle(sistem: durum, robot: durum);
    } else {
      _connModel.topluGuncelle(
        sistem: durum,
        robot: durum,
        plc: ConnDurum.cevrimdisi,
        stm32: ConnDurum.cevrimdisi,
        bt: ConnDurum.cevrimdisi,
      );
      _agvModel.updatePlc(durum: 'bağlantı yok');
    }
    final alarms = Provider.of<GcsAlarmModel>(context, listen: false);
    if (rosState.status == RosConnectionStatus.error) {
      alarms.setAlarm(AlarmTur.robotBaglantiHata, mesaj: rosState.message);
    } else if (rosState.status == RosConnectionStatus.connected) {
      alarms.clearAlarm(AlarmTur.robotBaglantiHata);
    } else {
      alarms.clearAlarm(AlarmTur.plcBaglantiHata);
    }
    final logText = '${rosState.status.name}:${rosState.message}';
    if (rosState.message.isNotEmpty && logText != _lastRosStateLog) {
      _lastRosStateLog = logText;
      _onMissionEvent('ROS: ${rosState.message}');
    }
  }

  Future<void> _loadLastRosAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('rosBridgeAddress');
    if (!mounted || saved == null || saved.isEmpty) return;
    setState(() => _ipController.text = saved);
  }

  // Kısa yol: model erişimi (listen: false — sadece write için)
  GcsConnectionModel get _connModel =>
      Provider.of<GcsConnectionModel>(context, listen: false);

  GcsMappingModel get _mappingModel =>
      Provider.of<GcsMappingModel>(context, listen: false);

  /// "Bağlan" butonuna basıldığında çağrılır.
  ///
  /// 1. Önce `baglaniyor` durumunu set eder (anlık geri bildirim).
  /// 2. Ardından periyodik bağlantı kontrolünü başlatır.
  Future<void> _baglantiyiBaslat(String ip) async {
    if (ip.isEmpty) return;
    String normalized;
    try {
      normalized = RosBridgeClient.normalizeAddress(ip).toString();
    } catch (error) {
      _connModel.topluGuncelle(
        sistem: ConnDurum.hata,
        robot: ConnDurum.hata,
      );
      _onMissionEvent('Geçersiz ROS adresi: $error');
      return;
    }
    setState(() {
      _site = normalized;
      isConnected = false;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rosBridgeAddress', normalized);
    if (!mounted) return;
    _connModel.topluGuncelle(
      sistem: ConnDurum.baglaniyor,
      robot: ConnDurum.baglaniyor,
      plc: ConnDurum.baglaniyor,
    );
    // Yeni adres oturumu: eski preview/status temizlenir (last-good burada bitmez).
    _mappingModel.clearPreviewForNewSession();
    try {
      await AgvService.connectRos(normalized);
    } catch (_) {
      // Durum ve hata metni RosBridgeClient.state uzerinden gosterilir.
    }
  }

  /// Yazılımsal güvenli durdurma — fiziksel acil stopun yerine geçmez.
  ///
  /// Görevi iptal eder, komutu pasife alır, olay günlüğüne kaydeder.
  Future<void> _guvenliDurdur() async {
    final log = Provider.of<GcsEventLogModel>(context, listen: false);
    final mission = Provider.of<GcsMissionModel>(context, listen: false);
    final alarms = Provider.of<GcsAlarmModel>(context, listen: false);

    AgvService.stopManual();
    if (AgvService.ros.state.value.isConnected) {
      try {
        final response = await AgvService.emergencyStop();
        final accepted = response['success'] == true;
        if (accepted) {
          mission.asamaGuncelle(GorevAsama.acilStop);
          alarms.setAlarm(AlarmTur.acilStop,
              mesaj: 'Yazılımsal acil durdurma kilitlendi');
        }
        log.ekle(response['message']?.toString() ??
            'Yazılımsal acil durdurma istendi');
      } catch (error) {
        log.ekle('Güvenli durdurma gönderilemedi: $error');
      }
    } else {
      log.ekle(
          'Manuel hareket durduruldu; ROS bağlı olmadığı için görev iptali gönderilmedi');
    }
  }

  void _manualLiftUnavailable() {
    _onMissionEvent(
        'Lift komutu gönderilmedi: gerçek lift ROS bağlantısı henüz hazır değil');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Gerçek lift bağlantısı henüz hazır değil.'),
    ));
  }

  /// "Bağlantıyı Kes" butonuna basıldığında çağrılır.
  Future<void> _baglantiyiKes() async {
    setState(() {
      _site = '';
      isConnected = false;
    });
    _connModel.baglantiyiKes();
    await AgvService.disconnectRos();
  }

  Future<void> _missionBaslat() async {
    if (!AgvService.ros.state.value.isConnected) {
      _onMissionEvent('Görev başlatılamadı: ROS bağlı değil');
      return;
    }
    try {
      final response = await AgvService.startMission();
      if (!RosServiceResponse.missionAccepted(response)) {
        throw StateError(RosServiceResponse.failureMessage(
          response,
          fallback: 'Görev başlatma isteği reddedildi',
        ));
      }
      _onMissionEvent(
          response['message']?.toString() ?? 'Başlatma yanıtı alındı');
    } catch (error) {
      _onMissionEvent('Başlatma hatası: $error');
    }
  }

  Future<void> _missionIptal() async {
    if (!AgvService.ros.state.value.isConnected) {
      _onMissionEvent('Görev iptal edilemedi: ROS bağlı değil');
      return;
    }
    try {
      final response = await AgvService.cancelMission();
      if (!RosServiceResponse.missionAccepted(response)) {
        throw StateError(RosServiceResponse.failureMessage(
          response,
          fallback: 'Görev iptal isteği reddedildi',
        ));
      }
      _onMissionEvent(response['message']?.toString() ?? 'İptal yanıtı alındı');
    } catch (error) {
      _onMissionEvent('İptal hatası: $error');
    }
  }

  Future<void> _resetSafety() async {
    if (!AgvService.ros.state.value.isConnected) {
      _onMissionEvent('Safety reset yapılamadı: ROS bağlı değil');
      return;
    }
    try {
      final response = await AgvService.resetMissionSafety();
      if (!RosServiceResponse.missionAccepted(response)) {
        throw StateError(RosServiceResponse.failureMessage(
          response,
          fallback: 'Safety reset isteği reddedildi',
        ));
      }
      _onMissionEvent(response['message']?.toString() ?? 'Safety reset yanıtı');
    } catch (error) {
      _onMissionEvent('Safety reset hatası: $error');
    }
  }

  /// UI kademesinden normalize komut ölçeği; istemci SI Twist'e çevirir.
  double get _manualCommandScale =>
      RosManualDriveLimits.scaleFromSpeedStep(speed);

  void _manualDrive(double linearScale, double angularScale) {
    final sent = AgvService.publishManual(
      RosManualDriveLimits.clampCommandScale(linearScale),
      RosManualDriveLimits.clampCommandScale(angularScale),
    );
    if (!sent) {
      _onMissionEvent(
          'Manuel hareket reddedildi: ROS bağlantısını ve fiziksel manuel modu kontrol edin');
    }
  }

  Future<void> _navigateToScenarioPage(List<DataPoint> dataPoints) async {
    // F.3: harita noktaları veya öğretilmiş alma/bırakma düğümleri yeterli.
    final hasTaughtRoute = context.read<GcsNodeModel>().hasRouteEligibleNodes;
    if (dataPoints.isEmpty && !hasTaughtRoute) {
      _onMissionEvent(
        'Senaryo için harita noktası veya Düğümler’de alma/bırakma gerekli',
      );
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScenarioPage(
          dataPoints: dataPoints,
          site: _site,
          rota: _scenarioData,
        ),
      ),
    );

    if (!mounted) return;
    if (result != null) {
      setState(() {
        _scenarioData = result;
      });
    }
  }

  Future<void> _navigateToDataPage(String site) async {
    if (site.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DataPage(site: site)),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AgvService.ros.state.removeListener(_onRosConnectionState);
    AgvService.ros.onRobotStatus = null;
    AgvService.ros.onMissionEvent = null;
    AgvService.ros.onMapMetadata = null;
    AgvService.ros.onMapFrame = null;
    AgvService.ros.onMappingStatus = null;
    AgvService.ros.onLocalizationStatus = null;
    AgvService.ros.onDemoStatus = null;
    AgvService.ros.onObstacleDetected = null;
    AgvService.ros.onBuzzerState = null;
    AgvService.ros.onMapPreviewImage = null;
    AgvService.ros.onMapPreviewMetadata = null;
    AgvService.ros.onMapPreviewRobotPixel = null;
    AgvService.ros.onMappingSubscriptionsReady = null;
    _occupancyImageGeneration++;
    _disposeOccupancyImage();
    AgvService.stopManual();
    unawaited(AgvService.disconnectRos());
    _focusNode.dispose();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agv = context.watch<AgvSensorModel>();
    final mission = context.watch<GcsMissionModel>();
    final alarms = context.watch<GcsAlarmModel>();
    final conn = context.watch<GcsConnectionModel>();
    final mapping = context.watch<GcsMappingModel>();
    final eventLog = context.watch<GcsEventLogModel>();
    final dataPoints = context.watch<DataModel>().dataPoints;
    // Tek kaynak: GCS çalışma modu (Manuel / Otonom)
    final oto = !conn.fizikselManuelMod;
    final calismaModu = conn.fizikselManuelMod ? 'Manuel' : 'Otonom';
    final buzzerButtonText = _buzzerCommandInFlight
        ? (_pendingBuzzerTarget == true
            ? 'Buzzer Açılıyor'
            : 'Buzzer Kapatılıyor')
        : _buzzerEnabled == null
            ? 'Buzzer Durumu Bekleniyor'
            : _buzzerEnabled!
                ? 'Buzzer Kapat'
                : 'Buzzer Aç';
    final buzzerButtonEnabled =
        isConnected && _buzzerEnabled != null && !_buzzerCommandInFlight;

    const Color bg = Color(0xFF121212);
    const Color panelBg = Color(0xFF1A1A1A);
    const Color borderC = Color(0xFF333333);
    const Color accent = Color(0xFF1565C0);
    const Color muted = Color(0xFF9E9E9E);
    const Color bright = Color(0xFFE0E0E0);
    const Color success = Color(0xFF43A047);
    const Color danger = Color(0xFFE53935);

    String safe(String v) => (v.isEmpty || v == 'null') ? '--' : v;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: panelBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(0.3.h),
          child: Divider(height: 0.3.h, color: borderC),
        ),
        titleSpacing: 4.w,
        title: Row(
          children: [
            Container(
              width: 2.5.w,
              height: 2.5.w,
              decoration: BoxDecoration(
                color: conn.sistemBaglanti == ConnDurum.bagli
                    ? success
                    : conn.sistemBaglanti == ConnDurum.baglaniyor
                        ? const Color(0xFFFF9800)
                        : conn.sistemBaglanti == ConnDurum.hata
                            ? danger
                            : const Color(0xFF555555),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 1.5.w),
            Text(
              "LiftAnt GCS",
              style: TextStyle(
                color: Colors.white,
                fontSize: 5.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(width: 2.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 0.5.h),
              decoration: BoxDecoration(
                color: borderC,
                borderRadius: BorderRadius.circular(2.r),
              ),
              child: Text(
                conn.sistemBaglanti.aktif ? _site : conn.sistemBaglanti.etiket,
                style: TextStyle(
                    color: conn.sistemBaglanti.aktif ? muted : danger,
                    fontSize: 3.sp,
                    fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          _NavBtn(
              label: "BAĞLANTI",
              onTap: () {
                setState(() {
                  isConnectionPanelOpen = !isConnectionPanelOpen;
                });
              }),
          _NavBtn(
              label: "ARAÇ 3D",
              onTap: () => Navigator.pushNamed(context, '3d-page')),
          _NavBtn(
              label: "KAYITLI HARİTALAR",
              onTap: () => Navigator.pushNamed(context, 'saved-fields-page')),
          _NavBtn(
              label: "DÜĞÜMLER",
              onTap: () => Navigator.pushNamed(context, 'node-teach-page')),
          _NavBtn(
              label: "QR LİSTESİ",
              onTap: () => Navigator.pushNamed(context, 'QR-page')),
          _NavBtn(label: "VERİLER", onTap: () => _navigateToDataPage(_site)),
          _NavBtn(
              label: "PARAMETRELER",
              onTap: () => Navigator.pushNamed(context, 'parameter-page',
                  arguments: _site)),
          SizedBox(width: 2.w),
        ],
      ),
      body: ExcludeSemantics(
        child: Focus(
          child: KeyboardListener(
            focusNode: _focusNode,
            onKeyEvent: (keyEvent) {
              // Kontrol modu fiziksel anahtardan /robot_status ile gelir.
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ──────── LEFT: Harita + Kontrol Butonları (flex 7) ────────
                Expanded(
                  flex: 7,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Grid en alt katmanda
                      ExcludeSemantics(
                          child: CustomPaint(painter: _GcsGridPainter())),
                      // Row: bağlantı paneli (opsiyonel) + harita sütunu
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Bağlantı paneli — hard-cut (animasyonsuz)
                          if (isConnectionPanelOpen)
                            SizedBox(
                              width: 42.w,
                              child: _inlineConnectionPanel(panelBg, borderC,
                                  muted, bright, success, danger),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ── Özet Bilgi Şeridi ─────────────────────
                                _buildSummaryStrip(
                                  mission,
                                  alarms,
                                  agv,
                                  conn,
                                  panelBg,
                                  borderC,
                                  muted,
                                  bright,
                                  success,
                                  danger,
                                ),
                                // ── Sekme çubuğu ──────────────────────────────
                                _buildWorkTabBar(panelBg, borderC),
                                // ── Sekme içeriği ──────────────────────────────
                                Expanded(
                                  flex: 8,
                                  child: _buildWorkAreaContent(
                                    agv,
                                    mapping,
                                    panelBg,
                                    borderC,
                                    muted,
                                    bright,
                                  ),
                                ),
                                // ── Olay günlüğü ──────────────────────────────
                                Flexible(
                                  flex: 2,
                                  child: _buildEventLogPanel(
                                    eventLog,
                                    panelBg,
                                    borderC,
                                    muted,
                                    bright,
                                  ),
                                ),
                                _buildDemoControlBar(
                                  mapping,
                                  panelBg,
                                  borderC,
                                  muted,
                                  bright,
                                  success,
                                  danger,
                                ),
                                // Alt buton şeridi
                                Container(
                                  color: panelBg,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 3.w, vertical: 1.h),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      PowerButton(
                                        labelOff: 'Görevi\nBaşlat',
                                        labelOn: 'Başlatılıyor',
                                        onPressed: _missionBaslat,
                                        onLongPress: _missionIptal,
                                      ),
                                      SizedBox(width: 2.w),
                                      Expanded(
                                          child: NormalButton(
                                        text: mapping.startButtonLabel,
                                        assignedKey: LogicalKeyboardKey.keyM,
                                        onPressed: () {
                                          unawaited(_promptAndStartMapping());
                                        },
                                      )),
                                      SizedBox(width: 1.5.w),
                                      Expanded(
                                          child: NormalButton(
                                        text: "Senaryo",
                                        assignedKey: LogicalKeyboardKey.keyN,
                                        onPressed: () async {
                                          await _navigateToScenarioPage(
                                              dataPoints);
                                        },
                                      )),
                                      SizedBox(width: 1.5.w),
                                      Expanded(
                                          child: NormalButton(
                                        text: "Led",
                                        assignedKey: LogicalKeyboardKey.keyL,
                                        onPressed: () {
                                          if (!AgvService.setLed()) {
                                            _onMissionEvent(
                                              'LED komutu gönderilmedi: güncel ROS backend LED arayüzü sunmuyor',
                                            );
                                          }
                                        },
                                      )),
                                      SizedBox(width: 1.5.w),
                                      Expanded(
                                          child: NormalButton(
                                        text: buzzerButtonText,
                                        assignedKey: LogicalKeyboardKey.keyB,
                                        enabled: buzzerButtonEnabled,
                                        active: _buzzerEnabled == true,
                                        onPressed: () =>
                                            unawaited(_toggleBuzzer()),
                                      )),
                                    ],
                                  ),
                                ),
                              ], // closes Column.children
                            ), // closes Column
                          ), // closes Expanded(child: Column)
                        ], // closes Row.children
                      ), // closes Row
                    ], // closes Stack.children
                  ), // closes Stack
                ), // closes Expanded(flex: 7)
                // Dikey ayraç
                Container(width: 0.3.w, color: borderC),
                // ──────── RIGHT: Telemetri + Kontroller (flex 3) ────────────
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    padding:
                        EdgeInsets.symmetric(horizontal: 2.w, vertical: 2.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Robot Durumu ──────────────────────────────
                        _sectionLabel("ROBOT DURUMU"),
                        SizedBox(height: 1.h),
                        Container(
                          padding: EdgeInsets.all(2.w),
                          decoration: _flatBox(panelBg, borderC),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _statusRow(
                                'ROBOT BAĞLANTISI',
                                conn.robotBaglanti.etiket,
                                conn.robotBaglanti == ConnDurum.bagli
                                    ? success
                                    : conn.robotBaglanti == ConnDurum.baglaniyor
                                        ? const Color(0xFFFF9800)
                                        : danger,
                                muted,
                                bright,
                              ),
                              SizedBox(height: 0.8.h),
                              _statusRow(
                                'ÇALIŞMA MODU',
                                calismaModu,
                                oto ? accent : bright,
                                muted,
                                bright,
                              ),
                              SizedBox(height: 0.8.h),
                              _statusRow(
                                'UZAKTAN KOMUT',
                                _komutDurumu(conn.robotBaglanti.aktif,
                                    conn.uzaktanKontrolAktif),
                                _komutRenk(
                                    conn.robotBaglanti.aktif,
                                    conn.uzaktanKontrolAktif,
                                    success,
                                    muted,
                                    danger),
                                muted,
                                bright,
                              ),
                              SizedBox(height: 0.8.h),
                              Row(children: [
                                _StatusDot(
                                    conn.plcBaglanti.aktif ? success : muted),
                                SizedBox(width: 1.w),
                                Text(
                                  'PLC ${conn.plcBaglanti.etiket}',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 2.4.sp,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ]),
                            ],
                          ),
                        ),
                        SizedBox(height: 2.h),
                        // ── Telemetri ─────────────────────────────────
                        _sectionLabel("TELEMETRİ"),
                        SizedBox(height: 1.h),
                        IntrinsicHeight(
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                    child: _GcsTelCard(
                                  icon: Icons.battery_full,
                                  label: "GÜÇ",
                                  value:
                                      "${agv.bataryaYuzde.toStringAsFixed(0)}%",
                                  valueColor: _battColor(agv.bataryaYuzde),
                                  panelBg: panelBg,
                                  borderC: borderC,
                                  bright: bright,
                                  muted: muted,
                                )),
                                SizedBox(width: 1.5.w),
                                Expanded(
                                    child: _GcsTelCard(
                                  icon: Icons.thermostat,
                                  label: "KONTROLCÜ SICAK.",
                                  value: safe(agv.sicaklik) == '--'
                                      ? '--'
                                      : "${safe(agv.sicaklik)}°C",
                                  panelBg: panelBg,
                                  borderC: borderC,
                                  bright: bright,
                                  muted: muted,
                                )),
                              ]),
                        ),
                        SizedBox(height: 1.5.h),
                        IntrinsicHeight(
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                    child: _GcsTelCard(
                                  icon: Icons.electric_bolt,
                                  label: "AKIM",
                                  value: safe(agv.amper) == '--'
                                      ? '--'
                                      : "${safe(agv.amper)} A",
                                  panelBg: panelBg,
                                  borderC: borderC,
                                  bright: bright,
                                  muted: muted,
                                )),
                                SizedBox(width: 1.5.w),
                                Expanded(
                                    child: _GcsTelCard(
                                  icon: Icons.electric_meter,
                                  label: "VOLTAJ",
                                  value: safe(agv.voltage) == '--'
                                      ? '--'
                                      : "${safe(agv.voltage)} V",
                                  panelBg: panelBg,
                                  borderC: borderC,
                                  bright: bright,
                                  muted: muted,
                                )),
                              ]),
                        ),
                        SizedBox(height: 1.5.h),
                        IntrinsicHeight(
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                    child: _GcsTelCard(
                                  icon: Icons.speed,
                                  label: "HIZ",
                                  value:
                                      "${agv.anlikHiz.toStringAsFixed(2)} m/s",
                                  panelBg: panelBg,
                                  borderC: borderC,
                                  bright: bright,
                                  muted: muted,
                                )),
                                SizedBox(width: 1.5.w),
                                Expanded(
                                    child: _GcsTelCard(
                                  icon: Icons.location_on,
                                  label: "KONUM",
                                  value:
                                      "(${agv.currX.toStringAsFixed(1)}, ${agv.currY.toStringAsFixed(1)})",
                                  panelBg: panelBg,
                                  borderC: borderC,
                                  bright: bright,
                                  muted: muted,
                                )),
                              ]),
                        ),
                        SizedBox(height: 1.5.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 2.w, vertical: 1.h),
                          decoration: _flatBox(panelBg, borderC),
                          child: Row(children: [
                            Icon(Icons.timelapse, color: muted, size: 5.sp),
                            SizedBox(width: 2.w),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("GÖREV SÜRESİ",
                                    style: TextStyle(
                                        color: muted,
                                        fontSize: 2.5.sp,
                                        letterSpacing: 0.5)),
                                Text(
                                  mission.gorevAktif
                                      ? mission.gorevSuresiFormatli
                                      : '--',
                                  style: TextStyle(
                                    color: bright,
                                    fontSize: 3.5.sp,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ]),
                        ),
                        SizedBox(height: 2.h),
                        // ── Mod ve Kontrol ────────────────────────────
                        _sectionLabel("MOD VE KONTROL"),
                        SizedBox(height: 1.h),
                        Container(
                          padding: EdgeInsets.all(2.w),
                          decoration: _flatBox(panelBg, borderC),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('ÇALIŞMA MODU',
                                          style: TextStyle(
                                              color: muted,
                                              fontSize: 2.5.sp,
                                              letterSpacing: 0.5)),
                                      Text(
                                        conn.fizikselManuelMod
                                            ? 'Manuel'
                                            : 'Otonom',
                                        style: TextStyle(
                                          color: conn.fizikselManuelMod
                                              ? bright
                                              : accent,
                                          fontSize: 3.5.sp,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  ExcludeSemantics(
                                    child: SizedBox(
                                      width: 14.w,
                                      height: 28.h,
                                      child: FittedBox(
                                        fit: BoxFit.fill,
                                        child: Switch(
                                          value: oto,
                                          activeThumbColor: accent,
                                          onChanged: null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: EdgeInsets.only(top: 0.8.h),
                                child: Text(
                                  oto
                                      ? 'Otonom: fiziksel mod anahtarı, WASD kapalı'
                                      : 'Manuel: fiziksel mod doğrulandı, WASD açık',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 2.2.sp,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              SizedBox(height: 1.2.h),
                              _statusRow(
                                'UZAKTAN KONTROL',
                                oto
                                    ? 'Kilitli (Otonom)'
                                    : (conn.uzaktanKontrolAktif
                                        ? 'Aktif'
                                        : 'Kilitli'),
                                oto
                                    ? muted
                                    : (conn.uzaktanKontrolAktif
                                        ? success
                                        : danger),
                                muted,
                                bright,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 2.h),

                        // ── Güvenli Durdur ────────────────────────────
                        GestureDetector(
                          onTap: _guvenliDurdur,
                          onLongPress: _resetSafety,
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 1.4.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A0A0A),
                              border: Border.all(
                                  color: const Color(0xFFB71C1C), width: 0.6.w),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.stop_circle_outlined,
                                    color: const Color(0xFFEF5350),
                                    size: 4.5.sp),
                                SizedBox(width: 1.5.w),
                                Text(
                                  'GÜVENLİ DURDUR',
                                  style: TextStyle(
                                    color: const Color(0xFFEF5350),
                                    fontSize: 3.5.sp,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 2.h),

                        // ── Manuel Kontroller ─────────────────────────
                        _sectionLabel("MANUEL KONTROLLER"),
                        if (oto || !conn.robotBaglanti.aktif)
                          Padding(
                            padding: EdgeInsets.only(bottom: 1.h),
                            child: Text(
                              !conn.robotBaglanti.aktif
                                  ? 'Robot bağlantısı yok; manuel kontrol kilitli'
                                  : 'Otomatik modda manuel kontrol pasif',
                              style: TextStyle(
                                color: muted,
                                fontSize: 2.4.sp,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        SizedBox(height: 0.5.h),
                        // WASD/QE: yalnız Otonom veya bağlantı yokken kapalı.
                        // Mapping durumu operatörün manuel sürüş tercihini kilitlemez.
                        Builder(builder: (context) {
                          final joystickBlocked =
                              oto || !conn.robotBaglanti.aktif;
                          final joystickKeysEnabled =
                              !joystickBlocked && !isConnectionPanelOpen;
                          return IgnorePointer(
                            ignoring: joystickBlocked,
                            child: AnimatedOpacity(
                              opacity: joystickBlocked ? 0.35 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: EdgeInsets.all(2.w),
                                          decoration:
                                              _flatBox(panelBg, borderC),
                                          child: Column(
                                            children: [
                                              Text("LİFT",
                                                  style: TextStyle(
                                                      color: muted,
                                                      fontSize: 3.sp,
                                                      letterSpacing: 1)),
                                              SizedBox(height: 2.h),
                                              ControlButton(
                                                shortcutsEnabled:
                                                    joystickKeysEnabled,
                                                onPressed:
                                                    _manualLiftUnavailable,
                                                onReleased: () {},
                                                assignedKey:
                                                    LogicalKeyboardKey.keyQ,
                                                child: Icon(
                                                    Icons.arrow_upward_rounded,
                                                    size: 7.sp),
                                              ),
                                              SizedBox(height: 3.h),
                                              ControlButton(
                                                shortcutsEnabled:
                                                    joystickKeysEnabled,
                                                onPressed:
                                                    _manualLiftUnavailable,
                                                onReleased: () {},
                                                assignedKey:
                                                    LogicalKeyboardKey.keyE,
                                                child: Icon(
                                                    Icons
                                                        .arrow_downward_rounded,
                                                    size: 7.sp),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 2.w),
                                      Expanded(
                                        child: Container(
                                          padding: EdgeInsets.all(2.w),
                                          decoration:
                                              _flatBox(panelBg, borderC),
                                          child: Column(
                                            children: [
                                              Text("ARAÇ",
                                                  style: TextStyle(
                                                      color: muted,
                                                      fontSize: 3.sp,
                                                      letterSpacing: 1)),
                                              SizedBox(height: 1.h),
                                              ControlButton(
                                                shortcutsEnabled:
                                                    joystickKeysEnabled,
                                                onPressed: () {
                                                  _manualDrive(
                                                      _manualCommandScale, 0);
                                                },
                                                onReleased: () {
                                                  AgvService.stopManual();
                                                },
                                                assignedKey:
                                                    LogicalKeyboardKey.keyW,
                                                child: Icon(Icons.arrow_drop_up,
                                                    size: 7.sp),
                                              ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  ControlButton(
                                                    shortcutsEnabled:
                                                        joystickKeysEnabled,
                                                    onPressed: () {
                                                      _manualDrive(0,
                                                          _manualCommandScale);
                                                    },
                                                    onReleased: () {
                                                      AgvService.stopManual();
                                                    },
                                                    assignedKey:
                                                        LogicalKeyboardKey.keyA,
                                                    child: Icon(
                                                        Icons.arrow_left,
                                                        size: 7.sp),
                                                  ),
                                                  SizedBox(width: 8.w),
                                                  ControlButton(
                                                    shortcutsEnabled:
                                                        joystickKeysEnabled,
                                                    onPressed: () {
                                                      _manualDrive(0,
                                                          -_manualCommandScale);
                                                    },
                                                    onReleased: () {
                                                      AgvService.stopManual();
                                                    },
                                                    assignedKey:
                                                        LogicalKeyboardKey.keyD,
                                                    child: Icon(
                                                        Icons.arrow_right,
                                                        size: 7.sp),
                                                  ),
                                                ],
                                              ),
                                              ControlButton(
                                                shortcutsEnabled:
                                                    joystickKeysEnabled,
                                                onPressed: () {
                                                  _manualDrive(
                                                      -_manualCommandScale, 0);
                                                },
                                                onReleased: () {
                                                  AgvService.stopManual();
                                                },
                                                assignedKey:
                                                    LogicalKeyboardKey.keyS,
                                                child: Icon(
                                                    Icons.arrow_drop_down,
                                                    size: 7.sp),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ), // Row (lift + araç butonları)
                                  SizedBox(height: 1.5.h),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 2.w, vertical: 1.h),
                                    decoration: _flatBox(panelBg, borderC),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'KOMUT: $speed'
                                          ' (${_manualCommandScale.toStringAsFixed(1)})',
                                          style: TextStyle(
                                            color: bright,
                                            fontSize: 3.sp,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        ExcludeSemantics(
                                          child: Slider(
                                            value: speed
                                                .clamp(
                                                  RosManualDriveLimits
                                                      .speedStepMin,
                                                  RosManualDriveLimits
                                                      .speedStepMax,
                                                )
                                                .toDouble(),
                                            divisions: RosManualDriveLimits
                                                .speedStepMax,
                                            min: RosManualDriveLimits
                                                .speedStepMin
                                                .toDouble(),
                                            max: RosManualDriveLimits
                                                .speedStepMax
                                                .toDouble(),
                                            activeColor: accent,
                                            inactiveColor: borderC,
                                            label: speed.toString(),
                                            onChanged: (val) {
                                              setState(() {
                                                speed = val.toInt();
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 3.h),
                                ],
                              ), // Column inside AnimatedOpacity
                            ), // AnimatedOpacity
                          ); // IgnorePointer
                        }), // Builder (joystickKeysEnabled)
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Inline bağlantı paneli (animasyonsuz, hard-cut) ──────────────────
  Widget _inlineConnectionPanel(
    Color panelBg,
    Color borderC,
    Color muted,
    Color bright,
    Color success,
    Color danger,
  ) {
    final conn = context.watch<GcsConnectionModel>();

    Color durumRengi(ConnDurum d) => switch (d) {
          ConnDurum.bagli => success,
          ConnDurum.baglaniyor => const Color(0xFFFF9800),
          ConnDurum.hata => danger,
          ConnDurum.cevrimdisi => const Color(0xFF555555),
        };

    Widget kanalRow(String label, ConnDurum durum, {String? alt}) {
      final renk = durumRengi(durum);
      return Padding(
        padding: EdgeInsets.only(bottom: 1.4.h),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 1.8.w,
            height: 1.8.w,
            decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
          ),
          SizedBox(width: 1.5.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: muted, fontSize: 2.4.sp)),
                Text(
                  alt ?? durum.etiket,
                  style: TextStyle(
                    color: renk,
                    fontSize: 2.4.sp,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ]),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        border: Border(right: BorderSide(color: borderC, width: 0.3.w)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.5.h),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Başlık + kapat ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text('BAĞLANTI PANELİ',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: muted,
                          fontSize: 2.8.sp,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2)),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    isConnectionPanelOpen = false;
                  }),
                  child: Icon(Icons.close, color: muted, size: 4.5.sp),
                ),
              ],
            ),
            SizedBox(height: 1.5.h),

            // ── Bağlantı kanalları ──────────────────────────────────────
            _connSectionLabel('BAĞLANTI KANALLARI', muted),
            SizedBox(height: 1.h),
            kanalRow('Genel Sistem Bağlantısı', conn.sistemBaglanti),
            kanalRow('Robot Bağlantısı', conn.robotBaglanti,
                alt: conn.robotBaglanti.aktif
                    ? 'Bağlı: $_site'
                    : conn.robotBaglanti.etiket),
            kanalRow('PLC Bağlantısı', conn.plcBaglanti),
            kanalRow('STM32 Haberleşmesi', conn.stm32Baglanti),
            kanalRow('Bluetooth Bağlantısı', conn.bluetooth),
            SizedBox(height: 1.5.h),

            // ── IP girişi ───────────────────────────────────────────────
            _connSectionLabel('ROBOT IP ADRESİ', muted),
            SizedBox(height: 1.h),
            TextField(
              controller: _ipController,
              style: TextStyle(
                  color: bright, fontSize: 3.5.sp, fontFamily: 'monospace'),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF111111),
                hintText: 'ws://192.168.x.x:9090',
                hintStyle: TextStyle(
                    color: const Color(0xFF444444),
                    fontSize: 3.sp,
                    fontFamily: 'monospace'),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.5.h),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: borderC, width: 0.5.w),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: const Color(0xFF1565C0), width: 0.7.w),
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ),
            SizedBox(height: 1.5.h),

            // ── Bağlan butonu ───────────────────────────────────────────
            GestureDetector(
              onTap: () {
                final ip = _ipController.text.trim();
                if (ip.isEmpty) return;
                _baglantiyiBaslat(ip);
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 1.1.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2540),
                  border:
                      Border.all(color: const Color(0xFF1565C0), width: 0.5.w),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.link,
                        color: const Color(0xFF42A5F5), size: 3.5.sp),
                    SizedBox(width: 1.w),
                    Flexible(
                      child: Text('BAĞLAN',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF42A5F5),
                            fontSize: 3.2.sp,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            letterSpacing: 0.8,
                          )),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 1.h),

            // ── Bağlantıyı kes butonu ───────────────────────────────────
            GestureDetector(
              onTap: () {
                _baglantiyiKes();
                setState(() {
                  isConnectionPanelOpen = false;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 1.1.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1010),
                  border:
                      Border.all(color: const Color(0xFF6B2020), width: 0.5.w),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.link_off,
                        color: const Color(0xFFEF5350), size: 3.5.sp),
                    SizedBox(width: 1.w),
                    Flexible(
                      child: Text('BAĞLANTIYI KES',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFFEF5350),
                            fontSize: 3.2.sp,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            letterSpacing: 0.8,
                          )),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }

  // ── Özet Bilgi Şeridi ──────────────────────────────────────────────────────
  Widget _buildSummaryStrip(
    GcsMissionModel mission,
    GcsAlarmModel alarms,
    AgvSensorModel agv,
    GcsConnectionModel conn,
    Color panelBg,
    Color borderC,
    Color muted,
    Color bright,
    Color success,
    Color danger,
  ) {
    String safe(String v) => (v.isEmpty || v == 'null') ? '--' : v;

    final robotBagli = conn.robotBaglanti.aktif;
    final alarmColor = !robotBagli
        ? muted
        : alarms.kritikAlarmVar
            ? danger
            : alarms.temiz
                ? success
                : const Color(0xFFFF9800);

    final rota = mission.rotaDugumleri.isNotEmpty
        ? mission.rotaDugumleri.join(' → ')
        : (mission.almaNoktasi.isNotEmpty || mission.birakNoktasi.isNotEmpty)
            ? '${safe(mission.almaNoktasi)} → ${safe(mission.birakNoktasi)}'
            : '--';

    // Robot/WiFi yokken eski agv.plcDurum ("bağlı") gösterilmesin.
    final plcEtiket = !robotBagli
        ? 'Bağlı Değil'
        : (conn.plcBaglanti.aktif ? 'Bağlı' : conn.plcBaglanti.etiket);

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        border: Border(bottom: BorderSide(color: borderC, width: 0.3.w)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Kart 1: Görev Özeti ───────────────────────────────────────────
          Expanded(
              child: _SummaryCard(
            title: 'GÖREV ÖZETİ',
            titleColor: mission.asama.hataVeyaStop ? danger : null,
            borderC:
                mission.asama.hataVeyaStop ? danger.withAlpha(100) : borderC,
            muted: muted,
            bright: bright,
            rows: [
              _SRow('ID', safe(mission.gorevId)),
              _SRow('KAYNAK', safe(mission.gorevKaynagi)),
              _SRow('ROTA', rota, truncate: true),
              _SRow('DURUM', mission.asama.etiket,
                  valueColor: mission.asama.hataVeyaStop
                      ? danger
                      : mission.asama == GorevAsama.tamamlandi
                          ? success
                          : null,
                  truncate: true),
              _SRow(
                'SONRAKİ',
                // Kapı izni zaten verilmişse "Kapı iznini bekle" yerine ileri adım yaz
                (mission.asama == GorevAsama.yukluHareket ||
                            mission.asama == GorevAsama.kapiIzniBekleniyor) &&
                        mission.kapiIzni
                    ? 'Kapıdan geç → Bırakma noktasına ilerle'
                    : mission.asama.sonrakiAdim,
                truncate: true,
              ),
            ],
            footer: _MissionProgressBar(
              asama: mission.asama,
              bright: bright,
              muted: muted,
              success: success,
              danger: danger,
            ),
          )),
          SizedBox(width: 1.5.w),

          // ── Kart 2: Fabrika Otomasyon Özeti ───────────────────────────────
          Expanded(
              child: _SummaryCard(
            title: 'FABRİKA OTOMASYON',
            borderC: borderC,
            muted: muted,
            bright: bright,
            rows: [
              _SRow('PLC', plcEtiket,
                  valueColor:
                      robotBagli && conn.plcBaglanti.aktif ? success : danger),
              _SRow(
                  'KAPI İZNİ',
                  !robotBagli
                      ? '--'
                      : (mission.kapiIzni ? 'Serbest' : 'Kapalı'),
                  valueColor: !robotBagli
                      ? muted
                      : (mission.kapiIzni ? success : muted)),
              _SRow(
                  'GELEN',
                  !robotBagli
                      ? '--'
                      : safe(mission.sonOtomasyonMesaj.isNotEmpty
                          ? mission.sonOtomasyonMesaj
                          : agv.plcSonMesaj),
                  truncate: true),
              _SRow('GÖNDERİLEN',
                  !robotBagli ? '--' : safe(mission.sonGonderilenMesaj),
                  truncate: true),
            ],
          )),
          SizedBox(width: 1.5.w),

          // ── Kart 3: Konum Doğrulama ───────────────────────────────────────
          Expanded(
              child: _SummaryCard(
            title: 'KONUM DOĞRULAMA',
            borderC: borderC,
            muted: muted,
            bright: bright,
            rows: robotBagli
                ? [
                    _SRow('POZ',
                        '${agv.currX.toStringAsFixed(2)}, ${agv.currY.toStringAsFixed(2)}'),
                    _SRow('LOKAL',
                        agv.lokalizasyonGecerli ? 'Geçerli' : 'Geçersiz',
                        valueColor: agv.lokalizasyonGecerli ? success : danger),
                    _SRow('EDGE', safe(agv.aktifRotaEdge), truncate: true),
                    _SRow('SONRAKİ', safe(agv.sonrakiNode), truncate: true),
                    _SRow(
                        'SAPMA',
                        agv.rotaSapmasi.isFinite
                            ? '${agv.rotaSapmasi.toStringAsFixed(3)} m'
                            : '--'),
                    _SRow('ENGEL', agv.engelAlgilandi ? 'VAR' : 'Yok',
                        valueColor: agv.engelAlgilandi ? danger : success),
                    _SRow('SON QR', safe(agv.sonQR)),
                  ]
                : [
                    const _SRow('POZ', '--'),
                    _SRow('LOKAL', 'İzlenmiyor', valueColor: muted),
                    const _SRow('EDGE', '--'),
                    const _SRow('SONRAKİ', '--'),
                    const _SRow('SAPMA', '--'),
                    _SRow('ENGEL', 'İzlenmiyor', valueColor: muted),
                    const _SRow('SON QR', '--'),
                  ],
          )),
          SizedBox(width: 1.5.w),

          // ── Kart 4: Güvenlik Özeti ────────────────────────────────────────
          Expanded(
              child: _SummaryCard(
            title: 'GÜVENLİK',
            titleColor: alarmColor,
            borderC: borderC,
            muted: muted,
            bright: bright,
            rows: robotBagli
                ? [
                    _SRow(
                        'DURUM',
                        alarms.temiz && !alarms.guvenliDurusAktif
                            ? 'Güvenli'
                            : 'Uyarı',
                        valueColor: alarms.temiz && !alarms.guvenliDurusAktif
                            ? success
                            : danger),
                    _SRow('ACİL STOP',
                        alarms.isAktif(AlarmTur.acilStop) ? 'AKTİF' : 'Normal',
                        valueColor: alarms.isAktif(AlarmTur.acilStop)
                            ? danger
                            : success),
                    _SRow('GÜV. DURUŞ',
                        alarms.guvenliDurusAktif ? 'Aktif' : 'Normal',
                        valueColor:
                            alarms.guvenliDurusAktif ? danger : success),
                    _SRow(
                        'ALARM',
                        alarms.temiz
                            ? 'Yok'
                            : (alarms.aktifAlarmlar.isNotEmpty
                                ? alarms.aktifAlarmlar.first.tur.etiket
                                : 'Aktif'),
                        valueColor:
                            alarms.temiz ? success : const Color(0xFFFF9800),
                        truncate: true),
                    _SRow(
                        'KRİTİK',
                        alarms.kritikAlarmVar
                            ? (alarms.enKritik?.etiket ?? 'Var')
                            : 'Yok',
                        valueColor: alarms.kritikAlarmVar ? danger : success,
                        truncate: true),
                  ]
                : [
                    _SRow('DURUM', 'Bağlı Değil', valueColor: danger),
                    const _SRow('ACİL STOP', '--'),
                    const _SRow('GÜV. DURUŞ', '--'),
                    _SRow('ALARM', 'İzlenmiyor', valueColor: muted),
                    const _SRow('KRİTİK', '--'),
                  ],
          )),
        ],
      ),
    );
  }

  /// Olay günlüğü paneli — sol alt, buton şeridinin üstünde.
  Widget _buildEventLogPanel(
    GcsEventLogModel eventLog,
    Color panelBg,
    Color borderC,
    Color muted,
    Color bright,
  ) {
    final kayitlar = eventLog.kayitlar;

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        border: Border(
          top: BorderSide(color: borderC, width: 0.3.w),
          bottom: BorderSide(color: borderC, width: 0.3.w),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SİSTEM MESAJLARI / OLAY GÜNLÜĞÜ',
            style: TextStyle(
              color: muted,
              fontSize: 2.3.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 0.4.h),
          Expanded(
            child: kayitlar.isEmpty
                ? Center(
                    child: Text(
                      'Henüz olay kaydı yok',
                      style: TextStyle(color: muted, fontSize: 2.5.sp),
                    ),
                  )
                : ListView.builder(
                    itemCount: kayitlar.length,
                    itemBuilder: (_, i) {
                      final e = kayitlar[i];
                      return Padding(
                        padding: EdgeInsets.only(bottom: 0.4.h),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '[${e.zamanFormatli}]',
                              style: TextStyle(
                                color: const Color(0xFF616161),
                                fontSize: 2.3.sp,
                                fontFamily: 'monospace',
                              ),
                            ),
                            SizedBox(width: 1.w),
                            Expanded(
                              child: Text(
                                e.mesaj,
                                style: TextStyle(
                                  color: bright,
                                  fontSize: 2.5.sp,
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(
    String label,
    String value,
    Color valueColor,
    Color muted,
    Color bright,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 22.w,
          child: Text(
            label,
            style:
                TextStyle(color: muted, fontSize: 2.4.sp, letterSpacing: 0.3),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 2.8.sp,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _komutDurumu(bool connected, bool uzaktanAktif) {
    final oto = !_connModel.fizikselManuelMod;
    if (!connected) return 'Pasif';
    // Otomatik modda uzaktan kontrol kilitlidir ama komut gönderimi sistem tarafından aktiftir.
    if (oto) return 'Aktif (Otonom)';
    if (!uzaktanAktif) return 'Pasif';
    return 'Aktif';
  }

  Color _komutRenk(
    bool connected,
    bool uzaktanAktif,
    Color success,
    Color muted,
    Color danger,
  ) {
    final oto = !_connModel.fizikselManuelMod;
    if (!connected) return danger;
    if (oto) return success;
    if (!uzaktanAktif) return muted;
    return success;
  }

  Widget _sectionLabel(String title) => Padding(
        padding: EdgeInsets.only(bottom: 0.5.h),
        child: Text(
          title,
          style: TextStyle(
            color: const Color(0xFF616161),
            fontSize: 2.8.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      );

  Widget _connSectionLabel(String title, Color color) => Padding(
        padding: EdgeInsets.only(bottom: 0.4.h),
        child: Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 2.6.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      );

  BoxDecoration _flatBox(Color bg, Color border) => BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 0.5.w),
        borderRadius: BorderRadius.circular(4.r),
      );

  Color _battColor(double pct) {
    if (pct > 50) return const Color(0xFF43A047);
    if (pct > 20) return Colors.orange;
    return const Color(0xFFE53935);
  }

  // ── Orta alan sekme yapısı ────────────────────────────────────────────────

  /// Sekme çubuğu — düz GCS stili.
  Widget _buildWorkTabBar(Color panelBg, Color borderC) {
    const tabs = ['HARİTA', 'KAMERA', 'LiDAR', '3D'];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.w),
      decoration: BoxDecoration(
        color: panelBg,
        border: Border(
          bottom: BorderSide(color: borderC, width: 0.3.w),
        ),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _selectedWorkTab == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedWorkTab = i),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 1.2.h),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color:
                        selected ? const Color(0xFF1565C0) : Colors.transparent,
                    width: 1.5.h.clamp(1.5, 3.0),
                  ),
                ),
              ),
              child: Text(
                tabs[i],
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF42A5F5)
                      : const Color(0xFF616161),
                  fontSize: 3.sp,
                  fontFamily: 'monospace',
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  int _fingerprintDataPoints(List<DataPoint> dataPoints) {
    var hash = dataPoints.length;
    for (final point in dataPoints) {
      hash = Object.hash(
        hash,
        point.type,
        point.x,
        point.y,
        point.rosNodeName,
        point.yaw,
      );
    }
    return hash;
  }

  void _rebuildCachedMapLayers({
    required OccupancyGridMetadata metadata,
    required List<DataPoint> dataPoints,
    required GcsMissionModel mission,
    required String aktifRotaEdge,
  }) {
    final points = <MapPoint>[];
    for (final point in dataPoints) {
      MapPointType? type;
      String label = '';
      if (point.type.startsWith('pickupPoint')) {
        type = MapPointType.almaNoktasi;
        label = point.type.substring(11);
      } else if (point.type.startsWith('dropoffPoint')) {
        type = MapPointType.birakNoktasi;
        label = point.type.substring(12);
      } else if (point.type.startsWith('startArea')) {
        type = MapPointType.beklemeNoktasi;
        label = 'S${point.type.substring(9)}';
      } else if (point.type.startsWith('chargeStation')) {
        type = MapPointType.sarjIstasyonu;
        label = 'ŞARJ';
      } else if (point.type.startsWith('Q')) {
        type = MapPointType.qrNoktasi;
        label = point.type;
      }
      if (type == null) continue;

      final nodeName = RosGcsContract.nodeForPoint(point);
      final mapPosition = RosGcsContract.editorGridToMap(
        point.x,
        point.y,
        metadata,
      );
      points.add(MapPoint(
        id: nodeName ?? '${point.type}_${point.x}_${point.y}',
        label: label,
        x: mapPosition.dx,
        y: mapPosition.dy,
        type: type,
        aktif: nodeName != null &&
            (nodeName == mission.almaNoktasi ||
                nodeName == mission.birakNoktasi),
      ));
    }

    final routes = <MapRoute>[];
    final edge = aktifRotaEdge.split('->');
    if (edge.length == 2) {
      final from = RosGcsContract.graphNodes[edge[0]];
      final to = RosGcsContract.graphNodes[edge[1]];
      if (from != null && to != null) {
        routes.add(MapRoute(
          id: aktifRotaEdge,
          label: aktifRotaEdge,
          waypoints: [from, to],
        ));
      }
    }

    _cachedMapPoints = points;
    _cachedMapRoutes = routes;
  }

  /// Robot pose her tick güncellenir; nokta/rota dönüşümü yalnız key değişince.
  GcsMapData _mapDataFromSavedPoints(AgvSensorModel agv) {
    final metadata = _mapMetadata!;
    final dataPoints =
        Provider.of<DataModel>(context, listen: false).dataPoints;
    final mission = Provider.of<GcsMissionModel>(context, listen: false);
    final key = Object.hash(
      metadata.width,
      metadata.height,
      metadata.resolution,
      metadata.originX,
      metadata.originY,
      metadata.originYaw,
      _fingerprintDataPoints(dataPoints),
      mission.almaNoktasi,
      mission.birakNoktasi,
      agv.aktifRotaEdge,
      identityHashCode(_occupancyImage),
    );
    if (_cachedMapStaticKey != key) {
      _cachedMapStaticKey = key;
      _rebuildCachedMapLayers(
        metadata: metadata,
        dataPoints: dataPoints,
        mission: mission,
        aktifRotaEdge: agv.aktifRotaEdge,
      );
    }
    return GcsMapData(
      robotX: agv.currX,
      robotY: agv.currY,
      robotYaw: agv.currYaw,
      points: _cachedMapPoints,
      routes: _cachedMapRoutes,
      occupancyImage: _occupancyImage,
      mapMeta: metadata,
    );
  }

  /// Seçili sekmeye göre içerik döndürür.
  Widget _buildDemoControlBar(
    GcsMappingModel mapping,
    Color panelBg,
    Color borderC,
    Color muted,
    Color bright,
    Color success,
    Color danger,
  ) {
    final statusColor =
        mapping.demoStatus == DemoStatus.complete ? success : bright;
    final demoStatusText = mapping.demoMessage.trim().isNotEmpty
        ? mapping.demoMessage.trim()
        : mapping.demoStatus?.etiket ?? 'Demo durumu bekleniyor';
    final points = mapping.demoPointsReady ? 'A/B hazır' : 'A/B eksik';
    return Container(
      padding: EdgeInsets.fromLTRB(3.w, 0.6.h, 3.w, 0.8.h),
      decoration: BoxDecoration(
        color: panelBg,
        border: Border(top: BorderSide(color: borderC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.route_outlined, color: statusColor, size: 3.5.sp),
              SizedBox(width: 1.w),
              Expanded(
                child: Text(
                  demoStatusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: statusColor, fontSize: 2.5.sp),
                ),
              ),
              Text(
                '$points${mapping.demoActiveTarget.isEmpty ? '' : ' · Hedef ${mapping.demoActiveTarget}'}',
                style: TextStyle(color: muted, fontSize: 2.2.sp),
              ),
            ],
          ),
          SizedBox(height: 0.5.h),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: mapping.canStartDemo
                      ? () => unawaited(_startSavedDemo())
                      : null,
                  style: FilledButton.styleFrom(
                    disabledBackgroundColor: const Color(0xFF2A2A2A),
                    disabledForegroundColor: muted,
                  ),
                  child: const Text('Demoyu Başlat'),
                ),
              ),
              SizedBox(width: 1.w),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: mapping.canContinueDemo
                      ? () => unawaited(_continueDemo())
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: success,
                    disabledBackgroundColor: const Color(0xFF2A2A2A),
                    disabledForegroundColor: muted,
                  ),
                  child: const Text('Yük Yerleştirildi / Devam Et'),
                ),
              ),
              SizedBox(width: 1.w),
              Expanded(
                child: OutlinedButton(
                  onPressed: mapping.canCancelDemo
                      ? () => unawaited(_cancelDemo())
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: danger,
                    disabledForegroundColor: muted,
                    side: BorderSide(
                      color: mapping.canCancelDemo ? danger : borderC,
                    ),
                  ),
                  child: const Text('Demoyu İptal Et'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Seçili sekmeye göre içerik döndürür.
  Widget _buildWorkAreaContent(
    AgvSensorModel agv,
    GcsMappingModel mapping,
    Color panelBg,
    Color borderC,
    Color muted,
    Color bright,
  ) {
    switch (_selectedWorkTab) {
      // ── Harita ─────────────────────────────────────────────────────────
      case 0:
        final Widget body;
        if (mapping.hasPreviewPng) {
          final demoMarkers = <MapPreviewNodeMarker>[];
          final demoA = mapPreviewDemoPointMarker(
            label: 'A',
            pose: mapping.demoPointA,
            metadata: mapping.previewMetadata,
            color: const Color(0xFF29B6F6),
          );
          final demoB = mapPreviewDemoPointMarker(
            label: 'B',
            pose: mapping.demoPointB,
            metadata: mapping.previewMetadata,
            color: const Color(0xFFFF7043),
          );
          if (demoA != null) demoMarkers.add(demoA);
          if (demoB != null) demoMarkers.add(demoB);
          // Öncelik: /map_preview PNG (+ robot_pixel). Last-good kopunca kalır.
          body = MapPreviewStage(
            pngBytes: mapping.previewPng!,
            metadata: mapping.previewMetadata,
            robotPixel: mapping.visibleRobotPixel,
            awaitingFresh: mapping.awaitingFreshPreview,
            sourceLabel: mapping.previewSourceLabel,
            nodeMarkers: demoMarkers,
          );
        } else if (_mapMetadata != null) {
          // Geçici fallback: eski OccupancyGrid.
          body = GcsMapView(data: _mapDataFromSavedPoints(agv));
        } else {
          final idleHint = mapping.liveMappingStatus == MappingStatus.idle ||
              mapping.mappingStatus == null;
          body = _workAreaPlaceholder(
            'HARİTA',
            Icons.map_outlined,
            mapping.awaitingFreshPreview
                ? 'Bağlandı — harita güncelleniyor…'
                : 'Harita önizlemesi bekleniyor…',
            mapping.isConnected
                ? (idleHint
                    ? 'Harita Oluştur ile mapping başlatın; '
                        'PNG /map_preview üzerinden gelecek.'
                    : 'Mapping çalışıyor — ilk PNG karesi bekleniyor.')
                : 'ROS bağlı değil',
            panelBg,
            borderC,
            muted,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Kopuk şeridi yok; metin merkez placeholder altında.
            if (mapping.isConnected || mapping.isConnecting)
              MappingConnectionBanner(model: mapping),
            MappingFieldBar(
              model: mapping,
              onFinishMapping: () => unawaited(_finishAndSaveMapping()),
              onCancelMapping: () => unawaited(_cancelMappingWithoutSave()),
            ),
            Expanded(child: body),
          ],
        );

      // ── Kamera (HTTP MJPEG; rosbridge kullanılmaz) ─────────────────────
      case 1:
        // Sekmeden çıkınca widget dispose olur → stream serbest bırakılır.
        return const MjpegCameraView();

      // ── LiDAR ──────────────────────────────────────────────────────────
      case 2:
        return _workAreaPlaceholder(
          'LiDAR',
          Icons.radar,
          'LiDAR verisi bekleniyor...',
          'Bu sekme ileride ROS 2 /scan konusuna bağlanacak.',
          panelBg,
          borderC,
          muted,
        );

      // ── 3D ─────────────────────────────────────────────────────────────
      case 3:
        return _workAreaPlaceholder(
          '3D',
          Icons.view_in_ar_rounded,
          '3D görünüm hazırlanıyor...',
          'Robotun 3 boyutlu URDF modeli buraya yüklenecek.',
          panelBg,
          borderC,
          muted,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  /// Henüz uygulanmamış sekmeler için tutarlı placeholder widget'ı.
  Widget _workAreaPlaceholder(
    String title,
    IconData icon,
    String mainMsg,
    String subMsg,
    Color panelBg,
    Color borderC,
    Color muted,
  ) {
    return Container(
      color: const Color(0xFF0D0D0D),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12.w, color: const Color(0xFF2A2A2A)),
            SizedBox(height: 2.h),
            Text(
              title,
              style: TextStyle(
                color: const Color(0xFF333333),
                fontSize: 5.sp,
                fontFamily: 'monospace',
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              mainMsg,
              style: TextStyle(color: muted, fontSize: 3.sp),
            ),
            if (subMsg.trim().isNotEmpty) ...[
              SizedBox(height: 0.8.h),
              Text(
                subMsg,
                style: TextStyle(
                  color: muted,
                  fontSize: 2.8.sp,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private UI helpers (controller_page only)
// ─────────────────────────────────────────────────────────────────────────────

/// Blueprint/radar ızgara deseni — harita alanının arka planı için.
/// Çizgi rengi #222222, arka plan #0D0D0D üzerinde soluk ve sade görünür.
class _GcsGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Küçük kareler (her 20 px) — daha soluk
    final thin = Paint()
      ..color = const Color(0xFF222222)
      ..strokeWidth = 0.5;
    // Büyük kareler (her 80 px) — biraz daha belirgin
    final thick = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..strokeWidth = 0.8;
    const smallStep = 20.0;
    const bigStep = 80.0;

    for (double x = 0; x <= size.width; x += smallStep) {
      final p = (x % bigStep == 0) ? thick : thin;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += smallStep) {
      final p = (y % bigStep == 0) ? thick : thin;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GcsGridPainter _) => false;
}

/// Küçük durum gösterge noktası (yeşil = aktif, kırmızı = pasif).
class _StatusDot extends StatelessWidget {
  final Color color;
  const _StatusDot(this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2.w,
      height: 2.w,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Telemetri veri kartı: ikon + etiket + monospace değer.
class _GcsTelCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Color panelBg;
  final Color borderC;
  final Color bright;
  final Color muted;

  const _GcsTelCard({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    required this.panelBg,
    required this.borderC,
    required this.bright,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: panelBg,
        border: Border.all(color: borderC, width: 0.5.w),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Row(
        children: [
          Icon(icon, color: muted, size: 5.sp),
          SizedBox(width: 1.5.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(
                        color: muted, fontSize: 2.5.sp, letterSpacing: 0.5)),
                SizedBox(height: 0.5.h),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? bright,
                    fontSize: 4.sp,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Özet şerit yardımcıları
// ─────────────────────────────────────────────────────────────────────────────

/// Özet kart içindeki tek bir satır için veri taşıyıcısı.
class _SRow {
  final String label;
  final String value;
  final Color? valueColor;
  final bool truncate;
  const _SRow(this.label, this.value, {this.valueColor, this.truncate = false});
}

/// 4-kart özet şeridinde kullanılan kompakt bilgi kartı.
class _SummaryCard extends StatelessWidget {
  final String title;
  final Color? titleColor;
  final List<_SRow> rows;
  final Widget? footer;
  final Color borderC;
  final Color muted;
  final Color bright;

  const _SummaryCard({
    required this.title,
    this.titleColor,
    required this.rows,
    this.footer,
    required this.borderC,
    required this.muted,
    required this.bright,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        border: Border.all(color: borderC, width: 0.4.w),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kart başlığı
          Text(
            title,
            style: TextStyle(
              color: titleColor ?? const Color(0xFF9E9E9E),
              fontSize: 2.5.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 0.8.h),
          // Satırlar
          ...rows.map((r) => Padding(
                padding: EdgeInsets.only(bottom: 0.5.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Etiket sütunu sabit genişlik
                    SizedBox(
                      width: 15.w,
                      child: Text(
                        r.label,
                        style: TextStyle(
                          color: muted,
                          fontSize: 2.4.sp,
                          letterSpacing: 0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 1.w),
                    // Değer sütunu esnek
                    Expanded(
                      child: Text(
                        r.value,
                        style: TextStyle(
                          color: r.valueColor ?? bright,
                          fontSize: 2.6.sp,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: r.truncate
                            ? TextOverflow.ellipsis
                            : TextOverflow.clip,
                        maxLines: r.truncate ? 1 : null,
                      ),
                    ),
                  ],
                ),
              )),
          if (footer != null) ...[
            SizedBox(height: 0.8.h),
            footer!,
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Görev ilerleme çubuğu
// ─────────────────────────────────────────────────────────────────────────────

/// Görevin 7 adımlık akışını yatay şerit olarak gösterir.
///
/// Tamamlanan adımlar ✓ ile, aktif adım parlak vurgulu, bekleyenler soluk görünür.
/// Hata/acil stop durumunda tüm şerit kırmızı uyarı moduna girer.
class _MissionProgressBar extends StatelessWidget {
  final GorevAsama asama;
  final Color bright;
  final Color muted;
  final Color success;
  final Color danger;

  static const List<String> _adimlar = [
    'Görev\nAlındı',
    'Yüksüz\nHareket',
    'Yük\nAlma',
    'Yüklü\nHareket',
    'Kapı\nİzni',
    'Yük\nBırakma',
    'Tamamlandı',
  ];

  const _MissionProgressBar({
    required this.asama,
    required this.bright,
    required this.muted,
    required this.success,
    required this.danger,
  });

  @override
  Widget build(BuildContext context) {
    final aktifIndex = asama.adimSirasi;
    final isError = asama.hataVeyaStop;
    final tamamlandi = asama == GorevAsama.tamamlandi;

    return Row(
      children: List.generate(_adimlar.length * 2 - 1, (i) {
        // Çift index → bağlantı çizgisi
        if (i.isOdd) {
          final stepIndex = (i + 1) ~/ 2;
          final lineActive =
              !isError && (tamamlandi || (aktifIndex >= stepIndex));
          return Expanded(
            child: Container(
              height: 0.4.h,
              color: lineActive ? success : const Color(0xFF333333),
            ),
          );
        }

        final stepIndex = i ~/ 2;
        final isDone = !isError && (tamamlandi || aktifIndex > stepIndex);
        final isActive = !isError && aktifIndex == stepIndex;
        final isWaiting = !isDone && !isActive;

        Color dotColor;
        Color textColor;

        if (isError) {
          dotColor = danger;
          textColor = stepIndex == aktifIndex ? danger : muted;
        } else if (isDone) {
          dotColor = success;
          textColor = success;
        } else if (isActive) {
          dotColor = bright;
          textColor = bright;
        } else {
          dotColor = const Color(0xFF333333);
          textColor = muted;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nokta veya ✓
            Container(
              width: 2.5.w,
              height: 2.5.w,
              decoration: BoxDecoration(
                color: isDone ? success : dotColor,
                shape: BoxShape.circle,
                border:
                    isActive ? Border.all(color: bright, width: 0.4.w) : null,
              ),
              child: isDone
                  ? Icon(Icons.check, size: 1.5.sp, color: Colors.black)
                  : isActive && isError
                      ? Icon(Icons.warning_amber,
                          size: 1.5.sp, color: Colors.white)
                      : null,
            ),
            SizedBox(height: 0.4.h),
            // Adım etiketi
            Text(
              isError && isActive
                  ? (asama == GorevAsama.acilStop ? 'Acil\nStop' : 'Hata')
                  : _adimlar[stepIndex],
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isWaiting ? const Color(0xFF555555) : textColor,
                fontSize: 1.8.sp,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                height: 1.2,
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// AppBar navigasyon butonu — yalın TextButton.
class _NavBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF9E9E9E),
        padding: EdgeInsets.symmetric(horizontal: 2.w),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 3.5.sp, fontWeight: FontWeight.w500, letterSpacing: 0.5),
      ),
    );
  }
}
