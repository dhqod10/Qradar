import 'package:qradar/domain/entities/main_category_entity.dart';
import 'package:qradar/domain/repositories/main_category_repository.dart';

/// 메인 카테고리 전체 stream (admin 용, inactive 포함).
class WatchMainCategoriesAllUseCase {
  final MainCategoryRepository _repository;
  WatchMainCategoriesAllUseCase(this._repository);

  Stream<List<MainCategoryEntity>> call() =>
      _repository.watchAll(activeOnly: false);
}

/// 메인 카테고리 active 만 stream (customer/brand/owner 용).
class WatchMainCategoriesActiveUseCase {
  final MainCategoryRepository _repository;
  WatchMainCategoriesActiveUseCase(this._repository);

  Stream<List<MainCategoryEntity>> call() =>
      _repository.watchAll(activeOnly: true);
}
