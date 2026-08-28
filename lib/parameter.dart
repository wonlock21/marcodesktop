import 'parameter_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

// ─── Renk sabitleri ────────────────────────────────────────────────────────
const _bg = Color(0xFF121212);
const _panelBg = Color(0xFF1A1A1A);
const _borderC = Color(0xFF333333);
const _muted = Color(0xFF9E9E9E);
const _bright = Color(0xFFE0E0E0);

class ParameterPage extends StatefulWidget {
  const ParameterPage({super.key});

  @override
  State<ParameterPage> createState() => _ParameterPageState();
}

class _ParameterPageState extends State<ParameterPage> {
  // ── State değişkenleri (değiştirilmedi) ───────────────────────────────
  double speed = 0;
  double hizS = 0;
  double hizI = 0;
  double hizD = 0;
  late ParameterModel parameterModel;
  String hizSure = '';
  String hizIvme = '';
  String donusHizi = '';
  String qrHizi = '';
  String katsayiHiz = '';
  String donusBasHiz = '';
  String donusOnceSure = '';
  String liftOnceSure = '';
  String qrAraSure = '';
  String manuelHizL = '';
  String manuelHizR = '';
  String otonomHizL = '';
  String otonomHizR = '';
  String arduinoPIDkontrolP = '';
  String arduinoPIDkontrolI = '';
  String arduinoPIDkontrolD = '';
  String raspiPIDkontrolP = '';
  String raspiPIDkontrolI = '';
  String raspiPIDkontrolD = '';
  String dur = '';
  String sol = '';
  String sag = '';
  String ileri = '';
  String geri = '';
  String liftu = '';
  String liftd = '';
  String lifts = '';

  @override
  void initState() {
    super.initState();
    parameterModel = Provider.of<ParameterModel>(context, listen: false);

    Future.microtask(() async {
      await parameterModel.loadParameters();
      if (!mounted) return;
      setState(() {
        hizSure = parameterModel.hizSure;
        hizIvme = parameterModel.hizIvme;
        donusHizi = parameterModel.donusHizi;
        qrHizi = parameterModel.qrHizi;
        katsayiHiz = parameterModel.katsayiHiz;
        donusBasHiz = parameterModel.donusBasHiz;
        donusOnceSure = parameterModel.donusOnceSure;
        liftOnceSure = parameterModel.liftOnceSure;
        qrAraSure = parameterModel.qrAraSure;
        manuelHizL = parameterModel.manuelHizL;
        manuelHizR = parameterModel.manuelHizR;
        otonomHizL = parameterModel.otonomHizL;
        otonomHizR = parameterModel.otonomHizR;
        arduinoPIDkontrolP = parameterModel.arduinoPIDkontrolP;
        arduinoPIDkontrolI = parameterModel.arduinoPIDkontrolI;
        arduinoPIDkontrolD = parameterModel.arduinoPIDkontrolD;
        raspiPIDkontrolP = parameterModel.raspiPIDkontrolP;
        raspiPIDkontrolI = parameterModel.raspiPIDkontrolI;
        raspiPIDkontrolD = parameterModel.raspiPIDkontrolD;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool veriBas(String veri) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(
        content: Text(
          'Parametre gönderilmedi: güncel ROS backend genel donanım/parametre '
          'komut arayüzü sunmuyor.',
        ),
      ));
    return false;
  }

  // ── GCS stili TextField dekorasyon yardımcısı ─────────────────────────
  InputDecoration _gcsInput(String label, String hint) {
    return InputDecoration(
      labelText: label.isEmpty ? null : label,
      labelStyle:
          TextStyle(color: _muted, fontSize: 3.5.sp, letterSpacing: 0.3),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      hintText: hint.isEmpty ? null : hint,
      hintStyle: TextStyle(
        color: const Color(0xFF4A4A4A),
        fontSize: 3.sp,
        fontFamily: 'monospace',
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.5.h),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _borderC, width: 0.5.w),
        borderRadius: BorderRadius.circular(4.r),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: const Color(0xFF1565C0), width: 0.7.w),
        borderRadius: BorderRadius.circular(4.r),
      ),
    );
  }

