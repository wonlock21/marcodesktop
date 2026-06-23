import 'dart:async';
import 'admin_mode.dart';
import 'data_model.dart';
import 'data_page.dart';
import 'models/agv_sensor_model.dart';
import 'parameter_model.dart';
import 'scenerio_page.dart';
import 'services/agv_service.dart';
import 'widgets/control_buttons.dart';
import 'widgets/live_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'timer.dart';

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
      _agvModel.loadDemoData();
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
    super.dispose();
  } 

  @override
  Widget build(BuildContext context) {
    final agv = context.watch<AgvSensorModel>();
    final dataPoints = context.watch<DataModel>().dataPoints;
    return Scaffold(
      appBar: AppBar(
          title: const Text("AGV-LiftAnt"),
          foregroundColor: Colors.black,
          surfaceTintColor: Colors.black,
          actions: [
            const Spacer(),
            TextButton(
              onPressed: () async {
                final result = await Navigator.pushNamed(context, 'connection-page');
                if (!mounted) return;
                if (result != null) {
                  setState(() { _site = result as String; });
                } else {
                  setState(() {});
                }
              },
              child: Text(
                "BAĞLANTI",
                style: TextStyle(
                  color: const Color.fromARGB(255, 255, 255, 255),
                  fontSize: 5.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '3d-page'),
              child: Text(
                "ARAÇ 3D",
                style: TextStyle(
                    color: const Color.fromARGB(255, 255, 255, 255),
                    fontSize: 5.sp,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, 'map-page'),
              child: Text(
                "HARİTA", //"GİRİLEN HARİTA",
                style: TextStyle(
                    color: const Color.fromARGB(255, 255, 255, 255),
                    fontSize: 5.sp,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, 'QR-page'),
              child: Text(
                "QR KOD LİSTESİ",//"QR KOD LİSTESİ",
                style: TextStyle(
                    color: const Color.fromARGB(255, 255, 255, 255),
                    fontSize: 5.sp,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _navigateToDataPage(_site),
              child: Text(
                "VERİLER",
                style: TextStyle(
                    color: const Color.fromARGB(255, 255, 255, 255), fontSize: 5.sp, fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, 'parameter-page', arguments : _site),
              child: Text(
                "PARAMETRE",
                style: TextStyle(
                    color: const Color.fromARGB(255, 255, 255, 255), fontSize: 5.sp, fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
          ]),
      body: Focus(
        child: KeyboardListener(
          focusNode: _focusNode,
          onKeyEvent: (keyEvent) {
            if (keyEvent is KeyDownEvent) {
              if (keyEvent.logicalKey == LogicalKeyboardKey.keyO) {
                setState(() {
                  oto = !oto; // Switch'in değerini değiştir
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
          child: Padding(
            padding: EdgeInsets.symmetric( horizontal: 2.w, vertical: 5.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Column(
                    children: [
                      SizedBox(
                        height: 550.h,
                        width: 260.w,
                        child: LiveMapFixedUrl(
                          site: _site, // "http://IP:5000"
                          poseFn: () => Pose(agv.currX, agv.currY, agv.currYaw),
                          imagePath: "/get_image",
                          interval: const Duration(milliseconds: 500), // ihtiyaca göre 200–1000ms
                        ),
                      ),
                      SizedBox(
                        width: 80.w,
                      ),
                      SizedBox(
                        height: 10.h,
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Column(   
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PowerButton(onPressed: () {veriBas("k315");},),
                                SizedBox(height: 30.h,)
                              ],
                            ),
                            SizedBox(
                              width: 5.w,
                            ),
                            Column(
                              children: [
                                NormalButton(
                                  text: "Haritalandır",
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: Text('Hangi Başlangıç Alanı?', style: TextStyle(color: Colors.black, fontSize: 7.sp),),
                                          backgroundColor: Colors.grey,
                                          content: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: [
                                              Row(
                                                children: [
                                                  IconButton(
                                                    icon: Icon(Icons.location_on, color: Colors.black, size: 7.sp),
                                                    onPressed: () {
                                                      Navigator.of(context).pop(); // Popup'u kapat
                                                      veriBas("k005");      
                                                    },
                                                  ),
                                                  Text("S1", style: TextStyle(fontSize: 4.sp, color: Colors.black),)
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  IconButton(
                                                    icon: Icon(Icons.location_on, color: Colors.black, size: 7.sp),
                                                    onPressed: () {
                                                      Navigator.of(context).pop(); // Popup'u kapat   
                                                      veriBas("k006");
                                                    },
                                                  ),
                                                  Text("S2", style: TextStyle(fontSize: 4.sp, color: Colors.black),)
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  assignedKey: LogicalKeyboardKey.keyM,
                                ),
                                SizedBox(
                                  height: 20.h,
                                ),
                                NormalButton(
                                  text: "Senaryo",
                                  assignedKey: LogicalKeyboardKey.keyN,
                                  onPressed: () async {
                                    await _navigateToScenarioPage(dataPoints);
                                    /*if(_scenarioData != ""){
                                      veriBas("v$_scenarioData");
                                    }*/
                                  },
                                ),
                              ],
                            ),
                            SizedBox(
                              width: 5.w,
                            ),
                            Column(
                              children: [
                                NormalButton(
                                  text: "Led",
                                  onPressed: () {veriBas("k312");},
                                  assignedKey: LogicalKeyboardKey.keyL,
                                ),
                                SizedBox(
                                  height: 20.h,
                                ),
                                NormalButton(
                                  text: "Buzzer",
                                  onPressed: () {veriBas("k313");},
                                  assignedKey: LogicalKeyboardKey.keyB,
                                ),
                              ],
                            ),
                            SizedBox(
                              width: 5.w,
                            ),
                            Column(
                              children: [
                                NormalButton(
                                  text: "Lidar A/K", //311 aç 316 kapat
                                  onPressed: () {
                                    if(lidarDurum)
                                    {
                                      veriBas("k316");
                                      lidarDurum = false;
                                    }
                                    else{
                                     veriBas("k311");
                                     lidarDurum = true; 
                                    }
                                  
                                    },
                                    assignedKey: LogicalKeyboardKey.keyV,
                                ),
                                SizedBox(
                                  height: 35.h,
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox( 
                                      width: 60.w, 
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "Hız:$speed",
                                            textScaler: TextScaler.noScaling,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 40.w,
                                            height: 40.h,
                                            child: FittedBox(
                                              fit: BoxFit.fill,
                                              child: Slider(
                                                value: speed.toDouble(),
                                                divisions: 4,
                                                min: 0.0,
                                                max: 4,
                                                activeColor: const Color.fromARGB(255, 27, 141, 255),
                                                inactiveColor: const Color.fromARGB(255, 207, 245, 255),
                                                label: speed.round().toString(),
                                                onChanged: (val) {
                                                  setState(() {
                                                    speed = val.toInt();
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 30.h,),
                      SizedBox(
                        width: 300.w,
                        height: 450.h,
                        child: Column(
                          children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 60.w,
                                      height: 80.h,
                                      child: Card(
                                        shape: RoundedRectangleBorder(
                                            side: BorderSide(
                                                color: Colors.blue, width: 1.w),
                                            borderRadius: BorderRadius.circular(10)),
                                        color: Colors.transparent,
                                        child: Center(
                                          child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            //Icon(Icons.directions_car, color: Colors.blue, size: 45,),
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                    "Durum",
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 4.sp,
                                                        fontWeight: FontWeight.bold),
                                                ),
                                                SizedBox(
                                                  width: 50.w,
                                                ),
                                                Text(
                                                  isConnected.toString(),
                                                  style: TextStyle(
                                                      color: Colors.blue,
                                                      fontSize: 5.sp),
                                                )
                                              ],
                                            ),
                                          ],
                                        )),
                                      ),
                                    ),
                                    SizedBox(width: 1.w,),
                                    SizedBox(
                                      width: 60.w,
                                      height: 80.h,
                                      child: Card(
                                        shape: RoundedRectangleBorder(
                                            side:  BorderSide(
                                                color: Colors.blue, width: 1.w),
                                            borderRadius: BorderRadius.circular(10)),
                                        color: Colors.transparent,
                                        child:  Center(
                                         child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            SizedBox(width: 1.w,),
                                            Icon(
                                              Icons.timelapse,
                                              color: Colors.blue,
                                              size: 13.sp,
                                            ),
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                    "Görev Süresi",
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 4.sp,
                                                        fontWeight: FontWeight.bold),
                                                ),
                                                SizedBox(width: 28.w,),
                                                const TimerPage(),
                                              ],
                                            ),
                                            SizedBox(width: 3.w,)
                                          ],
                                        )),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    SizedBox(
                                      width: 60.w,
                                      height: 80.h,
                                      child: Card(
                                        shape: RoundedRectangleBorder(
                                            side:  BorderSide(
                                                color: Colors.blue, width: 1.w),
                                            borderRadius: BorderRadius.circular(10)),
                                        color: Colors.transparent,
                                        child: Center(
                                            child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            Icon(
                                              Icons.battery_saver,
                                              color: Colors.blue,
                                              size: 13.sp,
                                            ),
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                    "Güç Seviyesi",
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 4.sp,
                                                        fontWeight: FontWeight.bold),
                                                ),
                                                Text(
                                                  "%69",
                                                  style: TextStyle(
                                                      color: Colors.blue,
                                                      fontSize: 5.sp),
                                                )
                                              ],
                                            ),
                                            SizedBox(
                                              width: 3.w,
                                            )
                                          ],
                                        )),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 60.w,
                                      height: 80.h,
                                      child: Card(
                                        shape: RoundedRectangleBorder(
                                            side: BorderSide(
                                                color: Colors.blue, width: 1.w),
                                            borderRadius: BorderRadius.circular(10)),
                                        color: Colors.transparent,
                                        child: Center(
                                            child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            Icon(
                                              Icons.thermostat,
                                              color: Colors.blue,
                                              size: 13.sp,
                                            ),
                                            
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                    "Sıcaklık",
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 4.sp,
                                                        fontWeight: FontWeight.bold),
                                                ),
                                                SizedBox(width: 18.w,),
                                                Text(
                                                  agv.sicaklik,
                                                  style: TextStyle(
                                                      color: Colors.blue,
                                                      fontSize: 5.sp),
                                                )
                                              ],
                                            ),
                                            SizedBox(
                                              width: 3.w,
                                            )
                                          ],
                                        )),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    SizedBox(
                                      width: 60.w,
                                      height: 80.h,
                                      child: Card(
                                        shape: RoundedRectangleBorder(
                                            side:  BorderSide(
                                                color: Colors.blue, width: 1.w),
                                            borderRadius: BorderRadius.circular(10)),
                                        color: Colors.transparent,
                                        child: Center(
                                            child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: [
                                            Icon(
                                              Icons.electric_bolt,
                                              color: Colors.blue,
                                              size: 13.sp,
                                             ),
                                            Column(
                                              mainAxisAlignment:MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                    "Amper",
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 5.sp,
                                                        fontWeight: FontWeight.bold),
                                                ),
                                               SizedBox(width: 20.w,),
                                               Text(
                                                  "",
                                                  style: TextStyle(
                                                      color: Colors.blue,
                                                      fontSize: 3.sp),
                                                )
                                              ],
                                            ),
                                            SizedBox(
                                              width: 3.w,
                                            )
                                          ],
                                        )),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 60.w,
                                      height: 80.h,
                                      child: Card(
                                        shape: RoundedRectangleBorder(
                                            side: BorderSide(
                                                color: Colors.blue, width: 1.w),
                                            borderRadius: BorderRadius.circular(10)),
                                        color: Colors.transparent,
                                        child: Center(
                                          child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                          //  SizedBox(width: 0.5.w,),
                                            Icon(
                                              Icons.electric_meter,
                                              color: Colors.blue,
                                              size: 13.sp,
                                            ),
                                            Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                    "Voltaj",
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 4.sp,
                                                        fontWeight: FontWeight.bold),
                                                ),
                                                SizedBox(width: 18.w,),
                                                Text(
                                                  "12.8",
                                                  style: TextStyle(
                                                      color: Colors.blue,
                                                      fontSize: 5.sp),
                                                )
                                              ],
                                            ),
                                            SizedBox(
                                              width: 3.w,
                                            )
                                          ],
                                        )),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    SizedBox(
                                      width: 60.w,
                                      height: 80.h,
                                      child: Card(
                                        shape: RoundedRectangleBorder(
                                            side: BorderSide(
                                                color: Colors.blue, width: 1.w),
                                            borderRadius: BorderRadius.circular(10)),
                                        color: Colors.transparent,
                                        child: Center(
                                            child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            Icon(
                                              Icons.settings_overscan,
                                              color: Colors.blue,
                                              size: 13.sp,
                                            ),
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                    "Son RFID",
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 4.sp,
                                                        fontWeight: FontWeight.bold),
                                                ),
                                                
                                                Text(
                                                  agv.rfid,
                                                  style: TextStyle(
                                                      color: Colors.blue,
                                                      fontSize: 5.sp),
                                                )
                                              ],
                                            ),
                                           SizedBox(
                                              width: 3.w,
                                            )
                                          ],
                                        )),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 60.w,
                                      height: 80.h,
                                      child: Card(
                                        shape: RoundedRectangleBorder(
                                            side: BorderSide(
                                                color: Colors.blue, width: 1.w),
                                            borderRadius: BorderRadius.circular(10)),
                                        color: Colors.transparent,
                                        child: Center(
                                            child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            Icon(
                                              Icons.qr_code_2,
                                              color: Colors.blue,
                                              size: 13.sp,
                                            ),
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                    "Son QR",
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 4.sp,
                                                        fontWeight: FontWeight.bold),
                                                ),
                                                SizedBox(width: 18.w,),
                                                Text(
                                                  agv.sonQR,
                                                  style: TextStyle(
                                                      color: Colors.blue,
                                                      fontSize: 5.sp),
                                                )
                                              ],
                                            ),
                                            SizedBox(
                                              width: 3.w,
                                            )
                                          ],
                                        )),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 15.h,),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Text(
                                          manuelOrOtonom,
                                          style: TextStyle(
                                              fontSize: 4.sp,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        SizedBox(
                                          width: 14.w,
                                          height: 40.h,
                                          child: FittedBox(
                                            fit: BoxFit.fill,
                                            child: Switch(
                                              // This bool value toggles the switch.
                                              value: oto,
                                              activeThumbColor: Colors.blue,
                                              onChanged: (bool value) {
                                                // This is called when the user toggles the switch.
                                                setState(() {
                                                  oto = value;
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
                                        )
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        QRButton(onPressed: (){veriBas("k319");} , shortcutKey: LogicalKeyboardKey.keyX),
                                        Text(nextQR, style: TextStyle(color: const Color.fromARGB(255, 0, 0, 0), fontSize: 3.sp),)
                                      ],
                                    ),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text("Bağlantı Durumu:", style: TextStyle(fontSize: 4.sp, color: Colors.blue),),
                                        Text(isConnected.toString(), style: TextStyle(color: Colors.black, fontSize: 3.5.sp),)
                                      ],
                                    )
                                  ],
                                ),
                                SizedBox(
                                  height: 3.h,
                                )
                                
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 25.h,
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            SizedBox(width: 13.w,),
                            Column(
                              children: [
                                SizedBox(
                                  width: 40.w,
                                  height: 50.h,
                                  child: Card(
                                    color: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                        side: BorderSide(
                                            color: Colors.blue, width: 0.5.w),
                                        borderRadius: BorderRadius.circular(10)),
                                    child:  Text("LİFT KONTROLLERİ",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 3.sp,
                                                fontWeight: FontWeight.w600))),
                                ),
                                SizedBox(
                                  height: 32.h,
                                ),
                                ControlButton(
                                  onPressed: () {veriBas("k802");},
                                  onReleased: () {veriBas("k801");},
                                  assignedKey: LogicalKeyboardKey.keyQ,
                                  child:  Icon(Icons.arrow_upward_rounded , size: 7.sp),
                                  
                                ),
                                SizedBox(
                                  height: 25.h,
                                ),
                                ControlButton(
                                  onPressed: () {veriBas("k800");},
                                  onReleased: () {veriBas("k801");},
                                  assignedKey: LogicalKeyboardKey.keyE,
                                
                                  child:  Icon(Icons.arrow_downward_rounded , size: 7.sp),
                                ),
                                SizedBox(
                                  height: 10.h,
                                )
                              ],
                            ),
                            SizedBox(width: 10.w,),
                            Column(
                              children: [
                                SizedBox(
                                  width: 40.w,
                                  height: 50.h,
                                  child: Card(
                                    color: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                        side: BorderSide(
                                            color: Colors.blue, width: 0.5.w),
                                        borderRadius: BorderRadius.circular(10)),
                                    child: Text("ARAÇ KONTROLLERİ",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 3.sp,
                                                fontWeight: FontWeight.w600))),
                                ),
                                SizedBox(
                                  height: 18.h,
                                ),
                                Focus(
                                  child: Center(
                                    child: Column(
                                      children: [
                                        ControlButton(
                                          onPressed: () {
                                            veriBas("k94${4 - speed}");
                          
                                            },
                                          onReleased: () {veriBas("k944");},
                                          assignedKey: LogicalKeyboardKey.keyW,
                                          child: Icon(Icons.arrow_drop_up, size: 7.sp),
                                        ),
                                        Row(
                                          children: [
                                            ControlButton(
                                              onPressed: () {veriBas("k9${4 - speed}4");},
                                              onReleased: () {veriBas("k944");},
                                              assignedKey: LogicalKeyboardKey.keyA,
                                              child:  Icon(Icons.arrow_left , size: 7.sp),
                                            ),
                                            SizedBox(
                                              width: 15.w,
                                            ),
                                            ControlButton(
                                              onPressed: () {veriBas("k9${4 + speed}4");},
                                              onReleased: () {veriBas("k944");},
                                              assignedKey: LogicalKeyboardKey.keyD,
                                              child:  Icon(Icons.arrow_right , size: 7.sp),
                                            ),
                                          ],
                                        ),
                                        ControlButton(
                                          onPressed: () {veriBas("k94${4 + speed}");},
                                          onReleased: () {veriBas("k944");},
                                          assignedKey: LogicalKeyboardKey.keyS,
                                          child: Icon(Icons.arrow_drop_down , size: 7.sp),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
