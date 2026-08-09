import 'package:flutter_test/flutter_test.dart';
import 'package:liftant_v2_bitirme/models/gcs_mapping_model.dart';
import 'package:liftant_v2_bitirme/models/gcs_node_model.dart';
import 'package:liftant_v2_bitirme/services/ros_bridge_client.dart';
import 'package:liftant_v2_bitirme/services/ros_mapping_contract.dart';

void main() {
  group('RosFieldNameRules', () {
    test('geçerli saha adları', () {
      expect(RosFieldNameRules.isValid('saha_01'), isTrue);
      expect(RosFieldNameRules.isValid('A1-B2'), isTrue);
    });

    test('boşluk ve boş reddedilir', () {
      expect(RosFieldNameRules.validate(''), isNotNull);
      expect(RosFieldNameRules.validate('saha 01'), isNotNull);
      expect(RosFieldNameRules.validate('saha/01'), isNotNull);
    });
  });

  group('RosMappingErrors', () {
    test('A.1 wire kodları Türkçe', () {
      expect(RosMappingErrors.toUserMessage('lidar_not_found'),
          RosMappingErrors.lidarNotFound);
      expect(RosMappingErrors.toUserMessage('stm32_not_found'),
          RosMappingErrors.stm32NotFound);
      expect(RosMappingErrors.toUserMessage('map_save_failed'),
          RosMappingErrors.mapSaveFailed);
    });
  });

  group('Servis bazlı response sözleşmeleri', () {
    final cases =
        <String, ({bool Function(Map<String, dynamic>) check, String key})>{
      '/mapping/start': (
        check: RosServiceResponse.mappingStartAccepted,
        key: 'accepted',
      ),
      '/mapping/stop': (
        check: RosServiceResponse.mappingStopSucceeded,
        key: 'success',
      ),
      '/mapping/save': (
        check: RosServiceResponse.mappingSaveSucceeded,
        key: 'success',
      ),
      '/fields/list': (
        check: RosServiceResponse.fieldsListSucceeded,
        key: 'success',
      ),
      '/localization/start': (
        check: RosServiceResponse.localizationStartAccepted,
        key: 'accepted',
      ),
      '/localization/stop': (
        check: RosServiceResponse.localizationStopSucceeded,
        key: 'success',
      ),
    };

    for (final entry in cases.entries) {
      test('${entry.key}: yalnız gerçek başarı alanı kabul edilir', () {
        final check = entry.value.check;
        final key = entry.value.key;
        final wrongKey = key == 'success' ? 'accepted' : 'success';

        expect(check({key: true}), isTrue);
        expect(check({key: false}), isFalse);
        expect(check({}), isFalse);
        expect(check({wrongKey: true}), isFalse);
        expect(check({'message': 'reddedildi'}), isFalse);
        expect(
          RosServiceResponse.failureMessage({'message': 'reddedildi'}),
          'reddedildi',
        );
      });
    }

    test('boş response anlaşılır hata verir', () {
      expect(
        RosServiceResponse.failureMessage({}),
        'ROS servisi boş cevap döndürdü',
      );
    });
  });

  group('MappingStatus → buton kapıları', () {
    test('idle/error start; mapping finish; starting kilitli', () {
      expect(MappingStatus.idle.canStartMapping, isTrue);
      expect(MappingStatus.error.canStartMapping, isTrue);
      expect(MappingStatus.mapping.canStartMapping, isFalse);
      expect(MappingStatus.mapping.canFinishMapping, isTrue);
      expect(MappingStatus.starting.uiLocked, isTrue);
      expect(MappingStatus.stopping.uiLocked, isTrue);
    });

    test('GcsMappingModel Yeniden Dene etiketi ERROR iken', () {
      final m = GcsMappingModel();
      m.applyConnectionState(
        const RosConnectionState(RosConnectionStatus.connected),
      );
      m.setFieldName('saha_01');
      m.applyMappingStatus(const MappingStatusSnapshot(
        status: MappingStatus.error,
        message: 'LiDAR bulunamadı',
      ));
      expect(m.isMappingError, isTrue);
      expect(m.startButtonLabel, 'Yeniden Dene');
      expect(m.canPromptStartMapping, isTrue);
      expect(m.canStartMapping, isTrue);
    });

    test('MAPPING iken Bitir aktif, start kapalı', () {
      final m = GcsMappingModel();
      m.applyConnectionState(
        const RosConnectionState(RosConnectionStatus.connected),
      );
      m.setFieldName('saha_01');
      m.applyMappingStatus(const MappingStatusSnapshot(
        status: MappingStatus.mapping,
      ));
      expect(m.canPromptStartMapping, isFalse);
      expect(m.canStartMapping, isFalse);
      expect(m.canFinishMapping, isTrue);
      expect(m.startButtonLabel, 'Harita Oluştur');
    });

    test('save sonrası SAVED beklenir', () async {
      final m = GcsMappingModel();
      m.applyConnectionState(
        const RosConnectionState(RosConnectionStatus.connected),
      );
      m.applyMappingStatus(const MappingStatusSnapshot(
        status: MappingStatus.mapping,
      ));
      m.beginFinishMapping();

      var completed = false;
      final waiting = m.waitUntilMappingSaved().then((_) => completed = true);
      m.applyMappingStatus(const MappingStatusSnapshot(
        status: MappingStatus.saving,
      ));
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      m.applyMappingStatus(const MappingStatusSnapshot(
        status: MappingStatus.saved,
      ));
      await waiting;
      expect(completed, isTrue);
      expect(m.finishInFlight, isTrue,
          reason: 'Saha listesi yenilenene kadar yeni mapping başlatılmamalı');
      m.endFinishMapping();
      expect(m.finishInFlight, isFalse);
    });

    test('SAVED beklerken bağlantı koparsa save akışı reddedilir', () async {
      final m = GcsMappingModel();
      m.applyConnectionState(
        const RosConnectionState(RosConnectionStatus.connected),
      );
      m.applyMappingStatus(const MappingStatusSnapshot(
        status: MappingStatus.saving,
      ));

      final waiting = m.waitUntilMappingSaved();
      m.applyConnectionState(
        const RosConnectionState(RosConnectionStatus.error),
      );
      await expectLater(waiting, throwsStateError);
    });

    test('SAVED beklerken ERROR gelirse save akışı reddedilir', () async {
      final m = GcsMappingModel();
      m.applyConnectionState(
        const RosConnectionState(RosConnectionStatus.connected),
      );
      m.applyMappingStatus(const MappingStatusSnapshot(
        status: MappingStatus.saving,
      ));

      final waiting = m.waitUntilMappingSaved();
      m.applyMappingStatus(const MappingStatusSnapshot(
        status: MappingStatus.error,
        message: 'SLAM kapandı',
      ));
      await expectLater(waiting, throwsStateError);
    });

    test('workflow stop çağırmadan doğrudan bir kez save eder', () async {
      final calls = <String>[];

      final response = await RosMappingWorkflow.saveActiveMapping(
        save: () async {
          calls.add('save');
          return {'success': true};
        },
      );
      expect(calls, ['save']);
      expect(response['success'], isTrue);
    });

    test('workflow save reddini hata olarak iletir', () async {
      await expectLater(
        RosMappingWorkflow.saveActiveMapping(
          save: () async => {'success': false, 'message': 'SLAM hazır değil'},
        ),
        throwsStateError,
      );
    });

    test('localization yalnız LOCALIZING durumunda aktif olur', () {
      final m = GcsMappingModel();
      m.beginLocalization('saha_01');
      m.acknowledgeLocalizationStart('saha_01');
      expect(m.activeLocalizedField, isNull);
      m.applyLocalizationStatus(const LocalizationStatusSnapshot(
        status: LocalizationStatus.initializing,
        fieldName: 'saha_01',
      ));
      expect(m.localizationInFlight, isTrue);
      m.applyLocalizationStatus(const LocalizationStatusSnapshot(
        status: LocalizationStatus.localizing,
        fieldName: 'saha_01',
      ));
      expect(m.activeLocalizedField, 'saha_01');
      expect(m.localizationInFlight, isFalse);
    });

    test('fields/list localization_ready alanını korur', () {
      final fields = SavedFieldInfo.fromListFieldsResponse({
        'fields': [
          {
            'field_name': 'saha_01',
            'field_directory': '/data/saha_01',
            'map_yaml': '/data/saha_01/map.yaml',
            'preview_png': '/data/saha_01/map.png',
            'created_at': '2026-08-09',
            'map_ready': true,
            'initial_pose_ready': true,
            'localization_ready': false,
            'message': 'ilk poz eksik',
          }
        ],
      });
      expect(fields.single.localizationReady, isFalse);
      expect(fields.single.isFaulty, isTrue);
      expect(fields.single.mapYaml, endsWith('map.yaml'));
    });
  });

  group('GcsNodeModel ad benzersizliği', () {
    test('aynı ad reddedilir; exceptId ile düzenleme serbest', () {
      final nodes = GcsNodeModel();
      expect(
        nodes.addAtRobot(
          name: 'A1',
          type: FieldNodeType.alma,
          pixelX: 10,
          pixelY: 20,
          screenYaw: 0,
          fieldName: 'saha_01',
        ),
        isTrue,
      );
      expect(nodes.validateNewName('A1'), isNotNull);
      expect(nodes.validateNewName('a1'), isNotNull);
      expect(nodes.validateNewName('B1'), isNull);

      final id = nodes.nodes.first.id;
      expect(nodes.validateName('A1', exceptId: id), isNull);
      expect(
        nodes.updateMeta(id: id, name: 'A1', type: FieldNodeType.birakma),
        isTrue,
      );
    });

    test('geçersiz karakter', () {
      final nodes = GcsNodeModel();
      expect(nodes.validateNewName('A 1'), isNotNull);
      expect(nodes.validateNewName(''), isNotNull);
    });
  });
}
