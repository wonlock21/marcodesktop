import 'dart:convert';

/// Largest integer that can be carried losslessly by JSON on Flutter Web.
const int maxSafeRosJsonId = 9007199254740991;

class RosContractException extends FormatException {
  const RosContractException(super.message);
}

abstract final class FieldGraphId {
  static int _lastGenerated = 0;

  static int requireSafe(dynamic value, String field) {
    if (value is! int || value < 0 || value > maxSafeRosJsonId) {
      throw RosContractException(
        '$field, 0..$maxSafeRosJsonId aralığında JSON int olmalıdır',
      );
    }
    return value;
  }

  static int next() {
    var candidate = DateTime.now().microsecondsSinceEpoch;
    if (candidate <= _lastGenerated) candidate = _lastGenerated + 1;
    if (candidate > maxSafeRosJsonId) {
      throw StateError('Güvenli ROS kimlik aralığı tükendi');
    }
    _lastGenerated = candidate;
    return candidate;
  }
}

abstract final class _RosJson {
  static Map<String, dynamic> object(dynamic value, String field) {
    if (value is! Map) {
      throw RosContractException('$field JSON object olmalıdır');
    }
    return Map<String, dynamic>.from(value);
  }

  static List<dynamic> list(dynamic value, String field) {
    if (value is! List) {
      throw RosContractException('$field JSON array olmalıdır');
    }
    return value;
  }

  static String string(dynamic value, String field) {
    if (value is! String) {
      throw RosContractException('$field string olmalıdır');
    }
    return value;
  }

  static bool boolean(dynamic value, String field) {
    if (value is! bool) {
      throw RosContractException('$field bool olmalıdır');
    }
    return value;
  }

  static int integer(dynamic value, String field, {int? max}) {
    if (value is! int || value < 0 || (max != null && value > max)) {
      throw RosContractException(
          '$field geçerli bir pozitif integer olmalıdır');
    }
    return value;
  }

  static double number(dynamic value, String field) {
    if (value is! num) {
      throw RosContractException('$field number olmalıdır');
    }
    final parsed = value.toDouble();
    if (!parsed.isFinite) {
      throw RosContractException('$field sonlu olmalıdır');
    }
    return parsed;
  }

  static List<String> strings(dynamic value, String field) =>
      List<String>.unmodifiable(
        list(value, field).asMap().entries.map(
              (entry) => string(entry.value, '$field[${entry.key}]'),
            ),
      );

  static void metadataObject(String value, String field) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(value);
    } catch (_) {
      throw RosContractException('$field geçerli JSON olmalıdır');
    }
    if (decoded is! Map) {
      throw RosContractException('$field JSON object metni olmalıdır');
    }
  }
}

class RosTime {
  final int sec;
  final int nanosec;

  const RosTime({required this.sec, required this.nanosec});

  factory RosTime.fromRosJson(dynamic raw) {
    final map = _RosJson.object(raw, 'header.stamp');
    return RosTime(
      sec: _RosJson.integer(map['sec'], 'header.stamp.sec'),
      nanosec: _RosJson.integer(
        map['nanosec'],
        'header.stamp.nanosec',
        max: 999999999,
      ),
    );
  }

  Map<String, dynamic> toRosJson() => {'sec': sec, 'nanosec': nanosec};
}

class RosHeader {
  final RosTime stamp;
  final String frameId;

  const RosHeader({required this.stamp, required this.frameId});

  static const empty = RosHeader(
    stamp: RosTime(sec: 0, nanosec: 0),
    frameId: '',
  );

  factory RosHeader.fromRosJson(dynamic raw) {
    final map = _RosJson.object(raw, 'header');
    return RosHeader(
      stamp: RosTime.fromRosJson(map['stamp']),
      frameId: _RosJson.string(map['frame_id'], 'header.frame_id'),
    );
  }

  Map<String, dynamic> toRosJson() => {
        'stamp': stamp.toRosJson(),
        'frame_id': frameId,
      };
}

class FieldPose2D {
  final double x;
  final double y;
  final double theta;

  const FieldPose2D({required this.x, required this.y, required this.theta});

  static const zero = FieldPose2D(x: 0, y: 0, theta: 0);

  factory FieldPose2D.fromRosJson(dynamic raw) {
    final map = _RosJson.object(raw, 'pose');
    return FieldPose2D(
      x: _RosJson.number(map['x'], 'pose.x'),
      y: _RosJson.number(map['y'], 'pose.y'),
      theta: _RosJson.number(map['theta'], 'pose.theta'),
    );
  }

