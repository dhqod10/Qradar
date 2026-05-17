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
}
