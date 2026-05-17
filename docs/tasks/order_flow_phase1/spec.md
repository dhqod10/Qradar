# order_flow_phase1 기능 명세 (음료 주문 기본 플로우 — Phase 1, **Umbrella**)

> ## ⚑ 분할 진행 확정 (2026-04-26)
>
> 본 문서는 Phase 1 전체의 **데이터 모델·결정사항·범위 정의 우산**이다. 실제 작업은 아래 3개 서브 phase 로 분할되어 진행된다.
>
> - **Phase 1a** — Domain + Data 전부 + StoreMenuPage + MenuItemDetailPage (담기는 placeholder 스낵바). 시드 스크립트 포함. → [docs/tasks/order_flow_phase1a/spec.md](../order_flow_phase1a/spec.md)
> - **Phase 1b** — CartPage 본구현 + addToCart 동작 + 매장 충돌 다이얼로그. (Phase 1a 완료 후 spec 작성)
> - **Phase 1c** — 즐겨찾기 토글 (매장/메뉴) + Repository. (Phase 1b 완료 후 spec 작성)
>
> 각 서브 phase 는 본 문서의 결정사항 1~8 을 그대로 따른다. 변경이 필요하면 본 문서를 갱신한다.
>
> ## ⚑ 시드 데이터 전략 확정
>
> 개발 검증용 시드 데이터는 `lib/dev/seed/` 폴더에 격리한다. **사용자 요청 시 폴더 통째 삭제 + MorePage 의 진입 트리거 1개 제거** 만으로 완전 정리되도록 설계.
>
> - 위치: `lib/dev/seed/phase1_seed.dart` 등 (전 파일에 `// DEV_ONLY_SEED — order_flow_phase1` 주석 마커)
> - 트리거: `MorePage` 앱 버전 텍스트 long-press → 다이얼로그 → "Phase 1 시드 실행" 버튼 (`kDebugMode` 분기로 release 빌드 노출 차단)
> - 제거 절차 (사용자가 "지워달라" 했을 때): `lib/dev/seed/` 폴더 삭제 + `MorePage` 의 `_DevSeedTrigger` import/사용처 1줄 제거. grep `DEV_ONLY_SEED` 로 잔존 마커 확인.

## 개요

- **목적**: 사용자가 매장을 선택하고, 메뉴를 탐색하고, 음료 옵션을 선택해 **장바구니에 담는** 기본 주문 플로우를 구축한다. Phase 2 자동 추천(원클릭 재주문)의 데이터 인프라(Log, 즐겨찾기, 임계값 상수) 도 함께 마련한다.
- **작업 유형**: 신규 기능 (대규모)
- **결제는 별도 Phase**. 이번 작업은 "결제 직전 상태 = 장바구니 확정" 까지.

### 영향 범위

| 레이어 | 영향 |
|---|---|
| 화면 | (신규) 매장 메뉴 페이지, 음료 상세/옵션 페이지, 장바구니 페이지, 즐겨찾기 토글 / (수정) 라우터, 홈 매장카드·주문 탭 매장카드 진입 동작 |
| Domain | (신규) MenuCategory, MenuItem, OptionGroup, OptionItem, CartItem, Cart, FavoriteStore, FavoriteMenuItem, OrderLog 엔티티 + 각 Repository 인터페이스 + UseCase 다수 |
| Data | (신규) Firestore 컬렉션 5종, Local Cart DataSource, Repository 구현체 5종, Model(DTO) 다수 |
| Presentation | (신규) `presentation/customer/order/store/`, `presentation/customer/order/menu/`, `presentation/customer/cart/` |
| 공통 컴포넌트 | (신규) `OptionGroupSelector`, `FavoriteToggleIconButton`, `QuantityStepper` |
| 라우팅 | (신규) `/order/store/:storeId` (매장 메뉴), `/order/store/:storeId/menu/:menuItemId` (음료 상세), `/cart` (장바구니) |
| 권한 / 환경 설정 | 변경 없음 (Firestore 보안 규칙은 admin/owner 작성 task 에서 별도 다룸) |

### 비범위

