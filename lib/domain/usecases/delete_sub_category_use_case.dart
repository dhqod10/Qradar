import 'package:qradar/domain/entities/sub_category_entity.dart';
import 'package:qradar/domain/repositories/sub_category_repository.dart';

/// 부 카테고리 삭제.
/// 사용 중이면 [SubCategoryInUseException] throw (repository 단).
class DeleteSubCategoryUseCase {
  final SubCategoryRepository _repository;
  DeleteSubCategoryUseCase(this._repository);

  Future<void> call({
    required String id,
    required SubCategoryScope scope,
    String? brandId,
    String? storeId,
  }) =>
      _repository.delete(
        id: id,
        scope: scope,
        brandId: brandId,
        storeId: storeId,
      );
}
