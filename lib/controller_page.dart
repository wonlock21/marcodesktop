import 'dart:convert';
import 'data_model.dart';
import 'data_page.dart';
import 'parameter_model.dart';
import 'scenerio_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'timer.dart';

class ControllerPage extends StatefulWidget {
  const ControllerPage({super.key});

  @override
  State<ControllerPage> createState() {
    return _ControllerPageState();
  }
}

class _ControllerPageState extends State<ControllerPage> {
  String sicaklik = "";
  String yukKutle = "";
  String voltage = "";
  String amper = "";
  String isCharging = "Çalışıyor";
  List<dynamic> sensor = [];
  bool oto = false;
  bool lidarDurum = false;
  int speed = 0;
  int actionTime = 10;
  String manuelOrOtonom = "Manuel";
  String _site = '';
  bool isConnected = false;
  String _data = 'Veri yükleniyor...';
  String bas = "C";
  String bit = "A";
  List<dynamic> qrVeri = [0];
  String sonQR = "null";
  String rfid = "null";
  String nextQR = "null";
  String _scenarioData = "";
  FocusNode _focusNode = FocusNode();
  late ParameterModel parameterModel;

  double currX = 0.0;
  double currY = 0.0;
  double currYaw = 0.0;

  Timer? _poseTimer;
  Timer? _dataPollTimer;
  Timer? _connectionTimer;
  bool _mapReady = false; // harita en az bir kez yüklendi mi?

