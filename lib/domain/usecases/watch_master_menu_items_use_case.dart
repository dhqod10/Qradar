import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/repositories/master_menu_item_repository.dart';

class WatchMasterMenuItemsUseCase {
  final MasterMenuItemRepository _repository;

  const WatchMasterMenuItemsUseCase(this._repository);

  Stream<List<MenuItemEntity>> call(String brandId) =>
      _repository.watchByBrand(brandId);
}
