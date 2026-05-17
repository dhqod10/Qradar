import 'package:qradar/domain/repositories/master_menu_item_repository.dart';

class RejectMasterMenuItemUseCase {
  final MasterMenuItemRepository _repository;

  const RejectMasterMenuItemUseCase(this._repository);

  Future<void> call(
          String brandId, String menuItemId, String adminUid, String reason) =>
      _repository.rejectMasterMenuItem(brandId, menuItemId, adminUid, reason);
}