  @override
  void initState() {
    super.initState();
    startConnectionCheck();
    Provider.of<DataModel>(context, listen: false).loadDataPoints();
    parameterModel = Provider.of<ParameterModel>(context, listen: false);
    parameterModel.loadParameters(); // Verileri yükle
    _poseTimer = Timer.periodic(const Duration(milliseconds: 200), (_) => fetchPose());
    _dataPollTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) async {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      imageCache.clearLiveImages();

      fetchQRData();
      await Future.delayed(const Duration(milliseconds: 10));
      fetchRfid();
      await Future.delayed(const Duration(milliseconds: 10));
      fetchSensorData();
      await Future.delayed(const Duration(milliseconds: 10));
      chargingCheck();
      if (mounted) {
        setState(() {});
      }
      await Future.delayed(const Duration(milliseconds: 10));
    });
  }

  void startConnectionCheck() {
    _connectionTimer?.cancel();
    _connectionTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) async {
      final ok = await checkConnection();
      if (!mounted) return;
      setState(() {
        isConnected = ok;
      });
    });
  }
  Future<bool> checkConnection() async {
    try {
      final response = await http.get(Uri.parse(_site));
      if (response.statusCode == 200) {
        return true;  // Bağlantı başarılı
      } else {
        return false; // Bağlantı başarısız
      }
    } catch (e) {
      return false;   // Bağlantı başarısız
    }
  }

  void chargingCheck() {
    if (!mounted) return;
    try {
      if (amper.isNotEmpty && double.tryParse(amper) != null) {
        if (double.parse(amper) >= 1.0) {
          isCharging = "Şarj Doluyor";
        } else {
          isCharging = "Çalışıyor";
        }
      } else {
        isCharging = "Bağlantı Yok";
      }
    } catch (_) {
      isCharging = "Çalışıyor";
    }
  }

  /*Future<void> fetchQRData() async {
    try {
      var response = await http.get(Uri.parse("${_site}/qrliste"));
      if (response.statusCode == 200) {
        setState(() {
          qrVeri = response.body.split("-");
          sonQR = qrVeri[qrVeri.length - 2].toString().split(';').first;
          if(_scenarioData.isNotEmpty){
            List<String> listForScanner = _scenarioData.split("/");
            for(int i = 0; i<listForScanner.length; i++){
              if(listForScanner[i] == sonQR){
                for(int k = i+1; k < listForScanner.length; k++){
                  if(listForScanner[k].contains("Q")){
                    nextQR = listForScanner[k];
                    break;
                  }
                }
              }
            }
          }
        });
      } else {
        throw Exception('Veri alınamadı: ${response.reasonPhrase}');
      }
    } catch (e) {
      setState(() {
        qrVeri = [0];
      });
    }
  }*/

  Future<void> fetchQRData() async {
    try {
      final response = await http.get(Uri.parse('$_site/qrliste'));
      if (response.statusCode == 200) {
        sonQR=response.body; // gelen string
      } else {
        sonQR = "null"; 
      }
    } catch (e) {
      return null; // hata varsa null
    }
  }

  Future<void> fetchRfid() async {
    try {
      final response = await http.get(Uri.parse('$_site/rfid'));
      if (response.statusCode == 200) {
        rfid = response.body;
      } else {
        rfid = "null";
      }
    } catch (e) {
      return null;
    }
  }
  
  Future<void> fetchPose() async {
    if (_site.isEmpty) return; // connection-page’den dönmeden deneme
    final uri = Uri.parse('$_site/pose'); // <- varsayılan endpoint
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 2));
      if (resp.statusCode == 200) {
        final s = resp.body.trim(); // "x/y/yaw"
        final parts = s.split('/');
        if (parts.length >= 3) {
          final x = double.tryParse(parts[0]) ?? currX;
          final y = double.tryParse(parts[1]) ?? currY;
          final yaw = double.tryParse(parts[2]) ?? currYaw;
          setState(() {
            currX = y*10;
            currY = x*10;
            currYaw = yaw;
          });
        }
      } else {
        // debugPrint('get_pose status: ${resp.statusCode}');
      }
    } catch (e) {
      // debugPrint('get_pose error: $e');
    }
  }
  Future<void> fetchSensorData() async {  // sıcaklık-voltaj-akım-yük
    try {
      var response = await http.get(Uri.parse("${_site}/s"));
      if (response.statusCode == 200) {
        setState(() {
          sensor = response.body.split("/");
          sicaklik = sensor[0];
          voltage = sensor[1];
          amper = sensor[2];
        
        });
      } else {
        throw Exception('Veri alınamadı: ${response.reasonPhrase}');
      }
    } catch (e) {
      setState(() {
        sensor = [];
      });
    }
  }

  void startSendingData(String command, Duration duration) async {
    final int endTime = DateTime.now().millisecondsSinceEpoch + duration.inMilliseconds;

    while (DateTime.now().millisecondsSinceEpoch < endTime) {
      veriBas(command);
      await Future.delayed(const Duration(milliseconds: 50)); // 0.1 saniye bekleyip tekrar gönder
    }
  }

  //ekrandaki yazı girdisine yazılan yazının sayfası için servera istek gönderir
  Future<void> veriBas(String veri) async {
    try {
      var response = await http.get(Uri.parse("$_site/$veri"));
      if (response.statusCode == 200) {
        setState(() {
          _data = response.body;
        });
      } else {
        throw Exception('Veri basılamadı: ${response.reasonPhrase}');
      }
    } catch (e) {
      setState(() {
        _data = 'Hata: $e';
      });
    }
  }

  Future<void> _navigateToScenarioPage(List<DataPoint> dataPoints) async {
    if (dataPoints.isEmpty){
      return;
    }
    else {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScenarioPage(dataPoints: dataPoints, site: _site, rota: _scenarioData),
          ),
        );


        if (result != null) {
          setState(() {
            _scenarioData = result;
          });
        }
      }
  }
  Future<void> _navigateToDataPage(String site) async {
    if (site.isEmpty){
      print("no data");
    }
    else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DataPage(site: site),
          ),
        );
      }
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
    List<DataPoint> dataPoints = Provider.of<DataModel>(context).dataPoints;
    const Offset kOriginPx = Offset(120.0, 420.0);  // 0,0’ın JPEG’deki pikseli
    const double kPixelsPerMeter = 20.0;            // 1 m = 20 px
    const double kHeadingOffset = 0.0;              // gerekirse math.pi/2 ekle
    const String  kMapPath = '/map.jpg';            // JPEG servisin yolu
    const double  kIconSize = 24.0;
    
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
                if (result != null) {
                  setState(() {
                    _site = result as String;
                  });
                }
                else {
                  setState(() {
                
                    _mapReady = false; // yeni sitede haritayı tekrar bekle
                  }); 
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
                          poseFn: () => Pose(currX, currY, currYaw),
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
                                                activeColor: Color.fromARGB(255, 27, 141, 255),
                                                inactiveColor: Color.fromARGB(255, 207, 245, 255),
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
                        child: Card(
                            elevation: 0,
                            color: const Color.fromARGB(0, 255, 255, 255),
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
                                                Center(
                                                  child: Text(
                                                    "Durum",
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 4.sp,
                                                        fontWeight: FontWeight.bold),
                                                  ),
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
                                                Center(
                                                  child: Text(
                                                    "Görev Süresi",
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 4.sp,
                                                        fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                SizedBox(width: 28.w,),
                                                TimerPage(),
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
                                                Center(
                                                  child: Text(
                                                    "Güç Seviyesi",
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 4.sp,
                                                        fontWeight: FontWeight.bold),
                                                  ),
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
                                                Center(
                                                  child: Text(
                                                    "Sıcaklık",
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 4.sp,
                                                        fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                SizedBox(width: 18.w,),
                                                Text(
                                                  sicaklik,
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
                                                Center(
                                                  child: Text(
                                                    "Amper",
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 5.sp,
                                                        fontWeight: FontWeight.bold),
                                                  ),
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
                                                Center(
                                                  child: Text(
                                                    "Voltaj",
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 4.sp,
                                                        fontWeight: FontWeight.bold),
                                                  ),
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
                                                Center(
                                                  child: Text(
                                                    "Son RFID",
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 4.sp,
                                                        fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                
                                                Text(
                                                  rfid,
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
                                                Center(
                                                  child: Text(
                                                    "Son QR",
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 4.sp,
                                                        fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                SizedBox(width: 18.w,),
                                                Text(
                                                  sonQR,
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
                                              activeColor: Colors.blue,
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
                                    child:  Center(
                                        child: Text("LİFT KONTROLLERİ",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 3.sp,
                                                fontWeight: FontWeight.w600))),
                                    ),
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
                                    child: Center(
                                        child: Text("ARAÇ KONTROLLERİ",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 3.sp,
                                                fontWeight: FontWeight.w600))),
                                  ),
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

class PowerButton extends StatefulWidget {
  final double height;
  final double width;
  final IconData icon;
  Function onPressed;

  PowerButton(
      {super.key,
      this.icon = Icons.power_settings_new,
      this.width = 300,
      this.height = 100,
      required this.onPressed,
      });

  @override
  _PowerButtonState createState() => _PowerButtonState();
}

class _PowerButtonState extends State<PowerButton> {
  bool isOn = false;

  void _toggleState() {
    setState(() {
      isOn = !isOn;
    });

    // Reset to initial state after 1 millisecond
    Future.delayed(const Duration(milliseconds: 600), () {
      setState(() {
        isOn = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _toggleState();
        widget.onPressed;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 150.h,
        width: 80.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          color: Colors.grey[800],
          boxShadow: [
            BoxShadow(
              color: isOn ? Colors.transparent : Colors.black54,
              blurRadius: isOn ? 0 : 10,
              spreadRadius: isOn ? 0 : 4,
              offset: isOn ? const Offset(0, 0) : const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: AnimatedContainer(
            padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 25.w),
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: (isOn ? Colors.red : Colors.grey[700])!,
                width: 1.w,
              ),
            ),
            child: AnimatedScale(
              scale: isOn ? 0.85 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                widget.icon,
                color: isOn ? Colors.red : Colors.grey[600],
                size: 20.sp,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class QRButton extends StatefulWidget {
  final VoidCallback onPressed;
  final LogicalKeyboardKey shortcutKey;

  const QRButton({required this.onPressed, required this.shortcutKey, Key? key}) : super(key: key);

  @override
  _QRButtonState createState() => _QRButtonState();
}

class _QRButtonState extends State<QRButton> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _focusNode.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == widget.shortcutKey) {
      widget.onPressed();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.qr_code_scanner, size: 10.sp,),
      focusNode: _focusNode,
      onPressed: widget.onPressed,
    );
  }
}


class NormalButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final LogicalKeyboardKey assignedKey;
  final FocusNode? customFocusNode;

  const NormalButton({
    Key? key,
    required this.text,
    required this.onPressed,
    required this.assignedKey,
    this.customFocusNode,
  }) : super(key: key);
  
  @override
  _NormalButtonState createState() => _NormalButtonState();
}

class _NormalButtonState extends State<NormalButton> {
  bool isOn = false;
  late FocusNode _focusNode;

  void _toggleState() {
    setState(() {
      isOn = !isOn;
    });

    // Reset to initial state after 1 millisecond
    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        isOn = false;
      });
    });
  }
    @override
  void initState() {
    super.initState();
    _focusNode = widget.customFocusNode ?? FocusNode();
    _focusNode.requestFocus(); // Automatically request focus
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _focusNode.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == widget.assignedKey) {
      if (!isOn) {
        setState(() {
          _toggleState();
          widget.onPressed();
        });
      }
      return true;
    } 
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: GestureDetector(
        onTap: () {
          _toggleState();
          widget.onPressed();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 80.h,
          width: 50.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            color: Colors.grey[800],
            boxShadow: [
              BoxShadow(
                color: isOn ? Colors.transparent : Colors.black54,
                blurRadius: isOn ? 0 : 10,
                spreadRadius: isOn ? 0 : 2,
                offset: isOn ? const Offset(0, 0) : const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: AnimatedContainer(
              alignment: Alignment.center,
              width: 45.w,
              height: 65.h,
              padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 6.w),
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: (isOn ? Colors.blue : Colors.grey[700])!,
                  width: 1.w,
                ),
              ),
              child: AnimatedScale(
                scale: isOn ? 0.85 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: Text(widget.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isOn ? Colors.blue : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 5.sp,
                    )),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ControlButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final VoidCallback onReleased;
  final LogicalKeyboardKey assignedKey;
  final FocusNode? customFocusNode;

  const ControlButton({
    Key? key,
    required this.child,
    required this.onPressed,
    required this.onReleased,
    required this.assignedKey,
    this.customFocusNode,
  }) : super(key: key);

  @override
  _ControlButtonState createState() => _ControlButtonState();
}

class _ControlButtonState extends State<ControlButton> {
  bool isPressed = false;
  late FocusNode _focusNode;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.customFocusNode ?? FocusNode();
    _focusNode.requestFocus(); // Otomatik odaklanma
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == widget.assignedKey) {
      _handlePress();
      return true;
    } else if (event is KeyUpEvent && event.logicalKey == widget.assignedKey) {
      _handleRelease();
      return true;
    }
    return false;
  }

 void _handlePress() {
  if (!isPressed) {
    setState(() {
      isPressed = true;
    });
    widget.onPressed();
  }
  
  // Debounce timer, onPress'den sonra tekrar başlamasın
  _debounceTimer?.cancel();
  _debounceTimer = Timer(const Duration(milliseconds: 50), () {});
}

void _handleRelease() {
  if (_debounceTimer?.isActive ?? false) return;

  if (isPressed) {
    setState(() {
      isPressed = false;
    });
    widget.onReleased();
  }

  // Debounce timer, onRelease'den sonra tekrar başlamasın
  _debounceTimer?.cancel();
  _debounceTimer = Timer(const Duration(milliseconds: 50), () {});
}


  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: GestureDetector(
        onTapDown: (_) => _handlePress(),
        onTapUp: (_) => _handleRelease(),
        //onTapCancel: _handleRelease,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: isPressed
                ? const Color.fromARGB(255, 173, 173, 173)
                : const Color.fromARGB(255, 121, 121, 121),
            borderRadius: BorderRadius.circular(25.r),
            boxShadow: isPressed
                ? null
                : [
                    BoxShadow(
                      color: const Color.fromARGB(255, 163, 163, 163),
                      offset: const Offset(0, 5),
                      blurRadius: 15.r,
                    ),
                    BoxShadow(
                      color: const Color.fromARGB(255, 76, 76, 76),
                      offset: const Offset(0, -2),
                      blurRadius: 10.r,
                    ),
                  ],
            gradient: const LinearGradient(
              colors: [
                Color.fromARGB(255, 107, 107, 107),
                Color.fromARGB(255, 162, 162, 162),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Transform.scale(
            scale: isPressed ? 0.96 : 1,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/*
class LiveMapImage extends StatefulWidget {
  final String site; // ör: http://127.0.0.1:5000
  final Duration interval;
  const LiveMapImage({
    super.key,
    required this.site,
    this.interval = const Duration(seconds: 1),
  });

  @override
  State<LiveMapImage> createState() => _LiveMapImageState();
}

class _LiveMapImageState extends State<LiveMapImage> {
  Timer? _timer;
  String? _url; // null => “bekleme” modunda (site seçilmemiş)

  @override
  void initState() {
    super.initState();
    _maybeStart();
  }

  @override
  void didUpdateWidget(covariant LiveMapImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.site != widget.site || oldWidget.interval != widget.interval) {
      _stop();
      _maybeStart();
    }
  }

  void _maybeStart() {
    if (widget.site.isEmpty) {
      setState(() => _url = null);
      return;
    }
    _bump(); // ilk kare
    _timer = Timer.periodic(widget.interval, (_) => _bump());
  }

  void _bump() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _url = '${widget.site}/map.png?t=$ts';
      // Yalnızca canlı görsellerin cache’ini temizle (global clear yok)
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_url == null) {
      return const Text('Bağlantı seçilmedi'); // veya CircularProgressIndicator()
    }
    return Image.network(
      _url!,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, __, ___) => const Text('Harita yüklenemedi'),
    );
  }
}*/


// ——— manuel kalibrasyon ———
const Offset kOriginPx = Offset(120.0, 260.0);
const double kPixelsPerMeter = 20.0;
const double kHeadingOffset  = 7.6;
const double kIconSize       = 24.0;

class Pose { final double x,y,yaw; const Pose(this.x,this.y,this.yaw); }

class LiveMapFixedUrl extends StatefulWidget {
  final String site;                 // ör: http://10.0.0.12:5000
  final String imagePath;            // ör: /get_image ya da /map.jpg
  final Pose Function() poseFn;      // x,y,yaw sağlayan fonksiyon
  final Duration interval;           // kaç ms’de bir yenile
  final Duration timeout;

  const LiveMapFixedUrl({
    super.key,
    required this.site,
    required this.poseFn,
    this.imagePath = '/get_image',
    this.interval = const Duration(milliseconds: 500),
    this.timeout  = const Duration(seconds: 8),
  });

  @override
  State<LiveMapFixedUrl> createState() => _LiveMapFixedUrlState();
}

class _LiveMapFixedUrlState extends State<LiveMapFixedUrl> {
  Timer? _timer;
  bool _mapReady = false;
  Uint8List? _frame;
  bool _fetching = false;
  String? _lastError;

  String get _url {
    // imagePath tam URL ise aynen kullan; değilse site ile birleştir
    final p = widget.imagePath;
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    final base = widget.site.endsWith('/') ? widget.site.substring(0, widget.site.length - 1) : widget.site;
    final tail = p.startsWith('/') ? p : '/$p';
    return '$base$tail';
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant LiveMapFixedUrl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.site != widget.site ||
        oldWidget.interval != widget.interval ||
        oldWidget.imagePath != widget.imagePath) {
      _stop();
      setState(() {
        _mapReady = false;
        _frame = null;
        _lastError = null;
      });
      _start();
    }
  }

  void _start() {
    if (widget.site.isEmpty) return;
    _tick();
    _timer = Timer.periodic(widget.interval, (_) => _tick());
  }

// ... üst kısımlar aynı

  Future<void> _tick() async {
    if (_fetching || widget.site.isEmpty) return;
    _fetching = true;
    try {
      final resp = await http.get(Uri.parse(_url)).timeout(widget.timeout);

      if (resp.statusCode == 200) {
        Uint8List? bytes;
        final headers = resp.headers.map((k, v) => MapEntry(k.toLowerCase(), v));
        final ct = (headers['content-type'] ?? '').toLowerCase();

        if (ct.startsWith('image/')) {
          if (resp.bodyBytes.isNotEmpty) bytes = resp.bodyBytes;
        }

        bytes ??= _sniffBinaryImage(resp.bodyBytes);

        if (bytes == null && ct.contains('application/json')) {
          final obj = jsonDecode(utf8.decode(resp.bodyBytes));
          if (obj is Map) {
            final String b64 = (obj['data'] as String?) ?? (obj['image'] as String? ?? '');
            if (b64.isNotEmpty) bytes = base64Decode(_stripDataUrlPrefix(b64));
          }
        }

        // YENİ: HTML sayfa ise, <img src="..."> veya data:image/... ara
        if (bytes == null && ct.contains('text/html')) {
          final html = _tryDecodeUtf8Lossy(resp.bodyBytes);
          // 1) data URL var mı?
          final dataUrl = _extractDataImageUrl(html);
          if (dataUrl != null) {
            bytes = base64Decode(_stripDataUrlPrefix(dataUrl));
          } else {
            // 2) <img src="..."> var mı? varsa aynı siteden çek
            final imgSrc = _extractFirstImgSrc(html);
            if (imgSrc != null) {
              final resolved = _resolveUrl(Uri.parse(_url), imgSrc);
              _debug('HTML içinden img src bulundu: $resolved');
              final imgResp = await http.get(resolved).timeout(widget.timeout);
              if (imgResp.statusCode == 200) {
                // yine aynı çözme mantıkları:
                final ct2 = (imgResp.headers['content-type'] ?? '').toLowerCase();
                if (ct2.startsWith('image/')) {
                  if (imgResp.bodyBytes.isNotEmpty) bytes = imgResp.bodyBytes;
                }
                bytes ??= _sniffBinaryImage(imgResp.bodyBytes);
                if (bytes == null && ct2.contains('application/json')) {
                  final obj2 = jsonDecode(utf8.decode(imgResp.bodyBytes));
                  if (obj2 is Map) {
                    final String b64 = (obj2['data'] as String?) ?? (obj2['image'] as String? ?? '');
                    if (b64.isNotEmpty) bytes = base64Decode(_stripDataUrlPrefix(b64));
                  }
                }
                if (bytes == null) {
                  // belki düz base64 metin
                  final bodyStr2 = _tryDecodeUtf8Lossy(imgResp.bodyBytes).trim();
                  if (_looksLikeBase64(bodyStr2)) {
                    bytes = base64Decode(_stripDataUrlPrefix(bodyStr2));
                  }
                }
              } else {
                _debug('img src HTTP ${imgResp.statusCode}');
              }
            } else {
              // Teşhis için HTML’in başını logla (çok uzun olmayacak kadar)
              _debug('HTML geldi ama IMG tag bulunamadı. Head: ${html.substring(0, html.length.clamp(0, 200))}');
            }
          }
        }

        if (bytes == null) {
          // Son çare: düz base64
          final bodyStr = _tryDecodeUtf8Lossy(resp.bodyBytes).trim();
          if (_looksLikeBase64(bodyStr)) {
            try { bytes = base64Decode(_stripDataUrlPrefix(bodyStr)); } catch (e) { _debug('Base64 decode hatası: $e'); }
          }
        }

        if (bytes != null && bytes.isNotEmpty && mounted) {
          setState(() { _frame = bytes; _mapReady = true; _lastError = null; });
        } else {
          _noteError('200 aldı ama görüntü çözülemedi (ct="$ct", len=${resp.bodyBytes.length}).');
        }
      } else {
        _noteError('HTTP ${resp.statusCode} – ${resp.reasonPhrase ?? ''}');
      }
    } catch (e) {
      _noteError('İstek hatası: $e');
    } finally {
      _fetching = false;
    }
  }

  // --- yardımcılar (yeni) ---
  String? _extractFirstImgSrc(String html) {
    // basit ve toleranslı bir regex
  final r = RegExp(
    r'''<img[^>]+src=["']([^"']+)["']''',
    caseSensitive: false,
  );


    final m = r.firstMatch(html);
    return m?.group(1);
  }

  String? _extractDataImageUrl(String html) {
    // data:image/...;base64,..... yakala
    final r = RegExp(r'data:image\/[a-zA-Z0-9.+-]+;base64,[A-Za-z0-9+\/=\r\n]+', caseSensitive: false);
    final m = r.firstMatch(html);
    return m?.group(0);
  }

  Uri _resolveUrl(Uri base, String href) {
    // relatif/absolute fark etmez, düzgünleştir
    if (href.startsWith('http://') || href.startsWith('https://')) return Uri.parse(href);
    if (href.startsWith('//')) return Uri.parse('${base.scheme}:$href');
    if (href.startsWith('/')) return Uri.parse('${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}$href');
    // relative path
    final b = base.toString();
    final withoutFile = b.endsWith('/') ? b : b.substring(0, b.lastIndexOf('/') + 1);
    return Uri.parse('$withoutFile$href');
  }


  // JPEG/PNG/WebP sihirli bayt imzası kontrolü
  Uint8List? _sniffBinaryImage(Uint8List data) {
    if (data.length < 12) return null;
    // JPEG: FF D8 FF
    if (data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF) return data;
    // PNG: 89 50 4E 47 0D 0A 1A 0A
    const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (List.generate(8, (i) => data[i]).every((b) => b == png[data.indexOf(b)])) return data;
    // WebP: "RIFF"...."WEBP"
    final riff = utf8.encode('RIFF');
    final webp = utf8.encode('WEBP');
    if (_startsWith(data, riff) && _containsAt(data, webp, 8)) return data;
    return null;
  }

  bool _startsWith(Uint8List d, List<int> sig) {
    if (d.length < sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (d[i] != sig[i]) return false;
    }
    return true;
  }

  bool _containsAt(Uint8List d, List<int> sig, int offset) {
    if (d.length < offset + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (d[offset + i] != sig[i]) return false;
    }
    return true;
  }

  String _stripDataUrlPrefix(String s) {
    final i = s.indexOf(',');
    return s.startsWith('data:') && i != -1 ? s.substring(i + 1) : s;
  }

  String _tryDecodeUtf8Lossy(Uint8List data) {
    // Yanlış Content-Type durumunda binary veriyi "metin" sanıp patlamayalım
    try {
      return utf8.decode(data);
    } catch (_) {
      return const AsciiDecoder(allowInvalid: true).convert(data);
    }
  }

  bool _looksLikeBase64(String s) {
    // kaba kontrol: sadece base64 karakterleri + '=' padding ve en az 100 byte civarı
    final cleaned = _stripDataUrlPrefix(s).replaceAll('\n', '').replaceAll('\r', '');
    if (cleaned.length < 16) return false;
    final reg = RegExp(r'^[A-Za-z0-9+/=]+$');
    return reg.hasMatch(cleaned.substring(0, cleaned.length.clamp(0, 256)));
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _noteError(String msg) {
    _debug(msg);
    if (!mounted) return;
    setState(() => _lastError = msg);
  }

  void _debug(String msg) {
    // burada log kanalı kullanmak istersen debugPrint'i tercih et
    // ignore: avoid_print
    print('[LiveMap] $msg  url=${_url}');
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.site.isEmpty) {
      return const _StatusPane(text: "Bağlantı bekleniyor...");
    }

    final pose = widget.poseFn();
    final px = kOriginPx.dx + pose.x * kPixelsPerMeter;
    final py = kOriginPx.dy - pose.y * kPixelsPerMeter;
    final theta = -pose.yaw + kHeadingOffset;

    return Stack(
      children: [
        Positioned.fill(
          child: (_frame == null)
              ? _StatusPane(text: _lastError == null ? "Harita yükleniyor..." : _lastError!)
              : Image.memory(
                  _frame!,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.low,
                  fit: BoxFit.fill,
                ),
        ),
        if (_mapReady)
          Positioned(
            left: (px - kIconSize / 2),
            top:  (py - kIconSize / 2),
            width: kIconSize,
            height: kIconSize,
            child: Transform.rotate(
              angle: theta,
              child: const Icon(Icons.navigation, color: Colors.redAccent, size: kIconSize),
            ),
          ),
      ],
    );
  }
}

class _StatusPane extends StatelessWidget {
  final String text;
  const _StatusPane({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 8),
        Text(text, style: const TextStyle(color: Colors.grey)),
      ]),
    );
    }
}
