import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';
import 'package:qradar/domain/repositories/menu_override_repository.dart';

/// 개인 매장 / 브랜드 매장 점포 한정 메뉴 옵션 비활성 업데이트 (sub-phase 5).
///
/// stores/{storeId}/menuItems/{menuItemId}.disabledOption* partial update.
class UpdateDisabledOptionsForPersonalMenuUseCase {
  final MenuItemRepository _repository;
  UpdateDisabledOptionsForPersonalMenuUseCase(this._repository);

  Future<void> call(
    MenuItemEntity item, {
    required List<String> disabledGroupIds,
    required List<String> disabledItemIds,
  }) =>
      _repository.updateStoreOnlyMenuOperation(
        item.copyWith(
          disabledOptionGroupIds: disabledGroupIds,
          disabledOptionItemIds: disabledItemIds,
        ),
      );
}

/// 브랜드 매장 마스터 메뉴 ref 옵션 비활성 업데이트 (sub-phase 5 — W2 upsert 패턴).
///
/// stores/{storeId}/menuOverrides/{masterMenuItemId}.disabledOption* upsert.
class UpdateDisabledOptionsForOverrideUseCase {
  final MenuOverrideRepository _repository;
  UpdateDisabledOptionsForOverrideUseCase(this._repository);

  Future<void> call(
    MenuOverrideEntity override, {
    required List<String> disabledGroupIds,
    required List<String> disabledItemIds,
  }) =>
      _repository.updateOverrideOperationFields(
        override.copyWith(
          disabledOptionGroupIds: disabledGroupIds,
          disabledOptionItemIds: disabledItemIds,
        ),
      );
}
