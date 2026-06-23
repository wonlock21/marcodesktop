import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ParameterModel with ChangeNotifier {
  static const Map<String, String> _defaults = {
    'hizSure': '0',
    'hizIvme': '0.0',
    'donusHizi': '0',
    'qrHizi': '0',
    'katsayiHiz': '0.0',
    'donusBasHiz': '0',
    'donusOnceSure': '0',
    'liftOnceSure': '0',
    'qrAraSure': '0',
    'manuelHizL': '0',
    'manuelHizR': '0',
    'otonomHizL': '0',
    'otonomHizR': '0',
    'arduinoPIDkontrolP': '0',
    'arduinoPIDkontrolI': '0',
    'arduinoPIDkontrolD': '0',
    'raspiPIDkontrolP': '0',
    'raspiPIDkontrolI': '0',
    'raspiPIDkontrolD': '0',
    'dur': '0',
    'sol': '0',
    'sag': '0',
    'ileri': '0',
    'geri': '0',
    'liftu': '0',
    'liftd': '0',
    'lifts': '0',
  };

  final Map<String, String> _params = Map.of(_defaults);

  // Named getters — parameter.dart erişimini bozmaz
  String get hizSure => _params['hizSure']!;
  String get hizIvme => _params['hizIvme']!;
  String get donusHizi => _params['donusHizi']!;
  String get qrHizi => _params['qrHizi']!;
  String get katsayiHiz => _params['katsayiHiz']!;
  String get donusBasHiz => _params['donusBasHiz']!;
  String get donusOnceSure => _params['donusOnceSure']!;
  String get liftOnceSure => _params['liftOnceSure']!;
  String get qrAraSure => _params['qrAraSure']!;
  String get manuelHizL => _params['manuelHizL']!;
  String get manuelHizR => _params['manuelHizR']!;
  String get otonomHizL => _params['otonomHizL']!;
  String get otonomHizR => _params['otonomHizR']!;
  String get arduinoPIDkontrolP => _params['arduinoPIDkontrolP']!;
  String get arduinoPIDkontrolI => _params['arduinoPIDkontrolI']!;
  String get arduinoPIDkontrolD => _params['arduinoPIDkontrolD']!;
  String get raspiPIDkontrolP => _params['raspiPIDkontrolP']!;
  String get raspiPIDkontrolI => _params['raspiPIDkontrolI']!;
  String get raspiPIDkontrolD => _params['raspiPIDkontrolD']!;
  String get dur => _params['dur']!;
  String get sol => _params['sol']!;
  String get sag => _params['sag']!;
  String get ileri => _params['ileri']!;
  String get geri => _params['geri']!;
  String get liftu => _params['liftu']!;
  String get liftd => _params['liftd']!;
  String get lifts => _params['lifts']!;

  void updateParam(String key, String value) {
    assert(_defaults.containsKey(key), 'Bilinmeyen parametre anahtarı: $key');
    _params[key] = value;
    saveParameters();
    notifyListeners();
  }

  Future<void> saveParameters() async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in _params.entries) {
      await prefs.setString(entry.key, entry.value);
    }
  }

  Future<void> loadParameters() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _defaults.keys) {
      _params[key] = prefs.getString(key) ?? _defaults[key]!;
    }
    notifyListeners();
  }
}