- **결제 (Phase 3)**: 토스페이/카카오페이/네이버페이 연동, 결제 완료 후 후처리.
- **자동 진입 / 원클릭 재주문 카드 (Phase 2)**: 즐겨찾기·Log 누적 기반 자동 추천, 홈 상단 빠른 주문 카드.
- **자동 추천 로직 (Phase 2)**: "30일/5회" 등 빈도 산정 알고리즘, 임계값 활용. (단, **상수 파일은 본 작업에서 미리 만든다**.)
- **관리자 화면**: 마스터 카테고리/부 카테고리/메뉴/옵션 CRUD UI. 데이터는 Firestore 콘솔에서 수동 시드.
- **점주 화면**: 매장별 메뉴 품절·제외, 가격 오버라이드 UI.
- **장바구니 영속화 (Phase 2 권장)**: 본 작업은 **메모리 only** (앱 재시작 시 카트 초기화). 필요 시 Phase 2 에서 SharedPreferences 백업.
- **OrderLog 실제 저장**: 결제 시점에 작성. Phase 1 에서는 **Entity / Repository 인터페이스만 정의** 하고 DataSource·Impl 은 결제 Phase 에서 작성.
- **홈 화면 12종 카테고리 필터** (`MenuCategories.all`): 본 작업의 3종 카테고리(커피/논커피/디저트)는 **매장 안 메뉴 분류용**이며, 홈 화면 12종은 **매장 검색 필터용**. **다른 차원**이므로 본 작업에서 12종을 건드리지 않는다. 향후 통합은 별도 task.

---

## architect 결정사항 (사용자 확인 요청)

⚠ 아래 결정은 architect 가 정한 잠정안이다. 사용자 승인 후 designer/developer 호출.

### 결정 1. 매장 선택 진입점 — 두 곳 모두 사용, 라우트는 단일 통합

- 진입점:
  - 홈 화면 `RecommendedStoreCard` / `StoreCard` 탭 → 매장 메뉴 페이지로 이동
  - 주문 탭 (매장 검색 / 지도 검색) 매장 선택 → 매장 메뉴 페이지로 이동
- **단일 라우트**: `/order/store/:storeId` (`StoreMenuPage`)
- 진입점은 두 곳이지만 **목적지/UI 는 동일**.
- order_store_map 의 `store_map_marker_sheet` "주문하기" 버튼도 이 라우트로 연결되도록 후속 수정.

### 결정 2. 카테고리/부 카테고리 데이터 모델

- **메인 카테고리는 enum 으로 하드코딩** (3종 고정): `coffee` / `nonCoffee` / `dessert`
  - 이유: 메인 카테고리는 사양상 **앱 전체 고정**이고 자주 바뀌지 않음. enum 은 컴파일 타임 안전성 + 다국어 라벨 분기 용이.
- **부 카테고리는 Firestore 글로벌 컬렉션**: `subCategories/{id}`
  - 필드: `id`, `mainCategoryCode (coffee|nonCoffee|dessert)`, `name`, `displayOrder`, `active`
  - 관리자가 전 매장 공통으로 정의.
  - 이유: 추가/제거가 잦을 수 있고, 매장은 자기가 보유한 부 카테고리만 노출 (메뉴와의 매핑으로 자동 판정).

### 결정 3. 메뉴(MenuItem) 데이터 모델 — Phase 1 은 매장 단위로 단순화

- product_scope.md 는 "**브랜드 단위 마스터 메뉴 + 매장별 가격 오버라이드**"를 admin 기능으로 정의.
- Phase 1 에서는 admin/owner 화면이 비범위. 따라서 **Phase 1 은 매장 직접 보유 모델**로 단순화:
  - `stores/{storeId}/menuItems/{menuItemId}` (서브컬렉션)
  - 필드: `id`, `name`, `imageUrl`, `description`, `mainCategoryCode`, `subCategoryId`, `basePrice (원)`, `optionGroupRefs: [{scope: master|store, id: string}]`, `soldOut: bool`, `displayOrder`, `createdAt`
- **추후 admin 작업 시** 마이그레이션 경로:
  - `brands/{brandId}/menuItems` (마스터) + `stores/{storeId}/menuOverrides` (price/soldOut 오버라이드) 구조로 전환.
  - Repository Interface 는 동일 유지, DataSource/Impl 만 교체. → Domain/Presentation 변경 없이 데이터 마이그레이션 가능.

### 결정 4. 옵션 데이터 모델 — 글로벌 + 매장 한정 2계층

- **글로벌 마스터 옵션**: `optionGroups/{id}` (관리자가 정의, 전 매장 공통)
  - 예: 온도 (단일/필수: 아이스/핫/연하게), 샷 추가 (다중/선택: +1샷, +2샷), 시럽 (다중/선택: 바닐라, 헤이즐넛)
- **매장 한정 옵션**: `stores/{storeId}/optionGroups/{id}` (점주/관리자가 정의)
  - 예: 텀블러 할인 (다중/선택: 개인 텀블러 -300원)
