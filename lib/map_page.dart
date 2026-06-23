import 'data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';

var verticalRoad = Center(child: SizedBox(width: 0.5.w, height: 50.h, child: const ColoredBox(color: Color.fromARGB(255, 0, 0, 0)),));
var horizontalRoad = Center(child: SizedBox(width: 15.w, height: 2.h, child: const ColoredBox(color: Colors.black),));
var halfVerticalRoadFromEdge = Align(
  alignment: Alignment.topCenter, // Çizgiyi üst kısımdan başlatmak için
  child: FractionallySizedBox( // Genişlik ince bir çizgi olarak
    heightFactor: 0.5, // Yükseklik yarı boyutta
    child: Container(
      width: 0.5.w,
      color: Colors.black,
    )
  ),
);
var halfHorizontalRoadFromEdge = Align(
  alignment: Alignment.centerLeft, // Çizgiyi sol kenardan başlatmak için
  child: FractionallySizedBox(
    widthFactor: 0.5, // Yatay uzunluk genişletilmiş olacak // Yükseklik ince bir çizgi olarak ayarlanmış
    child: Container(
      height: 2.h,
      color: Colors.black,
    )
  ),
);

var topToLeftRoad = Stack(
      alignment: Alignment.center,
      children: [
        halfVerticalRoadFromEdge,
        halfHorizontalRoadFromEdge
      ],
    );

var topToRightRoad = Transform.rotate(
      angle: math.pi / 2, 
      child: topToLeftRoad,
    );

var bottomToRightRoad = Transform.rotate(
      angle: math.pi, 
      child: topToLeftRoad,
    );

var bottomToLeftRoad = Transform.rotate(
      angle: 3 * math.pi / 2, 
      child: topToLeftRoad,
    );

var verticalToLeftRoad = Stack(
      alignment: Alignment.center,
      children: [
        verticalRoad,
        halfHorizontalRoadFromEdge
      ],
    );

var horizontalToTopRoad = Transform.rotate(
      angle: math.pi / 2, 
      child: verticalToLeftRoad,
    );

var verticalToRightRoad = Transform.rotate(
      angle: math.pi, 
      child: verticalToLeftRoad,
    );

