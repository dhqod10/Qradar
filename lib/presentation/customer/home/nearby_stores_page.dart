import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/dialog/dialog_queue_service.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/location_permission_status.dart';
import 'package:qradar/presentation/common/store_list_states.dart';
import 'package:qradar/presentation/customer/home/providers/home_providers.dart';
import 'package:qradar/presentation/customer/home/providers/nearby_paged_providers.dart';
import 'package:qradar/presentation/customer/home/widgets/pre_permission_dialog.dart';
import 'package:qradar/presentation/customer/home/widgets/store_card.dart';
import 'package:qradar/presentation/customer/order/store/store_menu_page.dart';

/// 이 거리(px) 이내로 끝에 가까워지면 다음 페이지를 읽는다 (design.md: maxScrollExtent - 300).
const double _loadMoreTriggerExtent = 300;

/// 위치 권한 상태 — 폴백 배너의 `설정 열기` 액션 분기용 (읽기만, 요청 발생 안 함).
final _locationPermissionProvider =
    FutureProvider.autoDispose<LocationPermissionStatus>(
      (ref) => ref.watch(checkLocationPermissionUseCaseProvider)(),
    );

/// `주변매장` 전체보기 — 가까운 순 20건씩 무한 스크롤 (store_list_pagination, D0-a).
class NearbyStoresPage extends ConsumerStatefulWidget {
  const NearbyStoresPage({super.key});

  @override
  ConsumerState<NearbyStoresPage> createState() => _NearbyStoresPageState();
}

class _NearbyStoresPageState extends ConsumerState<NearbyStoresPage> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 끝 근접 판정 — 스크롤 이벤트와 레이아웃 직후(짧은 목록) 양쪽에서 쓴다.
  /// `canLoadMore` 가 로딩중/소진/실패 상태를 걸러 주므로 여기서는 거리만 본다.
  void _maybeLoadMore() {
    if (!mounted || !_controller.hasClients) return;
    final state = ref.read(pagedNearbyStoresProvider).value;
    if (state == null || !state.canLoadMore) return;
    final pos = _controller.position;
    // 내용이 화면보다 짧으면 maxScrollExtent <= 0 이라 extentAfter 도 0 -> 자동으로 계속 채운다.
    if (pos.extentAfter <= _loadMoreTriggerExtent) {
      ref.read(pagedNearbyStoresProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pagedNearbyStoresProvider);

    // 레이아웃이 끝난 뒤 한 번 더 판정: 초기 20건이 화면을 못 채워 스크롤 이벤트가 안 생기는 경우를 구제한다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());

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
          '주변매장',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        centerTitle: false,
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.axis == Axis.vertical) _maybeLoadMore();
          return false;
        },
        child: CustomScrollView(
          controller: _controller,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: _slivers(context, async),
        ),
      ),
    );
  }

  List<Widget> _slivers(
    BuildContext context,
    AsyncValue<NearbyPagedState> async,
  ) {
    // hasValue 우선 — 재빌드 중에도 직전 목록 유지.
    if (async.hasValue) {
      final s = async.requireValue;
      final items = s.visible;
      return [
        if (s.isFallbackLocation)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverToBoxAdapter(child: _FallbackBanner()),
          ),
        if (items.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: NearbyEmptyState()),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: EdgeInsets.only(
                    bottom: i == items.length - 1 ? 0 : 12,
                  ),
                  child: RecommendedStoreCard(
                    store: items[i],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StoreMenuPage(store: items[i]),
                      ),
                    ),
                  ),
                ),
                childCount: items.length,
              ),
            ),
          ),
        SliverToBoxAdapter(child: _footer(s, items.isEmpty)),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ];
    }
    if (async.hasError) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: StoreListError(
              onRetry: () => ref.invalidate(pagedNearbyStoresProvider),
            ),
          ),
        ),
      ];
    }
    return const [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 32),
        sliver: SliverToBoxAdapter(child: StoreListSkeleton(rows: 6)),
      ),
    ];
  }

  Widget _footer(NearbyPagedState s, bool empty) {
    // 빈 목록은 이미 NearbyEmptyState 가 안내하므로 소진 문구를 중복하지 않는다.
    final Widget child;
    if (s.isLoadingMore) {
      child = const StoreListLoadingFooter(key: ValueKey('loading'));
    } else if (s.loadMoreFailed) {
      child = StoreListRetryFooter(
        key: const ValueKey('retry'),
        onRetry: () =>
            ref.read(pagedNearbyStoresProvider.notifier).retryLoadMore(),
      );
    } else if (s.exhausted && !empty) {
      child = const StoreListEndFooter(key: ValueKey('end'));
    } else if (s.hasMore) {
      // 다음 페이지 대기 — 레이아웃 점프 없이 스피너 높이만 확보.
      child = const SizedBox(key: ValueKey('idle'), height: 72);
    } else {
      child = const SizedBox.shrink(key: ValueKey('none'));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: child,
    );
  }
}

/// 위치 폴백 배너 + (권한 거부 계열일 때만) `설정 열기` 액션.
class _FallbackBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(_locationPermissionProvider).value;
    final canAct = status == LocationPermissionStatus.deniedForever ||
        status == LocationPermissionStatus.notYetAsked;
    return LocationFallbackBanner(
      actionLabel: canAct ? '설정 열기' : null,
      onAction: canAct ? () => _onAction(context, ref, status!) : null,
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    LocationPermissionStatus status,
  ) async {
    if (status == LocationPermissionStatus.deniedForever) {
      await AppSettings.openAppSettings();
      return;
    }
    // notYetAsked(홈에서 '나중에' 선택) — 홈과 같은 pre-permission 흐름을 재사용.
    final agreed = await PrePermissionDialog.show(
      context,
      queue: ref.read(dialogQueueServiceProvider),
    );
    if (agreed) {
      // 위치가 확정되면 userLocationProvider 변경 -> 목록 전체 리셋(skeleton 부터), 배너 제거.
      await ref.read(userLocationProvider.notifier).allowAndFetch();
    }
  }
}
