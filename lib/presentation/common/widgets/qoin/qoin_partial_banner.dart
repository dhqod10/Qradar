import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_labels.dart';

/// 끝나지 않은 일괄 적용(`partial` 또는 오래 멈춘 `in_progress`) 안내 — **세 곳에 같은 컴포넌트**
/// (브랜드 편집 / 이력 행 / 허브). admin 이 해야 할 일을 화면이 말한다:
/// ① 무슨 일이 있었나 ② 안전한가 ③ 무엇을 하면 되나.
///
/// 편집형(`full`)의 판정은 `resolveBulkBanner(브랜드 포인터)` 이고, 이 위젯은 결과를 렌더만 한다. 본문 수치([progress])는
/// 보조 읽기라 null 이어도(로딩·실패·문서 없음) **배너와 `이어서 적용` 은 그대로 그리고 수치 문구만 생략**한다 (spec §21.1).
///
/// 이력 타일이 이 위젯을 품기 때문에 `common` 에 둔다 (design 의 admin/qoin/widgets 에서 이동).
class QoinPartialBanner extends StatelessWidget {
  const QoinPartialBanner._({
    super.key,
    required this.mode,
    this.change,
    this.brandName = '',
    this.rate = QoinRateSetting.absent,
    this.progress,
    this.stale = false,
    this.onResume,
    this.onLater,
  });

  /// 브랜드 편집 화면용 풀 배너 (이어서 적용 / 나중에). 새 적립률 줄은 이력의 `after` 가 아니라 **브랜드 문서의 현재 값**
  /// ([rate]) 에서 읽는다 — 수치 읽기 실패에 종속되지 않는다.
  const QoinPartialBanner.full({
    Key? key,
    required String brandName,
    required QoinRateSetting rate,
    required bool stale,
    QoinRateChangeEntity? progress,
    required VoidCallback onResume,
    required VoidCallback onLater,
  }) : this._(
         key: key,
         mode: QoinPartialBannerMode.full,
         brandName: brandName,
         rate: rate,
         stale: stale,
         progress: progress,
         onResume: onResume,
         onLater: onLater,
       );

  /// 이력 행 내장형. [onResume] 이 null 이면 (점주·브랜드, 또는 포인터와 일치하지 않는 행) 안내 plate 만, 버튼 없음.
  const QoinPartialBanner.inRow({
    Key? key,
    required QoinRateChangeEntity change,
    VoidCallback? onResume,
  }) : this._(
         key: key,
         mode: QoinPartialBannerMode.inRow,
         change: change,
         onResume: onResume,
       );

  final QoinPartialBannerMode mode;
  final QoinRateChangeEntity? change;
  final String brandName;
  final QoinRateSetting rate;
  final QoinRateChangeEntity? progress;
  final bool stale;
  final VoidCallback? onResume;
  final VoidCallback? onLater;

  static const String title = '일부 매장에는 아직 적용되지 않았어요';
  static const String staleTitle = '적용이 중간에 멈춘 것으로 보여요';
  static const String readerRowText = '일부 매장에 아직 적용되지 않았어요';
  static const String resumeLabel = '이어서 적용';
  static const String laterLabel = '나중에';

  /// 안내가 사라지는 조건을 미리 알린다 (design §19-3 사전 고지). 편집 배너에만 둔다.
  static const String disappearNote =
      '이어서 적용을 끝내거나 브랜드 설정을 다시 바꾸면 이 안내는 저절로 사라져요. 중단 기록은 이력에 남아요';

  /// "바뀌었어요" 앞 구절. 새 값이 숫자 / 상위 설정 따르기 중 무엇인지에 따라 조사를 맞춘다.
  String get _changedPhrase {
    if (rate.isAbsent) return '이미 상위 설정을 따르도록 바뀌었어요.';
    final v = rate.value;
    if (v == null) return '이미 바뀌었어요.';
    return '이미 ${QoinRateValueLabel.history(v)} 로 바뀌었어요.';
  }

  int? get _total => progress?.totalCount;
  int get _processed => progress?.processedCount ?? 0;

  /// 본문 (design §15-b / §19-1): ② 안전한가 — 브랜드 값은 이미 바뀌었고 남은 매장은 이전 개별 설정을 유지한다.
  /// 수치를 모르면 수치 문구만 생략한다.
  String get body {
    final head = '브랜드 "$brandName" 의 적립률은 $_changedPhrase';
    final t = _total;
    if (t == null) {
      return '$head 남은 매장은 이전 개별 설정을 계속 쓰고 있어요.';
    }
    final r = (t - _processed).clamp(0, t);
    return '$head 개별 설정 $t곳 중 $_processed곳까지 처리했고, 남은 $r곳은 이전 개별 설정을 계속 쓰고 있어요.';
  }