  // ── Bölüm başlığı ─────────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.5.h, top: 2.h),
      child: Text(
        text,
        style: TextStyle(
          color: _muted,
          fontSize: 3.sp,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  // ── TextField sarmalayıcı ──────────────────────────────────────────────
  Widget _field({
    required double w,
    required double h,
    required InputDecoration decoration,
    TextInputType? keyboardType,
    required void Function(String) onSubmitted,
  }) {
    return SizedBox(
      width: w.w,
      height: h.h,
      child: TextField(
        keyboardType: keyboardType,
        cursorColor: _bright,
        style: TextStyle(
          color: _bright,
          fontSize: 3.5.sp,
          fontFamily: 'monospace',
        ),
        decoration: decoration,
        onSubmitted: onSubmitted,
      ),
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
          'PARAMETRELER',
          style: TextStyle(
            color: Colors.white,
            fontSize: 4.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding:
            EdgeInsets.only(top: 120.h, bottom: 4.h, left: 4.w, right: 4.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ══════════════════════════════════════════════════════════
            // SOL KOLON — Hareket Parametreleri
            // ══════════════════════════════════════════════════════════
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _field(
                      w: 80,
                      h: 52,
                      decoration: _gcsInput("Hız", hizSure),
                      keyboardType: TextInputType.number,
                      onSubmitted: (value) async {
                        setState(() {
                          hizSure = value.trim();
                        });
                        await Future.delayed(const Duration(milliseconds: 200));
                        veriBas("k11${hizSure.substring(0, 1)}");
                        await Future.delayed(const Duration(milliseconds: 200));
                        veriBas("k12${hizSure.substring(1, 2)}");
                        await Future.delayed(const Duration(milliseconds: 200));
                        veriBas("k13${hizSure.substring(2, 3)}");
                        parameterModel.updateParam('hizSure', hizSure);
                      },
                    ),
                    SizedBox(width: 4.w),
                    _field(
                      w: 80,
                      h: 52,
                      decoration: _gcsInput("Hızlanma İvmesi", hizIvme),
                      onSubmitted: (value) async {
                        setState(() {
                          hizIvme = value.trim();
                        });
                        await Future.delayed(const Duration(milliseconds: 100));
                        veriBas("k40${hizIvme.substring(0, 1)}");
                        await Future.delayed(const Duration(milliseconds: 100));
                        veriBas("k41${hizIvme.substring(1, 2)}");
                        await Future.delayed(const Duration(milliseconds: 100));
                        veriBas("k42${hizIvme.substring(2, 3)}");
                        parameterModel.updateParam('hizIvme', hizIvme);
                      },
                    ),
                  ]),
                  SizedBox(height: 3.h),
                  Row(children: [
                    _field(
                      w: 80,
                      h: 52,
                      decoration: _gcsInput("Dönüş Hızı", donusHizi),
                      onSubmitted: (value) async {
                        setState(() {
                          donusHizi = value.trim();
                        });
                        await Future.delayed(const Duration(milliseconds: 100));
                        veriBas("k14${donusHizi.substring(0, 1)}");
                        await Future.delayed(const Duration(milliseconds: 100));
                        veriBas("k15${donusHizi.substring(1, 2)}");
                        await Future.delayed(const Duration(milliseconds: 100));
                        veriBas("k16${donusHizi.substring(2, 3)}");
                        parameterModel.updateParam('donusHizi', donusHizi);
                      },
                    ),
                    SizedBox(width: 4.w),
                    _field(
                      w: 80,
                      h: 52,
                      decoration: _gcsInput("QR Hızı", qrHizi),
                      onSubmitted: (value) async {
                        setState(() {
                          qrHizi = value.trim();
                        });
                        await Future.delayed(const Duration(milliseconds: 100));
                        veriBas("k43${qrHizi.substring(0, 1)}");
                        await Future.delayed(const Duration(milliseconds: 100));
                        veriBas("k44${qrHizi.substring(1, 2)}");
                        await Future.delayed(const Duration(milliseconds: 100));
                        veriBas("k45${qrHizi.substring(2, 3)}");
                        parameterModel.updateParam('qrHizi', qrHizi);
                      },
                    ),
                  ]),
                  SizedBox(height: 3.h),
                  Row(children: [
                    _field(
                      w: 80,
                      h: 52,
                      decoration: _gcsInput("Hızlanma Katsayısı", katsayiHiz),
                      onSubmitted: (value) {
                        setState(() {
                          katsayiHiz = value.trim();
                          veriBas("k20${katsayiHiz.substring(0, 1)}");
                          parameterModel.updateParam('katsayiHiz', katsayiHiz);
                        });
                      },
                    ),
                    SizedBox(width: 4.w),
                    _field(
                      w: 80,
                      h: 52,
                      decoration:
                          _gcsInput("Dönüş Başlangıç Hızı", donusBasHiz),
                      onSubmitted: (value) async {
                        setState(() {
                          donusBasHiz = value.trim();
                        });
                        await Future.delayed(const Duration(milliseconds: 100));
                        veriBas("k17${donusBasHiz.substring(0, 1)}");
                        await Future.delayed(const Duration(milliseconds: 100));
                        veriBas("k18${donusBasHiz.substring(1, 2)}");
                        await Future.delayed(const Duration(milliseconds: 100));
                        veriBas("k19${donusBasHiz.substring(2, 3)}");
                        parameterModel.updateParam('donusBasHiz', donusBasHiz);
                      },
                    ),
                  ]),
                  SizedBox(height: 3.h),
                  Row(children: [
                    _field(
                      w: 80,
                      h: 52,
                      decoration: _gcsInput("Dönüş Öncesi Süre", donusOnceSure),
                      onSubmitted: (value) async {
                        setState(() {
                          donusOnceSure = value.trim();
                        });
                        await Future.delayed(const Duration(milliseconds: 100));
                        veriBas("k21${donusOnceSure.substring(0, 1)}");
                        await Future.delayed(const Duration(milliseconds: 100));
                        veriBas("k22${donusOnceSure.substring(1, 2)}");
                        await Future.delayed(const Duration(milliseconds: 100));
                        veriBas("k23${donusOnceSure.substring(2, 3)}");
                        parameterModel.updateParam(
                            'donusOnceSure', donusOnceSure);
                      },
                    ),
                    SizedBox(width: 4.w),
                    _field(
                      w: 80,
                      h: 52,
                      decoration: _gcsInput("Lift Öncesi Süre", liftOnceSure),
                      onSubmitted: (value) async {
                        setState(() {
                          liftOnceSure = value.trim();
                        });
                        await Future.delayed(const Duration(milliseconds: 100));
                        veriBas("k24${liftOnceSure.substring(0, 1)}");
                        await Future.delayed(const Duration(milliseconds: 100));
                        veriBas("k25${liftOnceSure.substring(1, 2)}");
                        await Future.delayed(const Duration(milliseconds: 100));
                        veriBas("k26${liftOnceSure.substring(2, 3)}");
                        parameterModel.updateParam(
                            'liftOnceSure', liftOnceSure);
                      },
                    ),
                  ]),
                  SizedBox(height: 3.h),
                  Row(children: [
                    _field(
                      w: 80,
                      h: 52,
                      decoration: _gcsInput("QR Arası Süre", qrAraSure),
                      onSubmitted: (value) {
                        setState(() async {
                          qrAraSure = value.trim();
                          veriBas("k27${qrAraSure.substring(0, 1)}");
                          await Future.delayed(
                              const Duration(milliseconds: 100));
                          veriBas("k28${qrAraSure.substring(1, 2)}");
                          await Future.delayed(
                              const Duration(milliseconds: 100));
                          veriBas("k29${qrAraSure.substring(2, 3)}");
                          parameterModel.updateParam('qrAraSure', value);
                        });
                      },
                    ),
                    SizedBox(width: 4.w),
                    _field(
                      w: 80,
                      h: 52,
                      decoration: _gcsInput("", "Sayı Girin"),
                      onSubmitted: (value) {
                        setState(() {
                          // kullanılmıyor
                        });
                      },
                    ),
                  ]),
                  SizedBox(height: 3.h),
                  Row(children: [
                    _field(
                      w: 80,
                      h: 52,
                      decoration: _gcsInput("", "Sayı Girin"),
                      onSubmitted: (value) {
                        setState(() {
                          // kullanılmıyor
                        });
                      },
                    ),
                    SizedBox(width: 4.w),
                    _field(
                      w: 80,
                      h: 52,
                      decoration: _gcsInput("", "Sayı Girin"),
                      onSubmitted: (value) {
                        setState(() {
                          // kullanılmıyor
                        });
                      },
                    ),
                  ]),
                  SizedBox(height: 3.h),
                  Row(children: [
                    _field(
                      w: 80,
                      h: 52,
                      decoration: _gcsInput("", "Sayı Girin"),
                      onSubmitted: (value) {
                        setState(() {
                          // kullanılmıyor
                        });
                      },
                    ),
                    SizedBox(width: 4.w),
                    _field(
                      w: 80,
                      h: 52,
                      decoration: _gcsInput("", "Sayı Girin"),
                      onSubmitted: (value) {
                        setState(() {
                          // kullanılmıyor
                        });
                      },
                    ),
                  ]),
                ],
              ),
            ),

            SizedBox(width: 6.w),

            // ══════════════════════════════════════════════════════════
            // SAĞ KOLON — Hız Kontrol & PID
            // ══════════════════════════════════════════════════════════
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _field(
                      w: 80,
                      h: 52,
                      decoration: _gcsInput("Manuel Hız – Sol", manuelHizL),
                      keyboardType: TextInputType.number,
                      onSubmitted: (value) async {
                        setState(() {
                          manuelHizL = value.trim();
                          veriBas("ML$manuelHizL");
                          parameterModel.updateParam('manuelHizL', manuelHizL);
                        });
                      },
                    ),
                    SizedBox(width: 4.w),
                    _field(
                      w: 80,
                      h: 52,
                      decoration: _gcsInput("Manuel Hız – Sağ", manuelHizR),
                      onSubmitted: (value) async {
                        setState(() {
                          manuelHizR = value.trim();
                          veriBas("MR$manuelHizR");
                          parameterModel.updateParam('manuelHizR', manuelHizR);
                        });
                      },
                    ),
                  ]),
                  SizedBox(height: 3.h),
                  Row(children: [
                    _field(
                      w: 80,
                      h: 52,
                      decoration: _gcsInput("Otonom Hız – Sol", otonomHizL),
                      onSubmitted: (value) async {
                        setState(() {
                          otonomHizL = value.trim();
                          veriBas("OL$otonomHizL");
                          parameterModel.updateParam('otonomHizL', otonomHizL);
                        });
                      },
                    ),
                    SizedBox(width: 4.w),
                    _field(
                      w: 80,
                      h: 52,
                      decoration: _gcsInput("Otonom Hız – Sağ", otonomHizR),
                      onSubmitted: (value) async {
                        setState(() {
                          otonomHizR = value.trim();
                          veriBas("OR$otonomHizR");
                          parameterModel.updateParam('otonomHizR', otonomHizR);
                        });
                      },
                    ),
                  ]),
                  SizedBox(height: 4.h),
                  _sectionLabel("STM32 MANUEL PID"),
                  Row(children: [
                    _field(
                      w: 50,
                      h: 52,
                      decoration: _gcsInput("P", arduinoPIDkontrolP),
                      onSubmitted: (value) {
                        setState(() {
                          arduinoPIDkontrolP = value.trim();
                          veriBas("MKP$arduinoPIDkontrolP");
                          parameterModel.updateParam(
                              'arduinoPIDkontrolP', arduinoPIDkontrolP);
                        });
                      },
                    ),
                    SizedBox(width: 4.w),
                    _field(
                      w: 50,
                      h: 52,
                      decoration: _gcsInput("I", arduinoPIDkontrolI),
                      onSubmitted: (value) {
                        setState(() {
                          arduinoPIDkontrolI = value.trim();
                          veriBas("MKI$arduinoPIDkontrolI");
                          parameterModel.updateParam(
                              'arduinoPIDkontrolI', arduinoPIDkontrolI);
                        });
                      },
                    ),
                    SizedBox(width: 4.w),
                    _field(
                      w: 50,
                      h: 52,
                      decoration: _gcsInput("D", arduinoPIDkontrolD),
                      onSubmitted: (value) async {
                        setState(() {
                          arduinoPIDkontrolD = value.trim();
                          veriBas("MKD$arduinoPIDkontrolD");
                          parameterModel.updateParam(
                              'arduinoPIDkontrolD', arduinoPIDkontrolD);
                        });
                      },
                    ),
                  ]),
                  SizedBox(height: 4.h),
                  _sectionLabel("ORANGE PI 5 / ROS 2 OTONOM PID"),
                  Row(children: [
                    _field(
                      w: 50,
                      h: 52,
                      decoration: _gcsInput("P", raspiPIDkontrolP),
                      onSubmitted: (value) {
                        setState(() {
                          raspiPIDkontrolP = value.trim();
                          veriBas("OKP$raspiPIDkontrolP");
                          parameterModel.updateParam(
                              'raspiPIDkontrolP', raspiPIDkontrolP);
                        });
                      },
                    ),
                    SizedBox(width: 4.w),
                    _field(
                      w: 50,
                      h: 52,
                      decoration: _gcsInput("I", raspiPIDkontrolI),
                      onSubmitted: (value) {
                        setState(() {
                          raspiPIDkontrolI = value.trim();
                          veriBas("OKI$raspiPIDkontrolI");
                          parameterModel.updateParam(
                              'raspiPIDkontrolI', raspiPIDkontrolI);
                        });
                      },
                    ),
                    SizedBox(width: 4.w),
                    _field(
                      w: 50,
                      h: 52,
                      decoration: _gcsInput("D", raspiPIDkontrolD),
                      onSubmitted: (value) async {
                        setState(() {
                          raspiPIDkontrolD = value.trim();
                          veriBas("OKD$raspiPIDkontrolD");
                          parameterModel.updateParam(
                              'raspiPIDkontrolD', raspiPIDkontrolD);
                        });
                      },
                    ),
                  ]),
                  SizedBox(height: 4.h),
                  _sectionLabel("MANUEL KOMUT DEĞERLERİ"),
                  Row(children: [
                    _field(
                      w: 28,
                      h: 52,
                      decoration: _gcsInput("Dur", dur),
                      onSubmitted: (value) {
                        setState(() async {
                          dur = value.trim();
                          veriBas("DUR$dur");
                          parameterModel.updateParam('dur', dur);
                        });
                      },
                    ),
                    SizedBox(width: 3.w),
                    _field(
                      w: 28,
                      h: 52,
                      decoration: _gcsInput("Sol", sol),
                      onSubmitted: (value) {
                        setState(() {
                          sol = value.trim();
                          veriBas("SOL$sol");
                          parameterModel.updateParam('sol', sol);
                        });
                      },
                    ),
                    SizedBox(width: 3.w),
                    _field(
                      w: 28,
                      h: 52,
                      decoration: _gcsInput("Sağ", sag),
                      onSubmitted: (value) {
                        setState(() {
                          sag = value.trim();
                          veriBas("SAG$sag");
                          parameterModel.updateParam('sag', sag);
                        });
                      },
                    ),
                    SizedBox(width: 3.w),
                    _field(
                      w: 28,
                      h: 52,
                      decoration: _gcsInput("İleri", ileri),
                      onSubmitted: (value) {
                        setState(() {
                          ileri = value.trim();
                          veriBas("ILERI$ileri");
                          parameterModel.updateParam('ileri', ileri);
                        });
                      },
                    ),
                    SizedBox(width: 3.w),
                    _field(
                      w: 28,
                      h: 52,
                      decoration: _gcsInput("Geri", geri),
                      onSubmitted: (value) {
                        setState(() {
                          geri = value.trim();
                          veriBas("GERI$geri");
                          parameterModel.updateParam('geri', geri);
                        });
                      },
                    ),
                  ]),
                  SizedBox(height: 4.h),
                  _sectionLabel("FORKLİFT / LİFT HAREKET PARAMETRELERİ"),
                  Row(children: [
                    _field(
                      w: 50,
                      h: 52,
                      decoration: _gcsInput("Yukarı", liftu),
                      onSubmitted: (value) {
                        setState(() {
                          liftu = value.trim();
                          veriBas("LFTU$liftu");
                          parameterModel.updateParam('liftu', liftu);
                        });
                      },
                    ),
                    SizedBox(width: 4.w),
                    _field(
                      w: 50,
                      h: 52,
                      decoration: _gcsInput("Dur", liftd),
                      onSubmitted: (value) {
                        setState(() {
                          liftd = value.trim();
                          veriBas("LFTD$liftd");
                          parameterModel.updateParam('liftd', liftd);
                        });
                      },
                    ),
                    SizedBox(width: 4.w),
                    _field(
                      w: 50,
                      h: 52,
                      decoration: _gcsInput("Aşağı", lifts),
                      onSubmitted: (value) async {
                        setState(() {
                          lifts = value.trim();
                          veriBas("LFTS$lifts");
                          parameterModel.updateParam('lifts', lifts);
                        });
                      },
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
