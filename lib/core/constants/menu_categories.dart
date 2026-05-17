/// Qradar 앱에서 지원하는 12개 메뉴 카테고리.
/// 매장이 제공하는 카테고리 매칭 및 홈 화면 필터 칩 표시에 사용.
class MenuCategories {
  MenuCategories._();

  static const List<String> all = [
    '추천메뉴',
    '커피',
    '우리의 디카페인',
    '논커피/파일라떼',
    '티',
    '스무디/프라페',
    '에이드/쥬스',
    '밀크쉐이크',
    '아이스크림',
    '푸드/디저트',
    'MD상품',
    '콜라보 메뉴',
  ];

  static const String defaultSelected = '추천메뉴';
}
