import 'package:qradar/domain/repositories/menu_item_repository.dart';

/// 점포 한정 메뉴 삭제 UseCase (brand 전용).
class DeleteStoreOnlyMenuUseCase {
  final MenuItemRepository _repository;

  DeleteStoreOnlyMenuUseCase(this._repository);

  Future<void> call(String storeId, String menuItemId) {
    return _repository.deleteStoreOnlyMenu(storeId, menuItemId);
  }
}
