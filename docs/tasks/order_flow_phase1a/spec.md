# order_flow_phase1a 기능 명세 (Phase 1a — 매장 메뉴 + 음료 상세 + 옵션)

> 본 spec 은 우산 문서 [docs/tasks/order_flow_phase1/spec.md](../order_flow_phase1/spec.md) 의 결정사항 1~8 을 그대로 따른다. 데이터 모델 / 카테고리 체계 / 옵션 구조 / 컬렉션 경로는 우산 문서를 단일 진실원으로 본다.

---

## 개요

- **목적**: 매장을 진입해 메뉴를 탐색하고, 음료 상세에서 옵션을 골라 가격을 계산하는 흐름을 완성한다. **카트 담기는 placeholder 스낵바** ("Phase 1b 에서 구현")로 둔다.
- **작업 유형**: 신규 기능 (대형)
- **결제는 Phase 3, 카트는 Phase 1b, 즐겨찾기는 Phase 1c 로 분리**.

### 영향 범위

| 레이어 | 영향 |
|---|---|
| 화면 | (신규) `StoreMenuPage`, `MenuItemDetailPage` |
| Domain | (신규) MainCategoryCode / SubCategoryEntity / MenuItemEntity / OptionGroupEntity / OptionItemEntity / OptionScope / OptionSelectionType + 각 Repository 인터페이스 + UseCase. **CartItemEntity / CartEntity 도 본 phase 에서 정의**(다음 phase 에서 사용) |
| Domain (인터페이스만) | OrderLogEntity + OrderLogRepository + CartRepository + FavoritesRepository (인터페이스 + 임시 빈 stub Impl 또는 미작성 — 아래 결정 참조) |
| Data | (신규) sub_category, menu_item, option (master + store) — Model + DataSource + RepositoryImpl. CartLocalDataSource 는 Phase 1b. FavoritesRemoteDataSource 는 Phase 1c. OrderLog 는 Phase 3. |
| Presentation | (신규) `presentation/customer/order/store/`, `presentation/customer/order/menu/` |
| 공통 컴포넌트 | (신규) `OptionGroupSelector`, `QuantityStepper` |
| 라우팅 | (신규) `/order/store/:storeId`, `/order/store/:storeId/menu/:menuItemId` |
| 기존 진입점 수정 | 홈 매장 카드, 주문 리스트/지도 매장 선택 → 신규 라우트 |
| 시드 | `lib/dev/seed/` 폴더 + MorePage long-press 트리거 |
| 권한 / 환경 | 변경 없음 |

### 비범위 (Phase 1a)

- CartPage 본구현, addToCart 실제 카트 저장, 매장 충돌 다이얼로그 → **Phase 1b**
- 즐겨찾기 토글 UI / Repository → **Phase 1c**
- 결제 → **Phase 3**
- 관리자/점주 화면 (admin/owner CRUD)
- OrderLog Repository Impl (인터페이스/Entity/Model 만 정의 — Phase 3 에서 Impl)

---

## 결정사항 (architect, Phase 1a 한정)

### 결정 A. CartRepository / FavoritesRepository / OrderLogRepository 의 Phase 1a 처리

- **OrderLogRepository**: Entity + Model + Interface 작성. **RepositoryImpl 미작성** (Phase 3 에서 작성). Provider 선언 없음.
- **CartRepository**: 인터페이스만 정의 (Phase 1b 가 의존). **RepositoryImpl 미작성**. Provider 선언 없음.
- **FavoritesRepository**: 인터페이스만 정의 (Phase 1c 가 의존). **RepositoryImpl 미작성**. Provider 선언 없음.
- 이유: 이번 phase 의 화면이 cart/favorites 를 호출하지 않음. Impl 을 미리 만들면 dead code → tester 검증/유지보수 부담. 인터페이스만 미리 두면 다음 phase 가 Domain 변경 없이 진입 가능.

### 결정 B. "담기" 버튼 동작

