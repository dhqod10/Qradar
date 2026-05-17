import 'package:qradar/domain/entities/menu_override_entity.dart';

/// 매장 메뉴 오버라이드 Repository 인터페이스.
///
/// - brand role: watchByStore, upsertOverrideCore, deleteOverride, seedExclusionsForStore
/// - admin role: watchPendingForAdmin, approveOverride, rejectOverride, deleteAllForMaster
abstract class MenuOverrideRepository {
  /// 특정 매장의 override 목록 실시간 감시.
  Stream<List<MenuOverrideEntity>> watchByStore(String storeId);

  /// admin 승인 큐: status==pending override 전체 (collectionGroup query).
  Stream<List<MenuOverrideEntity>> watchPendingForAdmin();

  /// 단건 조회.
  Future<MenuOverrideEntity?> getByStoreAndMaster(
    String storeId,
    String masterMenuItemId,
  );

  /// 핵심 필드(priceOverride / excluded) 변경.
  ///
  /// status=pending 회귀 + submittedBy/At 갱신 + approvedBy/At 보존.
  Future<void> upsertOverrideCore(MenuOverrideEntity override);

  /// 운영 필드(soldOut / disabledOption*) partial update + upsert (sub-phase 5 — W1/W2).
  ///
  /// - override 가 없으면 신규 생성: status='approved', priceOverride=null, excluded=false.
  /// - override 가 있으면 운영 필드만 partial update (status / 핵심 필드 보존).
  /// - admin 승인 게이트 없음 — 즉시 반영.
  Future<void> updateOverrideOperationFields(MenuOverrideEntity override);

  /// admin 승인.
  Future<void> approveOverride(
    String storeId,
    String masterMenuItemId,
    String adminUid,
  );

  /// admin 반려.
  Future<void> rejectOverride(
    String storeId,
    String masterMenuItemId,
    String adminUid,
    String reason,
  );

  /// override 삭제.
  Future<void> deleteOverride(String storeId, String masterMenuItemId);

  /// 마스터 메뉴 삭제 cascade (collectionGroup batch delete).
  ///
  /// MasterMenuItemRepository.deleteWithCascade 에서 호출.
  /// sub-phase 1 시그니처 그대로 + 본 sub-phase 에서 실제 batch delete 구현.
  Future<void> deleteAllForMaster(String masterMenuItemId);

  /// 매장 등록 시 미선택 마스터 메뉴를 일괄 excluded=true 로 batch seed (U2).
  Future<void> seedExclusionsForStore({
    required String storeId,
    required String brandId,
    required List<String> excludedMasterMenuItemIds,
  });

  /// 특정 마스터 메뉴에 priceOverride 를 가진 매장 수 반환 (U7).
  ///
  /// N>0 일 때 admin/brand UI 에서 "N개 매장의 가격 오버라이드에 영향 없습니다" 알림.
  Future<int> countStoresUsingPriceOverride(
    String brandId,
    String masterMenuItemId,
  );
}
