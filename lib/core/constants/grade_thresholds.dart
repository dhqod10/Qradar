/// 등급 계산 임계값 상수.
///
/// 사용자가 매장에 S/A/B/C 4단계로 평가를 남기면,
/// 내부 점수(S=4, A=3, B=2, C=1)의 평균을 구해 아래 임계값으로 최종 등급 판정.
///
/// 향후 Firebase Remote Config로 전환 가능하도록 상수로 격리.
class GradeThresholds {
  GradeThresholds._();

  // 내부 점수 (사용자에게 노출되지 않음)
  static const int sScore = 4;
  static const int aScore = 3;
  static const int bScore = 2;
  static const int cScore = 1;

  // 평균 점수 → 등급 판정 임계값
  static const double sMin = 3.5;
  static const double aMin = 2.5;
  static const double bMin = 1.5;
  // C급: 1.0 ~ 1.4

  // 주변 매장 조회 반경 (km)
  static const double nearbyRadiusKm = 20.0;

  // 주문 화면 매장 조회 반경 + 개수 상한
  static const double orderRadiusKm = 10.0;
  static const int orderStoresLimit = 50;

  // ── 홈 검색 / 추천 전체보기 (docs/tasks/home_search/spec.md §9.3) ─────────
  // 상수는 이 한 곳에만 둔다 — 리터럴을 위젯에 흩뿌리면 spec §5.3 전환 트리거를 코드에서 찾을 수 없게 된다.

  /// 메뉴 검색 후보 매장 반경 (km).
  static const double searchRadiusKm = 10.0;

  /// 메뉴 검색 후보 매장 수 (가까운 순 상위). 메뉴 인덱스 쿼리 수의 상한이 된다.
  static const int menuSearchStoreLimit = 30;

  /// 메뉴 결과 표시 상한 (행).
  static const int menuSearchResultLimit = 30;

  /// 메뉴 검색 2단계(override 검증) fan-out 상한 — 일치한 distinct 브랜드 매장 중 가까운 N곳만 읽는다 (최악 쿼리 천장).
  static const int menuSearchVerifyStoreLimit = 10;

  /// 홈 `맞춤 추천` 미리보기 건수.
  static const int recommendedPreviewCount = 5;

  /// 최근 검색어 보관 건수 (세션 메모리).
  static const int recentSearchLimit = 10;

  /// 검색 입력 debounce (ms). 주문 탭 매장 검색과 같다.
  static const int searchDebounceMs = 250;

  /// 메뉴 검색을 시작하는 최소 글자 수 (정규화 후). 매장 검색은 1글자부터.
  static const int menuSearchMinQueryLength = 2;

  // 기본 위치 (서울 시청) — 위치 권한 거부 시 폴백
  static const double defaultLatitude = 37.5665;
  static const double defaultLongitude = 126.9780;
}
