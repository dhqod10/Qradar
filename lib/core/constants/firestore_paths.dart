/// Firestore 컬렉션/필드 경로 상수.
class FirestorePaths {
  FirestorePaths._();

  // ── Brand (sub-phase 1b) ───────────────────────────────────────────────
  /// 브랜드 컬렉션 `brands/{brandId}`.
  static const String brands = 'brands';

  /// 브랜드 마스터 메뉴 서브컬렉션 키 `brands/{brandId}/menuItems/{id}`.
  /// collectionGroup query 에서도 동일 키 사용.
  static const String brandMenuItems = 'menuItems';

  /// Firebase Storage 브랜드 이미지 경로 prefix.
  static const String brandImagesStoragePrefix = 'brand_images';

  /// Firebase Storage 브랜드 마스터 메뉴 이미지 경로 prefix.
  static const String menuImagesBrandStoragePrefix = 'menu_images/brand';

  /// 브랜드 마스터 메뉴 경로 헬퍼.
  static String brandMenuItemsPath(String brandId) =>
      '$brands/$brandId/$brandMenuItems';

  /// 단일 브랜드 마스터 메뉴 아이템 경로 헬퍼.
  static String brandMenuItemPath(String brandId, String menuItemId) =>
      '$brands/$brandId/$brandMenuItems/$menuItemId';

  static const String users = 'users';
  static const String stores = 'stores';
  static const String reviews = 'reviews';

  /// 글로벌 메인 카테고리 컬렉션 `mainCategories/{id}`.
  static const String mainCategories = 'mainCategories';

  /// 글로벌 부 카테고리 컬렉션 (legacy).
  static const String subCategories = 'subCategories';

  /// 부 카테고리 서브컬렉션 키 (brand/store 하위).
  /// `brands/{brandId}/subCategories/` 또는 `stores/{storeId}/subCategories/`
  static const String subCategoriesSubcollection = 'subCategories';

  /// brand scope 부 카테고리 경로 헬퍼.
  static String brandSubCategoriesPath(String brandId) =>
      '$brands/$brandId/$subCategoriesSubcollection';

  /// store scope 부 카테고리 경로 헬퍼.
  static String storeSubCategoriesPath(String storeId) =>
      '$stores/$storeId/$subCategoriesSubcollection';

  /// 글로벌(master) 옵션 그룹 컬렉션.
  static const String optionGroups = 'optionGroups';

  /// 매장 서브컬렉션 키 — `stores/{storeId}/menuItems/{menuItemId}`.
  static const String menuItems = 'menuItems';

  /// 매장 서브컬렉션 키 — `stores/{storeId}/menuOverrides/{masterMenuItemId}`.
  /// collectionGroup query 에서도 동일 키 사용.
  static const String menuOverrides = 'menuOverrides';

  /// 브랜드 매장 메뉴 오버라이드 경로 헬퍼.
  static String menuOverridesPath(String storeId) =>
      '$stores/$storeId/$menuOverrides';

  /// 단일 오버라이드 경로 헬퍼.
  static String menuOverridePath(String storeId, String masterMenuItemId) =>
      '$stores/$storeId/$menuOverrides/$masterMenuItemId';

  /// 매장 서브컬렉션 키 — `stores/{storeId}/optionGroups/{optionGroupId}` (store-scoped).
  static const String optionGroupsSubcollection = 'optionGroups';

  /// 브랜드 서브컬렉션 키 — `brands/{brandId}/optionGroups/{id}` (brand-scoped).
  static const String brandOptionGroupsSubcollection = 'optionGroups';

  /// brand scope 옵션 그룹 경로 헬퍼.
  static String brandOptionGroupsPath(String brandId) =>
      '$brands/$brandId/$brandOptionGroupsSubcollection';

  /// store scope 옵션 그룹 경로 헬퍼.
  static String storeOptionGroupsPath(String storeId) =>
      '$stores/$storeId/$optionGroupsSubcollection';

  /// 사용자 즐겨찾기 매장 서브컬렉션 — `users/{userId}/favoriteStores/{storeId}`.
  static const String favoriteStores = 'favoriteStores';

  /// 사용자 즐겨찾기 음료 서브컬렉션 — `users/{userId}/favoriteMenuItems/{compositeId}`.
  static const String favoriteMenuItems = 'favoriteMenuItems';

  /// 주문 내역(Log) 사용자 서브컬렉션 키 — `users/{uid}/orderLogs/{logId}`.
  /// Phase 2 부터 시드/추천 read 경로로 사용. Phase 3 결제에서 write.
  static const String orderLogs = 'orderLogs';

  /// Firebase Storage 내 매장 이미지 경로 prefix.
  static const String storeImagesStoragePrefix = 'store_images';

  /// 사용자 주문 로그 컬렉션 경로 헬퍼.
  /// `users/{uid}/orderLogs/{logId}` 형태.
  static String userOrderLogs(String uid) => '$users/$uid/$orderLogs';

  // ── Orders (Phase 3a) ─────────────────────────────────────────────────────
  /// 주문 컬렉션 `orders/{orderId}`.
  static const String orders = 'orders';

  /// 단일 주문 경로 헬퍼.
  static String orderPath(String orderId) => '$orders/$orderId';
}
