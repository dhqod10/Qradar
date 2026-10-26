# 홈 검색 + 추천 매장 전체보기 구현 기록

| 일자 | 작성자 | 내용 |
|---|---|---|
| 2026-10-26 | developer | **2차 개정(spec §15 / design §13) 구현 — §12 추가** (1차 이력 보존). |
| 2026-10-26 | developer | 검증 FAIL 3건 + 부수 5건 수정 반영(§11). |
| 2026-10-26 | developer | 최초 작성. spec §9 · design §1~§10 기준 구현. 확정 결정(D1~D7, N1 확장안) 변경 없음 |

## 1. 구현 요약

- 홈이 매장을 **한 번만** 읽는다: `storeSnapshotProvider`(승인 매장 전체, 거리 포함, `fetchAll(100)` 1회). 주변 / 카테고리 필터 / 추천 미리보기·전체 / 검색이 모두 이 스냅샷의 순수 파생이다.
- 메뉴 검색은 **Lazy Menu Index**: 질의 2글자 이상에서 처음 구독될 때 출처 단위 `get()` 1회, 세션 캐시.
- 검색 화면의 모든 상태는 `resolveSearchView(storeAsync, menuAsync, normalizedQuery)` 한 함수가 enum 으로 결정한다. 위젯은 렌더만 한다.
- `StoreMenuPage` 에 `initialMainCategoryCode` / `highlightMenuItemId` 추가 (N1 확장안).

## 2. 파일

### 신규
| 레이어 | 파일 |
|---|---|
| core | `lib/core/utils/search_normalizer.dart` |
| domain | `entities/menu_search_hit_entity.dart` (+`.freezed.dart`, `MenuHitSource`, `MenuSearchIndex`), `usecases/get_approved_stores_use_case.dart`, `usecases/search_stores_use_case.dart`, `usecases/search_menu_items_use_case.dart` |
| presentation/common | `store_list_states.dart` (skeleton / 에러 블록 / 카테고리 빈 상태 — 홈·전체보기·검색 공용, 문구는 파라미터) |
| presentation/home | `recommended_stores_page.dart`, `providers/recommended_stores_providers.dart` |
| presentation/search | `search_page.dart`, `providers/search_providers.dart`, `widgets/{search_input_bar,menu_search_result_tile,recent_search_list,search_state_widgets}.dart` |
| test | `test/core/search_normalizer_test.dart`, `test/domain/home_search_use_cases_test.dart`, `test/presentation/home_search_providers_test.dart`, `test/presentation/home_search_widgets_test.dart` |

### 수정
| 파일 | 내용 |
|---|---|
| `core/constants/grade_thresholds.dart` | 상수 7개 (`searchRadiusKm`, `menuSearchStoreLimit`, `menuSearchResultLimit`, `recommendedPreviewCount`, `recentSearchLimit`, `searchDebounceMs`, `menuSearchMinQueryLength`). 위젯에 숫자 리터럴을 두지 않고 보간 |
| `domain/repositories/{store,menu_item,master_menu_item}_repository.dart` + impl 3 | `getApprovedStores` / `fetchStoreMenusOnce` / `fetchBrandMasterMenusOnce`. 기존 메서드 동작 불변 (주문 탭 `orderBaseStoresProvider` 무수정) |
| `data/datasources/remote/{menu_item,master_menu_item}_remote_data_source.dart` | `fetchByStore` / `fetchAllByBrand` — `.orderBy('displayOrder').get()` 만 |
| `domain/usecases/get_nearby_stores_use_case.dart`, `get_stores_by_categories_use_case.dart` | 순수 static `withinRadius` / `filterByCategories` 추가 (`call()` 불변) |
| `home/providers/home_providers.dart` | `storeSnapshotProvider` 신설. `nearbyStoresProvider` / `filteredStoresProvider` 는 `Provider<AsyncValue<…>>` 파생으로 변경 |
| `home/providers/recommendation_providers.dart` | `storesByIdProvider` 가 스냅샷을 본다 |
| `home/home_page.dart`, `widgets/nearby_stores_section.dart`, `widgets/recommended_stores_section.dart` | invalidate 대상을 `storeSnapshotProvider` 로 교체 |
| `home/widgets/home_header.dart` | `SearchPage` push. 박스 문구·스타일 불변, Semantics 추가 |
| `home/widgets/recommended_stores_section.dart` | 5건 미리보기, 헤더 전체 건수, `전체보기`(44px) + `N곳 더 보기` 버튼, 에러 문구 교체 |
| `home/widgets/store_card.dart` | `RecommendedStoreCard.subtitle`(nullable, 기본 null = 레이아웃 불변) |
| `order/store/store_menu_page.dart`, `widgets/menu_item_card.dart` | `initialMainCategoryCode`, `highlightMenuItemId`, 안내 띠, 카드 테두리 |

