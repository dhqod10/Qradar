import 'package:qradar/domain/repositories/brand_repository.dart';

/// 내가 제출한 브랜드를 내 계정에 연결한다 (서버가 `submittedBy == uid` 를 검증). 멱등. 실패는 `BrandClaimException`.
class ClaimSubmittedBrandUseCase {
  final BrandRepository _repository;
  const ClaimSubmittedBrandUseCase(this._repository);

  Future<void> call(String brandId) {
    if (brandId.isEmpty) throw ArgumentError.value(brandId, 'brandId');
    return _repository.claimSubmittedBrand(brandId);
  }
}
