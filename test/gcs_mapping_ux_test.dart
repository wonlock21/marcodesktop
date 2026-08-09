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

    test('stop sonrası save için IDLE beklenir', () async {
      final m = GcsMappingModel();
      m.applyConnectionState(
        const RosConnectionState(RosConnectionStatus.connected),
      );
      m.applyMappingStatus(const MappingStatusSnapshot(
        status: MappingStatus.mapping,
      ));
      m.beginFinishMapping();

      var completed = false;
      final waiting = m.waitUntilMappingIdle().then((_) => completed = true);
      m.applyMappingStatus(const MappingStatusSnapshot(
        status: MappingStatus.stopping,
      ));
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      m.applyMappingStatus(const MappingStatusSnapshot(
        status: MappingStatus.idle,
      ));
      await waiting;
      expect(completed, isTrue);
      expect(m.finishInFlight, isTrue,
          reason: 'Save tamamlanana kadar yeni mapping başlatılmamalı');
      m.endFinishMapping();
      expect(m.finishInFlight, isFalse);
    });

    test('IDLE beklerken bağlantı koparsa save akışı reddedilir', () async {
      final m = GcsMappingModel();
      m.applyConnectionState(
        const RosConnectionState(RosConnectionStatus.connected),
      );
      m.applyMappingStatus(const MappingStatusSnapshot(
        status: MappingStatus.stopping,
      ));

      final waiting = m.waitUntilMappingIdle();
      m.applyConnectionState(
        const RosConnectionState(RosConnectionStatus.error),
      );
      await expectLater(waiting, throwsStateError);
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
