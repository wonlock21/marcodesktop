import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
  // Gerçek veriler gelene kadar placeholder — tüm alanlar '--'
  Map<String, String> _data = {};

  @override
  void initState() {
    super.initState();
    if (kAdminMode) {
      _data = {
        // RPLiDAR A3
        'lidar_scan':    'Aktif',
        'lidar_minDist': '0.18 m',
        'lidar_engel':   'Yok',
        'lidar_harita':  'SLAM Aktif',
        // IMX219 Kamera
        'cam_on':        'Aktif',
        'cam_back':      'Pasif',
        'cam_cizgi':     'Algılandı',
        'cam_qrPos':     'Onaylandı',
        // GM67 QR
        'qr_son':        'QA2.1',
        'qr_durum':      'Hazır',
        'qr_tip':        'QR Code',
        'qr_zaman':      '14:07:32',
        // Rotary Encoder
        'enc_solPulse':  '2148',
        'enc_sagPulse':  '2151',
        'enc_solHiz':    '0.87 m/s',
        'enc_sagHiz':    '0.86 m/s',
        // Max471
        'pwr_akim':      '1.8 A',
        'pwr_voltaj':    '24.6 V',
        'pwr_batarya':   '% 78',
        'pwr_sarj':      'Şarj Yok',
        // STM32
        'stm_durum':     'Bağlı',
        'stm_fw':        'v2.3.1',
        'stm_ping':      '4 ms',
        'stm_hata':      'Yok',
        // Bluetooth HC06
        'bt_durum':      'Bağlı Değil',
        'bt_mac':        '--',
        'bt_rssi':       '--',
        'bt_baud':       '9600',
        // PLC / WiFi
        'plc_durum':     'Bağlı',
        'plc_ip':        '192.168.1.50',
        'plc_latency':   '12 ms',
        'plc_mesaj':     'Kapı Açık',
      };
    }
  }

  String _v(String key) => _data[key] ?? '--';

  // ── Sensör değer kutusu ────────────────────────────────────────────────
  Widget _valueBox(String label, String value,
      {double w = 30, double h = 52, Color? valueColor}) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 2.8.sp,
            color: _muted,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: 0.8.h),
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
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 4.sp,
                color: valueColor ?? _bright,
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
            fontSize: 4.sp,
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

  // ── 4'lü sensör satırı ────────────────────────────────────────────────
  Widget _row4(
    String l1, String v1,
    String l2, String v2,
    String l3, String v3,
    String l4, String v4, {
    double w = 28,
    double h = 50,
  }) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4.w,
      runSpacing: 2.h,
      children: [
        _valueBox(l1, v1, w: w, h: h),
        _valueBox(l2, v2, w: w, h: h),
        _valueBox(l3, v3, w: w, h: h),
        _valueBox(l4, v4, w: w, h: h),
      ],
    );
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
          'VERİLER',
          style: TextStyle(
            color: Colors.white,
            fontSize: 4.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 480.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                // ── RPLiDAR A3 ──────────────────────────────────────────
                _sectionLabel('RPLiDAR A3'),
                _row4(
                  'Scan Durumu',     _v('lidar_scan'),
                  'Min. Mesafe',     _v('lidar_minDist'),
                  'Engel Durumu',    _v('lidar_engel'),
                  'Harita Durumu',   _v('lidar_harita'),
                ),

                // ── IMX219 Kamera ───────────────────────────────────────
                _sectionLabel('IMX219 Kamera'),
                _row4(
                  'Ön Kamera',          _v('cam_on'),
                  'Arka Kamera',         _v('cam_back'),
                  'Çizgi Algılama',      _v('cam_cizgi'),
                  'QR Pos. Doğrulama',   _v('cam_qrPos'),
                ),

                // ── GM67 QR Okuyucu ─────────────────────────────────────
                _sectionLabel('GM67 QR Okuyucu'),
                _row4(
                  'Son QR',          _v('qr_son'),
                  'Okuma Durumu',    _v('qr_durum'),
                  'QR Tipi',         _v('qr_tip'),
                  'Son Okunma',      _v('qr_zaman'),
                ),

                // ── Rotary Encoder ──────────────────────────────────────
                _sectionLabel('Rotary Encoder'),
                _row4(
                  'Sol Pulse',       _v('enc_solPulse'),
                  'Sağ Pulse',       _v('enc_sagPulse'),
                  'Sol Motor Hızı',  _v('enc_solHiz'),
                  'Sağ Motor Hızı',  _v('enc_sagHiz'),
                ),

                // ── Max471 Akım / Voltaj ────────────────────────────────
                _sectionLabel('Max471 Akım / Voltaj'),
                _row4(
                  'Akım',            _v('pwr_akim'),
                  'Voltaj',          _v('pwr_voltaj'),
                  'Batarya',         _v('pwr_batarya'),
                  'Şarj Durumu',     _v('pwr_sarj'),
                ),

                // ── STM32 Haberleşmesi ──────────────────────────────────
                _sectionLabel('STM32 Haberleşmesi'),
                _row4(
                  'Bağlantı',        _v('stm_durum'),
                  'Firmware',        _v('stm_fw'),
                  'Ping',            _v('stm_ping'),
                  'Hata',            _v('stm_hata'),
                ),

                // ── Bluetooth HC06 ──────────────────────────────────────
                _sectionLabel('Bluetooth HC06'),
                _row4(
                  'Bağlantı',        _v('bt_durum'),
                  'MAC Adresi',      _v('bt_mac'),
                  'RSSI',            _v('bt_rssi'),
                  'Baud Rate',       _v('bt_baud'),
                ),

                // ── PLC / WiFi Haberleşmesi ─────────────────────────────
                _sectionLabel('PLC / WiFi Haberleşmesi'),
                _row4(
                  'Bağlantı',        _v('plc_durum'),
                  'IP Adresi',       _v('plc_ip'),
                  'Gecikme',         _v('plc_latency'),
                  'Son Mesaj',       _v('plc_mesaj'),
                  w: 30, h: 50,
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
