import 'package:flutter/material.dart';

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
        MapPointType.almaNoktasi    => 'Alma',
        MapPointType.birakNoktasi   => 'Bırakma',
        MapPointType.beklemeNoktasi => 'Bekleme',
        MapPointType.kapiKontrol    => 'Kapı',
        MapPointType.sarjIstasyonu  => 'Şarj',
        MapPointType.qrNoktasi      => 'QR',
        MapPointType.engel          => 'Engel',
        MapPointType.guvenliDurus   => 'Güvenli',
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

  const GcsMapData({
    this.robotX   = 0.0,
    this.robotY   = 0.0,
    this.robotYaw = 0.0,
    this.points   = const [],
    this.routes   = const [],
    this.zones    = const [],
  });

  GcsMapData copyWith({
    double?         robotX,
    double?         robotY,
    double?         robotYaw,
    List<MapPoint>? points,
    List<MapRoute>? routes,
    List<MapZone>?  zones,
  }) =>
      GcsMapData(
        robotX:   robotX   ?? this.robotX,
        robotY:   robotY   ?? this.robotY,
        robotYaw: robotYaw ?? this.robotYaw,
        points:   points   ?? this.points,
        routes:   routes   ?? this.routes,
        zones:    zones    ?? this.zones,
      );

  // ── Mock factory ─────────────────────────────────────────────────────────

  /// Demo/test amaçlı örnek fabrika katı haritası.
  ///
  /// Senaryo: 8 × 8 m fabrika alanı.
  /// Robot A2'den yük almış, B3'e taşıyor.
  static GcsMapData mock({
    double robotX   = 3.2,
    double robotY   = 2.1,
    double robotYaw = 0.45,
  }) =>
      GcsMapData(
        robotX:   robotX,
        robotY:   robotY,
        robotYaw: robotYaw,
        points: const [
          // Alma noktaları
          MapPoint(id: 'a1', label: 'A1', x: 1.0, y: 0.5,  type: MapPointType.almaNoktasi),
          MapPoint(id: 'a2', label: 'A2', x: 2.0, y: 0.5,  type: MapPointType.almaNoktasi,  aktif: true),
          MapPoint(id: 'a3', label: 'A3', x: 3.0, y: 0.5,  type: MapPointType.almaNoktasi),
          MapPoint(id: 'a4', label: 'A4', x: 4.0, y: 0.5,  type: MapPointType.almaNoktasi),
          // Bırakma noktaları
          MapPoint(id: 'b1', label: 'B1', x: 1.0, y: 4.5,  type: MapPointType.birakNoktasi),
          MapPoint(id: 'b2', label: 'B2', x: 2.0, y: 4.5,  type: MapPointType.birakNoktasi),
          MapPoint(id: 'b3', label: 'B3', x: 4.0, y: 4.5,  type: MapPointType.birakNoktasi, aktif: true),
          MapPoint(id: 'b4', label: 'B4', x: 5.0, y: 4.5,  type: MapPointType.birakNoktasi),
          // Bekleme / başlangıç
          MapPoint(id: 's1', label: 'S1', x: 0.5, y: 0.5,  type: MapPointType.beklemeNoktasi),
          MapPoint(id: 's2', label: 'S2', x: 0.5, y: 2.5,  type: MapPointType.beklemeNoktasi),
          // Kapı kontrol
          MapPoint(id: 'd1', label: 'KAPI-1', x: 3.0, y: 3.0, type: MapPointType.kapiKontrol),
          // Şarj istasyonu
          MapPoint(id: 'cs', label: 'CS',   x: -1.5, y: 1.5, type: MapPointType.sarjIstasyonu),
          // Son QR
          MapPoint(id: 'qr_last', label: 'QA2.1', x: 2.0, y: 0.5, type: MapPointType.qrNoktasi),
        ],
        routes: const [
          MapRoute(
            id: 'aktif_rota',
            label: 'A2 → B3',
            waypoints: [
              Offset(0.5, 0.5),
              Offset(2.0, 0.5),
              Offset(3.2, 2.1),
              Offset(4.0, 4.5),
            ],
          ),
        ],
        zones: const [
          MapZone(
            id: 'obs1',
            label: 'Engel',
            center: Offset(5.5, 1.5),
            radius: 0.6,
            isEngel: true,
          ),
          MapZone(
            id: 'safe1',
            label: 'Güvenli',
            center: Offset(-0.5, 3.5),
            radius: 0.8,
            isEngel: false,
          ),
        ],
      );
}
