import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';

/// 옵션 그룹 Read-only Repository 인터페이스.
///
/// master / brand / store 세 scope 를 모두 읽는다.
/// CRUD 는 [OptionGroupRepository] 에서 담당.
abstract class OptionRepository {
  /// 글로벌(master) 옵션 그룹 1건 조회. 없으면 null.
  Future<OptionGroupEntity?> getMasterOptionGroup(String id);

  /// brand scope 옵션 그룹 1건 조회. 없으면 null.
  Future<OptionGroupEntity?> getBrandOptionGroup({
    required String brandId,
    required String id,
  });

  /// 매장(store) 한정 옵션 그룹 1건 조회. 없으면 null.
  Future<OptionGroupEntity?> getStoreOptionGroup({
    required String storeId,
    required String id,
  });

  /// 메뉴에 적용된 옵션 그룹들을 ref(scope+id) 기준으로 모두 fetch.
  ///
  /// B-3 scope 모델:
  /// - master ref → 글로벌 컬렉션 read
  /// - brand ref → brands/{brandId}/optionGroups/{id}
  /// - store ref → stores/{storeId}/optionGroups/{id}
  ///
  /// [disabledGroupIds]: 점주가 비활성화한 그룹 ID 목록 (sub-phase 5). 해당 그룹 전체 제외.
  /// [disabledItemIds]: 점주가 비활성화한 항목 compositeId 목록 (`{groupId}_{itemId}` 형식).
  ///
  /// 결과 순서는 menuItem.optionGroupRefs 순서를 보존한다.
  Future<List<OptionGroupEntity>> getOptionGroupsForMenuItem(
    MenuItemEntity menuItem, {
    Set<String> disabledGroupIds = const {},
    Set<String> disabledItemIds = const {},
  });
}
