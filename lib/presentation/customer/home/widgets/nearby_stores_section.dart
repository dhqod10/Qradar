import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/customer/home/providers/home_providers.dart';
import 'package:qradar/presentation/customer/home/widgets/section_title.dart';
import 'package:qradar/presentation/customer/home/widgets/store_card.dart';
import 'package:qradar/presentation/customer/order/store/store_menu_page.dart';
import 'package:shimmer/shimmer.dart';

class NearbyStoresSection extends ConsumerWidget {
  const NearbyStoresSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = ref.watch(nearbyStoresProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: '주변매장'),
        SizedBox(
          height: 200,
          child: stores.when(
            data: (list) {
              if (list.isEmpty) return const _EmptyNearby();
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final store = list[i];
                  return NearbyStoreCard(
                    store: store,
                    onTap: () => _openStoreMenu(context, store),
                  );
                },
              );
            },
            loading: () => const _NearbyLoading(),
            error: (e, _) => _NearbyError(message: '$e'),
          ),
        ),
      ],
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

class _NearbyLoading extends StatelessWidget {
  const _NearbyLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemCount: 3,
      itemBuilder: (_, _) {
        return Shimmer.fromColors(
          baseColor: AppColors.surface,
          highlightColor: AppColors.surfaceElevated,
          child: Container(
            width: 160,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }
}

class _NearbyError extends ConsumerWidget {
  final String message;
  const _NearbyError({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 32, color: AppColors.error),
            const SizedBox(height: 8),
            const Text(
              '주변매장을 불러올 수 없어요',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textBody,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.invalidate(nearbyStoresProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '다시 시도',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNearby extends StatelessWidget {
  const _EmptyNearby();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.place_outlined, size: 40, color: AppColors.textMuted),
          SizedBox(height: 8),
          Text(
            '주변에 매장이 없습니다',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textBody,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
