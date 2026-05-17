import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';

/// 점포 한정 메뉴 핵심 필드 수정 UseCase (brand 전용). status=pending 회귀.
class UpdateStoreOnlyMenuCoreUseCase {
  final MenuItemRepository _repository;

  UpdateStoreOnlyMenuCoreUseCase(this._repository);

  Future<void> call(MenuItemEntity item) {
    return _repository.updateStoreOnlyMenuCore(item);
  }
}
