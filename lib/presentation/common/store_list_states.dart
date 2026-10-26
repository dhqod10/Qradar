import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:shimmer/shimmer.dart';

/// 매장 목록 공통 상태 UI — 홈 `맞춤 추천` · 추천 전체보기 · 검색이 같은 패턴을 쓴다 (문구는 파라미터).

/// 카드 skeleton (기본 높이 96, 간격 12).
class StoreListSkeleton extends StatelessWidget {
  const StoreListSkeleton({
    super.key,
    this.rows = 3,
    this.rowHeight = 96,
    this.gap = 12,
  });

  final int rows;
  final double rowHeight;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        rows,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: i == rows - 1 ? 0 : gap),
          child: Shimmer.fromColors(
            baseColor: AppColors.surface,
            highlightColor: AppColors.surfaceElevated,
            child: Container(
              height: rowHeight,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 에러 블록 — 예외 원문을 **노출하지 않는다** (고정 문구).
class StoreListError extends StatelessWidget {
  const StoreListError({
    super.key,
    required this.onRetry,
    this.title = '매장 정보를 불러올 수 없어요',
    this.description = '잠시 후 다시 시도해 주세요',
    this.actionLabel = '다시 시도',
  });

  final VoidCallback onRetry;
  final String title;
  final String description;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 카테고리 미일치 빈 상태 (홈 · 전체보기 공용).
class RecommendedEmptyState extends StatelessWidget {
  const RecommendedEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.filter_alt_off_outlined,
              size: 40,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 12),
            Text(
              '선택한 카테고리에 해당하는 매장이 없습니다',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textBody,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
