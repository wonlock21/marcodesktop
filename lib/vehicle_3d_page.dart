import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ─── Renk sabitleri ────────────────────────────────────────────────────────
const _bg      = Color(0xFF121212);
const _panelBg = Color(0xFF1A1A1A);
const _borderC = Color(0xFF333333);
const _muted   = Color(0xFF9E9E9E);
const _bright  = Color(0xFFE0E0E0);
const _accent  = Color(0xFF42A5F5);

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
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _panelBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(0.3.h),
          child: Divider(height: 0.3.h, color: _borderC),
        ),
        title: Text(
          "ARAÇ 3D",
          style: TextStyle(
            color: Colors.white,
            fontSize: 4.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Araç görseli
            SizedBox(
              width: 150.w,
              height: 520.h,
              child: Image.asset('assets/images/agv_vehicle.png'),
            ),
            SizedBox(width: 6.w),
            // Özellikler paneli
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık bandı
                Container(
                  width: 202.w,
                  height: 22.h,
                  decoration: BoxDecoration(
                    color: _panelBg,
                    border: Border.all(color: _borderC, width: 0.5.w),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Center(
                    child: Text(
                      "ÖZELLİKLER",
                      style: TextStyle(
                        color: _bright,
                        fontSize: 4.5.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 3.h),
                const Row(
                  children: [
                    PropertyCard(cardName: "Max Hız",        value: "1.46 m/sn"),
                    PropertyCard(cardName: "Kapasite",       value: "400 kg"),
                    PropertyCard(cardName: "Max Pil Süresi", value: "3 sa 20 dk"),
                  ],
                ),
                const Row(
                  children: [
                    PropertyCard(cardName: "Genişlik",       value: "850 mm"),
                    PropertyCard(cardName: "Uzunluk",        value: "950 mm"),
                    PropertyCard(cardName: "Yükseklik",      value: "450 mm"),
                  ],
                ),
                const Row(
                  children: [
                    PropertyCard(cardName: "Taban Yük.",     value: "30 mm"),
                    PropertyCard(cardName: "Lift Yük.",      value: "100 mm"),
                    PropertyCard(cardName: "Çekme Kap.",     value: "500 kg"),
                  ],
                ),
                const Row(
                  children: [
                    PropertyCard(cardName: "Motor Gücü",     value: "500 W"),
                    PropertyCard(cardName: "Haberleşme",     value: "70 m"),
                    PropertyCard(cardName: "Çalışma V.",     value: "24 V"),
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

class PropertyCard extends StatefulWidget {
  const PropertyCard({super.key, required this.cardName, required this.value});
  final String cardName;
  final String value;

  @override
  State<PropertyCard> createState() {
    return _PropertyCardState();
  }
}

class _PropertyCardState extends State<PropertyCard> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 1.5.h),
      child: Container(
        width: 64.w,
        height: 70.h,
        decoration: BoxDecoration(
          color: _panelBg,
          border: Border.all(color: _borderC, width: 0.5.w),
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.cardName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 3.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: 1.5.h),
            Text(
              widget.value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _accent,
                fontSize: 4.5.sp,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
