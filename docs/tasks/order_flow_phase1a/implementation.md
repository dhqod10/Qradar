# 주문 플로우 Phase 1a 구현 내역

## 구현 파일 목록

### 신규 — Domain
- `lib/domain/entities/main_category_code.dart` — `coffee` / `nonCoffee` / `dessert` enum + `asString` / `fromString` / `label`
- `lib/domain/entities/option_scope.dart` — `master` / `store` enum
- `lib/domain/entities/option_selection_type.dart` — `single` / `multi` enum
- `lib/domain/entities/sub_category_entity.dart` (freezed)
- `lib/domain/entities/menu_item_entity.dart` (freezed) — `optionGroupRefs: List<OptionGroupRef>` 포함
- `lib/domain/entities/option_item_entity.dart` (freezed)
- `lib/domain/entities/option_group_entity.dart` (freezed)
- `lib/domain/entities/cart_item_entity.dart` (freezed) — Phase 1b 사용 예정 (모델만)
- `lib/domain/entities/favorite_entity.dart` (freezed) — Phase 1c 사용 예정 (모델만)
- `lib/domain/entities/order_log_entity.dart` (freezed) — 결제 phase 사용 예정 (모델만)
- `lib/domain/repositories/menu_category_repository.dart`
- `lib/domain/repositories/menu_item_repository.dart`
- `lib/domain/repositories/option_repository.dart`
- `lib/domain/repositories/cart_repository.dart` — 인터페이스만 (Phase 1b 구현)
- `lib/domain/repositories/favorites_repository.dart` — 인터페이스만 (Phase 1c 구현)
- `lib/domain/repositories/order_log_repository.dart` — 인터페이스만 (결제 phase 구현)
- `lib/domain/usecases/watch_sub_categories_use_case.dart`
- `lib/domain/usecases/watch_menu_items_by_store_use_case.dart`
- `lib/domain/usecases/watch_menu_item_detail_use_case.dart`
- `lib/domain/usecases/get_option_groups_for_menu_item_use_case.dart`

### 신규 — Core
- `lib/core/constants/recommendation_thresholds.dart` — Phase 2 자동 추천용 상수 (사용처 없음, 주석 명시)
- `lib/core/utils/price_formatter.dart` — `formatKrw(int)` / `formatDelta(int)` (1,000 단위 콤마 + 부호)

### 신규 — Data
- `lib/data/models/sub_category_model.dart`
- `lib/data/models/option_item_model.dart`
- `lib/data/models/option_group_model.dart`
- `lib/data/models/menu_item_model.dart`
- `lib/data/datasources/remote/sub_category_remote_data_source.dart`
- `lib/data/datasources/remote/menu_item_remote_data_source.dart`
- `lib/data/datasources/remote/option_remote_data_source.dart`
- `lib/data/repositories/menu_category_repository_impl.dart`
- `lib/data/repositories/menu_item_repository_impl.dart`
- `lib/data/repositories/option_repository_impl.dart`

### 신규 — Presentation
- `lib/presentation/customer/order/store/providers/store_menu_providers.dart` — DI + StreamProviders + Notifiers + 파생 (`storeAvailableMainCategoriesProvider` / `storeAvailableSubCategoryIdsProvider` / `filteredMenuItemsProvider`)
- `lib/presentation/customer/order/menu/providers/menu_detail_providers.dart` — DI + 상세 + 옵션그룹 + 선택 상태(`menuItemSelectedOptionsProvider`) + 수량(`menuItemQuantityProvider`) + 파생가격/유효성
- `lib/presentation/customer/order/store/store_menu_page.dart`
- `lib/presentation/customer/order/store/widgets/store_menu_header.dart`
- `lib/presentation/customer/order/store/widgets/main_category_tabs.dart`
- `lib/presentation/customer/order/store/widgets/sub_category_chips.dart`
- `lib/presentation/customer/order/store/widgets/menu_item_card.dart`
- `lib/presentation/customer/order/menu/menu_item_detail_page.dart`
- `lib/presentation/customer/order/menu/widgets/option_group_selector.dart`
- `lib/presentation/common/quantity_stepper.dart`

