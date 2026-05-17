import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/repositories/master_menu_item_repository.dart';

/// 마스터 메뉴 운영 필드 수정 UseCase (결정 J — 메서드 분리).
///
/// 운영 필드: visible, tags, displayOrder, imageUrl.
/// status / 승인 메타 모두 보존. updatedAt 만 갱신. customer 측 즉시 반영.
class UpdateMasterMenuItemOperationUseCase {
  final MasterMenuItemRepository _repository;

  const UpdateMasterMenuItemOperationUseCase(this._repository);

  Future<void> call(MenuItemEntity item) =>
      _repository.updateMasterMenuItemOperation(item);
}
