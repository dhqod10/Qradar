import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/domain/entities/refund_request_entity.dart';

/// Firestore `orders/{orderId}.refundRequest` 필드 매퍼.
class RefundRequestModel {
  final String reason;
  final DateTime requestedAt;
  final DateTime? deniedAt;
  final String? deniedReason;

  const RefundRequestModel({
    required this.reason,
    required this.requestedAt,
    this.deniedAt,
    this.deniedReason,
  });

  factory RefundRequestModel.fromMap(Map<String, dynamic> map) {
    final ts = map['requestedAt'];
    final deniedTs = map['deniedAt'];
    return RefundRequestModel(
      reason: (map['reason'] as String?) ?? '',
      requestedAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      deniedAt: deniedTs is Timestamp ? deniedTs.toDate() : null,
      deniedReason: map['deniedReason'] as String?,
    );
  }

  factory RefundRequestModel.fromEntity(RefundRequestEntity entity) {
    return RefundRequestModel(
      reason: entity.reason,
      requestedAt: entity.requestedAt,
      deniedAt: entity.deniedAt,
      deniedReason: entity.deniedReason,
    );
  }

  RefundRequestEntity toEntity() {
    return RefundRequestEntity(
      reason: reason,
      requestedAt: requestedAt,
      deniedAt: deniedAt,
      deniedReason: deniedReason,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'reason': reason,
        'requestedAt': Timestamp.fromDate(requestedAt),
        if (deniedAt != null) 'deniedAt': Timestamp.fromDate(deniedAt!),
        if (deniedReason != null) 'deniedReason': deniedReason,
      };
}
