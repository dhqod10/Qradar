import 'package:qradar/domain/entities/favorite_menu_item_entity.dart';
import 'package:qradar/domain/repositories/favorites_repository.dart';

/// 사용자의 즐겨찾기 매장-음료 페어 stream.
///
/// 비로그인 상태면 빈 List emit.
class WatchFavoriteMenuItemsUseCase {
  final FavoritesRepository _repository;
  WatchFavoriteMenuItemsUseCase(this._repository);

  Stream<List<FavoriteMenuItemEntity>> call() {
    return _repository.watchFavoriteMenuItems();
  }
}
