import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/repositories/brand_repository.dart';

class UpsertBrandUseCase {
  final BrandRepository _repository;

  const UpsertBrandUseCase(this._repository);

  /// 브랜드 등록 또는 수정. 반환값: 저장된 brandId.
  Future<String> call(BrandEntity brand) => _repository.upsertBrand(brand);
}
