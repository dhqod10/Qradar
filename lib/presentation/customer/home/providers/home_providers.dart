import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/constants/grade_thresholds.dart';
import 'package:qradar/core/errors/permission_denied_exception.dart';
import 'package:qradar/data/datasources/remote/location_data_source.dart';
import 'package:qradar/data/datasources/remote/store_remote_data_source.dart';
import 'package:qradar/data/repositories/location_repository_impl.dart';
import 'package:qradar/data/repositories/store_repository_impl.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/domain/repositories/location_repository.dart';
import 'package:qradar/domain/repositories/store_repository.dart';
import 'package:qradar/domain/usecases/check_location_permission_use_case.dart';
import 'package:qradar/domain/usecases/get_approved_stores_use_case.dart';
import 'package:qradar/domain/usecases/get_current_location_use_case.dart';
import 'package:qradar/domain/usecases/get_nearby_stores_use_case.dart';
import 'package:qradar/domain/usecases/get_stores_by_categories_use_case.dart';

// ── DI (DataSource → Repository → UseCase) ──────────────────────────────

final _storeRemoteDataSourceProvider = Provider<StoreRemoteDataSource>(
  (_) => StoreRemoteDataSource(),
);

final _locationDataSourceProvider = Provider<LocationDataSource>(
  (_) => LocationDataSource(),
);

final storeRepositoryProvider = Provider<StoreRepository>(
  (ref) => StoreRepositoryImpl(ref.watch(_storeRemoteDataSourceProvider)),
);

final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => LocationRepositoryImpl(ref.watch(_locationDataSourceProvider)),
);

final getApprovedStoresUseCaseProvider = Provider<GetApprovedStoresUseCase>(
  (ref) => GetApprovedStoresUseCase(ref.watch(storeRepositoryProvider)),
);

final getNearbyStoresUseCaseProvider = Provider<GetNearbyStoresUseCase>(
  (ref) => GetNearbyStoresUseCase(ref.watch(storeRepositoryProvider)),
);

final getStoresByCategoriesUseCaseProvider =
    Provider<GetStoresByCategoriesUseCase>(
  (ref) => GetStoresByCategoriesUseCase(ref.watch(storeRepositoryProvider)),
);

final getCurrentLocationUseCaseProvider = Provider<GetCurrentLocationUseCase>(
  (ref) => GetCurrentLocationUseCase(ref.watch(locationRepositoryProvider)),
);

final checkLocationPermissionUseCaseProvider =
    Provider<CheckLocationPermissionUseCase>(
  (ref) =>
      CheckLocationPermissionUseCase(ref.watch(locationRepositoryProvider)),
);

// ── State ───────────────────────────────────────────────────────────────

const UserLocation _fallbackLocation = UserLocation(
  latitude: GradeThresholds.defaultLatitude,
  longitude: GradeThresholds.defaultLongitude,
  isFallback: true,
);

/// 현재 사용자 위치.
///
/// 초기 상태는 resolve 되지 않은 `loading` — pre-permission 다이얼로그가 끝난 뒤
/// UI가 [UserLocationNotifier.allowAndFetch] 또는 [UserLocationNotifier.declineAndFallback] 을
/// 호출해야 상태가 확정됨.
final userLocationProvider =
    AsyncNotifierProvider<UserLocationNotifier, UserLocation>(
  UserLocationNotifier.new,
);

class UserLocationNotifier extends AsyncNotifier<UserLocation> {
  @override
  Future<UserLocation> build() {
    // 명시적 허용/거부 전까지 loading 유지
    return Completer<UserLocation>().future;
  }

  /// 사용자가 위치 권한에 동의 → 실제 조회 (필요 시 OS 권한 다이얼로그가 이 시점에 뜸).
  Future<void> allowAndFetch() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(getCurrentLocationUseCaseProvider)(),
    );
  }

  /// 사용자가 위치 공유를 거부 → 서울 시청 폴백 즉시 적용.
  void declineAndFallback() {
    state = const AsyncValue.data(_fallbackLocation);
  }
}

/// 읽기 실패 자동 재시도 정책 (홈 스냅샷 · 메뉴 인덱스 전용).
///
/// Riverpod 3 기본값은 10회·약 38초라 그동안 사용자는 정상 로딩으로 보이는 skeleton 만 본다 (design ⓑ 표가
/// 보증한 "실패 시 보이는 것" 이 38초 뒤에야 성립). 일시 오류는 **한 번만** 0.8초 뒤 다시 시도하고,
/// 권한 거부는 재시도해도 같으므로 즉시 에러로 확정한다. 그 뒤는 `다시 시도` 버튼이 맡는다.
Duration? searchReadRetry(int retryCount, Object error) {
  if (error is PermissionDeniedException) return null;
  return retryCount < 1 ? const Duration(milliseconds: 800) : null;
}

/// 승인 매장 스냅샷 — 홈 진입 시 **단 한 번** 읽는다 (`fetchAll(100)`).
/// 주변 / 필터 / 추천 전체보기 / 검색은 모두 이 값에서 파생한다. 당겨서 새로고침은 이것만 invalidate.
final storeSnapshotProvider = FutureProvider<List<StoreEntity>>(
  (ref) async {
    final location = await ref.watch(userLocationProvider.future);
    return ref.watch(getApprovedStoresUseCaseProvider)(location: location);
  },
  retry: searchReadRetry,
);

/// 당겨서 새로고침 — 스냅샷을 **한 번만** 다시 읽는다.
/// 권한이 있으면 `allowAndFetch` 가 위치 상태를 바꿔 스냅샷을 이미 다시 만들므로 invalidate 를 또 부르지 않는다
/// (불필요한 2회 읽기 방지). 폴백 경로는 위치 값이 그대로일 수 있어 invalidate 로 보장한다.
Future<void> refreshHomeStoreSnapshot({
  required UserLocationNotifier notifier,
  required bool permissionGranted,
  required void Function() invalidateSnapshot,
}) async {
  if (permissionGranted) {
    await notifier.allowAndFetch();
  } else {
    notifier.declineAndFallback();
    invalidateSnapshot();
  }
}

/// 주변 매장(반경 [GradeThresholds.nearbyRadiusKm] 이내, 가까운 순, 10건). 스냅샷 파생 — 추가 읽기 없음.
final nearbyStoresProvider = Provider<AsyncValue<List<StoreEntity>>>((ref) {
  return ref
      .watch(storeSnapshotProvider)
      .whenData(GetNearbyStoresUseCase.withinRadius);
});

/// 선택된 메인 카테고리 코드(id, 다중 선택). 초기값 빈 집합 = "전체"(필터 없음). 칩 토글로 필터.
final selectedCategoriesProvider =
    NotifierProvider<SelectedCategoriesNotifier, Set<String>>(
  SelectedCategoriesNotifier.new,
);

class SelectedCategoriesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void toggle(String category) {
    final next = <String>{...state};
    if (next.contains(category)) {
      next.remove(category);
    } else {
      next.add(category);
    }
    state = next;
  }
}

/// 선택된 카테고리 기반 필터링 매장. 스냅샷 파생이라 토글해도 읽기가 발생하지 않는다.
final filteredStoresProvider = Provider<AsyncValue<List<StoreEntity>>>((ref) {
  final categories = ref.watch(selectedCategoriesProvider);
  return ref
      .watch(storeSnapshotProvider)
      .whenData((all) => GetStoresByCategoriesUseCase.filterByCategories(all, categories));
});
