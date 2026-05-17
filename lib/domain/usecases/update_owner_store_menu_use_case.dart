import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';

/// 개인 매장 점주의 메뉴 수정 UseCase (sub-phase 4, V2 — Core/Operation 통합).
///
/// RepositoryImpl 의 updateStoreOnlyMenuCore 를 호출.
/// 개인 매장 분기에서 status=approved 강제 + 승인 메타 null 처리.
class UpdateOwnerStoreMenuUseCase {
  final MenuItemRepository _repository;

  UpdateOwnerStoreMenuUseCase(this._repository);

  Future<void> call(MenuItemEntity item) {
    return _repository.updateStoreOnlyMenuCore(item);
  }
}