### 신규 — Dev seed (DEV_ONLY)
- `lib/dev/seed/phase1_seed_data.dart` — 시드 페이로드 모음 (subCategories 9, masterOptionGroups 3, storeOptionGroups 1, menuItems 7)
- `lib/dev/seed/phase1_seed.dart` — `runPhase1Seed()` Firestore batch 시드
- `lib/dev/seed/dev_seed_trigger.dart` — `kDebugMode` 분기 long-press → AlertDialog → 시드 실행 위젯

### 수정
- `lib/core/constants/firestore_paths.dart` — `subCategories` / `optionGroups` / `menuItems` / `optionGroupsSubcollection` / `favoriteStores` / `favoriteMenuItems` / `orderLogs` 추가
- `lib/presentation/customer/home/widgets/nearby_stores_section.dart` — 카드 onTap → `StoreMenuPage` push
- `lib/presentation/customer/home/widgets/recommended_stores_section.dart` — 카드 onTap → `StoreMenuPage` push (전체보기 트레일링 버튼은 placeholder 유지)
- `lib/presentation/customer/order/tabs/store_list_tab.dart` — 카드 onTap → `StoreMenuPage` push
- `lib/presentation/customer/order/tabs/store_map_tab.dart` — 마커 시트 "주문하기" → `StoreMenuPage` push
- `lib/presentation/customer/more/more_page.dart` — 앱 버전 텍스트(`Qradar v0.1.0`) 추가 + `DevSeedTrigger` 래퍼 (DEV_ONLY)

---

## 주요 결정사항

- **DI 방식**: `Provider` 트리(DataSource → Repository → UseCase)로 layered DI. 테스트/모킹 가능성 확보.
- **Riverpod API**: 프로젝트는 `hooks_riverpod` 3.x. 가족 Notifier 는 `class X extends Notifier<T> { X(this.arg); final Arg arg; @override T build() => ...; } NotifierProvider.family<X,T,Arg>(X.new)` 패턴 사용 (3.x 에 `FamilyNotifier` 없음). `AsyncValue` 는 `.value`(nullable) 사용.
- **카테고리 자동 선택**: `selectedMainCategoryProvider` 기본값 = `coffee`. 매장이 보유한 main 이 아니면 UI 가 첫 보유 main 으로 자동 전환 (`storeMenuItemsProvider` 데이터 도착 후 `_resolveActiveMain` 헬퍼).
- **subCategory chips 가시성**: 매장이 보유한 부 카테고리 수가 ≤1 이면 chips 영역 자체 숨김(헤더 delegate 의 maxExtent 도 분기). "전체" 칩 포함 시에도 동일 규칙 적용.
- **옵션 필수 기본값 자동 선택**: `MenuItemDetailPage` 진입 시 `ref.listen(menuItemOptionGroupsProvider)` 가 데이터 도착을 감지하면 `selectedOptionsNotifier.primeRequiredDefaults(groups)` 호출 — 단일/필수 그룹의 첫 항목을 자동 선택. 사용자가 선택 변경 후엔 다시 덮어쓰지 않음.
- **canAddToCart 계산**: 모든 `required && selectionType==single` 그룹에 1개 이상 선택, `required && selectionType==multi` 도 1개 이상 선택. 누락 그룹이 있으면 SnackBar 에 그룹명을 명시.
- **가격 포맷**: 1,000 단위 콤마는 `intl` 의존 없이 `lib/core/utils/price_formatter.dart` 에서 직접 분리. `priceDelta == 0` 표기 생략, 음수는 `-300원` 형태 (할인). 단가 = `basePrice + Σ priceDelta`, 합계 = 단가 × quantity.
- **"담기" 버튼**: Phase 1a 는 placeholder. 비활성 시(필수 미충족) 회색 + 누르면 누락된 첫 그룹 안내 SnackBar. 활성 시 누르면 `"장바구니 기능은 준비 중입니다 (Phase 1b)"` SnackBar (`canAddToCartProvider` 로직은 Phase 1b 에서 onTap 만 교체하면 동작 그대로).
- **즐겨찾기 / 카트 아이콘 / 카트 뱃지**: Phase 1a 는 모두 placeholder SnackBar 또는 아이콘 자리만 노출. 즐겨찾기는 시각적 활성 상태 변경 없음(항상 비활성 표시).
- **영업 상태**: `StoreMenuHeader` 내부에 `_isOpenNow(BusinessHours, DateTime now)` 헬퍼로 시각 비교. 자정 넘어가는 영업 시간(close < open) 처리 포함.
- **옵션 그룹 fetch**: `OptionRepositoryImpl.getOptionGroupsForMenuItem` 가 `MenuItem.optionGroupRefs` 를 순회, scope=master/store 별로 dispatch. 누락된 ref 는 `null` → `whereType<OptionGroupEntity>()` 로 필터링하여 silently 무시 (UI 가 빈 그룹 처리에 견고).
- **Firestore 경로**: 매장 메뉴 = `stores/{storeId}/menuItems/{id}` (서브컬렉션). store-scoped optionGroups = `stores/{storeId}/optionGroups/{id}`. 글로벌 optionGroups = `optionGroups/{id}`. 글로벌 subCategories = `subCategories/{id}`.
- **시드 다이얼로그**: 더보기 페이지의 `Qradar v0.1.0` 텍스트를 long-press(=`kDebugMode` 분기). 다이얼로그에서 `실행` 시 `runPhase1Seed()` → `WriteBatch` 단일 commit 으로 9 sub + 3 master OG + store + 1 store OG + 7 menu = 21 docs 일괄 upsert. 실패 시 SnackBar 로 에러 노출.

