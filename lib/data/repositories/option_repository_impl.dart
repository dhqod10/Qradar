import 'package:qradar/data/datasources/remote/option_remote_data_source.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/option_scope.dart';
import 'package:qradar/domain/repositories/option_repository.dart';

class OptionRepositoryImpl implements OptionRepository {
  final OptionRemoteDataSource _dataSource;

  OptionRepositoryImpl(this._dataSource);

  @override
  Future<OptionGroupEntity?> getMasterOptionGroup(String id) async {
    final model = await _dataSource.getMaster(id);
    return model?.toEntity();
  }

  @override
  Future<OptionGroupEntity?> getBrandOptionGroup({
    required String brandId,
    required String id,
  }) async {
    final model = await _dataSource.getBrand(brandId: brandId, id: id);
    return model?.toEntity();
  }

  @override
  Future<OptionGroupEntity?> getStoreOptionGroup({
    required String storeId,
    required String id,
  }) async {
    final model = await _dataSource.getStore(storeId: storeId, id: id);
    return model?.toEntity();
  }

  @override
  Future<List<OptionGroupEntity>> getOptionGroupsForMenuItem(
    MenuItemEntity menuItem, {
    Set<String> disabledGroupIds = const {},
    Set<String> disabledItemIds = const {},
  }) async {
    final futures = menuItem.optionGroupRefs.map((ref) async {
      switch (ref.scope) {
        case OptionScope.master:
          return getMasterOptionGroup(ref.id);
        case OptionScope.brand:
          // brand ref 는 brandId 컨텍스트 필요 — menuItem.brandId 사용
          final brandId = menuItem.brandId;
          if (brandId == null || brandId.isEmpty) return null;
          return getBrandOptionGroup(brandId: brandId, id: ref.id);
        case OptionScope.store:
          return getStoreOptionGroup(storeId: menuItem.storeId, id: ref.id);
      }
    });
    final results = await Future.wait(futures);
    // active=false 인 그룹은 고객 화면에서 제외 (sub-phase 7 B-3)
    final groups = results
        .whereType<OptionGroupEntity>()
        .where((g) => g.active)
        .toList(growable: false);

    // sub-phase 5 — 점주 비활성 필터 적용
    if (disabledGroupIds.isEmpty && disabledItemIds.isEmpty) return groups;

    final filtered = <OptionGroupEntity>[];
    for (final group in groups) {
      // 그룹 전체 비활성: 통째로 제외
      if (disabledGroupIds.contains(group.id)) continue;

      // 항목 필터: compositeId = "{groupId}_{itemId}"
      if (disabledItemIds.isEmpty) {
        filtered.add(group);
        continue;
      }
      final filteredItems = group.items.where((item) {
        final compositeId = '${group.id}_${item.id}';
        return !disabledItemIds.contains(compositeId);
      }).toList(growable: false);
      filtered.add(group.copyWith(items: filteredItems));
    }
    return filtered;
  }
}