- 옵션 그룹 필드: `id`, `name`, `selectionType: single|multi`, `required: bool`, `items: [{id, label, priceDelta}]`, `displayOrder`
- 메뉴 → 옵션 그룹 참조: `MenuItem.optionGroupRefs` 가 `[{scope, id}]` 형태로 master/store 두 출처를 모두 참조.

### 결정 5. 장바구니(Cart) 데이터 모델 — 메모리 + 1 활성 카트

- **메모리 only** (Riverpod state). 앱 재시작 시 초기화. Phase 2 에서 영속화 검토.
- **활성 카트는 1개** (1 매장).
- 다른 매장 메뉴를 담으려 하면 **확인 다이얼로그** ("기존 매장 카트를 비우고 새 매장으로 시작할까요?").
- Cart Entity:
  - `storeId`, `items: List<CartItem>`, `subtotal: int (원)`
- CartItem Entity:
  - `cartItemId (uuid)`, `menuItemId`, `menuItemName`, `quantity`, `selectedOptions: List<{groupId, itemId, label, priceDelta}>`, `unitPriceWithOptions`, `lineTotal`
- 동일 메뉴+동일 옵션 조합은 quantity 증가, 다른 옵션은 별개 라인.

### 결정 6. 즐겨찾기 데이터 모델 — 두 컬렉션 분리

- `users/{uid}/favoriteStores/{storeId}` — `addedAt`
- `users/{uid}/favoriteMenuItems/{storeId_menuItemId}` — `storeId`, `menuItemId`, `addedAt`
- 분리 이유: 의미 단위가 다름 (매장 vs 매장-음료 페어), 쿼리 패턴이 다름, Phase 2 추천이 두 종류를 다르게 활용.

### 결정 7. OrderLog(주문 내역 = `Log`) 인프라 — Phase 1 은 모델/인터페이스만

- product_scope.md 의 **Log** 용어 사용.
- Phase 1 작성 범위:
  - `domain/entities/order_log_entity.dart` — Entity
  - `domain/repositories/order_log_repository.dart` — Interface (`writeLog`, `watchLogsByUser`, `watchLogsByUserAndStore`)
  - `data/models/order_log_model.dart` — DTO (Firestore 직렬화)
  - **DataSource / RepositoryImpl 미작성** (결제 Phase 에서 작성)
- 컬렉션 경로 (예약): `users/{uid}/orderLogs/{logId}` 또는 `orderLogs/{logId}` — 결정은 결제 Phase 에서 (이번 task 는 결정 보류 메모만).
- 이유: Phase 2 자동 추천이 `orderLogRepository.watchLogsByUser` 를 호출할 수 있게 인터페이스를 미리 확정. Phase 2 시작 시 인터페이스 변경 없이 DataSource 만 추가하면 됨.

### 결정 8. 추천 임계값 상수 — 본 작업에서 파일만 만들고 사용은 Phase 2

- 신규: `lib/core/constants/recommendation_thresholds.dart`
- 잠정값:
  - `frequentStoreLookbackDays = 30`
  - `frequentStoreMinVisits = 5`
  - `frequentStoreMinActiveWeeks = 3` (대안 기준: 4주 중 3주)
  - `frequentMenuLookbackDays = 30`
  - `frequentMenuMinOrders = 4` (매장-음료 페어 기준)
- 본 task 코드는 이 상수를 직접 사용하지 않음 (Phase 2 prep).

---

## 요구사항

### 기능 요구사항

#### 매장 진입
- [ ] 홈 화면의 매장 카드 탭 시 `/order/store/:storeId` 라우트로 이동
- [ ] 주문 탭(검색/지도)의 매장 선택 시 동일 라우트로 이동
- [ ] order_store_map 의 마커 시트 "주문하기" 버튼도 동일 라우트로 연결 (placeholder 스낵바 → 실제 라우팅으로 교체)

#### 매장 메뉴 페이지 (`StoreMenuPage`)
- [ ] 매장 헤더 (이름, 등급, 거리, 즐겨찾기 토글, 영업 상태)
- [ ] 메인 카테고리 탭 3개: 커피 / 논커피 / 디저트
  - 매장이 보유한 메뉴가 0인 메인 카테고리 탭은 비활성/숨김 처리
- [ ] 부 카테고리 chips (현재 메인 카테고리에 매장이 보유한 부 카테고리만 표시; 1개뿐이면 자동 숨김)
- [ ] 메뉴 그리드/리스트 (이미지, 이름, 가격, 품절 뱃지)
- [ ] 메뉴 탭 시 음료 상세 페이지로 이동
- [ ] 우상단 카트 아이콘 + 개수 뱃지 (다른 매장 카트가 있어도 그 매장의 개수 표시)

