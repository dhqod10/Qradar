import 'package:qradar/domain/repositories/brand_repository.dart';

class ApproveBrandUseCase {
  final BrandRepository _repository;

  const ApproveBrandUseCase(this._repository);

  Future<void> call(String brandId, String adminUid) =>
      _repository.approveBrand(brandId, adminUid);
}
