import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/domain/entities/qoin_transaction_entity.dart';
import 'package:qradar/domain/entities/qoin_transaction_type.dart';

/// `users/{uid}/qoinTransactions/{txId}` 매퍼. **읽기 전용** (쓰기는 CF 전용).
class QoinTransactionModel {
  const QoinTransactionModel._();

  static QoinTransactionEntity fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      fromMap(doc.id, doc.data() ?? const <String, dynamic>{});

  /// 방어적 파싱. 누락/비정상 필드는 안전 기본값. amount 부호는 그대로 보존.
  static QoinTransactionEntity fromMap(String id, Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    return QoinTransactionEntity(
      txId: id,
      type: QoinTransactionType.fromCode(_str(data['type'])),
      amount: _int(data['amount']) ?? 0,
      balanceAfter: _int(data['balanceAfter']) ?? 0,
      orderId: _str(data['orderId']) ?? '',
      storeId: _str(data['storeId']) ?? '',
      storeName: _str(data['storeName']) ?? '',
      orderTotalPrice: _int(data['orderTotalPrice']),
      accrualRate: _rate(data['accrualRate']),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }

  static String? _str(Object? v) => v is String ? v : null;

  static int? _int(Object? v) {
    if (v is! num || v.isNaN || v.isInfinite) return null;
    return v.toInt();
  }

  static double? _rate(Object? v) {
    if (v is! num || v.isNaN || v.isInfinite) return null;
    return v.toDouble();
  }
}