  Map<String, dynamic> toRosJson() {
    if (!x.isFinite || !y.isFinite || !theta.isFinite) {
      throw const RosContractException('pose alanları sonlu olmalıdır');
    }
    return {'x': x, 'y': y, 'theta': theta};
  }
}

enum FieldNodeRole {
  wait('WAIT'),
  pickupApproach('PICKUP_APPROACH'),
  pickupDock('PICKUP_DOCK'),
  dropoffApproach('DROPOFF_APPROACH'),
  dropoffDock('DROPOFF_DOCK'),
  gateQ5('GATE_Q5'),
  gateQ6('GATE_Q6'),
  qrTrigger('QR_TRIGGER'),
  transit('TRANSIT');

  final String wireName;
  const FieldNodeRole(this.wireName);

  static FieldNodeRole parse(dynamic raw, String field) {
    final value = _RosJson.string(raw, field).trim().toUpperCase();
    return values.firstWhere(
      (entry) => entry.wireName == value,
      orElse: () => throw RosContractException('$field geçersiz: $value'),
    );
  }
}

enum FieldLoadRule {
  any('ANY'),
  empty('EMPTY'),
  loaded('LOADED');

  final String wireName;
  const FieldLoadRule(this.wireName);

  static FieldLoadRule parse(dynamic raw, String field) {
    final value = _RosJson.string(raw, field).trim().toUpperCase();
    return values.firstWhere(
      (entry) => entry.wireName == value,
      orElse: () => throw RosContractException('$field geçersiz: $value'),
    );
  }
}

enum FieldApproachMode {
  navigate('NAVIGATE'),
  dock('DOCK'),
  passThrough('PASS_THROUGH'),
  trigger('TRIGGER');

  final String wireName;
  const FieldApproachMode(this.wireName);

  static FieldApproachMode parse(dynamic raw, String field) {
    final value = _RosJson.string(raw, field).trim().toUpperCase();
    return values.firstWhere(
      (entry) => entry.wireName == value,
      orElse: () => throw RosContractException('$field geçersiz: $value'),
    );
  }
}

enum FieldMovementDirection {
  forward('FORWARD'),
  reverse('REVERSE'),
  either('EITHER');

  final String wireName;
  const FieldMovementDirection(this.wireName);

  static FieldMovementDirection parse(dynamic raw, String field) {
    final value = _RosJson.string(raw, field).trim().toUpperCase();
    return values.firstWhere(
      (entry) => entry.wireName == value,
      orElse: () => throw RosContractException('$field geçersiz: $value'),
    );
  }
}

enum FieldPackageState {
  draft,
  valid,
  active,
  archived,
  error;

  int get code => index;

  static FieldPackageState parse(dynamic raw) {
    final code = _RosJson.integer(raw, 'status.state', max: 4);
    return values[code];
  }
}

class FieldNode {
  final int nodeId;
  final String name;
  final FieldNodeRole role;
  final String stationId;
  final FieldPose2D pose;
  final FieldLoadRule loadRule;
  final FieldApproachMode approachMode;
  final String metadataJson;

  const FieldNode({
    required this.nodeId,
    required this.name,
    required this.role,
    required this.stationId,
    required this.pose,
    required this.loadRule,
    required this.approachMode,
    this.metadataJson = '{}',
  });

  factory FieldNode.fromRosJson(dynamic raw) {
    final map = _RosJson.object(raw, 'node');
    final metadata =
        _RosJson.string(map['metadata_json'], 'node.metadata_json');
    _RosJson.metadataObject(metadata, 'node.metadata_json');
    return FieldNode(
      nodeId: FieldGraphId.requireSafe(map['node_id'], 'node.node_id'),
      name: _RosJson.string(map['name'], 'node.name'),
      role: FieldNodeRole.parse(map['role'], 'node.role'),
      stationId: _RosJson.string(map['station_id'], 'node.station_id'),
      pose: FieldPose2D.fromRosJson(map['pose']),
      loadRule: FieldLoadRule.parse(map['load_rule'], 'node.load_rule'),
      approachMode:
          FieldApproachMode.parse(map['approach_mode'], 'node.approach_mode'),
      metadataJson: metadata,
    );
  }

  FieldNode copyWith({
    String? name,
    FieldNodeRole? role,
    String? stationId,
    FieldPose2D? pose,
    FieldLoadRule? loadRule,
    FieldApproachMode? approachMode,
    String? metadataJson,
  }) =>
      FieldNode(
        nodeId: nodeId,
        name: name ?? this.name,
        role: role ?? this.role,
        stationId: stationId ?? this.stationId,
        pose: pose ?? this.pose,
        loadRule: loadRule ?? this.loadRule,
        approachMode: approachMode ?? this.approachMode,
        metadataJson: metadataJson ?? this.metadataJson,
      );

