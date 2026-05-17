import 'package:qradar/domain/repositories/favorites_repository.dart';

/// 매장 즐겨찾기 토글.
///
/// 이미 즐겨찾기에 있으면 제거, 없으면 추가.
class ToggleFavoriteStoreUseCase {
  final FavoritesRepository _repository;
  ToggleFavoriteStoreUseCase(this._repository);

  Future<void> call(String storeId) {
    return _repository.toggleFavoriteStore(storeId);
  }
}
