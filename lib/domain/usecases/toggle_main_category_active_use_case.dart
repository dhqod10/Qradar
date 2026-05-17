import 'package:qradar/domain/repositories/main_category_repository.dart';

/// 메인 카테고리 active 토글. admin only.
class ToggleMainCategoryActiveUseCase {
  final MainCategoryRepository _repository;
  ToggleMainCategoryActiveUseCase(this._repository);

  Future<void> call(String id, bool active) async {
    final entity = await _repository.findById(id);
    if (entity == null) return;
    await _repository.upsert(entity.copyWith(active: active));
  }
}
