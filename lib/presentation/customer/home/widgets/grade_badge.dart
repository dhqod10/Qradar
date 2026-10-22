import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/store_grade.dart';

/// 매장 등급 + 평가 개수 통합 배지.
///
/// home.png 스펙 기준 — 등급별 색 구분 대신 **미드나잇 단일 채움 pill**.
/// 등급 구분은 텍스트("S급")로 전달한다.
///
/// 평가가 0건이면 등급 대신 약한 `미평가` pill 을 보여준다 (C급 폴백이 아님).
/// [showChevron] 은 탭 어포던스(`>`)로, 매장 메뉴 헤더에서만 켠다.
class GradeBadge extends StatelessWidget {
  final StoreGrade grade;
  final int reviewCount;
  final bool showChevron;

  const GradeBadge({
    super.key,
    required this.grade,
    required this.reviewCount,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    if (reviewCount == 0) {
      return Semantics(
        label: '아직 평가가 없는 매장',
        excludeSemantics: true,
        child: _unrated(),
      );
    }
    return Semantics(
      label: '${grade.label}, 평가 $reviewCount개',
      excludeSemantics: true,
      child: _rated(),
    );
  }

  Widget _rated() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            grade.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.onPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '($reviewCount)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.onPrimary.withValues(alpha: 0.75),
            ),
          ),
          if (showChevron) ...[
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: AppColors.onPrimary,
            ),
          ],
        ],
      ),
    );
  }

  /// border 1px 만큼 padding 을 줄여(가로 9 / 세로 3.5, 글자 높이 실측 -1px 보정) 총 크기를 `rated` 와 맞춘다.
  Widget _unrated() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '미평가',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textBody,
            ),
          ),
          if (showChevron) ...[
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: AppColors.textBody,
            ),
          ],
        ],
      ),
    );
  }
}
