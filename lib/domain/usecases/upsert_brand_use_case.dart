import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/brand_private_profile_entity.dart';
import 'package:qradar/domain/repositories/brand_repository.dart';

class UpsertBrandUseCase {
  final BrandRepository _repository;

  const UpsertBrandUseCase(this._repository);

  /// 브랜드 등록 또는 수정. 반환값: 저장된 brandId.
  ///
  /// [privateProfile] 은 사업자 PII — 부모 문서와 분리 저장되며 brandKey 는 쓰지 않는다.
  Future<String> call(
    BrandEntity brand, {
    BrandPrivateProfileEntity? privateProfile,
  }) => _repository.upsertBrand(brand, privateProfile: privateProfile);
}