  Map<String, dynamic> toRosJson() {
    FieldGraphId.requireSafe(nodeId, 'node.node_id');
    _RosJson.metadataObject(metadataJson, 'node.metadata_json');
    if (name.trim().isEmpty) {
      throw const RosContractException('node.name boş olamaz');
    }
    return {
      'node_id': nodeId,
      'name': name.trim(),
      'role': role.wireName,
      'station_id': stationId.trim(),
      'pose': pose.toRosJson(),
      'load_rule': loadRule.wireName,
      'approach_mode': approachMode.wireName,
      'metadata_json': metadataJson,
    };
  }
}

class FieldEdge {
  final int edgeId;
  final int startNodeId;
  final int endNodeId;
  final bool bidirectional;
  final double cost;
  final double maxSpeed;
  final FieldLoadRule loadRule;
  final FieldMovementDirection movementDirection;
  final String gateEvent;
  final String metadataJson;

  const FieldEdge({
    required this.edgeId,
    required this.startNodeId,
    required this.endNodeId,
    required this.bidirectional,
    required this.cost,
    required this.maxSpeed,
    required this.loadRule,
    required this.movementDirection,
    this.gateEvent = '',
    this.metadataJson = '{}',
  });

  factory FieldEdge.fromRosJson(dynamic raw) {
    final map = _RosJson.object(raw, 'edge');
    final metadata =
        _RosJson.string(map['metadata_json'], 'edge.metadata_json');
    _RosJson.metadataObject(metadata, 'edge.metadata_json');
    return FieldEdge(
      edgeId: FieldGraphId.requireSafe(map['edge_id'], 'edge.edge_id'),
      startNodeId:
          FieldGraphId.requireSafe(map['start_node_id'], 'edge.start_node_id'),
      endNodeId:
          FieldGraphId.requireSafe(map['end_node_id'], 'edge.end_node_id'),
      bidirectional:
          _RosJson.boolean(map['bidirectional'], 'edge.bidirectional'),
      cost: _RosJson.number(map['cost'], 'edge.cost'),
      maxSpeed: _RosJson.number(map['max_speed'], 'edge.max_speed'),
      loadRule: FieldLoadRule.parse(map['load_rule'], 'edge.load_rule'),
      movementDirection: FieldMovementDirection.parse(
        map['movement_direction'],
        'edge.movement_direction',
      ),
      gateEvent: _RosJson.string(map['gate_event'], 'edge.gate_event'),
      metadataJson: metadata,
    );
  }

  FieldEdge copyWith({
    int? startNodeId,
    int? endNodeId,
    bool? bidirectional,
    double? cost,
    double? maxSpeed,
    FieldLoadRule? loadRule,
    FieldMovementDirection? movementDirection,
    String? gateEvent,
    String? metadataJson,
  }) =>
      FieldEdge(
        edgeId: edgeId,
        startNodeId: startNodeId ?? this.startNodeId,
        endNodeId: endNodeId ?? this.endNodeId,
        bidirectional: bidirectional ?? this.bidirectional,
        cost: cost ?? this.cost,
        maxSpeed: maxSpeed ?? this.maxSpeed,
        loadRule: loadRule ?? this.loadRule,
        movementDirection: movementDirection ?? this.movementDirection,
        gateEvent: gateEvent ?? this.gateEvent,
        metadataJson: metadataJson ?? this.metadataJson,
      );

  List<String> validationErrors({Iterable<FieldNode> nodes = const []}) {
    final errors = <String>[];
    if (startNodeId == endNodeId) {
      errors.add('Başlangıç ve bitiş düğümü aynı olamaz');
    }
    if (!cost.isFinite || cost <= 0) errors.add('Maliyet 0’dan büyük olmalı');
    if (!maxSpeed.isFinite || maxSpeed < 0.05 || maxSpeed > 0.50) {
      errors.add('Azami hız 0.05..0.50 m/s aralığında olmalı');
    }
    if (loadRule == FieldLoadRule.loaded &&
        movementDirection != FieldMovementDirection.reverse) {
      errors.add('Yüklü kenarın hareket yönü REVERSE olmalı');
    }
    final byId = {for (final node in nodes) node.nodeId: node};
    final startNode = byId[startNodeId];
    final endNode = byId[endNodeId];
    if (startNode != null && endNode != null) {
      final expected = gateEventForRoles(startNode.role, endNode.role);
      if (expected != null && (bidirectional || gateEvent != expected)) {
        errors.add(
          'Gate crossing yönlü olmalı ve gate_event=$expected kullanmalı',
        );
      } else if (expected == null &&
          (gateEvent == 'q5_outbound' || gateEvent == 'q6_return')) {
        errors.add(
          'Gate event yalnız iki gate rolü arasındaki crossing için kullanılabilir',
        );
      }
    }
    try {
      _RosJson.metadataObject(metadataJson, 'edge.metadata_json');
    } on FormatException catch (error) {
      errors.add(error.message);
    }
    return errors;
  }

