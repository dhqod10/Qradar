import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';

/// 점포 한정 메뉴 운영 필드 수정 UseCase (brand 전용). status/승인 메타 보존 즉시 반영.
class UpdateStoreOnlyMenuOperationUseCase {
  final MenuItemRepository _repository;

  UpdateStoreOnlyMenuOperationUseCase(this._repository);

  Future<void> call(MenuItemEntity item) {
    return _repository.updateStoreOnlyMenuOperation(item);
  }
}
