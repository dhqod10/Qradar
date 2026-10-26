import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/distance_calculator.dart';
import 'package:qradar/domain/entities/menu_search_hit_entity.dart';
import 'package:qradar/presentation/customer/order/store/providers/main_category_providers.dart';
import 'package:shimmer/shimmer.dart';

/// 메뉴 검색 결과 1행 = (메뉴 x 매장). **숫자 칸을 예약하지 않는다** — 가격·할인·품절·별점 없음.
/// 카테고리 태그는 이동 후 선택될 탭의 글자와 같다 (해석 실패 시 태그를 그리지 않는다).
class MenuSearchResultTile extends ConsumerWidget {
  const MenuSearchResultTile({
    super.key,
    required this.hit,
    required this.onTap,
  });

  final MenuSearchHitEntity hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(mainCategoriesActiveProvider).asData?.value;
    String? categoryLabel;
    if (categories != null) {
      for (final c in categories) {
        if (c.id == hit.mainCategoryCode) {
          categoryLabel = c.label;
          break;
        }
      }
    }
    final distance = hit.distanceKm != null
        ? DistanceCalculator.formatKm(hit.distanceKm!)
        : null;

    return Semantics(
      button: true,
      excludeSemantics: true,
      label:
          '${[hit.menuName, hit.storeName, ?distance, if (categoryLabel != null) '$categoryLabel 카테고리'].join(', ')}. 탭하면 매장 메뉴 화면으로 이동',
      child: Material(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          overlayColor: WidgetStatePropertyAll(
            AppColors.primary.withValues(alpha: 0.04),
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                ExcludeSemantics(child: _Thumb(url: hit.menuImageUrl)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hit.menuName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textHeading,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              hit.storeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textBody,
                              ),
                            ),
                          ),
                          if (distance != null)
                            Text(
                              ' · $distance',
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textBody,
                              ),
                            ),
                        ],
                      ),
                      if (categoryLabel != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            categoryLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textBody,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 56,
        height: 56,
        child: url.isEmpty
            ? _placeholder()
            : CachedNetworkImage(
                imageUrl: url,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                placeholder: (_, _) => Shimmer.fromColors(
                  baseColor: AppColors.surface,
                  highlightColor: AppColors.surfaceElevated,
                  child: Container(color: AppColors.surface),
                ),
                errorWidget: (_, _, _) => _placeholder(),
              ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: AppColors.surface,
    alignment: Alignment.center,
    child: const Icon(
      Icons.restaurant_menu_outlined,
      size: 24,
      color: AppColors.textMuted,
    ),
  );
}
