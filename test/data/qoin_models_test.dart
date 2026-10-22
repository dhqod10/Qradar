import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/data/models/qoin_config_model.dart';
import 'package:qradar/data/models/qoin_transaction_model.dart';
import 'package:qradar/data/models/user_model.dart';
import 'package:qradar/domain/entities/qoin_transaction_type.dart';

void main() {
  group('QU1 UserModelFactory.parseQoinBalance', () {
    test('absent / null -> 0', () {
      expect(UserModelFactory.parseQoinBalance(null), 0);
    });
    test('int passes through', () {
      expect(UserModelFactory.parseQoinBalance(135), 135);
    });
    test('double 135.0 -> 135', () {
      expect(UserModelFactory.parseQoinBalance(135.0), 135);
    });
    test('string -> 0', () {
      expect(UserModelFactory.parseQoinBalance('135'), 0);
    });
    test('negative is preserved (no clamp, spec §8.3)', () {
      expect(UserModelFactory.parseQoinBalance(-100), -100);
    });
    test('NaN / infinity -> 0', () {
      expect(UserModelFactory.parseQoinBalance(double.nan), 0);
      expect(UserModelFactory.parseQoinBalance(double.infinity), 0);
    });
  });

  group('QU2 QoinTransactionModel.fromMap', () {
    test('full document', () {
      final ts = Timestamp.fromDate(DateTime(2026, 10, 22, 14, 35));
      final e = QoinTransactionModel.fromMap('earn_o1', {
        'type': 'earn',
        'amount': 540,
        'balanceAfter': 1200,
        'orderId': 'o1',
        'storeId': 's1',
        'storeName': '스타벅스',
        'orderTotalPrice': 18000,
        'accrualRate': 0.03,
        'createdAt': ts,
      });
      expect(e.txId, 'earn_o1');
      expect(e.type, QoinTransactionType.earn);
      expect(e.amount, 540);
      expect(e.balanceAfter, 1200);
      expect(e.orderTotalPrice, 18000);
      expect(e.accrualRate, 0.03);
      expect(e.createdAt, DateTime(2026, 10, 22, 14, 35));
    });
    test('missing fields -> safe defaults, no throw', () {
      final e = QoinTransactionModel.fromMap('x', const {});
      expect(e.type, isNull);
      expect(e.amount, 0);
      expect(e.balanceAfter, 0);
      expect(e.orderId, '');
      expect(e.storeName, '');
      expect(e.orderTotalPrice, isNull);
      expect(e.accrualRate, isNull);
      expect(e.createdAt, isNull);
    });
    test('unknown type string -> null type, amount sign preserved', () {
      final e = QoinTransactionModel.fromMap('x', {
        'type': 'expire',
        'amount': -50,
      });
      expect(e.type, isNull);
      expect(e.amount, -50);
    });
    test('createdAt non-Timestamp -> null; amount double -> int', () {
      final e = QoinTransactionModel.fromMap('x', {
        'createdAt': 'now',
        'amount': 135.0,
      });
      expect(e.createdAt, isNull);
      expect(e.amount, 135);
    });
  });

  group('QU3 QoinTransactionType.fromCode', () {
    test('known codes', () {
      expect(QoinTransactionType.fromCode('earn'), QoinTransactionType.earn);
      expect(
        QoinTransactionType.fromCode('clawback'),
        QoinTransactionType.clawback,
      );
    });
    test('unknown / null are NOT folded into earn', () {
      expect(QoinTransactionType.fromCode('expire'), isNull);
      expect(QoinTransactionType.fromCode(null), isNull);
    });
  });

  group('QU4 QoinConfigModel.fromMap', () {
    test('enabled absent -> false (fail-closed)', () {
      expect(QoinConfigModel.fromMap({'accrualRate': 0.03}).enabled, isFalse);
    });
    test('enabled non-bool -> false', () {
      expect(QoinConfigModel.fromMap({'enabled': 'true'}).enabled, isFalse);
    });
    test('accrualRate non-number / out of range -> null', () {
      expect(
        QoinConfigModel.fromMap({'accrualRate': '0.03'}).accrualRate,
        isNull,
      );
      expect(QoinConfigModel.fromMap({'accrualRate': 5}).accrualRate, isNull);
      expect(
        QoinConfigModel.fromMap({'accrualRate': -0.1}).accrualRate,
        isNull,
      );
      expect(
        QoinConfigModel.fromMap({'accrualRate': double.nan}).accrualRate,
        isNull,
      );
    });
    test('valid', () {
      final c = QoinConfigModel.fromMap({'accrualRate': 0.03, 'enabled': true});
      expect(c.accrualRate, 0.03);
      expect(c.enabled, isTrue);
    });
  });
}
