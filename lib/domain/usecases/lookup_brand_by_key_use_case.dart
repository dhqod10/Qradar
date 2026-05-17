import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/repositories/brand_repository.dart';

/// brandKey 로 승인된 brand 를 조회한다 (V4).
///
/// 미매칭 또는 status != approved 이면 null 반환.
/// 점주 매장 등록 폼에서 brandKey 검증 진입점.
class LookupBrandByKeyUseCase {
  final BrandRepository _repository;
  LookupBrandByKeyUseCase(this._repository);

  Future<BrandEntity?> call(String brandKey) =>
      _repository.findByBrandKey(brandKey);
}
