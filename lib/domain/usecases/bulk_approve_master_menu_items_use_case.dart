import 'package:qradar/domain/repositories/master_menu_item_repository.dart';

/// 브랜드의 마스터 메뉴 여러 건을 일괄 승인. admin 전용.
class BulkApproveMasterMenuItemsUseCase {
  final MasterMenuItemRepository _repository;

  const BulkApproveMasterMenuItemsUseCase(this._repository);

  Future<void> call(
          String brandId, List<String> menuItemIds, String adminUid) =>
      _repository.bulkApprove(brandId, menuItemIds, adminUid);
}
