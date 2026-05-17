import 'package:qradar/domain/repositories/menu_item_repository.dart';

/// 개인 매장 점주의 메뉴 삭제 UseCase (sub-phase 4).
class DeleteOwnerStoreMenuUseCase {
  final MenuItemRepository _repository;

  DeleteOwnerStoreMenuUseCase(this._repository);

  Future<void> call(String storeId, String menuItemId) {
    return _repository.deleteStoreOnlyMenu(storeId, menuItemId);
  }
}
