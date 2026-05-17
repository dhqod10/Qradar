import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';

/// 개인 매장 점주의 메뉴 신규 등록 UseCase (sub-phase 4).
///
/// RepositoryImpl 내부에서 brandId==null 분기 → status=approved 강제 + 승인 메타 null.
class CreateOwnerStoreMenuUseCase {
  final MenuItemRepository _repository;

  CreateOwnerStoreMenuUseCase(this._repository);

  Future<String> call(MenuItemEntity item) {
    return _repository.createStoreOnlyMenu(item);
  }
}
