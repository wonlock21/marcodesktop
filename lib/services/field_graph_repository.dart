import '../models/field_graph_models.dart';
import 'agv_service.dart';

class FieldServiceFailure implements Exception {
  final String message;
  const FieldServiceFailure(this.message);

  @override
  String toString() => message;
}

class FieldGraphData {
  final String message;
  final List<FieldNode> nodes;
  final List<FieldEdge> edges;
  final FieldPackageStatus status;

  const FieldGraphData({
    required this.message,
    required this.nodes,
    required this.edges,
    required this.status,
  });
}

class FieldMutationResult {
  final String message;
  final String packageHash;
  final FieldNode? savedNode;
  final FieldEdge? savedEdge;
  final int deletedEdgeCount;

  const FieldMutationResult({
    required this.message,
    required this.packageHash,
    this.savedNode,
    this.savedEdge,
    this.deletedEdgeCount = 0,
  });
}

class FieldValidationResult {
  final bool success;
  final String message;
  final FieldPackageStatus status;

  const FieldValidationResult({
    required this.success,
    required this.message,
    required this.status,
  });
}

class FieldActivationResult {
  final bool success;
  final String message;
  final ActiveField activeField;
  final FieldPackageStatus status;

  const FieldActivationResult({
    required this.success,
    required this.message,
    required this.activeField,
    required this.status,
  });
}

class ActiveFieldResult {
  final String message;
  final ActiveField activeField;
  final FieldPackageStatus status;

  const ActiveFieldResult({
    required this.message,
    required this.activeField,
    required this.status,
  });
}

/// Typed boundary between rosbridge JSON and the GCS state/UI.
class FieldGraphRepository {
  const FieldGraphRepository();

  static String _requiredString(
    Map<String, dynamic> response,
    String field,
  ) {
    final value = response[field];
    if (value is! String) {
      throw RosContractException('$field string olmalıdır');
    }
    return value;
  }

  static bool _requiredBool(Map<String, dynamic> response, String field) {
    final value = response[field];
    if (value is! bool) {
      throw RosContractException('$field bool olmalıdır');
    }
    return value;
  }

  static int _requiredUint32(Map<String, dynamic> response, String field) {
    final value = response[field];
    if (value is! int || value < 0 || value > 0xffffffff) {
      throw RosContractException('$field uint32 olmalıdır');
    }
    return value;
  }

  static String _message(Map<String, dynamic> response) =>
      _requiredString(response, 'message');

  static void _requireSuccess(Map<String, dynamic> response) {
    final success = _requiredBool(response, 'success');
    if (!success) {
      final message = response['message'];
      throw FieldServiceFailure(
        message is String && message.trim().isNotEmpty
            ? message.trim()
            : 'ROS saha işlemi reddedildi',
      );
    }
  }

  Future<List<StationApproachConfig>> getStationConfigs(
      String fieldName) async {
    final response = await AgvService.ros.getStationApproachConfigs(fieldName);
    _requireSuccess(response);
    _requiredString(response, 'package_hash');
    final raw = response['configs'];
    if (raw is! List) {
      throw const RosContractException('configs JSON array olmalıdır');
    }
    return List.unmodifiable(raw.map(StationApproachConfig.fromRosJson));
  }

  Future<String> saveStationConfig(
      String fieldName, StationApproachConfig config) async {
    final response =
        await AgvService.ros.saveStationApproachConfig(fieldName, config);
    _requireSuccess(response);
    StationApproachConfig.fromRosJson(response['saved_config']);
    return _requiredString(response, 'package_hash');
  }

  Future<List<FieldInfo>> listFields() async {
    final response = await AgvService.listFields();
    _requireSuccess(response);
    final raw = response['fields'];
    if (raw is! List) {
      throw const RosContractException('fields JSON array olmalıdır');
    }
    return List<FieldInfo>.unmodifiable(raw.map(FieldInfo.fromRosJson));
  }

