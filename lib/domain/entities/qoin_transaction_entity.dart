import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/qoin_transaction_type.dart';

part 'qoin_transaction_entity.freezed.dart';

/// Qoin 원장 1건 (`users/{uid}/qoinTransactions/{txId}`). append-only, CF 전용 쓰기.
@freezed
abstract class QoinTransactionEntity with _$QoinTransactionEntity {
  const factory QoinTransactionEntity({
    required String txId,

    /// 미지 타입이면 null. 적립/회수 판정은 [amount] 부호로 한다.
    QoinTransactionType? type,

    /// 부호 포함. 적립 양수, 회수 음수.
    required int amount,

    /// 이 거래 직후 잔액 (감사 추적).
    required int balanceAfter,
    @Default('') String orderId,
    @Default('') String storeId,
    @Default('') String storeName,

    /// 적립 산정 기준 결제액 (거래 당시). 누락 시 null.
    int? orderTotalPrice,

    /// 적립 당시 적용 비율 (거래 당시). 누락 시 null.
    double? accrualRate,

    /// 서버 타임스탬프 미확정(pending)이면 null.
    DateTime? createdAt,
  }) = _QoinTransactionEntity;
}
