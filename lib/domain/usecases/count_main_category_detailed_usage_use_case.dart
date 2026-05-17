import 'package:qradar/domain/repositories/main_category_repository.dart';

/// 메인 카테고리 영향 데이터 상세 조회.
/// DeactivateConfirmDialog 에 매장 수 / 메뉴 수 표시용.
class CountMainCategoryDetailedUsageUseCase {
  final MainCategoryRepository _repository;
  CountMainCategoryDetailedUsageUseCase(this._repository);

  Future<({int menuCount, int storeCount})> call(String id) =>
      _repository.countDetailedUsage(id);
}
