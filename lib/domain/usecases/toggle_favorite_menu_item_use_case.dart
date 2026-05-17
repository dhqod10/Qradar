import 'package:qradar/domain/repositories/favorites_repository.dart';

/// 매장-음료 페어 즐겨찾기 토글.
class ToggleFavoriteMenuItemUseCase {
  final FavoritesRepository _repository;
  ToggleFavoriteMenuItemUseCase(this._repository);

  Future<void> call({
    required String storeId,
    required String menuItemId,
  }) {
    return _repository.toggleFavoriteMenuItem(
      storeId: storeId,
      menuItemId: menuItemId,
    );
  }
}
