# 홈 검색 + 추천 매장 전체보기 구현 기록

| 일자 | 작성자 | 내용 |
|---|---|---|
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
