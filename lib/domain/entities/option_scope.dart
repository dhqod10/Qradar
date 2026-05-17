/// 옵션 그룹 출처.
///
/// - `master`: 글로벌 시드 (legacy, deprecated — read-only 호환 유지. 신규 doc 생성 불가).
/// - `brand`: 브랜드 본사 CRUD (`brands/{brandId}/optionGroups/{id}`).
/// - `store`: 개인 매장 CRUD (`stores/{storeId}/optionGroups/{id}`).
enum OptionScope {
  /// @deprecated — legacy global seed. 본 phase 이후 신규 doc 생성 안 함.
  /// 기존 menuItem.optionGroupRefs 호환 read 만 유지.
  master,

  /// 브랜드 본사 소유. CRUD 가능.
  brand,

  /// 개인 매장 소유. CRUD 가능.
  store;

  static OptionScope fromString(String value) {
    switch (value) {
      case 'brand':
        return OptionScope.brand;
      case 'store':
        return OptionScope.store;
      case 'master':
      default:
        return OptionScope.master;
    }
  }

  String get asString {
    switch (this) {
      case OptionScope.master:
        return 'master';
      case OptionScope.brand:
        return 'brand';
      case OptionScope.store:
        return 'store';
    }
  }
}
