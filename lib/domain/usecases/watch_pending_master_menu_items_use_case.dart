import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/repositories/master_menu_item_repository.dart';

class WatchPendingMasterMenuItemsUseCase {
  final MasterMenuItemRepository _repository;

  const WatchPendingMasterMenuItemsUseCase(this._repository);

  /// collectionGroup query 로 모든 브랜드의 pending 마스터 메뉴를 반환.
  Stream<List<MenuItemEntity>> call() => _repository.watchPendingForAdmin();
}
