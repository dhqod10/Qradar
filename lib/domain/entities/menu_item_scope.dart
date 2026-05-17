/// 메뉴 아이템 출처 범위.
///
/// - `brand`: 브랜드가 등록한 마스터 메뉴 (`brands/{brandId}/menuItems/{id}`)
/// - `store`: 매장이 등록한 개별 메뉴 (`stores/{storeId}/menuItems/{id}`)
enum MenuItemScope {
  brand,
  store;

  String get asString => name;

  static MenuItemScope fromString(String? v) {
    switch (v) {
      case 'brand':
        return MenuItemScope.brand;
      default:
        return MenuItemScope.store;
    }
  }
}
