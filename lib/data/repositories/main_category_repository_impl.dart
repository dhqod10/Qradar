import 'package:qradar/core/errors/main_category_in_use_exception.dart';
import 'package:qradar/data/datasources/remote/main_category_remote_data_source.dart';
import 'package:qradar/data/models/main_category_model.dart';
import 'package:qradar/domain/entities/main_category_entity.dart';
import 'package:qradar/domain/repositories/main_category_repository.dart';

class MainCategoryRepositoryImpl implements MainCategoryRepository {
  final MainCategoryRemoteDataSource _dataSource;

  MainCategoryRepositoryImpl(this._dataSource);

  @override
  Stream<List<MainCategoryEntity>> watchAll({bool activeOnly = false}) {
    return _dataSource
        .streamAll(activeOnly: activeOnly)
        .map((models) => models.map((m) => m.toEntity()).toList(growable: false));
  }

  @override
  Future<MainCategoryEntity?> findById(String id) async {
    final model = await _dataSource.getById(id);
    return model?.toEntity();
  }

  @override
  Future<void> upsert(MainCategoryEntity entity) async {
    await _dataSource.upsert(MainCategoryModel.fromEntity(entity));
  }

  @override
  Future<void> delete(String id) async {
    final usage = await countUsage(id);
    if (usage > 0) {
      throw MainCategoryInUseException(categoryId: id, usageCount: usage);
    }
    await _dataSource.delete(id);
  }

  @override
  Future<int> countUsage(String id) async {
    final menuCount = await _dataSource.countMenuItemUsage(id);
    final subCount = await _dataSource.countSubCategoryUsage(id);
    return menuCount + subCount;
  }

  @override
  Future<({int menuCount, int storeCount})> countDetailedUsage(String id) {
    return _dataSource.countDetailedUsage(id);
  }

  @override
  Future<void> seedDefaultsIfEmpty() {
    return _dataSource.seedDefaultsIfEmpty();
  }
}