var horizontalToBottomRoad = Transform.rotate(
      angle: 3 * math.pi / 2, 
      child: verticalToLeftRoad,
    );

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // eskiden top-level global olan değişkenler — artık instance field
  int incrementThing = -1;
  List<DataPoint> dataPoints = [];
  List<DataPoint> lastDataPoints = [];

  late List<Widget> gridWidgets;
  int qrCount = 0;
  int qrTemp = 0;
  int chargeStationCount = 0;
  late List<Widget> roadWidgets;
  int currentOneWayRoadIndex = 0;
  int currentTwoWayRoadIndex = 0;
  int currentThreeWayRoadIndex = 0;
  int cargoAreaIndex = 0;
  int numberOfStarts = 0;
  List<int> deletedQRIndices = [];

  String getNextCargoAreaName() {
    return String.fromCharCode('A'.codeUnitAt(0) + cargoAreaIndex++ % 26);
    
  }
  String getExCargoAreaName() {
    return String.fromCharCode('A'.codeUnitAt(0) + cargoAreaIndex-- % 26);
    
  }

  int incrementStartCount() {
    numberOfStarts++;
    return numberOfStarts;
  }

  int decrementStartCount() {
    numberOfStarts--;
    return numberOfStarts;
  }

  int incrementQRCount() {
    if (deletedQRIndices.isNotEmpty) {
      // Reuse the smallest deleted index
      return deletedQRIndices.removeAt(0);
    } 
    
    else {  
      for(int i = 0 ; i < dataPoints.length; i++){
        if (dataPoints[i].type.contains("Q")) {
          if (qrCount < int.parse(dataPoints[i].type.substring(1))){
            qrCount = int.parse(dataPoints[i].type.substring(1));
          }
        }
      }
      return ++qrCount;
    }
  }

  void decrementQRCount(int removedIndex) {
    // Add the removed index to the deleted list
    deletedQRIndices.add(removedIndex);
    deletedQRIndices.sort(); // Keep the list sorted for reusing the smallest index
    qrCount--;
  }

  int incrementChargeStationCount() {
    chargeStationCount++;
    return chargeStationCount;
  }

  int decrementChargeStationCount() {
    chargeStationCount--;
    return chargeStationCount;
  }

  @override
  void initState() {
    super.initState();
    roadWidgets = [
      verticalRoad,
      horizontalRoad,
      topToLeftRoad,
      topToRightRoad,
      bottomToRightRoad,
      bottomToLeftRoad,
      verticalToLeftRoad,
      horizontalToTopRoad,
      verticalToRightRoad,
      horizontalToBottomRoad
    ];
    incrementThing = -1;
    dataPoints = List.empty(growable: true);
  }

  Widget specialWidget(int ind){
    dataPoints.add(lastDataPoints[ind]);

    if(lastDataPoints[ind].type.contains("Q")){
      //incrementQRCount();
      qrTemp = int.parse(lastDataPoints[ind].type.substring(1));
      if(qrTemp > qrCount){
        qrCount = qrTemp;
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        Icon(Icons.qr_code, size: 5.sp,),
        Text(lastDataPoints[ind].type.substring(1), style: TextStyle(fontSize: 2.5.sp, fontWeight: FontWeight.w700),),
        ],
      );
    }

    else if(lastDataPoints[ind].type.contains("roadVertical")){
      return verticalRoad;
    }
    else if(lastDataPoints[ind].type.contains("roadHorizontal")){
      return horizontalRoad;
    }
    else if(lastDataPoints[ind].type.contains("topToLeftRoad")){
      return topToLeftRoad;
    }
    else if(lastDataPoints[ind].type.contains("topToRightRoad")){
      return topToRightRoad;
    }
    else if(lastDataPoints[ind].type.contains("bottomToRightRoad")){
      return bottomToRightRoad;
    }
    else if(lastDataPoints[ind].type.contains("bottomToLeftRoad")){
      return bottomToLeftRoad;
    }
    else if(lastDataPoints[ind].type.contains("verticalToRightRoad")){
      return verticalToRightRoad;
    }
    else if(lastDataPoints[ind].type.contains("verticalToLeftRoad")){
      return verticalToLeftRoad;
    }
    else if(lastDataPoints[ind].type.contains("horizontalToTopRoad")){
      return horizontalToTopRoad;
    }
    else if(lastDataPoints[ind].type.contains("horizontalToBottomRoad")){
      return horizontalToBottomRoad;
    }
    else if(lastDataPoints[ind].type.contains("start")) { //startArea1
      incrementStartCount(); 
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        Icon(Icons.location_on, size: 5.sp,),
        Text(lastDataPoints[ind].type.substring(9), style: TextStyle(fontSize: 2.5.sp, fontWeight: FontWeight.w700),),
        ],
      );
    }
    else if(lastDataPoints[ind].type.contains("charge")){
      incrementChargeStationCount();
      return Icon(Icons.battery_charging_full, size: 5.sp);
    }
    else if(lastDataPoints[ind].type.contains("cargo")){ //cargoAreaA
      getNextCargoAreaName();
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.archive_outlined, size: 5.sp),
          Text(lastDataPoints[ind].type.substring(9), style: TextStyle(fontSize: 3.sp))
        ],
      );
    }
    else {
      return const ColoredBox(color: Colors.red);
    }
    
  }
  @override
  Widget build(BuildContext context) {
    lastDataPoints = Provider.of<DataModel>(context, listen: false).dataPoints;

    return Scaffold(
     appBar: AppBar(
        title: Text(
          "Girilen Harita",
          style: TextStyle(
              color: const Color.fromARGB(255, 255, 255, 255),
              fontSize: 4.sp,
              fontWeight: FontWeight.w600),
        ),
      ),
     body: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Haritayı yerleştir.
        Column( 
          mainAxisAlignment: MainAxisAlignment.center,  
          children: [
            SizedBox(
              width: 250.w,
              height: 610.h,
              child: GridView.builder(
                addRepaintBoundaries: false,
                itemCount: 493,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 29, // Kare sayısı
                ),
                itemBuilder: (BuildContext context, int index) {
                  bool isEmpty = true;
                  int ind = 0;
                  bool invisibleQR = false;

                  for (int i = 0; i < lastDataPoints.length; i++) {
                    int localIndex = (16 - lastDataPoints[i].y) * 29 + (28 - lastDataPoints[i].x);

                    if (localIndex == index) {
                      // Aynı x ve y değerlerine sahip diğer veri noktalarını kontrol edin
                      for (int k = 0; k < lastDataPoints.length; k++) {
                        if (k != i && 
                            lastDataPoints[i].x == lastDataPoints[k].x && 
                            lastDataPoints[i].y == lastDataPoints[k].y) {
                          invisibleQR = true;
                          // QR kodunu arka planda ekleyin
                          if (lastDataPoints[i].type.contains("Q")) {
                            dataPoints.add(lastDataPoints[i]);
                          }
                          else {
                            isEmpty = false;
                            ind = i;
                          }
                          break;
                        }
                      }

                      // Eğer QR kodu gizlenmişse, diğer elemanlardan birini göster
                      if (!invisibleQR) {
                        isEmpty = false;
                        ind = i;
                      }
                    }
                  }
                  return DragTargetContainer(
                    index: index,
                    dataPoints: dataPoints,
                    incrementQRCount: incrementQRCount,
                    incrementChargeStationCount: incrementChargeStationCount,
                    getNextCargoAreaName: getNextCargoAreaName,
                    incrementStartCount: incrementStartCount,
                    decrementQRCount: decrementQRCount,
                    decrementChargeStationCount: decrementChargeStationCount,
                    decrementStartCount: decrementStartCount,
                    getExCargoAreaName: getExCargoAreaName,
                    child: isEmpty 
                      ? Container() 
                      : specialWidget(ind),
                  );
                },
              )
            )
          ],
        ),
        // Yapı Menüsünü yerleştir.
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                ConnectButton(
                  text: "Haritayı Kaydet",
                  onPressed: (){
                      Provider.of<DataModel>(context, listen: false)
                          .clearDataPoints(); // Önceki verileri temizleyin
                      for (var dataPoint in dataPoints) {
                        Provider.of<DataModel>(context, listen: false)
                            .addDataPoint(dataPoint);
                      }
                      Provider.of<DataModel>(context, listen: false).saveDataPoints();
                      lastDataPoints = Provider.of<DataModel>(context, listen: false).dataPoints;
                      Navigator.pop(context, 'controller-page');
                  },
                ),
                SizedBox(width: 10.w,),
                ResetButton(
                  text: "Sıfırla",
                  onPressed: (){
                    Provider.of<DataModel>(context, listen: false)
                          .clearDataPoints();
                    lastDataPoints = [];
                    Navigator.pop(context, 'controller-page');
                  },
                )
              ],
            ),
            SizedBox(height: 30.h,),
            Text("Yapılar", style: TextStyle(fontSize: 10.sp, color: Colors.blueAccent),),
            SizedBox(height: 10.h),
            SizedBox(
              width: 100.w,
              height: 500.h,
              child: Card.outlined(
                color: Colors.black26,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: const Color.fromARGB(255, 114, 114, 114) , width: 1.w)
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 2.w,),
                            Text("Yollar", style: TextStyle(color: Colors.blue , fontSize: 4.sp ),),
                          ],
                        ),
                        SizedBox(height: 50.h,),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            //Yatay Yol
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Draggable<Map<String, dynamic>>(
                                  data: const {'type': 'roadVertical'},
                                  feedback: Container(
                                    width: 15.w,
                                    height: 50.h,
                                    color: Colors.transparent,
                                    child: verticalRoad,
                                  ),
                                  childWhenDragging: Container(
                                    width: 15.w,
                                    height: 50.h,
                                    color: Colors.transparent,
                                    child: verticalRoad,
                                  ), 
                                  child: Container(
                                    width: 15.w,
                                    height: 50.h,
                                    color: Colors.transparent,
                                    child: verticalRoad,
                                  ),
                                ),
                                Draggable<Map<String, dynamic>>(
                                  data: const {'type': 'roadHorizontal'},
                                  feedback: Container(
                                    width: 15.w,
                                    height: 50.h,
                                    color: Colors.transparent,
                                    child: horizontalRoad,
                                  ),
                                  childWhenDragging: Container(
                                    width: 15.w,
                                    height: 50.h,
                                    color: Colors.transparent,
                                    child: horizontalRoad,
                                  ), 
                                  child: Container(
                                    width: 15.w,
                                    height: 50.h,
                                    color: Colors.transparent,
                                    child: horizontalRoad,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: 10.w,),
                            //İkili yollar
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Draggable<Map<String, dynamic>>(
                                      data: const {'type': 'topToLeftRoad'},
                                      feedback: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: topToLeftRoad,
                                      ),
                                      childWhenDragging: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: topToLeftRoad,
                                      ), 
                                      child: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: topToLeftRoad,
                                      ),
                                    ),
                                    
                                    Draggable<Map<String, dynamic>>(
                                      data: const {'type': 'topToRightRoad'},
                                      feedback: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: topToRightRoad,
                                      ),
                                      childWhenDragging: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: topToRightRoad,
                                      ), 
                                      child: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: topToRightRoad,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Draggable<Map<String, dynamic>>(
                                      data: const {'type': 'bottomToLeftRoad'},
                                      feedback: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: bottomToLeftRoad,
                                      ),
                                      childWhenDragging: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: bottomToLeftRoad,
                                      ), 
                                      child: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: bottomToLeftRoad,
                                      ),
                                    ),
                                    Draggable<Map<String, dynamic>>(
                                      data: const {'type': 'bottomToRightRoad'},
                                      feedback: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: bottomToRightRoad,
                                      ),
                                      childWhenDragging: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: bottomToRightRoad,
                                      ), 
                                      child: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: bottomToRightRoad,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(width: 10.w,),
                            //Üçlü yollar
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Draggable<Map<String, dynamic>>(
                                      data: const {'type': 'horizontalToTopRoad'},
                                      feedback: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: horizontalToTopRoad,
                                      ),
                                      childWhenDragging: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: horizontalToTopRoad,
                                      ),
                                      child: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: horizontalToTopRoad,
                                      ),
                                    ),
                                    Draggable<Map<String, dynamic>>(
                                      data: const {'type': 'horizontalToBottomRoad'},
                                      feedback: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: horizontalToBottomRoad,
                                      ),
                                      childWhenDragging: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: horizontalToBottomRoad,
                                      ),
                                      child: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: horizontalToBottomRoad,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Draggable<Map<String, dynamic>>(
                                      data: const {'type': 'verticalToLeftRoad'},
                                      feedback: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: verticalToLeftRoad,
                                      ),
                                      childWhenDragging: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: verticalToLeftRoad,
                                      ),
                                      child: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: verticalToLeftRoad,
                                      ),
                                    ),
                                    Draggable<Map<String, dynamic>>(
                                      data: const {'type': 'verticalToRightRoad'},
                                      feedback: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: verticalToRightRoad,
                                      ),
                                      childWhenDragging: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: verticalToRightRoad,
                                      ),
                                      child: Container(
                                        width: 15.w,
                                        height: 50.h,
                                        color: Colors.transparent,
                                        child: verticalToRightRoad,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 40.h,),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            SizedBox(width: 15.w,),
                            Text("QR", style: TextStyle(color: Colors.blue , fontSize: 3.5.sp),),
                            SizedBox(height: 5.h),
                            Draggable<Map<String, dynamic>>(
                              data: {'type': 'Q', 'index': qrCount},
                              feedback: Container(
                                width: 15.w,
                                height: 50.h,
                                color: Colors.blue.withValues(alpha: 0.5),
                                child: Center(child: Icon(Icons.qr_code, size: 6.sp,))
                              ),
                              childWhenDragging: Container(
                                width: 15.w,
                                height: 50.h,
                                color: const Color.fromARGB(255, 103, 155, 197),
                                child: Center(child: Icon(Icons.qr_code, size: 6.sp,))
                              ), // Yapı türü
                              child: Container(
                                constraints: BoxConstraints.tight(Size(9.w, 35.h)),
                                width: 15.w,
                                height: 50.h,
                                color: Colors.blue,
                                child: Center(child: Icon(Icons.qr_code, size: 6.sp,)),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: 20.w,),
                        Column(
                          children: [
                            Text("Başlangıç Alanı", style: TextStyle(color: Colors.blue, fontSize: 3.5.sp ),),
                            SizedBox(height: 5.h),
                            Draggable<Map<String, dynamic>>(
                              data: {'type': 'startArea', 'index': incrementStartCount},
                              feedback: Container(
                                width: 15.w,
                                height: 50.h,
                                color: Colors.blue.withValues(alpha: 0.5),
                                child: Center(child: Icon(Icons.location_on, size: 6.w)),
                              ),
                              childWhenDragging: Container(
                                width: 15.w,
                                height: 50.h,
                                color: const Color.fromARGB(255, 103, 155, 197),
                                child: Center(child: Icon(Icons.location_on, size: 6.w)),
                              ), // Yapı türü
                              child: Container(
                                constraints: BoxConstraints.tight(Size(9.w, 35.h)),
                                width: 15.w,
                                height: 50.h,
                                color: Colors.blue,
                                child: Center(child: Icon(Icons.location_on, size: 6.w)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 40.h,),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Text("Yük Alanı", style: TextStyle(color: Colors.blue, fontSize: 3.5.sp ),),
                            SizedBox(height: 5.h),
                            Draggable<Map<String, dynamic>>(
                              data: {'type': 'cargoArea', 'name': getNextCargoAreaName},
                              feedback: Container(
                                width: 15.w,
                                height: 50.h,
                                color: Colors.blue.withValues(alpha: 0.5),
                                child: Center(child: Icon(Icons.archive_outlined, size: 6.w)),
                              ),
                              childWhenDragging: Container(
                                width: 15.w,
                                height: 50.h,
                                color: const Color.fromARGB(255, 103, 155, 197),
                                child: Center(child: Icon(Icons.archive_outlined, size: 6.w)),
                              ), // Yapı türü
                              child: Container(
                                constraints: BoxConstraints.tight(Size(9.w, 35.h)),
                                width: 15.w,
                                height: 50.h,
                                color: Colors.blue,
                                child: Center(child: Icon(Icons.archive_outlined, size: 6.w)),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: 20.w,),
                        Column(
                          children: [
                            Text("Şarj İstasyonu", style: TextStyle(color: Colors.blue, fontSize: 3.5.sp),),
                            SizedBox(height: 5.h),
                            Draggable<Map<String, dynamic>>(
                              data: {'type': 'chargeStation', 'index': chargeStationCount},
                              feedback: Container(
                                width: 15.w,
                                height: 50.h,
                                color: Colors.blue.withValues(alpha: 0.5),
                                child: Center(child: Icon(Icons.battery_charging_full, size: 5.w)),
                              ),
                              childWhenDragging: Container(
                                width: 15.w,
                                height: 50.h,
                                color: const Color.fromARGB(255, 103, 155, 197),
                                child: Center(child: Icon(Icons.battery_charging_full, size: 5.w)),
                              ), // Yapı türü
                              child: Container(
                                constraints: BoxConstraints.tight(Size(9.w, 35.h)),
                                width: 15.w,
                                height: 50.h,
                                color: Colors.blue,
                                child: Center(child: Icon(Icons.battery_charging_full, size: 5.w)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 15.h,),
                    Column(
                          children: [
                            Text("Yapıyı Sil", style: TextStyle(color: Colors.red, fontSize: 3.5.sp),),
                            SizedBox(height: 5.h),
                            Draggable<Map<String, dynamic>>(
                              data: const {'type': 'delete'},
                              feedback: Container(
                                width: 8.w,
                                height: 30.h,
                                color: Colors.red.withValues(alpha: 0.5),
                                child: Center(child: Icon(Icons.clear, size: 5.w)),
                              ),
                              childWhenDragging: Container(
                                width: 8.w,
                                height: 30.h,
                                color: const Color.fromARGB(255, 217, 144, 139),
                                child: Center(child: Icon(Icons.clear, size: 5.w)),
                              ), // Yapı türü
                              child: Container(
                                constraints: BoxConstraints.tight(Size(8.w, 30.h)),
                                width: 8.w,
                                height: 30.h,
                                color: Colors.redAccent,
                                child: Center(child: Icon(Icons.clear, size: 5.w)),
                              ),
                            ),
                          ],
                        ),
                  ],
                ),
              )
            )
          ],
        )
      ],
     ),
    );
  }
}
class DragTargetContainer extends StatefulWidget {
  const DragTargetContainer({
    super.key,
    required this.child,
    required this.index,
    required this.dataPoints,
    required this.incrementQRCount,
    required this.incrementChargeStationCount,
    required this.incrementStartCount,
    required this.getNextCargoAreaName,
    required this.decrementChargeStationCount,
    required this.decrementQRCount,
    required this.decrementStartCount,
    required this.getExCargoAreaName,
  });

