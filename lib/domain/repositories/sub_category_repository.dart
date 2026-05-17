import 'package:qradar/domain/entities/sub_category_entity.dart';

/// 부 카테고리 Repository 인터페이스 (2-tier: brand / store scope).
abstract class SubCategoryRepository {
  // ── Stream ──────────────────────────────────────────────────────────────

  /// brand scope 부 카테고리 stream.
  /// [activeOnly] == true 이면 active=true 만.  displayOrder asc.
  Stream<List<SubCategoryEntity>> watchByBrand({
    required String brandId,
    bool activeOnly = false,
  });

  /// store scope 부 카테고리 stream.
  /// [activeOnly] == true 이면 active=true 만.  displayOrder asc.
  Stream<List<SubCategoryEntity>> watchByStore({
    required String storeId,
    bool activeOnly = false,
  });

  // ── 단건 조회 ────────────────────────────────────────────────────────────

  Future<SubCategoryEntity?> findById({
    required String id,
    required SubCategoryScope scope,
    String? brandId,
    String? storeId,
  });

  // ── 쓰기 ────────────────────────────────────────────────────────────────

  /// 등록 또는 수정 (set merge).
  /// 같은 scope 내 동일 이름이 있으면 [DuplicateSubCategoryNameException] throw.
  Future<void> upsert(SubCategoryEntity entity);

  /// active 토글 (즉시, confirm 없음).
  Future<void> toggleActive({
    required String id,
    required SubCategoryScope scope,
    required bool active,
    String? brandId,
    String? storeId,
  });

  /// 삭제.
  /// 사용 중(usageCount >= 1)이면 [SubCategoryInUseException] throw.
  Future<void> delete({
    required String id,
    required SubCategoryScope scope,
    String? brandId,
    String? storeId,
  });

  // ── 검증 ────────────────────────────────────────────────────────────────

  /// 같은 scope 내 동일 normalized name 이 있는지 조회.
  /// [excludeId] 지정 시 해당 id 는 제외 (수정 시 자기 자신 제외).
  Future<bool> findDuplicateName({
    required String name,
    required SubCategoryScope scope,
    String? brandId,
    String? storeId,
    String? excludeId,
  });

  // ── 사용 수 ─────────────────────────────────────────────────────────────

  /// 해당 sub-category 를 참조하는 menuItem 수.
  Future<int> countUsage(String subCategoryId);
}
