import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DataModel with ChangeNotifier {
  List<DataPoint> _dataPoints = [];

  List<DataPoint> get dataPoints => _dataPoints;

  /// Veri ekleme fonksiyonu
  void addDataPoint(DataPoint dataPoint) {
    _dataPoints.add(dataPoint);
    notifyListeners();
    //saveDataPoints(); // Yeni veriyi ekledikten sonra kaydediyoruz
  }

  /// Verileri temizleme fonksiyonu
  void clearDataPoints() {
    _dataPoints.clear();
    notifyListeners();
    clearAllData();
    //saveDataPoints(); // Verileri temizledikten sonra kaydediyoruz
  }

  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Verileri SharedPreferences ile kaydetme fonksiyonu
  Future<void> saveDataPoints() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> jsonList =
        _dataPoints.map((dataPoint) => jsonEncode(dataPoint.toJson())).toList();
    await prefs.setStringList('dataPoints', jsonList);
  }

  /// Verileri SharedPreferences ile yükleme fonksiyonu
  Future<void> loadDataPoints() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? jsonList = prefs.getStringList('dataPoints');
    if (jsonList != null) {
      _dataPoints = jsonList
          .map((jsonString) => DataPoint.fromJson(jsonDecode(jsonString)))
          .toList();
      notifyListeners();
    }
  }
}

class DataPoint {
  String type;
  int x;
  int y;

  DataPoint({required this.type, required this.x, required this.y});

  /// Nesneyi JSON formatına dönüştürme
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'x': x,
      'y': y,
    };
  }

  /// JSON'u nesneye dönüştürme
  factory DataPoint.fromJson(Map<String, dynamic> json) {
    return DataPoint(
      type: json['type'],
      x: json['x'],
      y: json['y'],
    );
  }
}
