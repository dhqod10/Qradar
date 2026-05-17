import 'package:qradar/domain/repositories/brand_repository.dart';

class RejectBrandUseCase {
  final BrandRepository _repository;

  const RejectBrandUseCase(this._repository);

  Future<void> call(String brandId, String adminUid, String reason) =>
      _repository.rejectBrand(brandId, adminUid, reason);
}
