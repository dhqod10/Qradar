import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/utils/qoin_formatters.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/domain/entities/qoin_transaction_entity.dart';
import 'package:qradar/domain/entities/qoin_transaction_type.dart';
import 'package:qradar/presentation/customer/qoin/widgets/qoin_transaction_tile.dart';

void main() {
  group('QU5 QoinFormatters', () {
    test('balance', () {
      expect(QoinFormatters.balance(1200), '1,200 Q');
      expect(QoinFormatters.balance(0), '0 Q');
      expect(QoinFormatters.balance(-100), '-100 Q');
    });
    test('signed', () {
      expect(QoinFormatters.signed(540), '+540 Q');
      expect(QoinFormatters.signed(-540), '-540 Q');
      expect(QoinFormatters.signed(0), '0 Q');
      expect(QoinFormatters.signed(1234567), '+1,234,567 Q');
    });
    test('spoken uses 마이너스, never a hyphen', () {
      expect(QoinFormatters.balanceSpoken(-100), '마이너스 100 Q');
      expect(QoinFormatters.balanceSpoken(1200), '1,200 Q');
    });
  });

  group('QoinPolicy.validateRateInput (100x guard)', () {
    RateInputStatus st(String s) => QoinPolicy.validateRateInput(s).status;
    test('0.03 (ratio typed as percent) is blocked as tooLow', () {
      expect(st('0.03'), RateInputStatus.tooLow);
      expect(st('0.05'), RateInputStatus.tooLow);
      expect(st('0'), RateInputStatus.tooLow);
      expect(st('.03'), RateInputStatus.tooLow);
    });
    test('boundaries', () {
      expect(st('0.1'), RateInputStatus.valid);
      expect(st('20'), RateInputStatus.valid);
      expect(st('20.0'), RateInputStatus.valid);
      expect(st('20.1'), RateInputStatus.tooHigh);
      expect(st('30'), RateInputStatus.tooHigh);
      expect(st('300'), RateInputStatus.tooHigh);
    });
    test('tenths are exact', () {
      expect(QoinPolicy.validateRateInput('3').tenths, 30);
      expect(QoinPolicy.validateRateInput('2.5').tenths, 25);
      expect(QoinPolicy.validateRateInput('3.50').tenths, 35);
      expect(QoinPolicy.validateRateInput('7').tenths, 70);
      expect(QoinPolicy.validateRateInput('0.1').tenths, 1);
    });
    test('precision / malformed / empty', () {
      expect(st('3.55'), RateInputStatus.tooPrecise);
      expect(st(''), RateInputStatus.empty);
      expect(st('.'), RateInputStatus.malformed);
      expect(st('3a'), RateInputStatus.malformed);
      expect(st('-3'), RateInputStatus.malformed);
    });
  });

  group('QoinPolicy conversions', () {
    test('rateFromTenths has no float drift for 0.1% steps', () {
      expect(QoinPolicy.rateFromTenths(30), 0.03);
      expect(QoinPolicy.rateFromTenths(25), 0.025);
      expect(QoinPolicy.rateFromTenths(70), 0.07);
    });
    test('formatRatePercent', () {
      expect(QoinPolicy.formatRatePercent(0.03), '3%');
      expect(QoinPolicy.formatRatePercent(0.025), '2.5%');
      expect(QoinPolicy.formatRatePercent(0.07), '7%');
      expect(QoinPolicy.formatRatePercent(0.001), '0.1%');
    });
    test('previewAmount floors with integer math', () {
      expect(QoinPolicy.previewAmount(30), 300);
      expect(QoinPolicy.previewAmount(70), 700);
      expect(QoinPolicy.previewAmount(25), 250);
      expect(QoinPolicy.previewAmount(1), 10);
      expect(QoinPolicy.previewAmount(30, paymentKrw: 4150), 124);
    });
    test('shouldWarnIncrease', () {
      expect(
        QoinPolicy.shouldWarnIncrease(currentTenths: 30, newTenths: 60),
        isTrue,
      );
      expect(
        QoinPolicy.shouldWarnIncrease(currentTenths: 30, newTenths: 50),
        isFalse,
      );
      expect(
        QoinPolicy.shouldWarnIncrease(currentTenths: 80, newTenths: 100),
        isTrue,
      );
      expect(
        QoinPolicy.shouldWarnIncrease(currentTenths: 150, newTenths: 100),
        isFalse,
      );
      expect(
        QoinPolicy.shouldWarnIncrease(currentTenths: null, newTenths: 100),
        isTrue,
      );
      expect(
        QoinPolicy.shouldWarnIncrease(currentTenths: null, newTenths: 30),
        isFalse,
      );
    });
  });

  group('qoinReasonText (uses ledger snapshot, not current policy)', () {
    QoinTransactionEntity tx({
      QoinTransactionType? type,
      int amount = 540,
      int? total,
      double? rate,
    }) => QoinTransactionEntity(
      txId: 't',
      type: type,
      amount: amount,
      balanceAfter: 0,
      orderTotalPrice: total,
      accrualRate: rate,
    );

    test('earn shows order total and rate at accrual time', () {
      expect(
        qoinReasonText(
          tx(type: QoinTransactionType.earn, total: 18000, rate: 0.03),
        ),
        '픽업 완료 적립 · 결제액 18,000원의 3%',
      );
    });
    test('earn missing basis -> plain', () {
      expect(qoinReasonText(tx(type: QoinTransactionType.earn)), '픽업 완료 적립');
    });
    test('clawback / unknown', () {
      expect(
        qoinReasonText(tx(type: QoinTransactionType.clawback, amount: -540)),
        '환불로 회수',
      );
      expect(qoinReasonText(tx(type: null)), 'Qoin 조정');
    });
    test('spoken text has no hyphen for negatives', () {
      final s = qoinSpokenText(
        tx(type: QoinTransactionType.clawback, amount: -540),
      );
      expect(s.contains('-'), isFalse);
      expect(s.contains('540 Q 회수'), isTrue);
    });
  });
}
