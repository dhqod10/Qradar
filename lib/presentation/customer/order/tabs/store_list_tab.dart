import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/customer/home/widgets/store_card.dart';
import 'package:qradar/presentation/customer/order/providers/order_providers.dart';
import 'package:qradar/presentation/customer/order/store/store_menu_page.dart';
import 'package:qradar/presentation/customer/order/widgets/grade_filter_chips.dart';
import 'package:qradar/presentation/customer/order/widgets/order_search_bar.dart';
import 'package:shimmer/shimmer.dart';

/// 주문 화면 "매장 검색" 탭 — 검색창 + 등급 필터 + 거리순 매장 리스트.
class StoreListTab extends ConsumerWidget {
  const StoreListTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = ref.watch(orderStoresProvider);
    final base = ref.watch(orderBaseStoresProvider);
    final query = ref.watch(orderSearchQueryProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: OrderSearchBar(),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: GradeFilterChips(),
          ),
          _ResultCount(asyncStores: filtered),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceElevated,
              onRefresh: () async {
                ref.invalidate(orderBaseStoresProvider);
                await ref.read(orderBaseStoresProvider.future);
              },
              child: filtered.when(
                data: (stores) => _ListContent(
                  stores: stores,
                  query: query,
                  baseCount: base.asData?.value.length ?? 0,
                ),
                loading: () => const _ListLoading(),
                error: (err, _) => _ListError(message: '$err'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCount extends StatelessWidget {
  final AsyncValue<List<StoreEntity>> asyncStores;
  const _ResultCount({required this.asyncStores});

  @override
  Widget build(BuildContext context) {
    final count = asyncStores.maybeWhen(
      data: (list) => list.length,
      orElse: () => null,
    );
    if (count == null) {
      return const SizedBox(height: 20);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '검색 결과 $count곳',
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

class _ListContent extends StatelessWidget {
  final List<StoreEntity> stores;
  final String query;
  final int baseCount;

  const _ListContent({
    required this.stores,
    required this.query,
    required this.baseCount,
  });

  @override
  Widget build(BuildContext context) {
    if (stores.isEmpty) {
      return _EmptyList(query: query, baseCount: baseCount);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: stores.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => RecommendedStoreCard(
        store: stores[i],
        onTap: () => _openStoreMenu(context, stores[i]),
      ),
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

class _ListLoading extends StatelessWidget {
  const _ListLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Shimmer.fromColors(
        baseColor: AppColors.surface,
        highlightColor: AppColors.surfaceElevated,
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _ListError extends ConsumerWidget {
  final String message;
  const _ListError({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline, size: 40, color: AppColors.error),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            '매장 정보를 불러올 수 없어요',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: () => ref.invalidate(orderBaseStoresProvider),
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
        ),
      ],
    );
  }
}

/// 빈 상태 2단 분기: base 0 ↔ 필터 후 0.
class _EmptyList extends StatelessWidget {
  final String query;
  final int baseCount;

  const _EmptyList({required this.query, required this.baseCount});

  @override
  Widget build(BuildContext context) {
    final trimmed = query.trim();
    final IconData icon;
    final String title;
    final String? subtitle;

    if (baseCount == 0) {
      icon = Icons.storefront_outlined;
      title = '주변 10km 이내에 매장이 없어요';
      subtitle = '위치를 이동해서 다시 시도해보세요';
    } else if (trimmed.isNotEmpty) {
      icon = Icons.search_off_rounded;
      title = "'$trimmed'에 해당하는 매장이 없어요";
      subtitle = null;
    } else {
      icon = Icons.search_off_rounded;
      title = '선택한 등급에 해당하는 매장이 없어요';
      subtitle = null;
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 40, color: AppColors.textMuted),
        const SizedBox(height: 12),
        Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textBody,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Center(
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
