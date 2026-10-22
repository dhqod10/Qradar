import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';

part 'qoin_rate_change_entity.freezed.dart';

/// 이력이 다루는 필드.
enum QoinRateField {
  /// 적립률 (`accrualRate` / `qoinAccrualRate`).
  accrualRate('accrualRate'),

  /// 전역 비상 정지 (`config/qoin.enabled`).
  enabled('enabled');

  const QoinRateField(this.code);
  final String code;

  static QoinRateField? fromCode(Object? code) {
    for (final f in values) {
      if (f.code == code) return f;
    }
    return null;
  }
}

/// 변경 경로. `direct` 는 Console / 직접 쓰기 (행위자를 알 수 없다).
enum QoinRateChangeSource {
  callable('callable'),
  bulk('bulk'),
  direct('direct');

  const QoinRateChangeSource(this.code);
  final String code;

  static QoinRateChangeSource? fromCode(Object? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

enum QoinRateChangeOp {
  set('set'),
  clear('clear'),
  bulkApply('bulkApply');

  const QoinRateChangeOp(this.code);
  final String code;

  static QoinRateChangeOp? fromCode(Object? code) {
    for (final o in values) {
      if (o.code == code) return o;
    }
    return null;
  }
}

enum QoinBulkMode {
  preserve('preserve'),
  overwrite('overwrite');

  const QoinBulkMode(this.code);
  final String code;

  static QoinBulkMode? fromCode(Object? code) {
    for (final m in values) {
      if (m.code == code) return m;
    }
    return null;
  }
}

enum QoinBulkStatus {
  inProgress('in_progress'),
  completed('completed'),
  partial('partial');

  const QoinBulkStatus(this.code);
  final String code;

  static QoinBulkStatus? fromCode(Object? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

/// 적립률 변경 이력 1건 (`…/qoinRateHistory/{id}`). 읽기 전용 — 쓰기는 CF 전담.
///
/// `before` / `after`: [field] 가 accrualRate 면 [beforeRate] / [afterRate] (null = 설정 없음/상속, 0 = 적립 안 함),
/// enabled 면 [beforeEnabled] / [afterEnabled].
@freezed
abstract class QoinRateChangeEntity with _$QoinRateChangeEntity {
  const QoinRateChangeEntity._();

  const factory QoinRateChangeEntity({
    required String id,
    required QoinRateScope scope,
    required String targetId,

    /// 변경 당시 대상 이름 (박제). 옛 이력은 빈 문자열일 수 있다.
    @Default('') String targetName,
    required QoinRateField field,
    double? beforeRate,
    double? afterRate,
    bool? beforeEnabled,
    bool? afterEnabled,

    /// null = Console 등 out-of-band 편집 (행위자 알 수 없음).
    String? changedBy,
    DateTime? changedAt,
    String? reason,
    required QoinRateChangeSource source,
    required QoinRateChangeOp op,

    // ── 일괄 적용 (op == bulkApply) ───────────────────────────────────────────
    QoinBulkMode? bulkMode,
    QoinBulkStatus? status,

    /// 서버가 실제로 센 값 (클라이언트 미리보기가 아니다).
    int? affectedCount,
    int? clearedCount,
    int? preservedCount,
    int? processedCount,

    /// 처리 대상(개별 설정이 있던) 매장 수.
    int? totalCount,
    DateTime? lastProgressAt,
  }) = _QoinRateChangeEntity;

  bool get isBulk => op == QoinRateChangeOp.bulkApply;

  /// 끝나지 않은 일괄 적용인가: partial, 또는 오래 갱신이 없는 in_progress (고아 — design D8).
  bool isUnfinished(DateTime now) {
    if (!isBulk) return false;
    if (status == QoinBulkStatus.partial) return true;
    if (status != QoinBulkStatus.inProgress) return false;
    final last = lastProgressAt ?? changedAt;
    if (last == null) return true;
    return now.difference(last) > QoinPolicy.bulkStaleAfter;
  }

  /// 진행 중(아직 stale 아님)인가.
  bool isRunning(DateTime now) =>
      isBulk && status == QoinBulkStatus.inProgress && !isUnfinished(now);
}
