import 'dart:async';
import 'dart:math' as math;
import 'admin_mode.dart';
import 'data_model.dart';
import 'data_page.dart';
import 'models/agv_sensor_model.dart';
import 'models/gcs_alarm_model.dart';
import 'models/gcs_connection_model.dart';
import 'models/gcs_event_log_model.dart';
import 'models/gcs_mission_model.dart';
import 'mock/gcs_mock_data.dart';
import 'parameter_model.dart';
import 'scenerio_page.dart';
import 'services/agv_service.dart';
import 'services/ros_bridge_client.dart';
import 'services/ros_gcs_contract.dart';
import 'widgets/control_buttons.dart';
import 'models/gcs_map_model.dart';
import 'widgets/gcs_map_view.dart';
import 'widgets/live_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ControllerPage extends StatefulWidget {
  const ControllerPage({super.key});

  @override
  State<ControllerPage> createState() {
    return _ControllerPageState();
  }
}

class _ControllerPageState extends State<ControllerPage> {
  bool oto = false;
  bool lidarDurum = false;
  int speed = 0;
  String manuelOrOtonom = "Otonom";
  String _site = '';
  bool isConnected = false;
  String nextQR = "null";
  String _scenarioData = "";
  final FocusNode _focusNode = FocusNode();
  late ParameterModel parameterModel;
  late AgvSensorModel _agvModel;
  OccupancyGridMetadata? _mapMetadata;

  // Orta alan sekme indeksi: 0=Harita 1=Kamera 2=LiDAR 3=3D
  int _selectedWorkTab = 0;

  // Bağlantı paneli durumu ve IP giriş kontrolcüsü
  bool isConnectionPanelOpen = false;
  final TextEditingController _ipController = TextEditingController();
  String _lastRosStateLog = '';

