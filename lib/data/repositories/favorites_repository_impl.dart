import 'package:qradar/core/errors/unauthenticated_exception.dart';
import 'package:qradar/data/datasources/remote/favorites_remote_data_source.dart';
import 'package:qradar/domain/entities/favorite_menu_item_entity.dart';
import 'package:qradar/domain/entities/favorite_store_entity.dart';
import 'package:qradar/domain/repositories/favorites_repository.dart';

/// 즐겨찾기 Repository 구현체.
///
/// uid 획득은 생성자에 주입받은 [_currentUidGetter] callback 으로 한다.
/// 카카오/네이버 로그인 사용자는 `uid` 가 `kakao_${id}` / `naver_${id}` prefix 를 갖고,
/// `FirebaseAuth.currentUser.uid` 와 다르므로 Presentation 의 `authProvider` 에서
/// 끌어온 uid 를 그대로 사용해야 한다.
class FavoritesRepositoryImpl implements FavoritesRepository {
  final FavoritesRemoteDataSource _ds;
  final String? Function() _currentUidGetter;

  FavoritesRepositoryImpl(
    this._ds,
    this._currentUidGetter,
  );

  // ── Watch ──────────────────────────────────────────────────────────────

  @override
  Stream<List<FavoriteStoreEntity>> watchFavoriteStores() {
    final uid = _currentUidGetter();
    if (uid == null) {
      return Stream<List<FavoriteStoreEntity>>.value(
        const <FavoriteStoreEntity>[],
      );
    }
    return _ds.streamFavoriteStores(uid).map(
          (models) =>
              models.map((m) => m.toEntity()).toList(growable: false),
        );
  }

  @override
  Stream<List<FavoriteMenuItemEntity>> watchFavoriteMenuItems() {
    final uid = _currentUidGetter();
    if (uid == null) {
      return Stream<List<FavoriteMenuItemEntity>>.value(
        const <FavoriteMenuItemEntity>[],
      );
    }
    return _ds.streamFavoriteMenuItems(uid).map(
          (models) =>
              models.map((m) => m.toEntity()).toList(growable: false),
        );
  }

  @override
  Stream<bool> isStoreFavorited(String storeId) {
    final uid = _currentUidGetter();
    if (uid == null) return Stream<bool>.value(false);
    return _ds.watchStoreExists(uid, storeId);
  }

  @override
  Stream<bool> isMenuItemFavorited({
    required String storeId,
    required String menuItemId,
  }) {
    final uid = _currentUidGetter();
    if (uid == null) return Stream<bool>.value(false);
    return _ds.watchMenuItemExists(uid, storeId, menuItemId);
  }

  // ── Toggle ─────────────────────────────────────────────────────────────

  @override
  Future<void> toggleFavoriteStore(String storeId) async {
    final uid = _currentUidGetter();
    if (uid == null) throw const UnauthenticatedException();
    final exists = await _ds.getStoreExistsOnce(uid, storeId);
    if (exists) {
      await _ds.deleteFavoriteStore(uid, storeId);
    } else {
      await _ds.setFavoriteStore(uid, storeId);
    }
  }

  @override
  Future<void> toggleFavoriteMenuItem({
    required String storeId,
    required String menuItemId,
  }) async {
    final uid = _currentUidGetter();
    if (uid == null) throw const UnauthenticatedException();
    final exists =
        await _ds.getMenuItemExistsOnce(uid, storeId, menuItemId);
    if (exists) {
      await _ds.deleteFavoriteMenuItem(uid, storeId, menuItemId);
    } else {
      await _ds.setFavoriteMenuItem(uid, storeId, menuItemId);
    }
  }
}
