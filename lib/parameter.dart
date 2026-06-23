import 'parameter_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'services/agv_service.dart';
import 'package:provider/provider.dart';

class ParameterPage extends StatefulWidget {
  const ParameterPage({super.key});

  @override
  State<ParameterPage> createState() => _ParameterPageState();
}

class _ParameterPageState extends State<ParameterPage> {
  // Variables to hold the parameter values
  double speed = 0;  // For the slider
  double hizS =0;
  double hizI = 0;
  double hizD =0;
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

  String _site = '';
  
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
  void dispose(){
    super.dispose();
  }
  Future<void> veriBas(String veri) => AgvService.veriBas(_site, veri);

  @override
  Widget build(BuildContext context) {
    
    _site = ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      appBar: AppBar(
        title: Text('Parametre Sayfası',
              style: TextStyle(
              color: const Color.fromARGB(255, 255, 255, 255),
              fontSize: 4.sp,
              fontWeight: FontWeight.w600),),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 10.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 60.w,
                          height: 50.h,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "Hız",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: hizSure,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) async {
                              setState(() {
                                hizSure = value.trim();
                              });
                              // Asenkron işlemleri başlat
                              await Future.delayed(const Duration(milliseconds: 200));
                              veriBas("k11${hizSure.substring(0,1)}");
                              
                              await Future.delayed(const Duration(milliseconds: 200));
                              veriBas("k12${hizSure.substring(1,2)}");
                              
                              await Future.delayed(const Duration(milliseconds: 200));
                              veriBas("k13${hizSure.substring(2,3)}");
                              
                              parameterModel.updateParam('hizSure', hizSure);
                            },
                          ),
                        ),
                        SizedBox(width: 25.w,),
                        
                        // Acceleration rate input
                        SizedBox(
                          width: 60.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "Hızlanma İvmesi",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: hizIvme,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) async {
                              setState(() {
                                hizIvme = value.trim();
                              });
                              // Asenkron işlemleri başlat
                              await Future.delayed(const Duration(milliseconds: 100));
                              veriBas("k40${hizIvme.substring(0,1)}");
                              
                              await Future.delayed(const Duration(milliseconds: 100));
                              veriBas("k41${hizIvme.substring(1,2)}");
                              
                              await Future.delayed(const Duration(milliseconds: 100));
                              veriBas("k42${hizIvme.substring(2,3)}");

                              parameterModel.updateParam('hizIvme', hizIvme);
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 40.h),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 60.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "Dönüş Hızı",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: donusHizi,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) async {
                              setState(() {
                                donusHizi = value.trim();
                              });
                              // Asenkron işlemleri başlat
                              await Future.delayed(const Duration(milliseconds: 100));
                              veriBas("k14${donusHizi.substring(0,1)}");
                              
                              await Future.delayed(const Duration(milliseconds: 100));
                              veriBas("k15${donusHizi.substring(1,2)}");
                              
                              await Future.delayed(const Duration(milliseconds: 100));
                              veriBas("k16${donusHizi.substring(2,3)}");

                              parameterModel.updateParam('donusHizi', donusHizi);
                            },
                          ),
                        ),
                        SizedBox(width: 25.w),
                        
                        // Running time input
                        SizedBox(
                          width: 60.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "QR Hızı",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: qrHizi,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) async {
                              setState(() {
                                qrHizi = value.trim();
                              });
                              // Asenkron işlemleri başlat
                              await Future.delayed(const Duration(milliseconds: 100));
                              veriBas("k43${qrHizi.substring(0,1)}");
                              
                              await Future.delayed(const Duration(milliseconds: 100));
                              veriBas("k44${qrHizi.substring(1,2)}");
                              
                              await Future.delayed(const Duration(milliseconds: 100));
                              veriBas("k45${qrHizi.substring(2,3)}");

                              parameterModel.updateParam('qrHizi', qrHizi);
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 40.h,),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 60.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "Hızlanma Katsayısı",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: katsayiHiz,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) {
                              setState(() {
                                katsayiHiz = value.trim();
                                veriBas("k20${katsayiHiz.substring(0,1)}");
                                parameterModel.updateParam('katsayiHiz', katsayiHiz);
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 25.w),
                        
                        // Running time input
                        SizedBox(
                          width: 60.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "Dönüş Başlangıç Hızı",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: donusBasHiz,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) async {
                              setState(() {
                                donusBasHiz = value.trim();
                              });
                              // Asenkron işlemleri başlat
                              await Future.delayed(const Duration(milliseconds: 100));
                              veriBas("k17${donusBasHiz.substring(0,1)}");
                              
                              await Future.delayed(const Duration(milliseconds: 100));
                              veriBas("k18${donusBasHiz.substring(1,2)}");
                              
                              await Future.delayed(const Duration(milliseconds: 100));
                              veriBas("k19${donusBasHiz.substring(2,3)}");

                              parameterModel.updateParam('donusBasHiz', donusBasHiz);
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 40.h,),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 60.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "Dönüş Öncesi Süre",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: donusOnceSure,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) async {
                              setState(() {
                                donusOnceSure = value.trim();
                              });
                              // Asenkron işlemleri başlat
                              await Future.delayed(const Duration(milliseconds: 100));
                              veriBas("k21${donusOnceSure.substring(0,1)}");
                              
                              await Future.delayed(const Duration(milliseconds: 100));
                              veriBas("k22${donusOnceSure.substring(1,2)}");
                              
                              await Future.delayed(const Duration(milliseconds: 100));
                              veriBas("k23${donusOnceSure.substring(2,3)}");

                              parameterModel.updateParam('donusOnceSure', donusOnceSure);
                            },
                          ),
                        ),
                        SizedBox(width: 25.w),
                        
                        // Running time input
                        SizedBox(
                          width: 60.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "Lift Öncesi Süre",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: liftOnceSure,
                                hintStyle:TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) async {
                              setState(() {
                                liftOnceSure = value.trim();
                              });
                              // Asenkron işlemleri başlat
                              await Future.delayed(const Duration(milliseconds: 100));
                              veriBas("k24${liftOnceSure.substring(0,1)}");
                              
                              await Future.delayed(const Duration(milliseconds: 100));
                              veriBas("k25${liftOnceSure.substring(1,2)}");
                              
                              await Future.delayed(const Duration(milliseconds: 100));
                              veriBas("k26${liftOnceSure.substring(2,3)}");

                              parameterModel.updateParam('liftOnceSure', liftOnceSure);
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 40.h,),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 60.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "QR Arası Süre",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: qrAraSure,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) {
                              setState(() async{
                                qrAraSure = value.trim();
                                veriBas("k27${qrAraSure.substring(0,1)}");
                                await Future.delayed(const Duration(milliseconds: 100));
                                veriBas("k28${qrAraSure.substring(1,2)}");
                                await Future.delayed(const Duration(milliseconds: 100));
                                veriBas("k29${qrAraSure.substring(2,3)}");

                                parameterModel.updateParam('qrAraSure', value);
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 25.w),
                        
                        // Running time input
                        SizedBox(
                          width: 60.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: 'Sayı Girin',
                                hintStyle: TextStyle(color: Colors.white, fontSize: 2.5.sp)),
                            onSubmitted: (value) {
                              setState(() {
                               // qrHizi = value.trim();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 40.h,),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 60.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: 'Sayı Girin',
                                hintStyle: TextStyle(color: Colors.white, fontSize: 2.5.sp)),
                            onSubmitted: (value) {
                              setState(() {
                               // donusHizi = value.trim();
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 25.w),
                        
                        // Running time input
                        SizedBox(
                          width: 60.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: 'Sayı Girin',
                                hintStyle: TextStyle(color: Colors.white, fontSize: 2.5.sp)),
                            onSubmitted: (value) {
                              setState(() {
                              //  qrHizi = value.trim();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 40.h,),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 60.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: 'Sayı Girin',
                                hintStyle: TextStyle(color: Colors.white, fontSize: 2.5.sp)),
                            onSubmitted: (value) {
                              setState(() {
                               // donusHizi = value.trim();
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 25.w),
                        
                        // Running time input
                        SizedBox(
                          width: 60.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: 'Sayı Girin',
                                hintStyle: TextStyle(color: Colors.white, fontSize: 2.5.sp)),
                            onSubmitted: (value) {
                              setState(() {
                               //qrHizi = value.trim();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            SizedBox(width: 25.w,),



            // SAĞDAKİ BUTONLAR
            Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 60.w,
                          height: 50.h,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "Manuel Hız Kontrol - Sol",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: manuelHizL,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) async {
                              setState(() {
                                manuelHizL = value.trim();
                                veriBas("ML$manuelHizL");
                                parameterModel.updateParam('manuelHizL', manuelHizL);
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 25.w,),
                        
                        // Acceleration rate input
                        SizedBox(
                          width: 60.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "Manuel Hız Kontrol - Sağ",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: manuelHizR,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) async {
                              setState(() {
                                manuelHizR = value.trim();
                                veriBas("MR$manuelHizR");
                                parameterModel.updateParam('manuelHizR', manuelHizR);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 40.h),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 60.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "Otonom Hız Kontrol - Sol",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: otonomHizL,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) async {
                              setState(() {
                                otonomHizL = value.trim();
                                veriBas("OL$otonomHizL");
                                parameterModel.updateParam('otonomHizL', otonomHizL);
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 25.w),
                        
                        // Running time input
                        SizedBox(
                          width: 60.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "Otonom Hız Kontrol - Sağ",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: otonomHizR,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) async {
                              setState(() {
                                otonomHizR = value.trim();
                                veriBas("OR$otonomHizR");
                                parameterModel.updateParam('otonomHizR', otonomHizR);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 30.h,),
                    Text("Arduino Manuel PID Kontrol", style: TextStyle(color: Colors.blue, fontSize: 3.5.sp),),
                    SizedBox(height: 2.h,),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 35.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "P",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: arduinoPIDkontrolP,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) {
                              setState(() {
                                arduinoPIDkontrolP = value.trim();
                                veriBas("MKP$arduinoPIDkontrolP");
                                parameterModel.updateParam('arduinoPIDkontrolP', arduinoPIDkontrolP);
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 25.w),
                        SizedBox(
                          width: 35.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "I",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: arduinoPIDkontrolI,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) {
                              setState(() {
                                arduinoPIDkontrolI = value.trim();
                                veriBas("MKI$arduinoPIDkontrolI");
                                parameterModel.updateParam('arduinoPIDkontrolI', arduinoPIDkontrolI);
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 25.w),
                        // Running time input
                        SizedBox(
                          width: 35.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "D",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: arduinoPIDkontrolD,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) async {
                              setState(() {
                                arduinoPIDkontrolD = value.trim();
                                veriBas("MKD$arduinoPIDkontrolD");
                                parameterModel.updateParam('arduinoPIDkontrolD', arduinoPIDkontrolD);
                              });
                              // Asenkron işlemleri başlat
                              
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 40.h,),
                    Text("RaspberryPI Otonom PID Kontrol", style: TextStyle(color: Colors.blue, fontSize: 3.5.sp),),
                    SizedBox(height: 2.h,),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 35.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "P",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: raspiPIDkontrolP,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) {
                              setState(() {
                                raspiPIDkontrolP = value.trim();
                                veriBas("OKP$raspiPIDkontrolP");
                                parameterModel.updateParam('raspiPIDkontrolP', raspiPIDkontrolP);
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 25.w),
                        SizedBox(
                          width: 35.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "I",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: raspiPIDkontrolI,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) {
                              setState(() {
                                raspiPIDkontrolI = value.trim();
                                veriBas("OKI$raspiPIDkontrolI");
                                parameterModel.updateParam('raspiPIDkontrolI', raspiPIDkontrolI);
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 25.w),
                        // Running time input
                        SizedBox(
                          width: 35.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "D",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: raspiPIDkontrolD,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) async {
                              setState(() {
                                raspiPIDkontrolD = value.trim();
                                veriBas("OKD$raspiPIDkontrolD");
                                parameterModel.updateParam('raspiPIDkontrolD', raspiPIDkontrolD);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 30.h,),
                    Text("Komut Değer Değiştirme", style: TextStyle(color: Colors.blue, fontSize: 3.5.sp),),
                    SizedBox(height: 5.h,),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "Dur",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: dur,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) {
                              setState(() async{
                                dur = value.trim();
                                veriBas("DUR$dur");
                                parameterModel.updateParam('dur', dur);
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 15.w),
                        
                        // Running time input
                        SizedBox(
                          width: 20.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "Sol",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: sol,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) {
                              setState(() {
                                sol = value.trim();
                                veriBas("SOL$sol");
                                parameterModel.updateParam('sol', sol);
                              });
                            },
                          ),
                        ),

                        SizedBox(width: 15.w),
                        
                        // Running time input
                        SizedBox(
                          width: 20.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "Sağ",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: sag,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) {
                              setState(() {
                                sag = value.trim();
                                veriBas("SAG$sag");
                                parameterModel.updateParam('sag', sag);
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 15.w),
                        
                        // Running time input
                        SizedBox(
                          width: 20.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "İleri",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: ileri,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) {
                              setState(() {
                                ileri = value.trim();
                                veriBas("ILERI$ileri");
                                parameterModel.updateParam('ileri', ileri);
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 15.w),
                        
                        // Running time input
                        SizedBox(
                          width: 20.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "Geri",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: geri,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) {
                              setState(() {
                                geri = value.trim();
                                veriBas("GERI$geri");
                                parameterModel.updateParam('geri', geri);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 40.h,),  
                    Text("Lift Hareket Parametre Değiştirme", style: TextStyle(color: Colors.blue, fontSize: 3.5.sp),),
                    SizedBox(height: 4.h,),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 35.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "Yukarı",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: liftu,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) {
                              setState(() {
                                liftu = value.trim();
                                veriBas("LFTU$liftu");
                                parameterModel.updateParam('liftu', liftu);
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 25.w),
                        SizedBox(
                          width: 35.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "Dur",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: liftd,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) {
                              setState(() {
                                liftd = value.trim();
                                veriBas("LFTD$liftd");
                                parameterModel.updateParam('liftd', liftd);
                              });
                            },
                          ),
                        ),
                        SizedBox(width: 25.w),
                        // Running time input
                        SizedBox(
                          width: 35.w,
                          height: 50.h,
                          child: TextField(
                            cursorColor: Colors.white54,
                            style: TextStyle(color: Colors.white, fontSize: 3.5.sp),
                            decoration: InputDecoration(
                              labelText: "Aşağı",
                              labelStyle: TextStyle(color: Colors.blue, fontSize: 4.5.sp),
                                filled: true,
                                fillColor: Colors.black26,
                                enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.blue, width: 0.5.w)),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: const Color.fromARGB(255, 0, 140, 255),
                                        width: 0.7.w)),
                                hintText: lifts,
                                hintStyle: TextStyle(color: const Color.fromARGB(255, 144, 206, 236), fontSize: 3.sp)),
                            onSubmitted: (value) async {
                              setState(() {
                                lifts = value.trim();
                                veriBas("LFTS$lifts");
                                parameterModel.updateParam('lifts', lifts);
                              });
                            
                            },
                          ),
                        ),
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
