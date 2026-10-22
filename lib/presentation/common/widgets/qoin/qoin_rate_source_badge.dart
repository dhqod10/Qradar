import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_labels.dart';

/// 적립률 출처 배지 (`매장 설정 / 브랜드 설정 / 브랜드 상속 / 전역 상속 / 매장에서 중단 / 브랜드에서 중단 / 설정 확인 필요`).
///
/// 의미를 **글자 + 아이콘**이 지고 색은 보조다 (색 없이도 7종이 구분된다). 글자는 전부 `textBody`.
/// 기존 `StoreScopeBadge`(알약 radius 999)와 한 타일에 있어도 구분되도록 **radius 6 태그** 모양이다.
/// owner / brand / admin 이 모두 쓰므로 `common` 에 둔다 (역할 간 import 방지).
class QoinRateSourceBadge extends StatelessWidget {
  const QoinRateSourceBadge({super.key, required this.kind});

  /// 해석 결과로부터 만든다. [target] 은 보는 대상의 범위 (brand 또는 store).
  factory QoinRateSourceBadge.of(
    EffectiveQoinRate effective, {
    required QoinRateScope target,
    Key? key,
  }) => QoinRateSourceBadge(
    key: key,
    kind: QoinRateBadgeKind.of(effective, target: target),
  );

  final QoinRateBadgeKind kind;

  @override
  Widget build(BuildContext context) {
    final spec = _spec(kind);
    return Semantics(
      label: '적립률 출처, ${kind.label}',
      excludeSemantics: true,
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: spec.tint,
          borderRadius: BorderRadius.circular(6),
          border: spec.border,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(spec.icon, size: 12, color: spec.iconColor),
            const SizedBox(width: 4),
            Text(
              kind.label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textBody,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static _BadgeSpec _spec(QoinRateBadgeKind kind) {
    switch (kind) {
      case QoinRateBadgeKind.storeSet:
      case QoinRateBadgeKind.brandSet:
        return _BadgeSpec(
          Icons.tune_rounded,
          AppColors.primary.withValues(alpha: 0.10),
          AppColors.primary,
        );
      case QoinRateBadgeKind.brandInherit:
        // sky 아이콘은 흰 배경 대비가 낮아 아이콘만 navy.
        return _BadgeSpec(
          Icons.subdirectory_arrow_right_rounded,
          AppColors.primaryBright.withValues(alpha: 0.15),
          AppColors.primary,
        );
      case QoinRateBadgeKind.globalInherit:
        return _BadgeSpec(
          Icons.subdirectory_arrow_right_rounded,
          AppColors.textMuted.withValues(alpha: 0.12),
          AppColors.textMuted,
        );
      case QoinRateBadgeKind.storeStopped:
      case QoinRateBadgeKind.brandStopped:
        return _BadgeSpec(
          Icons.pause_circle_outline_rounded,
          AppColors.warning.withValues(alpha: 0.18),
          AppColors.warning,
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.5),
            width: 1,
          ),
        );
      case QoinRateBadgeKind.invalid:
        // 유일한 error 사용처 — 데이터가 실제로 깨진 상태.
        return _BadgeSpec(
          Icons.error_outline_rounded,
          AppColors.error.withValues(alpha: 0.10),
          AppColors.error,
        );
    }
  }
}

class _BadgeSpec {
  const _BadgeSpec(this.icon, this.tint, this.iconColor, {this.border});
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final BoxBorder? border;
}

/// 적립률 값 텍스트 — 값의 **위계**로 상속과 명시를 구분한다.
/// 명시 값 = `textHeading`/w800, 상속 값 = `textMuted`/w600, 해석 불가 `—` = muted.
/// 배지를 못 봐도 숫자의 무게만으로 "정한 값인가, 흘러온 값인가" 가 읽힌다.
class QoinRateValueText extends StatelessWidget {
  const QoinRateValueText({
    super.key,
    required this.effective,
    required this.kind,
    this.fontSize = 17,
    this.disabledSentence = false,
  });

  final EffectiveQoinRate effective;
  final QoinRateBadgeKind kind;
  final double fontSize;

  /// 사용 안 함일 때 문장형 `적립 사용 안 함` (점주·브랜드 읽기 행) / false 면 값 라벨 `사용 안 함`.
  final bool disabledSentence;

  @override
  Widget build(BuildContext context) {
    final explicit = kind.isExplicit;
    final invalid = effective.isInvalid;
    if (effective.isDisabled) {
      // 스위치가 꺼진 값 칸: pause 아이콘 + `사용 안 함`. 숫자를 보이지 않는다 (`5%` 로 읽히면 안 된다).
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pause_circle_outline_rounded,
              size: fontSize * 0.8,
              color: AppColors.warning,
            ),
            const SizedBox(width: 4),
            Text(
              disabledSentence
                  ? QoinRateLabels.switchOffSentence
                  : QoinRateLabels.switchOff,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: AppColors.textHeading,
              ),
            ),
          ],
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text(
        QoinRateValueLabel.effective(effective),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: explicit ? FontWeight.w800 : FontWeight.w600,
          color: explicit && !invalid
              ? AppColors.textHeading
              : AppColors.textMuted,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