## 3. 핵심 설계 결정

1. **스냅샷 파생**: 카테고리 토글·정렬 변경은 순수 compute 라 읽기가 생기지 않는다. 홈 당겨서 새로고침과 모든 `다시 시도` 는 `storeSnapshotProvider` 하나만 invalidate.
2. **메뉴 인덱스 provider 는 질의를 보지 않는다** (`menuSearchIndexProvider`, autoDispose 아님 = 세션 캐시). 후보 = 스냅샷의 `distanceKm ≤ 10km` 상위 30곳. 정규화 길이 < 2 면 `menuSearchResultsProvider` 가 인덱스를 구독하지 않는다.
3. **출처별 실패 흡수**: 브랜드/개인 출처마다 try/catch. 일부 실패는 `failedSourceCount`, 전부 실패(출처 ≥ 1)면 예외 -> 메뉴 섹션만 에러. 로그는 `dart:developer log`.
4. **필터 위치**: `SearchMenuItemsUseCase.buildIndex`(domain). 마스터 = `visible && approved`, 개인 매장 = `visible && (status null || approved)` — `StoreMenuPage` 와 같은 기준.
5. **`resolveSearchView`**: 0글자 / 1글자 4상태 / 2글자 이상 12상태(design §3-c 번호 그대로 `s1…s12`). `hasValue` 우선이라 재시도(refresh) 중에도 직전 결과 행이 유지된다. 통합 빈 상태(`s10`, `s12`)는 메뉴가 확정(데이터 0 또는 부분 실패)일 때만 나온다.
6. **건수는 한 곳**: 검색은 `SearchViewModel.storeCount/menuTotal`, 홈은 `recommendedTotalCountProvider`(= `length`). 로딩·에러에서는 `(n)` 을 그리지 않는다.
7. **`selectedMainCategoryProvider` (전역)**: `Future.microtask` 로 첫 프레임 직후 적용(빌드 중 provider 수정 금지). 이 화면이 바꾼 경우에만 `dispose` 때 `null` 로 되돌려 다른 매장으로 새지 않게 한다. 매장에 없는 카테고리면 기존 `filteredMenuItemsProvider` 가 무시(= 현행 동작).
8. **비로그인**: `getApprovedStores` 가 `permission-denied` 를 `PermissionDeniedException` 으로 변환 -> 검색 화면이 `로그인이 필요해요` + `로그인` 버튼. (다른 매장 조회 경로는 불변)

## 4. 표면 인벤토리 15행 반영 (design §1)

