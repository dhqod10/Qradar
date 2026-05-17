// 결정 J 적용으로 폐기됨. UpdateMasterMenuItemCoreUseCase / UpdateMasterMenuItemOperationUseCase 사용.
// ignore_for_file: deprecated_member_use_from_same_package
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/repositories/master_menu_item_repository.dart';

@Deprecated(
  'Use UpdateMasterMenuItemCoreUseCase or UpdateMasterMenuItemOperationUseCase. '
  'Removed in favour of decision-J field split.',
)
class UpdateMasterMenuItemUseCase {
  final MasterMenuItemRepository _repository;

  const UpdateMasterMenuItemUseCase(this._repository);

  /// 수정 시 status=pending 으로 회귀 (S3). — 폐기됨.
  @Deprecated('Use updateMasterMenuItemCore / updateMasterMenuItemOperation.')
  Future<void> call(MenuItemEntity item) =>
      _repository.updateMasterMenuItemCore(item);
}
