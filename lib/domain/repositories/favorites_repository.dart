import 'package:qradar/domain/entities/favorite_menu_item_entity.dart';
import 'package:qradar/domain/entities/favorite_store_entity.dart';

/// 즐겨찾기 Repository 인터페이스.
///
/// **본 phase(1a)에서는 인터페이스만 정의.** Impl 은 Phase 1c 에서 작성.
abstract class FavoritesRepository {
  /// 사용자 즐겨찾기 매장 stream. addedAt desc.
  Stream<List<FavoriteStoreEntity>> watchFavoriteStores();

  /// 사용자 즐겨찾기 음료(매장-음료 페어) stream.
  Stream<List<FavoriteMenuItemEntity>> watchFavoriteMenuItems();

  /// 매장 즐겨찾기 토글. 이미 등록되어 있으면 제거, 없으면 추가.
  Future<void> toggleFavoriteStore(String storeId);

  /// 매장-음료 페어 즐겨찾기 토글.
  Future<void> toggleFavoriteMenuItem({
    required String storeId,
    required String menuItemId,
  });

  /// 매장이 즐겨찾기 되어 있는지.
  Stream<bool> isStoreFavorited(String storeId);

  /// 매장-음료 페어가 즐겨찾기 되어 있는지.
  Stream<bool> isMenuItemFavorited({
    required String storeId,
    required String menuItemId,
  });
}
