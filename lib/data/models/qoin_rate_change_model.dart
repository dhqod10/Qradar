import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';

/// `…/qoinRateHistory/{id}` 매퍼.
///
/// 알 수 없는 `scope` / `field` 는 **null 반환, 폴백 금지** —
/// 이력은 감사 기록이라 모르는 값을 아는 척 그리면 안 된다 (1차 `QoinTransactionType.fromCode` 와 같은 정책).
/// `source` / `op` 의 미지값은 `unknown` 으로 읽어 행은 보여준다 (미지값 관대 처리). 목록은 null 을 걸러서 보여준다.
class QoinRateChangeModel {
  const QoinRateChangeModel._();

  static QoinRateChangeEntity? fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => fromMap(doc.id, doc.data() ?? const <String, dynamic>{});

  static QoinRateChangeEntity? fromMap(String id, Map<String, dynamic> data) {
    final scope = QoinRateScope.fromCode(data['scope']);
    final field = QoinRateField.fromCode(data['field']);
    // source / op 의 미지값은 unknown 으로 관대하게 읽는다 (행은 보여주고 경로는 말하지 않는다).
    // scope / field 는 모르면 행 자체를 아는 척 그릴 수 없으므로 거른다.
    final source = QoinRateChangeSource.fromCode(data['source']);
    final op = QoinRateChangeOp.fromCode(data['op']);
    final targetId = data['targetId'];
    if (scope == null || field == null || targetId is! String) {
      return null;
    }

    double? rate(Object? v) => v is num ? v.toDouble() : null;
    bool? flag(Object? v) => v is bool ? v : null;
    int? count(Object? v) => v is num ? v.toInt() : null;
    DateTime? ts(Object? v) => v is Timestamp ? v.toDate() : null;
    double? asDouble(Object? v) => v is num ? v.toDouble() : null;
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
      beforeState: QoinBeforeState.fromCode(data['beforeState']),
      beforeRaw: data['beforeRaw'] is String
          ? data['beforeRaw'] as String
          : null,
      bulkHistoryId: data['bulkHistoryId'] is String
          ? data['bulkHistoryId'] as String
          : null,
      // TRANSITIONAL(spec §20.4.5): 마이그레이션 이력의 옛 숫자(0) 박제 필드. 정리 커밋에서 필드째 삭제한다 (읽기 호환만 잃는다).
      migratedFromRate: asDouble(data['migratedFromRate']),
      resumedAt: ts(data['resumedAt']),
      resumeCount: count(data['resumeCount']),
      disabledUntouchedCount: count(data['disabledUntouchedCount']),
      clearedValueCount: count(data['clearedValueCount']),
      clearedInvalidCount: count(data['clearedInvalidCount']),
      brandDisabled: flag(data['brandDisabled']),
      closedReason: data['closedReason'] is String
          ? data['closedReason'] as String
          : null,
      supersededByUid: data['supersededByUid'] is String
          ? data['supersededByUid'] as String
          : null,
    );
  }
}
