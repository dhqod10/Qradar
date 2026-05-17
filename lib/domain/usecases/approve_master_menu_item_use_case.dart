import 'package:qradar/domain/repositories/master_menu_item_repository.dart';

class ApproveMasterMenuItemUseCase {
  final MasterMenuItemRepository _repository;

  const ApproveMasterMenuItemUseCase(this._repository);

  Future<void> call(String brandId, String menuItemId, String adminUid) =>
      _repository.approveMasterMenuItem(brandId, menuItemId, adminUid);
}
