import 'package:qradar/domain/repositories/menu_item_repository.dart';

/// admin 점포 한정 메뉴 승인 UseCase.
class ApproveStoreOnlyMenuUseCase {
  final MenuItemRepository _repository;

  ApproveStoreOnlyMenuUseCase(this._repository);

  Future<void> call(String storeId, String menuItemId, String adminUid) {
    return _repository.approveStoreOnlyMenu(storeId, menuItemId, adminUid);
  }
}
