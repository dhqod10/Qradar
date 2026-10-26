import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/constants/grade_thresholds.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/common/store_list_states.dart';
import 'package:qradar/presentation/customer/home/providers/home_providers.dart';
import 'package:qradar/presentation/customer/home/providers/recommended_stores_providers.dart';
import 'package:qradar/presentation/customer/home/recommended_stores_page.dart';
import 'package:qradar/presentation/customer/home/widgets/section_title.dart';
import 'package:qradar/presentation/customer/home/widgets/store_card.dart';
import 'package:qradar/presentation/customer/order/store/store_menu_page.dart';

/// 홈 `맞춤 추천` — 상위 [GradeThresholds.recommendedPreviewCount] 건 미리보기.
/// 헤더 건수 / `전체보기` / `더 보기` 는 모두 [recommendedTotalCountProvider] 한 곳에서 나온다.
class RecommendedStoresSection extends ConsumerWidget {
  const RecommendedStoresSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = ref.watch(recommendedStoresPreviewProvider);
    final total = ref.watch(recommendedTotalCountProvider);
    final hasMore =
        total != null && total > GradeThresholds.recommendedPreviewCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          // 로딩·에러에는 건수를 그리지 않는다 ('(0)' 오독 방지).
          title: total == null ? '맞춤 추천' : '맞춤 추천 ($total)',
          trailing: hasMore ? _SeeAllButton(onTap: () => _openAll(context)) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: stores.when(
            data: (list) {
              if (list.isEmpty) return const RecommendedEmptyState();
              return Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    RecommendedStoreCard(
                      store: list[i],
                      onTap: () => _openStoreMenu(context, list[i]),
                    ),
                    if (i != list.length - 1) const SizedBox(height: 12),
                  ],
                  if (hasMore) ...[
                    const SizedBox(height: 12),
                    _MoreButton(
                      remaining:
                          total - GradeThresholds.recommendedPreviewCount,
                      onTap: () => _openAll(context),
                    ),
                  ],
                ],
              );
            },
            loading: () => const StoreListSkeleton(),
            error: (_, _) => StoreListError(
              onRetry: () => ref.invalidate(storeSnapshotProvider),
            ),
          ),
        ),
      ],
    );
  }

  void _openAll(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RecommendedStoresPage()),
    );
  }

  void _openStoreMenu(BuildContext context, StoreEntity store) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoreMenuPage(store: store),
      ),
    );
  }
}

/// 헤더 `전체보기` — 터치 영역 최소 44x44.
class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: const SizedBox(
        height: 44,
        child: Center(
          widthFactor: 1,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '전체보기',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.info,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 5건 아래 `맞춤 추천 N곳 더 보기` 버튼 (전체 > 5 일 때만).
class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.remaining, required this.onTap});
  final int remaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '맞춤 추천 $remaining곳 더 보기, 버튼',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '맞춤 추천 $remaining곳 더 보기',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textBody,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
