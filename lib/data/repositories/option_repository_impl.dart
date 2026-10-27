import 'package:qradar/core/utils/option_availability.dart';
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
    // 선택 가능 판정(active / 점주 비활성)은 순수 함수 하나다 — payment_price_authority R6.
    // 서버 optionPricing.ts 와 같은 규칙이며 교차 골든으로 고정된다. 여기에 판정을 남기지 않는다.
    return resolveSelectableOptions(
      groups: results.whereType<OptionGroupEntity>(),
      disabledGroupIds: disabledGroupIds,
      disabledItemIds: disabledItemIds,
    );
  }
}