#### 음료 상세 페이지 (`MenuItemDetailPage`)
- [ ] 메뉴 이미지 / 이름 / 설명 / 기본가
- [ ] 즐겨찾기(♥) 토글
- [ ] 옵션 그룹 렌더 (필수 그룹 미선택 시 "담기" 비활성)
  - 단일 선택: 라디오
  - 다중 선택: 체크박스
  - priceDelta 표시
- [ ] 수량 stepper (최소 1, 최대 99)
- [ ] 실시간 합계 (basePrice + 선택 옵션 priceDelta 합 × quantity)
- [ ] "담기" 버튼:
  - 다른 매장 카트가 활성 상태면 확인 다이얼로그 → 카트 초기화 후 추가
  - 동일 매장이면 그대로 추가
  - 추가 후 매장 메뉴 페이지로 pop + 토스트 ("카트에 담겼어요")

#### 장바구니 페이지 (`CartPage`)
- [ ] 매장 헤더 + 카트 비우기 버튼
- [ ] 카트 라인 리스트 (메뉴명, 옵션 요약, 수량 stepper, 라인 합계, 삭제)
- [ ] 전체 합계
- [ ] "결제하기" 버튼 → "준비 중" 스낵바 (Phase 3)
- [ ] 빈 상태 (카트 0개): 안내 + "메뉴 보러가기" 버튼

#### 즐겨찾기
- [ ] 매장 메뉴 페이지에서 매장 즐겨찾기 토글
- [ ] 음료 상세 페이지에서 음료 즐겨찾기 토글 (매장-음료 페어 키)
- [ ] 비로그인 시 토글 누르면 로그인 유도 다이얼로그 → 로그인 페이지

### 상태 요구사항

| 화면 | 로딩 | 에러 | 빈 상태 |
|---|---|---|---|
| StoreMenuPage | shimmer (헤더 + 그리드) | 에러 카드 + 재시도 | 메뉴 0개 → "등록된 메뉴가 없어요" |
| MenuItemDetailPage | shimmer | 에러 카드 + 재시도 | — |
| CartPage | (메모리이므로 즉시) | — | "카트가 비어있어요" + CTA |

---

## 데이터 모델

### Entity

#### `MainCategoryCode` (enum)
- `coffee` (라벨: "커피")
- `nonCoffee` (라벨: "논커피")
- `dessert` (라벨: "디저트")

#### `SubCategoryEntity`
| 필드 | 타입 | 설명 |
|---|---|---|
| id | String | Firestore doc id |
| mainCategoryCode | MainCategoryCode | 소속 메인 카테고리 |
| name | String | 표시 이름 (예: "에스프레소") |
| displayOrder | int | 정렬 |
| active | bool | 비활성 시 노출 제외 |

#### `MenuItemEntity`
| 필드 | 타입 | 설명 |
|---|---|---|
| id | String | menuItem id |
| storeId | String | 소속 매장 |
| name | String | |
| imageUrl | String | |
| description | String? | |
| mainCategoryCode | MainCategoryCode | |
| subCategoryId | String? | null 허용 (부 카테고리 없는 매장 호환) |
| basePrice | int | 원 단위 |
| optionGroupRefs | List<OptionGroupRef> | `{scope: master\|store, id}` |
| soldOut | bool | |
| displayOrder | int | |
| createdAt | DateTime | |

#### `OptionGroupEntity`
| 필드 | 타입 | 설명 |
|---|---|---|
| id | String | |
| scope | OptionScope (master\|store) | 출처 |
| storeId | String? | scope=store 일 때만 |
| name | String | "온도", "샷 추가" 등 |
| selectionType | OptionSelectionType (single\|multi) | |
| required | bool | |
| items | List<OptionItemEntity> | |
| displayOrder | int | |

#### `OptionItemEntity`
| 필드 | 타입 | 설명 |
|---|---|---|
| id | String | |
| label | String | "아이스", "+1샷" |
| priceDelta | int | 원, 음수 가능 (텀블러 할인 등) |

#### `CartEntity`
| 필드 | 타입 | 설명 |
|---|---|---|
| storeId | String | 활성 매장 |
| storeName | String | UI 캐싱용 |
| items | List<CartItemEntity> | |
| subtotal | int | 합계 (원) |

#### `CartItemEntity`
| 필드 | 타입 | 설명 |
|---|---|---|
| cartItemId | String | uuid (라인 식별) |
| menuItemId | String | |
| menuItemName | String | |
| imageUrl | String | UI 캐싱용 |
| quantity | int | 1~99 |
| selectedOptions | List<SelectedOption> | `{groupId, groupName, itemId, label, priceDelta}` |
| unitPriceWithOptions | int | basePrice + 옵션 합 |
| lineTotal | int | unitPriceWithOptions × quantity |

