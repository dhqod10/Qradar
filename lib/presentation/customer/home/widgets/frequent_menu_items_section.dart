import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/domain/entities/frequent_menu_item_entity.dart';
import 'package:qradar/presentation/customer/home/providers/recommendation_providers.dart';
import 'package:qradar/presentation/customer/home/widgets/section_title.dart';
import 'package:qradar/presentation/customer/order/store/store_menu_page.dart';
import 'package:shimmer/shimmer.dart';

const double _kCardHeight = 244;

/// "자주 찾는 메뉴" 섹션 — 매장-메뉴 페어 빈도 + favorite boost.
class FrequentMenuItemsSection extends ConsumerWidget {
  const FrequentMenuItemsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(frequentMenuItemsProvider);

    final child = async.when(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return _ContentColumn(items: list);
      },
      loading: () => const _LoadingColumn(),
      error: (e, _) {
        if (kDebugMode) debugPrint('[FrequentMenuItems] error: $e');
        return const SizedBox.shrink();
      },
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      child: child,
    );
  }
}

class _ContentColumn extends ConsumerWidget {
  final List<FrequentMenuItemEntity> items;
  const _ContentColumn({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      key: const ValueKey('frequent-menu-content'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: '자주 찾는 메뉴'),
        SizedBox(
          height: _kCardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final entity = items[i];
              return FrequentMenuCard(
                entity: entity,
                onTap: () => _openStore(context, ref, entity.storeId),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _openStore(BuildContext context, WidgetRef ref, String storeId) {
    final store = ref.read(storesByIdProvider)[storeId];
    if (store == null) return; // store entity 미로드 → 진입 보류
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => StoreMenuPage(store: store)),
    );
  }
}

class _LoadingColumn extends StatelessWidget {
  const _LoadingColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('frequent-menu-loading'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: '자주 찾는 메뉴'),
        SizedBox(
          height: _kCardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemCount: 3,
            itemBuilder: (_, _) => Shimmer.fromColors(
              baseColor: AppColors.surface,
              highlightColor: AppColors.surfaceElevated,
              child: Container(
                width: 160,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class FrequentMenuCard extends StatelessWidget {
  final FrequentMenuItemEntity entity;
  final VoidCallback onTap;

  const FrequentMenuCard({
    super.key,
    required this.entity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.4;
    final clampedWidth = width.clamp(140.0, 180.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: clampedWidth,
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: _MenuImage(
                    url: entity.imageUrl,
                    size: clampedWidth,
                  ),
                ),
                if (entity.orderCount > 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _CountBadge(count: entity.orderCount),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entity.menuItemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHeading,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entity.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '최근 ${entity.orderCount}회 주문',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    PriceFormatter.formatKrw(entity.basePrice),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.textHeading.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.repeat_rounded,
            size: 11,
            color: AppColors.onPrimary,
          ),
          const SizedBox(width: 4),
          Text(
            '$count회',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuImage extends StatelessWidget {
  final String url;
  final double size;

  const _MenuImage({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder();
    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (_, _) => _shimmer(),
      errorWidget: (_, _, _) => _placeholder(),
    );
  }

  Widget _shimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceElevated,
      child: Container(width: size, height: size, color: AppColors.surface),
    );
  }

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      color: AppColors.surface,
      alignment: Alignment.center,
      child: const Icon(
        Icons.local_cafe_outlined,
        color: AppColors.textMuted,
        size: 28,
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: AppColors.surfaceElevated,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.border, width: 1),
    boxShadow: [
      BoxShadow(
        color: AppColors.primary.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}
