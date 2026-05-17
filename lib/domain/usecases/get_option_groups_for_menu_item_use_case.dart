import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/repositories/option_repository.dart';

class GetOptionGroupsForMenuItemUseCase {
  final OptionRepository _repository;
  GetOptionGroupsForMenuItemUseCase(this._repository);

  /// [menuItem.disabledOptionGroupIds] / [menuItem.disabledOptionItemIds] 를 읽어
  /// 자동으로 비활성 필터를 적용한다 (sub-phase 5 — W4 결정).
  Future<List<OptionGroupEntity>> call(MenuItemEntity menuItem) =>
      _repository.getOptionGroupsForMenuItem(
        menuItem,
        disabledGroupIds: menuItem.disabledOptionGroupIds.toSet(),
        disabledItemIds: menuItem.disabledOptionItemIds.toSet(),
      );
}