#### `FavoriteStoreEntity`
| 필드 | 타입 | 설명 |
|---|---|---|
| storeId | String | |
| addedAt | DateTime | |

#### `FavoriteMenuItemEntity`
| 필드 | 타입 | 설명 |
|---|---|---|
| storeId | String | |
| menuItemId | String | |
| addedAt | DateTime | |

#### `OrderLogEntity` (Phase 1: 모델만)
| 필드 | 타입 | 설명 |
|---|---|---|
| id | String | |
| userId | String | |
| storeId | String | |
| storeName | String | 시점 스냅샷 |
| items | List<OrderLogItem> | menuItemId, name, quantity, optionsSnapshot, lineTotal |
| total | int | |
| paidAt | DateTime | 결제 완료 시각 |
| paymentMethod | String | "tossPay", "kakaoPay" 등 (Phase 3 에서 enum 화) |

### DTO / Model

각 Entity 마다 `*_model.dart` (freezed + json_serializable) 작성. Firestore 직렬화 규칙:

- `DateTime` ↔ Firestore `Timestamp` (`.toDate()` / `Timestamp.fromDate()`)
- enum (`MainCategoryCode`, `OptionScope`, `OptionSelectionType`) ↔ String code
- `priceDelta`, `basePrice`, `total` 등 금액은 모두 **int (원)** 으로 통일

---

## 레이어 설계

### Domain

**Entities** (`lib/domain/entities/`):
- `main_category_code.dart` (enum)
- `sub_category_entity.dart` (freezed)
- `menu_item_entity.dart` (freezed)
- `option_group_entity.dart`, `option_item_entity.dart` (freezed)
- `option_scope.dart` (enum)
- `option_selection_type.dart` (enum)
- `cart_entity.dart`, `cart_item_entity.dart`, `selected_option.dart` (freezed)
- `favorite_store_entity.dart`, `favorite_menu_item_entity.dart` (freezed)
- `order_log_entity.dart` (freezed)

**Repositories Interface** (`lib/domain/repositories/`):
- `menu_category_repository.dart`
  - `Stream<List<SubCategoryEntity>> watchSubCategories(MainCategoryCode main)`
- `menu_item_repository.dart`
  - `Stream<List<MenuItemEntity>> watchByStore(String storeId)`
  - `Stream<MenuItemEntity?> watchById(String storeId, String menuItemId)`
- `option_repository.dart`
  - `Future<OptionGroupEntity?> getMasterOptionGroup(String id)`
  - `Future<OptionGroupEntity?> getStoreOptionGroup(String storeId, String id)`
  - `Future<List<OptionGroupEntity>> getOptionGroupsForMenuItem(MenuItemEntity menuItem)` (편의)
- `cart_repository.dart`
  - `Stream<CartEntity?> watchCart()`
  - `Future<void> addItem(CartItemEntity item, {required String storeId, required String storeName})`
  - `Future<void> updateQuantity(String cartItemId, int quantity)`
  - `Future<void> removeItem(String cartItemId)`
  - `Future<void> clear()`
- `favorites_repository.dart`
  - `Stream<List<FavoriteStoreEntity>> watchFavoriteStores(String userId)`
  - `Stream<List<FavoriteMenuItemEntity>> watchFavoriteMenuItems(String userId)`
  - `Future<void> toggleFavoriteStore(String userId, String storeId)`
  - `Future<void> toggleFavoriteMenuItem(String userId, String storeId, String menuItemId)`
- `order_log_repository.dart` **(인터페이스만, 구현 없음)**
  - `Future<void> writeLog(OrderLogEntity log)`
  - `Stream<List<OrderLogEntity>> watchLogsByUser(String userId)`
  - `Stream<List<OrderLogEntity>> watchLogsByUserAndStore(String userId, String storeId)`

**UseCases** (`lib/domain/usecases/`):
- `watch_sub_categories_use_case.dart`
- `watch_menu_items_by_store_use_case.dart`
- `watch_menu_item_detail_use_case.dart`
- `get_option_groups_for_menu_item_use_case.dart`
- `add_to_cart_use_case.dart`
- `update_cart_item_quantity_use_case.dart`
- `remove_cart_item_use_case.dart`
- `clear_cart_use_case.dart`
- `watch_cart_use_case.dart`
- `toggle_favorite_store_use_case.dart`
- `toggle_favorite_menu_item_use_case.dart`
- `watch_favorite_stores_use_case.dart`
- `watch_favorite_menu_items_use_case.dart`

### Data

