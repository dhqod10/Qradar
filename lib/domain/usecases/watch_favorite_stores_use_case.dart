import 'package:qradar/domain/entities/favorite_store_entity.dart';
import 'package:qradar/domain/repositories/favorites_repository.dart';

/// 사용자의 즐겨찾기 매장 stream.
///
/// 비로그인 상태면 빈 List emit (Repository 가 처리).
class WatchFavoriteStoresUseCase {
  final FavoritesRepository _repository;
  WatchFavoriteStoresUseCase(this._repository);

  Stream<List<FavoriteStoreEntity>> call() {
    return _repository.watchFavoriteStores();
  }
}
