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

// ── 무한 스크롤 목록 상태 (store_list_pagination) — 문구는 모두 파라미터 ──────────

/// 추가 로딩 footer — 리스트 끝 스피너 (20x20, primary).
class StoreListLoadingFooter extends StatelessWidget {
  const StoreListLoadingFooter({
    super.key,
    this.semanticsLabel = '매장을 더 불러오는 중',
  });

  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 추가 로드 실패 footer — 기존 목록은 그대로 두고 텍스트 버튼으로만 재시도한다.
class StoreListRetryFooter extends StatelessWidget {
  const StoreListRetryFooter({
    super.key,
    required this.onRetry,
    this.message = '매장을 더 불러오지 못했어요',
    this.actionLabel = '다시 시도',
  });

  final VoidCallback onRetry;
  final String message;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 18, color: AppColors.error),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 44),
              foregroundColor: AppColors.primaryBright,
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBright,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 소진 footer — 더 이상 불러올 매장이 없음. 반경(km) 수치를 노출하지 않는다.
class StoreListEndFooter extends StatelessWidget {
  const StoreListEndFooter({
    super.key,
    this.message = '주변에 더 이상 매장이 없어요',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// 주변 매장 없음 빈 상태 (최대 반경까지 확장한 뒤에만 노출).
class NearbyEmptyState extends StatelessWidget {
  const NearbyEmptyState({
    super.key,
    this.title = '주변에 매장이 없어요',
    this.subtitle = '위치를 바꾸거나 나중에 다시 확인해 주세요',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.storefront_outlined,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textBody,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// 위치 폴백 배너 — 거리순 기준이 사용자 위치가 아님을 고지. [onAction] 이 있을 때만 우측 액션 노출.
class LocationFallbackBanner extends StatelessWidget {
  const LocationFallbackBanner({
    super.key,
    this.title = '내 위치를 확인할 수 없어요',
    this.description = '서울시청 기준 가까운 순으로 보여드려요',
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_off_outlined,
            size: 20,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHeading,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBright,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
