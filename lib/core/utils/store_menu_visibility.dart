/// "이 메뉴가 매장 메뉴 화면에 보이는가" — 단일 판정 (design §1 F5).
///
/// 매장 메뉴 화면(`filteredMenuItemsProvider`)과 홈 검색 결과(`menuSearchResultsProvider`)가
/// **같은 함수**를 써서 "검색에 걸렸는데 매장 화면에는 없다" 를 구조적으로 막는다.
/// 기준: 고객 노출(`visible`) + 활성 메인 카테고리. 순수 Dart.
bool isMenuShownOnStoreScreen({
  required bool visible,
  required String mainCategoryCode,
  required Set<String> activeCategoryIds,
}) {
  return visible && activeCategoryIds.contains(mainCategoryCode);
}
