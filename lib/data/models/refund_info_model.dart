import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/domain/entities/refund_info_entity.dart';

/// Firestore `orders/{orderId}.refundInfo` 필드 매퍼.
class RefundInfoModel {
  final String cancellationKey;
  final String reason;
  final String approvedBy;
  final DateTime processedAt;
  final int amount;

  const RefundInfoModel({
    required this.cancellationKey,
    required this.reason,
    required this.approvedBy,
    required this.processedAt,
    required this.amount,
  });

  factory RefundInfoModel.fromMap(Map<String, dynamic> map) {
    final ts = map['processedAt'];
    return RefundInfoModel(
      cancellationKey: (map['cancellationKey'] as String?) ?? '',
      reason: (map['reason'] as String?) ?? '',
      approvedBy: (map['approvedBy'] as String?) ?? '',
      processedAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      amount: (map['amount'] as num?)?.toInt() ?? 0,
    );
  }

  factory RefundInfoModel.fromEntity(RefundInfoEntity entity) {
    return RefundInfoModel(
      cancellationKey: entity.cancellationKey,
      reason: entity.reason,
      approvedBy: entity.approvedBy,
      processedAt: entity.processedAt,
      amount: entity.amount,
    );
  }

  RefundInfoEntity toEntity() {
    return RefundInfoEntity(
      cancellationKey: cancellationKey,
      reason: reason,
      approvedBy: approvedBy,
      processedAt: processedAt,
      amount: amount,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'cancellationKey': cancellationKey,
        'reason': reason,
        'approvedBy': approvedBy,
        'processedAt': Timestamp.fromDate(processedAt),
        'amount': amount,
      };
}
