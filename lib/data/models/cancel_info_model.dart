import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/domain/entities/cancel_info_entity.dart';

/// Firestore `orders/{orderId}.cancelInfo` 필드 매퍼.
class CancelInfoModel {
  final String reason;
  final String approvedBy;
  final DateTime cancelledAt;
  final String? cancellationKey;

  const CancelInfoModel({
    required this.reason,
    required this.approvedBy,
    required this.cancelledAt,
    this.cancellationKey,
  });

  factory CancelInfoModel.fromMap(Map<String, dynamic> map) {
    final ts = map['cancelledAt'];
    return CancelInfoModel(
      reason: (map['reason'] as String?) ?? '',
      approvedBy: (map['approvedBy'] as String?) ?? '',
      cancelledAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      cancellationKey: map['cancellationKey'] as String?,
    );
  }

  factory CancelInfoModel.fromEntity(CancelInfoEntity entity) {
    return CancelInfoModel(
      reason: entity.reason,
      approvedBy: entity.approvedBy,
      cancelledAt: entity.cancelledAt,
      cancellationKey: entity.cancellationKey,
    );
  }

  CancelInfoEntity toEntity() {
    return CancelInfoEntity(
      reason: reason,
      approvedBy: approvedBy,
      cancelledAt: cancelledAt,
      cancellationKey: cancellationKey,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'reason': reason,
        'approvedBy': approvedBy,
        'cancelledAt': Timestamp.fromDate(cancelledAt),
        if (cancellationKey != null) 'cancellationKey': cancellationKey,
      };
}
