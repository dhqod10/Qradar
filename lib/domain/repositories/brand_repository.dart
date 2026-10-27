import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/brand_key_lookup.dart';
import 'package:qradar/domain/entities/brand_private_profile_entity.dart';
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
  /// - [privateProfile] (사업자 PII 5개) 는 부모 문서 쓰기와 **분리**해 `private/profile` 에 merge-set 한다.
  ///   PII 만 바뀌어도 status 는 회귀하지 않는다. **brandKey 는 어떤 경우에도 쓰지 않는다** (CF 전담).
  ///   null 이면 private 쓰기를 건너뛴다.
  ///
  /// 반환값: 저장된 brandId.
  Future<String> upsertBrand(
    BrandEntity brand, {
    BrandPrivateProfileEntity? privateProfile,
  });

  /// 브랜드 비공개 프로필(brandKey + PII) 실시간 감시. 문서가 없으면 null.
  /// **읽기 실패는 스트림 에러다** — 빈 프로필/미발급으로 폴백하지 않는다.
  Stream<BrandPrivateProfileEntity?> watchPrivateProfile(String brandId);

  /// 비공개 프로필 단발성 조회. 문서가 없으면 null, **읽기 실패는 예외**.
  Future<BrandPrivateProfileEntity?> fetchPrivateProfile(String brandId);

  /// 브랜드 승인. admin 전용.
  ///
  /// 서버 `issueBrandKey` 가 **성공한 뒤에만** 상태를 승인으로 바꾼다 (키 없는 승인 금지).
  /// 발급 실패는 `BrandKeyIssueException` — 이 경우 브랜드 문서는 변하지 않는다.
  Future<void> approveBrand(String brandId, String adminUid);

  /// 브랜드 반려. admin 전용.
  Future<void> rejectBrand(String brandId, String adminUid, String reason);

  /// 브랜드 삭제. 매장이 연결된 경우 차단 (sub-phase 2 이후 의미).
  Future<void> deleteBrand(String brandId);

  // ─── 신규 (sub-phase 3) ───────────────────────────────────────────────

  /// brand 가 운영하는 매장 리스트 실시간 감시. brand 본인의 brandId 만 호출 가능.
  Stream<List<StoreEntity>> watchStoresByBrand(String brandId);

  // ─── 신규 (sub-phase 6) ───────────────────────────────────────────────

  /// brandKey 로 승인된 브랜드를 서버(`lookupBrandByKey`)에서 조회한다 (V4).
  ///
  /// 미존재·미승인은 구분되지 않는다. 실패는 `BrandKeyLookupException`
  /// (notFound / rateLimited / failed) — 조회 실패를 "없는 키" 로 읽지 않는다.
  Future<BrandKeyLookup> lookupBrandByKey(String brandKey);

  // ─── brand_authorization_hardening (D1) ────────────────────────────────

  /// 내가 제출한 브랜드들 (`brands where submittedBy == 내 uid`), 가장 이른 `submittedAt` 순. 없으면 빈 목록.
  ///
  /// 조회 **실패는 예외**다 — 빈 목록과 구별해야 한다 (실패를 "0건" 으로 읽으면 이미 등록한 사용자가 등록 폼으로 떨어져
  /// 같은 브랜드를 다시 등록하고 고아 브랜드가 쌓인다).
  Future<List<BrandEntity>> fetchMySubmittedBrands();

  /// 내가 제출한 브랜드를 내 계정에 연결한다 (`users.brandId` 는 Cloud Function 만 쓴다). 멱등.
  /// 실패는 [BrandClaimException].
  Future<void> claimSubmittedBrand(String brandId);
}
