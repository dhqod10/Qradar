import 'package:qradar/domain/entities/sub_category_entity.dart';
import 'package:qradar/domain/repositories/sub_category_repository.dart';

/// 부 카테고리 등록 또는 수정.
/// 중복 이름 시 [DuplicateSubCategoryNameException] throw (repository 단).
class UpsertSubCategoryUseCase {
  final SubCategoryRepository _repository;
  UpsertSubCategoryUseCase(this._repository);

  Future<void> call(SubCategoryEntity entity) => _repository.upsert(entity);
}
