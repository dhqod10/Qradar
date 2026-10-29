import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/domain/repositories/store_repository.dart';

class GetStoresByCategoriesUseCase {
  final StoreRepository _repository;
  GetStoresByCategoriesUseCase(this._repository);

  Future<List<StoreEntity>> call({
    required List<String> categories,
    required UserLocation location,
  }) {
    return _repository.getStoresByCategories(
      categories: categories,
      location: location,
    );
  }

  /// 스냅샷에서 카테고리 중 하나라도 가진 매장 — [call] 과 같은 규칙의 순수 버전 (읽기 0).
  /// [categories] 는 메인 카테고리 코드(id). 선택이 비면 필터 없음(전체 매장) — 홈 기본 "전체" (Phase B).
  /// 입력 순서(가까운 순)를 보존한다.
  static List<StoreEntity> filterByCategories(
    List<StoreEntity> stores,
    Set<String> categories,
  ) {
    if (categories.isEmpty) return stores;
    return stores
        .where((s) => s.availableMainCategories.any(categories.contains))
        .toList(growable: false);
  }
}
