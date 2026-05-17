import 'package:qradar/domain/entities/sub_category_entity.dart';
import 'package:qradar/domain/repositories/sub_category_repository.dart';

/// brand 또는 store scope 부 카테고리 stream.
class WatchSubCategoriesByBrandUseCase {
  final SubCategoryRepository _repository;
  WatchSubCategoriesByBrandUseCase(this._repository);

  Stream<List<SubCategoryEntity>> call({
    required String brandId,
    bool activeOnly = false,
  }) =>
      _repository.watchByBrand(brandId: brandId, activeOnly: activeOnly);
}

class WatchSubCategoriesByStoreUseCase {
  final SubCategoryRepository _repository;
  WatchSubCategoriesByStoreUseCase(this._repository);

  Stream<List<SubCategoryEntity>> call({
    required String storeId,
    bool activeOnly = false,
  }) =>
      _repository.watchByStore(storeId: storeId, activeOnly: activeOnly);
}
