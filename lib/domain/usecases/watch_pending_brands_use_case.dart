import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/repositories/brand_repository.dart';

class WatchPendingBrandsUseCase {
  final BrandRepository _repository;

  const WatchPendingBrandsUseCase(this._repository);

  Stream<List<BrandEntity>> call() => _repository.watchPendingForAdmin();
}
