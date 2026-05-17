import 'package:freezed_annotation/freezed_annotation.dart';

part 'main_category_entity.freezed.dart';

/// 글로벌 메인 카테고리 엔티티.
///
/// admin 이 Firestore `mainCategories/{id}` 에 등록/수정/비활성화 가능.
/// [id] 는 Firestore 문서 id (예: `coffee`, `nonCoffee`, `dessert`, `bakery`).
@freezed
abstract class MainCategoryEntity with _$MainCategoryEntity {
  const factory MainCategoryEntity({
    required String id,
    required String label,
    @Default(0) int displayOrder,
    @Default(true) bool active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _MainCategoryEntity;
}
