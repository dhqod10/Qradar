import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/user_location.dart';

/// 매장 Repository 인터페이스.
///
/// Firebase ↔ AWS 마이그레이션 대비: Presentation/Domain은 이 인터페이스에만 의존.
/// sub-phase 2: 승인 게이트 메서드 + 핵심/운영 필드 분리(결정 J) 추가.
abstract class StoreRepository {
  // ── 기존 (Phase 1a) ─────────────────────────────────────────────────────

  /// 사용자 위치 기준 주변 매장 조회 (status=approved 필터 적용, T7).
  Future<List<StoreEntity>> getNearbyStores({
    required UserLocation location,
    required double radiusKm,
    int limit = 10,
  });

  /// 선택된 카테고리에 해당하는 매장 조회 (status=approved 필터 적용, T7).
  Future<List<StoreEntity>> getStoresByCategories({
    required List<String> categories,
    required UserLocation location,
  });

  /// 매장 삭제 (연관 이미지 삭제는 호출부 책임).
  Future<void> deleteStore(String storeId);

  /// 특정 ownerId 의 매장을 실시간 감시. MVP 기준 owner 당 매장은 최대 1개이므로 단일 엔티티 반환.
  Stream<StoreEntity?> watchByOwner(String ownerId);

  // ── 신규 (sub-phase 2) ──────────────────────────────────────────────────

  /// 매장 단건 조회 (admin 상세 진입용).
  Future<StoreEntity?> getById(String storeId);

  /// admin 전체 매장 실시간 감시 (status 무관).
  Stream<List<StoreEntity>> watchAllForAdmin();

  /// admin 승인 큐: status=pending 매장만 실시간 감시.
  Stream<List<StoreEntity>> watchPendingStoresForAdmin();

  /// admin 매장 승인.
  Future<void> approveStore(String storeId, String adminUid);

  /// admin 매장 반려.
  Future<void> rejectStore(String storeId, String adminUid, String reason);

  /// 점주 매장 등록 / 핵심 필드 수정 통합 진입점 (결정 J).
  ///
  /// - [store.id] 가 빈 문자열이면 신규 등록: status=pending, brandId=null 강제.
  /// - [store.id] 가 있으면 updateStoreCoreFields 위임.
  Future<void> submitStoreForApproval(StoreEntity store);

  /// 매장 핵심 필드 수정 (결정 J, T2).
  ///
  /// status=pending 회귀 + submittedBy/At 갱신 + approvedBy/At 보존.
  /// rejected 상태에서 호출 시 T3 동작 (재제출: approvedBy/At/rejectedReason 모두 null 클리어).
  Future<void> updateStoreCoreFields(StoreEntity store);

  /// 매장 운영 필드 수정 (결정 J, T2).
  ///
  /// status / 승인 메타 모두 보존. 운영 필드만 partial update. 즉시 반영.
  Future<void> updateStoreOperationFields(StoreEntity store);

  // ── Deprecated ──────────────────────────────────────────────────────────

  /// @deprecated sub-phase 2에서 submitStoreForApproval / updateStoreCoreFields 로 대체.
  @Deprecated('submitStoreForApproval 또는 updateStoreCoreFields 사용')
  Future<String> createStore(StoreEntity store);

  /// @deprecated sub-phase 2에서 submitStoreForApproval / updateStoreCoreFields 로 대체.
  @Deprecated('updateStoreCoreFields 또는 updateStoreOperationFields 사용')
  Future<void> updateStore(StoreEntity store);
}
