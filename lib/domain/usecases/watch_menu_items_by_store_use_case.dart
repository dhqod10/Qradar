import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';

class WatchMenuItemsByStoreUseCase {
  final MenuItemRepository _repository;
  WatchMenuItemsByStoreUseCase(this._repository);

  Stream<List<MenuItemEntity>> call(String storeId) =>
      _repository.watchByStore(storeId);
}
