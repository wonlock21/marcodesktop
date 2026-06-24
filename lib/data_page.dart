import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'admin_mode.dart';

// ─── Renk sabitleri ────────────────────────────────────────────────────────
const _bg      = Color(0xFF121212);
const _panelBg = Color(0xFF1A1A1A);
const _borderC = Color(0xFF333333);
const _muted   = Color(0xFF9E9E9E);
const _bright  = Color(0xFFE0E0E0);
const _accent  = Color(0xFF42A5F5);

class DataPage extends StatefulWidget {
  final String site;

  const DataPage({super.key, required this.site});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  List<String> pinData = ["-", "-", "-", "-", "-", "-", "-", "-"];

  @override
  void initState() {
    super.initState();
    // GEÇİCİ admin/demo modu: cihaz yokken rapor için örnek QTR verisi bas.
    if (kAdminMode && widget.site.isEmpty) {
      pinData = ["512", "498", "873", "61", "44", "905", "517", "488"];
    }
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (widget.site.isNotEmpty) {
      try {
        var response = await http.get(Uri.parse('${widget.site}/qtr'));
        if (response.statusCode == 200) {
          if (!mounted) return;
          setState(() {
            pinData = response.body.split("/");
          });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          pinData = ["-", "-", "-", "-", "-", "-", "-", "-"];
        });
        debugPrint('Bir hata oluştu: $e');
      }
    }
  }

  // ── Küçük sensör değer kutusu ──────────────────────────────────────────
  Widget _valueBox(String label, String value, {double w = 30, double h = 55}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 3.5.sp,
            color: _muted,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 1.h),
        Container(
          width: w.w,
          height: h.h,
          decoration: BoxDecoration(
            color: _panelBg,
            border: Border.all(width: 0.5.w, color: _borderC),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Center(
            child: Text(
              value.isEmpty ? '--' : value,
              style: TextStyle(
                fontSize: 6.sp,
                color: _bright,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Bölüm başlığı ─────────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: 4.h),
        Text(
          text,
          style: TextStyle(
            color: _accent,
            fontSize: 4.5.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 0.5.h),
        Divider(color: _borderC, thickness: 0.3.h),
        SizedBox(height: 1.5.h),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final qtr = List.generate(8, (i) => i < pinData.length ? pinData[i] : '-');

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
          "VERİLER",
          style: TextStyle(
            color: Colors.white,
            fontSize: 4.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── QTR-8A ─────────────────────────────────────────────
                _sectionLabel("QTR-8A"),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(8, (i) {
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 1.w),
                      child: _valueBox("PIN-${i + 1}", qtr[i]),
                    );
                  }),
                ),

                SizedBox(height: 6.h),

                // ── Sharp IR ────────────────────────────────────────────
                _sectionLabel("SHARP IR"),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _valueBox("Sharp 1", "078", h: 48),
                    SizedBox(width: 8.w),
                    _valueBox("Sharp 2", "312", h: 48),
                    SizedBox(width: 8.w),
                    _valueBox("Sharp 3", "113", h: 48),
                  ],
                ),

                SizedBox(height: 6.h),

                // ── Encoder ─────────────────────────────────────────────
                _sectionLabel("ENCODER"),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _valueBox("A", "751", h: 48),
                    SizedBox(width: 8.w),
                    _valueBox("B", "752", h: 48),
                    SizedBox(width: 8.w),
                    _valueBox("Z", "23", h: 48),
                  ],
                ),

                SizedBox(height: 6.h),

                // ── Haberleşme / Yük ────────────────────────────────────
                _sectionLabel("HABERLEŞMİ / YÜK"),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _valueBox("NRF24L01", "--", h: 48),
                    SizedBox(width: 8.w),
                    _valueBox("Bluetooth", "--", h: 48),
                    SizedBox(width: 8.w),
                    _valueBox("Load", "132", h: 48),
                  ],
                ),

                SizedBox(height: 6.h),

                // ── Çevresel ────────────────────────────────────────────
                _sectionLabel("ÇEVRESEL"),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _valueBox("Nem & Sıcak.", "435–482", w: 38, h: 48),
                    SizedBox(width: 8.w),
                    _valueBox("Akım", "232", h: 48),
                    SizedBox(width: 8.w),
                    _valueBox("Voltaj", "247", h: 48),
                  ],
                ),

                SizedBox(height: 6.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
