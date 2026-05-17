import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/constants/grade_thresholds.dart';
import 'package:qradar/core/constants/menu_categories.dart';
import 'package:qradar/data/datasources/remote/location_data_source.dart';
import 'package:qradar/data/datasources/remote/store_remote_data_source.dart';
import 'package:qradar/data/repositories/location_repository_impl.dart';
import 'package:qradar/data/repositories/store_repository_impl.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/domain/repositories/location_repository.dart';
import 'package:qradar/domain/repositories/store_repository.dart';
import 'package:qradar/domain/usecases/check_location_permission_use_case.dart';
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

/// 주변 매장(등급 상관없이 5km 이내, 가까운 순).
final nearbyStoresProvider = FutureProvider<List<StoreEntity>>((ref) async {
  final location = await ref.watch(userLocationProvider.future);
  final useCase = ref.watch(getNearbyStoresUseCaseProvider);
  return useCase(location: location);
});

/// 선택된 카테고리(다중 선택). 초기값: ["추천메뉴"]. 최소 1개 유지.
final selectedCategoriesProvider =
    NotifierProvider<SelectedCategoriesNotifier, Set<String>>(
  SelectedCategoriesNotifier.new,
);

class SelectedCategoriesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {MenuCategories.defaultSelected};

  void toggle(String category) {
    final next = <String>{...state};
    if (next.contains(category)) {
      // 최소 1개 유지
      if (next.length <= 1) return;
      next.remove(category);
    } else {
      next.add(category);
    }
    state = next;
  }
}

/// 선택된 카테고리 기반 필터링 매장. 카테고리 변경 시 자동 재조회.
final filteredStoresProvider = FutureProvider<List<StoreEntity>>((ref) async {
  final categories = ref.watch(selectedCategoriesProvider).toList();
  final location = await ref.watch(userLocationProvider.future);
  final useCase = ref.watch(getStoresByCategoriesUseCaseProvider);
  return useCase(categories: categories, location: location);
});
