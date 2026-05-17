import 'package:freezed_annotation/freezed_annotation.dart';

part 'frequent_menu_item_entity.freezed.dart';

/// "자주 찾는 메뉴" 카드 1건 — 매장-메뉴 페어.
///
/// 페어별 빈도 (orderCount) + 즐겨찾기 boost 로 점수 계산.
/// 카드 onTap → `StoreMenuPage(storeId)` 진입.
@freezed
abstract class FrequentMenuItemEntity with _$FrequentMenuItemEntity {
  const factory FrequentMenuItemEntity({
    required String storeId,
    required String storeName,
    required String menuItemId,
    required String menuItemName,

    /// 메뉴 이미지 URL. 미존재 시 빈 문자열 (카드 fallback 아이콘).
    @Default('') String imageUrl,

    /// 기준 가격 (옵션 미반영). 표시용.
    @Default(0) int basePrice,

    /// 최근 lookbackDays 기간 내 매장-메뉴 페어 카운트.
    @Default(0) int orderCount,

    /// 사용자가 (storeId, menuItemId) 페어를 즐겨찾기로 등록했는지.
    @Default(false) bool isFavorite,

    /// `orderCount + (isFavorite ? favoriteScoreBoost : 0)`.
    @Default(0) int score,
  }) = _FrequentMenuItemEntity;
}
