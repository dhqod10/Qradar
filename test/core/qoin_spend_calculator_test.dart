import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/utils/qoin_spend_calculator.dart';
import 'package:qradar/data/models/qoin_config_model.dart';

/// qoin_spend 교차 골든 — 서버 `functions/test/qoinSpend.test.mjs` 가 **같은 fixture** 를 읽는다.
/// 한쪽만 규칙(정책 해석·사용가능액·판정 경계)을 바꾸면 양쪽 중 하나가 깨져 대조가 강제된다.
Map<String, dynamic> _load() =>
    jsonDecode(File('test_fixtures/qoin_spend_contract.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final g = _load();
  final policyCases = (g['policyCases'] as List).cast<Map<String, dynamic>>();
  final maxCases = (g['maxCases'] as List).cast<Map<String, dynamic>>();
  final validateCases = (g['validateCases'] as List).cast<Map<String, dynamic>>();

  test('골든 fixture 가 충분하다', () {
    expect(policyCases.length, greaterThanOrEqualTo(12));
    expect(maxCases.length, greaterThanOrEqualTo(10));
    expect(validateCases.length, greaterThanOrEqualTo(12));
  });

  group('정책 해석 (fail-closed)', () {
    for (final c in policyCases) {
      test(c['name'] as String, () {
        final config = Map<String, dynamic>.from(c['config'] as Map);
        final expected = c['expect'] as Map<String, dynamic>;
        final p = QoinSpendPolicy.fromConfig(config);
        expect(p.enabled, expected['spendEnabled']);
        if (expected['spendEnabled'] == true) {
          expect(p.minUnit, expected['minUnit']);
          expect(p.minCashFloor, expected['minCashFloor']);
        }
        // 모델 경로(QoinConfigModel.fromMap)도 같은 결과여야 한다 — 화면은 이 경로로 읽는다.
        expect(QoinConfigModel.fromMap(config).spendPolicy, p);
      });
    }

    test('문서 부재(null) → 차단', () {
      expect(QoinSpendPolicy.fromConfig(null).enabled, isFalse);
      expect(QoinSpendPolicy.fromConfig(null), QoinSpendPolicy.disabled);
    });
  });

  group('사용가능액 (표시용)', () {
    for (final c in maxCases) {
      test(c['name'] as String, () {
        final policy = QoinSpendPolicy(
          enabled: true,
          minUnit: c['minUnit'] as int,
          minCashFloor: c['minCashFloor'] as int,
        );
        expect(
          QoinSpendCalculator.maxSpendable(
            balance: c['balance'] as int,
            subtotal: c['subtotal'] as int,
            policy: policy,
          ),
          c['expect'],
        );
      });
    }

    test('정책이 꺼져 있으면 항상 0', () {
      expect(
        QoinSpendCalculator.maxSpendable(
          balance: 99999,
          subtotal: 5000,
          policy: QoinSpendPolicy.disabled,
        ),
        0,
      );
    });
  });

  group('서버 판정과 같은 ok 여부 (isAllowed)', () {
    for (final c in validateCases) {
      test(c['name'] as String, () {
        final pol = c['policy'] as Map<String, dynamic>;
        final policy = QoinSpendPolicy(
          enabled: pol['spendEnabled'] as bool,
          minUnit: pol['minUnit'] as int,
          minCashFloor: pol['minCashFloor'] as int,
        );
        final requested = (c['requested'] as num);
        // 소수 요청은 Dart int 로 표현할 수 없다 — 입력 필터(digitsOnly)가 구조적으로 막는다. 서버 쪽 골든이 고정한다.
        if (requested != requested.truncate()) return;
        final expected = (c['expect'] as Map<String, dynamic>)['ok'] as bool;
        expect(
          QoinSpendCalculator.isAllowed(
            requested: requested.toInt(),
            balance: c['balance'] as int,
            subtotal: c['subtotal'] as int,
            policy: policy,
          ),
          expected,
        );
      });
    }
  });

  group('클램프 · 최종 금액', () {
    const policy = QoinSpendPolicy(enabled: true, minUnit: 1, minCashFloor: 300);
    test('한도 초과는 한도로, 음수는 0, 범위 내는 그대로', () {
      int clamp(int r) => QoinSpendCalculator.clamp(
        requested: r,
        balance: 12300,
        subtotal: 5000,
        policy: policy,
      );
      expect(clamp(99999), 4700);
      expect(clamp(5000), 4700);
      expect(clamp(700), 700);
      expect(clamp(0), 0);
      expect(clamp(-5), 0);
    });

    test('단위 100: 클램프는 단위 배수로 내림', () {
      const p100 = QoinSpendPolicy(enabled: true, minUnit: 100, minCashFloor: 300);
      expect(
        QoinSpendCalculator.clamp(requested: 250, balance: 9999, subtotal: 5000, policy: p100),
        200,
      );
      expect(
        QoinSpendCalculator.clamp(requested: 9999, balance: 9999, subtotal: 5000, policy: p100),
        4700,
      );
    });

    test('한도를 정한 쪽', () {
      expect(
        QoinSpendCalculator.limitedBy(balance: 1200, subtotal: 5000, policy: policy),
        QoinSpendLimitedBy.balance,
      );
      expect(
        QoinSpendCalculator.limitedBy(balance: 12300, subtotal: 5000, policy: policy),
        QoinSpendLimitedBy.cashFloor,
      );
      expect(
        QoinSpendCalculator.limitedBy(balance: 0, subtotal: 5000, policy: policy),
        QoinSpendLimitedBy.none,
      );
    });

    test('최종 금액 = 소계 − 사용액', () {
      expect(QoinSpendCalculator.finalAmount(subtotal: 8000, qoinToUse: 700), 7300);
      expect(QoinSpendCalculator.finalAmount(subtotal: 8000, qoinToUse: 0), 8000);
    });
  });
}
