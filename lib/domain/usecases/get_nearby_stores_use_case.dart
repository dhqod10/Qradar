import 'package:qradar/core/constants/grade_thresholds.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/domain/repositories/store_repository.dart';

class GetNearbyStoresUseCase {
  final StoreRepository _repository;
  GetNearbyStoresUseCase(this._repository);

  Future<List<StoreEntity>> call({
    required UserLocation location,
    double radiusKm = GradeThresholds.nearbyRadiusKm,
    int limit = 10,
  }) {
    return _repository.getNearbyStores(
      location: location,
      radiusKm: radiusKm,
      limit: limit,
    );
  }

  /// 스냅샷(가까운 순 정렬) 에서 반경 이내 상위 [limit]곳 — [call] 과 같은 규칙의 순수 버전.
  /// 홈 스냅샷 파생용 (읽기 0). 거리 미상은 제외.
  static List<StoreEntity> withinRadius(
    List<StoreEntity> stores, {
    double radiusKm = GradeThresholds.nearbyRadiusKm,
    int limit = 10,
  }) {
    return stores
        .where((s) => s.distanceKm != null && s.distanceKm! <= radiusKm)
        .take(limit)
        .toList(growable: false);
  }
}
