import '../models/station_approach_models.dart';
import 'agv_service.dart';

class StationApproachServiceFailure implements Exception {
  final String message;
  const StationApproachServiceFailure(this.message);

  @override
  String toString() => message;
}

class StationApproachConfigSet {
  final List<StationApproachConfig> configs;
  final String packageHash;
  final String message;

  const StationApproachConfigSet({
    required this.configs,
    required this.packageHash,
    required this.message,
  });
}

class StationApproachSaveResult {
  final StationApproachConfig savedConfig;
  final String packageHash;
  final String message;

  const StationApproachSaveResult({
    required this.savedConfig,
    required this.packageHash,
    required this.message,
  });
}

abstract interface class StationApproachDataSource {
  Future<StationApproachConfigSet> getConfigs(String fieldName);

  Future<StationApproachSaveResult> saveConfig({
    required String fieldName,
    required StationApproachConfig config,
  });
}

class StationApproachRepository implements StationApproachDataSource {
  const StationApproachRepository();

  @override
  Future<StationApproachConfigSet> getConfigs(String fieldName) async {
    final response = await AgvService.getStationApproachConfigs(fieldName);
    return parseGetResponse(response);
  }

  static StationApproachConfigSet parseGetResponse(
    Map<String, dynamic> response,
  ) {
    _requireSuccess(response);
    final rawConfigs = response['configs'];
    if (rawConfigs is! List) {
      throw const FormatException('configs JSON array olmalıdır');
    }
    return StationApproachConfigSet(
      configs: List.unmodifiable(
        rawConfigs.map(StationApproachConfig.fromRosJson),
      ),
      packageHash: _requiredString(response, 'package_hash'),
      message: _requiredString(response, 'message'),
    );
  }

  @override
  Future<StationApproachSaveResult> saveConfig({
    required String fieldName,
    required StationApproachConfig config,
  }) async {
    final validationError = config.validate();
    if (validationError != null) {
      throw StationApproachServiceFailure(validationError);
    }
    final response = await AgvService.saveStationApproachConfig(
      fieldName: fieldName,
      config: config,
    );
    return parseSaveResponse(response);
  }

  static StationApproachSaveResult parseSaveResponse(
    Map<String, dynamic> response,
  ) {
    _requireSuccess(response);
    return StationApproachSaveResult(
      savedConfig: StationApproachConfig.fromRosJson(
        response['saved_config'],
      ),
      packageHash: _requiredString(response, 'package_hash'),
      message: _requiredString(response, 'message'),
    );
  }

  static void _requireSuccess(Map<String, dynamic> response) {
    final success = response['success'];
    if (success is! bool) {
      throw const FormatException('success bool olmalıdır');
    }
    if (!success) {
      final message = response['message'];
      throw StationApproachServiceFailure(
        message is String && message.trim().isNotEmpty
            ? message.trim()
            : 'İstasyon yaklaşma işlemi ROS tarafından reddedildi',
      );
    }
  }

  static String _requiredString(Map<String, dynamic> response, String key) {
    final value = response[key];
    if (value is! String) throw FormatException('$key string olmalıdır');
    return value;
  }
}