  String get remainSentence {
    final t = _total;
    if (t == null) return '이어서 적용하면 남은 매장만 처리돼요.';
    final r = (t - _processed).clamp(0, t);
    return '이어서 적용하면 남은 $r곳만 처리돼요.';
  }

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case QoinPartialBannerMode.full:
        final heading = stale ? staleTitle : title;
        return _plate(
          context,
          children: [
            _titleRow(heading),
            const SizedBox(height: 6),
            Text(body, style: _bodyStyle),
            const SizedBox(height: 6),
            Text(
              remainSentence,
              style: _bodyStyle.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: onResume,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(110, 44),
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    resumeLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onLater,
                  style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
                  child: const Text(
                    laterLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textBody,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              disappearNote,
              style: TextStyle(fontSize: 11, height: 1.4, color: AppColors.textMuted),
            ),
          ],
          semantics:
              '경고. $heading. $body $remainSentence 이어서 적용 버튼이 있어요. $disappearNote',
        );
      case QoinPartialBannerMode.inRow:
        final canResume = onResume != null;
        final p = change?.processedCount ?? 0;
        final text = canResume ? '$p곳까지 처리했고 남은 곳이 있어요' : readerRowText;
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: _rowStyle)),
              if (canResume)
                TextButton(
                  onPressed: onResume,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text(
                    resumeLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        );
    }
  }

  Widget _titleRow(String t) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const ExcludeSemantics(
        child: Icon(
          Icons.warning_amber_rounded,
          size: 18,
          color: AppColors.warning,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          t,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textBody,
          ),
        ),
      ),
    ],
  );

  Widget _plate(
    BuildContext context, {
    required List<Widget> children,
    required String semantics,
  }) {
    return Semantics(
      container: true,
      label: semantics,
      child: ExcludeSemantics(
        excluding: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }

  static const TextStyle _bodyStyle = TextStyle(
    fontSize: 13,
    height: 1.5,
    color: AppColors.textBody,
  );
  static const TextStyle _rowStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textBody,
  );
}

enum QoinPartialBannerMode { full, inRow }


// ── 허브 배너 3상태 (design §18-8) ───────────────────────────────────────────────
// 데이터 출처는 이력(인덱스 의존)이 아니라 **브랜드 문서의 포인터**다. 로딩·에러·없음이 서로 다르게 보여야 한다 —
// 에러 때 배너가 사라지면 "중단 없음" 과 "알 수 없음" 이 구별되지 않는다 (H-3).

/// 허브 데이터 배너 (1건 이상). 탭 → 1건이면 그 브랜드 편집, 2건 이상이면 브랜드 목록.
class QoinHubPartialBanner extends StatelessWidget {
  const QoinHubPartialBanner({
    super.key,
    required this.brandName,
    this.moreCount = 0,
    required this.onTap,
  });

  final String brandName;
  final int moreCount;
  final VoidCallback onTap;

  static const String title = '끝나지 않은 일괄 적용이 있어요';

  @override
  Widget build(BuildContext context) {
    final sub = moreCount > 0
        ? '브랜드 "$brandName" 외 $moreCount건'
        : '브랜드 "$brandName"';
    return Semantics(
      button: true,
      label: '경고. $title. $sub',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 20,
                color: AppColors.warning,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textBody,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 허브 배너 로딩: "아직 모름" 을 보인다 (배너를 그리지도, 없음으로 읽히게 비우지도 않는다).
class QoinHubBannerSkeleton extends StatelessWidget {
  const QoinHubBannerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '일괄 적용 상태를 확인하고 있어요',
      excludeSemantics: true,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

/// 허브 배너 에러: 관측 실패는 `error` 틴트로 말한다. 중복 호출 방지를 위해 진행 중에는 버튼에 인디케이터.
class QoinHubBannerError extends StatelessWidget {
  const QoinHubBannerError({
    super.key,
    required this.onRetry,
    this.retrying = false,
  });

  final VoidCallback onRetry;
  final bool retrying;

  static const String title = '일괄 적용 상태를 확인하지 못했어요';
  static const String body =
      '끝나지 않은 일괄 적용이 있는지 알 수 없어요. 브랜드별 적립률에서 직접 확인해주세요';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '오류. $title. 끝나지 않은 일괄 적용이 있는지 알 수 없어요. 다시 시도 버튼이 있어요',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: AppColors.error,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBody,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              body,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: retrying ? null : onRetry,
                style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
                child: retrying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Text(
                        '다시 시도',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