| 행 | 구현 위치 | 반영 |
|---|---|---|
| F1-1 검색 매장 섹션 | `SearchView.shortError/s2StoreError` -> `StoreListError` 검색 영역 전체, 입력창 유지, 메뉴 섹션 숨김 | 완료 (위젯 테스트) |
| F1-2 홈 미리보기 | `recommendedStoresPreviewProvider`, 에러 시 `StoreListError`, 헤더 건수 없음 | 완료 |
| F1-3 전체보기 목록 | `RecommendedStoresPage._body` 에러 블록, 칩·정렬 토글 유지, 건수 줄은 skeleton 바 | 완료 |
| F1-4 헤더 건수 | `recommendedTotalCountProvider` (데이터 없으면 null -> 건수 미표기) | 완료 |
| F1-5 `전체보기`/`더 보기` 노출 | 같은 provider `> recommendedPreviewCount` 일 때만 | 완료 |
| F1-6 `전체 n곳` | 같은 provider, 로딩이면 숨김 | 완료 |
| F2-1 메뉴 결과 / 에러 / 부분 실패 | `s6/s11` `MenuErrorCard`(메뉴 인덱스만 invalidate), `s7/s9/s12` `MenuPartialFailureRow` | 완료 |
| F2-2 `메뉴 (n)` | 로딩·에러·1글자는 헤더 `메뉴` 만 | 완료 |
| F2-3 통합 빈 상태 | `resolveSearchView` 단독 | 완료 |
| F2-4 1글자 메뉴 자리 안내 | `MenuMinLengthPlate` (인덱스 미구독, 테스트로 호출 0 확인) | 완료 |
| F2-5 범위 안내 | `MenuScopeNotice` — `s4/s5/s7/s9` 에서만, 로딩·에러 제외 | 완료 |
| F2-6 이동 후 | `StoreMenuPage` 기존 로딩/에러 그대로 | 변경 없음 |
| F3-1 최근 검색어 | `recentSearchesProvider` 세션 메모리 (제출·결과 탭 기록, 10건, 중복 끌어올림, 개별/전체 삭제) | 완료 |
| F4-1 거리 | 스냅샷 `distanceKm`, null 이면 카드는 `-`, 메뉴 행은 거리 생략 | 완료 |
| F4-2 위치 미확정 | 스냅샷이 `userLocationProvider` 를 기다림 -> F1 로딩과 동일 | 완료 |

## 5. 읽기 실측 (카운팅 fake, `home_search_providers_test.dart`, 100개 승인 매장 fixture)

| 시나리오 | 이전 구조 (코드상) | 이번 구현 (실측) |
|---|---|---|
| 홈 진입 | `fetchAll(100)` 2회 (nearby + filtered) = 200 docs | `fetchAll` 1회 = **100 docs** |
| 카테고리 토글 (정렬 변경 포함) | 토글당 100 docs | **0** |
| 첫 메뉴 검색 | 해당 없음 | 출처 `get()` **17회** (개인 15 + 브랜드 2) / 55 docs — 후보 30곳 구성에 따라 달라지는 값 |
| 두 번째 이후 검색 | — | **0** |
| 1글자 질의 / 홈 진입만 | — | 메뉴 읽기 **0** |

문서 수는 fixture 크기에 비례한다. 실서버 수치가 아니라 **호출 횟수 구조**를 검증한 값이다 (운영 Firestore 는 읽지 않았다).

## 6. 강제 조건 확인

- 가격: 신규 파일 `price`(대소문자 무시) grep **0건**. `MenuSearchHitEntity` 에 가격 필드·숫자 예약 칸 없음. 결과 행은 메뉴명 / `매장명 · 거리` / 카테고리 태그만.
- 메뉴 상세 직행 없음: 결과 탭 -> `StoreMenuPage(initialMainCategoryCode, highlightMenuItemId)` 만.
- 인덱스: 신규 메뉴 쿼리는 `.orderBy('displayOrder').get()` — `where` / `collectionGroup` **미사용** (기존 stream 과 동일 문장). `firestore.rules` / `firestore.indexes.json` 무수정 -> 배포 순서 이슈 없음.
- `Color(0x…)` 0건, Firebase import 는 data 레이어(`store_repository_impl` 의 `FirebaseException` 변환 포함)에만.
- 기존 결함: `'$e'` 원문 노출 제거(홈 추천 에러 -> `매장 정보를 불러올 수 없어요` + `잠시 후 다시 시도해 주세요`), `전체보기` 터치 영역 44px.

## 7. 테스트 포인트 (tester 전달)

1. 홈 진입 후 네트워크 로그/읽기 수: 매장 `stores` 컬렉션 1회. 카테고리 칩을 여러 번 눌러도 추가 읽기 없음.
2. 검색: 1글자(매장만) / 2글자(메뉴 로딩 -> 도착) / 공백 포함·대소문자 / 주소만 매칭(카드 주소 한 줄) / 0건 / 일부 출처 실패 / 전체 실패.
3. 중간 상태에서 메뉴가 도착해도 매장 섹션 위치·스크롤이 유지되는지, 메뉴 로딩·에러 중 통합 빈 상태가 나오지 않는지.
4. 메뉴 행 탭 -> 해당 카테고리 탭 선택 + 카드 테두리 + `검색한 메뉴  {이름}` 띠. 매장이 팔지 않는 메뉴면 `이 매장에서는 판매하지 않는 메뉴일 수 있어요`. 다른 매장으로 이동했을 때 이전 카테고리 선택이 새지 않는지.
5. 홈 `맞춤 추천`: 5건 + 헤더 전체 건수 + (5 초과 시) `전체보기` / `N곳 더 보기`. 전체보기 화면: 칩 공유(홈 반영), 거리순/등급순, 당겨서 새로고침.
6. 텍스트 1.5x, 접근성 낭독(design §8) — **수동 확인 필요** (자동 테스트 없음).
7. 비로그인 상태 검색 -> `로그인이 필요해요` (수동).

