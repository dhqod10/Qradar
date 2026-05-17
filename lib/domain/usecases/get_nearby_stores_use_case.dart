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
}
