import 'package:flutter/foundation.dart';

const int maxSafeRosInteger = 9007199254740991;

enum StationTurnDirection {
  left('left', 'Sol'),
  right('right', 'Sağ');

  final String wireValue;
  final String label;

  const StationTurnDirection(this.wireValue, this.label);

  static StationTurnDirection parse(dynamic value) {
    if (value is! String) {
      throw const FormatException('turn_direction string olmalıdır');
    }
    return values.firstWhere(
      (item) => item.wireValue == value,
      orElse: () => throw FormatException(
        'Geçersiz turn_direction: $value (left veya right olmalı)',
      ),
    );
  }
}

@immutable
class StationApproachConfig {
  final String stationId;
  final int stationNodeId;
  final String approachQrId;
  final double dockHeadingYaw;
  final StationTurnDirection turnDirection;
  final double lineFollowDurationS;

  const StationApproachConfig({
    required this.stationId,
    required this.stationNodeId,
    required this.approachQrId,
    required this.dockHeadingYaw,
    required this.turnDirection,
    required this.lineFollowDurationS,
  });

  factory StationApproachConfig.fromRosJson(dynamic raw) {
    if (raw is! Map) {
      throw const FormatException('StationApproachConfig object olmalıdır');
    }
    final json = Map<String, dynamic>.from(raw);
    final stationId = _requiredString(json, 'station_id');
    final nodeId = json['station_node_id'];
    if (nodeId is! int || nodeId < 0 || nodeId > maxSafeRosInteger) {
      throw const FormatException(
        'station_node_id güvenli uint64/int aralığında olmalıdır',
      );
    }
    final yaw = _requiredFiniteDouble(json, 'dock_heading_yaw');
    final duration = _requiredFiniteDouble(json, 'line_follow_duration_s');
    return StationApproachConfig(
      stationId: stationId,
      stationNodeId: nodeId,
      approachQrId: _requiredString(json, 'approach_qr_id'),
      dockHeadingYaw: yaw,
      turnDirection: StationTurnDirection.parse(json['turn_direction']),
      lineFollowDurationS: duration,
    );
  }

  Map<String, dynamic> toRosJson() => {
        'station_id': stationId,
        'station_node_id': stationNodeId,
        'approach_qr_id': approachQrId,
        'dock_heading_yaw': dockHeadingYaw,
        'turn_direction': turnDirection.wireValue,
        'line_follow_duration_s': lineFollowDurationS,
      };

  StationApproachConfig copyWith({
    String? approachQrId,
    double? dockHeadingYaw,
    StationTurnDirection? turnDirection,
    double? lineFollowDurationS,
  }) =>
      StationApproachConfig(
        stationId: stationId,
        stationNodeId: stationNodeId,
        approachQrId: approachQrId ?? this.approachQrId,
        dockHeadingYaw: dockHeadingYaw ?? this.dockHeadingYaw,
        turnDirection: turnDirection ?? this.turnDirection,
        lineFollowDurationS: lineFollowDurationS ?? this.lineFollowDurationS,
      );

  String? validate() {
    if (stationId.trim().isEmpty) return 'İstasyon kimliği boş olamaz';
    if (stationNodeId < 0 || stationNodeId > maxSafeRosInteger) {
      return 'İstasyon düğüm kimliği geçersiz';
    }
    if (approachQrId.trim().isEmpty) return 'Yaklaşma QR kimliği boş olamaz';
    if (!dockHeadingYaw.isFinite) return 'Yanaşma açısı geçersiz';
    if (!lineFollowDurationS.isFinite ||
        lineFollowDurationS < 0.1 ||
        lineFollowDurationS > 120) {
      return 'Şerit takip süresi 0,1–120 saniye arasında olmalı';
    }
    return null;
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key boş olmayan string olmalıdır');
    }
    return value.trim();
  }

  static double _requiredFiniteDouble(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is! num || !value.toDouble().isFinite) {
      throw FormatException('$key sonlu sayı olmalıdır');
    }
    return value.toDouble();
  }
}

double? parseLocalizedDouble(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  final parsed = double.tryParse(normalized);
  return parsed != null && parsed.isFinite ? parsed : null;
}
