import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/common/store_list_states.dart';
import 'package:qradar/presentation/customer/home/providers/home_providers.dart';
import 'package:qradar/presentation/customer/home/providers/recommended_stores_providers.dart';
import 'package:qradar/presentation/customer/home/widgets/category_filter_section.dart';
import 'package:qradar/presentation/customer/home/widgets/store_card.dart';
import 'package:qradar/presentation/customer/order/store/store_menu_page.dart';
import 'package:shimmer/shimmer.dart';

/// `맞춤 추천` 전체 목록. 홈과 **같은 provider/같은 카테고리 선택**을 공유한다 (읽기 추가 0).
class RecommendedStoresPage extends ConsumerWidget {
  const RecommendedStoresPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = ref.watch(recommendedStoresFullProvider);
    final sort = ref.watch(recommendedSortProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.textHeading,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          '맞춤 추천',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceElevated,
        onRefresh: () async {
          ref.invalidate(storeSnapshotProvider);
          await ref
              .read(storeSnapshotProvider.future)
              .catchError((_) => <StoreEntity>[]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 16, bottom: 16),
                child: CategoryFilterSection(),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SortBarDelegate(
                count: stores.asData?.value.length,
                sort: sort,
                onSelect: (s) =>
                    ref.read(recommendedSortProvider.notifier).select(s),
              ),
            ),
            ..._body(context, ref, stores),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<StoreEntity>> stores,
  ) {
    // hasValue 우선 — 당겨서 새로고침 중에도 직전 목록을 유지한다.
    if (stores.hasValue) {
      final list = stores.requireValue;
      if (list.isEmpty) {
        return const [
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: RecommendedEmptyState()),
          ),
        ];
      }
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding: EdgeInsets.only(bottom: i == list.length - 1 ? 0 : 12),
                child: RecommendedStoreCard(
                  store: list[i],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StoreMenuPage(store: list[i]),
                    ),
                  ),
                ),
              ),
              childCount: list.length,
            ),
          ),
        ),
      ];
    }
    if (stores.hasError) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: StoreListError(
              onRetry: () => ref.invalidate(storeSnapshotProvider),
            ),
          ),
        ),
      ];
    }
    return const [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 32),
        sliver: SliverToBoxAdapter(child: StoreListSkeleton(rows: 5)),
      ),
    ];
  }
}

/// 고정 정렬 바 — 건수(데이터 있을 때만) + 거리순/등급순 토글.
class _SortBarDelegate extends SliverPersistentHeaderDelegate {
  _SortBarDelegate({
    required this.count,
    required this.sort,
    required this.onSelect,
  });

  final int? count;
  final RecommendedSort sort;
  final ValueChanged<RecommendedSort> onSelect;

  @override
  double get maxExtent => 52;

  @override
  double get minExtent => 52;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: count != null
                ? Text(
                    '전체 $count곳',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textBody,
                    ),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Shimmer.fromColors(
                      baseColor: AppColors.surface,
                      highlightColor: AppColors.surfaceElevated,
                      child: Container(
                        width: 64,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
          ),
          _SortToggle(sort: sort, onSelect: onSelect),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SortBarDelegate old) =>
      old.count != count || old.sort != sort;
}

/// 외곽 32 / 히트박스 44 — 세그먼트가 44 높이 제스처 영역이고 시각 pill 만 32 로 그린다.
class _SortToggle extends StatelessWidget {
  const _SortToggle({required this.sort, required this.onSelect});
  final RecommendedSort sort;
  final ValueChanged<RecommendedSort> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 152,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
          ),
          Row(
            children: [
              _Segment(
                label: '거리순',
                selected: sort == RecommendedSort.distance,
                onTap: () => onSelect(RecommendedSort.distance),
              ),
              _Segment(
                label: '등급순',
                selected: sort == RecommendedSort.grade,
                onTap: () => onSelect(RecommendedSort.grade),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: selected,
        button: true,
        label: '$label 정렬${selected ? ', 선택됨' : ''}',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? AppColors.onPrimary : AppColors.textBody,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
