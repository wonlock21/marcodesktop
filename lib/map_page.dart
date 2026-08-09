import 'data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';

// ??? GCS tema sabitleri ???????????????????????????????????????????????????
const _mpBg = Color(0xFF121212);
const _mpPanel = Color(0xFF1A1A1A);
const _mpBorder = Color(0xFF333333);
const _mpMuted = Color(0xFF9E9E9E);
const _mpBright = Color(0xFFE0E0E0);
const _mpAccent = Color(0xFF42A5F5);
const _mpDanger = Color(0xFFEF5350);
const _mpRoad =
    Color(0xFF546E7A); // yol ?izgisi rengi (koyu zemin ?zerinde g?r?n?r)

var verticalRoad = Center(
    child: SizedBox(
        width: 0.5.w, height: 50.h, child: const ColoredBox(color: _mpRoad)));
var horizontalRoad = Center(
    child: SizedBox(
        width: 15.w, height: 2.h, child: const ColoredBox(color: _mpRoad)));
var halfVerticalRoadFromEdge = Align(
  alignment: Alignment.topCenter,
  child: FractionallySizedBox(
      heightFactor: 0.5,
      child: Container(
        width: 0.5.w,
        color: _mpRoad,
      )),
);
var halfHorizontalRoadFromEdge = Align(
  alignment: Alignment.centerLeft,
  child: FractionallySizedBox(
      widthFactor: 0.5,
      child: Container(
        height: 2.h,
        color: _mpRoad,
      )),
);