  final Widget child;
  final int index;
  final List<DataPoint> dataPoints;
  final Function incrementQRCount;
  final Function incrementChargeStationCount;
  final Function getNextCargoAreaName;
  final Function incrementStartCount;
  final Function decrementChargeStationCount;
  final Function decrementQRCount;
  final Function decrementStartCount;
  final Function getExCargoAreaName;

  @override
  State<DragTargetContainer> createState() => _DragTargetContainerState();
}

class _DragTargetContainerState extends State<DragTargetContainer> {
  late Widget _child;
  late int localQrCount;
  late int localChargeStationCount;
  late int startAreaCount;
  late int xValue;
  late int yValue;
  late String cargoAreaName;
  int qrIndex = 0;
  String name = "";
  String qrName = "";

  @override
  void initState() {
    super.initState();
    _child = widget.child;
    if (_child != Container()){
      
    }
  }

  void handleCargoAreaDropped(String cargoAreaName) {
    // Bu fonksiyon, bir yük alanı bırakıldığında çağrılacak
    setState(() {
      _child = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.archive_outlined, size: 5.sp),
          Text(cargoAreaName, style: TextStyle(fontSize: 3.sp))
        ],
      );
    });
  }

  void calculatePosition(int index) {
    yValue = 16 - (index ~/ 29); // Inverted y calculation
    xValue = 28 - (index % 29); // Inverted x calculation based on 17 rows
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromARGB(255, 118, 118, 122),
      width: 10.w,
      height: 10.h,
      child: DragTarget<Map<String, dynamic>>(
        onAcceptWithDetails: (receivedData) {
          setState(() {
              if (receivedData.data['type'] == 'roadVertical') {
              _child = verticalRoad;
              } 
              else if (receivedData.data['type'] == 'roadHorizontal'){
                _child = horizontalRoad;
              }
              else if (receivedData.data['type'] == 'bottomToLeftRoad'){
                _child = bottomToLeftRoad;
              }
              else if (receivedData.data['type'] == 'bottomToRightRoad'){
                _child = bottomToRightRoad;
              }
              else if (receivedData.data['type'] == 'topToLeftRoad'){
                _child = topToLeftRoad;
              }
              else if (receivedData.data['type'] == 'topToRightRoad'){
                _child = topToRightRoad;
              }
              else if (receivedData.data['type'] == 'verticalToLeftRoad'){
                _child = verticalToLeftRoad;
              }
              else if (receivedData.data['type'] == 'verticalToRightRoad'){
                _child = verticalToRightRoad;
              }
              else if (receivedData.data['type'] == 'horizontalToTopRoad'){
                _child = horizontalToTopRoad;
              }
              else if (receivedData.data['type'] == 'horizontalToBottomRoad'){
                _child = horizontalToBottomRoad;
              }
              
              else if (receivedData.data['type'] == 'Q') {
                qrIndex = widget.incrementQRCount();
                name = qrIndex.toString();
                _child = Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code, size: 5.sp,),
                    Text(name, style: TextStyle(fontSize: 2.5.sp, fontWeight: FontWeight.w700),),
                  ],
                );
              }
              else if (receivedData.data['type'] == 'chargeStation'){
                localChargeStationCount = widget.incrementChargeStationCount();
                qrName = widget.incrementQRCount().toString();
                _child = Icon(Icons.battery_charging_full, size: 5.sp);
              }
              else if (receivedData.data['type'] == 'cargoArea'){
                qrName = widget.incrementQRCount().toString();
                String newCargoAreaName = widget.getNextCargoAreaName();
                name = newCargoAreaName;
                handleCargoAreaDropped(name);
              }
              else if (receivedData.data['type'] == 'startArea') {
                qrName = widget.incrementQRCount().toString();
                startAreaCount = widget.incrementStartCount();
                name = (startAreaCount).toString();
                _child = Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, size: 5.sp,),
                    Text(name, style: TextStyle(fontSize: 2.5.sp, fontWeight: FontWeight.w700),),
                  ],
                );
              }
              else if(receivedData.data['type'] == 'delete'){
                _child = Container();
              }

            calculatePosition(widget.index);
            if (receivedData.data['type'] == 'delete') {
              // İlgili konumdaki tüm elemanları silmek için listenin tersinden döngüye alın
              for (int i = widget.dataPoints.length - 1; i >= 0; i--) {
                if ((widget.dataPoints[i].x == xValue) && (widget.dataPoints[i].y == yValue)) {
                  if (widget.dataPoints[i].type.contains("Q")) {
                    int removedIndex = int.parse(widget.dataPoints[i].type.substring(1));
                    widget.decrementQRCount(removedIndex);
                  } else if (widget.dataPoints[i].type.contains("start")) {
                    widget.decrementStartCount();
                  } else if (widget.dataPoints[i].type.contains("charge")) {
                    widget.decrementChargeStationCount();
                  } else if (widget.dataPoints[i].type.contains("cargo")) {
                    widget.getExCargoAreaName();
                  }
                  widget.dataPoints.removeAt(i); // Tersinden döngü ile güvenli silme
                }
              }
            }

            else {
              if (receivedData.data['type'] != "Q" &&
               receivedData.data['type'] != 'roadVertical' &&
               receivedData.data['type'] != 'roadHorizontal' &&
               receivedData.data['type'] != 'bottomToLeftRoad' &&
               receivedData.data['type'] != 'bottomToRightRoad' &&
               receivedData.data['type'] != 'topToLeftRoad' &&
               receivedData.data['type'] != 'topToRightRoad' &&
               receivedData.data['type'] != 'verticalToLeftRoad' &&
               receivedData.data['type'] != 'verticalToRightRoad' &&
               receivedData.data['type'] != 'horizontalToTopRoad' &&
               receivedData.data['type'] != 'horizontalToBottomRoad'
              ){
                widget.dataPoints.add(DataPoint(type: ("Q$qrName"), x: xValue, y: yValue));
              }
              widget.dataPoints.add(DataPoint(type: (receivedData.data['type']+name), x: xValue, y: yValue));
            }
              
          });
        },
        builder: (context, candidateData, rejectedData) {
          return Container(
            width: 30.w,
            height: 50.h,
            color: const Color.fromARGB(255, 75, 76, 75).withValues(alpha: 1.0),
            child: _child,
          );
        },
      ),
    );
  }
}

