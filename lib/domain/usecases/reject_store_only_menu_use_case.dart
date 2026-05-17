import 'package:qradar/domain/repositories/menu_item_repository.dart';

/// admin 점포 한정 메뉴 반려 UseCase.
class RejectStoreOnlyMenuUseCase {
  final MenuItemRepository _repository;

  RejectStoreOnlyMenuUseCase(this._repository);

  Future<void> call(
    String storeId,
    String menuItemId,
    String adminUid,
    String reason,
  ) {
    return _repository.rejectStoreOnlyMenu(storeId, menuItemId, adminUid, reason);
  }
}
