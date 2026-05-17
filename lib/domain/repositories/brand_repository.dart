import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';

/// 브랜드 Repository 인터페이스.
///
/// - brand role 사용자: `watchById`, `upsertBrand`
/// - admin role 사용자: `watchAll`, `watchPendingForAdmin`, `approveBrand`, `rejectBrand`
abstract class BrandRepository {
  /// 모든 브랜드 목록 스트림 (admin 전용).
  Stream<List<BrandEntity>> watchAll();

  /// status == pending 인 브랜드 목록 (admin 승인 큐).
  Stream<List<BrandEntity>> watchPendingForAdmin();

  /// 특정 brandId 의 브랜드 스트림 (brand 본인 / admin).
  Stream<BrandEntity?> watchById(String brandId);

  /// 브랜드 등록 또는 수정 (결정 J — 변경 필드 분석 안(a) 채택).
  ///
  /// - 신규 등록: 항상 status=pending 강제.
  /// - 기존 수정: name/description 변경 시 status=pending 회귀, logoUrl 만 변경 시 status 보존.
  ///
  /// 반환값: 저장된 brandId.
  Future<String> upsertBrand(BrandEntity brand);

  /// 브랜드 승인. admin 전용.
  Future<void> approveBrand(String brandId, String adminUid);

  /// 브랜드 반려. admin 전용.
  Future<void> rejectBrand(String brandId, String adminUid, String reason);

  /// 브랜드 삭제. 매장이 연결된 경우 차단 (sub-phase 2 이후 의미).
  Future<void> deleteBrand(String brandId);

  // ─── 신규 (sub-phase 3) ───────────────────────────────────────────────

  /// brand 가 운영하는 매장 리스트 실시간 감시. brand 본인의 brandId 만 호출 가능.
  Stream<List<StoreEntity>> watchStoresByBrand(String brandId);

  // ─── 신규 (sub-phase 6) ───────────────────────────────────────────────

  /// brandKey 로 brand 조회. status='approved' 인 brand 만 매칭 (V4).
  ///
  /// 미매칭 시 null. 점주 매장 등록 시 brandKey 검증 진입점.
  Future<BrandEntity?> findByBrandKey(String brandKey);
}