- `MenuItemDetailPage` 의 "담기" 버튼은 placeholder 로 토스트 표시: "장바구니 기능은 준비 중입니다 (Phase 1b)".
- 단, **현재 가격 계산 / 옵션 충족 / 수량 stepper 로직은 모두 본 phase 에서 완성** — Phase 1b 는 onTap 만 교체하면 됨.

### 결정 C. 시드 진입 UI

- **위치**: `MorePage` (`presentation/customer/more/`) 하단 앱 버전 표시 텍스트.
- **트리거**: 텍스트 long-press (1초) → 다이얼로그 노출.
- **다이얼로그 내용**: "Phase 1 개발용 시드 데이터 — 실행 시 sub_categories / option_groups / 임시 매장 1개 + 메뉴 6~8개 가 Firestore 에 기록됩니다. 이미 존재 시 덮어씀." + "실행" / "취소" 버튼.
- **kDebugMode 분기**: `if (kDebugMode) GestureDetector(onLongPress: ...)` 로 release 빌드 차단.

---

## 요구사항

### 기능 요구사항

#### 매장 진입 (라우팅)
- [ ] 홈 화면 매장 카드 탭 → `context.push('/order/store/:storeId')`
- [ ] 주문 탭 매장 리스트 카드 탭 → 동일 라우트
- [ ] 주문 탭 지도 마커 시트 "주문하기" 버튼 → 동일 라우트 (기존 placeholder 스낵바 제거)
- [ ] 라우터에 `/order/store/:storeId`, `/order/store/:storeId/menu/:menuItemId` 등록

#### StoreMenuPage
- [ ] AppBar: 닫기/뒤로 + 매장 이름 + 우상단 카트 아이콘 (Phase 1a 는 카트 페이지로 이동만 가능 → Phase 1b 의존이므로 본 phase 는 placeholder 스낵바)
- [ ] 매장 헤더 카드: 이미지 / 이름 / 등급 뱃지 / 거리 / 영업 상태 / 즐겨찾기 토글 자리 (Phase 1c 까지 비활성 + "준비 중" 토스트)
- [ ] 메인 카테고리 탭 3개 (커피/논커피/디저트). 매장 보유 0 인 메인 카테고리 탭은 비활성.
- [ ] 부 카테고리 chips: 매장이 보유한 부 카테고리만 노출. 1개뿐이면 자동 숨김.
- [ ] 메뉴 그리드 (2열, 이미지/이름/기본가, 품절은 회색 오버레이 + "품절" 뱃지)
- [ ] 메뉴 카드 탭 → 음료 상세 라우트 push

#### MenuItemDetailPage
- [ ] 상단 메뉴 이미지 + 즐겨찾기 토글 자리 (Phase 1c 까지 placeholder 스낵바)
- [ ] 이름 / 설명 / 기본가
- [ ] 옵션 그룹 섹션 — 그룹별 헤더(이름 + 필수 라벨) + 라디오/체크박스
  - 단일/필수: 라디오, 첫 항목 자동 선택 (selectionType=single + required)
  - 단일/선택: 라디오 + "선택 안함" 옵션
  - 다중/선택: 체크박스
  - 각 항목 priceDelta 표시 (음수면 할인 표기)
- [ ] 수량 stepper (최소 1, 최대 99)
- [ ] 실시간 합계: `(basePrice + 선택 옵션 priceDelta 합) × quantity`
- [ ] 하단 고정 "담기" 버튼:
  - 필수 옵션 미선택 시 비활성 + 누르면 미충족 그룹 안내 토스트
  - 활성 시 누르면 placeholder 토스트 ("장바구니 기능은 준비 중입니다")

### 상태 요구사항

| 화면 | 로딩 | 에러 | 빈 상태 |
|---|---|---|---|
| StoreMenuPage | shimmer (헤더 + 그리드 4~6개) | 에러 카드 + "재시도" → `ref.invalidate(storeMenuItemsProvider(storeId))` | 메뉴 0개 → "등록된 메뉴가 없어요" + 뒤로가기 |
| MenuItemDetailPage | shimmer (이미지 + 텍스트 라인) | 에러 카드 + "재시도" | 메뉴 deleted → "메뉴를 찾을 수 없어요" + 뒤로가기 |

