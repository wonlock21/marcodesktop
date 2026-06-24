import 'dart:async';
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
import 'widgets/control_buttons.dart';
import 'models/gcs_map_model.dart';
import 'widgets/gcs_map_view.dart';
import 'widgets/live_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

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
  String manuelOrOtonom = "Manuel";
  String _site = '';
  bool isConnected = false;
  String nextQR = "null";
  String _scenarioData = "";
  final FocusNode _focusNode = FocusNode();
  late ParameterModel parameterModel;
  late AgvSensorModel _agvModel;

  // Orta alan sekme indeksi: 0=Harita 1=Kamera 2=LiDAR 3=3D
  int _selectedWorkTab = 0;

  // Bağlantı paneli durumu ve IP giriş kontrolcüsü
  bool isConnectionPanelOpen = false;
  final TextEditingController _ipController = TextEditingController();

  Timer? _poseTimer;
  Timer? _dataPollTimer;
  Timer? _connectionTimer;

  @override
  void initState() {
    super.initState();
    _agvModel = Provider.of<AgvSensorModel>(context, listen: false);
    parameterModel = Provider.of<ParameterModel>(context, listen: false);
    Provider.of<DataModel>(context, listen: false).loadDataPoints();
    parameterModel.loadParameters();
    // GEÇİCİ admin/demo modu: cihaz yokken rapor için örnek veri bas.
    if (kAdminMode) {
      isConnected = true;
      nextQR = "QB3.1";
      GcsMockData.applyAll(
        agvModel:      _agvModel,
        connModel:     Provider.of<GcsConnectionModel>(context, listen: false),
        missionModel:  Provider.of<GcsMissionModel>(context, listen: false),
        alarmModel:    Provider.of<GcsAlarmModel>(context, listen: false),
        eventLogModel: Provider.of<GcsEventLogModel>(context, listen: false),
      );
    }
    startConnectionCheck();
    _poseTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      final result = await AgvService.fetchPose(_site,
          fallbackX: _agvModel.currX,
          fallbackY: _agvModel.currY,
          fallbackYaw: _agvModel.currYaw);
      if (result != null && mounted) {
        _agvModel.updatePose(result.$1, result.$2, result.$3);
      }
    });
    _startPolling();
  }

  /// Telemetri polling döngüsünü başlatır.
  void _startPolling() {
    _runNextPoll();
  }

  /// Sequential polling: önceki döngü tamamlandıktan 1s sonra yenisi başlar.
  /// Timer.periodic yerine kullanılır — örtüşen async callback riski yok.
  Future<void> _runNextPoll() async {
    if (!mounted) return;

    // /telemetri endpoint'i varsa tek istekte tüm veriyi al
    final tel = await AgvService.fetchTelemetri(_site);

    if (tel != null && mounted) {
      final durum = tel['durum'];
      if (durum is String) _agvModel.updateRobotDurum(durum);

      final gorev = tel['gorev'];
      if (gorev is String) _agvModel.updateGorev(gorev);

      final lift = tel['lift'];
      final hiz  = (tel['hiz']  as num?)?.toDouble();
      if (lift is bool) _agvModel.updateLift(acik: lift, hiz: hiz);

      final batarya = (tel['batarya'] as num?)?.toDouble();
      if (batarya != null) _agvModel.updateBatarya(batarya);

      final plcDurum = tel['plcDurum'];
      final plcMesaj = tel['plcMesaj'] as String? ?? '';
      if (plcDurum is String) _agvModel.updatePlc(durum: plcDurum, mesaj: plcMesaj);

      final qrKonum = tel['qrKonum'];
      if (qrKonum is String && qrKonum.isNotEmpty) _agvModel.updateQrKonum(qrKonum);

      // Konum (opsiyonel — /pose timer'ı öncelikli, telemetri varsa override)
      final tx = (tel['x'] as num?)?.toDouble();
      final ty = (tel['y'] as num?)?.toDouble();
      final tyaw = (tel['yaw'] as num?)?.toDouble();
      if (tx != null && ty != null && mounted) {
        _agvModel.updatePose(tx, ty, tyaw ?? _agvModel.currYaw);
      }

      // Sensör (opsiyonel)
      final sicaklik = tel['sicaklik'] as String?;
      final voltaj   = tel['voltaj']   as String?;
      final akim     = tel['akim']     as String?;
      if (sicaklik != null && voltaj != null && akim != null && mounted) {
        _agvModel.updateSensor(
          sicaklik: sicaklik,
          voltage: voltaj,
          amper: akim,
        );
      }

      // QR (opsiyonel)
      final qr   = tel['qr']   as String?;
      final rfid = tel['rfid'] as String?;
      if (qr   != null && mounted) _agvModel.updateQR(qr);
      if (rfid != null && mounted) _agvModel.updateRfid(rfid);
    } else if (_site.isNotEmpty && mounted) {
      // Fallback: /telemetri yoksa eski endpoint'ler (sıralı, delay yok)
      imageCache.clearLiveImages();

      final qr = await AgvService.fetchQRData(_site);
      if (qr != null && mounted) _agvModel.updateQR(qr);

      final rfidVal = await AgvService.fetchRfid(_site);
      if (rfidVal != null && mounted) _agvModel.updateRfid(rfidVal);

      final sensorData = await AgvService.fetchSensorData(_site);
      if (sensorData != null && mounted) {
        _agvModel.updateSensor(
          sicaklik: sensorData.sicaklik,
          voltage: sensorData.voltage,
          amper: sensorData.amper,
        );
      }
    }

    // Önceki döngü bitti; 1s sonra bir sonraki başlasın
    if (mounted) {
      _dataPollTimer = Timer(const Duration(seconds: 1), _runNextPoll);
    }
  }

  void startConnectionCheck() {
    // GEÇİCİ admin/demo modu: gerçek bağlantı kontrolünü atla, "bağlı" göster.
    if (kAdminMode) return;
    _connectionTimer?.cancel();
    _connectionTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) async {
      final ok = await AgvService.checkConnection(_site);
      if (!mounted) return;
      setState(() { isConnected = ok; });
    });
  }
  Future<void> veriBas(String veri) => AgvService.veriBas(_site, veri);

  Future<void> startSendingData(String command, Duration duration) =>
      AgvService.startSendingData(_site, command, duration);

  Future<void> _navigateToScenarioPage(List<DataPoint> dataPoints) async {
    if (dataPoints.isEmpty && !kAdminMode){
      return;
    }
    else {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScenarioPage(dataPoints: dataPoints, site: _site, rota: _scenarioData),
          ),
        );


        if (!mounted) return;
        if (result != null) {
          setState(() { _scenarioData = result; });
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
    _poseTimer?.cancel();
    _dataPollTimer?.cancel();
    _connectionTimer?.cancel();
    _focusNode.dispose();
    _ipController.dispose();
    super.dispose();
  } 

  @override
  Widget build(BuildContext context) {
    final agv        = context.watch<AgvSensorModel>();
    final mission    = context.watch<GcsMissionModel>();
    final alarms     = context.watch<GcsAlarmModel>();
    final conn       = context.watch<GcsConnectionModel>();
    final eventLog   = context.watch<GcsEventLogModel>();
    final dataPoints = context.watch<DataModel>().dataPoints;

    const Color bg      = Color(0xFF121212);
    const Color panelBg = Color(0xFF1A1A1A);
    const Color borderC = Color(0xFF333333);
    const Color accent  = Color(0xFF1565C0);
    const Color muted   = Color(0xFF9E9E9E);
    const Color bright  = Color(0xFFE0E0E0);
    const Color success = Color(0xFF43A047);
    const Color danger  = Color(0xFFE53935);

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
                color: isConnected ? success : danger,
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
                _site.isEmpty ? "BAĞLI DEĞİL" : _site,
                style: TextStyle(color: muted, fontSize: 3.sp, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          _NavBtn(label: "BAĞLANTI", onTap: () {
            setState(() { isConnectionPanelOpen = !isConnectionPanelOpen; });
          }),
          _NavBtn(label: "ARAÇ 3D",   onTap: () => Navigator.pushNamed(context, '3d-page')),
          _NavBtn(label: "HARİTA",    onTap: () => Navigator.pushNamed(context, 'map-page')),
          _NavBtn(label: "QR LİSTE",  onTap: () => Navigator.pushNamed(context, 'QR-page')),
          _NavBtn(label: "VERİLER",   onTap: () => _navigateToDataPage(_site)),
          _NavBtn(label: "PARAMETRE", onTap: () => Navigator.pushNamed(context, 'parameter-page', arguments: _site)),
          SizedBox(width: 2.w),
        ],
      ),
      body: ExcludeSemantics(
        child: Focus(
        child: KeyboardListener(
          focusNode: _focusNode,
          onKeyEvent: (keyEvent) {
            if (keyEvent is KeyDownEvent) {
              if (keyEvent.logicalKey == LogicalKeyboardKey.keyO) {
                setState(() {
                  oto = !oto;
                  if (manuelOrOtonom == "Manuel") {
                    manuelOrOtonom = "Otonom";
                    veriBas("k300");
                  } else {
                    manuelOrOtonom = "Manuel";
                    veriBas("k310");
                  }
                });
              }
            }
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
                    ExcludeSemantics(child: CustomPaint(painter: _GcsGridPainter())),
                    // Row: bağlantı paneli (opsiyonel) + harita sütunu
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Bağlantı paneli — hard-cut (animasyonsuz)
                        if (isConnectionPanelOpen)
                          SizedBox(
                            width: 42.w,
                            child: _inlineConnectionPanel(panelBg, borderC, muted, bright, success, danger),
                          ),
                        Expanded(
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        // ── Özet Bilgi Şeridi ─────────────────────
                        _buildSummaryStrip(
                          mission, alarms, agv, conn,
                          panelBg, borderC, muted, bright, success, danger,
                        ),
                        // ── Sekme çubuğu ──────────────────────────────
                        _buildWorkTabBar(panelBg, borderC),
                        // ── Sekme içeriği ──────────────────────────────
                        Expanded(
                          flex: 8,
                          child: _buildWorkAreaContent(
                            agv, panelBg, borderC, muted, bright,
                          ),
                        ),
                        // ── Olay günlüğü ──────────────────────────────
                        Flexible(
                          flex: 2,
                          child: _buildEventLogPanel(
                            eventLog, panelBg, borderC, muted, bright,
                          ),
                        ),
                        // Alt buton şeridi
                        Container(
                          color: panelBg,
                          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              PowerButton(onPressed: () { veriBas("k315"); }),
                              SizedBox(width: 2.w),
                              Expanded(child: NormalButton(
                                text: "Haritalandır",
                                assignedKey: LogicalKeyboardKey.keyM,
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text('Başlangıç Alanı',
                                          style: TextStyle(color: Colors.black, fontSize: 7.sp)),
                                      backgroundColor: Colors.grey,
                                      content: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Row(children: [
                                            IconButton(
                                              icon: Icon(Icons.location_on, color: Colors.black, size: 7.sp),
                                              onPressed: () { Navigator.of(ctx).pop(); veriBas("k005"); },
                                            ),
                                            Text("S1", style: TextStyle(fontSize: 4.sp, color: Colors.black)),
                                          ]),
                                          Row(children: [
                                            IconButton(
                                              icon: Icon(Icons.location_on, color: Colors.black, size: 7.sp),
                                              onPressed: () { Navigator.of(ctx).pop(); veriBas("k006"); },
                                            ),
                                            Text("S2", style: TextStyle(fontSize: 4.sp, color: Colors.black)),
                                          ]),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )),
                              SizedBox(width: 1.5.w),
                              Expanded(child: NormalButton(
                                text: "Senaryo",
                                assignedKey: LogicalKeyboardKey.keyN,
                                onPressed: () async { await _navigateToScenarioPage(dataPoints); },
                              )),
                              SizedBox(width: 1.5.w),
                              Expanded(child: NormalButton(
                                text: "Led",
                                assignedKey: LogicalKeyboardKey.keyL,
                                onPressed: () { veriBas("k312"); },
                              )),
                              SizedBox(width: 1.5.w),
                              Expanded(child: NormalButton(
                                text: "Buzzer",
                                assignedKey: LogicalKeyboardKey.keyB,
                                onPressed: () { veriBas("k313"); },
                              )),
                              SizedBox(width: 1.5.w),
                              Expanded(child: NormalButton(
                                text: "Lidar A/K",
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
                          ],  // closes Column.children
                        ),    // closes Column
                        ),    // closes Expanded(child: Column)
                      ],      // closes Row.children
                    ),        // closes Row
                  ],          // closes Stack.children
                ),            // closes Stack
              ),              // closes Expanded(flex: 7)
              // Dikey ayraç
              Container(width: 0.3.w, color: borderC),
              // ──────── RIGHT: Telemetri + Kontroller (flex 3) ────────────
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 2.h),
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
                              isConnected ? 'AKTİF' : 'PASİF',
                              isConnected ? success : danger,
                              muted, bright,
                            ),
                            SizedBox(height: 0.8.h),
                            _statusRow(
                              'MOD',
                              kAdminMode && !isConnected
                                  ? 'ADMIN / DEMO'
                                  : (kAdminMode ? 'DEMO' : 'CANLI'),
                              kAdminMode ? const Color(0xFFFF9800) : bright,
                              muted, bright,
                            ),
                            SizedBox(height: 0.8.h),
                            _statusRow(
                              'ÇALIŞMA MODU',
                              manuelOrOtonom,
                              oto ? accent : bright,
                              muted, bright,
                            ),
                            SizedBox(height: 0.8.h),
                            _statusRow(
                              'KOMUT GÖNDERİM',
                              _komutDurumu(isConnected, conn.uzaktanKontrolAktif),
                              _komutRenk(isConnected, conn.uzaktanKontrolAktif, success, muted, danger),
                              muted, bright,
                            ),
                            SizedBox(height: 0.8.h),
                            Row(children: [
                              _StatusDot(conn.plcBaglanti.aktif ? success : muted),
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
                        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Expanded(child: _GcsTelCard(
                            icon: Icons.battery_full, label: "GÜÇ",
                            value: "${agv.bataryaYuzde.toStringAsFixed(0)}%",
                            valueColor: _battColor(agv.bataryaYuzde),
                            panelBg: panelBg, borderC: borderC, bright: bright, muted: muted,
                          )),
                          SizedBox(width: 1.5.w),
                          Expanded(child: _GcsTelCard(
                            icon: Icons.thermostat, label: "SICAKLIK",
                            value: safe(agv.sicaklik) == '--' ? '--' : "${safe(agv.sicaklik)}°C",
                            panelBg: panelBg, borderC: borderC, bright: bright, muted: muted,
                          )),
                        ]),
                      ),
                      SizedBox(height: 1.5.h),
                      IntrinsicHeight(
                        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Expanded(child: _GcsTelCard(
                            icon: Icons.electric_bolt, label: "AKIM",
                            value: safe(agv.amper) == '--' ? '--' : "${safe(agv.amper)} A",
                            panelBg: panelBg, borderC: borderC, bright: bright, muted: muted,
                          )),
                          SizedBox(width: 1.5.w),
                          Expanded(child: _GcsTelCard(
                            icon: Icons.electric_meter, label: "VOLTAJ",
                            value: safe(agv.voltage) == '--' ? '--' : "${safe(agv.voltage)} V",
                            panelBg: panelBg, borderC: borderC, bright: bright, muted: muted,
                          )),
                        ]),
                      ),
                      SizedBox(height: 1.5.h),
                      IntrinsicHeight(
                        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Expanded(child: _GcsTelCard(
                            icon: Icons.speed, label: "HIZ",
                            value: "${agv.anlikHiz.toStringAsFixed(2)} m/s",
                            panelBg: panelBg, borderC: borderC, bright: bright, muted: muted,
                          )),
                          SizedBox(width: 1.5.w),
                          Expanded(child: _GcsTelCard(
                            icon: Icons.location_on, label: "KONUM",
                            value: "(${agv.currX.toStringAsFixed(1)}, ${agv.currY.toStringAsFixed(1)})",
                            panelBg: panelBg, borderC: borderC, bright: bright, muted: muted,
                          )),
                        ]),
                      ),
                      SizedBox(height: 1.5.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
                        decoration: _flatBox(panelBg, borderC),
                        child: Row(children: [
                          Icon(Icons.timelapse, color: muted, size: 5.sp),
                          SizedBox(width: 2.w),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("GÖREV SÜRESİ",
                                  style: TextStyle(color: muted, fontSize: 2.5.sp, letterSpacing: 0.5)),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("FİZİKSEL MOD",
                                        style: TextStyle(color: muted, fontSize: 2.5.sp, letterSpacing: 0.5)),
                                    Text(
                                      conn.fizikselManuelMod ? 'Manuel' : 'Otomatik',
                                      style: TextStyle(
                                        color: conn.fizikselManuelMod ? bright : accent,
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
                                        onChanged: (val) {
                                          setState(() {
                                            oto = val;
                                            if (manuelOrOtonom == "Manuel") {
                                              manuelOrOtonom = "Otonom";
                                              startSendingData("k300", const Duration(milliseconds: 500));
                                            } else {
                                              manuelOrOtonom = "Manuel";
                                              startSendingData("k310", const Duration(milliseconds: 500));
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 1.2.h),
                            _statusRow(
                              'UZAKTAN KONTROL',
                              conn.uzaktanKontrolAktif ? 'Aktif' : 'Kilitli',
                              conn.uzaktanKontrolAktif ? success : danger,
                              muted, bright,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 2.h),
                      // ── Manuel Kontroller ─────────────────────────
                      _sectionLabel("MANUEL KONTROLLER"),
                      SizedBox(height: 1.h),
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
                                          color: muted, fontSize: 3.sp, letterSpacing: 1)),
                                  SizedBox(height: 2.h),
                                  ControlButton(
                                    onPressed: () { veriBas("k802"); },
                                    onReleased: () { veriBas("k801"); },
                                    assignedKey: LogicalKeyboardKey.keyQ,
                                    child: Icon(Icons.arrow_upward_rounded, size: 7.sp),
                                  ),
                                  SizedBox(height: 3.h),
                                  ControlButton(
                                    onPressed: () { veriBas("k800"); },
                                    onReleased: () { veriBas("k801"); },
                                    assignedKey: LogicalKeyboardKey.keyE,
                                    child: Icon(Icons.arrow_downward_rounded, size: 7.sp),
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
                                          color: muted, fontSize: 3.sp, letterSpacing: 1)),
                                  SizedBox(height: 1.h),
                                  ControlButton(
                                    onPressed: () { veriBas("k94${4 - speed}"); },
                                    onReleased: () { veriBas("k944"); },
                                    assignedKey: LogicalKeyboardKey.keyW,
                                    child: Icon(Icons.arrow_drop_up, size: 7.sp),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ControlButton(
                                        onPressed: () { veriBas("k9${4 - speed}4"); },
                                        onReleased: () { veriBas("k944"); },
                                        assignedKey: LogicalKeyboardKey.keyA,
                                        child: Icon(Icons.arrow_left, size: 7.sp),
                                      ),
                                      SizedBox(width: 8.w),
                                      ControlButton(
                                        onPressed: () { veriBas("k9${4 + speed}4"); },
                                        onReleased: () { veriBas("k944"); },
                                        assignedKey: LogicalKeyboardKey.keyD,
                                        child: Icon(Icons.arrow_right, size: 7.sp),
                                      ),
                                    ],
                                  ),
                                  ControlButton(
                                    onPressed: () { veriBas("k94${4 + speed}"); },
                                    onReleased: () { veriBas("k944"); },
                                    assignedKey: LogicalKeyboardKey.keyS,
                                    child: Icon(Icons.arrow_drop_down, size: 7.sp),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 1.5.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
                        decoration: _flatBox(panelBg, borderC),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                  setState(() { speed = val.toInt(); });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 3.h),
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
    Color panelBg, Color borderC, Color muted, Color bright, Color success, Color danger,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        border: Border(right: BorderSide(color: borderC, width: 0.3.w)),
      ),
      padding: EdgeInsets.all(3.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Başlık + kapat
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("BAĞLANTI",
                style: TextStyle(
                  color: muted, fontSize: 3.sp,
                  fontWeight: FontWeight.bold, letterSpacing: 1.5,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() { isConnectionPanelOpen = false; }),
                child: Icon(Icons.close, color: muted, size: 5.sp),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          // Mevcut bağlantı durumu
          Row(children: [
            Container(
              width: 2.w, height: 2.w,
              decoration: BoxDecoration(
                color: isConnected ? success : danger,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 1.5.w),
            Expanded(
              child: Text(
                isConnected ? "Bağlı: $_site" : "Bağlı değil",
                style: TextStyle(
                  color: muted, fontSize: 2.5.sp, fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          SizedBox(height: 3.h),
          // IP giriş alanı
          Text("IP Adresi",
            style: TextStyle(color: muted, fontSize: 2.8.sp, letterSpacing: 0.5)),
          SizedBox(height: 1.h),
          TextField(
            controller: _ipController,
            style: TextStyle(
              color: bright, fontSize: 3.5.sp, fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF111111),
              hintText: 'http://192.168.x.x:5000',
              hintStyle: TextStyle(
                color: const Color(0xFF444444), fontSize: 3.sp, fontFamily: 'monospace',
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.5.h),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: borderC, width: 0.5.w),
                borderRadius: BorderRadius.circular(4.r),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: const Color(0xFF1565C0), width: 0.7.w),
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
          ),
          SizedBox(height: 3.h),
          // Bağlan butonu
          GestureDetector(
            onTap: () {
              final ip = _ipController.text.trim();
              if (ip.isEmpty) return;
              setState(() {
                _site = ip;
                isConnectionPanelOpen = false;
              });
              startConnectionCheck();
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 1.5.h),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2540),
                border: Border.all(color: const Color(0xFF1565C0), width: 0.5.w),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link, color: const Color(0xFF42A5F5), size: 4.sp),
                    SizedBox(width: 1.w),
                    Text("BAĞLAN",
                      style: TextStyle(
                        color: const Color(0xFF42A5F5),
                        fontSize: 3.5.sp,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ── Özet Bilgi Şeridi ──────────────────────────────────────────────────────
  Widget _buildSummaryStrip(
    GcsMissionModel mission,
    GcsAlarmModel   alarms,
    AgvSensorModel  agv,
    GcsConnectionModel conn,
    Color panelBg, Color borderC,
    Color muted,   Color bright,
    Color success, Color danger,
  ) {
    String safe(String v) => (v.isEmpty || v == 'null') ? '--' : v;

    final alarmColor = alarms.kritikAlarmVar
        ? danger
        : alarms.temiz
            ? success
            : const Color(0xFFFF9800);

    final rota = (mission.almaNoktasi.isNotEmpty || mission.birakNoktasi.isNotEmpty)
        ? '${safe(mission.almaNoktasi)} → ${safe(mission.birakNoktasi)}'
        : '--';

    final plcEtiket = conn.plcBaglanti.aktif
        ? 'Bağlı'
        : (conn.plcBaglanti == ConnDurum.baglaniyor ? 'Bağlanıyor' : safe(agv.plcDurum));

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
          Expanded(child: _SummaryCard(
            title: 'GÖREV ÖZETİ',
            borderC: borderC, muted: muted, bright: bright,
            rows: [
              _SRow('ID',    safe(mission.gorevId)),
              _SRow('ROTA',  rota, truncate: true),
              _SRow('AŞAMA', mission.asama.etiket, truncate: true),
              _SRow('SONRAKİ', mission.asama.sonrakiAdim, truncate: true),
              _SRow('SÜRE',  mission.gorevAktif ? mission.gorevSuresiFormatli : '--'),
            ],
          )),
          SizedBox(width: 1.5.w),

          // ── Kart 2: Fabrika Otomasyon Özeti ───────────────────────────────
          Expanded(child: _SummaryCard(
            title: 'FABRİKA OTOMASYON',
            borderC: borderC, muted: muted, bright: bright,
            rows: [
              _SRow('PLC',
                  plcEtiket,
                  valueColor: conn.plcBaglanti.aktif ? success : danger),
              _SRow('KAPI İZNİ',
                  mission.kapiIzni ? 'Serbest' : 'Kapalı',
                  valueColor: mission.kapiIzni ? success : muted),
              _SRow('GELEN',
                  safe(mission.sonOtomasyonMesaj.isNotEmpty
                      ? mission.sonOtomasyonMesaj
                      : agv.plcSonMesaj),
                  truncate: true),
              _SRow('GÖNDERİLEN', safe(mission.sonGonderilenMesaj), truncate: true),
            ],
          )),
          SizedBox(width: 1.5.w),

          // ── Kart 3: Konum Doğrulama ───────────────────────────────────────
          Expanded(child: _SummaryCard(
            title: 'KONUM DOĞRULAMA',
            borderC: borderC, muted: muted, bright: bright,
            rows: [
              _SRow('SON QR', safe(agv.sonQR)),
              _SRow('QR DOĞR.',
                  safe(agv.qrDogrulama),
                  valueColor: agv.qrDogrulama == 'Geçerli' ? success : null),
              _SRow('KONUM',
                  safe(agv.konumDogrulamaSonucu),
                  valueColor: agv.konumDogrulamaSonucu == 'Onaylandı' ? success : null),
              _SRow('KON. HATA', safe(agv.konumHatasi)),
              _SRow('YÖN HATA', safe(agv.yonHatasi)),
            ],
          )),
          SizedBox(width: 1.5.w),

          // ── Kart 4: Güvenlik Özeti ────────────────────────────────────────
          Expanded(child: _SummaryCard(
            title: 'GÜVENLİK',
            titleColor: alarmColor,
            borderC: borderC, muted: muted, bright: bright,
            rows: [
              _SRow('ACİL STOP',
                  alarms.isAktif(AlarmTur.acilStop) ? 'AKTİF' : 'Normal',
                  valueColor: alarms.isAktif(AlarmTur.acilStop) ? danger : success),
              _SRow('ALARM',
                  alarms.temiz ? 'Temiz' : '${alarms.aktifAlarmlar.length} Aktif',
                  valueColor: alarms.temiz ? success : const Color(0xFFFF9800)),
              _SRow('GÜV. DURUŞ',
                  alarms.guvenliDurusAktif ? 'Aktif' : 'Normal',
                  valueColor: alarms.guvenliDurusAktif ? danger : muted),
              _SRow('KRİTİK',
                  alarms.kritikAlarmVar
                      ? (alarms.enKritik?.etiket ?? 'Var')
                      : 'Yok',
                  valueColor: alarms.kritikAlarmVar ? danger : muted,
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
            style: TextStyle(color: muted, fontSize: 2.4.sp, letterSpacing: 0.3),
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
    if (kAdminMode) return 'Simülasyon';
    if (!connected || !uzaktanAktif) return 'Pasif';
    return 'Aktif';
  }

  Color _komutRenk(
    bool connected,
    bool uzaktanAktif,
    Color success,
    Color muted,
    Color danger,
  ) {
    if (kAdminMode) return const Color(0xFFFF9800);
    if (!connected || !uzaktanAktif) return danger;
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
                    color: selected
                        ? const Color(0xFF1565C0)
                        : Colors.transparent,
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
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          );
        }),
      ),
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
        final mapData = GcsMapData.mock(
          robotX:   agv.currX,
          robotY:   agv.currY,
          robotYaw: agv.currYaw,
        );
        return GcsMapView(data: mapData);

      // ── Kamera ─────────────────────────────────────────────────────────
      case 1:
        return Container(
          color: const Color(0xFF0D0D0D),
          child: ClipRect(
            child: LiveMapFixedUrl(
              site:      _site,
              poseFn:    () => Pose(agv.currX, agv.currY, agv.currYaw),
              imagePath: '/get_image',
              interval:  const Duration(milliseconds: 500),
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
          panelBg, borderC, muted,
        );

      // ── 3D ─────────────────────────────────────────────────────────────
      case 3:
        return _workAreaPlaceholder(
          '3D',
          Icons.view_in_ar_rounded,
          '3D görünüm hazırlanıyor...',
          'Robotun 3 boyutlu URDF modeli buraya yüklenecek.',
          panelBg, borderC, muted,
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
    const bigStep   = 80.0;

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
  final bool   truncate;
  const _SRow(this.label, this.value,
      {this.valueColor, this.truncate = false});
}

/// 4-kart özet şeridinde kullanılan kompakt bilgi kartı.
class _SummaryCard extends StatelessWidget {
  final String      title;
  final Color?      titleColor;
  final List<_SRow> rows;
  final Color       borderC;
  final Color       muted;
  final Color       bright;

  const _SummaryCard({
    required this.title,
    this.titleColor,
    required this.rows,
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
        ],
      ),
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
            fontSize: 3.5.sp,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5),
      ),
    );
  }
}
