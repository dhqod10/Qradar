import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/domain/entities/qoin_bulk_banner.dart';
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
      expect(
        e.field,
        QoinRateField.globalEnabled,
      ); // 개명 전 코드 `enabled` 도 같은 것으로 읽는다
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
      expect(
        resolveHistoryRow(e, pointer: null, now: DateTime(2026, 10, 22, 14, 36))
            .isUnfinished,
        isTrue,
      );
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
      QoinHistoryRowState at(DateTime now) =>
          resolveHistoryRow(e, pointer: null, now: now);
      expect(at(DateTime(2026, 10, 22, 14, 39)).isUnfinished, isFalse);
      expect(at(DateTime(2026, 10, 22, 14, 39)).isRunning, isTrue);
      expect(at(DateTime(2026, 10, 22, 14, 41)).isUnfinished, isTrue);
      expect(at(DateTime(2026, 10, 22, 14, 41)).isRunning, isFalse);
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
      expect(resolveHistoryRow(e, pointer: null, now: DateTime(2030)).isUnfinished, isFalse);
    });

    test(
      '알 수 없는 scope / field -> null (폴백 금지), op / source 미지값은 unknown 으로 관대하게',
      () {
        Map<String, dynamic> m(String k, Object v) => {
          'scope': 'store',
          'targetId': 's',
          'field': 'accrualRate',
          'source': 'callable',
          'op': 'set',
          k: v,
        };
        expect(QoinRateChangeModel.fromMap('h', m('scope', 'menu')), isNull);
        expect(
          QoinRateChangeModel.fromMap('h', m('op', 'rollback'))!.op,
          QoinRateChangeOp.unknown,
        );
        expect(
          QoinRateChangeModel.fromMap('h', m('source', 'script'))!.source,
          QoinRateChangeSource.unknown,
        );
        expect(QoinRateChangeModel.fromMap('h', m('field', 'foo')), isNull);
      },
    );

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
    test(
      '0.5 / 1 / 0 / 음수 / NaN / 문자열 -> accrualRate null, 무효 setting (전역 0 도 무효, legacyZero 아님)',
      () {
        for (final v in <Object>[0.5, 1, 0, -0.1, double.nan, '0.03']) {
          final c = QoinConfigModel.fromMap({
            'accrualRate': v,
            'enabled': true,
          });
          expect(c.accrualRate, isNull, reason: '$v');
          expect(c.accrualRateSetting.isInvalid, isTrue, reason: '$v');
        }
      },
    );
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
      qoinAccrualEnabled: QoinSwitchSetting.disabled,
    );

    test('StoreModel 쓰기 맵 4종 — qoin* 필드가 하나도 없다', () {
      final m = store();
      for (final map in [
        m.toFirestoreForCreate(),
        m.toFirestoreForCoreUpdate(isResubmit: true),
        m.toFirestoreForOperationUpdate(),
        m.toFirestoreForBrandCreate(),
      ]) {
        expect(map.keys.where((k) => k.startsWith('qoin')), isEmpty);
      }
    });

    test('BrandModel.toFirestore — 적립률·스위치·일괄 포인터 어느 것도 쓰지 않는다', () {
      final b = BrandModel(
        id: 'b',
        name: 'B',
        qoinAccrualRate: QoinRateSetting.valid(0.05),
        qoinAccrualEnabled: QoinSwitchSetting.disabled,
        qoinBulkHistoryId: 'h1',
        qoinBulkStatus: QoinBulkStatus.partial,
        qoinBulkAt: DateTime(2026),
      );
      expect(b.toFirestore().keys.where((k) => k.startsWith('qoin')), isEmpty);
    });

    test('entity 왕복에서 적립률·스위치·포인터가 보존된다', () {
      final m = store();
      final back = StoreModel.fromEntity(m.toEntity());
      expect(back.qoinAccrualRate, QoinRateSetting.valid(0.05));
      expect(back.qoinAccrualEnabled, QoinSwitchSetting.disabled);
      final b = BrandModel(
        id: 'b',
        name: 'B',
        qoinAccrualEnabled: QoinSwitchSetting.disabled,
        qoinBulkHistoryId: 'h1',
        qoinBulkStatus: QoinBulkStatus.inProgress,
        qoinBulkAt: DateTime(2026, 1, 2),
      );
      final rb = BrandModel.fromEntity(b.toEntity());
      expect(rb.qoinAccrualEnabled, QoinSwitchSetting.disabled);
      expect(rb.qoinBulkHistoryId, 'h1');
      expect(rb.qoinBulkStatus, QoinBulkStatus.inProgress);
      expect(rb.qoinBulkAt, DateTime(2026, 1, 2));
    });
  });

  group('이력 신규 필드 (spec §20 / design §18-7)', () {
    final ts = Timestamp.fromDate(DateTime(2026, 10, 22, 14, 35));

    test('accrualEnabled: before/after 는 bool|null (null = 부재 = 사용)', () {
      final e = QoinRateChangeModel.fromMap('h', {
        'scope': 'store',
        'targetId': 's',
        'field': 'accrualEnabled',
        'before': null,
        'after': false,
        'beforeState': 'absent',
        'changedBy': 'u',
        'changedAt': ts,
        'source': 'callable',
        'op': 'set',
      })!;
      expect(e.field, QoinRateField.accrualEnabled);
      expect(e.beforeEnabled, isNull);
      expect(e.afterEnabled, isFalse);
      expect(e.beforeState, QoinBeforeState.absent);
      expect(e.beforeRate, isNull);
    });

    // TRANSITIONAL(spec §20.4.5): 아래 migratedFromRate · legacyZero 케이스는 정리 커밋에서 삭제한다.
    test('migration: migratedFromRate 박제 + 무효 beforeState/beforeRaw', () {
      final e = QoinRateChangeModel.fromMap('h', {
        'scope': 'store',
        'targetId': 's',
        'field': 'accrualEnabled',
        'before': null,
        'after': false,
        'source': 'migration',
        'op': 'set',
        'migratedFromRate': 0,
        'beforeState': 'invalid',
        'beforeRaw': '"3"',
      })!;
      expect(e.source, QoinRateChangeSource.migration);
      expect(e.migratedFromRate, 0);
      expect(e.beforeState, QoinBeforeState.invalid);
      expect(e.beforeRaw, '"3"');
    });

    test('clearByBulk 매장 이력: bulkHistoryId 연결', () {
      final e = QoinRateChangeModel.fromMap('h', {
        'scope': 'store',
        'targetId': 's',
        'field': 'accrualRate',
        'before': 0.05,
        'after': null,
        'beforeState': 'value',
        'source': 'bulk',
        'op': 'clearByBulk',
        'bulkHistoryId': 'brandHist',
        'bulkMode': 'overwrite',
      })!;
      expect(e.op, QoinRateChangeOp.clearByBulk);
      expect(e.bulkHistoryId, 'brandHist');
      expect(e.beforeRate, 0.05);
      expect(e.isBulk, isFalse); // 매장 이력은 일괄 "묶음" 이 아니다
    });

    test('일괄 적용 집계 4종 (clearedZeroCount 는 없다)', () {
      final e = QoinRateChangeModel.fromMap('h', {
        'scope': 'brand',
        'targetId': 'b',
        'field': 'accrualRate',
        'before': 0.02,
        'after': 0.06,
        'source': 'bulk',
        'op': 'bulkApply',
        'bulkMode': 'overwrite',
        'status': 'completed',
        'clearedCount': 5,
        'clearedValueCount': 4,
        'clearedInvalidCount': 1,
        'disabledUntouchedCount': 3,
        'brandDisabled': true,
        'resumeCount': 1,
        'resumedAt': ts,
      })!;
      expect(e.clearedValueCount, 4);
      expect(e.clearedInvalidCount, 1);
      expect(e.disabledUntouchedCount, 3);
      expect(e.brandDisabled, isTrue);
      expect(e.resumeCount, 1);
      expect(e.resumedAt, DateTime(2026, 10, 22, 14, 35));
    });

    test('미지의 source/op 는 unknown 으로 관대하게 읽고 행은 살린다, scope/field 미지는 거른다', () {
      final e = QoinRateChangeModel.fromMap('h', {
        'scope': 'store',
        'targetId': 's',
        'field': 'accrualRate',
        'source': 'from_the_future',
        'op': 'teleport',
      })!;
      expect(e.source, QoinRateChangeSource.unknown);
      expect(e.op, QoinRateChangeOp.unknown);
      expect(
        QoinRateChangeModel.fromMap('h', {
          'scope': 'store',
          'targetId': 's',
          'field': 'mystery',
          'source': 'callable',
          'op': 'set',
        }),
        isNull,
      );
    });

    test('app_direct 는 행위자가 있는 앱 직접 쓰기', () {
      final e = QoinRateChangeModel.fromMap('h', {
        'scope': 'global',
        'targetId': 'qoin',
        'field': 'globalEnabled',
        'before': true,
        'after': false,
        'changedBy': 'adminUid',
        'source': 'app_direct',
        'op': 'set',
      })!;
      expect(e.source, QoinRateChangeSource.appDirect);
      expect(e.changedBy, 'adminUid');
    });
  });

  group('StoreModel / BrandModel — 스위치·포인터 읽기', () {
    DocumentSnapshot<Map<String, dynamic>> snap(Map<String, dynamic> data) =>
        _FakeDoc('id', data);

    final base = <String, dynamic>{
      'name': 'N',
      'location': const GeoPoint(0, 0),
      'createdAt': Timestamp.fromDate(DateTime(2026)),
    };

    test('스위치: 부재/true = 사용, false = 사용 안 함, 비bool = 무효', () {
      QoinSwitchSetting read(Map<String, dynamic> extra) =>
          StoreModel.fromFirestore(
            snap({...base, ...extra}),
          ).qoinAccrualEnabled;
      expect(read({}).isEnabled, isTrue);
      expect(read({'qoinAccrualEnabled': true}).isEnabled, isTrue);
      expect(read({'qoinAccrualEnabled': false}).isDisabled, isTrue);
      expect(read({'qoinAccrualEnabled': 'false'}).isInvalid, isTrue);
      expect(read({'qoinAccrualEnabled': 0}).isInvalid, isTrue);
      expect(read({'qoinAccrualEnabled': null}).isInvalid, isTrue);
    });

    test('브랜드 일괄 적용 포인터 3필드 읽기', () {
      final b = BrandModel.fromFirestore(
        snap({
          'name': 'B',
          'qoinBulkHistoryId': 'h9',
          'qoinBulkStatus': 'partial',
          'qoinBulkAt': Timestamp.fromDate(DateTime(2026, 3, 4)),
        }),
      );
      expect(b.qoinBulkHistoryId, 'h9');
      expect(b.qoinBulkStatus, QoinBulkStatus.partial);
      expect(b.qoinBulkAt, DateTime(2026, 3, 4));
      final none = BrandModel.fromFirestore(snap({'name': 'B'}));
      expect(none.qoinBulkStatus, isNull);
    });

    test('매장 적립률 0 은 legacyZero (읽기 전용 호환), 전역 0 은 무효', () {
      final s = StoreModel.fromFirestore(snap({...base, 'qoinAccrualRate': 0}));
      expect(s.qoinAccrualRate.isLegacyZero, isTrue);
    });
  });
}

// ignore: subtype_of_sealed_class
class _FakeDoc extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDoc(this._id, this._data);
  final String _id;
  final Map<String, dynamic> _data;

  @override
  String get id => _id;
  @override
  Map<String, dynamic>? data() => _data;
}
