import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';

/// 점포 한정 메뉴 생성 UseCase (brand 전용). scope=store, status=pending 강제.
class CreateStoreOnlyMenuUseCase {
  final MenuItemRepository _repository;

  CreateStoreOnlyMenuUseCase(this._repository);

  Future<String> call(MenuItemEntity item) {
    return _repository.createStoreOnlyMenu(item);
  }
}
