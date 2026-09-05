import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/field_graph_repository.dart';
import 'field_graph_models.dart';
import 'robot_status.dart';

class GcsFieldGraphModel extends ChangeNotifier {
  GcsFieldGraphModel(
      {FieldGraphRepository repository = const FieldGraphRepository()})
      : _repository = repository;

  final FieldGraphRepository _repository;

  List<FieldInfo> fields = const [];
  List<FieldNode> nodes = const [];
  List<FieldEdge> edges = const [];
  List<StationApproachConfig> stationConfigs = const [];
  String? stationConfigsError;
  bool _graphLoaded = false;
  FieldPackageStatus? packageStatus;
  ActiveField? activeField;

  String? selectedFieldName;
  String? fieldsError;
  String? graphError;
  String lastMessage = '';
  String? operation;

  bool connected = false;
  bool fieldsLoading = false;
  bool graphLoading = false;
  bool activeFresh = false;
  bool packageStatusFresh = false;
  bool robotStatusFresh = false;
  bool mappingActive = false;
  bool mappingStatusFresh = false;
  bool missionActive = false;
  bool vehicleMoving = false;

  bool robotActiveFieldReady = false;
  String robotActiveFieldName = '';
  String robotActiveFieldVersion = '';
  String robotActiveFieldHash = '';

  int _graphRevision = 0;
  int? _validatedRevision;
  String? _validatedHash;
  int _syncGeneration = 0;

  bool get busy => operation != null;
  String? get validatedHash => _validatedHash;
  bool get hasSelectedField => selectedFieldName?.isNotEmpty == true;

  FieldInfo? get selectedField {
    final name = selectedFieldName;
    if (name == null) return null;
    for (final field in fields) {
      if (field.fieldName == name) return field;
    }
    return null;
  }

  bool get selectedFieldIsActive {
    final name = selectedFieldName;
    if (name == null) return false;
    return selectedField?.active == true ||
        (activeFresh &&
            activeField?.active == true &&
            activeField?.fieldName == name);
  }

  bool get graphFresh =>
      connected &&
      _graphLoaded &&
      hasSelectedField &&
      !graphLoading &&
      graphError == null;

  bool get canEdit =>
      graphFresh && activeFresh && !selectedFieldIsActive && !busy;

  bool get validationCurrent =>
      _validatedHash?.isNotEmpty == true &&
      _validatedRevision == _graphRevision &&
      packageStatus?.state == FieldPackageState.valid &&
      packageStatus?.packageHash == _validatedHash;

  bool get canActivate =>
      canEdit &&
      activeFresh &&
      robotStatusFresh &&
      validationCurrent &&
      mappingStatusFresh &&
      !mappingActive &&
      !missionActive &&
      !vehicleMoving;

  FieldNode? nodeById(int id) {
    for (final node in nodes) {
      if (node.nodeId == id) return node;
    }
    return null;
  }

  List<FieldEdge> connectedEdges(int nodeId) => edges
      .where(
        (edge) => edge.startNodeId == nodeId || edge.endNodeId == nodeId,
      )
      .toList(growable: false);

  void applyConnection(bool isConnected) {
    if (connected == isConnected) return;
    connected = isConnected;
    if (!isConnected) markDisconnected();
    notifyListeners();
  }

  void markDisconnected() {
    _syncGeneration++;
    _graphLoaded = false;
    stationConfigs = const [];
    connected = false;
    activeFresh = false;
    mappingStatusFresh = false;
    packageStatusFresh = false;
    robotStatusFresh = false;
    robotActiveFieldReady = false;
    robotActiveFieldName = '';
    robotActiveFieldVersion = '';
    robotActiveFieldHash = '';
    fieldsLoading = false;
    graphLoading = false;
    _invalidateValidation();
  }

  void applyMappingActive(bool? value) {
    mappingStatusFresh = value != null;
    if (value != null) mappingActive = value;
    notifyListeners();
  }

