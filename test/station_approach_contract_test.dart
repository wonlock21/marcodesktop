import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liftant_v2_bitirme/models/gcs_station_approach_model.dart';
import 'package:liftant_v2_bitirme/models/station_approach_models.dart';
import 'package:liftant_v2_bitirme/services/ros_bridge_client.dart';
import 'package:liftant_v2_bitirme/services/ros_mapping_contract.dart';
import 'package:liftant_v2_bitirme/services/station_approach_repository.dart';

const _a1 = StationApproachConfig(
  stationId: 'A1',
  stationNodeId: 9007199254740991,
  approachQrId: 'QA1',
  dockHeadingYaw: 1.25,
  turnDirection: StationTurnDirection.left,
  lineFollowDurationS: 4.5,
);

void main() {
  test('istasyon config round-trip ve güvenli uint64 sınırı korunur', () {
    final parsed = StationApproachConfig.fromRosJson(_a1.toRosJson());

    expect(parsed.stationNodeId, 9007199254740991);
    expect(parsed.turnDirection, StationTurnDirection.left);
    expect(parsed.toRosJson(), _a1.toRosJson());
    expect(
      () => StationApproachConfig.fromRosJson({
        ..._a1.toRosJson(),
        'station_node_id': 9007199254740992,
      }),
      throwsFormatException,
    );
    expect(
      () => StationApproachConfig.fromRosJson({
        ..._a1.toRosJson(),
        'station_node_id': 4.0,
      }),
      throwsFormatException,
    );
  });

  test('turn_direction, süre ve virgüllü ondalık doğrulanır', () {
    expect(parseLocalizedDouble('4,75'), 4.75);
    expect(parseLocalizedDouble('sonsuz'), isNull);
    expect(
      _a1.copyWith(lineFollowDurationS: 0.09).validate(),
      contains('0,1'),
    );
    expect(
      _a1.copyWith(lineFollowDurationS: 120.01).validate(),
      contains('120'),
    );
    expect(
      () => StationApproachConfig.fromRosJson({
        ..._a1.toRosJson(),
        'turn_direction': 'back',
      }),
      throwsFormatException,
    );
  });

  test('iç success=false ROS işlemini başarısız sayar', () {
    expect(
      () => StationApproachRepository.parseGetResponse({
        'success': false,
        'message': 'paket kilitli',
        'configs': const [],
        'package_hash': '',
      }),
      throwsA(
        isA<StationApproachServiceFailure>().having(
          (error) => error.message,
          'message',
          'paket kilitli',
        ),
      ),
    );
  });

  test('iki istasyon yaklaşma servisi exact ad, tip ve snake_case gönderir',
      () async {
    final calls = <Map<String, dynamic>>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((data) {
        if (data is! String) return;
        final message = Map<String, dynamic>.from(jsonDecode(data));
        if (message['op'] != 'call_service') return;
        calls.add(message);
        final service = message['service'];
        socket.add(jsonEncode({
          'op': 'service_response',
          'id': message['id'],
          'service': service,
          'result': true,
          'values': service == RosMappingTopics.fieldsGetStationApproachConfigs
              ? {
                  'success': true,
                  'message': 'ok',
                  'configs': [_a1.toRosJson()],
                  'package_hash': 'hash-1',
                }
              : {
                  'success': true,
                  'message': 'saved',
                  'saved_config': _a1.toRosJson(),
                  'package_hash': 'hash-2',
                },
        }));
      });
    });

    final client = RosBridgeClient();
    await client.connect('ws://127.0.0.1:${server.port}');
    await client.getStationApproachConfigs('saha_01');
    await client.saveStationApproachConfig(
      fieldName: 'saha_01',
      config: _a1.toRosJson(),
    );

    expect(calls, hasLength(2));
    expect(calls[0]['service'], '/fields/get_station_approach_configs');
    expect(calls[0]['type'], 'marco_msgs/srv/GetStationApproachConfigs');
    expect(calls[0]['args'], {'field_name': 'saha_01'});
    expect(calls[1]['service'], '/fields/save_station_approach_config');
    expect(calls[1]['type'], 'marco_msgs/srv/SaveStationApproachConfig');
    expect(calls[1]['args'], {
      'field_name': 'saha_01',
      'config': _a1.toRosJson(),
    });

    await client.dispose();
    await server.close(force: true);
  });

  test('aktif saha değişince eski GET cevabı uygulanmaz', () async {
    final source = _ControlledSource();
    final model = GcsStationApproachModel(repository: source)
      ..applyConnection(true)
      ..applyRobotStatus({
        'active_field_ready': true,
        'active_field_name': 'saha_eski',
        'active_field_version': 'v1',
        'active_field_hash': 'h1',
      });
    await Future<void>.delayed(Duration.zero);

    model.applyRobotStatus({
      'active_field_ready': true,
      'active_field_name': 'saha_yeni',
      'active_field_version': 'v2',
      'active_field_hash': 'h2',
    });
    await Future<void>.delayed(Duration.zero);

    source.complete(
      'saha_yeni',
      StationApproachConfigSet(
        configs: [_a1.copyWith(approachQrId: 'YENI')],
        packageHash: 'new-hash',
        message: 'ok',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    source.complete(
      'saha_eski',
      StationApproachConfigSet(
        configs: [_a1.copyWith(approachQrId: 'ESKI')],
        packageHash: 'old-hash',
        message: 'ok',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(model.loadedFieldName, 'saha_yeni');
    expect(model.packageHash, 'new-hash');
    expect(model.configs['A1']?.approachQrId, 'YENI');
  });

  test('eksik config ve bağlantı yokken kayıt gönderilmez', () async {
    final source = _ControlledSource();
    final model = GcsStationApproachModel(repository: source);

    expect(await model.save(_a1), isFalse);
    expect(source.saved, isEmpty);
    expect(model.cardError('A1'), contains('hazır'));
  });
}

class _ControlledSource implements StationApproachDataSource {
  final Map<String, Completer<StationApproachConfigSet>> _gets = {};
  final List<StationApproachConfig> saved = [];

  @override
  Future<StationApproachConfigSet> getConfigs(String fieldName) =>
      (_gets[fieldName] ??= Completer<StationApproachConfigSet>()).future;

  void complete(String fieldName, StationApproachConfigSet result) {
    _gets[fieldName]!.complete(result);
  }

  @override
  Future<StationApproachSaveResult> saveConfig({
    required String fieldName,
    required StationApproachConfig config,
  }) async {
    saved.add(config);
    return StationApproachSaveResult(
      savedConfig: config,
      packageHash: 'saved-hash',
      message: 'ok',
    );
  }
}
