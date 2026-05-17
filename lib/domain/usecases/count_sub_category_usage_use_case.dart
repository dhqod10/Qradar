import 'package:qradar/domain/repositories/sub_category_repository.dart';

/// 부 카테고리를 참조하는 menuItem 수 조회.
class CountSubCategoryUsageUseCase {
  final SubCategoryRepository _repository;
  CountSubCategoryUsageUseCase(this._repository);

  Future<int> call(String subCategoryId) =>
      _repository.countUsage(subCategoryId);
}
