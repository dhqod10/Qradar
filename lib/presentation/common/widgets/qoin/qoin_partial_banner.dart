import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_labels.dart';

/// 끝나지 않은 일괄 적용(`partial` 또는 오래 멈춘 `in_progress`) 안내 — **세 곳에 같은 컴포넌트**
/// (브랜드 편집 / 이력 행 / 허브). admin 이 해야 할 일을 화면이 말한다:
/// ① 무슨 일이 있었나 ② 안전한가 ③ 무엇을 하면 되나.
///
/// 이력 타일이 이 위젯을 품기 때문에 `common` 에 둔다 (design 의 admin/qoin/widgets 에서 이동).
class QoinPartialBanner extends StatelessWidget {
  const QoinPartialBanner._({
    super.key,
    required this.mode,
    required this.change,
    this.onResume,
    this.onLater,
    this.moreCount = 0,
    this.onTap,
  });

  /// 브랜드 편집 화면용 풀 배너 (이어서 적용 / 나중에).
  const QoinPartialBanner.full({
    Key? key,
    required QoinRateChangeEntity change,
    required VoidCallback onResume,
    required VoidCallback onLater,
  }) : this._(
         key: key,
         mode: QoinPartialBannerMode.full,
         change: change,
         onResume: onResume,
         onLater: onLater,
       );

  /// 이력 행 내장형. [onResume] 이 null 이면 (점주·브랜드) 안내 plate 만, 버튼 없음.
  const QoinPartialBanner.inRow({
    Key? key,
    required QoinRateChangeEntity change,
    VoidCallback? onResume,
  }) : this._(key: key, mode: QoinPartialBannerMode.inRow, change: change, onResume: onResume);

  /// 허브 축약형. 탭 → 이력 `미완료` 필터. [moreCount] 는 첫 건 외 개수.
  const QoinPartialBanner.hub({
    Key? key,
    required QoinRateChangeEntity change,
    int moreCount = 0,
    required VoidCallback onTap,
  }) : this._(
         key: key,
         mode: QoinPartialBannerMode.hub,
         change: change,
         moreCount: moreCount,
         onTap: onTap,
       );

  final QoinPartialBannerMode mode;
  final QoinRateChangeEntity change;
  final VoidCallback? onResume;
  final VoidCallback? onLater;
  final int moreCount;
  final VoidCallback? onTap;

  static const String title = '일부 매장에는 아직 적용되지 않았어요';
  static const String hubTitle = '끝나지 않은 일괄 적용이 있어요';
  static const String readerRowText = '일부 매장에 아직 적용되지 않았어요';
  static const String resumeLabel = '이어서 적용';
  static const String laterLabel = '나중에';

  /// "바뀌었어요" 앞 구절. 새 값이 숫자 / 적립 안 함 / 상위 설정 따르기 중 무엇인지에 따라 조사를 맞춘다.
  String get _changedPhrase {
    final a = change.afterRate;
    if (a == null) return '이미 상위 설정을 따르도록 바뀌었어요.';
    if (a == 0) return '이미 적립 안 함 (0%) 으로 바뀌었어요.';
    return '이미 ${QoinRateValueLabel.history(a)} 로 바뀌었어요.';
  }

  /// 본문 (design §15-b): ② 안전한가 — 브랜드 값은 이미 바뀌었고 남은 매장은 이전 개별 설정을 유지한다.
  String get body {
    final name = change.targetName;
    final t = change.totalCount;
    final p = change.processedCount ?? 0;
    final head = '브랜드 "$name" 의 적립률은 $_changedPhrase';
    if (t == null) {
      return '$head $p곳까지 처리했고, 남은 매장은 이전 개별 설정을 계속 쓰고 있어요.';
    }
    final r = (t - p).clamp(0, t);
    return '$head 개별 설정 $t곳 중 $p곳까지 처리했고, 남은 $r곳은 이전 개별 설정을 계속 쓰고 있어요.';
  }

  String get remainSentence {
    final t = change.totalCount;
    if (t == null) return '이어서 적용하면 남은 매장만 처리돼요.';
    final r = (t - (change.processedCount ?? 0)).clamp(0, t);
    return '이어서 적용하면 남은 $r곳만 처리돼요.';
  }

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case QoinPartialBannerMode.full:
        return _plate(
          context,
          children: [
            _titleRow(title),
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
          ],
          semantics:
              '경고. $title. $body $remainSentence 이어서 적용 버튼이 있어요',
        );
      case QoinPartialBannerMode.inRow:
        final canResume = onResume != null;
        final p = change.processedCount ?? 0;
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
      case QoinPartialBannerMode.hub:
        final sub = moreCount > 0
            ? '브랜드 "${change.targetName}" 외 $moreCount건'
            : '브랜드 "${change.targetName}"';
        return Semantics(
          button: true,
          label: '경고. $hubTitle. $sub',
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
                          hubTitle,
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

enum QoinPartialBannerMode { full, inRow, hub }
