import 'package:freezed_annotation/freezed_annotation.dart';

part 'refund_info_entity.freezed.dart';

/// 환불 완료 정보.
@freezed
abstract class RefundInfoEntity with _$RefundInfoEntity {
  const factory RefundInfoEntity({
    required String cancellationKey,
    required String reason,
    /// 'customer' | 'owner' | 'store_reject'
    required String approvedBy,
    required DateTime processedAt,
    required int amount,
  }) = _RefundInfoEntity;
}
