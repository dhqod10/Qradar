import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/domain/repositories/store_repository.dart';

/// 홈 매장 스냅샷 — 승인 매장 전체(거리 포함, 가까운 순)를 **한 번** 읽는다.
///
/// 주변 매장 / 카테고리 필터 / 추천 전체보기 / 검색은 이 스냅샷에서 순수 함수로 파생한다 (`GetNearbyStoresUseCase.withinRadius` / `GetStoresByCategoriesUseCase.filterByCategories`)
/// (카테고리 토글이 더 이상 읽기를 만들지 않는다).
class GetApprovedStoresUseCase {
  final StoreRepository _repository;
  GetApprovedStoresUseCase(this._repository);

  Future<List<StoreEntity>> call({
    required UserLocation location,
    int limit = 100,
  }) => _repository.getApprovedStores(location: location, limit: limit);
}