## 8. 검증 결과

- `flutter analyze`: No issues found.
- `flutter test`: 501 통과 (기존 453 + 신규 48).
- Rules 하네스(`test_rules`, `npm test`): 341/341 PASS (Rules 무수정 확인 목적).
- `dart format`: 신규 파일 18개만 지정 실행. 디렉터리 단위 실행 없음. 실험용 엔트리포인트(`lib/tmp_*`) 없음.

## 9. 작업표와 현실의 차이 / 보류

| 항목 | spec/design | 실제 |
|---|---|---|
| `SearchMenuItemsUseCase.filter` | `limit = 30` 파라미터 | 전체 일치 목록을 반환하고 provider 가 30행으로 자름. 헤더 `메뉴 (총 일치 수)` 와 `{총}개 중 30개` 문구에 상한 적용 전 건수가 필요해서 |
| `menuSearchIndexProvider` keepAlive | `ref.keepAlive()` | autoDispose 가 아닌 `FutureProvider`(항상 살아 있음). 스냅샷을 watch 하므로 새로고침으로 스냅샷이 다시 읽히면 캐시도 다음 검색 때 다시 만들어진다 |
| 마스터 repo 접근 | — | 고객 검색이 `brand/providers/brand_di_providers.dart` 의 `masterMenuItemRepositoryProvider` 를 사용 (fetch 는 auth getter 를 쓰지 않음) |
| `initialMainCategoryCode` 적용 시점 | "첫 build 전" | Riverpod 이 빌드 중 provider 수정을 금지해 **첫 프레임 직후(microtask)**. 첫 프레임은 메뉴 stream 로딩 shimmer 구간 |
| design §3-d 페이드 150ms | skeleton -> 결과 페이드 | 미구현 (즉시 교체). 위치·스크롤 불변은 충족 |
| `전체보기` 44px | 터치 영역 확장 | 헤더 행 높이가 약 22px 커져 `맞춤 추천` 헤더 아래 간격이 늘어난다 (5건 초과일 때만) |
| 브랜드 매장의 점포 한정 메뉴(`scope=store`) | — | 인덱스는 브랜드 마스터만 읽는다 (spec §2.2 그대로). 점포 한정 메뉴는 검색되지 않음 |

## 10. 설계 관점 우려 (보고만, 변경 없음)

1. `selectedMainCategoryProvider` 가 전역이라 **검색 경로가 아닌** 기존 진입(홈/주문 탭)에서는 이전 선택이 다른 매장으로 새는 기존 동작이 남아 있다 (`filteredMenuItemsProvider` 가 없는 카테고리를 무시해 빈 화면은 피함). family 화 또는 화면 단위 reset 은 별도 과제.
2. `storesByIdProvider` 가 스냅샷 기반이 되어 20km 밖 자주 찾는 매장도 lookup 된다 (spec 이 인정한 부수 개선) — 홈 `자주 찾는 매장` 노출 대상이 늘 수 있다.
3. 100건 절단(D7)은 손대지 않았다. 스냅샷이 `fetchAll(100)` 상한에 묶이므로 승인 매장 80곳 트리거(`docs/backlog.md`) 도달 시 검색·추천이 함께 영향받는다.

## 11. 검증 FAIL 수정 (test_report.md 후속)

테스트가 provider 를 `overrideWith` 하거나 `AsyncValue` 를 손으로 만들면 Riverpod 3 자동 재시도 · `whenData` 변환 · 전역 UI 상태 누수가 실행되지 않는다. 회귀 테스트는 **I/O 경계만 대체하고 실제 provider 그래프·실제 화면·실제 타이머**로 만들었다 (`test/presentation/home_search_real_graph_test.dart`).

