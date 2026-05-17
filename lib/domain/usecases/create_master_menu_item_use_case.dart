import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/repositories/master_menu_item_repository.dart';

class CreateMasterMenuItemUseCase {
  final MasterMenuItemRepository _repository;

  const CreateMasterMenuItemUseCase(this._repository);

  /// 반환값: 생성된 menuItemId.
  Future<String> call(MenuItemEntity item) =>
      _repository.createMasterMenuItem(item);
}
