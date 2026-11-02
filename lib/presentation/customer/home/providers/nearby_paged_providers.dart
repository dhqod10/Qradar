import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/constants/grade_thresholds.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/usecases/get_nearby_stores_paged_use_case.dart';
import 'package:qradar/presentation/customer/home/providers/home_providers.dart';

/// 주변매장 전체보기 페이지네이션 상태 (store_list_pagination).
///
/// [loaded] 는 지금까지 읽은 전체(가까운 순, id 중복 없음), [shownCount] 는 화면에 노출한 개수다.
/// 추가 로드는 항상 [loaded] 의 **뒤에만** 붙으므로 기존 항목 순서가 요동치지 않는다.
class NearbyPagedState {
  const NearbyPagedState({
    required this.loaded,
    required this.shownCount,
    required this.loadedRadiusKm,
    required this.isFallbackLocation,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<StoreEntity> loaded;
  final int shownCount;
  final double loadedRadiusKm;
  final bool isFallbackLocation;
  final bool isLoadingMore;

  /// 추가 로드 실패 — 기존 목록은 보존하고 footer 재시도만 노출. 자동 재호출 금지.
  final bool loadMoreFailed;

  List<StoreEntity> get visible => loaded.sublist(0, shownCount);

  /// 미노출분이 남았거나 반경을 더 넓힐 수 있다.
  bool get hasMore =>
      shownCount < loaded.length ||
      !GetNearbyStoresPagedUseCase.isMaxRadius(loadedRadiusKm);

  /// 최대 반경까지 읽고 전부 노출했다.
  bool get exhausted => !hasMore;

  /// 스크롤 트리거가 `loadMore()` 를 호출해도 되는 상태 (로딩중/소진/실패 상태는 무시).
  bool get canLoadMore => hasMore && !isLoadingMore && !loadMoreFailed;

  NearbyPagedState copyWith({
    List<StoreEntity>? loaded,
    int? shownCount,
    double? loadedRadiusKm,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) => NearbyPagedState(
    loaded: loaded ?? this.loaded,
    shownCount: shownCount ?? this.shownCount,
    loadedRadiusKm: loadedRadiusKm ?? this.loadedRadiusKm,
    isFallbackLocation: isFallbackLocation,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
  );
}

final getNearbyStoresPagedUseCaseProvider =
    Provider<GetNearbyStoresPagedUseCase>(
      (ref) => GetNearbyStoresPagedUseCase(ref.watch(storeRepositoryProvider)),
    );

/// 주변매장 전체보기 목록. 위치가 바뀌면 `build` 가 다시 돌아 **처음부터** 다시 읽는다 (부분 재정렬 금지).
final pagedNearbyStoresProvider =
    AsyncNotifierProvider<PagedNearbyStoresNotifier, NearbyPagedState>(
      PagedNearbyStoresNotifier.new,
      retry: searchReadRetry,
    );

class PagedNearbyStoresNotifier extends AsyncNotifier<NearbyPagedState> {
  /// build 세대 — 위치 변경 등으로 재빌드된 뒤 늦게 끝난 loadMore 가 새 상태를 덮어쓰지 않게 한다.
  int _generation = 0;

  @override
  Future<NearbyPagedState> build() async {
    ++_generation;
    final location = await ref.watch(userLocationProvider.future);
    final useCase = ref.read(getNearbyStoresPagedUseCaseProvider);

    // 시작 반경에서 한 페이지(20)가 찰 때까지 반경을 넓힌다. 확장 중에는 build 가 끝나지 않으므로
    // 화면은 empty 가 아니라 skeleton 을 유지하고, 최대 반경까지 0건일 때만 빈 목록이 확정된다.
    var radius = GradeThresholds.nearbyPagedStartRadiusKm;
    var loaded = <StoreEntity>[];
    while (true) {
      final page = await useCase(center: location, radiusKm: radius);
      loaded = [
        ...loaded,
        ...GetNearbyStoresPagedUseCase.newItemsOnly(
          page.items,
          {for (final s in loaded) s.id},
        ),
      ];
      if (loaded.length >= GradeThresholds.nearbyPageSize ||
          GetNearbyStoresPagedUseCase.isMaxRadius(radius)) {
        break;
      }
      radius = GetNearbyStoresPagedUseCase.nextRadius(radius);
    }
    return NearbyPagedState(
      loaded: loaded,
      shownCount: loaded.length < GradeThresholds.nearbyPageSize
          ? loaded.length
          : GradeThresholds.nearbyPageSize,
      loadedRadiusKm: radius,
      isFallbackLocation: location.isFallback,
    );
  }

  /// 다음 20건. 미노출분이 20 이상이면 읽기 없이 노출만 늘리고, 모자라면 반경을 넓혀 읽는다.
  Future<void> loadMore() async {
    final cur = state.value;
    if (cur == null || !cur.canLoadMore) return;
    const pageSize = GradeThresholds.nearbyPageSize;

    if (cur.loaded.length - cur.shownCount >= pageSize) {
      state = AsyncData(cur.copyWith(shownCount: cur.shownCount + pageSize));
      return;
    }

    final gen = _generation;
    state = AsyncData(cur.copyWith(isLoadingMore: true));
    final location = await ref.read(userLocationProvider.future);
    final useCase = ref.read(getNearbyStoresPagedUseCaseProvider);

    var radius = cur.loadedRadiusKm;
    var loaded = cur.loaded;
    try {
      while (loaded.length - cur.shownCount < pageSize &&
          !GetNearbyStoresPagedUseCase.isMaxRadius(radius)) {
        final next = GetNearbyStoresPagedUseCase.nextRadius(radius);
        final page = await useCase(center: location, radiusKm: next);
        if (gen != _generation) return;
        loaded = [
          ...loaded,
          ...GetNearbyStoresPagedUseCase.newItemsOnly(
            page.items,
            {for (final s in loaded) s.id},
          ),
        ];
        radius = next;
      }
    } catch (_) {
      if (gen != _generation) return;
      // 기존 목록 보존 + footer 재시도. 이미 읽은 반경/항목은 유지해 재시도가 같은 읽기를 반복하지 않는다.
      state = AsyncData(
        cur.copyWith(
          loaded: loaded,
          loadedRadiusKm: radius,
          isLoadingMore: false,
          loadMoreFailed: true,
        ),
      );
      return;
    }
    if (gen != _generation) return;
    final target = cur.shownCount + pageSize;
    state = AsyncData(
      cur.copyWith(
        loaded: loaded,
        loadedRadiusKm: radius,
        shownCount: target < loaded.length ? target : loaded.length,
        isLoadingMore: false,
      ),
    );
  }

  /// footer `다시 시도` — 실패 표시를 걷고 즉시 로딩 footer 로 전환해 재호출. 사용자 탭으로만 호출된다.
  Future<void> retryLoadMore() async {
    final cur = state.value;
    if (cur == null || !cur.loadMoreFailed) return;
    state = AsyncData(cur.copyWith(loadMoreFailed: false));
    await loadMore();
  }
}