| 항목 | 수정 | 위치 |
|---|---|---|
| FAIL-1 띠 오경보 | 띠의 `foundName` 을 `filtered` 가 아니라 **머지 목록 전체(`allItems`)** 에서 F5 단일 함수로 찾는다. 초기 카테고리 적용 시 `selectedSubCategoryIdProvider.clear()` 도 호출(같은 메인이면 `select` 가 early return 하던 경로). 활성 카테고리 미도달이면 띠를 그리지 않는다 | `store_menu_page.dart` |
| FAIL-2 비활성 카테고리 | **양쪽을 한 함수로 통합**: `isMenuShownOnStoreScreen`(`core/utils/store_menu_visibility.dart`)를 `filteredMenuItemsProvider` 와 검색 결과 필터가 같이 쓴다. 검색 결과에서 매장 화면에 안 보일 메뉴를 빼고, `effectiveMain` 후보도 "보이는 메뉴의 카테고리" 로 한정해 비활성 카테고리가 선택돼도 매장의 다른 메뉴가 사라지지 않는다 | `store_menu_providers.dart`, `search_providers.dart` |
| FAIL-3 자동 재시도 | `storeSnapshotProvider` / `menuSearchIndexProvider` 에 `retry: searchReadRetry`(일시 오류 1회·0.8초, `PermissionDeniedException` 은 즉시 확정). 범위 판단은 backlog B-1 | `home_providers.dart` |
| ① 범위 안내 | 인덱스가 `searchedStoreCount` 를 싣고, 문구는 그 값을 말한다. 0곳이면 별도 문구 | `menu_search_hit_entity.dart`, `search_state_widgets.dart` |
| ② L1 | 안내 둘째 줄에 `매장 한정 메뉴` 한 구절 | `search_state_widgets.dart` |
| ③ F5 | design §1-e 추가. 판정 통합은 위 FAIL-2 | `design.md` |
| ④ 목적지 에러 | `StoreMenuPage._ErrorView` 의 `err.toString()` 노출 제거 -> `잠시 후 다시 시도해 주세요` | `store_menu_page.dart` |
| ⑤ 새로고침 2회 | `refreshHomeStoreSnapshot` — 권한 허용이면 `allowAndFetch` 의 재빌드에 맡기고 invalidate 하지 않는다(거부/폴백 경로만 invalidate). 컨테이너에서 단순 연속 호출은 재빌드가 합쳐져 재현되지 않았고, 두 호출 사이에 한 번 양보(`Future.delayed(zero)`)가 있으면 3회가 나오는 것으로 재현·검증 | `home_providers.dart`, `home_page.dart` |

### 문서 정정
- 커밋 `38f9319` 메시지의 "띠가 L2·L5 를 알리는 유일한 지점" 은 틀렸다. **띠는 L2(머지 목록에 없음)만** 알린다. **L5(품절)는 `MenuItemCard` 의 품절 배지**가 알린다 (design §1-e F5-4).
- §3-7 의 "첫 프레임은 shimmer 구간" 은 메뉴 스트림이 이미 살아 있는 매장에서는 틀렸다. 그 경우 첫 프레임은 전역에 남은 이전 카테고리로 그려질 수 있으나 띠는 목록 필터와 무관해져 오경보는 나오지 않는다 (카드 테두리는 microtask 보정 프레임부터).

### 남은 것
- 첫 프레임 1프레임 동안 이전 카테고리 목록이 보일 수 있다 (근본 원인은 전역 선택 상태, backlog B-2).
- 전역 재시도 정책은 사용자 결정 대기 (backlog B-1).

---

## 12. 2차 개정 구현 (spec §15 / design §13) — §1~§11 은 이력, 충돌 시 이 절이 이긴다

### 12.1 구현 순서와 검증 게이트

라이브 화면을 건드리는 ①②를 먼저 끝내고 검증한 뒤(전체 526 통과) ③~⑧로 갔다. 전환 애니메이션(§13-4)은 단순 버전이 끝난 뒤 별도 단계로 올렸다.