  void applyRobotStatus(Map<String, dynamic> status) {
    if (status.isEmpty || !RobotStatus.fromRosJson(status).valid) {
      robotStatusFresh = false;
      missionActive = false;
      vehicleMoving = false;
      robotActiveFieldReady = false;
      robotActiveFieldName = '';
      robotActiveFieldVersion = '';
      robotActiveFieldHash = '';
      notifyListeners();
      return;
    }
    robotStatusFresh = true;
    final missionState = status['mission_state'];
    missionActive = missionState != 0 && missionState != 6;
    final speed = status['linear_speed'];
    vehicleMoving = speed is num && speed.toDouble().abs() > 0.02;
    robotActiveFieldReady = status['active_field_ready'] == true;
    robotActiveFieldName = status['active_field_name'] is String
        ? status['active_field_name'] as String
        : '';
    robotActiveFieldVersion = status['active_field_version'] is String
        ? status['active_field_version'] as String
        : '';
    robotActiveFieldHash = status['active_field_hash'] is String
        ? status['active_field_hash'] as String
        : '';
    notifyListeners();
  }

  void applyActiveTopic(ActiveField? value) {
    if (value == null) {
      activeFresh = false;
      notifyListeners();
      return;
    }
    activeField = value;
    activeFresh = true;
    lastMessage = value.message;
    notifyListeners();
  }

  void applyPackageStatusTopic(FieldPackageStatus? value) {
    if (value == null) {
      packageStatusFresh = false;
      notifyListeners();
      return;
    }
    packageStatusFresh = true;
    if (value.fieldName == selectedFieldName) {
      if (value.packageHash != packageStatus?.packageHash) {
        _invalidateValidation();
        _graphLoaded = false;
      }
      packageStatus = value;
    }
    lastMessage = value.message;
    notifyListeners();
  }

  Future<void> synchronize({String? preferredField}) async {
    if (!connected) return;
    final generation = ++_syncGeneration;
    _invalidateValidation();
    _graphLoaded = false;
    fieldsLoading = true;
    fieldsError = null;
    notifyListeners();

    try {
      final updatedFields = await _repository.listFields();
      if (!connected) return;
      fields = updatedFields;
      fieldsError = null;
    } catch (error) {
      fieldsError = _userError(error, listUnavailable: true);
    } finally {
      if (generation == _syncGeneration) {
        fieldsLoading = false;
        notifyListeners();
      }
    }
    if (generation != _syncGeneration || !connected) return;

    try {
      final active = await _repository.getActive();
      if (generation != _syncGeneration) return;
      activeField = active.activeField;
      activeFresh = true;
      lastMessage = active.message;
      if (active.status.fieldName == selectedFieldName) {
        packageStatus = active.status;
        packageStatusFresh = true;
      }
    } catch (error) {
      if (generation != _syncGeneration) return;
      activeFresh = false;
      lastMessage = _userError(error);
    }
    notifyListeners();

    final requested = preferredField?.trim();
    final selectedExists = fields.any(
      (field) => field.fieldName == selectedFieldName,
    );
    final preferredExists = requested?.isNotEmpty == true &&
        fields.any((field) => field.fieldName == requested);
    if (preferredExists) {
      selectedFieldName = requested;
    } else if (!selectedExists && activeField?.active == true) {
      selectedFieldName = activeField!.fieldName;
    }
    if (selectedFieldName?.isNotEmpty == true) {
      await loadGraph(selectedFieldName!, generation: generation);
    }
  }

