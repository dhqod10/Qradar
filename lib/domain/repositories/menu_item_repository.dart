import 'package:qradar/domain/entities/menu_item_entity.dart';

/// 매장 메뉴 Repository 인터페이스.
///
/// - case A (brandId==null 개인 매장): stores/{storeId}/menuItems 단순 stream.
/// - case B (brandId!=null 브랜드 매장): master + overrides + storeOnly 머지 stream (U8).
abstract class MenuItemRepository {
  /// 매장의 모든 메뉴 stream. displayOrder asc.
  ///
  /// brandId != null 인 매장은 case B 머지 결과 반환 (sub-phase 3 활성화).
  Stream<List<MenuItemEntity>> watchByStore(String storeId, {String? brandId});

  /// 매장 내 단일 메뉴 stream. 삭제되면 null.
  Stream<MenuItemEntity?> watchById({
    required String storeId,
    required String menuItemId,
  });

  // ─── 신규 (sub-phase 3) — 점포 한정 메뉴 CRUD ───────────────────────

  /// 점포 한정 메뉴 생성. scope=store, brandId=store.brandId, status=pending 강제.
  /// 반환값: 생성된 menuItemId.
  Future<String> createStoreOnlyMenu(MenuItemEntity item);

  /// 점포 한정 메뉴 핵심 필드 수정. status=pending 회귀.
  Future<void> updateStoreOnlyMenuCore(MenuItemEntity item);

  /// 점포 한정 메뉴 운영 필드 수정. status/승인 메타 보존 즉시 반영.
  Future<void> updateStoreOnlyMenuOperation(MenuItemEntity item);

  /// 점포 한정 메뉴 삭제.
  Future<void> deleteStoreOnlyMenu(String storeId, String menuItemId);

  /// admin 승인 큐: scope==store && status==pending 점포 한정 메뉴 (collectionGroup query).
  Stream<List<MenuItemEntity>> watchPendingStoreOnlyMenus();

  /// admin 점포 한정 메뉴 승인.
  Future<void> approveStoreOnlyMenu(
      String storeId, String menuItemId, String adminUid);

  /// admin 점포 한정 메뉴 반려.
  Future<void> rejectStoreOnlyMenu(
      String storeId, String menuItemId, String adminUid, String reason);
}
