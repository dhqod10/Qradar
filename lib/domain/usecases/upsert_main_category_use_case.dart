import 'package:qradar/domain/entities/main_category_entity.dart';
import 'package:qradar/domain/repositories/main_category_repository.dart';

/// 메인 카테고리 등록 또는 수정. admin only.
class UpsertMainCategoryUseCase {
  final MainCategoryRepository _repository;
  UpsertMainCategoryUseCase(this._repository);

  Future<void> call(MainCategoryEntity entity) =>
      _repository.upsert(entity);
}
