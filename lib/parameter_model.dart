import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ParameterModel with ChangeNotifier {
  // Parametreler
  String hizSure; // Hız
  String hizIvme; // Hızlanma ivmesi
  String donusHizi; // Dönüş hızı
  String qrHizi; // QR okuma hızı
  String katsayiHiz; // Hızlanma katsayısı
  String donusBasHiz; // Dönüş başlangıç hızı
  String donusOnceSure; // Dönüş öncesi süre
  String liftOnceSure; // Lift öncesi süre
  String qrAraSure; // QR arası süre
  String manuelHizL;
  String manuelHizR;
  String otonomHizL;
  String otonomHizR;
  String arduinoPIDkontrolP;
  String arduinoPIDkontrolI;
  String arduinoPIDkontrolD;
  String raspiPIDkontrolP;
  String raspiPIDkontrolI;
  String raspiPIDkontrolD;
  String dur;
  String sol;
  String sag;
  String ileri;
  String geri;
  String liftu;
  String liftd;
  String lifts;

  // Constructor
  ParameterModel({
    this.hizSure = '0',
    this.hizIvme = '0.0',
    this.donusHizi = '0',
    this.qrHizi = '0',
    this.katsayiHiz = '0.0',
    this.donusBasHiz = '0',
    this.donusOnceSure = '0',
    this.liftOnceSure = '0',
    this.qrAraSure = '0',
    this.manuelHizL = '0',
    this.manuelHizR = '0',
    this.otonomHizL = '0',
    this.otonomHizR = '0',
    this.arduinoPIDkontrolP = '0',
    this.arduinoPIDkontrolI = '0',
    this.arduinoPIDkontrolD = '0',
    this.raspiPIDkontrolP = '0',
    this.raspiPIDkontrolI = '0',
    this.raspiPIDkontrolD = '0',
    this.dur = '0',
    this.sol = '0',
    this.sag = '0',
    this.ileri = '0',
    this.geri = '0',
    this.liftu = '0',
    this.liftd = '0',
    this.lifts = '0',
  });

  // Verileri kaydetmek için SharedPreferences kullanımı
  Future<void> saveParameters() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('hizSure', hizSure);
    prefs.setString('hizIvme', hizIvme);
    prefs.setString('donusHizi', donusHizi);
    prefs.setString('qrHizi', qrHizi);
    prefs.setString('katsayiHiz', katsayiHiz);
    prefs.setString('donusBasHiz', donusBasHiz);
    prefs.setString('donusOnceSure', donusOnceSure);
    prefs.setString('liftOnceSure', liftOnceSure);
    prefs.setString('qrAraSure', qrAraSure);
    prefs.setString('manuelHizL', manuelHizL);
    prefs.setString('manuelHizR', manuelHizR);
    prefs.setString('otonomHizL', otonomHizL);
    prefs.setString('otonomHizR', otonomHizR);
    prefs.setString('arduinoPIDkontrolP', arduinoPIDkontrolP);
    prefs.setString('arduinoPIDkontrolI', arduinoPIDkontrolI);
    prefs.setString('arduinoPIDkontrolD', arduinoPIDkontrolD);
    prefs.setString('raspiPIDkontrolP', raspiPIDkontrolP);
    prefs.setString('raspiPIDkontrolI', raspiPIDkontrolI);
    prefs.setString('raspiPIDkontrolD', raspiPIDkontrolD);
    prefs.setString('dur', dur);
    prefs.setString('sol', sol);
    prefs.setString('sag', sag);
    prefs.setString('ileri', ileri);
    prefs.setString('geri', geri);
    prefs.setString('liftu', liftu);
    prefs.setString('liftd', liftd);
    prefs.setString('lifts', lifts);
  }

  // Verileri yüklemek için SharedPreferences kullanımı
  Future<void> loadParameters() async {
    final prefs = await SharedPreferences.getInstance();
    hizSure = prefs.getString('hizSure') ?? '0';
    hizIvme = prefs.getString('hizIvme') ?? '0.0';
    donusHizi = prefs.getString('donusHizi') ?? '0';
    qrHizi = prefs.getString('qrHizi') ?? '0';
    katsayiHiz = prefs.getString('katsayiHiz') ?? '0.0';
    donusBasHiz = prefs.getString('donusBasHiz') ?? '0';
    donusOnceSure = prefs.getString('donusOnceSure') ?? '0';
    liftOnceSure = prefs.getString('liftOnceSure') ?? '0';
    qrAraSure = prefs.getString('qrAraSure') ?? '0';
    manuelHizL = prefs.getString('manuelHizL') ?? '0';
    manuelHizR = prefs.getString('manuelHizR') ?? '0';
    otonomHizL = prefs.getString('otonomHizL') ?? '0';
    otonomHizR = prefs.getString('otonomHizR') ?? '0';
    arduinoPIDkontrolP = prefs.getString('arduinoPIDkontrolP') ?? '0';
    arduinoPIDkontrolI = prefs.getString('arduinoPIDkontrolI') ?? '0';
    arduinoPIDkontrolD = prefs.getString('arduinoPIDkontrolD') ?? '0';
    raspiPIDkontrolP = prefs.getString('raspiPIDkontrolP') ?? '0';
    raspiPIDkontrolI = prefs.getString('raspiPIDkontrolI') ?? '0';
    raspiPIDkontrolD = prefs.getString('raspiPIDkontrolD') ?? '0';
    dur = prefs.getString('dur') ?? '0';
    sol = prefs.getString('sol') ?? '0';
    sag = prefs.getString('sag') ?? '0';
    ileri = prefs.getString('ileri') ?? '0';
    geri = prefs.getString('geri') ?? '0';
    liftu = prefs.getString('liftu') ?? '0';
    liftd = prefs.getString('liftd') ?? '0';
    lifts = prefs.getString('lifts') ?? '0';
    notifyListeners();
  }

  // Parametreleri güncelleme metotları
  void updateSpeed(String newSpeed) {
    hizSure = newSpeed; // Hız
    saveParameters();
    notifyListeners();
  }

  void updateAccelerationRate(String newAccelerationRate) {
    hizIvme = newAccelerationRate; // Hızlanma ivmesi
    saveParameters();
    notifyListeners();
  }

  void updateTurningSpeed(String newTurningSpeed) {
    donusHizi = newTurningSpeed; // Dönüş hızı
    saveParameters();
    notifyListeners();
  }

  void updateQrReadingSpeed(String newQrReadingSpeed) {
    qrHizi = newQrReadingSpeed; // QR okuma hızı
    saveParameters();
    notifyListeners();
  }

  void updateAccelerationFactor(String newAccelerationFactor) {
    katsayiHiz = newAccelerationFactor; // Hızlanma katsayısı
    saveParameters();
    notifyListeners();
  }

  void updatedonusBasHiz(String newdonusBasHiz) {
    donusBasHiz = newdonusBasHiz; // Dönüş başlangıç hızı
    saveParameters();
    notifyListeners();
  }

  void updatedonusOnceSure(String newdonusOnceSure) {
    donusOnceSure = newdonusOnceSure; // Dönüş öncesi süre
    saveParameters();
    notifyListeners();
  }

  void updatePreLiftDuration(String newPreLiftDuration) {
    liftOnceSure = newPreLiftDuration; // Lift öncesi süre
    saveParameters();
    notifyListeners();
  }

  void updateqrAraSure(String newqrAraSure) {
    qrAraSure = newqrAraSure; // QR arası süre
    saveParameters();
    notifyListeners();
  }

  void updateManuelHizL(String newValue) {
    manuelHizL = newValue; // Hız
    saveParameters();
    notifyListeners();
  }

  void updateManuelHizR(String newValue) {
    manuelHizR = newValue; // Hız
    saveParameters();
    notifyListeners();
  }
  void updateOtonomHizL(String newValue) {
    otonomHizL = newValue; // Hız
    saveParameters();
    notifyListeners();
  }
  void updateOtonomHizR(String newValue) {
    otonomHizR = newValue; // Hız
    saveParameters();
    notifyListeners();
  }
  void updateArduinoP(String newValue) {
    arduinoPIDkontrolP = newValue; // Hız
    saveParameters();
    notifyListeners();
  }
  void updateArduinoI(String newValue) {
    arduinoPIDkontrolI = newValue; // Hız
    saveParameters();
    notifyListeners();
  }
  void updateArduinoD(String newValue) {
    arduinoPIDkontrolD = newValue; // Hız
    saveParameters();
    notifyListeners();
  }
  void updateRaspiP(String newValue) {
    raspiPIDkontrolP = newValue; // Hız
    saveParameters();
    notifyListeners();
  }
  void updateRaspiI(String newValue) {
    raspiPIDkontrolI = newValue; // Hız
    saveParameters();
    notifyListeners();
  }
  void updateRaspiD(String newValue) {
    raspiPIDkontrolD = newValue; // Hız
    saveParameters();
    notifyListeners();
  }
  void updateDur(String newValue) {
    dur = newValue;
    saveParameters();
    notifyListeners();
  }

  void updateSol(String newValue) {
    sol = newValue;
    saveParameters();
    notifyListeners();
  }

  void updateSag(String newValue) {
    sag = newValue;
    saveParameters();
    notifyListeners();
  }

  void updateIleri(String newValue) {
    ileri = newValue;
    saveParameters();
    notifyListeners();
  }

  void updateGeri(String newValue) {
    geri = newValue;
    saveParameters();
    notifyListeners();
  }

  void updateLiftU(String newValue) {
    liftu = newValue;
    saveParameters();
    notifyListeners();
  }

  void updateLiftD(String newValue) {
    liftd = newValue;
    saveParameters();
    notifyListeners();
  }

  void updateLifts(String newValue) {
    lifts = newValue;
    saveParameters();
    notifyListeners();
  }
}
