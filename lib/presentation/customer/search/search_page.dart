import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/constants/grade_thresholds.dart';
import 'package:qradar/core/errors/permission_denied_exception.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/menu_search_hit_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/usecases/search_stores_use_case.dart';
import 'package:qradar/presentation/common/store_list_states.dart';
import 'package:qradar/presentation/customer/auth/login_page.dart';
import 'package:qradar/presentation/customer/home/providers/home_providers.dart';
import 'package:qradar/presentation/customer/home/providers/recommendation_providers.dart';
import 'package:qradar/presentation/customer/home/widgets/section_title.dart';
import 'package:qradar/presentation/customer/home/widgets/store_card.dart';
import 'package:qradar/presentation/customer/order/store/store_menu_page.dart';
import 'package:qradar/presentation/customer/search/providers/search_providers.dart';
import 'package:qradar/presentation/customer/search/widgets/menu_search_result_tile.dart';
import 'package:qradar/presentation/customer/search/widgets/recent_search_list.dart';
import 'package:qradar/presentation/customer/search/widgets/search_input_bar.dart';
import 'package:qradar/presentation/customer/search/widgets/search_state_widgets.dart';

/// 홈 검색 — 매장 섹션 -> 메뉴 섹션을 한 세로 목록에 이어 붙인다.
/// 모든 상태는 [resolveSearchView] 한 함수가 결정하고, 이 화면은 렌더만 한다.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: GradeThresholds.searchDebounceMs),
      () {
        if (!mounted) return;
        ref.read(searchQueryProvider.notifier).set(raw);
      },
    );
  }

  /// `×` — debounce 를 기다리지 않고 즉시 비우며 포커스를 유지한다.
  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(searchQueryProvider.notifier).clear();
    _focus.requestFocus();
  }

  /// 키보드 `검색` — 키보드를 내리고 현재 질의를 기록 (debounce 우회).
  void _submit(String raw) {
    _debounce?.cancel();
    ref.read(searchQueryProvider.notifier).set(raw);
    ref.read(recentSearchesProvider.notifier).record(raw);
    _focus.unfocus();
  }

  /// 최근 검색어 탭 — 입력창에 채우고 재검색 (키보드 유지), 맨 앞으로.
  void _applyRecent(String text) {
    _debounce?.cancel();
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    ref.read(searchQueryProvider.notifier).set(text);
    ref.read(recentSearchesProvider.notifier).record(text);
  }

  void _openStore(StoreEntity store, {MenuSearchHitEntity? hit}) {
    ref
        .read(recentSearchesProvider.notifier)
        .record(ref.read(searchQueryProvider));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoreMenuPage(
          store: store,
          initialMainCategoryCode: hit?.mainCategoryCode,
          highlightMenuItemId: hit?.menuItemId,
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(storeSnapshotProvider);
    ref.invalidate(menuSearchIndexProvider);
    try {
      await ref.read(storeSnapshotProvider.future);
    } catch (_) {
      // 에러는 화면의 에러 블록이 보여준다.
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(searchViewModelProvider);
    final rawQuery = ref.watch(searchQueryProvider);
    final storeAsync = ref.watch(searchStoreResultsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.textHeading,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 20),
          child: SearchInputBar(
            controller: _controller,
            focusNode: _focus,
            onChanged: _onChanged,
            onClear: _clear,
            onSubmitted: _submit,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceElevated,
        onRefresh: _refresh,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: _children(vm, rawQuery, storeAsync.error),
        ),
      ),
    );
  }

  List<Widget> _children(
    SearchViewModel vm,
    String rawQuery,
    Object? storeError,
  ) {
    final q = rawQuery;
    switch (vm.view) {
      case SearchView.initial:
        final recents = ref.watch(recentSearchesProvider);
        if (recents.isEmpty) return const [SearchInitialHint()];
        return [
          RecentSearchList(
            items: recents,
            onTap: _applyRecent,
            onRemove: ref.read(recentSearchesProvider.notifier).remove,
            onClear: ref.read(recentSearchesProvider.notifier).clear,
          ),
        ];

      case SearchView.shortLoading:
      case SearchView.s1StoreLoading:
        return [
          const StoreListSkeleton(),
          const SizedBox(height: 24),
          if (vm.view == SearchView.s1StoreLoading) ...[
            const MenuSectionHeader(loading: true),
            const MenuSkeleton(),
          ] else
            const MenuSectionHeader(),
        ];

      case SearchView.shortError:
      case SearchView.s2StoreError:
        return [_storeErrorBlock(storeError)];

      case SearchView.shortWithStores:
        return [
          ..._storeSection(vm, q),
          const SizedBox(height: 24),
          const MenuSectionHeader(),
          const MenuMinLengthPlate(),
        ];

      case SearchView.shortNoStores:
        return [
          const SizedBox(height: 48),
          Center(
            child: Text(
              "'${_echo(q)}' 와 일치하는 매장이 없어요",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textHeading,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              '메뉴는 두 글자부터 찾아요',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
        ];

      case SearchView.s3StoresMenuLoading:
        return [
          ..._storeSection(vm, q),
          const SizedBox(height: 24),
          const MenuSectionHeader(loading: true),
          const MenuSkeleton(),
        ];

      case SearchView.s4StoresMenuData:
        return [
          ..._storeSection(vm, q),
          const SizedBox(height: 24),
          ..._menuSection(vm),
        ];

      case SearchView.s5StoresMenuEmpty:
        return [
          ..._storeSection(vm, q),
          const SizedBox(height: 12),
          SearchOneLiner("'${_echo(q)}' 와 일치하는 메뉴가 없어요"),
          const MenuScopeNotice(),
        ];

      case SearchView.s6StoresMenuError:
        return [
          ..._storeSection(vm, q),
          const SizedBox(height: 24),
          const MenuSectionHeader(),
          MenuErrorCard(onRetry: _retryMenu),
        ];

      case SearchView.s7StoresMenuPartial:
        return [
          ..._storeSection(vm, q),
          const SizedBox(height: 24),
          ..._menuSection(vm, q: q),
        ];

      case SearchView.s8NoStoresMenuLoading:
        return [
          SearchOneLiner("'${_echo(q)}' 와 일치하는 매장이 없어요"),
          const SizedBox(height: 12),
          const MenuSectionHeader(loading: true),
          const MenuSkeleton(),
        ];

      case SearchView.s9NoStoresMenuData:
        return [
          SearchOneLiner("'${_echo(q)}' 와 일치하는 매장이 없어요"),
          const SizedBox(height: 12),
          ..._menuSection(vm),
        ];

      case SearchView.s10UnifiedEmpty:
        return [SearchUnifiedEmpty(query: q)];

      case SearchView.s11NoStoresMenuError:
        return [
          SearchOneLiner("'${_echo(q)}' 와 일치하는 매장이 없어요"),
          const SizedBox(height: 12),
          const MenuSectionHeader(),
          MenuErrorCard(onRetry: _retryMenu),
        ];

      case SearchView.s12UnifiedEmptyPartial:
        return [
          SearchUnifiedEmpty(query: q),
          MenuPartialFailureRow(
            onRetry: _retryMenu,
            retrying: vm.menuRefreshing,
          ),
        ];
    }
  }

  /// 질의 echo — 최대 20자 후 말줄임.
  String _echo(String q) => q.length > 20 ? '${q.substring(0, 20)}…' : q;

  void _retryMenu() => ref.invalidate(menuSearchIndexProvider);

  Widget _storeErrorBlock(Object? error) {
    if (error is PermissionDeniedException) {
      return StoreListError(
        title: '로그인이 필요해요',
        description: '로그인하면 매장과 메뉴를 검색할 수 있어요',
        actionLabel: '로그인',
        onRetry: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const LoginPage())),
      );
    }
    return StoreListError(onRetry: () => ref.invalidate(storeSnapshotProvider));
  }

  /// 매장 섹션 — `매장 (n)`. n 은 [SearchViewModel.storeCount] 한 곳에서만 나온다.
  List<Widget> _storeSection(SearchViewModel vm, String rawQuery) {
    return [
      Semantics(
        header: true,
        child: SectionTitle(title: '매장 (${vm.storeCount})'),
      ),
      for (var i = 0; i < vm.stores.length; i++) ...[
        RecommendedStoreCard(
          store: vm.stores[i],
          subtitle:
              SearchStoresUseCase.isAddressOnlyMatch(
                vm.stores[i],
                vm.normalizedQuery,
              )
              ? vm.stores[i].address
              : null,
          onTap: () => _openStore(vm.stores[i]),
        ),
        if (i != vm.stores.length - 1) const SizedBox(height: 12),
      ],
    ];
  }

  /// 메뉴 섹션 — 결과 행 + 상한 안내 + (부분 실패 줄) + 범위 안내.
  List<Widget> _menuSection(SearchViewModel vm, {String? q}) {
    final menu = vm.menu;
    final storesById = ref.read(storesByIdProvider);
    return [
      if (menu.total > 0) ...[
        Semantics(
          header: true,
          child: SectionTitle(title: '메뉴 (${vm.menuTotal})'),
        ),
        for (var i = 0; i < menu.rows.length; i++) ...[
          MenuSearchResultTile(
            hit: menu.rows[i],
            onTap: () {
              final store = storesById[menu.rows[i].storeId];
              if (store != null) _openStore(store, hit: menu.rows[i]);
            },
          ),
          if (i != menu.rows.length - 1) const SizedBox(height: 10),
        ],
        if (menu.isTruncated)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '메뉴 ${menu.total}개 중 ${GradeThresholds.menuSearchResultLimit}개만 보여드려요. 검색어를 더 구체적으로 입력해 보세요',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ),
      ] else if (q != null)
        SearchOneLiner("'${_echo(q)}' 와 일치하는 메뉴가 없어요"),
      if (menu.isPartial)
        MenuPartialFailureRow(onRetry: _retryMenu, retrying: vm.menuRefreshing),
      const MenuScopeNotice(),
    ];
  }
}
