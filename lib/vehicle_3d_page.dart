import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class Vehicle3DPage extends StatefulWidget {
  const Vehicle3DPage({super.key});

  @override
  State<Vehicle3DPage> createState() {
    return _Vehicle3DPageState();
  }
}

class _Vehicle3DPageState extends State<Vehicle3DPage> { 
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "ARAÇ 3D",
          style: TextStyle(
              color: const Color.fromARGB(255, 255, 255, 255),
              fontSize: 4.sp,
              fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(vertical: 100.h,),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                //3D Araç fotoğrafı için
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.h,),
                  child: SizedBox(
                    width: 150.w,
                    height: 500.h,
                    child: Image.asset('assets/images/agv_vehicle.png',),
                  ),
                )
              ],
            ),
            Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20.r),
                    color: Colors.grey[800],
                    boxShadow: const [
                      BoxShadow(
                        color:  Color.fromARGB(179, 0, 0, 0) ,
                        blurRadius: 4,
                        spreadRadius: 4,
                        offset:Offset(0, 5),
                      ),
                    ],
                  ),
                  width: 60.w,
                  height: 90.h,
                  child: Card(
                    color: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: Colors.blue, width: 1.5.w),
                        borderRadius: BorderRadius.circular(15.r)),
                        child:  Center(
                          child: Text("ÖZELLİKLER",
                            style: TextStyle(
                            color: Colors.white,
                            fontSize: 5.sp,
                            fontWeight: FontWeight.w700))
                            ),
                    ),
                ),
                SizedBox(height: 50.h,),
                Row(
                  children: [
                   PropertyCard(cardName: "Max Hız", value: "1.46 m/sn"),
                   PropertyCard(cardName: "Kapasite", value: "400 kg"),
                   PropertyCard(cardName: "Max Pil Süresi", value: "3 saat 20 dakika")
                  ],
                ),
                Row(
                  children: [
                   PropertyCard(cardName: "Genişlik", value: "850 mm"),
                   PropertyCard(cardName: "Uzunluk", value: "950 mm"),
                   PropertyCard(cardName: "Yükseklik", value: "450 mm")
                  ],
                ),
                Row(
                  children: [
                   PropertyCard(cardName: "Taban Yüksekliği", value: "30 mm"),
                   PropertyCard(cardName: "Lift Yüksekliği", value: "100 mm"),
                   PropertyCard(cardName: "Çekme Kapasitesi", value: "500 kg")
                  ],
                ),
                Row(
                  children: [
                   PropertyCard(cardName: "Motor Gücü", value: "500W"),
                   PropertyCard(cardName: "Haberleşme Mesafesi", value: "70 m"),
                   PropertyCard(cardName: "Çalışma Gerilimi", value: "24V")
                  ],
                ),
              ],
            ),
            
          ],
        ),
      ),
    );
  }
}

class PropertyCard extends StatefulWidget{
  PropertyCard({super.key, required this.cardName, required this.value});
  final String cardName;
  final String value;

  State<PropertyCard> createState(){
    return _PropertyCardState();
  }
}

class _PropertyCardState extends State<PropertyCard> {

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 7.h),
      child: SizedBox(
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
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Center(
                        child: Text(
                          widget.cardName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 4.sp,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 50.w,
                      ),
                      Text(
                        widget.value,
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 5.sp
                        ),
                      )
                    ],
                  ),
                ],
              )
            ),
          ),
        ),
    );
  }
}