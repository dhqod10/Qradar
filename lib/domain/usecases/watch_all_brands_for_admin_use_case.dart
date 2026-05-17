import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/repositories/brand_repository.dart';

class WatchAllBrandsForAdminUseCase {
  final BrandRepository _repository;

  const WatchAllBrandsForAdminUseCase(this._repository);

  Stream<List<BrandEntity>> call() => _repository.watchAll();
}