**Models** (`lib/data/models/`):
- `sub_category_model.dart`
- `menu_item_model.dart`
- `option_group_model.dart`, `option_item_model.dart`
- `cart_model.dart`, `cart_item_model.dart`, `selected_option_model.dart`
- `favorite_store_model.dart`, `favorite_menu_item_model.dart`
- `order_log_model.dart`

**DataSources** (`lib/data/datasources/`):
- `remote/sub_category_remote_data_source.dart` — `subCategories` 글로벌 컬렉션
- `remote/menu_item_remote_data_source.dart` — `stores/{storeId}/menuItems`
- `remote/option_remote_data_source.dart` — `optionGroups` 글로벌 + `stores/{storeId}/optionGroups`
- `remote/favorites_remote_data_source.dart` — `users/{uid}/favoriteStores`, `users/{uid}/favoriteMenuItems`
- `local/cart_local_data_source.dart` — 메모리 (StateNotifier 형태로 in-memory)

**Repositories Implementation** (`lib/data/repositories/`):
- `menu_category_repository_impl.dart`
- `menu_item_repository_impl.dart`
- `option_repository_impl.dart`
- `cart_repository_impl.dart` (Local DataSource 사용)
- `favorites_repository_impl.dart`
- ~`order_log_repository_impl.dart`~ — **Phase 1 비범위**

**Firestore 컬렉션 경로 추가** (`lib/core/constants/firestore_paths.dart`):
- `subCategories`
- `optionGroups` (글로벌)
- 기존 `users`/`stores` 의 서브컬렉션 키 상수: `menuItems`, `optionGroups` (store-scoped), `favoriteStores`, `favoriteMenuItems`

### Presentation

**Pages**:
- `presentation/customer/order/store/store_menu_page.dart` — 매장 메뉴 페이지
- `presentation/customer/order/menu/menu_item_detail_page.dart` — 음료 상세
- `presentation/customer/cart/cart_page.dart` — 장바구니

**Widgets**:
- `presentation/customer/order/store/widgets/store_menu_header.dart`
- `presentation/customer/order/store/widgets/main_category_tabs.dart`
- `presentation/customer/order/store/widgets/sub_category_chips.dart`
- `presentation/customer/order/store/widgets/menu_item_card.dart`
- `presentation/customer/order/menu/widgets/option_group_selector.dart` (단일/다중 분기)
- `presentation/customer/order/menu/widgets/quantity_stepper.dart` (공통화 — `presentation/common/` 후보)
- `presentation/customer/cart/widgets/cart_line_tile.dart`
- `presentation/common/favorite_toggle_icon_button.dart`

**Providers**:
- `presentation/customer/order/store/providers/store_menu_providers.dart`
  - `selectedMainCategoryProvider` (NotifierProvider)
  - `selectedSubCategoryIdProvider` (NotifierProvider, nullable)
  - `storeMenuItemsProvider` (StreamProvider, family<storeId>)
  - `storeAvailableSubCategoriesProvider` (Provider, 매장이 보유한 부 카테고리만)
  - `filteredMenuItemsProvider` (Provider, 메인+부 필터 적용)
- `presentation/customer/order/menu/providers/menu_detail_providers.dart`
  - `menuItemDetailProvider` (StreamProvider.family)
  - `menuItemOptionGroupsProvider` (FutureProvider.family)
  - `menuItemSelectedOptionsProvider` (NotifierProvider.family<menuItemId>)
  - `menuItemQuantityProvider` (NotifierProvider.family)
  - `menuItemCurrentPriceProvider` (Provider.family)
  - `menuItemAddToCartReadyProvider` (Provider.family — 필수 옵션 충족 여부)
- `presentation/customer/cart/providers/cart_providers.dart`
  - `cartProvider` (StreamProvider — `watchCartUseCase`)
- `presentation/customer/order/favorites/providers/favorites_providers.dart`
  - `favoriteStoreIdsProvider` (StreamProvider — userId 기반)
  - `favoriteMenuItemKeysProvider` (StreamProvider — `${storeId}_${menuItemId}` Set)

**라우팅** (`lib/app/router.dart` 수정):
- `/order/store/:storeId` → `StoreMenuPage`
- `/order/store/:storeId/menu/:menuItemId` → `MenuItemDetailPage`
- `/cart` → `CartPage`

---

## 데이터 흐름

### 매장 진입 → 메뉴 표시

