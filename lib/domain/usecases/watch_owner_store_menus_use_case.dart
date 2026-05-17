import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';

/// 개인 매장 점주의 메뉴 목록 스트림 UseCase (sub-phase 4).
///
/// watchByStore(storeId, brandId: null) — case A 분기. 시그니처 불변.
class WatchOwnerStoreMenusUseCase {
  final MenuItemRepository _repository;

  WatchOwnerStoreMenusUseCase(this._repository);

  Stream<List<MenuItemEntity>> call(String storeId) {
    // brandId: null → case A (개인 매장)
    return _repository.watchByStore(storeId, brandId: null);
  }
}
