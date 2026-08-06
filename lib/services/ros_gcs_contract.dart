import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data_model.dart';

class OccupancyGridMetadata {
  final double resolution;
  final int width;
  final int height;
  final double originX;
  final double originY;
  final double originYaw;

  const OccupancyGridMetadata({
    required this.resolution,
    required this.width,
    required this.height,
    required this.originX,
    required this.originY,
    required this.originYaw,
  });

  factory OccupancyGridMetadata.fromRosMessage(Map<String, dynamic> message) {
    final rawInfo = message['info'];
    if (rawInfo is! Map) {
      throw const FormatException('OccupancyGrid.info eksik');
    }
    final info = Map<String, dynamic>.from(rawInfo);
    final resolution = (info['resolution'] as num?)?.toDouble();
    final width = (info['width'] as num?)?.toInt();
    final height = (info['height'] as num?)?.toInt();
    final rawOrigin = info['origin'];
    if (resolution == null ||
        !resolution.isFinite ||
        resolution <= 0 ||
        width == null ||
        width <= 0 ||
        height == null ||
        height <= 0 ||
        rawOrigin is! Map) {
      throw const FormatException('OccupancyGrid.info alanları geçersiz');
    }
    final origin = Map<String, dynamic>.from(rawOrigin);
    final rawPosition = origin['position'];
    final rawOrientation = origin['orientation'];
    if (rawPosition is! Map || rawOrientation is! Map) {
      throw const FormatException('OccupancyGrid.info.origin geçersiz');
    }
    final position = Map<String, dynamic>.from(rawPosition);
    final orientation = Map<String, dynamic>.from(rawOrientation);
    final x = (position['x'] as num?)?.toDouble();
    final y = (position['y'] as num?)?.toDouble();
    final qx = (orientation['x'] as num?)?.toDouble() ?? 0;
    final qy = (orientation['y'] as num?)?.toDouble() ?? 0;
    final qz = (orientation['z'] as num?)?.toDouble() ?? 0;
    final qw = (orientation['w'] as num?)?.toDouble() ?? 1;
    if (x == null || y == null || !x.isFinite || !y.isFinite) {
      throw const FormatException('OccupancyGrid origin konumu geçersiz');
    }
    final yaw = math.atan2(
      2 * (qw * qz + qx * qy),
      1 - 2 * (qy * qy + qz * qz),
    );
    return OccupancyGridMetadata(
      resolution: resolution,
      width: width,
      height: height,
      originX: x,
      originY: y,
      originYaw: yaw,
    );
  }

  double get mapWidthMeters => width * resolution;
  double get mapHeightMeters => height * resolution;
}

/// ROS rota grafi ile GCS harita editoru arasındaki sözleşme.
abstract final class RosGcsContract {
  static const int editorColumns = 29;
  static const int editorRows = 17;

  static const Map<String, Offset> graphNodes = {
    'bekla_A': Offset(-2, -2),
    'alma_1': Offset(2, -2),
    'alma_2': Offset(3, -1),
    'alma_3': Offset(3, 0),
    'birak_1': Offset(-2, 2),
    'birak_2': Offset(-3, 1),
    'birak_3': Offset(-3, 2),
    'kapi_q5': Offset(2, 2),
  };

  static const Map<String, String> labelsByNode = {
    'bekla_A': 'S1',
    'alma_1': 'A1',
    'alma_2': 'A2',
    'alma_3': 'A3',
    'birak_1': 'B1',
    'birak_2': 'B2',
    'birak_3': 'B3',
    'kapi_q5': 'KAPI',
  };

  /// 29×17 editor grid'indeki bir noktayı canlı OccupancyGrid hücre
  /// merkezine, ardından `info.origin` pozuna dönüştürür.
  static Offset editorGridToMap(
    int gridX,
    int gridY,
    OccupancyGridMetadata metadata,
  ) {
    if (gridX < 0 ||
        gridX >= editorColumns ||
        gridY < 0 ||
        gridY >= editorRows) {
      throw RangeError('Editor grid noktası sınır dışında: ($gridX, $gridY)');
    }
    final screenColumn = editorColumns - 1 - gridX;
    final cellX =
        0.5 + screenColumn / (editorColumns - 1) * (metadata.width - 1);
    final cellY = 0.5 + gridY / (editorRows - 1) * (metadata.height - 1);
    final localX = cellX * metadata.resolution;
    final localY = cellY * metadata.resolution;
    final cosYaw = math.cos(metadata.originYaw);
    final sinYaw = math.sin(metadata.originYaw);
    return Offset(
      metadata.originX + cosYaw * localX - sinYaw * localY,
      metadata.originY + sinYaw * localX + cosYaw * localY,
    );
  }

  static double editorYawToMap(
    double editorYaw,
    OccupancyGridMetadata metadata,
  ) =>
      _normalize(metadata.originYaw + math.pi - editorYaw);

  static double _normalize(double angle) {
    var result = angle;
    while (result > math.pi) {
      result -= 2 * math.pi;
    }
    while (result <= -math.pi) {
      result += 2 * math.pi;
    }
    return result;
  }

  static String? nodeForPoint(DataPoint point) {
    final explicit = point.rosNodeName;
    if (explicit != null && graphNodes.containsKey(explicit)) return explicit;
    if (point.type.startsWith('pickupPoint')) {
      final raw = point.type.substring(11);
      final suffix = raw.startsWith('A') ? raw.substring(1) : raw;
      final node = 'alma_$suffix';
      return graphNodes.containsKey(node) ? node : null;
    }
    if (point.type.startsWith('dropoffPoint')) {
      final raw = point.type.substring(12);
      final suffix = raw.startsWith('B') ? raw.substring(1) : raw;
      final node = 'birak_$suffix';
      return graphNodes.containsKey(node) ? node : null;
    }
    if (point.type.startsWith('startArea')) return 'bekla_A';
    return null;
  }

  static String labelForNode(String node) => labelsByNode[node] ?? node;
}