class ConnectButton extends StatefulWidget {
  const ConnectButton({super.key, this.text = "", required this.onPressed});

  final VoidCallback onPressed;
  final String text;
  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton> {
  bool isOn = false;

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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _toggleState();
        widget.onPressed();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 60.h,
        width: 45.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          color: Colors.grey[850],
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
            width: 75.w,
            height: 65.h,
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 6.w),
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15.r),
              border: Border.all(
                color: isOn ? Colors.grey : Colors.blue,
                width: 1.w,
              ),
            ),
            child: AnimatedScale(
              scale: isOn ? 0.85 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Row(
                children: [
                  Icon(Icons.save, color: isOn? Colors.grey : Colors.blue, size: 6.sp,),
                  SizedBox(width: 1.w,),
                  Text(widget.text,
                      style: TextStyle(
                        color: isOn ? Colors.grey : Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 3.sp,
                      )
                   ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ResetButton extends StatefulWidget {
  const ResetButton({super.key, this.text = "", required this.onPressed});

  final VoidCallback onPressed;
  final String text;
  @override
  State<ResetButton> createState() => _ResetButtonState();
}

class _ResetButtonState extends State<ResetButton> {
  bool isOn = false;

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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _toggleState();
        widget.onPressed();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 60.h,
        width: 32.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          color: Colors.grey[850],
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
            width: 75.w,
            height: 65.h,
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 6.w),
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15.r),
              border: Border.all(
                color: isOn ? Colors.grey : Colors.red,
                width: 1.w,
              ),
            ),
            child: AnimatedScale(
              scale: isOn ? 0.85 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Row(
                children: [
                  Icon(Icons.delete, color: isOn? Colors.grey : Colors.red, size: 6.sp,),
                  SizedBox(width: 1.w,),
                  Text(widget.text,
                      style: TextStyle(
                        color: isOn ? Colors.grey : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 3.sp,
                      )
                   ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

