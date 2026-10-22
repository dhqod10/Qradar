import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/data/models/brand_model.dart';
import 'package:qradar/data/models/qoin_config_model.dart';
import 'package:qradar/data/models/qoin_rate_change_model.dart';
import 'package:qradar/data/models/store_model.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';

void main() {
  group('QoinRateChangeModel.fromMap', () {
    final ts = Timestamp.fromDate(DateTime(2026, 10, 22, 14, 35));

    test('단일 변경: before null(상속) -> after 0.05 왕복', () {
      final e = QoinRateChangeModel.fromMap('h1', {
        'scope': 'store',
        'targetId': 's1',
        'targetName': '강남점',
        'field': 'accrualRate',
        'before': null,
        'after': 0.05,
        'changedBy': 'adminUid',
        'changedAt': ts,
        'reason': '프로모션',
        'source': 'callable',
        'op': 'set',
      })!;
      expect(e.scope, QoinRateScope.store);
      expect(e.targetName, '강남점');
      expect(e.beforeRate, isNull);
      expect(e.afterRate, 0.05);
      expect(e.changedBy, 'adminUid');
      expect(e.changedAt, DateTime(2026, 10, 22, 14, 35));
      expect(e.op, QoinRateChangeOp.set);
      expect(e.isBulk, isFalse);
    });

    test('0(적립 안 함) 과 null(상속) 을 구분한다', () {
      final e = QoinRateChangeModel.fromMap('h', {
        'scope': 'brand',
        'targetId': 'b',
        'field': 'accrualRate',
        'before': 0,
        'after': null,
        'source': 'callable',
        'op': 'clear',
      })!;
      expect(e.beforeRate, 0);
      expect(e.afterRate, isNull);
    });

    test('enabled 필드는 bool 로 읽는다', () {
      final e = QoinRateChangeModel.fromMap('h', {
        'scope': 'global',
        'targetId': 'qoin',
        'field': 'enabled',
        'before': true,
        'after': false,
        'changedBy': null,
        'source': 'direct',
        'op': 'set',
      })!;
      expect(e.field, QoinRateField.enabled);
      expect(e.beforeEnabled, isTrue);
      expect(e.afterEnabled, isFalse);
      expect(e.beforeRate, isNull);
      expect(e.changedBy, isNull);
      expect(e.source, QoinRateChangeSource.direct);
    });

    test('일괄 적용 메타', () {
      final e = QoinRateChangeModel.fromMap('h', {
        'scope': 'brand',
        'targetId': 'b',
        'field': 'accrualRate',
        'before': 0.02,
        'after': 0.06,
        'source': 'bulk',
        'op': 'bulkApply',
        'bulkMode': 'overwrite',
        'status': 'partial',
        'affectedCount': 12,
        'clearedCount': 3,
        'preservedCount': 0,
        'processedCount': 2,
        'totalCount': 3,
        'changedAt': ts,
        'lastProgressAt': ts,
      })!;
      expect(e.isBulk, isTrue);
      expect(e.bulkMode, QoinBulkMode.overwrite);
      expect(e.status, QoinBulkStatus.partial);
      expect(
        [e.affectedCount, e.clearedCount, e.processedCount, e.totalCount],
        [12, 3, 2, 3],
      );
      expect(e.isUnfinished(DateTime(2026, 10, 22, 14, 36)), isTrue);
    });

    test('in_progress 는 5분 지나면 중단(미완료)으로 본다', () {
      final base = {
        'scope': 'brand',
        'targetId': 'b',
        'field': 'accrualRate',
        'before': 0.02,
        'after': 0.06,
        'source': 'bulk',
        'op': 'bulkApply',
        'bulkMode': 'overwrite',
        'status': 'in_progress',
        'changedAt': ts,
        'lastProgressAt': ts,
      };
      final e = QoinRateChangeModel.fromMap('h', base)!;
      expect(e.isUnfinished(DateTime(2026, 10, 22, 14, 39)), isFalse);
      expect(e.isRunning(DateTime(2026, 10, 22, 14, 39)), isTrue);
      expect(e.isUnfinished(DateTime(2026, 10, 22, 14, 41)), isTrue);
      expect(e.isRunning(DateTime(2026, 10, 22, 14, 41)), isFalse);
    });

    test('completed 는 미완료가 아니다', () {
      final e = QoinRateChangeModel.fromMap('h', {
        'scope': 'brand',
        'targetId': 'b',
        'field': 'accrualRate',
        'source': 'bulk',
        'op': 'bulkApply',
        'status': 'completed',
        'changedAt': ts,
      })!;
      expect(e.isUnfinished(DateTime(2030)), isFalse);
    });

    test('알 수 없는 scope / op / source / field -> null (폴백 금지)', () {
      Map<String, dynamic> m(String k, Object v) => {
        'scope': 'store',
        'targetId': 's',
        'field': 'accrualRate',
        'source': 'callable',
        'op': 'set',
        k: v,
      };
      expect(QoinRateChangeModel.fromMap('h', m('scope', 'menu')), isNull);
      expect(QoinRateChangeModel.fromMap('h', m('op', 'rollback')), isNull);
      expect(QoinRateChangeModel.fromMap('h', m('source', 'script')), isNull);
      expect(QoinRateChangeModel.fromMap('h', m('field', 'foo')), isNull);
    });

    test('필수 필드 누락 / 빈 문서 -> null, throw 없음', () {
      expect(QoinRateChangeModel.fromMap('h', const {}), isNull);
      expect(
        QoinRateChangeModel.fromMap('h', {
          'scope': 'store',
          'field': 'accrualRate',
          'source': 'callable',
          'op': 'set',
        }),
        isNull,
        reason: 'targetId 없음',
      );
    });

    test('옛 이력(targetName 없음) 은 빈 문자열', () {
      final e = QoinRateChangeModel.fromMap('h', {
        'scope': 'store',
        'targetId': 's',
        'field': 'accrualRate',
        'source': 'callable',
        'op': 'set',
      })!;
      expect(e.targetName, '');
    });
  });

  group('QoinConfigModel — 전역 경계는 CF 와 같다 (F3 Dart 쪽)', () {
    test('0.5 / 1 / 0 / 음수 / NaN / 문자열 -> accrualRate null, 무효 setting', () {
      for (final v in <Object>[0.5, 1, 0, -0.1, double.nan, '0.03']) {
        final c = QoinConfigModel.fromMap({'accrualRate': v, 'enabled': true});
        expect(c.accrualRate, isNull, reason: '$v');
        expect(c.accrualRateSetting.isInvalid, isTrue, reason: '$v');
      }
    });
    test('부재 -> absent (무효와 구분)', () {
      final c = QoinConfigModel.fromMap({'enabled': true});
      expect(c.accrualRate, isNull);
      expect(c.accrualRateSetting.isAbsent, isTrue);
    });
    test('경계 0.001 / 0.2 유효, 0.2001 무효', () {
      expect(
        QoinConfigModel.fromMap({'accrualRate': 0.001}).accrualRate,
        0.001,
      );
      expect(QoinConfigModel.fromMap({'accrualRate': 0.2}).accrualRate, 0.2);
      expect(
        QoinConfigModel.fromMap({'accrualRate': 0.2001}).accrualRate,
        isNull,
      );
    });
  });

  group('적립률 필드는 쓰기 맵에 절대 들어가지 않는다 (점주 수정이 값을 덮어쓰면 안 된다)', () {
    StoreModel store() => StoreModel(
      id: 's',
      name: 'S',
      imageUrl: '',
      latitude: 0,
      longitude: 0,
      averageScore: 0,
      reviewCount: 0,
      menuCategories: const [],
      createdAt: DateTime(2026),
      qoinAccrualRate: QoinRateSetting.valid(0.05),
    );

    test('StoreModel 쓰기 맵 4종', () {
      final m = store();
      for (final map in [
        m.toFirestoreForCreate(),
        m.toFirestoreForCoreUpdate(isResubmit: true),
        m.toFirestoreForOperationUpdate(),
        m.toFirestoreForBrandCreate(),
      ]) {
        expect(map.containsKey('qoinAccrualRate'), isFalse);
      }
    });

    test('BrandModel.toFirestore', () {
      const b = BrandModel(
        id: 'b',
        name: 'B',
        qoinAccrualRate: QoinRateSetting.zero,
      );
      expect(b.toFirestore().containsKey('qoinAccrualRate'), isFalse);
    });

    test('entity 왕복에서 4값이 보존된다', () {
      final m = store();
      final back = StoreModel.fromEntity(m.toEntity());
      expect(back.qoinAccrualRate, QoinRateSetting.valid(0.05));
      const b = BrandModel(
        id: 'b',
        name: 'B',
        qoinAccrualRate: QoinRateSetting.zero,
      );
      expect(
        BrandModel.fromEntity(b.toEntity()).qoinAccrualRate.isZero,
        isTrue,
      );
    });
  });
}
