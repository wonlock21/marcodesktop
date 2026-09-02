import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/station_approach_repository.dart';
import 'station_approach_models.dart';

class GcsStationApproachModel extends ChangeNotifier {
  GcsStationApproachModel({StationApproachDataSource? repository})
      : _repository = repository ?? const StationApproachRepository();

  static const expectedStationIds = ['A1', 'A2', 'A3', 'B1', 'B2', 'B3'];

  final StationApproachDataSource _repository;
  final Map<String, StationApproachConfig> _configs = {};
  final Set<String> _savingStations = {};
  final Map<String, String> _cardErrors = {};

  bool connected = false;
  bool activeFieldReady = false;
  String activeFieldName = '';
  String activeFieldVersion = '';
  String activeFieldHash = '';
  String packageHash = '';
  String loadedFieldName = '';
  bool loading = false;
  bool fresh = false;
  String errorMessage = '';
  int _generation = 0;

  Map<String, StationApproachConfig> get configs => Map.unmodifiable(_configs);
  Set<String> get savingStations => Set.unmodifiable(_savingStations);
  String? cardError(String stationId) => _cardErrors[stationId];
  bool isSaving(String stationId) => _savingStations.contains(stationId);
  bool get canLoad =>
      connected && activeFieldReady && activeFieldName.isNotEmpty;
  bool get canEdit => canLoad && fresh && loadedFieldName == activeFieldName;

  void applyConnection(bool value) {
    if (connected == value) return;
    connected = value;
    if (!value) {
      _invalidate(clearActiveField: false);
    } else if (canLoad) {
      unawaited(refresh());
    }
    notifyListeners();
  }

  void applyRobotStatus(Map<String, dynamic> status) {
    if (status.isEmpty) {
      if (activeFieldReady || fresh) {
        activeFieldReady = false;
        _invalidate(clearActiveField: false);
        notifyListeners();
      }
      return;
    }

    final nextReady = status['active_field_ready'] == true;
    final nextName = status['active_field_name']?.toString().trim() ?? '';
    final nextVersion = status['active_field_version']?.toString().trim() ?? '';
    final nextHash = status['active_field_hash']?.toString().trim() ?? '';
    final fieldChanged = nextName != activeFieldName;
    final readinessChanged = nextReady != activeFieldReady;
    final metadataChanged =
        nextVersion != activeFieldVersion || nextHash != activeFieldHash;

    activeFieldReady = nextReady;
    activeFieldName = nextName;
    activeFieldVersion = nextVersion;
    activeFieldHash = nextHash;

    if (fieldChanged || !nextReady || nextName.isEmpty) {
      _invalidate(clearActiveField: false);
    }
    if (connected && canLoad && (fieldChanged || readinessChanged)) {
      unawaited(refresh());
    }
    if (fieldChanged || readinessChanged || metadataChanged) {
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (!canLoad || loading) return;
    final requestedField = activeFieldName;
    final requestGeneration = ++_generation;
    loading = true;
    errorMessage = '';
    notifyListeners();
    try {
      final result = await _repository.getConfigs(requestedField);
      if (!_isCurrent(requestGeneration, requestedField)) return;
      _configs
        ..clear()
        ..addEntries(
          result.configs
              .where((item) => expectedStationIds.contains(item.stationId))
              .map((item) => MapEntry(item.stationId, item)),
        );
      packageHash = result.packageHash;
      loadedFieldName = requestedField;
      fresh = true;
    } catch (error) {
      if (!_isCurrent(requestGeneration, requestedField)) return;
      fresh = false;
      errorMessage = _userMessage(error);
    } finally {
      if (_isCurrent(requestGeneration, requestedField)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> save(StationApproachConfig config) async {
    final stationId = config.stationId;
    if (_savingStations.contains(stationId)) return false;
    if (!canEdit) {
      _cardErrors[stationId] =
          'Aktif saha hazır ve güncel değil; kayıt gönderilmedi';
      notifyListeners();
      return false;
    }
    final current = _configs[stationId];
    if (current == null || current.stationNodeId != config.stationNodeId) {
      _cardErrors[stationId] =
          'İstasyon düğüm kimliği güncel ROS verisiyle eşleşmiyor';
      notifyListeners();
      return false;
    }
    final validationError = config.validate();
    if (validationError != null) {
      _cardErrors[stationId] = validationError;
      notifyListeners();
      return false;
    }

    final requestedField = activeFieldName;
    final requestGeneration = _generation;
    _savingStations.add(stationId);
    _cardErrors.remove(stationId);
    notifyListeners();
    try {
      final result = await _repository.saveConfig(
        fieldName: requestedField,
        config: config,
      );
      if (!_isCurrent(requestGeneration, requestedField)) return false;
      if (result.savedConfig.stationId != stationId ||
          result.savedConfig.stationNodeId != current.stationNodeId) {
        throw const FormatException(
          'ROS yanıtındaki istasyon veya düğüm kimliği istekle eşleşmiyor',
        );
      }
      _configs[stationId] = result.savedConfig;
      packageHash = result.packageHash;
      fresh = true;
      notifyListeners();
      await _refreshAfterSave(requestedField, requestGeneration);
      return true;
    } catch (error) {
      if (_isCurrent(requestGeneration, requestedField)) {
        _cardErrors[stationId] = _userMessage(error);
      }
      return false;
    } finally {
      _savingStations.remove(stationId);
      notifyListeners();
    }
  }

  Future<void> _refreshAfterSave(String fieldName, int generation) async {
    try {
      final result = await _repository.getConfigs(fieldName);
      if (!_isCurrent(generation, fieldName)) return;
      _configs
        ..clear()
        ..addEntries(
          result.configs
              .where((item) => expectedStationIds.contains(item.stationId))
              .map((item) => MapEntry(item.stationId, item)),
        );
      packageHash = result.packageHash;
      loadedFieldName = fieldName;
      fresh = true;
    } catch (error) {
      if (_isCurrent(generation, fieldName)) {
        errorMessage =
            'Kayıt başarılı, yenileme başarısız: ${_userMessage(error)}';
      }
    }
  }

  bool _isCurrent(int generation, String fieldName) =>
      generation == _generation &&
      connected &&
      activeFieldReady &&
      activeFieldName == fieldName;

  void _invalidate({required bool clearActiveField}) {
    _generation++;
    loading = false;
    fresh = false;
    loadedFieldName = '';
    packageHash = '';
    errorMessage = '';
    _configs.clear();
    _cardErrors.clear();
    if (clearActiveField) {
      activeFieldReady = false;
      activeFieldName = '';
      activeFieldVersion = '';
      activeFieldHash = '';
    }
  }

  static String _userMessage(Object error) {
    if (error is StationApproachServiceFailure) return error.message;
    final text =
        error.toString().replaceFirst(RegExp(r'^\w+(?:Error)?:\s*'), '');
    return text.isEmpty ? 'İstasyon yaklaşma işlemi başarısız' : text;
  }
}