  Map<String, dynamic> toRosJson() {
    FieldGraphId.requireSafe(edgeId, 'edge.edge_id');
    FieldGraphId.requireSafe(startNodeId, 'edge.start_node_id');
    FieldGraphId.requireSafe(endNodeId, 'edge.end_node_id');
    final errors = validationErrors();
    if (errors.isNotEmpty) throw RosContractException(errors.join('\n'));
    return {
      'edge_id': edgeId,
      'start_node_id': startNodeId,
      'end_node_id': endNodeId,
      'bidirectional': bidirectional,
      'cost': cost,
      'max_speed': maxSpeed,
      'load_rule': loadRule.wireName,
      'movement_direction': movementDirection.wireName,
      'gate_event': gateEvent.trim(),
      'metadata_json': metadataJson,
    };
  }
}

class FieldPackageStatus {
  final RosHeader header;
  final FieldPackageState state;
  final String fieldName;
  final String packageHash;
  final int nodeCount;
  final int edgeCount;
  final List<String> errors;
  final List<String> warnings;
  final String message;

  const FieldPackageStatus({
    required this.header,
    required this.state,
    required this.fieldName,
    required this.packageHash,
    required this.nodeCount,
    required this.edgeCount,
    required this.errors,
    required this.warnings,
    required this.message,
  });

  factory FieldPackageStatus.fromRosJson(dynamic raw) {
    final map = _RosJson.object(raw, 'status');
    return FieldPackageStatus(
      header: RosHeader.fromRosJson(map['header']),
      state: FieldPackageState.parse(map['state']),
      fieldName: _RosJson.string(map['field_name'], 'status.field_name'),
      packageHash: _RosJson.string(map['package_hash'], 'status.package_hash'),
      nodeCount: _RosJson.integer(
        map['node_count'],
        'status.node_count',
        max: 0xffffffff,
      ),
      edgeCount: _RosJson.integer(
        map['edge_count'],
        'status.edge_count',
        max: 0xffffffff,
      ),
      errors: _RosJson.strings(map['errors'], 'status.errors'),
      warnings: _RosJson.strings(map['warnings'], 'status.warnings'),
      message: _RosJson.string(map['message'], 'status.message'),
    );
  }

