import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/unauthenticated_exception.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/store_menu_visibility.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/sub_category_entity.dart';
import 'package:qradar/presentation/common/favorite_login_required_dialog.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/auth/login_page.dart';
import 'package:qradar/presentation/customer/cart/cart_page.dart';
import 'package:qradar/presentation/customer/cart/providers/cart_providers.dart';
import 'package:qradar/presentation/customer/order/favorites/providers/favorites_providers.dart';
import 'package:qradar/presentation/customer/order/menu/menu_item_detail_page.dart';
import 'package:qradar/presentation/customer/order/store/providers/main_category_providers.dart';
import 'package:qradar/presentation/customer/order/store/providers/store_menu_providers.dart';
import 'package:qradar/presentation/customer/review/providers/store_review_providers.dart';
import 'package:qradar/presentation/customer/order/store/widgets/main_category_tabs.dart';
import 'package:qradar/presentation/customer/order/store/widgets/menu_item_card.dart';
import 'package:qradar/presentation/customer/order/store/widgets/store_menu_header.dart';
import 'package:qradar/presentation/customer/order/store/widgets/sub_category_chips.dart';
import 'package:shimmer/shimmer.dart';

/// 지금 열려 있는 `StoreMenuPage` 들의 storeId (열린 순서). 상세의 `_DeletedView` 가
/// "아래 스택이 그 매장 화면인가" 를 판단하는 데 쓴다 (맞으면 pop, 아니면 매장 화면으로 교체).
final List<String> openStoreMenuStoreIds = <String>[];

class StoreMenuPage extends ConsumerStatefulWidget {
  const StoreMenuPage({
    super.key,
    required this.store,
    this.initialMainCategoryCode,
    this.highlightMenuItemId,
    this.autoOpenMenuItemId,
    this.seamlessEntry = false,
  });

  final StoreEntity store;

  /// 홈 검색에서 진입할 때 미리 선택할 메인 카테고리 id. null = 현행 동작.
  /// 매장에 해당 카테고리 메뉴가 없으면 `filteredMenuItemsProvider` 가 선택을 무시한다 (기존 폴백).
  final String? initialMainCategoryCode;

  /// 홈 검색에서 찾은 메뉴 id. 있으면 그 카드에 테두리 + 상단 안내 띠를 그린다 (스크롤 없음).
  /// 목록에 없으면 `이 매장에서는 판매하지 않는 메뉴일 수 있어요` 띠.
  final String? highlightMenuItemId;

  /// 검색에서 메뉴 행을 눌러 들어온 경우: 메뉴 목록이 확정된 뒤 그 메뉴가 **이 화면 목록에 있으면**(F5 단일 판정)
  /// 그 위에 상세를 한 번만 올린다. 없으면 올리지 않고 안내 띠가 알린다. 뒤로가기로 나오면 다시 열리지 않는다.
  final String? autoOpenMenuItemId;

  /// 검색 메뉴 행 탭으로 연 경우 true: 상세가 덮을 때까지 아무것도 그리지 않는다 ([SeamlessStoreMenuRoute] 와 함께 쓴다).
  final bool seamlessEntry;

  @override
  ConsumerState<StoreMenuPage> createState() => _StoreMenuPageState();
}

class _StoreMenuPageState extends ConsumerState<StoreMenuPage> {
  /// 이 화면이 `selectedMainCategoryProvider` 를 바꿨는지 (바꿨다면 나갈 때 되돌려 다른 매장으로 새지 않게).
  bool _appliedInitialCategory = false;
  bool _highlightDismissed = false;

  /// 자동 상세 push 는 딱 한 번 (뒤로 나온 뒤 재진입 금지).
  bool _autoOpened = false;

  // ── 전환 (seamlessEntry) ──
  late bool _revealed = !widget.seamlessEntry;
  bool _fadeIn = false;
  bool _showScrim = false;
  Timer? _scrimTimer;
  Timer? _giveUpTimer;
  Animation<double>? _secondary;

  /// 매장 화면을 드러낸다. 드러내는 시점: 상세가 위를 완전히 덮은 뒤 / 상세를 올리지 않는 분기(페이드) / 3초 초과(폴백).
  void _reveal({bool fade = false}) {
    if (!mounted || _revealed) return;
    _scrimTimer?.cancel();
    _giveUpTimer?.cancel();
    setState(() {
      _fadeIn = fade;
      _revealed = true;
    });
  }

