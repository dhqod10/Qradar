import 'package:freezed_annotation/freezed_annotation.dart';

part 'cancel_info_entity.freezed.dart';

/// 주문 취소 정보 (paid → cancelled 상태 전이 시 기록).
///
/// [approvedBy] 는 `"customer"` (고객 직접 취소) 또는 `"owner"` (점주 거절).
@freezed
abstract class CancelInfoEntity with _$CancelInfoEntity {
  const factory CancelInfoEntity({
    required String reason,
    required String approvedBy,
    required DateTime cancelledAt,
    String? cancellationKey,
  }) = _CancelInfoEntity;
}