```
홈 StoreCard onTap
  → context.push('/order/store/$storeId')
StoreMenuPage build
  → ref.watch(storeMenuItemsProvider(storeId))
       → watchMenuItemsByStoreUseCase
       → menuItemRepository.watchByStore
       → menuItemRemoteDataSource.streamByStore
       → Firestore: stores/{storeId}/menuItems
  → ref.watch(storeAvailableSubCategoriesProvider(storeId))
       → menuItems 의 distinct subCategoryId 추출 + watchSubCategories(main) 결과와 매핑
  → ref.watch(filteredMenuItemsProvider(storeId))
       → main + sub 필터 적용
```

### 음료 상세 → 옵션 선택 → 카트 담기

```
MenuItemCard onTap
  → context.push('/order/store/$storeId/menu/$menuItemId')
MenuItemDetailPage build
  → ref.watch(menuItemDetailProvider((storeId, menuItemId)))
  → ref.watch(menuItemOptionGroupsProvider(menuItemId))
       → getOptionGroupsForMenuItemUseCase
       → optionRepository.getOptionGroupsForMenuItem
            ├─ master refs → getMasterOptionGroup
            └─ store refs → getStoreOptionGroup
"담기" 버튼 onTap
  → addToCartUseCase(
       storeId: ...,
       storeName: ...,
       cartItem: CartItemEntity(...),
     )
  → cartRepository.addItem
       → cartLocalDataSource.addItem
       → 다른 매장이면 emit ConfirmReplaceException → UI 다이얼로그 → 사용자 승인 후 clear() 후 재시도
  → 성공 시 pop + 토스트
```

### 카트 보기

```
AppBar 카트 아이콘 onTap
  → context.push('/cart')
CartPage build
  → ref.watch(cartProvider)
       → watchCartUseCase
       → cartRepository.watchCart
       → cartLocalDataSource.watch (Stream<CartEntity?>)
"결제하기" → 스낵바 ("결제 기능 준비 중")
```

### 즐겨찾기 토글

```
FavoriteToggleIconButton onTap
  → 비로그인이면 로그인 유도 다이얼로그
  → toggleFavoriteStoreUseCase(userId, storeId)  /  toggleFavoriteMenuItemUseCase(userId, storeId, menuItemId)
  → favoritesRepository.toggle*
  → favoritesRemoteDataSource: doc 존재하면 delete, 없으면 set
  → watchFavoriteStoresProvider 가 자동 갱신
```

---

## 에러 처리

| 케이스 | 처리 |
|---|---|
| 매장 메뉴 0개 | "등록된 메뉴가 없어요" 빈 상태 화면 |
| 메인 카테고리 매장 보유 0 | 해당 탭 비활성/숨김 |
| Firestore 조회 실패 | 에러 카드 + 재시도 버튼 (`ref.invalidate`) |
| 음료 상세 진입 후 메뉴 deleted | "메뉴를 찾을 수 없어요" + 뒤로가기 |
| 필수 옵션 미선택 | "담기" 버튼 비활성 + 누르면 토스트로 미선택 그룹 안내 |
| 다른 매장 카트 충돌 | 확인 다이얼로그 → 사용자 승인 후 카트 초기화 + 추가 |
| 카트 수량 0 입력 | 라인 자동 삭제 (또는 stepper 가 1 이하 못 가게 막음) |
| 즐겨찾기 토글 시 비로그인 | 로그인 유도 다이얼로그 |
| 즐겨찾기 토글 시 네트워크 실패 | 토스트 ("저장 실패") + 낙관적 UI 롤백 |
| 카트 매장의 음료 정보가 변동 (가격 변경, 품절) | Phase 1 비대응 (메모리 카트라 단명) — 결제 Phase 에서 검증 단계 추가 |

---

## 보안 / 환경 설정

- 변경 없음. (Firestore 보안 규칙 별도 task)
- 단, **즐겨찾기 / 카트는 인증된 사용자 기반**. 비로그인 사용자는 로그인 유도.
- Firestore 룰 작성 task 에서: `users/{uid}/favoriteStores` 등은 본인만 read/write 허용.

---

## 작업 분배

### designer (먼저 호출 권장)

다음 화면의 design.md 작성:

1. **StoreMenuPage**: 매장 헤더(이미지/이름/등급/거리/즐겨찾기/영업상태) + 메인 카테고리 탭 + 부 카테고리 chips + 메뉴 그리드 (2열 카드, 이미지/이름/가격/품절오버레이)
2. **MenuItemDetailPage**: 메뉴 이미지(상단), 즐겨찾기 토글, 이름/설명/가격, 옵션 그룹 섹션(단일/다중), 수량 stepper, 하단 고정 "담기" 버튼 with 실시간 합계
3. **CartPage**: 매장 헤더 + 비우기 버튼, 라인 카드(이미지/이름/옵션요약/수량/라인합계/삭제), 하단 고정 합계 + "결제하기" 버튼
4. **공통 위젯**: `OptionGroupSelector` (라디오/체크박스 분기), `QuantityStepper`, `FavoriteToggleIconButton`
5. **상태 UI**: 각 페이지의 loading / error / empty 변형

