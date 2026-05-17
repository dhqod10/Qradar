import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/frequent_store_entity.dart';
import 'package:qradar/presentation/customer/home/providers/recommendation_providers.dart';
import 'package:qradar/presentation/customer/home/widgets/grade_badge.dart';
import 'package:qradar/presentation/customer/home/widgets/section_title.dart';
import 'package:qradar/presentation/customer/order/store/store_menu_page.dart';
import 'package:shimmer/shimmer.dart';

const double _kCardHeight = 200;
const double _kImageHeight = 112;

/// "자주 찾는 매장" 섹션 — visitCount + favorite boost.
class FrequentStoresSection extends ConsumerWidget {
  const FrequentStoresSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(frequentStoresProvider);

    final child = async.when(
      data: (list) {
        // store == null 인 항목은 hide.
        final visible =
            list.where((e) => e.store != null).toList(growable: false);
        if (visible.isEmpty) return const SizedBox.shrink();
        return _ContentColumn(stores: visible);
      },
      loading: () => const _LoadingColumn(),
      error: (e, _) {
        if (kDebugMode) debugPrint('[FrequentStores] error: $e');
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

class _ContentColumn extends StatelessWidget {
  final List<FrequentStoreEntity> stores;
  const _ContentColumn({required this.stores});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('frequent-stores-content'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: '자주 찾는 매장'),
        SizedBox(
          height: _kCardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemCount: stores.length,
            itemBuilder: (context, i) {
              final entity = stores[i];
              return FrequentStoreCard(
                entity: entity,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StoreMenuPage(store: entity.store!),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _LoadingColumn extends StatelessWidget {
  const _LoadingColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('frequent-stores-loading'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: '자주 찾는 매장'),
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

class FrequentStoreCard extends StatelessWidget {
  final FrequentStoreEntity entity;
  final VoidCallback onTap;

  const FrequentStoreCard({
    super.key,
    required this.entity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.4;
    final store = entity.store!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width.clamp(140.0, 180.0),
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
                  child: _StoreImage(
                    url: store.imageUrl,
                    width: double.infinity,
                    height: _kImageHeight,
                  ),
                ),
                if (entity.visitCount > 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _CountBadge(count: entity.visitCount),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GradeBadge(
                    grade: store.grade,
                    reviewCount: store.reviewCount,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entity.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHeading,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '최근 ${entity.visitCount}회 방문',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
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

class _StoreImage extends StatelessWidget {
  final String url;
  final double width;
  final double height;

  const _StoreImage({
    required this.url,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder();
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (_, _) => _shimmer(),
      errorWidget: (_, _, _) => _placeholder(),
    );
  }

  Widget _shimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceElevated,
      child: Container(width: width, height: height, color: AppColors.surface),
    );
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surface,
      alignment: Alignment.center,
      child: const Icon(
        Icons.storefront_outlined,
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
