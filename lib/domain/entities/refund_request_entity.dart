import 'package:freezed_annotation/freezed_annotation.dart';

part 'refund_request_entity.freezed.dart';

/// customer 환불 요청 정보.
@freezed
abstract class RefundRequestEntity with _$RefundRequestEntity {
  const factory RefundRequestEntity({
    required String reason,
    required DateTime requestedAt,
    DateTime? deniedAt,
    String? deniedReason,
  }) = _RefundRequestEntity;
}