레퍼런스: `docs/design/screens/` 의 기존 매장/홈 디자인 + Qradar 디자인 시스템(`docs/agents/designer_guide.md`).

### developer (디자인 확정 후)

상세는 `docs/agents/developer_guide.md` 의 구현 순서를 따라 도메인 → 데이터 → 프레젠테이션 순서로 진행.

핵심 작업:

1. `lib/core/constants/recommendation_thresholds.dart` 생성 (사용은 안 함)
2. `lib/core/constants/firestore_paths.dart` 에 신규 컬렉션 키 추가
3. **Domain**: 엔티티 + Repository 인터페이스 + UseCase
4. **Data**: 모델 + DataSources + RepositoryImpl (OrderLog 는 Repository Impl 제외)
5. **Presentation**: Providers → Pages → Widgets
6. **Router**: `/order/store/:storeId`, `/order/store/:storeId/menu/:menuItemId`, `/cart`
7. **기존 진입점 수정**:
   - 홈 매장 카드 onTap → 신규 라우트
   - 주문 탭 매장 카드 onTap → 신규 라우트
   - `store_map_marker_sheet` "주문하기" → 신규 라우트 (placeholder 스낵바 제거)
8. **Firestore 시드 데이터** (개발 검증용):
   - `subCategories` 글로벌 약 6~8개
   - `optionGroups` 글로벌 (온도, 샷, 시럽) 3개
   - 1개 매장에 menuItems 6~8개 (각 메인 카테고리 골고루) + store optionGroups 1~2개
   - 시드 절차는 implementation.md 에 기록 (Firestore 콘솔 수동)
9. `flutter analyze` / `flutter test` 실행

산출물: `docs/tasks/order_flow_phase1/implementation.md`

### tester (구현 후)

검증 대상:

- spec.md 의 모든 기능 요구사항 (체크리스트 위주)
- 레이어 규칙 (presentation 에서 Firebase 직접 import 없음, 색상 하드코딩 없음)
- 상태 UI 3종 (loading/error/empty) 각 페이지
- 카트 충돌 다이얼로그 동작 (다른 매장 메뉴 추가 시)
- 필수 옵션 미선택 시 "담기" 비활성
- 즐겨찾기 토글 비로그인 처리
- 라우팅: 진입점 3곳(홈/주문 리스트/주문 지도) 모두 같은 라우트로 가는지
- 결제 버튼이 "준비 중" 스낵바인지 (Phase 3 비범위 명시)
- OrderLog 인프라가 인터페이스/모델만 있고 RepositoryImpl 이 없는지 (의도된 비범위)

산출물: `docs/tasks/order_flow_phase1/test_report.md`

---

## 분할 권장 (Optional — 사용자 판단)

본 Phase 1 의 범위가 매우 크다. 다음과 같이 **분할 진행 가능**:

| 서브 단계 | 범위 |
|---|---|
| **Phase 1a** | Domain + Data 전부 + 라우팅 + StoreMenuPage + MenuItemDetailPage (옵션 선택 + 수량 + 합계) — 카트 담기는 placeholder 스낵바 |
| **Phase 1b** | CartPage 본구현 + addToCart 동작 연결 + 매장 충돌 다이얼로그 |
| **Phase 1c** | 즐겨찾기 토글 (매장/메뉴) UI + Repository |

분할 시 `docs/tasks/order_flow_phase1a/`, `1b/`, `1c/` 로 spec/design/implementation/test_report 분리.

분할하지 않으려면 본 spec.md 그대로 designer/developer 호출 가능 (단, 산출 코드량이 매우 큼).

---

## 완료 기준

- [ ] 요구사항이 모두 구현되거나 보류 사유가 명시됨
- [ ] `design.md` 작성 완료
- [ ] `implementation.md` 작성 완료 — 시드 데이터 절차 포함
- [ ] `test_report.md` 작성 완료
- [ ] FAIL 항목이 없거나 후속 작업으로 분리됨
- [ ] `flutter analyze` 0 issue
- [ ] 매장 진입 3개 경로(홈/주문리스트/지도마커) 모두 동작
- [ ] 카트 메모리 동작 검증 (앱 재시작 시 초기화 확인)
- [ ] OrderLog 모델/인터페이스가 존재하고 RepositoryImpl 이 명시적으로 비어있음 (또는 미작성)
