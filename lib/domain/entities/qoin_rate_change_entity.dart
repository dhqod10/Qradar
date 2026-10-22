import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';

part 'qoin_rate_change_entity.freezed.dart';

/// 이력이 다루는 필드.
enum QoinRateField {
  /// 적립률 (`accrualRate` / `qoinAccrualRate`).
  accrualRate('accrualRate'),

  /// 매장·브랜드 적립 스위치 (`qoinAccrualEnabled`). before/after 는 bool|null (null = 부재 = 사용).
  accrualEnabled('accrualEnabled'),

  /// 전역 비상 정지 (`config/qoin.enabled`). 옛 코드 `enabled` 도 이것으로 읽는다.
  globalEnabled('globalEnabled');

  const QoinRateField(this.code);
  final String code;

  static QoinRateField? fromCode(Object? code) {
    if (code == 'enabled') return globalEnabled; // 관대한 판독: 개명 전 코드
    for (final f in values) {
      if (f.code == code) return f;
    }
    return null;
  }
}

/// 변경 경로. `direct` 는 Console / 직접 쓰기 (행위자를 알 수 없다), `appDirect` 는 앱 직접 쓰기 (행위자 uid 있음).
/// 알 수 없는 값은 [unknown] — 이력 행은 보여주되 경로는 말하지 않는다.
enum QoinRateChangeSource {
  callable('callable'),
  bulk('bulk'),
  direct('direct'),
  appDirect('app_direct'),

  /// 마이그레이션 (0% → 사용 안 함 이전). 정리 커밋 후에도 이력 판독용으로 남는다.
  migration('migration'),
  unknown('unknown');

  const QoinRateChangeSource(this.code);
  final String code;

  static QoinRateChangeSource fromCode(Object? code) {
    for (final s in values) {
      if (s != unknown && s.code == code) return s;
    }
    return unknown;
  }
}

enum QoinRateChangeOp {
  set('set'),
  clear('clear'),
  bulkApply('bulkApply'),

  /// 브랜드 일괄 적용이 이 매장의 개별 적립률을 지웠다 (매장별 이력).
  clearByBulk('clearByBulk'),
  unknown('unknown');

  const QoinRateChangeOp(this.code);
  final String code;

  static QoinRateChangeOp fromCode(Object? code) {
    for (final o in values) {
      if (o != unknown && o.code == code) return o;
    }
    return unknown;
  }
}

/// 변경 직전 값의 상태 (`before` 의 모호성 제거). 문서에 없으면 null.
enum QoinBeforeState {
  absent('absent'),
  value('value'),
  invalid('invalid');

  const QoinBeforeState(this.code);
  final String code;

  static QoinBeforeState? fromCode(Object? code) {
    for (final s in values) {
      if (s.code == code) return s;
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
/// `before` / `after`: [field] 가 accrualRate 면 [beforeRate] / [afterRate] (null = 설정 없음/상속),
/// accrualEnabled / globalEnabled 면 [beforeEnabled] / [afterEnabled] (accrualEnabled 의 null = 부재 = 사용).
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

    // ── 부가 B / F2 / 마이그레이션 ─────────────────────────────────────────────
    /// 변경 직전 값의 상태. 옛 이력은 null (관대하게 해석).
    QoinBeforeState? beforeState,

    /// 무효였던 값의 원형 문자열 (비number/비bool 일 때만).
    String? beforeRaw,

    /// 매장별 `clearByBulk` 이력이 가리키는 브랜드 이력 ID (admin 용 상관 키 — 점주용 링크가 아니다, N8).
    String? bulkHistoryId,

    /// 마이그레이션이 사라지게 한 옛 숫자(0). 박제용.
    double? migratedFromRate,
    DateTime? resumedAt,
    int? resumeCount,

    /// 일괄 적용 후에도 적립이 시작되지 않는(스위치 off) 산하 매장 수. `cleared*` 합에 들어가지 않는다.
    int? disabledUntouchedCount,
    int? clearedValueCount,
    int? clearedInvalidCount,

    /// 일괄 적용 시점에 브랜드 자신의 스위치가 꺼져 있었는가 → 산하 매장 전체가 적립되지 않는다.
    bool? brandDisabled,
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