var topToLeftRoad = Stack(
  alignment: Alignment.center,
  children: [halfVerticalRoadFromEdge, halfHorizontalRoadFromEdge],
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
  children: [verticalRoad, halfHorizontalRoadFromEdge],
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
  // eskiden top-level global olan de?i?kenler ? art?k instance field
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
    } else {
      for (int i = 0; i < dataPoints.length; i++) {
        if (dataPoints[i].type.contains("Q")) {
          if (qrCount < int.parse(dataPoints[i].type.substring(1))) {
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
    deletedQRIndices
        .sort(); // Keep the list sorted for reusing the smallest index
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

  Widget specialWidget(int ind) {
    dataPoints.add(lastDataPoints[ind]);

    if (lastDataPoints[ind].type.contains("Q")) {
      //incrementQRCount();
      qrTemp = int.parse(lastDataPoints[ind].type.substring(1));
      if (qrTemp > qrCount) {
        qrCount = qrTemp;
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.qr_code,
            size: 5.sp,
          ),
          Text(
            lastDataPoints[ind].type.substring(1),
            style: TextStyle(fontSize: 2.5.sp, fontWeight: FontWeight.w700),
          ),
        ],
      );
    } else if (lastDataPoints[ind].type.contains("roadVertical")) {
      return verticalRoad;
    } else if (lastDataPoints[ind].type.contains("roadHorizontal")) {
      return horizontalRoad;
    } else if (lastDataPoints[ind].type.contains("topToLeftRoad")) {
      return topToLeftRoad;
    } else if (lastDataPoints[ind].type.contains("topToRightRoad")) {
      return topToRightRoad;
    } else if (lastDataPoints[ind].type.contains("bottomToRightRoad")) {
      return bottomToRightRoad;
    } else if (lastDataPoints[ind].type.contains("bottomToLeftRoad")) {
      return bottomToLeftRoad;
    } else if (lastDataPoints[ind].type.contains("verticalToRightRoad")) {
      return verticalToRightRoad;
    } else if (lastDataPoints[ind].type.contains("verticalToLeftRoad")) {
      return verticalToLeftRoad;
    } else if (lastDataPoints[ind].type.contains("horizontalToTopRoad")) {
      return horizontalToTopRoad;
    } else if (lastDataPoints[ind].type.contains("horizontalToBottomRoad")) {
      return horizontalToBottomRoad;
    } else if (lastDataPoints[ind].type.contains("start")) {
      //startArea1
      incrementStartCount();
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on,
            size: 5.sp,
          ),
          Text(
            lastDataPoints[ind].type.substring(9),
            style: TextStyle(fontSize: 2.5.sp, fontWeight: FontWeight.w700),
          ),
        ],
      );
    } else if (lastDataPoints[ind].type.contains("charge")) {
      incrementChargeStationCount();
      return Icon(Icons.battery_charging_full, size: 5.sp);
    } else if (lastDataPoints[ind].type.startsWith("pickupPoint")) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.file_upload_outlined, size: 5.sp, color: _mpAccent),
            Text(lastDataPoints[ind].type.substring(11),
                style: TextStyle(fontSize: 3.sp, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    } else if (lastDataPoints[ind].type.startsWith("dropoffPoint")) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.file_download_outlined, size: 5.sp, color: _mpDanger),
            Text(lastDataPoints[ind].type.substring(12),
                style: TextStyle(fontSize: 3.sp, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    } else if (lastDataPoints[ind].type.contains("cargo")) {
      //cargoAreaA
      getNextCargoAreaName();
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.archive_outlined, size: 5.sp),
          Text(lastDataPoints[ind].type.substring(9),
              style: TextStyle(fontSize: 3.sp))
        ],
      );
    } else {
      return const ColoredBox(color: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    lastDataPoints = Provider.of<DataModel>(context, listen: false).dataPoints;

    return Scaffold(
      backgroundColor: _mpBg,
      appBar: AppBar(
        backgroundColor: _mpPanel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(0.3.h),
          child: Divider(height: 0.3.h, color: _mpBorder),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 6.sp, color: _mpMuted),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'HARİTA EDİTÖRÜ (ESKİ)',
          style: TextStyle(
            color: _mpBright,
            fontSize: 4.sp,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
            letterSpacing: 0.8,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 3.w),
            child: Center(
              child: Text(
                'Yedek grid editör — düğüm öğretme: DÜĞÜMLER',
                style: TextStyle(color: _mpMuted, fontSize: 2.4.sp),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Haritay? yerle?tir.
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                  width: 250.w,
                  height: 610.h,
                  child: GridView.builder(
                    addRepaintBoundaries: false,
                    itemCount: 493,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 29, // Kare say?s?
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      bool isEmpty = true;
                      int ind = 0;
                      bool invisibleQR = false;

                      for (int i = 0; i < lastDataPoints.length; i++) {
                        int localIndex = (16 - lastDataPoints[i].y) * 29 +
                            (28 - lastDataPoints[i].x);

                        if (localIndex == index) {
                          // Ayn? x ve y de?erlerine sahip di?er veri noktalar?n? kontrol edin
                          for (int k = 0; k < lastDataPoints.length; k++) {
                            if (k != i &&
                                lastDataPoints[i].x == lastDataPoints[k].x &&
                                lastDataPoints[i].y == lastDataPoints[k].y) {
                              invisibleQR = true;
                              // QR kodunu arka planda ekleyin
                              if (lastDataPoints[i].type.contains("Q")) {
                                dataPoints.add(lastDataPoints[i]);
                              } else {
                                isEmpty = false;
                                ind = i;
                              }
                              break;
                            }
                          }

                          // E?er QR kodu gizlenmi?se, di?er elemanlardan birini g?ster
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
                        incrementChargeStationCount:
                            incrementChargeStationCount,
                        getNextCargoAreaName: getNextCargoAreaName,
                        incrementStartCount: incrementStartCount,
                        decrementQRCount: decrementQRCount,
                        decrementChargeStationCount:
                            decrementChargeStationCount,
                        decrementStartCount: decrementStartCount,
                        getExCargoAreaName: getExCargoAreaName,
                        child: isEmpty ? Container() : specialWidget(ind),
                      );
                    },
                  ))
            ],
          ),
          // Yap? Men?s?n? yerle?tir.
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  _GcsFlatButton(
                    text: "HAR?TAYI KAYDET",
                    icon: Icons.save_outlined,
                    color: _mpAccent,
                    onPressed: () async {
                      final dataModel =
                          Provider.of<DataModel>(context, listen: false);
                      await dataModel
                          .clearDataPoints(); // ?nceki verileri temizleyin
                      for (var dataPoint in dataPoints) {
                        dataModel.addDataPoint(dataPoint);
                      }
                      await dataModel.saveDataPoints();
                      if (!context.mounted) return;
                      lastDataPoints = dataModel.dataPoints;
                      Navigator.pop(context, 'controller-page');
                    },
                  ),
                  SizedBox(
                    width: 3.w,
                  ),
                  _GcsFlatButton(
                    text: "SIFIRLA",
                    icon: Icons.restart_alt,
                    color: _mpDanger,
                    onPressed: () async {
                      await Provider.of<DataModel>(context, listen: false)
                          .clearDataPoints();
                      if (!context.mounted) return;
                      lastDataPoints = [];
                      Navigator.pop(context, 'controller-page');
                    },
                  )
                ],
              ),
              SizedBox(height: 3.h),
              Text(
                'YAPILAR',
                style: TextStyle(
                  color: _mpMuted,
                  fontSize: 3.sp,
                  fontFamily: 'monospace',
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1.5.h),
              SizedBox(
                  width: 100.w,
                  height: 500.h,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _mpPanel,
                      border: Border.all(color: _mpBorder, width: 0.4.w),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 2.w,
                                ),
                                Text(
                                  'YOL',
                                  style: TextStyle(
                                      color: _mpAccent,
                                      fontSize: 3.sp,
                                      fontFamily: 'monospace',
                                      letterSpacing: 1.0),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 50.h,
                            ),
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
                                SizedBox(
                                  width: 10.w,
                                ),
                                //?kili yollar
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
                                          data: const {
                                            'type': 'topToRightRoad'
                                          },
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
                                          data: const {
                                            'type': 'bottomToLeftRoad'
                                          },
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
                                          data: const {
                                            'type': 'bottomToRightRoad'
                                          },
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
                                SizedBox(
                                  width: 10.w,
                                ),
                                //??l? yollar
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        Draggable<Map<String, dynamic>>(
                                          data: const {
                                            'type': 'horizontalToTopRoad'
                                          },
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
                                          data: const {
                                            'type': 'horizontalToBottomRoad'
                                          },
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
                                          data: const {
                                            'type': 'verticalToLeftRoad'
                                          },
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
                                          data: const {
                                            'type': 'verticalToRightRoad'
                                          },
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
                        SizedBox(
                          height: 40.h,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                SizedBox(
                                  width: 15.w,
                                ),
                                Text(
                                  'QR NOKTASI',
                                  style: TextStyle(
                                      color: _mpAccent,
                                      fontSize: 2.8.sp,
                                      fontFamily: 'monospace'),
                                ),
                                SizedBox(height: 5.h),
                                Draggable<Map<String, dynamic>>(
                                  data: {'type': 'Q', 'index': qrCount},
                                  feedback: Container(
                                      width: 15.w,
                                      height: 50.h,
                                      color: const Color(0xFF42A5F5)
                                          .withAlpha(120),
                                      child: Center(
                                          child: Icon(
                                        Icons.qr_code,
                                        size: 6.sp,
                                      ))),
                                  childWhenDragging: Container(
                                      width: 15.w,
                                      height: 50.h,
                                      color: const Color(0xFF1A3A5C),
                                      child: Center(
                                          child: Icon(
                                        Icons.qr_code,
                                        size: 6.sp,
                                      ))), // Yap? t?r?
                                  child: Container(
                                    constraints:
                                        BoxConstraints.tight(Size(9.w, 35.h)),
                                    width: 15.w,
                                    height: 50.h,
                                    color: const Color(0xFF42A5F5),
                                    child: Center(
                                        child: Icon(
                                      Icons.qr_code,
                                      size: 6.sp,
                                    )),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              width: 20.w,
                            ),
                            Column(
                              children: [
                                Text(
                                  'BA?LANGI?',
                                  style: TextStyle(
                                      color: _mpAccent,
                                      fontSize: 2.8.sp,
                                      fontFamily: 'monospace'),
                                ),
                                SizedBox(height: 5.h),
                                Draggable<Map<String, dynamic>>(
                                  data: {
                                    'type': 'startArea',
                                    'index': incrementStartCount
                                  },
                                  feedback: Container(
                                    width: 15.w,
                                    height: 50.h,
                                    color:
                                        const Color(0xFF42A5F5).withAlpha(120),
                                    child: Center(
                                        child:
                                            Icon(Icons.location_on, size: 6.w)),
                                  ),
                                  childWhenDragging: Container(
                                    width: 15.w,
                                    height: 50.h,
                                    color: const Color(0xFF1A3A5C),
                                    child: Center(
                                        child:
                                            Icon(Icons.location_on, size: 6.w)),
                                  ), // Yap? t?r?
                                  child: Container(
                                    constraints:
                                        BoxConstraints.tight(Size(9.w, 35.h)),
                                    width: 15.w,
                                    height: 50.h,
                                    color: const Color(0xFF42A5F5),
                                    child: Center(
                                        child:
                                            Icon(Icons.location_on, size: 6.w)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 40.h,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                Text(
                                  'YÜK ALMA',
                                  style: TextStyle(
                                      color: _mpAccent,
                                      fontSize: 2.8.sp,
                                      fontFamily: 'monospace'),
                                ),
                                SizedBox(height: 5.h),
                                Draggable<Map<String, dynamic>>(
                                  data: const {
                                    'type': 'pickupPoint',
                                  },
                                  feedback: Container(
                                    width: 15.w,
                                    height: 50.h,
                                    color:
                                        const Color(0xFF42A5F5).withAlpha(120),
                                    child: Center(
                                        child: Icon(Icons.file_upload_outlined,
                                            size: 6.w)),
                                  ),
                                  childWhenDragging: Container(
                                    width: 15.w,
                                    height: 50.h,
                                    color: const Color(0xFF1A3A5C),
                                    child: Center(
                                        child: Icon(Icons.file_upload_outlined,
                                            size: 6.w)),
                                  ), // Yap? t?r?
                                  child: Container(
                                    constraints:
                                        BoxConstraints.tight(Size(9.w, 35.h)),
                                    width: 15.w,
                                    height: 50.h,
                                    color: const Color(0xFF42A5F5),
                                    child: Center(
                                        child: Icon(Icons.file_upload_outlined,
                                            size: 6.w)),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              width: 10.w,
                            ),
                            Column(
                              children: [
                                Text(
                                  'YÜK BIRAKMA',
                                  style: TextStyle(
                                      color: _mpDanger,
                                      fontSize: 2.8.sp,
                                      fontFamily: 'monospace'),
                                ),
                                SizedBox(height: 5.h),
                                Draggable<Map<String, dynamic>>(
                                  data: const {'type': 'dropoffPoint'},
                                  feedback: Container(
                                    width: 15.w,
                                    height: 50.h,
                                    color:
                                        const Color(0xFFEF5350).withAlpha(120),
                                    child: Center(
                                        child: Icon(Icons.file_download_outlined,
                                            size: 6.w)),
                                  ),
                                  childWhenDragging: Container(
                                    width: 15.w,
                                    height: 50.h,
                                    color: const Color(0xFF3A1A1A),
                                    child: Center(
                                        child: Icon(Icons.file_download_outlined,
                                            size: 6.w)),
                                  ),
                                  child: Container(
                                    constraints:
                                        BoxConstraints.tight(Size(9.w, 35.h)),
                                    width: 15.w,
                                    height: 50.h,
                                    color: const Color(0xFFEF5350),
                                    child: Center(
                                        child: Icon(Icons.file_download_outlined,
                                            size: 6.w)),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              width: 10.w,
                            ),
                            Column(
                              children: [
                                Text(
                                  '?ARJ ?STASYONU',
                                  style: TextStyle(
                                      color: _mpAccent,
                                      fontSize: 2.8.sp,
                                      fontFamily: 'monospace'),
                                ),
                                SizedBox(height: 5.h),
                                Draggable<Map<String, dynamic>>(
                                  data: {
                                    'type': 'chargeStation',
                                    'index': chargeStationCount
                                  },
                                  feedback: Container(
                                    width: 15.w,
                                    height: 50.h,
                                    color:
                                        const Color(0xFF42A5F5).withAlpha(120),
                                    child: Center(
                                        child: Icon(Icons.battery_charging_full,
                                            size: 5.w)),
                                  ),
                                  childWhenDragging: Container(
                                    width: 15.w,
                                    height: 50.h,
                                    color: const Color(0xFF1A3A5C),
                                    child: Center(
                                        child: Icon(Icons.battery_charging_full,
                                            size: 5.w)),
                                  ), // Yap? t?r?
                                  child: Container(
                                    constraints:
                                        BoxConstraints.tight(Size(9.w, 35.h)),
                                    width: 15.w,
                                    height: 50.h,
                                    color: const Color(0xFF42A5F5),
                                    child: Center(
                                        child: Icon(Icons.battery_charging_full,
                                            size: 5.w)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 15.h,
                        ),
                        Column(
                          children: [
                            Text(
                              'YAPIYI S?L',
                              style: TextStyle(
                                  color: _mpDanger,
                                  fontSize: 2.8.sp,
                                  fontFamily: 'monospace'),
                            ),
                            SizedBox(height: 5.h),
                            Draggable<Map<String, dynamic>>(
                              data: const {'type': 'delete'},
                              feedback: Container(
                                width: 8.w,
                                height: 30.h,
                                color: const Color(0xFFEF5350).withAlpha(120),
                                child:
                                    Center(child: Icon(Icons.clear, size: 5.w)),
                              ),
                              childWhenDragging: Container(
                                width: 8.w,
                                height: 30.h,
                                color: const Color(0xFF3A1A1A),
                                child:
                                    Center(child: Icon(Icons.clear, size: 5.w)),
                              ), // Yap? t?r?
                              child: Container(
                                constraints:
                                    BoxConstraints.tight(Size(8.w, 30.h)),
                                width: 8.w,
                                height: 30.h,
                                color: const Color(0xFF2A0A0A),
                                child:
                                    Center(child: Icon(Icons.clear, size: 5.w)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ))
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
    if (_child != Container()) {}
  }

  void handleCargoAreaDropped(String cargoAreaName) {
    // Bu fonksiyon, bir y?k alan? b?rak?ld???nda ?a?r?lacak
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

  String _nextMissionPointName(String typePrefix, String labelPrefix) {
    final used = <int>{};
    for (final point in widget.dataPoints) {
      if (!point.type.startsWith(typePrefix)) continue;
      final label = point.type.substring(typePrefix.length);
      if (!label.startsWith(labelPrefix)) continue;
      final number = int.tryParse(label.substring(labelPrefix.length));
      if (number != null) used.add(number);
    }
    var next = 1;
    while (used.contains(next)) {
      next++;
    }
    return '$labelPrefix$next';
  }

  void _showMissionPoint(String label, {required bool pickup}) {
    _child = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            pickup ? Icons.file_upload_outlined : Icons.file_download_outlined,
            size: 5.sp,
            color: pickup ? _mpAccent : _mpDanger,
          ),
          Text(label,
              style: TextStyle(fontSize: 3.sp, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  void calculatePosition(int index) {
    yValue = 16 - (index ~/ 29); // Inverted y calculation
    xValue = 28 - (index % 29); // Inverted x calculation based on 17 rows
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      width: 10.w,
      height: 10.h,
      child: DragTarget<Map<String, dynamic>>(
        onAcceptWithDetails: (receivedData) {
          setState(() {
            if (receivedData.data['type'] == 'roadVertical') {
              _child = verticalRoad;
            } else if (receivedData.data['type'] == 'roadHorizontal') {
              _child = horizontalRoad;
            } else if (receivedData.data['type'] == 'bottomToLeftRoad') {
              _child = bottomToLeftRoad;
            } else if (receivedData.data['type'] == 'bottomToRightRoad') {
              _child = bottomToRightRoad;
            } else if (receivedData.data['type'] == 'topToLeftRoad') {
              _child = topToLeftRoad;
            } else if (receivedData.data['type'] == 'topToRightRoad') {
              _child = topToRightRoad;
            } else if (receivedData.data['type'] == 'verticalToLeftRoad') {
              _child = verticalToLeftRoad;
            } else if (receivedData.data['type'] == 'verticalToRightRoad') {
              _child = verticalToRightRoad;
            } else if (receivedData.data['type'] == 'horizontalToTopRoad') {
              _child = horizontalToTopRoad;
            } else if (receivedData.data['type'] == 'horizontalToBottomRoad') {
              _child = horizontalToBottomRoad;
            } else if (receivedData.data['type'] == 'Q') {
              qrIndex = widget.incrementQRCount();
              name = qrIndex.toString();
              _child = Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code,
                    size: 5.sp,
                  ),
                  Text(
                    name,
                    style: TextStyle(
                        fontSize: 2.5.sp, fontWeight: FontWeight.w700),
                  ),
                ],
              );
            } else if (receivedData.data['type'] == 'chargeStation') {
              localChargeStationCount = widget.incrementChargeStationCount();
              qrName = widget.incrementQRCount().toString();
              _child = Icon(Icons.battery_charging_full, size: 5.sp);
            } else if (receivedData.data['type'] == 'pickupPoint') {
              qrName = widget.incrementQRCount().toString();
              name = _nextMissionPointName('pickupPoint', 'A');
              _showMissionPoint(name, pickup: true);
            } else if (receivedData.data['type'] == 'dropoffPoint') {
              qrName = widget.incrementQRCount().toString();
              name = _nextMissionPointName('dropoffPoint', 'B');
              _showMissionPoint(name, pickup: false);
            } else if (receivedData.data['type'] == 'cargoArea') {
              qrName = widget.incrementQRCount().toString();
              String newCargoAreaName = widget.getNextCargoAreaName();
              name = newCargoAreaName;
              handleCargoAreaDropped(name);
            } else if (receivedData.data['type'] == 'startArea') {
              qrName = widget.incrementQRCount().toString();
              startAreaCount = widget.incrementStartCount();
              name = (startAreaCount).toString();
              _child = Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 5.sp,
                  ),
                  Text(
                    name,
                    style: TextStyle(
                        fontSize: 2.5.sp, fontWeight: FontWeight.w700),
                  ),
                ],
              );
            } else if (receivedData.data['type'] == 'delete') {
              _child = Container();
            }

            calculatePosition(widget.index);
            if (receivedData.data['type'] == 'delete') {
              // ?lgili konumdaki t?m elemanlar? silmek i?in listenin tersinden d?ng?ye al?n
              for (int i = widget.dataPoints.length - 1; i >= 0; i--) {
                if ((widget.dataPoints[i].x == xValue) &&
                    (widget.dataPoints[i].y == yValue)) {
                  if (widget.dataPoints[i].type.contains("Q")) {
                    int removedIndex =
                        int.parse(widget.dataPoints[i].type.substring(1));
                    widget.decrementQRCount(removedIndex);
                  } else if (widget.dataPoints[i].type.contains("start")) {
                    widget.decrementStartCount();
                  } else if (widget.dataPoints[i].type.contains("charge")) {
                    widget.decrementChargeStationCount();
                  } else if (widget.dataPoints[i].type.contains("cargo")) {
                    widget.getExCargoAreaName();
                  }
                  widget.dataPoints
                      .removeAt(i); // Tersinden d?ng? ile g?venli silme
                }
              }
            } else {
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
                  receivedData.data['type'] != 'horizontalToBottomRoad') {
                widget.dataPoints
                    .add(DataPoint(type: ("Q$qrName"), x: xValue, y: yValue));
              }
              final droppedType = receivedData.data['type'] as String;
              String? rosNodeName;
              if (droppedType == 'pickupPoint') {
                rosNodeName = 'alma_${name.substring(1)}';
              } else if (droppedType == 'dropoffPoint') {
                rosNodeName = 'birak_${name.substring(1)}';
              }
              widget.dataPoints.add(DataPoint(
                type: droppedType + name,
                x: xValue,
                y: yValue,
                rosNodeName: rosNodeName,
              ));
            }
          });
        },
        builder: (context, candidateData, rejectedData) {
          return Container(
            width: 30.w,
            height: 50.h,
            decoration: BoxDecoration(
              color: candidateData.isNotEmpty
                  ? _mpAccent.withAlpha(40)
                  : const Color(0xFF1A1A1A),
              border: Border.all(
                color: candidateData.isNotEmpty
                    ? _mpAccent.withAlpha(160)
                    : const Color(0xFF282828),
                width: 0.3,
              ),
            ),
            child: _child,
          );
        },
      ),
    );
  }
}

// ??? Flat GCS buton (ConnectButton + ResetButton için ortak) ?????????????
class _GcsFlatButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _GcsFlatButton({
    required this.text,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_GcsFlatButton> createState() => _GcsFlatButtonState();
}

class _GcsFlatButtonState extends State<_GcsFlatButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 1.4.h),
        decoration: BoxDecoration(
          color: _pressed
              ? widget.color.withAlpha(50)
              : widget.color.withAlpha(20),
          border: Border.all(
            color: widget.color.withAlpha(_pressed ? 220 : 140),
            width: 0.5.w,
          ),
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 4.sp, color: widget.color),
            SizedBox(width: 1.2.w),
            Text(
              widget.text,
              style: TextStyle(
                color: widget.color,
                fontSize: 3.sp,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Geriye dönük uyumluluk için wrapper sınıflar
class ConnectButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const ConnectButton({super.key, this.text = '', required this.onPressed});

  @override
  Widget build(BuildContext context) => _GcsFlatButton(
        text: text,
        icon: Icons.save_outlined,
        color: _mpAccent,
        onPressed: onPressed,
      );
}

class ResetButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  const ResetButton({super.key, this.text = '', required this.onPressed});

  @override
  Widget build(BuildContext context) => _GcsFlatButton(
        text: text,
        icon: Icons.restart_alt,
        color: _mpDanger,
        onPressed: onPressed,
      );
}