  static FieldPackageStatus? tryFromTopic(dynamic raw) {
    try {
      return FieldPackageStatus.fromRosJson(raw);
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic> toRosJson() => {
        'header': header.toRosJson(),
        'state': state.code,
        'field_name': fieldName,
        'package_hash': packageHash,
        'node_count': nodeCount,
        'edge_count': edgeCount,
        'errors': errors,
        'warnings': warnings,
        'message': message,
      };
}

class ActiveField {
  final RosHeader header;
  final bool active;
  final String fieldName;
  final String packageVersion;
  final String packageHash;
  final String graphFile;
  final String activatedAt;
  final String message;

  const ActiveField({
    required this.header,
    required this.active,
    required this.fieldName,
    required this.packageVersion,
    required this.packageHash,
    required this.graphFile,
    required this.activatedAt,
    required this.message,
  });

  factory ActiveField.fromRosJson(dynamic raw) {
    final map = _RosJson.object(raw, 'active_field');
    return ActiveField(
      header: RosHeader.fromRosJson(map['header']),
      active: _RosJson.boolean(map['active'], 'active_field.active'),
      fieldName: _RosJson.string(map['field_name'], 'active_field.field_name'),
      packageVersion: _RosJson.string(
        map['package_version'],
        'active_field.package_version',
      ),
      packageHash:
          _RosJson.string(map['package_hash'], 'active_field.package_hash'),
      graphFile: _RosJson.string(map['graph_file'], 'active_field.graph_file'),
      activatedAt:
          _RosJson.string(map['activated_at'], 'active_field.activated_at'),
      message: _RosJson.string(map['message'], 'active_field.message'),
    );
  }

  static ActiveField? tryFromTopic(dynamic raw) {
    try {
      return ActiveField.fromRosJson(raw);
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic> toRosJson() => {
        'header': header.toRosJson(),
        'active': active,
        'field_name': fieldName,
        'package_version': packageVersion,
        'package_hash': packageHash,
        'graph_file': graphFile,
        'activated_at': activatedAt,
        'message': message,
      };
}

class FieldInfo {
  final String fieldName;
  final String fieldDirectory;
  final String mapYaml;
  final String previewPng;
  final String createdAt;
  final bool mapReady;
  final bool initialPoseReady;
  final bool localizationReady;
  final bool routeReady;
  final bool validationPassed;
  final String routeHash;
  final bool active;
  final String packageVersion;
  final String packageHash;
  final String message;

  const FieldInfo({
    required this.fieldName,
    required this.fieldDirectory,
    required this.mapYaml,
    required this.previewPng,
    required this.createdAt,
    required this.mapReady,
    required this.initialPoseReady,
    required this.localizationReady,
    required this.routeReady,
    required this.validationPassed,
    required this.routeHash,
    required this.active,
    required this.packageVersion,
    required this.packageHash,
    required this.message,
  });

  factory FieldInfo.fromRosJson(dynamic raw) {
    final map = _RosJson.object(raw, 'field');
    return FieldInfo(
      fieldName: _RosJson.string(map['field_name'], 'field.field_name'),
      fieldDirectory:
          _RosJson.string(map['field_directory'], 'field.field_directory'),
      mapYaml: _RosJson.string(map['map_yaml'], 'field.map_yaml'),
      previewPng: _RosJson.string(map['preview_png'], 'field.preview_png'),
      createdAt: _RosJson.string(map['created_at'], 'field.created_at'),
      mapReady: _RosJson.boolean(map['map_ready'], 'field.map_ready'),
      initialPoseReady: _RosJson.boolean(
        map['initial_pose_ready'],
        'field.initial_pose_ready',
      ),
      localizationReady: _RosJson.boolean(
        map['localization_ready'],
        'field.localization_ready',
      ),
      routeReady: _RosJson.boolean(map['route_ready'], 'field.route_ready'),
      validationPassed: _RosJson.boolean(
        map['validation_passed'],
        'field.validation_passed',
      ),
      routeHash: _RosJson.string(map['route_hash'], 'field.route_hash'),
      active: _RosJson.boolean(map['active'], 'field.active'),
      packageVersion:
          _RosJson.string(map['package_version'], 'field.package_version'),
      packageHash: _RosJson.string(map['package_hash'], 'field.package_hash'),
      message: _RosJson.string(map['message'], 'field.message'),
    );
  }

  Map<String, dynamic> toRosJson() => {
        'field_name': fieldName,
        'field_directory': fieldDirectory,
        'map_yaml': mapYaml,
        'preview_png': previewPng,
        'created_at': createdAt,
        'map_ready': mapReady,
        'initial_pose_ready': initialPoseReady,
        'localization_ready': localizationReady,
        'route_ready': routeReady,
        'validation_passed': validationPassed,
        'route_hash': routeHash,
        'active': active,
        'package_version': packageVersion,
        'package_hash': packageHash,
        'message': message,
      };
}

class PixelToMapResult {
  final bool success;
  final String message;
  final FieldPose2D pose;
  final bool insideMap;
  final int mapWidth;
  final int mapHeight;

  const PixelToMapResult({
    required this.success,
    required this.message,
    required this.pose,
    required this.insideMap,
    required this.mapWidth,
    required this.mapHeight,
  });

  factory PixelToMapResult.fromServiceResponse(Map<String, dynamic> map) =>
      PixelToMapResult(
        success: _RosJson.boolean(map['success'], 'success'),
        message: _RosJson.string(map['message'], 'message'),
        pose: FieldPose2D.fromRosJson(map['pose']),
        insideMap: _RosJson.boolean(map['inside_map'], 'inside_map'),
        mapWidth:
            _RosJson.integer(map['map_width'], 'map_width', max: 0xffffffff),
        mapHeight:
            _RosJson.integer(map['map_height'], 'map_height', max: 0xffffffff),
      );
}

/// Only semantic roles determine crossing metadata; IDs/coordinates are field data.
String? gateEventForRoles(FieldNodeRole? start, FieldNodeRole? end) {
  if (start == FieldNodeRole.gateQ5 && end == FieldNodeRole.gateQ6) {
    return 'q5_outbound';
  }
  if (start == FieldNodeRole.gateQ6 && end == FieldNodeRole.gateQ5) {
    return 'q6_return';
  }
  return null;
}