  Future<FieldGraphData> getGraph(String fieldName) async {
    final response = await AgvService.getFieldGraph(fieldName);
    _requireSuccess(response);
    final rawNodes = response['nodes'];
    final rawEdges = response['edges'];
    if (rawNodes is! List || rawEdges is! List) {
      throw const RosContractException('nodes/edges JSON array olmalıdır');
    }
    return FieldGraphData(
      message: _message(response),
      nodes: List<FieldNode>.unmodifiable(rawNodes.map(FieldNode.fromRosJson)),
      edges: List<FieldEdge>.unmodifiable(rawEdges.map(FieldEdge.fromRosJson)),
      status: FieldPackageStatus.fromRosJson(response['status']),
    );
  }

  Future<FieldMutationResult> saveNode({
    required String fieldName,
    required FieldNode node,
    required bool currentPose,
  }) async {
    final response = currentPose
        ? await AgvService.saveCurrentPoseNode(
            fieldName: fieldName,
            node: node,
          )
        : await AgvService.saveFieldNode(fieldName: fieldName, node: node);
    _requireSuccess(response);
    return FieldMutationResult(
      message: _message(response),
      packageHash: _requiredString(response, 'package_hash'),
      savedNode: FieldNode.fromRosJson(response['saved_node']),
    );
  }

  Future<FieldMutationResult> deleteNode({
    required String fieldName,
    required int nodeId,
    required bool deleteConnectedEdges,
  }) async {
    final response = await AgvService.deleteFieldNode(
      fieldName: fieldName,
      nodeId: nodeId,
      deleteConnectedEdges: deleteConnectedEdges,
    );
    _requireSuccess(response);
    return FieldMutationResult(
      message: _message(response),
      packageHash: _requiredString(response, 'package_hash'),
      deletedEdgeCount: _requiredUint32(response, 'deleted_edge_count'),
    );
  }

  Future<FieldMutationResult> saveEdge({
    required String fieldName,
    required FieldEdge edge,
  }) async {
    final response =
        await AgvService.saveFieldEdge(fieldName: fieldName, edge: edge);
    _requireSuccess(response);
    return FieldMutationResult(
      message: _message(response),
      packageHash: _requiredString(response, 'package_hash'),
      savedEdge: FieldEdge.fromRosJson(response['saved_edge']),
    );
  }

  Future<FieldMutationResult> deleteEdge({
    required String fieldName,
    required int edgeId,
  }) async {
    final response =
        await AgvService.deleteFieldEdge(fieldName: fieldName, edgeId: edgeId);
    _requireSuccess(response);
    return FieldMutationResult(
      message: _message(response),
      packageHash: _requiredString(response, 'package_hash'),
    );
  }

  Future<PixelToMapResult> pixelToMap({
    required String fieldName,
    required double pixelX,
    required double pixelY,
    required double screenYaw,
  }) async {
    final response = await AgvService.pixelToMap(
      fieldName: fieldName,
      pixelX: pixelX,
      pixelY: pixelY,
      screenYaw: screenYaw,
    );
    final parsed = PixelToMapResult.fromServiceResponse(response);
    if (!parsed.success) throw FieldServiceFailure(parsed.message);
    return parsed;
  }

  Future<FieldValidationResult> validate(String fieldName) async {
    final response = await AgvService.validateField(fieldName);
    return FieldValidationResult(
      success: _requiredBool(response, 'success'),
      message: _message(response),
      status: FieldPackageStatus.fromRosJson(response['status']),
    );
  }

  Future<FieldActivationResult> activate({
    required String fieldName,
    required String expectedHash,
  }) async {
    final response = await AgvService.activateField(
      fieldName: fieldName,
      expectedHash: expectedHash,
    );
    return FieldActivationResult(
      success: _requiredBool(response, 'success'),
      message: _message(response),
      activeField: ActiveField.fromRosJson(response['active_field']),
      status: FieldPackageStatus.fromRosJson(response['status']),
    );
  }

  Future<String> archive(String fieldName) async {
    final response = await AgvService.archiveField(fieldName);
    _requireSuccess(response);
    _requiredString(response, 'archive_directory');
    return _message(response);
  }

  Future<ActiveFieldResult> getActive() async {
    final response = await AgvService.getActiveField();
    _requireSuccess(response);
    return ActiveFieldResult(
      message: _message(response),
      activeField: ActiveField.fromRosJson(response['active_field']),
      status: FieldPackageStatus.fromRosJson(response['status']),
    );
  }
}