---

## 데이터 모델

우산 문서 [docs/tasks/order_flow_phase1/spec.md#데이터-모델](../order_flow_phase1/spec.md) 의 정의를 따른다.

본 phase 에서 **실제 사용**하는 엔티티: `MainCategoryCode`, `SubCategoryEntity`, `MenuItemEntity`, `OptionGroupEntity`, `OptionItemEntity`, `OptionScope`, `OptionSelectionType`.

본 phase 에서 **인터페이스/Entity/Model 만 정의**(미사용): `CartEntity`, `CartItemEntity`, `SelectedOption`, `FavoriteStoreEntity`, `FavoriteMenuItemEntity`, `OrderLogEntity`.

---

## 레이어 설계

### Domain (`lib/domain/`)

**Entities**:
- `entities/main_category_code.dart` (enum + label getter)
- `entities/sub_category_entity.dart` (freezed)
- `entities/menu_item_entity.dart` (freezed)
- `entities/option_scope.dart` (enum)
- `entities/option_selection_type.dart` (enum)
- `entities/option_group_entity.dart` (freezed, items 포함)
- `entities/option_item_entity.dart` (freezed)
- `entities/cart_entity.dart`, `cart_item_entity.dart`, `selected_option.dart` (freezed) — **본 phase 미사용, 인터페이스 호환용**
- `entities/favorite_store_entity.dart`, `favorite_menu_item_entity.dart` (freezed) — **인터페이스 호환용**
- `entities/order_log_entity.dart`, `order_log_item.dart` (freezed) — **인터페이스 호환용**

**Repository Interfaces**:
- `repositories/menu_category_repository.dart` — `Stream<List<SubCategoryEntity>> watchSubCategories(MainCategoryCode main)`
- `repositories/menu_item_repository.dart` — `watchByStore`, `watchById`
- `repositories/option_repository.dart` — `getMasterOptionGroup`, `getStoreOptionGroup`, `getOptionGroupsForMenuItem`
- `repositories/cart_repository.dart` — 시그니처만 (Impl 없음)
- `repositories/favorites_repository.dart` — 시그니처만 (Impl 없음)
- `repositories/order_log_repository.dart` — 시그니처만 (Impl 없음)

**UseCases**:
- `usecases/watch_sub_categories_use_case.dart`
- `usecases/watch_menu_items_by_store_use_case.dart`
- `usecases/watch_menu_item_detail_use_case.dart`
- `usecases/get_option_groups_for_menu_item_use_case.dart`
- 카트/즐겨찾기/Log UseCase 는 **본 phase 에서 작성하지 않음** (다음 phase 가 작성)

### Data (`lib/data/`)

**Models** (freezed + json_serializable):
- `models/sub_category_model.dart`
- `models/menu_item_model.dart`
- `models/option_group_model.dart`, `option_item_model.dart`, `option_group_ref.dart`
- `models/cart_model.dart` 등 — **freezed 정의만, fromJson/toJson 도 작성** (다음 phase 사용 대비). RepositoryImpl 은 미작성.
- `models/favorite_*_model.dart`, `models/order_log_model.dart` — 동일 (정의만)

**DataSources**:
- `datasources/remote/sub_category_remote_data_source.dart` — `subCategories` 글로벌 컬렉션 stream
- `datasources/remote/menu_item_remote_data_source.dart` — `stores/{storeId}/menuItems` stream + doc
- `datasources/remote/option_remote_data_source.dart` — `optionGroups/{id}` (master) + `stores/{storeId}/optionGroups/{id}` (store)

**Repository Impl**:
- `repositories/menu_category_repository_impl.dart`
- `repositories/menu_item_repository_impl.dart`
- `repositories/option_repository_impl.dart`

**Firestore Paths 추가** (`lib/core/constants/firestore_paths.dart`):
- `subCategories`, `optionGroups`, `menuItems` (서브컬렉션 키), `optionGroupsSubcollection` (스토어 서브컬렉션 키), `favoriteStores`, `favoriteMenuItems`, `orderLogs` (예약)

**Recommendation Thresholds**:
- `lib/core/constants/recommendation_thresholds.dart` — 우산 spec 결정 8 의 잠정값. 본 phase 에서 사용처 없음.

### Presentation

**Pages**:
- `presentation/customer/order/store/store_menu_page.dart`
- `presentation/customer/order/menu/menu_item_detail_page.dart`

**Widgets**:
- `presentation/customer/order/store/widgets/store_menu_header.dart`
- `presentation/customer/order/store/widgets/main_category_tabs.dart`
- `presentation/customer/order/store/widgets/sub_category_chips.dart`
- `presentation/customer/order/store/widgets/menu_item_card.dart`
- `presentation/customer/order/menu/widgets/option_group_selector.dart`
- `presentation/common/quantity_stepper.dart` (공통 위젯)

**Providers**:
- `presentation/customer/order/store/providers/store_menu_providers.dart`
  - `subCategoriesProvider(MainCategoryCode)` — StreamProvider.family
  - `storeMenuItemsProvider(String storeId)` — StreamProvider.family
  - `selectedMainCategoryProvider` — Notifier (default `coffee`)
  - `selectedSubCategoryIdProvider` — Notifier (nullable, 메인 카테고리 변경 시 초기화)
  - `storeAvailableSubCategoriesProvider(String storeId)` — Provider.family (메뉴 items × 메인 카테고리 × subCategoryId 조합)
  - `filteredMenuItemsProvider(String storeId)` — Provider.family (메인+부 필터)
- `presentation/customer/order/menu/providers/menu_detail_providers.dart`
  - `menuItemDetailProvider((storeId, menuItemId))` — StreamProvider.family
  - `menuItemOptionGroupsProvider((storeId, menuItemId))` — FutureProvider.family
  - `menuItemSelectedOptionsProvider(menuItemId)` — Notifier<Map<groupId, Set<itemId>>>.family
  - `menuItemQuantityProvider(menuItemId)` — Notifier<int>.family (default 1)
  - `menuItemCurrentPriceProvider((storeId, menuItemId))` — Provider.family
  - `menuItemAddToCartReadyProvider((storeId, menuItemId))` — Provider.family<bool>

**라우팅** (`lib/app/router.dart`):
- `/order/store/:storeId` → `StoreMenuPage`
- `/order/store/:storeId/menu/:menuItemId` → `MenuItemDetailPage`

### 시드 (`lib/dev/seed/`)

**모든 파일 첫 줄 주석**: `// DEV_ONLY_SEED — order_flow_phase1. 사용자 요청 시 lib/dev/seed/ 폴더 통째로 삭제.`

- `lib/dev/seed/phase1_seed.dart` — `Future<SeedResult> runPhase1Seed()` (Firestore 쓰기)
- `lib/dev/seed/phase1_seed_data.dart` — 하드코딩된 시드 페이로드 (subCategories ~6, optionGroups ~3, 임시 매장 1 + menuItems 6~8 + store optionGroups 1)
- `lib/dev/seed/dev_seed_trigger.dart` — `MorePage` 에 삽입할 위젯 (`kDebugMode` 분기 + long-press + 다이얼로그). 단 1개의 import 점만 외부에 노출.

**MorePage 수정 1줄**:
```dart
// 앱 버전 텍스트 자리에:
const _versionText = Text('Qradar v$appVersion');
// kDebugMode 일 때만 long-press 활성:
final versionWidget = kDebugMode
    ? const DevSeedTrigger(child: _versionText)  // 이 1줄이 시드 진입점
    : _versionText;
```

**제거 절차** (사용자가 "지워달라" 시):
1. `rm -rf lib/dev/seed/`
2. `MorePage` 의 `DevSeedTrigger` import 1 줄 제거 + 위 위젯 분기를 `_versionText` 로 단순화
3. `grep -r DEV_ONLY_SEED lib/` 로 잔존 마커 0건 확인

---

## 데이터 흐름

### 매장 메뉴 표시
```
홈 StoreCard onTap
  → context.push('/order/store/$storeId')
StoreMenuPage build
  → ref.watch(storeMenuItemsProvider(storeId))
       → watchMenuItemsByStoreUseCase(storeId)
       → menuItemRepository.watchByStore(storeId)
       → menuItemRemoteDataSource.streamByStore(storeId)
       → Firestore: stores/{storeId}/menuItems (orderBy displayOrder)
  → ref.watch(subCategoriesProvider(selectedMainCategory))
  → ref.watch(filteredMenuItemsProvider(storeId))
       → 메인 + 선택된 부 카테고리(or 전체) 필터
```

### 음료 상세 + 옵션 + 가격 계산
```
MenuItemCard onTap
  → context.push('/order/store/$storeId/menu/$menuItemId')
MenuItemDetailPage build
  → ref.watch(menuItemDetailProvider((storeId, menuItemId)))
  → ref.watch(menuItemOptionGroupsProvider((storeId, menuItemId)))
       → getOptionGroupsForMenuItemUseCase(menuItem)
       → optionRepository.getOptionGroupsForMenuItem
            ├─ scope=master refs → optionRemoteDataSource.getMaster(id)
            └─ scope=store refs → optionRemoteDataSource.getStore(storeId, id)

옵션 라디오/체크박스 토글
  → ref.read(menuItemSelectedOptionsProvider(menuItemId).notifier).toggle(groupId, itemId)
수량 stepper +/-
  → ref.read(menuItemQuantityProvider(menuItemId).notifier).set(n)
가격 표시
  → ref.watch(menuItemCurrentPriceProvider((storeId, menuItemId)))
       → basePrice + Σ(selected option priceDelta) × quantity
"담기" 버튼 활성 여부
  → ref.watch(menuItemAddToCartReadyProvider((storeId, menuItemId)))
       → 모든 required 그룹이 1개 이상 선택됐는지 체크

"담기" onTap (Phase 1a)
  → 필수 미충족 시 미충족 그룹 토스트
  → 충족 시 "장바구니 기능은 준비 중입니다 (Phase 1b)" 토스트
  → (Phase 1b 에서 addToCartUseCase 호출로 교체)
```

### 시드 실행
```
MorePage 앱 버전 long-press
  → 다이얼로그 ("실행 / 취소")
  → "실행" → runPhase1Seed()
  → Firestore writes (batched):
       - subCategories/{id} 6~8개
       - optionGroups/{id} 3개 (master)
       - stores/seed_dev_store_001 (필요한 필드)
       - stores/seed_dev_store_001/menuItems/{id} 6~8개
       - stores/seed_dev_store_001/optionGroups/{id} 1개 (store)
  → SnackBar "시드 완료 ({write 수})"
```

---

## 에러 처리

| 케이스 | 처리 |
|---|---|
| Firestore 조회 실패 | StreamProvider error → 에러 카드 + 재시도 |
| 매장 메뉴 0개 | 빈 상태 화면 |
| 메인 카테고리 매장 보유 0 | 해당 탭 비활성 |
| 부 카테고리 1개뿐 | chips UI 자동 숨김 |
| 옵션 그룹 fetch 실패 | 상세 페이지 에러 카드 + 재시도 |
| 메뉴 deleted (`menuItemDetailProvider` null) | "메뉴를 찾을 수 없어요" + 뒤로가기 |
| 필수 옵션 미선택 | "담기" 비활성, 누르면 미충족 그룹 토스트 |
| 즐겨찾기 토글 (Phase 1c 까지) | "즐겨찾기는 준비 중입니다 (Phase 1c)" 토스트 |
| 카트 진입 (AppBar 카트 아이콘) | "장바구니는 준비 중입니다 (Phase 1b)" 토스트 |
| 시드 실행 실패 (네트워크/권한) | 다이얼로그 결과 SnackBar 에 에러 메시지 |

---

## 작업 분배

### designer

작성 대상: `docs/tasks/order_flow_phase1a/design.md`

1. **StoreMenuPage**
   - 매장 헤더 (이미지/이름/등급 뱃지/거리/영업 상태/즐겨찾기 토글 자리)
   - 메인 카테고리 탭 3개 (TabBar 또는 segmented 형태 — Qradar 디자인 시스템 기준 결정)
   - 부 카테고리 chips (가로 스크롤 가능)
   - 메뉴 그리드 (2열, MenuItemCard: 이미지/이름/가격/품절 오버레이)
2. **MenuItemDetailPage**
   - 메뉴 이미지(상단 비율 결정), 즐겨찾기 토글
   - 이름/설명/기본가
   - OptionGroupSelector (라디오/체크박스 — 그룹 헤더 + 필수 뱃지 + 항목 priceDelta 표기)
   - QuantityStepper
   - 하단 고정 "담기" 버튼 + 실시간 합계
3. **공통 위젯**
   - `OptionGroupSelector` (단일/다중)
   - `QuantityStepper`
4. **상태 UI** 각 페이지의 loading/error/empty
5. **시드 다이얼로그** — 텍스트만 (Qradar 다이얼로그 스타일 따름)

### developer

상세는 `docs/agents/developer_guide.md`. 작성 대상: `docs/tasks/order_flow_phase1a/implementation.md`

핵심 작업 순서:
1. `lib/core/constants/recommendation_thresholds.dart` 생성
2. `lib/core/constants/firestore_paths.dart` 신규 키 추가
3. **Domain 전부**: enums + entities (freezed) + repository 인터페이스 6개 + UseCase 4개 (Phase 1a 사용분만)
4. **Data**:
   - 사용 entity 의 model + datasource + repositoryImpl 3개
   - 다른 entity 의 model 정의만 (cart/favorites/orderLog)
5. **Presentation**: providers → pages → widgets
6. **Router** 수정
7. **기존 진입점 수정**:
   - `home_page.dart` 매장 카드 onTap
   - `store_list_tab.dart` 매장 카드 onTap
   - `store_map_marker_sheet.dart` "주문하기" 버튼
8. **시드** (`lib/dev/seed/`):
   - `phase1_seed_data.dart` 페이로드 작성
   - `phase1_seed.dart` Firestore writes
   - `dev_seed_trigger.dart` MorePage 진입 위젯
   - MorePage 1줄 수정
9. `flutter analyze` / 시드 실행 후 매장 진입 → 메뉴 → 옵션 → 가격 표시까지 수동 검증

산출물: 코드 + `implementation.md` (시드 제거 절차 명시)

### tester

작성 대상: `docs/tasks/order_flow_phase1a/test_report.md`

검증:
- 라우팅 3개 진입점 (홈/주문리스트/지도마커)
- 메인 카테고리 탭, 부 카테고리 chips 표시 규칙 (보유 0 → 비활성 / 1 → 숨김)
- 메뉴 그리드 + 카드 탭 → 상세 진입
- 옵션 그룹 단일/다중 동작, 필수 충족 검증
- 가격 실시간 계산
- "담기" placeholder 토스트
- 카트 아이콘 / 즐겨찾기 토글 placeholder 토스트
- 상태 UI 3종 (loading/error/empty)
- 시드 진입 트리거 release 빌드 차단 (`kDebugMode` 분기)
- 시드 실행 후 Firestore 데이터 정상 기록
- 레이어 규칙: presentation 에서 Firebase import 없음, 색상 하드코딩 없음
- `flutter analyze` 0 issue

---

## 완료 기준

- [ ] `design.md` / `implementation.md` / `test_report.md` 작성 완료
- [ ] `flutter analyze` 0 issue
- [ ] 매장 진입 3개 경로 모두 동작
- [ ] 옵션 선택 → 가격 계산 정상
- [ ] "담기" 버튼이 Phase 1b 인계 가능 상태 (onTap 만 교체하면 됨)
- [ ] 시드 실행 후 검증 매장 1개 + 메뉴 6~8개 정상 노출
- [ ] 시드 제거 절차가 implementation.md 에 기록됨
- [ ] FAIL 항목 0 또는 후속 분리
