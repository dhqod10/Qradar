import 'package:qradar/domain/entities/brand_private_profile_entity.dart';
import 'package:qradar/domain/repositories/brand_repository.dart';

/// 브랜드 비공개 프로필(brandKey + PII) 실시간 감시. 읽기 실패는 스트림 에러.
class WatchBrandPrivateProfileUseCase {
  final BrandRepository _repository;
  const WatchBrandPrivateProfileUseCase(this._repository);

  Stream<BrandPrivateProfileEntity?> call(String brandId) =>
      _repository.watchPrivateProfile(brandId);
}