| # | 내용 | 위치 |
|---|---|---|
| ① | `applyOverrideForCustomer` 추출 — `_mergeForBrandStore` 가 이 함수만 쓴다 (**동작 변화 0**, 교체 전 구현의 사본과 전 조합 동치 테스트) | `core/utils/store_menu_visibility.dart`, `menu_item_repository_impl.dart` |
| ② | `watchById` case B = `combineLatest3` + override 문서 단건 스트림 + 같은 함수 (D13). override 스트림 실패는 **에러로 전파**(마스터 값 폴백 없음), `excluded` -> null -> `_DeletedView`. 개인 매장(case A)은 override 를 구독하지 않는다 | `menu_item_repository_impl.dart`, `menu_override_remote_data_source.dart#streamByStoreAndMaster` |
| ③ | override one-shot: `fetchByStore` -> `fetchByStoreOnce` (`_overrideCol(storeId).get()`, **where / collectionGroup 없음**) | data source / repository IF / impl |
| ④ | `MenuSearchHitEntity` + `basePrice`·`soldOut`. `SearchMenuItemsUseCase.planVerification` / `applyVerification` (순수) | domain |
| ⑤ | `storeMenuOverridesProvider` (매장 단위, 검색 화면 수명) + `menuSearchResultsProvider` 결합 (R1~R6) | `search_providers.dart` |
| ⑥ | 메뉴 상세 품절 UI, `_DeletedView` 개정, `SoldOutOverlay` 공용화, `QuantityStepper.enabled` | `menu_item_detail_page.dart`, `common/` |
| ⑦ | `autoOpenMenuItemId` + 1회 자동 push | `store_menu_page.dart` |
| ⑧ | 검색 행 가격·품절 (`PriceFormatter.formatKrw` 한 곳), D9 매장 카드 품절 탭 허용 | `menu_search_result_tile.dart`, `menu_item_card.dart` |
| 마지막 | 전환 애니메이션 (§13-4) | `SeamlessStoreMenuRoute`, `StoreMenuPage.seamlessEntry` |

### 12.2 핵심 결정

- **override 규칙은 `applyOverrideForCustomer` 하나** (핵심 필드 `excluded`/`priceOverride` = `status==approved` 일 때만, 운영 필드 `soldOut`/`disabledOption*` = status 무관 즉시). 매장 화면 목록 · 메뉴 상세 · 검색 2단계가 모두 이것만 호출한다. 검색 2단계는 1단계 행에서 최소 `MenuItemEntity` 를 재구성해 같은 함수에 넣고 결과의 가격·품절만 취한다 (규칙 복제 없음).
- **D10 (점포 한정 메뉴 포함)**: 1단계가 브랜드 매장의 `stores/{id}/menuItems` 도 읽는다 (승인된 것만 — `_mergeForBrandStore` 의 점포 한정 기준과 같다). 1단계 쿼리 17 -> 32 (backlog "검색 1단계 비용" 20곳 트리거와 연결).
- **R1**: 2단계(`storeMenuOverridesProvider` 전부)가 도달하기 전에는 `AsyncLoading` — 1단계 행을 그리지 않는다. **자동 재시도 중(`isLoading`)에는 실패로 확정하지 않는다** (에러/부분 실패가 잠깐 비쳤다 사라지는 깜빡임 방지). 재시도 정책은 1차의 `searchReadRetry` 재사용 (override 1회·0.8초).
- **R4**: 일치한 distinct 브랜드 매장을 거리순으로 최대 `menuSearchVerifyStoreLimit`(10) 곳. 상한 밖 브랜드 행은 버리고 `fanOutTruncated` -> `검색 범위를 좁혀 보세요`. 개인·점포 한정 행은 override 가 없으므로 상한과 무관하게 통과.
- **R5/R6**: `total` = 검증 통과 수. 검증 실패 매장의 행은 **그리지 않고** `failedSourceCount` 에 합산(`s7`/`s9`/`s12`). 일치 행이 전부 브랜드 매장이고 검증이 전멸이면 `AsyncError` -> `s6`/`s11`.
- **D12**: override 캐시 = 검색 화면 수명. `SearchPage.dispose` 가 `invalidate(storeMenuOverridesProvider)` (family 전체) — 화면을 다시 열면 2단계만 다시 읽고, 1단계 인덱스(`menuSearchIndexProvider`, 세션 캐시)는 그대로. 부분 실패 `다시 시도` 와 당겨서 새로고침은 둘 다 invalidate.
- **자동 push (U2)**: `StoreMenuPage` 가 메뉴 목록·활성 카테고리가 확정되면 `isMenuShownOnStoreScreen`(F5 단일 판정)으로 `autoOpenMenuItemId` 를 찾아 다음 프레임에 상세를 1회 push (`_autoOpened`). 목록에 없으면 올리지 않고 `_SearchedMenuBand`. 판정은 `ref.listen` 대신 data 빌더 안에서 1회 수행해, 이미 로드된 스트림도 같은 경로로 처리한다.
- **`_DeletedView` 의 `매장 메뉴 보기`**: 바로 아래 스택이 그 매장의 `StoreMenuPage` 인지 `openStoreMenuStoreIds`(열린 매장 화면 id 목록)로 판단 — 맞으면 pop, 아니면 매장 화면으로 교체. 매장 정보를 못 얻으면 주 액션을 숨기고 `뒤로가기`만.
- **품절 판정 순서**: 상세 `_BottomAction` 은 `soldOut` -> `_busy` -> required 미선택. 품절은 버튼이 `onPressed: null` + 라벨 `품절`, `_onAddPressed` 도 품절이면 토스트 없이 즉시 return. 즐겨찾기는 그대로.
- **장바구니·결제의 품절 검증(spec F8)은 범위 밖**이라 손대지 않았다 (backlog F8 등재).

