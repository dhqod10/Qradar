import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';

/// 진리표는 TS 쪽(functions/test/qoinRate.test.mjs)과 **같은 파일**을 읽는다 (1차 F3 재발 방지):
/// test_fixtures/qoin_rate_truth_table.json — Dart / TS 가 같은 케이스로 같은 결과를 내야 한다.
/// 읽는 배열 6개: resolve(32) / resolve_legacy(3) / classify(13) / classifySwitch(7) / callable(12) / callableSwitch(4).
///
/// `transitionalExpect` 가 있는 행은 과도기 호환 분기(legacyZero)가 살아 있는 동안 `expect` 대신 그 값을 기대한다.
/// TRANSITIONAL(spec §20.4.5): 정리 커밋에서 `resolve_legacy` 와 `transitionalExpect` 를 삭제하면 이 테스트의
/// `_expectOf` 도 `row['expect']` 만 읽게 된다.
void main() {
  final table =
      jsonDecode(
            File('test_fixtures/qoin_rate_truth_table.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  /// 픽스처 셀 → (present, raw). 'absent' = 필드 부재.
  ({bool present, Object? raw}) decode(Object? cell) {
    if (cell == 'absent') return (present: false, raw: null);
    if (cell == 'nan') return (present: true, raw: double.nan);
    if (cell == 'null') return (present: true, raw: null);
    if (cell is String && cell.startsWith('str:')) {
      return (present: true, raw: cell.substring(4));
    }
    return (present: true, raw: cell);
  }

  QoinRateSetting rate(Object? cell) {
    final d = decode(cell);
    return QoinRateSetting.fromRaw(d.raw, present: d.present);
  }

  QoinSwitchSetting sw(Object? cell) {
    final d = decode(cell ?? 'absent');
    return QoinSwitchSetting.fromRaw(d.raw, present: d.present);
  }

  List<Map<String, dynamic>> rows(String key) =>
      (table[key] as List).cast<Map<String, dynamic>>();

  EffectiveQoinRate resolveRow(Map<String, dynamic> row) =>
      resolveEffectiveQoinRate(
        store: rate(row['store']),
        storeSwitch: sw(row['storeEnabled']),
        brand: rate(row['brand']),
        brandSwitch: sw(row['brandEnabled']),
        global: rate(row['global']),
      );

  /// 과도기에는 transitionalExpect 가 있으면 그것을 기대한다.
  Map<String, dynamic> expectOf(Map<String, dynamic> row) =>
      (row['transitionalExpect'] ?? row['expect']) as Map<String, dynamic>;

  void check(EffectiveQoinRate r, Map<String, dynamic> e) {
    if (e.containsKey('invalid')) {
      expect(r.isInvalid, isTrue, reason: 'expected invalid ${e['invalid']}');
      expect(r.isDisabled, isFalse);
      expect(r.rate, isNull);
      expect(r.source, isNull);
      expect(r.invalidScope!.code, e['invalid']);
    } else if (e.containsKey('disabled')) {
      expect(
        r.isDisabled,
        isTrue,
        reason: 'expected disabled ${e['disabled']}',
      );
      expect(r.isInvalid, isFalse);
      expect(r.rate, isNull);
      expect(r.source, isNull);
      expect(r.disabledSource!.code, e['disabled']);
      expect(r.legacy, e['legacy'] == true);
    } else {
      expect(r.isInvalid, isFalse);
      expect(r.isDisabled, isFalse);
      expect(r.rate, (e['rate'] as num).toDouble());
      expect(r.source!.code, e['source']);
    }
  }

  test(
    '픽스처 행 수 (resolve 32 / legacy 3 / classify 13 / switch 7 / callable 12 / callableSwitch 4)',
    () {
      expect(rows('resolve'), hasLength(32));
      expect(rows('resolve_legacy'), hasLength(3));
      expect(rows('classify'), hasLength(13));
      expect(rows('classifySwitch'), hasLength(7));
      expect(rows('callable'), hasLength(12));
      expect(rows('callableSwitch'), hasLength(4));
    },
  );

  group('resolveEffectiveQoinRate — spec §20.2.3 진리표 (TS 와 같은 JSON)', () {
    for (final row in rows('resolve')) {
      test('${row['id']} ${row['note'] ?? ''}', () {
        check(resolveRow(row), expectOf(row));
      });
    }
  });

  // TRANSITIONAL(spec §20.4.5): 정리 커밋에서 이 그룹과 픽스처의 resolve_legacy 배열을 삭제한다.
  group('resolve_legacy — 과도기 호환 (레거시 0 = 사용 안 함, legacy 표시)', () {
    for (final row in rows('resolve_legacy')) {
      test('${row['id']} ${row['note'] ?? ''}', () {
        check(resolveRow(row), row['expect'] as Map<String, dynamic>);
      });
    }
  });

  group(
    'QoinRateSetting.fromRaw — 3값 분류 + 과도기 legacyZero (TS classifyRate 와 같은 JSON)',
    () {
      for (final row in rows('classify')) {
        test(
          '${row['raw']} -> ${row['transitionalExpect'] ?? row['expect']}',
          () {
            final s = rate(row['raw']);
            expect(s.kind.name, row['transitionalExpect'] ?? row['expect']);
          },
        );
      }
    },
  );

  group('QoinPolicy.classifySwitch (TS classifySwitch 와 같은 JSON)', () {
    for (final row in rows('classifySwitch')) {
      test('${row['id']} ${row['raw']} -> ${row['expect']}', () {
        final d = decode(row['raw']);
        final k = QoinPolicy.classifySwitch(d.raw, present: d.present);
        expect(k.name, row['expect']);
        expect(QoinSwitchSetting.fromRaw(d.raw, present: d.present).kind, k);
      });
    }
  });

  group('QoinPolicy.isValidCallableRate — 서버 isValidCallableRate 와 같은 JSON', () {
    for (final row in rows('callable')) {
      test('${row['raw']} -> ${row['expect']}', () {
        final d = decode(row['raw']);
        // callable 은 number 만 받는다. 문자열/null 은 UseCase 의 타입(int tenths)이 이미 막으므로 false.
        final raw = d.raw;
        final ok = raw is num
            ? QoinPolicy.isValidCallableRate(raw.toDouble())
            : false;
        expect(ok, row['expect']);
      });
    }
  });

  group('QoinPolicy.isValidCallableSwitch — 서버 callableSwitch 와 같은 JSON', () {
    for (final row in rows('callableSwitch')) {
      test('${row['id']} ${row['enabled']} -> ${row['expect']}', () {
        final d = decode(row['enabled']);
        expect(
          QoinPolicy.isValidCallableSwitch(d.raw) ? 'accept' : 'reject',
          row['expect'],
        );
      });
    }
  });

  group('N4 — 사슬 순서 (스위치 단계가 숫자 단계를 통째로 앞선다)', () {
    EffectiveQoinRate r({
      QoinRateSetting store = QoinRateSetting.absent,
      QoinSwitchSetting storeSwitch = QoinSwitchSetting.enabled,
      QoinRateSetting brand = QoinRateSetting.absent,
      QoinSwitchSetting brandSwitch = QoinSwitchSetting.enabled,
      QoinRateSetting? global,
    }) => resolveEffectiveQoinRate(
      store: store,
      storeSwitch: storeSwitch,
      brand: brand,
      brandSwitch: brandSwitch,
      global: global ?? QoinRateSetting.valid(0.03),
    );

    test('브랜드 off + 매장 개별 10% -> 브랜드에서 중단 (R06)', () {
      final e = r(
        store: QoinRateSetting.valid(0.1),
        brand: QoinRateSetting.valid(0.05),
        brandSwitch: QoinSwitchSetting.disabled,
      );
      expect(e.isDisabled, isTrue);
      expect(e.disabledSource, QoinRateSource.brand);
      expect(e.rate, isNull);
    });
    test('매장 스위치 무효 + 브랜드 off -> disabled 가 먼저 (R21b, 누락 사건 아님)', () {
      final e = r(
        storeSwitch: QoinSwitchSetting.invalid,
        brandSwitch: QoinSwitchSetting.disabled,
      );
      expect(e.isDisabled, isTrue);
      expect(e.isInvalid, isFalse);
    });
    test('브랜드 스위치 무효 + 개별 10% -> 무효 (R22b)', () {
      final e = r(
        store: QoinRateSetting.valid(0.1),
        brandSwitch: QoinSwitchSetting.invalid,
      );
      expect(e.invalidScope, QoinRateInvalidScope.brandEnabled);
    });
    test('asIfEnabled 는 스위치를 켠 숫자 축만 본다', () {
      final e = r(
        store: QoinRateSetting.valid(0.1),
        storeSwitch: QoinSwitchSetting.disabled,
        brand: QoinRateSetting.valid(0.05),
        brandSwitch: QoinSwitchSetting.disabled,
      ).asIfEnabled();
      expect(e.isDisabled, isFalse);
      expect(e.rate, 0.1);
      expect(e.source, QoinRateSource.store);
    });
  });

  group('값 보존 — null / 0.0 으로 뭉개지 않는다', () {
    test('결과가 각 단계 원본을 그대로 들고 있다', () {
      final r = resolveEffectiveQoinRate(
        store: QoinRateSetting.absent,
        brand: QoinRateSetting.valid(0.05),
        brandSwitch: QoinSwitchSetting.disabled,
        global: QoinRateSetting.valid(0.03),
      );
      expect(r.store.kind, QoinRateCellKind.absent);
      expect(r.brand.kind, QoinRateCellKind.valid);
      expect(r.brandSwitch.kind, QoinSwitchKind.disabled);
      expect(r.global.kind, QoinRateCellKind.valid);
      expect(r.isDisabled, isTrue);
      expect(r.disabledSource, QoinRateSource.brand);
    });
    test('absent 와 invalid 는 같지 않다', () {
      expect(QoinRateSetting.absent == QoinRateSetting.invalid, isFalse);
      expect(QoinRateSetting.absent.value, isNull);
    });
    test('무효 값은 상위로 폴백하지 않는다 (store 0.5 + brand 0.05)', () {
      final r = resolveEffectiveQoinRate(
        store: rate(0.5),
        brand: rate(0.05),
        global: rate(0.03),
      );
      expect(r.isInvalid, isTrue);
    });
    test('valid() 는 범위 밖(0 포함)을 거부한다', () {
      expect(() => QoinRateSetting.valid(0.5), throwsArgumentError);
      expect(() => QoinRateSetting.valid(0), throwsArgumentError);
    });
    test('입력 0 은 zero 상태, 0.03 은 여전히 tooLow (design §18-2.4)', () {
      for (final z in ['0', '0.0', '00', '0.00']) {
        expect(
          QoinPolicy.validateRateInput(z).status,
          RateInputStatus.zero,
          reason: z,
        );
      }
      expect(
        QoinPolicy.validateRateInput('0.03').status,
        RateInputStatus.tooLow,
      );
      expect(QoinPolicy.validateRateInput('0.1').status, RateInputStatus.valid);
    });
  });

  group('경계 상수는 QoinPolicy 1곳 (F3)', () {
    test('Dart 경계 = 화면 0.1~20% = TS MIN/MAX_RATE(0.001/0.2)', () {
      expect(QoinPolicy.minTenths, 1);
      expect(QoinPolicy.maxTenths, 200);
      expect(QoinPolicy.isValidRate(0.001), isTrue);
      expect(QoinPolicy.isValidRate(0.0009), isFalse);
      expect(QoinPolicy.isValidRate(0.2), isTrue);
      expect(QoinPolicy.isValidRate(0.2001), isFalse);
      expect(QoinPolicy.isValidRate(0), isFalse);
      expect(QoinPolicy.isValidRate(double.nan), isFalse);
    });
    test('tenths 1..200 전부 비율 왕복이 일치하고 유효 범위 안이다', () {
      for (var t = QoinPolicy.minTenths; t <= QoinPolicy.maxTenths; t++) {
        final r = QoinPolicy.rateFromTenths(t);
        expect(QoinPolicy.tenthsFromRate(r), t);
        expect(QoinPolicy.isValidRate(r), isTrue, reason: 't=$t');
        expect(QoinPolicy.isValidCallableRate(r), isTrue, reason: 't=$t');
      }
    });
    test('일괄 적용 stale 기준 5분 (서버 BULK_STALE_MS 와 같은 값)', () {
      expect(QoinPolicy.bulkStaleAfter, const Duration(minutes: 5));
    });
  });
}
