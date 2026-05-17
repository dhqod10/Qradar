import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/unauthenticated_exception.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/sub_category_entity.dart';
import 'package:qradar/presentation/common/favorite_login_required_dialog.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/auth/login_page.dart';
import 'package:qradar/presentation/customer/cart/cart_page.dart';
import 'package:qradar/presentation/customer/cart/providers/cart_providers.dart';
import 'package:qradar/presentation/customer/order/favorites/providers/favorites_providers.dart';
import 'package:qradar/presentation/customer/order/menu/menu_item_detail_page.dart';
import 'package:qradar/presentation/customer/order/store/providers/store_menu_providers.dart';
import 'package:qradar/presentation/customer/order/store/widgets/main_category_tabs.dart';
import 'package:qradar/presentation/customer/order/store/widgets/menu_item_card.dart';
import 'package:qradar/presentation/customer/order/store/widgets/store_menu_header.dart';
import 'package:qradar/presentation/customer/order/store/widgets/sub_category_chips.dart';
import 'package:shimmer/shimmer.dart';

class StoreMenuPage extends ConsumerWidget {
  const StoreMenuPage({super.key, required this.store});

  final StoreEntity store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeId = store.id;
    final menuAsync = ref.watch(storeMenuItemsProvider(storeId));
    final selectedMain = ref.watch(selectedMainCategoryProvider);
    final selectedSubId = ref.watch(selectedSubCategoryIdProvider);
    final availableMains =
        ref.watch(storeAvailableMainCategoriesProvider(storeId));
    final availableSubIds =
        ref.watch(storeAvailableSubCategoryIdsProvider(storeId));
    final filtered = ref.watch(filteredMenuItemsProvider(storeId));
    final subCategoriesAsync = selectedMain == null
        ? const AsyncValue<List<SubCategoryEntity>>.data([])
        : ref.watch(subCategoriesForStoreProvider(
            (storeId: storeId, mainCategoryId: selectedMain),
          ));
    final filteredSubCategories = subCategoriesAsync.value
            ?.where((sc) => availableSubIds.contains(sc.id))
            .toList(growable: false) ??
        const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: menuAsync.when(
        loading: () => _LoadingShimmer(store: store),
        error: (err, _) => _ErrorView(
          store: store,
          message: err.toString(),
          onRetry: () => ref.invalidate(storeMenuItemsProvider(storeId)),
        ),
        data: (allItems) {
          if (allItems.isEmpty) {
            return _EmptyView(store: store);
          }
          return CustomScrollView(
            slivers: [
              _AppBar(store: store),
              SliverPersistentHeader(
                pinned: true,
                delegate: _CategoryHeaderDelegate(
                  showSubChips: filteredSubCategories.isNotEmpty,
                  child: Column(
                    children: [
                      MainCategoryTabs(
                        selected: selectedMain,
                        availableCategories: availableMains,
                        onSelect: (cat) => ref
                            .read(selectedMainCategoryProvider.notifier)
                            .select(cat),
                      ),
                      if (filteredSubCategories.isNotEmpty)
                        SubCategoryChips(
                          subCategories: filteredSubCategories,
                          selectedId: selectedSubId,
                          onSelect: (id) => ref
                              .read(selectedSubCategoryIdProvider.notifier)
                              .select(id),
                        ),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _FilteredEmpty(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      // 0.78 이면 좁은 화면(예: iPhone 13 mini 너비) 에서
                      // 카드 내부(이미지 정사각형 + 이름 + 가격) 높이를 못 담아
                      // bottom overflow ~14px 발생. 0.7 로 안전 마진 확보.
                      childAspectRatio: 0.7,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final item = filtered[i];
                        return MenuItemCard(
                          menuItem: item,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MenuItemDetailPage(
                                storeId: storeId,
                                storeName: store.name,
                                menuItemId: item.id,
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AppBar extends ConsumerWidget {
  const _AppBar({required this.store});
  final StoreEntity store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartItemCountProvider);
    final favoriteIds =
        ref.watch(favoriteStoreIdsProvider).asData?.value ?? const <String>{};
    final isFavorite = favoriteIds.contains(store.id);
    return SliverAppBar(
      pinned: true,
      expandedHeight: 200,
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
      title: Text(
        store.name,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textHeading,
        ),
      ),
      centerTitle: false,
      actions: [
        _CartIconButton(count: cartCount),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: StoreMenuHeader(
          store: store,
          isFavorite: isFavorite,
          onFavoriteTap: () => _onToggleStoreFavorite(context, ref, store.id),
        ),
      ),
    );
  }
}

/// 매장 즐겨찾기 토글 흐름.
///
/// 비로그인 → 다이얼로그 → "로그인하기" 시 LoginPage push.
/// 로그인 → toggleFavoriteStoreUseCase await → stream 으로 자동 갱신.
Future<void> _onToggleStoreFavorite(
  BuildContext context,
  WidgetRef ref,
  String storeId,
) async {
  final user = ref.read(authProvider).asData?.value;
  if (user == null) {
    final wantsLogin = await showFavoriteLoginRequiredDialog(context);
    if (!context.mounted) return;
    if (wantsLogin) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      );
    }
    return;
  }

  try {
    await ref.read(toggleFavoriteStoreUseCaseProvider).call(storeId);
  } on UnauthenticatedException {
    if (!context.mounted) return;
    final wantsLogin = await showFavoriteLoginRequiredDialog(context);
    if (!context.mounted) return;
    if (wantsLogin) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      );
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('즐겨찾기 저장에 실패했어요'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _CartIconButton extends StatelessWidget {
  const _CartIconButton({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const CartPage()),
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.shopping_cart_outlined,
            color: AppColors.textHeading,
          ),
          if (count > 0)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: AppColors.background,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimary,
                    height: 1.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  _CategoryHeaderDelegate({required this.child, required this.showSubChips});

  final Widget child;
  final bool showSubChips;

  double get _height => showSubChips ? 48.0 + 56.0 : 48.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: AppColors.background, child: child);
  }

  @override
  double get maxExtent => _height;

  @override
  double get minExtent => _height;

  @override
  bool shouldRebuild(covariant _CategoryHeaderDelegate oldDelegate) {
    return oldDelegate.showSubChips != showSubChips ||
        oldDelegate.child != child;
  }
}

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer({required this.store});
  final StoreEntity store;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _AppBar(store: store),
        SliverToBoxAdapter(
          child: Container(
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, _) => Shimmer.fromColors(
                baseColor: AppColors.surface,
                highlightColor: AppColors.surfaceElevated,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              childCount: 6,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.store,
    required this.message,
    required this.onRetry,
  });
  final StoreEntity store;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _AppBar(store: store),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '메뉴를 불러오지 못했어요',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHeading,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                    ),
                    child: const Text('재시도'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.store});
  final StoreEntity store;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _AppBar(store: store),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_cafe_outlined,
                  color: AppColors.textMuted,
                  size: 56,
                ),
                const SizedBox(height: 12),
                const Text(
                  '등록된 메뉴가 없어요',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeading,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('뒤로가기'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilteredEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          '해당 분류에 메뉴가 없어요',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