  Future<void> refreshFields() async {
    if (!connected || fieldsLoading) return;
    fieldsLoading = true;
    fieldsError = null;
    notifyListeners();
    try {
      final updatedFields = await _repository.listFields();
      if (!connected) return;
      fields = updatedFields;
    } catch (error) {
      fieldsError = _userError(error, listUnavailable: true);
    } finally {
      fieldsLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectField(String fieldName) async {
    final normalized = fieldName.trim();
    if (normalized.isEmpty || !connected || busy || graphLoading) return;
    if (selectedFieldName != normalized) {
      selectedFieldName = normalized;
      nodes = const [];
      edges = const [];
      stationConfigs = const [];
      _graphLoaded = false;
      packageStatus = null;
      _graphRevision++;
      _invalidateValidation();
      notifyListeners();
    }
    await loadGraph(normalized);
  }

  Future<void> loadGraph(String fieldName, {int? generation}) async {
    if (!connected || graphLoading) return;
    final expectedGeneration = generation ?? _syncGeneration;
    graphLoading = true;
    graphError = null;
    notifyListeners();
    try {
      final graph = await _repository.getGraph(fieldName);
      if (!connected || expectedGeneration != _syncGeneration) return;
      if (graph.status.fieldName != fieldName) {
        throw StateError('ROS farklı sahaya ait graph döndürdü');
      }
      selectedFieldName = fieldName;
      nodes = graph.nodes;
      edges = graph.edges;
      if (packageStatus?.packageHash != graph.status.packageHash) {
        _invalidateValidation();
      }
      packageStatus = graph.status;
      _graphLoaded = true;
      packageStatusFresh = true;
      lastMessage = graph.message;
      graphError = null;
      try {
        final configs = await _repository.getStationConfigs(fieldName);
        if (!connected || expectedGeneration != _syncGeneration) return;
        stationConfigs = configs;
        stationConfigsError = null;
      } catch (error) {
        stationConfigs = const [];
        stationConfigsError = _userError(error);
      }
    } catch (error) {
      if (expectedGeneration == _syncGeneration) graphError = _userError(error);
    } finally {
      if (expectedGeneration == _syncGeneration) {
        graphLoading = false;
        notifyListeners();
      }
    }
  }

  Future<PixelToMapResult> pixelToMap({
    required double pixelX,
    required double pixelY,
    required double screenYaw,
  }) async {
    _ensureEditable();
    return _repository.pixelToMap(
      fieldName: selectedFieldName!,
      pixelX: pixelX,
      pixelY: pixelY,
      screenYaw: screenYaw,
    );
  }

  Future<FieldMutationResult> saveNodeAtPixel({
    required FieldNode node,
    required double pixelX,
    required double pixelY,
    required double screenYaw,
  }) async {
    _ensureEditable();
    return _runMutation('node_pixel_save', () async {
      final converted = await _repository.pixelToMap(
        fieldName: selectedFieldName!,
        pixelX: pixelX,
        pixelY: pixelY,
        screenYaw: screenYaw,
      );
      if (!converted.insideMap) {
        throw StateError('Seçilen nokta harita sınırlarının dışında');
      }
      final result = await _repository.saveNode(
        fieldName: selectedFieldName!,
        node: node.copyWith(pose: converted.pose),
        currentPose: false,
      );
      await _afterMutation(result.packageHash);
      return result;
    });
  }

  Future<FieldMutationResult> saveNode(
    FieldNode node, {
    required bool currentPose,
  }) async {
    _ensureEditable();
    return _runMutation('node_save', () async {
      final result = await _repository.saveNode(
        fieldName: selectedFieldName!,
        node: node,
        currentPose: currentPose,
      );
      await _afterMutation(result.packageHash);
      return result;
    });
  }

  Future<void> saveStationConfig(StationApproachConfig config) async {
    _ensureEditable();
    await _runOperation('station_config_save', () async {
      final hash =
          await _repository.saveStationConfig(selectedFieldName!, config);
      await _afterMutation(hash);
      if (stationConfigsError != null) throw StateError(stationConfigsError!);
      lastMessage = 'İstasyon ayarı ROS üzerinden kaydedildi ve yeniden okundu';
    });
  }

  Future<FieldMutationResult> deleteNode(
    int nodeId, {
    required bool deleteConnectedEdges,
  }) async {
    _ensureEditable();
    return _runMutation('node_delete', () async {
      final result = await _repository.deleteNode(
        fieldName: selectedFieldName!,
        nodeId: nodeId,
        deleteConnectedEdges: deleteConnectedEdges,
      );
      await _afterMutation(result.packageHash);
      return result;
    });
  }

  Future<FieldMutationResult> saveEdge(FieldEdge edge) async {
    _ensureEditable();
    final formErrors = edge.validationErrors(nodes: nodes);
    if (formErrors.isNotEmpty) throw StateError(formErrors.join('\n'));
    return _runMutation('edge_save', () async {
      final result = await _repository.saveEdge(
        fieldName: selectedFieldName!,
        edge: edge,
      );
      await _afterMutation(result.packageHash);
      return result;
    });
  }

  Future<FieldMutationResult> deleteEdge(int edgeId) async {
    _ensureEditable();
    return _runMutation('edge_delete', () async {
      final result = await _repository.deleteEdge(
        fieldName: selectedFieldName!,
        edgeId: edgeId,
      );
      await _afterMutation(result.packageHash);
      return result;
    });
  }

  Future<FieldValidationResult> validateSelected() async {
    _ensureEditable();
    return _runOperation('validate', () async {
      final generation = _syncGeneration;
      final result = await _repository.validate(selectedFieldName!);
      _ensureSameSession(generation);
      if (result.status.fieldName != selectedFieldName) {
        throw StateError('ROS farklı sahaya ait durum döndürdü');
      }
      packageStatus = result.status;
      packageStatusFresh = true;
      lastMessage = result.message;
      if (result.success && result.status.state == FieldPackageState.valid) {
        _validatedHash = result.status.packageHash;
        _validatedRevision = _graphRevision;
      } else {
        _invalidateValidation();
      }
      notifyListeners();
      return result;
    });
  }

  Future<FieldActivationResult> activateSelected() async {
    if (!canActivate) {
      throw StateError('Saha şu anda etkinleştirilemez; yeniden doğrulayın');
    }
    final expectedHash = _validatedHash!;
    return _runOperation('activate', () async {
      final generation = _syncGeneration;
      final result = await _repository.activate(
        fieldName: selectedFieldName!,
        expectedHash: expectedHash,
      );
      _ensureSameSession(generation);
      if (result.status.fieldName != selectedFieldName) {
        throw StateError('ROS farklı sahaya ait durum döndürdü');
      }
      packageStatus = result.status;
      packageStatusFresh = true;
      lastMessage = result.message;
      if (!result.success) {
        notifyListeners();
        throw FieldServiceFailure(result.message);
      }
      activeField = result.activeField;
      activeFresh = true;
      notifyListeners();
      await refreshFields();
      await loadGraph(selectedFieldName!);
      return result;
    });
  }

  Future<String> archiveSelected() async {
    _ensureEditable();
    return _runOperation('archive', () async {
      final name = selectedFieldName!;
      final message = await _repository.archive(name);
      lastMessage = message;
      selectedFieldName = null;
      nodes = const [];
      edges = const [];
      stationConfigs = const [];
      _graphLoaded = false;
      packageStatus = null;
      _graphRevision++;
      _invalidateValidation();
      await refreshFields();
      return message;
    });
  }

  Future<void> _afterMutation(String packageHash) async {
    if (!connected) {
      throw StateError(
          'Bağlantı koptu; değişikliğin sonucu ROS üzerinden tekrar okunmalı');
    }
    _graphRevision++;
    _invalidateValidation();
    lastMessage = packageHash;
    notifyListeners();
    await loadGraph(selectedFieldName!);
  }

  Future<T> _runMutation<T>(String name, Future<T> Function() action) =>
      _runOperation(name, action);

  Future<T> _runOperation<T>(String name, Future<T> Function() action) async {
    if (busy) throw StateError('Başka bir saha işlemi devam ediyor');
    operation = name;
    notifyListeners();
    try {
      return await action();
    } finally {
      operation = null;
      notifyListeners();
    }
  }

  void _ensureSameSession(int generation) {
    if (!connected || generation != _syncGeneration) {
      throw StateError(
          'Bağlantı değişti; ROS saha durumunu yeniden sorgulayın');
    }
  }

  void _ensureEditable() {
    if (!connected) throw StateError('ROS bağlı değil');
    if (!hasSelectedField) throw StateError('Önce bir saha seçin');
    if (!activeFresh) throw StateError('Aktif saha durumu güncel değil');
    if (selectedFieldIsActive) throw StateError('Aktif saha salt okunurdur');
    if (!graphFresh) throw StateError('Saha grafiği güncel değil');
    if (busy) throw StateError('Başka bir saha işlemi devam ediyor');
  }

  void _invalidateValidation() {
    _validatedHash = null;
    _validatedRevision = null;
  }

  static String _userError(Object error, {bool listUnavailable = false}) {
    final raw = error.toString().replaceFirst('Bad state: ', '').trim();
    if (listUnavailable) {
      return 'Saha hazırlama servisi kullanılamıyor: $raw';
    }
    return raw.isEmpty ? 'ROS saha işlemi başarısız' : raw;
  }
}
