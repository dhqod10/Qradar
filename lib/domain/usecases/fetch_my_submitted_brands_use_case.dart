import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/repositories/brand_repository.dart';

/// 내가 제출한 브랜드들 (가장 이른 제출 순). 브랜드 계정이 `brandId` 없이 진입했을 때 연결 복구의 출발점이다.
/// 조회 실패는 예외로 전파된다 — 빈 목록("등록한 적 없음")과 구별되어야 한다.
class FetchMySubmittedBrandsUseCase {
  final BrandRepository _repository;
  const FetchMySubmittedBrandsUseCase(this._repository);

  Future<List<BrandEntity>> call() => _repository.fetchMySubmittedBrands();
}
