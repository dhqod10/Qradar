import 'package:qradar/domain/entities/sub_category_entity.dart';
import 'package:qradar/domain/repositories/sub_category_repository.dart';

/// 부 카테고리 active 즉시 토글 (confirm dialog 없음).
class ToggleSubCategoryActiveUseCase {
  final SubCategoryRepository _repository;
  ToggleSubCategoryActiveUseCase(this._repository);

  Future<void> call({
    required String id,
    required SubCategoryScope scope,
    required bool active,
    String? brandId,
    String? storeId,
  }) =>
      _repository.toggleActive(
        id: id,
        scope: scope,
        active: active,
        brandId: brandId,
        storeId: storeId,
      );
}
