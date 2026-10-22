import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';

/// 진리표는 TS 쪽(functions/test/qoinRate.test.mjs)과 **같은 파일**을 읽는다 (1차 F3 재발 방지):
/// test_fixtures/qoin_rate_truth_table.json — Dart / TS 가 같은 케이스로 같은 결과를 내야 한다.
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

  QoinRateSetting setting(Object? cell, {bool allowZero = true}) {
    final d = decode(cell);
    return QoinRateSetting.fromRaw(
      d.raw,
      present: d.present,
      allowZero: allowZero,
    );
  }

  group('resolveEffectiveQoinRate — spec §6 진리표 (TS 와 같은 JSON)', () {
    for (final row in (table['resolve'] as List).cast<Map<String, dynamic>>()) {
      test(
        '${row['id']} store=${row['store']} brand=${row['brand']} global=${row['global']}',
        () {
          final r = resolveEffectiveQoinRate(
            store: setting(row['store']),
            brand: setting(row['brand']),
            global: setting(row['global'], allowZero: false),
          );
          final expectV = row['expect'] as Map<String, dynamic>;
          if (expectV.containsKey('invalid')) {
            expect(r.isInvalid, isTrue);
            expect(r.rate, isNull);
            expect(r.source, isNull);
            expect(r.invalidScope!.name, expectV['invalid']);
          } else {
            expect(r.isInvalid, isFalse);
            expect(r.rate, (expectV['rate'] as num).toDouble());
            expect(r.source!.code, expectV['source']);
          }
        },
      );
    }
  });

  group('QoinRateSetting.fromRaw — 4값 분류 (TS classifyRate 와 같은 JSON)', () {
    for (final row
        in (table['classify'] as List).cast<Map<String, dynamic>>()) {
      test(
        '${row['raw']} allowZero=${row['allowZero']} -> ${row['expect']}',
        () {
          final s = setting(row['raw'], allowZero: row['allowZero'] as bool);
          expect(s.kind.name, row['expect']);
        },
      );
    }
  });

  group('QoinPolicy.isValidCallableRate — 서버 isValidCallableRate 와 같은 JSON', () {
    for (final row
        in (table['callable'] as List).cast<Map<String, dynamic>>()) {
      test('${row['raw']} allowZero=${row['allowZero']} -> ${row['expect']}', () {
        final d = decode(row['raw']);
        // callable 은 number 만 받는다. 문자열/null 은 UseCase 의 타입(int tenths)이 이미 막으므로 false.
        final raw = d.raw;
        final ok = raw is num
            ? QoinPolicy.isValidCallableRate(
                raw.toDouble(),
                allowZero: row['allowZero'] as bool,
              )
            : false;
        expect(ok, row['expect']);
      });
    }
  });

  group('4값 보존 — null / 0.0 으로 뭉개지 않는다', () {
    test('결과가 각 단계 원본을 그대로 들고 있다', () {
      final r = resolveEffectiveQoinRate(
        store: QoinRateSetting.absent,
        brand: QoinRateSetting.zero,
        global: QoinRateSetting.valid(0.03),
      );
      expect(r.store.kind, QoinRateCellKind.absent);
      expect(r.brand.kind, QoinRateCellKind.zero);
      expect(r.global.kind, QoinRateCellKind.valid);
      expect(r.isStopped, isTrue);
      expect(r.source, QoinRateSource.brand);
    });
    test('absent 와 zero 는 같지 않다', () {
      expect(QoinRateSetting.absent == QoinRateSetting.zero, isFalse);
      expect(QoinRateSetting.zero.value, 0);
      expect(QoinRateSetting.absent.value, isNull);
    });
    test('무효 값은 상위로 폴백하지 않는다 (store 0.5 + brand 0.05)', () {
      final r = resolveEffectiveQoinRate(
        store: setting(0.5),
        brand: setting(0.05),
        global: setting(0.03, allowZero: false),
      );
      expect(r.isInvalid, isTrue);
    });
    test('valid() 는 범위 밖을 거부한다', () {
      expect(() => QoinRateSetting.valid(0.5), throwsArgumentError);
      expect(() => QoinRateSetting.valid(0), throwsArgumentError);
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
        final rate = QoinPolicy.rateFromTenths(t);
        expect(QoinPolicy.tenthsFromRate(rate), t);
        expect(QoinPolicy.isValidRate(rate), isTrue, reason: 't=$t');
        expect(
          QoinPolicy.isValidCallableRate(rate, allowZero: false),
          isTrue,
          reason: 't=$t',
        );
      }
    });
    test('명시적 0 은 입력란으로 만들 수 없다 (tooLow)', () {
      expect(QoinPolicy.explicitOffRate, 0);
      expect(QoinPolicy.validateRateInput('0').status, RateInputStatus.tooLow);
    });
    test('일괄 적용 stale 기준 5분 (서버 BULK_STALE_MS 와 같은 값)', () {
      expect(QoinPolicy.bulkStaleAfter, const Duration(minutes: 5));
    });
  });
}
