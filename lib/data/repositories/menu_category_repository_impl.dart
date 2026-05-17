import 'package:qradar/data/datasources/remote/sub_category_remote_data_source.dart';
import 'package:qradar/domain/entities/sub_category_entity.dart';
import 'package:qradar/domain/repositories/menu_category_repository.dart';

class MenuCategoryRepositoryImpl implements MenuCategoryRepository {
  final SubCategoryRemoteDataSource _dataSource;

  MenuCategoryRepositoryImpl(this._dataSource);

  @override
  Stream<List<SubCategoryEntity>> watchSubCategories(String mainCategoryId) {
    return _dataSource.streamByMainCategory(mainCategoryId).map(
          (models) =>
              models.map((m) => m.toEntity()).toList(growable: false),
        );
  }
}
