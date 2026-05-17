import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';
import 'package:qradar/domain/repositories/menu_override_repository.dart';

/// 개인 매장 / 브랜드 매장 점포 한정 메뉴 품절 토글 (sub-phase 5).
///
/// stores/{storeId}/menuItems/{menuItemId}.soldOut partial update.
class ToggleSoldOutForPersonalMenuUseCase {
  final MenuItemRepository _repository;
  ToggleSoldOutForPersonalMenuUseCase(this._repository);

  Future<void> call(MenuItemEntity item, bool soldOut) =>
      _repository.updateStoreOnlyMenuOperation(item.copyWith(soldOut: soldOut));
}

/// 브랜드 매장 마스터 메뉴 ref 품절 토글 (sub-phase 5 — W2 upsert 패턴).
///
/// stores/{storeId}/menuOverrides/{masterMenuItemId}.soldOut upsert.
class ToggleSoldOutForOverrideUseCase {
  final MenuOverrideRepository _repository;
  ToggleSoldOutForOverrideUseCase(this._repository);

  Future<void> call(MenuOverrideEntity override, bool soldOut) =>
      _repository.updateOverrideOperationFields(
        override.copyWith(soldOut: soldOut),
      );
}
