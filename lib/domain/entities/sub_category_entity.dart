import 'package:freezed_annotation/freezed_annotation.dart';

part 'sub_category_entity.freezed.dart';

/// 부 카테고리 scope — brand 본사 소유 vs 개인 매장 소유.
enum SubCategoryScope { brand, store }

/// 부 카테고리.
///
/// - [scope] == `brand`: `brands/{brandId}/subCategories/{id}` 에 저장.
/// - [scope] == `store`: `stores/{storeId}/subCategories/{id}` 에 저장.
/// - 기존 글로벌 subCategories 컬렉션(`subCategoryScope==null`)은 legacy.
///
/// customer 측 호환: `mainCategoryCode` / `name` / `displayOrder` / `active` 를
/// 그대로 유지한다.
@freezed
abstract class SubCategoryEntity with _$SubCategoryEntity {
  const factory SubCategoryEntity({
    required String id,
    required String mainCategoryCode,
    required String name,
    @Default(0) int displayOrder,
    @Default(true) bool active,
    // ── 2-tier 신규 필드 ───────────────────────────────────────────────
    /// 소유 주체. null 이면 legacy global sub.
    SubCategoryScope? scope,
    /// brand scope 일 때 해당 brandId.
    String? brandId,
    /// store scope 일 때 해당 storeId.
    String? storeId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _SubCategoryEntity;
}
