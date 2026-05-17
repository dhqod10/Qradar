import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';

/// admin 점포 한정 메뉴 승인 큐 UseCase (collectionGroup, scope==store && status==pending).
class WatchPendingStoreOnlyMenusUseCase {
  final MenuItemRepository _repository;

  WatchPendingStoreOnlyMenusUseCase(this._repository);

  Stream<List<MenuItemEntity>> call() {
    return _repository.watchPendingStoreOnlyMenus();
  }
}
