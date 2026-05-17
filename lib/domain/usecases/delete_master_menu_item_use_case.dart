import 'package:qradar/domain/repositories/master_menu_item_repository.dart';

class DeleteMasterMenuItemUseCase {
  final MasterMenuItemRepository _repository;

  const DeleteMasterMenuItemUseCase(this._repository);

  /// 삭제 + cascade (S9). 본 sub-phase 에서 cascade 대상 0건.
  Future<void> call(String brandId, String menuItemId) =>
      _repository.deleteWithCascade(brandId, menuItemId);
}
