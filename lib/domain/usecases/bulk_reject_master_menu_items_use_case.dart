import 'package:qradar/domain/repositories/master_menu_item_repository.dart';

/// 브랜드의 마스터 메뉴 여러 건을 일괄 반려. admin 전용.
class BulkRejectMasterMenuItemsUseCase {
  final MasterMenuItemRepository _repository;

  const BulkRejectMasterMenuItemsUseCase(this._repository);

  Future<void> call(String brandId, List<String> menuItemIds, String adminUid,
          String reason) =>
      _repository.bulkReject(brandId, menuItemIds, adminUid, reason);
}