---

## 시드 데이터 삭제 절차

Phase 1 시드는 개발자 전용입니다. 시드가 더 이상 필요 없을 때 다음 절차를 따릅니다.

### 1. 시드 폴더 통째 삭제
```bash
rm -rf lib/dev/seed
```
포함 파일:
- `lib/dev/seed/phase1_seed_data.dart`
- `lib/dev/seed/phase1_seed.dart`
- `lib/dev/seed/dev_seed_trigger.dart`

### 2. MorePage 트리거 제거
`lib/presentation/customer/more/more_page.dart`:
- 상단의 다음 import 한 줄 삭제:
  ```dart
  // DEV_ONLY_SEED — order_flow_phase1. 시드 제거 시 다음 import 와 사용처(앱 버전 텍스트 래퍼) 삭제.
  import 'package:qradar/dev/seed/dev_seed_trigger.dart';
  ```
- 하단의 `DevSeedTrigger` 래퍼 블록을 제거하거나 `Text` 만 남기기:
  ```dart
  // DEV_ONLY_SEED — order_flow_phase1. 시드 제거 시 아래 DevSeedTrigger 래퍼만 떼고 Text 만 남기면 됨.
  Center(
    child: DevSeedTrigger(
      child: const Padding(... Text('Qradar v0.1.0') ...),
    ),
  ),
  ```
  → 단순히 래퍼만 삭제하면 앱 버전 텍스트는 유지된 채 long-press 트리거만 사라집니다.

### 3. Firestore 시드 데이터 정리 (선택)
시드된 문서 ID 는 모두 고정값입니다. Firebase 콘솔 또는 `firebase` CLI 로 다음을 삭제하세요.
- `subCategories/sc_*` 9건
- `optionGroups/og_master_*` 3건
- `stores/phase1_seed_store_001` (서브컬렉션 `menuItems`, `optionGroups` 포함)

### 4. analyze 확인
```bash
flutter analyze
```
unused import 경고가 없으면 깔끔히 제거된 것입니다.

---

## 테스트 포인트