### 12.3 전환 애니메이션 (design §13-4) — §13-4 해법을 올렸다. 플랫폼 문제 1건과 대응

- **올린 것**: 메뉴 행 탭 전용 `SeamlessStoreMenuRoute`(앞으로 0ms · 뒤로 300ms · `opaque:false`) + `StoreMenuPage.seamlessEntry`(상세가 덮을 때까지 `AnimatedOpacity` 0 으로 아무것도 그리지 않음, 데이터 판정은 계속 수행) + 250ms 뒤 스크림 + 3초 폴백 reveal + 상세를 올리지 않는 분기는 200ms 페이드 인. `secondaryAnimation` 이 completed 또는 reverse 가 되면 reveal. 매장 결과 탭 등 다른 진입은 기존 `MaterialPageRoute` 그대로.
- **플랫폼 문제**: design 이 가정한 `MaterialPageRoute` 상속(`opaque` 재정의)은 **생성자가 `assert(opaque)` 라 불가능**했다. 대신 `PageRoute` + `MaterialRouteTransitionMixin` 으로 직접 정의해 플랫폼 기본 전환(iOS 스와이프 백 포함)을 유지했다. 위젯 테스트는 Android·iOS 전환 둘 다에서 통과 (실기기 확인은 못 했다).
- 보이는 슬라이드는 상세 1회, 상세가 덮기 전 프레임마다 매장 화면 opacity 0 + 검색 화면 유지, 뒤로 나오면 완성된 매장 화면(강조 카드 유지)을 테스트로 고정했다.
- **알려진 한계**: 숨겨진 매장 화면도 위젯은 빌드되어 shimmer 애니메이션이 투명하게 돈다(비용 미미). iOS 에서 상세 위의 스와이프 백 도중 reveal 타이밍은 실기기 확인 필요.

### 12.4 표면 인벤토리 F5-5 ~ F5-12 와 구현의 일치

| 행 | 구현 | 확인 |
|---|---|---|
| F5-5 행 가격 | 검증된 `basePrice` (`PriceFormatter.formatKrw`, 접미사 없음). 가격만 비운 행은 존재하지 않음 | 테스트 |
| F5-6 행 품절 | 같은 검증 결과 `soldOut`: 배지 + 썸네일 덮개 + textMuted | 테스트 |
| F5-7 상세 가격 | `watchById` case B 3-스트림. override 실패 -> `_ErrorView`, 마스터 폴백 없음 | 테스트(실제 리포지토리) |
| F5-8 상세 품절 | 이미지 오버레이 · 안내 plate · 옵션 흐림/무시 · 수량 비활성 · `품절` 비활성 버튼 | 테스트 |
| F5-9 담기 합계 | `menuItemCurrentPriceProvider` <- 상세 `basePrice` (위와 같은 값) | 교차 테스트 |
| F5-10 `_DeletedView` | `watchById == null` 일 때만. 스트림 에러는 `_ErrorView` | 테스트 |
| F5-11 자동 열림 판정 | 매장 화면의 `isMenuShownOnStoreScreen`. 로딩: 투명 + 250ms 스크림 / 3초 폴백 | 테스트 |
| F5-12 카테고리 태그 | 해석 실패면 그리지 않음 (1차 그대로) | 1차 테스트 |
| 교차 일치 | 검색 행 == 매장 카드 == 상세 == 담기 합계 기본가 (품절 판정 포함) | `home_search_stage2_test.dart` |

