import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/repositories/brand_repository.dart';

/// brand 가 운영하는 매장 리스트 실시간 감시 UseCase.
class WatchStoresByBrandUseCase {
  final BrandRepository _repository;

  WatchStoresByBrandUseCase(this._repository);

  Stream<List<StoreEntity>> call(String brandId) {
    return _repository.watchStoresByBrand(brandId);
  }
}
