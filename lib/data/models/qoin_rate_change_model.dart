import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';

/// `…/qoinRateHistory/{id}` 매퍼.
///
/// 알 수 없는 `scope` / `field` / `source` / `op` 는 **null 반환, 폴백 금지** —
/// 이력은 감사 기록이라 모르는 값을 아는 척 그리면 안 된다 (1차 `QoinTransactionType.fromCode` 와 같은 정책).
/// 목록은 null 을 걸러서 보여준다.
class QoinRateChangeModel {
  const QoinRateChangeModel._();

  static QoinRateChangeEntity? fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => fromMap(doc.id, doc.data() ?? const <String, dynamic>{});

  static QoinRateChangeEntity? fromMap(String id, Map<String, dynamic> data) {
    final scope = QoinRateScope.fromCode(data['scope']);
    final field = QoinRateField.fromCode(data['field']);
    final source = QoinRateChangeSource.fromCode(data['source']);
    final op = QoinRateChangeOp.fromCode(data['op']);
    final targetId = data['targetId'];
    if (scope == null ||
        field == null ||
        source == null ||
        op == null ||
        targetId is! String) {
      return null;
    }

    double? rate(Object? v) => v is num ? v.toDouble() : null;
    bool? flag(Object? v) => v is bool ? v : null;
    int? count(Object? v) => v is num ? v.toInt() : null;
    DateTime? ts(Object? v) => v is Timestamp ? v.toDate() : null;
    final isRate = field == QoinRateField.accrualRate;

    return QoinRateChangeEntity(
      id: id,
      scope: scope,
      targetId: targetId,
      targetName: (data['targetName'] as String?) ?? '',
      field: field,
      beforeRate: isRate ? rate(data['before']) : null,
      afterRate: isRate ? rate(data['after']) : null,
      beforeEnabled: isRate ? null : flag(data['before']),
      afterEnabled: isRate ? null : flag(data['after']),
      changedBy: data['changedBy'] as String?,
      changedAt: ts(data['changedAt']),
      reason: data['reason'] as String?,
      source: source,
      op: op,
      bulkMode: QoinBulkMode.fromCode(data['bulkMode']),
      status: QoinBulkStatus.fromCode(data['status']),
      affectedCount: count(data['affectedCount']),
      clearedCount: count(data['clearedCount']),
      preservedCount: count(data['preservedCount']),
      processedCount: count(data['processedCount']),
      totalCount: count(data['totalCount']),
      lastProgressAt: ts(data['lastProgressAt']),
    );
  }
}
