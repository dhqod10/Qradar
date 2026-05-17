import 'package:qradar/domain/entities/menu_item_entity.dart';

/// 브랜드 마스터 메뉴 Repository 인터페이스.
///
/// 대상 컬렉션: `brands/{brandId}/menuItems/{menuItemId}`
abstract class MasterMenuItemRepository {
  /// 특정 브랜드의 마스터 메뉴 전체 스트림 (brand 본인 + admin).
  Stream<List<MenuItemEntity>> watchByBrand(String brandId);

  /// status == pending 인 마스터 메뉴 전체 스트림 (collectionGroup query).
  /// admin 승인 큐 전용.
  Stream<List<MenuItemEntity>> watchPendingForAdmin();

  /// 마스터 메뉴 생성. scope=brand, status=pending 강제.
  /// 반환값: 생성된 menuItemId.
  Future<String> createMasterMenuItem(MenuItemEntity item);

  // ─── S3: 핵심/운영 분리 (umbrella 결정 J — 메서드 분리 채택) ─────────
  /// 핵심 필드 (name, basePrice, optionGroupRefs, mainCategoryCode, subCategoryId, description) 변경.
  ///
  /// status=pending 으로 회귀 + submittedBy/At 갱신 + approvedBy/At 보존 (수정 대기 라벨용).
  Future<void> updateMasterMenuItemCore(MenuItemEntity item);

  /// 운영 필드 (visible, tags, displayOrder, imageUrl) 변경.
  ///
  /// status / 승인 메타 모두 보존. updatedAt 만 갱신. customer 측 즉시 반영.
  Future<void> updateMasterMenuItemOperation(MenuItemEntity item);

  /// 마스터 메뉴 삭제 + cascade (S9).
  ///
  /// 1. `brands/{brandId}/menuItems/{menuItemId}` 삭제
  /// 2. collectionGroup 으로 모든 매장의 `menuOverrides/{menuItemId}` batch delete
  ///    (본 sub-phase: cascade 대상 0건)
  Future<void> deleteWithCascade(String brandId, String menuItemId);

  /// 원본 메뉴를 draft 로 복제. DB 저장하지 않음.
  ///
  /// copyWith: id='', name='{원본} 복사', status=null, 승인 메타 reset.
  Future<MenuItemEntity> cloneAsDraft(String brandId, String sourceId);

  /// 해당 마스터 메뉴에 priceOverride 가 적용된 매장 수 조회 (S8).
  /// 본 sub-phase 에서는 항상 0 반환.
  Future<int> countStoresUsingPriceOverride(
      String brandId, String menuItemId);

  /// 마스터 메뉴 승인. admin 전용.
  Future<void> approveMasterMenuItem(
      String brandId, String menuItemId, String adminUid);

  /// 마스터 메뉴 반려. admin 전용.
  Future<void> rejectMasterMenuItem(
      String brandId, String menuItemId, String adminUid, String reason);

  /// 마스터 메뉴 일괄 승인. admin 전용. WriteBatch 사용.
  Future<void> bulkApprove(
      String brandId, List<String> menuItemIds, String adminUid);

  /// 마스터 메뉴 일괄 반려. admin 전용. WriteBatch 사용.
  Future<void> bulkReject(
      String brandId, List<String> menuItemIds, String adminUid, String reason);
}
