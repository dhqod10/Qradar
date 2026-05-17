import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/store_entity.dart';

part 'frequent_store_entity.freezed.dart';

/// "자주 찾는 매장" 카드 1건.
///
/// 빈도(visitCount) + 즐겨찾기 boost 로 점수를 계산해 정렬한다.
/// 카드 onTap → `StoreMenuPage(store)` 진입에 [store] 가 그대로 사용된다.
@freezed
abstract class FrequentStoreEntity with _$FrequentStoreEntity {
  const factory FrequentStoreEntity({
    required String storeId,
    required String storeName,

    /// 최근 lookbackDays 기간 내 OrderLog 매장별 카운트.
    @Default(0) int visitCount,

    /// 사용자가 해당 매장을 즐겨찾기로 등록했는지.
    @Default(false) bool isFavorite,

    /// `visitCount + (isFavorite ? favoriteScoreBoost : 0)`.
    @Default(0) int score,

    /// 매장 메타 (StoreMenuPage 진입에 사용).
    /// 매장 stream 에서 매칭되지 않으면 null — 카드 자체를 hide.
    StoreEntity? store,
  }) = _FrequentStoreEntity;
}