### 12.5 쿼리 실측 (카운팅 fake, 후보 30곳 = 개인 15 + 브랜드 매장 15 / 브랜드 2개)

| 시나리오 | 1차 (실측) | 2차 (실측) |
|---|---|---|
| 첫 메뉴 검색 1단계 | 17 쿼리 / 55 docs | **32 쿼리** / 100 docs (브랜드 마스터 2 + 매장 자체 30 — D10 로 브랜드 매장 점포 한정 15 추가) |
| 2단계 (일치 브랜드 매장 15곳) | — | **10 쿼리** (fan-out 상한) + `fanOutTruncated` |
| 합계 | 17 | **42** (spec 의 "최악 27" 은 D10 이전 계산 — 1단계가 17 -> 32 가 된 만큼 올라갔다) |
| 개인 매장만 일치 | 17 | 32 + **2단계 0** |
| 같은 세션, 같은 매장 재일치 | 0 | **0** |
| 검색 화면 재진입 | 0 | 1단계 **0** / 2단계 **다시 10** (D12 의도) |

- **인덱스 0건**: 신규 one-shot 은 `.orderBy('displayOrder').get()` / `.get()` 뿐(`where`·`collectionGroup` 없음), 상세는 문서 단건 `snapshots()`. `firestore.rules` / `firestore.indexes.json` 무수정.
- 42 는 spec §5.3 전환선(60) 아래이지만 **여유가 줄었다**: 가맹점이 늘면 backlog "검색 1단계 비용"(가맹점 20곳)이 먼저 닿는다.

### 12.6 검증 결과

- `flutter analyze`: No issues found. `flutter test`: 544 통과. Rules 하네스: 341/341 PASS.
- **최우선 회귀 2건 통과**: ① `test/data/menu_override_apply_test.dart` — 교체 전 구현의 사본과 status x excluded x price x soldOut x disabled 전 조합 동치(+ `status != approved` 에서 `excluded`/`priceOverride` 무시, `soldOut`/`disabledOption*` 적용). ② 같은 파일 — 실제 `MenuItemRepositoryImpl` 로 카드 가격 == 상세 가격 (개정 전 상세는 마스터 가격).
- 2차 회귀 테스트는 모두 **Firestore 데이터 소스만 대체한 실제 그래프**: `test/presentation/home_search_stage2_test.dart` (R1 단일 전이, R4, R6, 자동 열림, 품절 상세, D9, `_DeletedView`, 전환 프레임 단위 검증, Android·iOS). 의도적 고장(R1 해제 / 전환 해제)으로 테스트가 잡는 것을 확인했다.
- 1차 테스트는 1단계가 브랜드 매장의 `menuItems` 도 읽는 변경(D10)과 `basePrice` 필수화를 반영해 수정했다.

### 12.7 남은 것 / 우려 (보고만)

1. 숨겨진 매장 화면의 shimmer 틱 / iOS 실기기 스와이프 백 타이밍 — 수동 확인 필요.
2. 상세에서 `담기` 를 막아도 장바구니·결제의 품절 검증은 없다 (backlog F8, 출시 전 점검 권장).
3. 부분 실패 `다시 시도` 는 1단계 인덱스(32쿼리)까지 다시 읽는다 — 2단계 실패만 다시 읽는 세분화는 하지 않았다.
4. design §13-5 의 150ms 페이드(shimmer -> 행)는 구현하지 않았다 (한 번에 교체; 행이 떴다 사라지는 일은 없다).
