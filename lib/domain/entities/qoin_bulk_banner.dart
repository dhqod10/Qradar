import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';

/// 일괄 적용 **중단 판정의 단일 출처** (spec §21.1 · §21.7-R1 · design §19-1).
///
/// 돈·중단·정책 상태를 화면에 말하는 판정은 이 파일의 함수를 통과한다. 화면은 결과만 렌더하고
/// 브랜드 문서의 `qoinBulkStatus` 나 이력 스트림을 직접 비교하지 않는다 (가드 테스트가 grep 으로 고정한다 —
/// `isUnfinished(` 와 `qoinBulkStatus` 직접 비교는 **이 파일에서만** 나온다).
///
/// 출처는 브랜드 문서의 포인터 하나다. 포인터는 브랜드 문서와 같은 스트림으로 오므로 그 읽기가 실패하면 화면 자체가
/// 에러 상태가 되어 "중단 없음" 으로 오독될 화면이 남지 않는다 (H-3 수용 기준).
enum QoinBulkBannerKind {
  /// 중단 없음: 포인터 부재 · `completed` · `superseded` · 신선한 `in_progress` · 모르는 코드(구버전 호환).
  none,

  /// 실제로 남은 일이 있는 중단 (`partial`).
  partial,

  /// 오래 갱신이 없는 `in_progress` — 중간에 멈춘 것으로 본다.
  stale,
}

class QoinBulkBanner {
  const QoinBulkBanner(this.kind, {this.historyId});

  static const QoinBulkBanner none = QoinBulkBanner(QoinBulkBannerKind.none);

  final QoinBulkBannerKind kind;

  /// 마지막 시도의 이력 id (포인터의 `qoinBulkHistoryId`). 본문 수치를 읽을 문서이자 `이어서 적용` 의 대상이다.
  final String? historyId;

  /// 배너 · `적용 중단됨` 태그 · 허브 배너를 그려야 하는가.
  bool get isUnfinished => kind != QoinBulkBannerKind.none;

  bool get isStale => kind == QoinBulkBannerKind.stale;
}

/// 브랜드 문서의 포인터로 중단 여부를 판정한다. **이 함수가 유일한 판정이다.**
///
/// - `partial` -> 중단
/// - `in_progress` 인데 `qoinBulkAt` 이 기준(5분)보다 오래됨(또는 시각 없음) -> 중단(stale)
/// - 그 외(null · `completed` · `superseded` · 신선한 `in_progress`) -> 없음
QoinBulkBanner resolveBulkBanner(BrandEntity brand, DateTime now) {
  switch (brand.qoinBulkStatus) {
    case QoinBulkStatus.partial:
      return QoinBulkBanner(
        QoinBulkBannerKind.partial,
        historyId: brand.qoinBulkHistoryId,
      );
    case QoinBulkStatus.inProgress:
      final at = brand.qoinBulkAt;
      if (at == null || now.difference(at) > QoinPolicy.bulkStaleAfter) {
        return QoinBulkBanner(
          QoinBulkBannerKind.stale,
          historyId: brand.qoinBulkHistoryId,
        );
      }
      return QoinBulkBanner(
        QoinBulkBannerKind.none,
        historyId: brand.qoinBulkHistoryId,
      );
    case QoinBulkStatus.completed:
    case QoinBulkStatus.superseded:
    case null:
      return QoinBulkBanner.none;
  }
}

/// 이력 행 하나가 말해야 하는 일괄 적용 상태 (design §19-3). 판정이 아니라 **그 문서의 렌더**이지만, 버튼 활성은 포인터와의
/// 일치를 요구하므로 새 비교식을 만들지 않고 [resolveBulkBanner] 결과를 받는다.
enum QoinHistoryRowKind {
  /// 일괄 적용이 아니거나, 평범하게 끝난 행.
  plain,

  /// 진행 중 (신선).
  running,

  /// 끝나지 않음 — 안내 plate. [QoinHistoryRowState.canResume] 이 버튼 활성 여부.
  unfinished,

  /// `이후 변경으로 마감됐어요`.
  superseded,

  /// `남은 개별 설정이 없어 마감됐어요`.
  closedNothingLeft,
}

class QoinHistoryRowState {
  const QoinHistoryRowState(this.kind, {this.canResume = false});
  final QoinHistoryRowKind kind;

  /// 포인터가 아직 중단이고 이 문서가 그 `qoinBulkHistoryId` 일 때만 true.
  final bool canResume;

  bool get isUnfinished => kind == QoinHistoryRowKind.unfinished;
  bool get isRunning => kind == QoinHistoryRowKind.running;
}

/// 이력 행의 일괄 적용 상태. [pointer] 는 그 브랜드의 [resolveBulkBanner] 결과이고, 브랜드를 아직 읽지 못했으면(로딩·실패·
/// 접근 불가) null 이다 — 그때도 행은 자기 문서의 `status` 로 그려지고 `이어서 적용` 만 숨는다.
QoinHistoryRowState resolveHistoryRow(
  QoinRateChangeEntity change, {
  required QoinBulkBanner? pointer,
  required DateTime now,
}) {
  if (!change.isBulk) {
    return const QoinHistoryRowState(QoinHistoryRowKind.plain);
  }
  switch (change.status) {
    case QoinBulkStatus.superseded:
      return const QoinHistoryRowState(QoinHistoryRowKind.superseded);
    case QoinBulkStatus.completed:
      return QoinHistoryRowState(
        change.isClosedNothingLeft
            ? QoinHistoryRowKind.closedNothingLeft
            : QoinHistoryRowKind.plain,
      );
    case QoinBulkStatus.partial:
      if (pointer == null) {
        return const QoinHistoryRowState(QoinHistoryRowKind.unfinished);
      }
      final matches =
          pointer.kind == QoinBulkBannerKind.partial &&
          pointer.historyId == change.id;
      // 포인터가 다른 시도로 옮겨 갔는데 문서만 partial 인 옛 기록은 종결 줄로 읽는다 (design §19-3).
      return matches
          ? const QoinHistoryRowState(
              QoinHistoryRowKind.unfinished,
              canResume: true,
            )
          : const QoinHistoryRowState(QoinHistoryRowKind.superseded);
    case QoinBulkStatus.inProgress:
      final last = change.lastProgressAt ?? change.changedAt;
      final stale =
          last == null || now.difference(last) > QoinPolicy.bulkStaleAfter;
      final matches = pointer != null && pointer.historyId == change.id;
      if (matches && pointer.kind == QoinBulkBannerKind.stale) {
        return const QoinHistoryRowState(
          QoinHistoryRowKind.unfinished,
          canResume: true,
        );
      }
      if (matches && pointer.kind == QoinBulkBannerKind.none) {
        return const QoinHistoryRowState(QoinHistoryRowKind.running);
      }
      return stale
          ? const QoinHistoryRowState(QoinHistoryRowKind.unfinished)
          : const QoinHistoryRowState(QoinHistoryRowKind.running);
    case null:
      return const QoinHistoryRowState(QoinHistoryRowKind.plain);
  }
}
