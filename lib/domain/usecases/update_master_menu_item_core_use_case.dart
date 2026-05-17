import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/repositories/master_menu_item_repository.dart';

/// 마스터 메뉴 핵심 필드 수정 UseCase (결정 J — 메서드 분리).
///
/// 핵심 필드: name, basePrice, optionGroupRefs, mainCategoryCode, subCategoryId, description.
/// 수정 시 status=pending 회귀 + submittedBy/At 갱신 + approvedBy/At 보존.
class UpdateMasterMenuItemCoreUseCase {
  final MasterMenuItemRepository _repository;

  const UpdateMasterMenuItemCoreUseCase(this._repository);

  Future<void> call(MenuItemEntity item) =>
      _repository.updateMasterMenuItemCore(item);
}
