import 'package:qradar/domain/repositories/main_category_repository.dart';

/// 메인 카테고리 삭제. admin only.
/// 사용 중이면 [MainCategoryInUseException] throw (Repository 책임).
class DeleteMainCategoryUseCase {
  final MainCategoryRepository _repository;
  DeleteMainCategoryUseCase(this._repository);

  Future<void> call(String id) => _repository.delete(id);
}
