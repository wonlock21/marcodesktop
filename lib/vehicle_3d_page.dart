import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ─── Renk sabitleri ────────────────────────────────────────────────────────
const _bg = Color(0xFF121212);
const _panelBg = Color(0xFF1A1A1A);
const _borderC = Color(0xFF333333);
const _muted = Color(0xFF9E9E9E);
const _bright = Color(0xFFE0E0E0);
const _accent = Color(0xFF42A5F5);

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
        padding:
            EdgeInsets.only(top: 120.h, bottom: 6.h, left: 4.w, right: 4.w),
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
            // Özellikler paneli — genişliği 202.w ile sabitle
            SizedBox(
              width: 202.w,
              child: Column(
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
                  // ── Mekanik / Güç Özellikleri ─────────────────────────
                  const Row(
                    children: [
                      PropertyCard(cardName: "Max Hız", value: "1.46 m/sn"),
                      PropertyCard(cardName: "Kapasite", value: "--"),
                      PropertyCard(cardName: "Max Pil Süresi", value: "--"),
                    ],
                  ),
                  const Row(
                    children: [
                      PropertyCard(cardName: "Genişlik", value: "850 mm"),
                      PropertyCard(cardName: "Uzunluk", value: "950 mm"),
                      PropertyCard(cardName: "Yükseklik", value: "450 mm"),
                    ],
                  ),
                  const Row(
                    children: [
                      PropertyCard(cardName: "Taban Yük.", value: "30 mm"),
                      PropertyCard(cardName: "Lift Yük.", value: "100 mm"),
                      PropertyCard(cardName: "Çekme Kap.", value: "--"),
                    ],
                  ),
                  const Row(
                    children: [
                      PropertyCard(cardName: "Motor Gücü", value: "500 W"),
                      PropertyCard(cardName: "Haberleşme", value: "--"),
                      PropertyCard(cardName: "Çalışma V.", value: "24 V"),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  // ── Sistem Bileşenleri ─────────────────────────────────
                  _ComponentsPanel(),
                ],
              ), // Column
            ), // SizedBox(width: 202.w)
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2026 Sistem Bileşenleri Paneli
// ─────────────────────────────────────────────────────────────────────────────

class _ComponentsPanel extends StatelessWidget {
  static const _items = [
    ('İşlemci', 'Orange Pi 5'),
    ('Alt Kontrol', 'STM32-Nucleo'),
    ('LiDAR', 'RPLiDAR A3'),
    ('Kamera', 'IMX219'),
    ('QR Okuyucu', 'GM67 USB'),
    ('Akım/Voltaj', 'Max471'),
    ('Bluetooth', 'HC06'),
    ('Motor Sürücü', 'BTS7960B'),
    ('İşletim Sistemi', 'ROS 2 / Nav2'),
    ('Haritalama', 'SLAM Toolbox'),
    ('Görüntü', 'OpenCV'),
    ('Geliştirme', 'STM32CubeIDE'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 202.w,
          height: 18.h,
          decoration: BoxDecoration(
            color: _panelBg,
            border: Border.all(color: _borderC, width: 0.5.w),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Center(
            child: Text(
              'SİSTEM BİLEŞENLERİ — 2026',
              style: TextStyle(
                color: _bright,
                fontSize: 3.5.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
        SizedBox(height: 1.5.h),
        Wrap(
          spacing: 1.w,
          runSpacing: 1.2.h,
          children: _items.map(((String label, String value) item) {
            return Container(
              width: 99.w,
              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: _panelBg,
                border: Border.all(color: _borderC, width: 0.4.w),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.$1,
                    style: TextStyle(color: _muted, fontSize: 2.6.sp),
                  ),
                  Flexible(
                    child: Text(
                      item.$2,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _accent,
                        fontSize: 2.8.sp,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
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
