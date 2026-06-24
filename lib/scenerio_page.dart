import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'services/agv_service.dart';
import 'data_model.dart';

// ─── Renk sabitleri ────────────────────────────────────────────────────────
const _bg      = Color(0xFF121212);
const _panelBg = Color(0xFF1A1A1A);
const _borderC = Color(0xFF333333);
const _muted   = Color(0xFF9E9E9E);
const _bright  = Color(0xFFE0E0E0);
const _accent  = Color(0xFF42A5F5);

class ScenarioPage extends StatefulWidget {
  final List<DataPoint> dataPoints; // kullanılmıyor
  final String site;                // SUNUCU adresi burada
  final String rota;                // kullanılmıyor

  const ScenarioPage({
    super.key,
    required this.dataPoints,
    required this.site,
    required this.rota,
  });

  @override
  State<ScenarioPage> createState() => _ScenarioPageState();
}

class _ScenarioPageState extends State<ScenarioPage> {
  final List<String> _allPlaces = const [
    'A1', 'A2', 'A3', 'A4',
    'B1', 'B2', 'B3', 'B4',
    'S1', 'S2',
    'CS',
  ];

  final List<String> _selected = [];
  String arota = "";
  bool senaryoIsDone = false;

  final Map<String, String> _qrMap = const {
    'A1': 'QA1.1', 'A2': 'QA2.1', 'A3': 'QA3.1', 'A4': 'QA4.1',
    'B1': 'QB1.1', 'B2': 'QB2.1', 'B3': 'QB3.1', 'B4': 'QB4.1',
    'S1': 'S1.1',  'S2': 'S2.1',
    'CS': 'CS1.1',
  };

  @override
  void initState() {
    super.initState();
    senaryoIsDone = widget.rota.isNotEmpty;
  }

  void _addPlace(String code) => setState(() => _selected.add(code));

  void _undo() {
    if (_selected.isEmpty) return;
    setState(() => _selected.removeLast());
  }

  void _returnData() => Navigator.pop(context, arota);

  String _displayName(String code) {
    if (code == 'CS') return 'Şarj İstasyonu';
    return code;
  }

  List<Widget> _buildChipList() => _selected.map((code) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 1.h, horizontal: 1.5.w),
          child: Chip(
            label: Text(
              _displayName(code),
              style: TextStyle(color: _bright, fontSize: 3.sp, fontFamily: 'monospace'),
            ),
            backgroundColor: _panelBg,
            side: BorderSide(width: 0.5.w, color: _borderC),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.r)),
          ),
        );
      }).toList();

  String rotaOlustur(String from, String to) {
    return ""; // TODO
  }

  Future<void> veriBas(String veri) => AgvService.veriBas(widget.site, veri);

  Future<void> _buildScenarioAndSend() async {
    if (_selected.isEmpty) return;

    final parts = <String>[];

    int startIndex = 0;
    if (_selected.first.startsWith('S')) {
      startIndex = 1;
    }

    bool pickupNext = true;
    for (int i = startIndex; i < _selected.length; i++) {
      final p  = _selected[i];
      final qr = _qrMap[p] ?? p;

      if (p.startsWith('A') || p.startsWith('B')) {
        parts..add(qr)..add(pickupNext ? 'q' : 'e');
        pickupNext = !pickupNext;
      } else if (p.startsWith('S') || p == 'CS') {
        parts..add(qr)..add('null');
      }
    }

    setState(() {
      senaryoIsDone = true;
      arota = parts.join('/');
    });

    if (arota.isNotEmpty) {
      await veriBas("v$arota");
    }

    if (mounted) {
      Navigator.pop(context, arota);
    }
  }

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
          'SENARYO',
          style: TextStyle(
            color: Colors.white,
            fontSize: 4.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 7.sp, color: _muted),
          onPressed: () {
            if (senaryoIsDone) {
              _returnData();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          children: [
            // ── Seçilen istasyonlar ─────────────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.5.h),
              decoration: BoxDecoration(
                color: _panelBg,
                border: Border.all(color: _borderC, width: 0.5.w),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 2.w,
                      children: _buildChipList().isEmpty
                          ? [
                              Text(
                                'İstasyon seçin...',
                                style: TextStyle(color: const Color(0xFF444444), fontSize: 3.5.sp),
                              ),
                            ]
                          : _buildChipList(),
                    ),
                  ),
                  IconButton(
                    onPressed: _undo,
                    icon: Icon(Icons.undo, color: _muted, size: 6.sp),
                    tooltip: 'Geri al',
                  ),
                ],
              ),
            ),

            SizedBox(height: 4.h),

            // ── İstasyon seçim butonları ────────────────────────────────
            Expanded(
              child: Wrap(
                spacing: 2.w,
                runSpacing: 2.h,
                children: _allPlaces.map((code) {
                  final isCS   = code == 'CS';
                  final title  = isCS ? 'Şarj\nİstasyonu' : code;
                  final icon   = isCS ? Icons.battery_charging_full : Icons.place_outlined;

                  return SizedBox(
                    width: 50.w,
                    height: 85.h,
                    child: GestureDetector(
                      onTap: () => _addPlace(code),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _panelBg,
                          border: Border.all(color: _borderC, width: 0.5.w),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, color: _accent, size: 6.sp),
                            SizedBox(height: 1.h),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _bright,
                                fontSize: isCS ? 3.sp : 4.sp,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            SizedBox(height: 4.h),

            // ── Senaryo oluştur butonu ──────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 60.w,
                  height: 50.h,
                  child: GestureDetector(
                    onTap: _selected.isNotEmpty ? _buildScenarioAndSend : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selected.isNotEmpty
                            ? const Color(0xFF1A2540)
                            : _panelBg,
                        border: Border.all(
                          color: _selected.isNotEmpty
                              ? const Color(0xFF1565C0)
                              : _borderC,
                          width: 0.5.w,
                        ),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Center(
                        child: Text(
                          "SENARYO OLUŞTUR",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _selected.isNotEmpty ? _accent : _muted,
                            fontSize: 3.sp,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 3.h),

            // ── Senaryo çıktısı ─────────────────────────────────────────
            Container(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: _panelBg,
                border: Border.all(color: _borderC, width: 0.5.w),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                arota.isNotEmpty ? "v$arota" : "-- Senaryo Oluşmadı --",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: arota.isNotEmpty ? _accent : _muted,
                  fontSize: 4.sp,
                  fontFamily: 'monospace',
                ),
              ),
            ),

            SizedBox(height: 4.h),
          ],
        ),
      ),
    );
  }
}
