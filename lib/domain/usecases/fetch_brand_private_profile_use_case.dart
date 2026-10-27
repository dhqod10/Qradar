import 'package:qradar/domain/entities/brand_private_profile_entity.dart';
import 'package:qradar/domain/repositories/brand_repository.dart';

/// 브랜드 비공개 프로필 단발성 조회 (수정 폼 초기값). 문서 없음 = null, 읽기 실패 = 예외.
class FetchBrandPrivateProfileUseCase {
  final BrandRepository _repository;
  const FetchBrandPrivateProfileUseCase(this._repository);

  Future<BrandPrivateProfileEntity?> call(String brandId) =>
      _repository.fetchPrivateProfile(brandId);
}
