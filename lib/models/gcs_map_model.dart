import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/ros_gcs_contract.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Harita üzerinde yer alabilecek nesne türleri
// ─────────────────────────────────────────────────────────────────────────────

enum MapPointType {
  /// Yük alma noktası (A1, A2…)
  almaNoktasi,

  /// Yük bırakma noktası (B1, B2…)
  birakNoktasi,

  /// Bekleme / başlangıç noktası (S1, S2)
  beklemeNoktasi,

  /// Kapı kontrol noktası — PLC kapı geçişi
  kapiKontrol,

  /// Şarj istasyonu (CS)
  sarjIstasyonu,

  /// Son okunan QR kod pozisyonu
  qrNoktasi,

  /// Engel ya da durma bölgesi sınırı (kırmızı)
  engel,

  /// Güvenli duruş bölgesi (sarı)
  guvenliDurus,
}

extension MapPointTypeExt on MapPointType {
  String get etiket => switch (this) {
        MapPointType.almaNoktasi => 'Alma',
        MapPointType.birakNoktasi => 'Bırakma',
        MapPointType.beklemeNoktasi => 'Bekleme',
        MapPointType.kapiKontrol => 'Kapı',
        MapPointType.sarjIstasyonu => 'Şarj',
        MapPointType.qrNoktasi => 'QR',
        MapPointType.engel => 'Engel',
        MapPointType.guvenliDurus => 'Güvenli',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Veri modelleri
// ─────────────────────────────────────────────────────────────────────────────

/// Haritada sabit veya anlık bir nokta.
class MapPoint {
  /// Benzersiz tanımlayıcı.
  final String id;

  /// Ekranda görünecek etiket (ör. "A2", "QA2.1").
  final String label;

  /// Dünya koordinatı — metre cinsinden.
  final double x;
  final double y;

  final MapPointType type;

  /// Aktif görevde bu nokta mı? (vurgu için)
  final bool aktif;

  const MapPoint({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    required this.type,
    this.aktif = false,
  });
}

/// Tanımlı ya da aktif navigasyon rotası.
class MapRoute {
  final String id;
  final String label;

  /// Yol boyunca ardışık dünya koordinatları (metre).
  final List<Offset> waypoints;

  const MapRoute({
    required this.id,
    this.label = '',
    required this.waypoints,
  });
}

/// Dairesel bölge — engel veya güvenli duruş alanı.
class MapZone {
  final String id;
  final String label;

  /// Bölge merkezi — dünya koordinatı (metre).
  final Offset center;

  /// Yarıçap — metre cinsinden.
  final double radius;

  /// `true` = engel (kırmızı), `false` = güvenli duruş (sarı).
  final bool isEngel;

  const MapZone({
    required this.id,
    this.label = '',
    required this.center,
    required this.radius,
    this.isEngel = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Harita anlık görüntüsü (immutable)
// ─────────────────────────────────────────────────────────────────────────────

/// Belirli bir anda haritanın tüm durumunu taşıyan immutable veri sınıfı.
///
/// `GcsMapView` CustomPainter'ına geçirilir. Gerçek veriler
/// `AgvSensorModel` ve `GcsMissionModel` üzerinden doldurulur.
class GcsMapData {
  /// Robot konum + yön (dünya koordinatı, yaw radyan).
  final double robotX;
  final double robotY;
  final double robotYaw;

  /// Sabit ve dinamik harita noktaları.
  final List<MapPoint> points;

  /// Navigasyon rotaları.
  final List<MapRoute> routes;

  /// Engel / güvenli duruş bölgeleri.
  final List<MapZone> zones;

  /// OccupancyGrid arka plan görüntüsü (satır 0 üstte).
  final ui.Image? occupancyImage;

  /// Görüntü ile eşleşen OccupancyGrid metadata.
  final OccupancyGridMetadata? mapMeta;

  const GcsMapData({
    this.robotX = 0.0,
    this.robotY = 0.0,
    this.robotYaw = 0.0,
    this.points = const [],
    this.routes = const [],
    this.zones = const [],
    this.occupancyImage,
    this.mapMeta,
  });

  GcsMapData copyWith({
    double? robotX,
    double? robotY,
    double? robotYaw,
    List<MapPoint>? points,
    List<MapRoute>? routes,
    List<MapZone>? zones,
    ui.Image? occupancyImage,
    OccupancyGridMetadata? mapMeta,
    bool clearOccupancy = false,
  }) =>
      GcsMapData(
        robotX: robotX ?? this.robotX,
        robotY: robotY ?? this.robotY,
        robotYaw: robotYaw ?? this.robotYaw,
        points: points ?? this.points,
        routes: routes ?? this.routes,
        zones: zones ?? this.zones,
        occupancyImage:
            clearOccupancy ? null : (occupancyImage ?? this.occupancyImage),
        mapMeta: clearOccupancy ? null : (mapMeta ?? this.mapMeta),
      );
}
