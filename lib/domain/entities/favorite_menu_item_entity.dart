import 'package:freezed_annotation/freezed_annotation.dart';

part 'favorite_menu_item_entity.freezed.dart';

/// Qrator 가 즐겨찾기한 매장-음료 페어.
///
/// 본 phase 에서는 인터페이스 호환용. 실제 사용은 Phase 1c.
@freezed
abstract class FavoriteMenuItemEntity with _$FavoriteMenuItemEntity {
  const factory FavoriteMenuItemEntity({
    required String storeId,
    required String menuItemId,
    required DateTime addedAt,
  }) = _FavoriteMenuItemEntity;
}