  void _onSecondaryStatus(AnimationStatus status) {
    // 상세가 완전히 덮었거나(completed), 사용자가 상세에서 뒤로 가기 시작(reverse)하면 드러낸다.
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.reverse) {
      _reveal();
    }
  }

  late final ProviderContainer _container;

  StoreEntity get store => widget.store;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    openStoreMenuStoreIds.add(widget.store.id);
    if (widget.seamlessEntry) {
      // 250ms 안에 끝나면 아무것도 안 보인다. 넘으면 검색 화면 위에 스크림 + 인디케이터.
      _scrimTimer = Timer(const Duration(milliseconds: 250), () {
        if (mounted && !_revealed) setState(() => _showScrim = true);
      });
      // 3초가 넘으면 중단하고 기존 매장 화면 상태(shimmer / 에러)를 그대로 보여 준다.
      _giveUpTimer = Timer(const Duration(seconds: 3), _reveal);
    }
    final code = widget.initialMainCategoryCode;
    if (code != null) {
      // 위젯 빌드 중 provider 수정은 금지 -> 첫 프레임 직후 적용. 첫 프레임은 메뉴 stream 로딩(shimmer) 구간이다.
      Future.microtask(() {
        if (!mounted) return;
        _appliedInitialCategory = true;
        _container.read(selectedMainCategoryProvider.notifier).select(code);
        // 같은 메인이 이미 선택돼 있으면 select 가 early return 해 서브 선택이 남는다 -> 직접 비운다.
        _container.read(selectedSubCategoryIdProvider.notifier).clear();
      });
    }
  }

  @override
  void dispose() {
    openStoreMenuStoreIds.remove(widget.store.id);
    _scrimTimer?.cancel();
    _giveUpTimer?.cancel();
    _secondary?.removeStatusListener(_onSecondaryStatus);
    if (_appliedInitialCategory) {
      final container = _container;
      Future.microtask(() {
        try {
          container.read(selectedMainCategoryProvider.notifier).select(null);
        } on StateError {
          // 앱/스코프 종료 중 container 가 이미 dispose 됨 — 되돌릴 상태가 없다.
        }
      });
    }
    super.dispose();
  }

  /// 목록 확정 후 1회: 검색한 메뉴가 이 화면 목록에 있으면 상세를 그 위에 올린다 (spec §15.8).
  /// 빌드 중 Navigator 호출은 금지이므로 다음 프레임에 올린다.
  void _maybeAutoOpen(
    List<MenuItemEntity> allItems,
    Set<String>? activeIds,
    Set<String> excludedIds,
  ) {
    final id = widget.autoOpenMenuItemId;
    if (id == null || _autoOpened || activeIds == null) return;
    _autoOpened = true; // 판정은 한 번 — 있든 없든 다시 시도하지 않는다
    final found = allItems.any(
      (m) =>
          m.id == id &&
          isMenuShownOnStoreScreen(
            visible: m.visible,
            mainCategoryCode: m.mainCategoryCode,
            activeCategoryIds: activeIds,
            excludedCategoryIds: excludedIds,
          ),
    );
    if (!found) {
      // 상세를 올리지 않는 분기 — 매장 화면을 페이드 인 + 안내 띠.
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(fade: true));
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 상세가 위를 덮는 애니메이션이 끝나면 비로소 매장 화면을 그린다.
      _secondary = ModalRoute.of(context)?.secondaryAnimation
        ?..addStatusListener(_onSecondaryStatus);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MenuItemDetailPage(
            storeId: store.id,
            storeName: store.name,
            menuItemId: id,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final storeId = store.id;
    // 평가 직후 CF 가 갱신한 등급·건수를 헤더 배지에 즉시 반영한다.
    // 진입 시점 스냅샷만 쓰면 평가를 남겨도 `미평가` 로 남아 사용자가
    // "반영이 안 됐다" 고 오인한다.
    final liveStore =
        ref.watch(watchedStoreProvider(storeId)).asData?.value ?? store;
    final menuAsync = ref.watch(storeMenuItemsProvider(storeId));
    final selectedMain = ref.watch(selectedMainCategoryProvider);
    final selectedSubId = ref.watch(selectedSubCategoryIdProvider);
    final availableMains = ref.watch(
      storeAvailableMainCategoriesProvider(storeId),
    );
    final availableSubIds = ref.watch(
      storeAvailableSubCategoryIdsProvider(storeId),
    );
    final filtered = ref.watch(filteredMenuItemsProvider(storeId));
    // 점주가 끈 카테고리. 확정 전(loading)에는 메뉴를 그리지 않는다 (숨길 메뉴가 잠깐 보이는 플리커 방지).
    final excludedAsync = ref.watch(storeExcludedMainCategoriesProvider(storeId));
    final excludedIds = excludedAsync.asData?.value ?? const <String>{};
    final activeCategoryIds = ref
        .watch(mainCategoriesActiveProvider)
        .asData
        ?.value
        .map((c) => c.id)
        .toSet();
    final subCategoriesAsync = selectedMain == null
        ? const AsyncValue<List<SubCategoryEntity>>.data([])
        : ref.watch(
            subCategoriesForStoreProvider((
              storeId: storeId,
              mainCategoryId: selectedMain,
            )),
          );
    final filteredSubCategories =
        subCategoriesAsync.value
            ?.where((sc) => availableSubIds.contains(sc.id))
            .toList(growable: false) ??
        const [];

    final scaffold = Scaffold(
      backgroundColor: AppColors.background,
      body: menuAsync.when(
        loading: () => _LoadingShimmer(store: liveStore),
        error: (err, _) => _ErrorView(
          store: liveStore,
          onRetry: () => ref.invalidate(storeMenuItemsProvider(storeId)),
        ),
        data: (allItems) {
          if (excludedAsync.isLoading && !excludedAsync.hasValue) {
            return _LoadingShimmer(store: liveStore);
          }
          if (excludedAsync.hasError && !excludedAsync.hasValue) {
            return _ErrorView(
              store: liveStore,
              onRetry: () =>
                  ref.invalidate(watchedStoreProvider(storeId)),
            );
          }
          _maybeAutoOpen(allItems, activeCategoryIds, excludedIds);
          if (allItems.isEmpty) {
            return _EmptyView(store: liveStore);
          }
          // 메뉴는 있으나 점주가 모든 카테고리를 꺼 가용 카테고리가 0 — 중립 문구 (내부 사정 비노출).
          // availableMains 는 active 스트림 미도달 시 전체를 보수적으로 통과시키므로, 도달 후에만 판정한다.
          if (activeCategoryIds != null &&
              excludedIds.isNotEmpty &&
              availableMains.isEmpty) {
            return _EmptyView(
              store: liveStore,
              title: '지금은 주문할 수 있는 메뉴가 없어요',
              subtitle: '매장에서 메뉴 준비 중이에요. 다른 매장을 둘러보세요.',
            );
          }
          return CustomScrollView(
            slivers: [
              _AppBar(store: store),
              if (liveStore.temporaryClosed)
                const SliverToBoxAdapter(child: _TemporaryClosedBanner()),
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
              if (widget.highlightMenuItemId != null &&
                  !_highlightDismissed &&
                  activeCategoryIds != null)
                SliverToBoxAdapter(
                  child: _SearchedMenuBand(
                    // "이 매장이 이 메뉴를 파는가" 는 카테고리 탭·서브 필터와 무관하다 -> 머지 목록 전체(allItems)
                    // 에서 F5 단일 판정으로 찾는다. 현재 탭에 안 보여도 오경보를 내지 않는다.
                    foundName: allItems
                        .where(
                          (m) =>
                              m.id == widget.highlightMenuItemId &&
                              isMenuShownOnStoreScreen(
                                visible: m.visible,
                                mainCategoryCode: m.mainCategoryCode,
                                activeCategoryIds: activeCategoryIds,
                                excludedCategoryIds: excludedIds,
                              ),
                        )
                        .map((m) => m.name)
                        .firstOrNull,
                    onClose: () => setState(() => _highlightDismissed = true),
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
                    delegate: SliverChildBuilderDelegate((_, i) {
                      final item = filtered[i];
                      return MenuItemCard(
                        menuItem: item,
                        highlighted:
                            !_highlightDismissed &&
                            item.id == widget.highlightMenuItemId,
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
                    }, childCount: filtered.length),
                  ),
                ),
            ],
          );
        },
      ),
    );
    return _wrapSeamless(scaffold);
  }

  /// 전환 단계 (design §13-4). 검색의 메뉴 행 탭으로 열린 경우([StoreMenuPage.seamlessEntry])에만 쓴다:
  /// 이 화면은 상세가 위를 덮을 때까지 **아무것도 그리지 않아** 검색 화면이 그대로 보이게 한다.
  /// (목록 확정 전 shimmer 가 비치거나 슬라이드가 두 번 보이는 것을 막는다.)
  Widget _wrapSeamless(Widget scaffold) {
    if (!widget.seamlessEntry) return scaffold;
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedOpacity(
          opacity: _revealed ? 1 : 0,
          duration: _fadeIn ? const Duration(milliseconds: 200) : Duration.zero,
          child: IgnorePointer(ignoring: !_revealed, child: scaffold),
        ),
        if (!_revealed && _showScrim)
          Semantics(
            liveRegion: true,
            label: '메뉴로 이동하고 있어요',
            child: ColoredBox(
              color: AppColors.background.withValues(alpha: 0.6),
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 검색 화면 위에 "보이지 않게" 깔리는 매장 화면 라우트. 정상 경로에서 보이는 슬라이드는 상세 하나뿐이다.
/// - 앞으로 가는 전환 0ms, `opaque: false` (아래 검색 화면이 계속 그려진다)
/// - 되돌아올 때는 표준 전환 (플랫폼 기본: `MaterialRouteTransitionMixin` 이므로 iOS 스와이프 백 포함)
class SeamlessStoreMenuRoute<T> extends PageRoute<T>
    with MaterialRouteTransitionMixin<T> {
  SeamlessStoreMenuRoute({required this.builder});

  /// `MaterialPageRoute` 는 생성자에서 `opaque` 를 assert 하므로 상속할 수 없다 — 같은 플랫폼 전환
  /// (`MaterialRouteTransitionMixin`: iOS 스와이프 백 포함)을 쓰는 라우트를 직접 정의한다.
  final WidgetBuilder builder;

  @override
  Widget buildContent(BuildContext context) => builder(context);

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  @override
  bool get opaque => false;
}

/// 임시 휴업 안내 배너 (temporary_closed_gate design §1-2).
class _TemporaryClosedBanner extends StatelessWidget {
  const _TemporaryClosedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.storefront_outlined, size: 18, color: AppColors.error),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '지금은 임시 휴업중이에요',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHeading,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '메뉴는 볼 수 있지만 주문은 영업을 다시 시작한 뒤에 할 수 있어요.',
                  style: TextStyle(fontSize: 12, color: AppColors.textBody),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 검색에서 넘어온 메뉴 안내 띠. 목록에서 찾으면 `검색한 메뉴  {이름}`, 못 찾으면 판매하지 않을 수 있다는 정직한 안내.
class _SearchedMenuBand extends StatelessWidget {
  const _SearchedMenuBand({required this.foundName, required this.onClose});

  final String? foundName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final found = foundName != null;
    final text = found ? '검색한 메뉴  $foundName' : '이 매장에서는 판매하지 않는 메뉴일 수 있어요';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          color: found
              ? AppColors.primaryBright.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              found ? Icons.search_rounded : Icons.info_outline_rounded,
              size: 16,
              color: found ? AppColors.primary : AppColors.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBody,
                ),
              ),
            ),
            IconButton(
              tooltip: '닫기',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
              padding: EdgeInsets.zero,
              onPressed: onClose,
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
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
    // 헤더 배지는 평가 반영(CF 집계)을 즉시 보여야 하므로 구독값을 쓴다.
    final liveStore =
        ref.watch(watchedStoreProvider(store.id)).asData?.value ?? store;
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
      actions: [_CartIconButton(count: cartCount)],
      flexibleSpace: FlexibleSpaceBar(
        background: StoreMenuHeader(
          store: liveStore,
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
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const LoginPage()));
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
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const LoginPage()));
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
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const CartPage())),
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
                  border: Border.all(color: AppColors.background, width: 1.5),
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
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
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
              border: Border(bottom: BorderSide(color: AppColors.border)),
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
  const _ErrorView({required this.store, required this.onRetry});
  final StoreEntity store;
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
                  const SizedBox(height: 6),
                  const Text(
                    '잠시 후 다시 시도해 주세요',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
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
  const _EmptyView({
    required this.store,
    this.title = '등록된 메뉴가 없어요',
    this.subtitle,
  });
  final StoreEntity store;
  final String title;
  final String? subtitle;

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
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeading,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
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
