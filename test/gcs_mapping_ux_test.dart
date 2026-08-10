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
      '/demo/point/save': (
        check: RosServiceResponse.demoPointSaveSucceeded,
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
      expect(m.canSaveDemoPoint, isFalse);
      m.applyConnectionState(
        const RosConnectionState(RosConnectionStatus.connected),
      );
      expect(m.canSaveDemoPoint, isTrue);
    });

    test('robot ikonu lokalizasyonda yalnız geçerli AMCL pozunu kullanır', () {
      final m = GcsMappingModel();
      m.applyConnectionState(
        const RosConnectionState(RosConnectionStatus.connected),
      );
      const slamPixel = MapPreviewRobotPixel(
        pixelX: 10,
        pixelY: 20,
        screenYaw: 0,
        mapWidth: 100,
        mapHeight: 100,
        insideMap: true,
        source: MapPreviewSource.slam_toolbox,
      );
      const amclPixel = MapPreviewRobotPixel(
        pixelX: 30,
        pixelY: 40,
        screenYaw: 1,
        mapWidth: 100,
        mapHeight: 100,
        insideMap: true,
        source: MapPreviewSource.amcl,
      );

      m.applyRobotPixel(slamPixel);
      expect(m.visibleRobotPixel, isNull);
      m.beginLocalization('saha_01');
      m.acknowledgeLocalizationStart('saha_01');
      m.applyLocalizationStatus(const LocalizationStatusSnapshot(
        status: LocalizationStatus.initializing,
        fieldName: 'saha_01',
      ));
      expect(m.visibleRobotPixel, isNull);
      m.applyLocalizationStatus(const LocalizationStatusSnapshot(
        status: LocalizationStatus.localizing,
        fieldName: 'saha_01',
      ));
      expect(m.visibleRobotPixel, isNull);
      m.applyRobotPixel(amclPixel);
      expect(m.visibleRobotPixel, same(amclPixel));
    });

    test('demo point servis cevabındaki pose parse edilir', () {
      final result = DemoPointSaveResult.fromServiceResponse({
        'success': true,
        'message': 'A noktası kaydedildi',
        'pose': {'x': 1.25, 'y': -0.5, 'theta': 1.57},
        'points_file': '/data/demo_points.yaml',
      });
      expect(result.success, isTrue);
      expect(result.pose?.x, 1.25);
      expect(result.pose?.theta, 1.57);
      expect(result.pointsFile, endsWith('demo_points.yaml'));
    });

    test('demo kapıları lokalizasyon, A/B, WAITING_LOAD ve engele bağlıdır',
        () {
      final m = GcsMappingModel();
      m.applyConnectionState(
        const RosConnectionState(RosConnectionStatus.connected),
      );
      m.beginLocalization('saha_01');
      m.acknowledgeLocalizationStart('saha_01');
      m.applyLocalizationStatus(const LocalizationStatusSnapshot(
        status: LocalizationStatus.localizing,
        fieldName: 'saha_01',
      ));
      expect(m.canStartDemo, isFalse);

      m.markDemoPointSaved(
        'A',
        const DemoPointSaveResult(
          success: true,
          pose: DemoPointPose(x: 1, y: 2, theta: 0),
        ),
      );
      m.markDemoPointSaved(
        'B',
        const DemoPointSaveResult(
          success: true,
          pose: DemoPointPose(x: 3, y: 4, theta: 1),
        ),
      );
      expect(m.canStartDemo, isTrue);

      m.applyDemoStatus(const DemoStatusSnapshot(
        status: DemoStatus.waitingLoad,
        message: 'Yük yerleştirilmesi bekleniyor',
        pointA: DemoPointPose(x: 1, y: 2, theta: 0),
        pointB: DemoPointPose(x: 3, y: 4, theta: 1),
      ));
      expect(m.canContinueDemo, isTrue);
      expect(m.canCancelDemo, isTrue);
      m.applyObstacleDetected(true);
      expect(m.canContinueDemo, isFalse);
      expect(m.demoStatusLine, 'Engel algılandı, araç bekliyor');
      m.applyObstacleDetected(false);
      expect(m.canContinueDemo, isTrue);
    });

    test('/demo/status alanları parse edilir', () {
      final status = DemoStatusSnapshot.fromRosMessage({
        'state': 6,
        'message': 'B noktasına gidiliyor',
        'active_target': 'B',
        'point_a': {'x': 1.0, 'y': 2.0, 'theta': 0.1},
        'point_b': {'x': 3.0, 'y': 4.0, 'theta': 0.2},
      });
      expect(status.status, DemoStatus.navigatingB);
      expect(status.activeTarget, 'B');
      expect(status.pointA.x, 1.0);
      expect(status.pointB.theta, 0.2);
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
