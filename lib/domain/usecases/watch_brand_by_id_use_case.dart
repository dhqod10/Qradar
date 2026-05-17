import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/repositories/brand_repository.dart';

class WatchBrandByIdUseCase {
  final BrandRepository _repository;

  const WatchBrandByIdUseCase(this._repository);

  Stream<BrandEntity?> call(String brandId) =>
      _repository.watchById(brandId);
}
