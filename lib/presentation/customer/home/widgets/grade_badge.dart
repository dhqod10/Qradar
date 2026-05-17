import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/store_grade.dart';

/// 매장 등급 + 평가 개수 통합 배지.
///
/// home.png 스펙 기준 — 등급별 색 구분 대신 **미드나잇 단일 채움 pill**.
/// 등급 구분은 텍스트("S급")로 전달한다.
class GradeBadge extends StatelessWidget {
  final StoreGrade grade;
  final int reviewCount;

  const GradeBadge({
    super.key,
    required this.grade,
    required this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    final countText = reviewCount == 0 ? '(-)' : '($reviewCount)';

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
            countText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.onPrimary.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}
