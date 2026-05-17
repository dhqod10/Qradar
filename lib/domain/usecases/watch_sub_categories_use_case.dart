import 'package:qradar/domain/entities/sub_category_entity.dart';
import 'package:qradar/domain/repositories/menu_category_repository.dart';

class WatchSubCategoriesUseCase {
  final MenuCategoryRepository _repository;
  WatchSubCategoriesUseCase(this._repository);

  Stream<List<SubCategoryEntity>> call(String mainCategoryId) =>
      _repository.watchSubCategories(mainCategoryId);
}
