import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';

class WatchMenuItemDetailUseCase {
  final MenuItemRepository _repository;
  WatchMenuItemDetailUseCase(this._repository);

  Stream<MenuItemEntity?> call({
    required String storeId,
    required String menuItemId,
  }) =>
      _repository.watchById(storeId: storeId, menuItemId: menuItemId);
}
