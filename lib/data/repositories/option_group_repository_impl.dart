import 'package:qradar/core/errors/option_group_in_use_exception.dart';
import 'package:qradar/data/datasources/remote/option_group_remote_data_source.dart';
import 'package:qradar/data/models/option_group_model.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/option_scope.dart';
import 'package:qradar/domain/repositories/option_group_repository.dart';

class OptionGroupRepositoryImpl implements OptionGroupRepository {
  final OptionGroupRemoteDataSource _dataSource;

  OptionGroupRepositoryImpl(this._dataSource);

  @override
  Stream<List<OptionGroupEntity>> watchByBrand({
    required String brandId,
    bool activeOnly = false,
  }) {
    return _dataSource
        .watchByBrand(brandId: brandId, activeOnly: activeOnly)
        .map((models) =>
            models.map((m) => m.toEntity()).toList(growable: false));
  }

  @override
  Stream<List<OptionGroupEntity>> watchByStore({
    required String storeId,
    bool activeOnly = false,
  }) {
    return _dataSource
        .watchByStore(storeId: storeId, activeOnly: activeOnly)
        .map((models) =>
            models.map((m) => m.toEntity()).toList(growable: false));
  }

  @override
  Future<void> upsert(OptionGroupEntity entity) async {
    if (entity.scope == OptionScope.master) {
      throw ArgumentError(
          'master scope 옵션 그룹은 CRUD 를 지원하지 않습니다. scope=master');
    }
    final model = OptionGroupModel.fromEntity(entity);
    switch (entity.scope) {
      case OptionScope.brand:
        final brandId = entity.brandId;
        if (brandId == null || brandId.isEmpty) {
          throw ArgumentError('brand scope 옵션 그룹은 brandId 가 필수입니다.');
        }
        await _dataSource.upsertBrand(brandId: brandId, model: model);
      case OptionScope.store:
        final storeId = entity.storeId;
        if (storeId == null || storeId.isEmpty) {
          throw ArgumentError('store scope 옵션 그룹은 storeId 가 필수입니다.');
        }
        await _dataSource.upsertStore(storeId: storeId, model: model);
      case OptionScope.master:
        break; // 위에서 이미 throw
    }
  }

  @override
  Future<void> toggleActive({
    required OptionScope scope,
    required String id,
    required bool active,
    String? brandId,
    String? storeId,
  }) async {
    switch (scope) {
      case OptionScope.brand:
        if (brandId == null) throw ArgumentError('brandId 필수');
        await _dataSource.toggleActiveBrand(
            brandId: brandId, id: id, active: active);
      case OptionScope.store:
        if (storeId == null) throw ArgumentError('storeId 필수');
        await _dataSource.toggleActiveStore(
            storeId: storeId, id: id, active: active);
      case OptionScope.master:
        throw ArgumentError('master scope 는 active 토글 불가');
    }
  }

  @override
  Future<void> delete({
    required OptionScope scope,
    required String id,
    String? brandId,
    String? storeId,
  }) async {
    // 사용 중 검사 — 0개일 때만 hard delete
    final usage = await countUsage(id: id);
    if (usage >= 1) {
      throw OptionGroupInUseException(
          optionGroupId: id, usageCount: usage);
    }
    switch (scope) {
      case OptionScope.brand:
        if (brandId == null) throw ArgumentError('brandId 필수');
        await _dataSource.deleteBrand(brandId: brandId, id: id);
      case OptionScope.store:
        if (storeId == null) throw ArgumentError('storeId 필수');
        await _dataSource.deleteStore(storeId: storeId, id: id);
      case OptionScope.master:
        throw ArgumentError('master scope 는 삭제 불가');
    }
  }

  @override
  Future<bool> findDuplicateName({
    required String name,
    required OptionScope scope,
    String? brandId,
    String? storeId,
    String? excludeId,
  }) async {
    switch (scope) {
      case OptionScope.brand:
        if (brandId == null) return false;
        return _dataSource.findDuplicateNameBrand(
            brandId: brandId, name: name, excludeId: excludeId);
      case OptionScope.store:
        if (storeId == null) return false;
        return _dataSource.findDuplicateNameStore(
            storeId: storeId, name: name, excludeId: excludeId);
      case OptionScope.master:
        return false; // master 는 read-only
    }
  }

  @override
  Future<int> countUsage({required String id}) =>
      _dataSource.countUsage(id: id);
}
