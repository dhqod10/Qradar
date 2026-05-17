/// Phase 2 자동 추천 로직에서 사용할 임계값 상수.
///
/// Phase 2 부터 실제 사용. 우산 spec `docs/tasks/order_flow_phase1/spec.md` 결정 8
/// + Phase 2 spec 결정 F 잠정값.
///
/// 의미:
/// - frequentStoreLookbackDays / frequentStoreMinVisits:
///   "최근 N일 동안 동일 매장 M회 이상 이용" → 단골 매장으로 간주.
/// - frequentStoreLookbackDaysAlt / frequentStoreMinVisitsAlt:
///   대체 임계값 (4주 / 3주 기준 등 A/B 비교용).
/// - frequentMenuPairLookbackDays / frequentMenuPairMinVisits:
///   "최근 N일 동안 같은 매장-음료 페어를 M회 이상 주문" → 단골 음료.
/// - favoriteScoreBoost:
///   즐겨찾기로 등록된 매장/메뉴에 더해지는 점수 부스트 (additive).
///   Phase 2 spec 결정 F 잠정값 = 5. 즐겨찾기만으로 임계값을 못 넘게 하기 위해
///   `frequentStoreMinVisits(5)` 와 동일하게 둔다 (visitCount 0 + boost 5 = 5
///   ≥ 5 라 통과 가능하지만 visitCount 0 이면 결정 F 의 "임계값 미달 노출 X"
///   해석상 visitCount > 0 추가 가드는 UseCase 가 적용).
/// - quickReorderMaxItems / frequentStoreMaxItems / frequentMenuPairMaxItems:
///   추천 카드 최대 노출 개수 (design.md 명세).
class RecommendationThresholds {
  RecommendationThresholds._();

  static const int frequentStoreLookbackDays = 30;
  static const int frequentStoreMinVisits = 5;

  static const int frequentStoreLookbackDaysAlt = 28;
  static const int frequentStoreMinVisitsAlt = 21;

  static const int frequentMenuPairLookbackDays = 30;
  static const int frequentMenuPairMinVisits = 3;

  /// 즐겨찾기 additive 점수 부스트.
  static const int favoriteScoreBoost = 5;

  /// "다시 주문하기" 카드 최대 개수.
  static const int quickReorderMaxItems = 3;

  /// "자주 찾는 매장" 카드 최대 개수.
  static const int frequentStoreMaxItems = 5;

  /// "자주 찾는 메뉴" 카드 최대 개수.
  static const int frequentMenuPairMaxItems = 5;
}
