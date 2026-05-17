import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/favorites_remote_data_source.dart';
import 'package:qradar/data/repositories/favorites_repository_impl.dart';
import 'package:qradar/domain/repositories/favorites_repository.dart';
import 'package:qradar/domain/usecases/toggle_favorite_menu_item_use_case.dart';
import 'package:qradar/domain/usecases/toggle_favorite_store_use_case.dart';
import 'package:qradar/domain/usecases/watch_favorite_menu_items_use_case.dart';
import 'package:qradar/domain/usecases/watch_favorite_stores_use_case.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';

// ── DI ────────────────────────────────────────────────────────────────────────

final favoritesRemoteDataSourceProvider =
    Provider<FavoritesRemoteDataSource>((ref) {
  return FavoritesRemoteDataSource();
});

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final ds = ref.watch(favoritesRemoteDataSourceProvider);
  // 현재 로그인된 사용자의 uid 를 callback 으로 주입.
  // 카카오/네이버 prefix uid 를 그대로 노출하기 위해 authProvider 에서 가져온다.
  String? currentUid() => ref.read(authProvider).asData?.value?.uid;
  return FavoritesRepositoryImpl(ds, currentUid);
});

// ── UseCase Provider ──────────────────────────────────────────────────────────

final toggleFavoriteStoreUseCaseProvider =
    Provider<ToggleFavoriteStoreUseCase>((ref) {
  return ToggleFavoriteStoreUseCase(ref.watch(favoritesRepositoryProvider));
});

final toggleFavoriteMenuItemUseCaseProvider =
    Provider<ToggleFavoriteMenuItemUseCase>((ref) {
  return ToggleFavoriteMenuItemUseCase(
    ref.watch(favoritesRepositoryProvider),
  );
});

final watchFavoriteStoresUseCaseProvider =
    Provider<WatchFavoriteStoresUseCase>((ref) {
  return WatchFavoriteStoresUseCase(ref.watch(favoritesRepositoryProvider));
});

final watchFavoriteMenuItemsUseCaseProvider =
    Provider<WatchFavoriteMenuItemsUseCase>((ref) {
  return WatchFavoriteMenuItemsUseCase(
    ref.watch(favoritesRepositoryProvider),
  );
});

// ── State (Set 기반 빠른 멤버십 체크) ────────────────────────────────────────

/// 즐겨찾기 매장 id Set stream.
///
/// - 비로그인 → `Stream.value(<String>{})`
/// - 로그인 → `watchFavoriteStoresUseCase().map((list) => list.map((e) => e.storeId).toSet())`
///
/// `authProvider` 변경 시 Provider 자체가 rebuild 되므로 자연스럽게 분기 전환.
final favoriteStoreIdsProvider = StreamProvider<Set<String>>((ref) {
  final user = ref.watch(authProvider).asData?.value;
  if (user == null) {
    return Stream<Set<String>>.value(const <String>{});
  }
  return ref
      .watch(watchFavoriteStoresUseCaseProvider)
      .call()
      .map((list) => list.map((e) => e.storeId).toSet());
});

/// 즐겨찾기 매장-음료 페어 key Set stream.
/// key = `'${storeId}_${menuItemId}'`.
final favoriteMenuItemKeysProvider = StreamProvider<Set<String>>((ref) {
  final user = ref.watch(authProvider).asData?.value;
  if (user == null) {
    return Stream<Set<String>>.value(const <String>{});
  }
  return ref
      .watch(watchFavoriteMenuItemsUseCaseProvider)
      .call()
      .map(
        (list) => list.map((e) => '${e.storeId}_${e.menuItemId}').toSet(),
      );
});

/// 매장-음료 페어 key 헬퍼.
String favoriteMenuItemKey({
  required String storeId,
  required String menuItemId,
}) =>
    '${storeId}_$menuItemId';
