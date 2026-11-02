import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/store_page.dart';
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

  /// 승인 매장 전체(거리 계산 + 가까운 순) — 홈 스냅샷 전용. 반경·개수 절단은 호출 측(파생 provider) 책임.
  /// 쿼리는 [getNearbyStores] 와 같은 1회 `fetchAll`(100건) — 홈 진입 읽기를 200 -> 100 으로 줄이는 단일 원본.
  Future<List<StoreEntity>> getApprovedStores({
    required UserLocation location,
    int limit = 100,
  });

  /// 주변매장 전체보기용 — [center] 기준 반경 [radiusKm] 이내 승인 매장 전부를 가까운 순으로 (geohash 근접 쿼리).
  /// 반경이 페이지 경계다 (store_list_pagination). 홈 스냅샷(`getApprovedStores`)과 독립.
  Future<StorePage> getNearbyStoresPaged({
    required UserLocation center,
    required double radiusKm,
  });

  /// 선택된 카테고리에 해당하는 매장 조회 (status=approved 필터 적용, T7).
  Future<List<StoreEntity>> getStoresByCategories({
    required List<String> categories,
    required UserLocation location,
  });

  // 매장 삭제는 클라이언트에서 하지 않는다 — admin 전용 서버 `deleteStore` (StoreDeletionRepository).

  /// 특정 ownerId 의 매장을 실시간 감시. MVP 기준 owner 당 매장은 최대 1개이므로 단일 엔티티 반환.
  Stream<StoreEntity?> watchByOwner(String ownerId);

  // ── 신규 (sub-phase 2) ──────────────────────────────────────────────────

  /// 매장 단건 조회 (admin 상세 진입용).
  Future<StoreEntity?> getById(String storeId);

  /// 매장 단건 실시간 감시. 평가 반영(CF 집계) 같은 외부 갱신을 즉시 반영해야 할 때 쓴다.
  Stream<StoreEntity?> watchById(String storeId);

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