  @override
  void initState() {
    super.initState();
    _agvModel = Provider.of<AgvSensorModel>(context, listen: false);
    parameterModel = Provider.of<ParameterModel>(context, listen: false);
    Provider.of<DataModel>(context, listen: false).loadDataPoints();
    parameterModel.loadParameters();
    _ipController.text = 'ws://localhost:9090';
    unawaited(_loadLastRosAddress());
    AgvService.ros.onRobotStatus = _applyRobotStatus;
    AgvService.ros.onMissionEvent = _onMissionEvent;
    AgvService.ros.onMapMetadata = _onMapMetadata;
    AgvService.ros.state.addListener(_onRosConnectionState);
    // GEÇİCİ admin/demo modu: cihaz yokken rapor için örnek veri bas.
    if (kAdminMode) {
      isConnected = true;
      nextQR = "QB3.1";
      GcsMockData.applyAll(
        agvModel: _agvModel,
        connModel: Provider.of<GcsConnectionModel>(context, listen: false),
        missionModel: Provider.of<GcsMissionModel>(context, listen: false),
        alarmModel: Provider.of<GcsAlarmModel>(context, listen: false),
        eventLogModel: Provider.of<GcsEventLogModel>(context, listen: false),
      );
    }
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
    final estop = status['estop_active'] == true;
    final obstacle = status['obstacle_detected'] == true;
    final plcConnected = status['plc_connected'] == true;
    final manualEnabled = status['manual_mode_enabled'] == true;
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
      manuelMod: manualEnabled,
      uzaktanKontrol: manualEnabled,
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
      oto = !manualEnabled;
      manuelOrOtonom = manualEnabled ? 'Manuel' : 'Otonom';
    });
  }

  void _onMissionEvent(String event) {
    if (!mounted) return;
    Provider.of<GcsEventLogModel>(context, listen: false).ekle(event);
  }

  void _onMapMetadata(OccupancyGridMetadata? metadata) {
    if (!mounted) return;
    final previous = _mapMetadata;
    setState(() => _mapMetadata = metadata);
    if (metadata != null &&
        (previous == null ||
            previous.resolution != metadata.resolution ||
            previous.width != metadata.width ||
            previous.height != metadata.height ||
            previous.originX != metadata.originX ||
            previous.originY != metadata.originY ||
            previous.originYaw != metadata.originYaw)) {
      _onMissionEvent(
        'Harita metadata: ${metadata.width}×${metadata.height}, '
        '${metadata.resolution} m/hücre, '
        'origin=(${metadata.originX}, ${metadata.originY}, '
        '${metadata.originYaw})',
      );
    }
  }

  void _onRosConnectionState() {
    if (!mounted) return;
    final rosState = AgvService.ros.state.value;
    final durum = switch (rosState.status) {
      RosConnectionStatus.connected => ConnDurum.bagli,
      RosConnectionStatus.connecting ||
      RosConnectionStatus.reconnecting =>
        ConnDurum.baglaniyor,
      RosConnectionStatus.error => ConnDurum.hata,
      RosConnectionStatus.disconnected => ConnDurum.cevrimdisi,
    };
    setState(() => isConnected = rosState.isConnected);
    _connModel.topluGuncelle(sistem: durum, robot: durum);
    final alarms = Provider.of<GcsAlarmModel>(context, listen: false);
    if (rosState.status == RosConnectionStatus.error) {
      alarms.setAlarm(AlarmTur.robotBaglantiHata,
          mesaj: rosState.message);
    } else if (rosState.status == RosConnectionStatus.connected) {
      alarms.clearAlarm(AlarmTur.robotBaglantiHata);
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

    AgvService.stopManual();
    if (!kAdminMode && AgvService.ros.state.value.isConnected) {
      try {
        final response = await AgvService.cancelMission();
        log.ekle(response['message']?.toString() ??
            'Yazılımsal güvenli durdurma istendi');
      } catch (error) {
        log.ekle('Güvenli durdurma gönderilemedi: $error');
      }
    } else {
      log.ekle('Manuel hareket durduruldu; ROS bağlı olmadığı için görev iptali gönderilmedi');
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
      _onMissionEvent(response['message']?.toString() ?? 'Safety reset yanıtı');
    } catch (error) {
      _onMissionEvent('Safety reset hatası: $error');
    }
  }

  void _manualDrive(double linear, double angular) {
    final sent = AgvService.publishManual(linear, angular);
    if (!sent) {
      _onMissionEvent(
          'Manuel hareket reddedildi: ROS bağlantısını ve fiziksel manuel modu kontrol edin');
    }
  }

  Future<void> veriBas(String veri) {
    if (_site.startsWith('ws://') || _site.startsWith('wss://')) {
      _onMissionEvent(
          'Komut gönderilmedi ($veri): bu eski buton için ROS karşılığı henüz tanımlı değil');
      return Future<void>.value();
    }
    return AgvService.veriBas(_site, veri);
  }

  Future<void> _navigateToScenarioPage(List<DataPoint> dataPoints) async {
    if (dataPoints.isEmpty && !kAdminMode) {
      return;
    } else {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScenarioPage(
              dataPoints: dataPoints, site: _site, rota: _scenarioData),
        ),
      );

      if (!mounted) return;
      if (result != null) {
        setState(() {
          _scenarioData = result;
        });
      }
    }
  }

  Future<void> _navigateToDataPage(String site) async {
    if (site.isEmpty && !kAdminMode) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DataPage(site: site)),
    );
  }

  @override
  void dispose() {
    AgvService.ros.state.removeListener(_onRosConnectionState);
    AgvService.ros.onRobotStatus = null;
    AgvService.ros.onMissionEvent = null;
    AgvService.ros.onMapMetadata = null;
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
    final eventLog = context.watch<GcsEventLogModel>();
    final dataPoints = context.watch<DataModel>().dataPoints;

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
              label: "HARİTA",
              onTap: () => Navigator.pushNamed(context, 'map-page')),
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
                                        text: "Haritalandır",
                                        assignedKey: LogicalKeyboardKey.keyM,
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: Text('Başlangıç Alanı',
                                                  style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 7.sp)),
                                              backgroundColor: Colors.grey,
                                              content: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceEvenly,
                                                children: [
                                                  Row(children: [
                                                    IconButton(
                                                      icon: Icon(
                                                          Icons.location_on,
                                                          color: Colors.black,
                                                          size: 7.sp),
                                                      onPressed: () {
                                                        Navigator.of(ctx).pop();
                                                        veriBas("k005");
                                                      },
                                                    ),
                                                    Text("S1",
                                                        style: TextStyle(
                                                            fontSize: 4.sp,
                                                            color:
                                                                Colors.black)),
                                                  ]),
                                                  Row(children: [
                                                    IconButton(
                                                      icon: Icon(
                                                          Icons.location_on,
                                                          color: Colors.black,
                                                          size: 7.sp),
                                                      onPressed: () {
                                                        Navigator.of(ctx).pop();
                                                        veriBas("k006");
                                                      },
                                                    ),
                                                    Text("S2",
                                                        style: TextStyle(
                                                            fontSize: 4.sp,
                                                            color:
                                                                Colors.black)),
                                                  ]),
                                                ],
                                              ),
                                            ),
                                          );
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
                                          veriBas("k312");
                                        },
                                      )),
                                      SizedBox(width: 1.5.w),
                                      Expanded(
                                          child: NormalButton(
                                        text: "Buzzer",
                                        assignedKey: LogicalKeyboardKey.keyB,
                                        onPressed: () {
                                          veriBas("k313");
                                        },
                                      )),
                                      SizedBox(width: 1.5.w),
                                      Expanded(
                                          child: NormalButton(
                                        text: "LiDAR A/K",
                                        assignedKey: LogicalKeyboardKey.keyV,
                                        onPressed: () {
                                          if (lidarDurum) {
                                            veriBas("k316");
                                            lidarDurum = false;
                                          } else {
                                            veriBas("k311");
                                            lidarDurum = true;
                                          }
                                        },
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
                                manuelOrOtonom,
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
                                      Text("FİZİKSEL MOD",
                                          style: TextStyle(
                                              color: muted,
                                              fontSize: 2.5.sp,
                                              letterSpacing: 0.5)),
                                      Text(
                                        conn.fizikselManuelMod
                                            ? 'Manuel'
                                            : 'Otomatik',
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
                        IgnorePointer(
                          ignoring: oto || !conn.robotBaglanti.aktif,
                          child: AnimatedOpacity(
                            opacity:
                                oto || !conn.robotBaglanti.aktif ? 0.35 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.all(2.w),
                                        decoration: _flatBox(panelBg, borderC),
                                        child: Column(
                                          children: [
                                            Text("LİFT",
                                                style: TextStyle(
                                                    color: muted,
                                                    fontSize: 3.sp,
                                                    letterSpacing: 1)),
                                            SizedBox(height: 2.h),
                                            ControlButton(
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
                                              onPressed:
                                                  _manualLiftUnavailable,
                                              onReleased: () {},
                                              assignedKey:
                                                  LogicalKeyboardKey.keyE,
                                              child: Icon(
                                                  Icons.arrow_downward_rounded,
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
                                        decoration: _flatBox(panelBg, borderC),
                                        child: Column(
                                          children: [
                                            Text("ARAÇ",
                                                style: TextStyle(
                                                    color: muted,
                                                    fontSize: 3.sp,
                                                    letterSpacing: 1)),
                                            SizedBox(height: 1.h),
                                            ControlButton(
                                              onPressed: () {
                                                _manualDrive(
                                                    (speed + 1) / 5, 0);
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
                                                  onPressed: () {
                                                    _manualDrive(
                                                        0, (speed + 1) / 5);
                                                  },
                                                  onReleased: () {
                                                    AgvService.stopManual();
                                                  },
                                                  assignedKey:
                                                      LogicalKeyboardKey.keyA,
                                                  child: Icon(Icons.arrow_left,
                                                      size: 7.sp),
                                                ),
                                                SizedBox(width: 8.w),
                                                ControlButton(
                                                  onPressed: () {
                                                    _manualDrive(
                                                        0, -(speed + 1) / 5);
                                                  },
                                                  onReleased: () {
                                                    AgvService.stopManual();
                                                  },
                                                  assignedKey:
                                                      LogicalKeyboardKey.keyD,
                                                  child: Icon(Icons.arrow_right,
                                                      size: 7.sp),
                                                ),
                                              ],
                                            ),
                                            ControlButton(
                                              onPressed: () {
                                                _manualDrive(
                                                    -(speed + 1) / 5, 0);
                                              },
                                              onReleased: () {
                                                AgvService.stopManual();
                                              },
                                              assignedKey:
                                                  LogicalKeyboardKey.keyS,
                                              child: Icon(Icons.arrow_drop_down,
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
                                        "HIZ: $speed",
                                        style: TextStyle(
                                          color: bright,
                                          fontSize: 3.sp,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      ExcludeSemantics(
                                        child: Slider(
                                          value: speed.toDouble(),
                                          divisions: 4,
                                          min: 0.0,
                                          max: 4,
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
                        ), // IgnorePointer
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

    final alarmColor = alarms.kritikAlarmVar
        ? danger
        : alarms.temiz
            ? success
            : const Color(0xFFFF9800);

    final rota = mission.rotaDugumleri.isNotEmpty
        ? mission.rotaDugumleri.join(' → ')
        : (mission.almaNoktasi.isNotEmpty || mission.birakNoktasi.isNotEmpty)
            ? '${safe(mission.almaNoktasi)} → ${safe(mission.birakNoktasi)}'
            : '--';

    final plcEtiket = conn.plcBaglanti.aktif
        ? 'Bağlı'
        : (conn.plcBaglanti == ConnDurum.baglaniyor
            ? 'Bağlanıyor'
            : safe(agv.plcDurum));

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
                  valueColor: conn.plcBaglanti.aktif ? success : danger),
              _SRow('KAPI İZNİ', mission.kapiIzni ? 'Serbest' : 'Kapalı',
                  valueColor: mission.kapiIzni ? success : muted),
              _SRow(
                  'GELEN',
                  safe(mission.sonOtomasyonMesaj.isNotEmpty
                      ? mission.sonOtomasyonMesaj
                      : agv.plcSonMesaj),
                  truncate: true),
              _SRow('GÖNDERİLEN', safe(mission.sonGonderilenMesaj),
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
            rows: [
              _SRow('POZ',
                  '${agv.currX.toStringAsFixed(2)}, ${agv.currY.toStringAsFixed(2)}'),
              _SRow('LOKAL', agv.lokalizasyonGecerli ? 'Geçerli' : 'Geçersiz',
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
            rows: [
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
                  valueColor:
                      alarms.isAktif(AlarmTur.acilStop) ? danger : success),
              _SRow('GÜV. DURUŞ', alarms.guvenliDurusAktif ? 'Aktif' : 'Normal',
                  valueColor: alarms.guvenliDurusAktif ? danger : success),
              _SRow(
                  'ALARM',
                  alarms.temiz
                      ? 'Yok'
                      : (alarms.aktifAlarmlar.isNotEmpty
                          ? alarms.aktifAlarmlar.first.tur.etiket
                          : 'Aktif'),
                  valueColor: alarms.temiz ? success : const Color(0xFFFF9800),
                  truncate: true),
              _SRow(
                  'KRİTİK',
                  alarms.kritikAlarmVar
                      ? (alarms.enKritik?.etiket ?? 'Var')
                      : 'Yok',
                  valueColor: alarms.kritikAlarmVar ? danger : success,
                  truncate: true),
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

  GcsMapData _mapDataFromSavedPoints(AgvSensorModel agv) {
    final metadata = _mapMetadata!;
    final dataPoints =
        Provider.of<DataModel>(context, listen: false).dataPoints;
    final mission = Provider.of<GcsMissionModel>(context, listen: false);
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
    final edge = agv.aktifRotaEdge.split('->');
    if (edge.length == 2) {
      final from = RosGcsContract.graphNodes[edge[0]];
      final to = RosGcsContract.graphNodes[edge[1]];
      if (from != null && to != null) {
        routes.add(MapRoute(
          id: agv.aktifRotaEdge,
          label: agv.aktifRotaEdge,
          waypoints: [from, to],
        ));
      }
    }
    return GcsMapData(
      robotX: agv.currX,
      robotY: agv.currY,
      robotYaw: agv.currYaw,
      points: points,
      routes: routes,
    );
  }

  /// Seçili sekmeye göre içerik döndürür.
  Widget _buildWorkAreaContent(
    AgvSensorModel agv,
    Color panelBg,
    Color borderC,
    Color muted,
    Color bright,
  ) {
    switch (_selectedWorkTab) {
      // ── Harita ─────────────────────────────────────────────────────────
      case 0:
        final metadata = _mapMetadata;
        if (metadata == null) {
          return _workAreaPlaceholder(
            'HARİTA',
            Icons.map_outlined,
            'ROS /map metadata bekleniyor...',
            'Noktalar resolution, origin, width ve height alınmadan '
                'dönüştürülmez.',
            panelBg,
            borderC,
            muted,
          );
        }
        final mapData = _mapDataFromSavedPoints(agv);
        return GcsMapView(data: mapData);

      // ── Kamera ─────────────────────────────────────────────────────────
      case 1:
        if (_site.startsWith('ws://') || _site.startsWith('wss://')) {
          return _workAreaPlaceholder(
            'KAMERA',
            Icons.videocam_outlined,
            'Kamera akışı henüz bağlı değil',
            'ROS görüntü topic veya HTTP kamera adresi netleşince bağlanacak.',
            panelBg,
            borderC,
            muted,
          );
        }
        return Container(
          color: const Color(0xFF0D0D0D),
          child: ClipRect(
            child: LiveMapFixedUrl(
              site: _site,
              poseFn: () => Pose(agv.currX, agv.currY, agv.currYaw),
              imagePath: '/get_image',
              interval: const Duration(milliseconds: 500),
            ),
          ),
        );

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
            SizedBox(height: 0.8.h),
            Text(
              subMsg,
              style: TextStyle(
                color: const Color(0xFF3A3A3A),
                fontSize: 2.5.sp,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
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
