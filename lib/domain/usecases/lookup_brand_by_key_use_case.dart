import 'package:qradar/domain/entities/brand_key_lookup.dart';
import 'package:qradar/domain/repositories/brand_repository.dart';

/// brandKey 로 승인된 브랜드를 서버에서 조회한다 (V4).
///
/// 성공하면 [BrandKeyLookup] (brandId·name·logoUrl 만). 실패는 `BrandKeyLookupException`
/// (notFound / rateLimited / failed) — **null 로 뭉개지 않는다**. 점주 매장 등록 폼의 brandKey 검증 진입점.
class LookupBrandByKeyUseCase {
  final BrandRepository _repository;
  LookupBrandByKeyUseCase(this._repository);

  Future<BrandKeyLookup> call(String brandKey) =>
      _repository.lookupBrandByKey(brandKey);
}