### 진입 / 라우팅
1. 홈 → 주변매장 카드 탭 → 매장 메뉴 페이지 push.
2. 홈 → 맞춤 추천 카드 탭 → 매장 메뉴 페이지 push.
3. 주문 탭 → 매장 검색 리스트 카드 탭 → 매장 메뉴 페이지 push.
4. 주문 탭 → 지도 마커 탭 → 시트 "주문하기" → 매장 메뉴 페이지 push.

### StoreMenuPage
5. 로딩 시 헤더 + 그리드 6개 shimmer 표시.
6. 메뉴 0개 매장: 빈 상태 + 뒤로가기 CTA.
7. 메인 카테고리 탭: 매장 보유 0 인 카테고리는 회색 + 비활성 (탭 안 됨).
8. 부 카테고리 chips: 보유한 부 카테고리만 노출, ≤1 이면 chips 영역 사라짐.
9. "전체" 칩 선택 시 해당 메인 카테고리 전체 메뉴 노출.
10. 그리드 카드: 이미지 / 이름 / 기본가 / 품절 오버레이 표시. 품절 카드는 onTap 무동작.
11. 우상단 카트 아이콘 / 즐겨찾기 토글: SnackBar placeholder.

### MenuItemDetailPage
12. 진입 시 단일/필수 옵션 그룹의 첫 항목 자동 선택.
13. 단일/선택 그룹: "선택 안함" 라디오가 prepend 되어야 함.
14. 다중/선택 그룹: 체크박스 + 자유 토글.
15. priceDelta 0 = 표기 생략, +값 = `+1,000원`, 음수 = `-300원`(success 색).
16. QuantityStepper: 1~99 클램프, 1 에서 minus / 99 에서 plus 비활성.
17. 합계: `(basePrice + Σ priceDelta) × quantity` 실시간 갱신, 콤마 포맷.
18. 필수 미충족 → 담기 버튼 회색 + 누르면 누락 그룹명 SnackBar.
19. 필수 충족 → 담기 버튼 활성 + 누르면 "장바구니 기능은 준비 중입니다 (Phase 1b)" SnackBar.
20. 즐겨찾기 토글: SnackBar placeholder, 시각 활성화 없음.

### 데이터 / 시드
21. MorePage `Qradar v0.1.0` long-press → 시드 다이얼로그 → 실행 → SnackBar 에 카운트 노출.
22. 동일 시드 재실행 → 동일 ID merge, 에러 없음.
23. 시드 후 홈/주문 탭에서 임시 매장이 노출되는지 확인 (Firestore 위치 = 서울 시청 좌표).

### 빌드
24. `dart run build_runner build --delete-conflicting-outputs` 성공.
25. `flutter analyze` → No issues found.

---

## 미구현 / 보류

### Phase 1b
- `CartRepository` 구현체 (`lib/data/repositories/cart_repository_impl.dart`)
- `CartLocalDataSource` (Hive/Sqflite 등 — 매장별 독립 카트, product_scope.md 명시)
- 카트 페이지 (`lib/presentation/customer/cart/...`)
- "담기" 버튼 onTap 실제 카트 추가 로직 + 카트 아이콘 뱃지 카운트
- 카트 화면에서 옵션/수량 변경, 결제 진입 placeholder

### Phase 1c
- `FavoritesRepository` 구현체 (`lib/data/repositories/favorites_repository_impl.dart`)
- `users/{uid}/favoriteStores` / `users/{uid}/favoriteMenuItems` 서브컬렉션 R/W
- 매장 헤더 ♥ 토글 / 메뉴 상세 ♥ 토글 시각 활성화 + 리스트 화면

### 결제 phase (Phase 3)
- `OrderLogRepository` 구현체
- 결제 모듈, 영수증, Log 기록

### Phase 2 (자동 추천)
- `recommendation_thresholds.dart` 상수 사용처 (Log 누적 후 의미 있음)
- 원클릭 재주문 카드, 자동 진입 로직

---

## 빌드 결과
- `dart run build_runner build --delete-conflicting-outputs` → 18 outputs, 성공.
- `flutter analyze` → **No issues found! (4.6s)**.
