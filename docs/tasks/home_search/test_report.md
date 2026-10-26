# 홈 검색 + 추천 매장 전체보기 테스트 리포트

## 테스트 일시

- 2026-10-26 (구현 커밋 `38f9319`, working tree clean 상태에서 검증)

---

## 테스트 방법

- 정적 코드 검증 (커밋 diff 40개 파일 전수, spec §2.2 / §5.3 / §8.2 / L1~L5, design §1 / §3-c / §3-d / §5-b 교차)
- 의뢰자가 직접 재실행한 항목은 **재실행하지 않았다**: `flutter analyze` 0 / `flutter test` 501 / Rules 하네스 341 / `price` grep 0건 / 신규 인덱스 0건 / Rules·indexes 무수정
- **테스트가 못 보는 것**을 찾기 위해 저장소 밖(스크래치패드)에 별도 probe 패키지를 만들어 실제 provider 그래프와 실제 위젯으로 재현했다.
  - 기존 테스트는 `overrideWith` 로 provider 를 갈아끼우거나 `AsyncValue` 를 손으로 만들어 `resolveSearchView` 에 넣는다. 그래서 Riverpod 3 의 자동 재시도, `whenData` 변환, 전역 UI 상태 누수는 한 번도 실행되지 않는다.
  - probe 는 저장소 코드를 수정하지 않고 `package_config` 만 가리켰다. 검증 후 삭제했다. 저장소에는 이 파일 외 변경이 없다.
- 운영 Firestore 는 읽거나 쓰지 않았다. 배포하지 않았다.

---

## 전체 결과

- PASS: 21개
- FAIL: 3개
- 보류: 8개

가장 먼저 고칠 것: **FAIL-1 (`판매하지 않는 메뉴일 수 있어요` 띠의 오경보)**. 이 띠는 spec 한계 L2 를 사용자에게 알리는 유일한 지점인데, 판정 기준이 잘못돼 **팔고 있는 메뉴에 "판매하지 않는다" 고 말한다.**

---

## FAIL 항목

### FAIL-1 [High] `판매하지 않는 메뉴일 수 있어요` 띠가 팔고 있는 메뉴에 오경보를 낸다

- **문제**: `_SearchedMenuBand.foundName` 을 **카테고리·서브카테고리 필터가 적용된 `filtered`** 에서 찾는다. 매장이 그 메뉴를 파는지(= 머지 목록 `allItems`)와 무관하게, **지금 화면에 보이는 목록에 없으면** `판매하지 않는 메뉴일 수 있어요` 로 바뀐다.
- **위치**: `lib/presentation/customer/order/store/store_menu_page.dart` 의 `highlightMenuItemId != null` 블록 (`filtered.where((m) => m.id == widget.highlightMenuItemId)`)
- **재현** (probe 위젯 테스트, 실제 `StoreMenuPage` + 실제 `filteredMenuItemsProvider`):
  1. 커피 `아메리카노`(m1) 와 티 `녹차` 가 있는 매장에 `initialMainCategoryCode: coffee, highlight: m1` 로 진입 -> 띠 `검색한 메뉴  아메리카노` (정상)
  2. 사용자가 `티` 탭을 누른다 -> **띠가 `이 매장에서는 판매하지 않는 메뉴일 수 있어요` 로 바뀐다.** 메뉴는 팔고 있다. (W2)
  3. 이전 매장에서 고른 서브카테고리(`selectedSubCategoryIdProvider`)가 남아 있으면 **같은 메인 카테고리로 진입해도** 하이라이트 메뉴가 서브 필터에 걸려 사라지고 같은 오경보가 뜬다. `SelectedMainCategoryNotifier.select` 가 `state == id` 면 early return 해서 서브 선택을 지우지 않기 때문이다. (W7)
  4. 메뉴 스트림이 이미 살아 있는 매장(주문 이력이 있는 매장은 `_menuItemsByStoreProvider` 가 스트림을 유지한다)에 진입하면 **첫 프레임**에 전역에 남은 이전 카테고리로 목록이 그려지고 띠도 `판매하지 않는` 이다. microtask 로 카테고리가 적용되는 다음 프레임에 정정된다. (W3)
- **왜 중요한가**: 이 띠는 L2(excluded) 신호의 유일한 지점이다. 거짓 양성이 나오면 사용자는 띠를 믿을 수 없게 되고, 진짜 L2 에서도 무시한다. 이번 사이클 내내 나온 "화면이 틀린 것을 아는 척한다" 패턴이다.
- **테스트가 못 본 이유**: 기존 테스트는 카테고리를 바꾸는 상호작용이 없고, 서브카테고리 누수 상태를 만들지 않으며, 메뉴 스트림 캐시 상태에서 첫 프레임을 보지 않는다.
- **제안 수정 방향**:
  - `foundName` 은 `allItems`(머지 목록, `visible` 만 거른 것) 기준으로 찾는다. 있으면 `검색한 메뉴`, 없을 때만 `판매하지 않는`.
  - 있는데 현재 탭에 안 보이면 오경보 대신 중립 문구(예: `검색한 메뉴는 {카테고리} 탭에 있어요`) 또는 띠 숨김.
  - `initialMainCategoryCode` 적용 시 `selectedSubCategoryIdProvider.clear()` 도 호출한다.
  - 첫 프레임 정정은 위젯 파라미터를 "microtask 적용 전까지의 유효 선택" 으로 먼저 쓰는 방식으로 막는다.
- **테스트 추가 권고**: (a) 탭 전환 후 띠, (b) 서브카테고리 누수 상태 진입, (c) 메뉴 캐시 상태 첫 프레임.

### FAIL-2 [Medium] 비활성(inactive) 메인 카테고리 메뉴가 검색에 걸리고, 탭하면 매장 메뉴 화면이 통째로 비어 보인다

- **문제**: 인덱스(`buildIndex`)는 `visible` / `approved` 만 거르고 **활성 메인 카테고리 여부를 보지 않는다.** 그런데 매장 메뉴 화면은 `filteredMenuItemsProvider` 에서 비활성 카테고리 메뉴를 제외한다. 결과 행은 뜨는데 매장 화면에는 없는 메뉴가 생긴다.
- 더 나쁜 점: `StoreMenuPage` 는 `initialMainCategoryCode` 를 그대로 선택하고, 폴백 판정(`effectiveMain`)은 **비활성 카테고리를 포함한 `storeMains`** 로 한다. 그래서 비활성 카테고리가 선택되면 `effectiveMain` 이 그 카테고리로 고정되어 **그 매장의 다른 모든 메뉴까지 필터링되어 사라진다.**
- **위치**: `lib/domain/usecases/search_menu_items_use_case.dart` (`buildIndex` 필터), `lib/presentation/customer/order/store/store_menu_page.dart` (`initState` 의 `initialMainCategoryCode` 적용), `store_menu_providers.dart` (`filteredMenuItemsProvider.effectiveMain`)
- **재현** (probe W1): 활성 카테고리 `coffee`, `tea` / 메뉴 `아메리카노`(coffee), `라떼`(coffee), `티라미수`(dessert, 비활성) 인 매장에 `initialMainCategoryCode: dessert, highlight: 티라미수` 로 진입 -> **세 메뉴 모두 보이지 않는다** (`아메리카노`·`라떼` 포함). 띠만 `판매하지 않는 메뉴일 수 있어요`.
- **제안 수정 방향**: 인덱스/결과를 활성 카테고리로 거르거나(`MenuSearchResultTile` 은 이미 활성 카테고리 목록을 구독한다), 최소한 `initialMainCategoryCode` 를 `storeAvailableMainCategoriesProvider` 에 있을 때만 적용한다.
- **참고**: `effectiveMain` 의 비활성 카테고리 처리는 기존 코드의 결함이며, 이번 기능이 그 경로를 처음으로 "의도적으로" 연다.

### FAIL-3 [Medium] Riverpod 3 자동 재시도 때문에 읽기 실패의 ⓑ(실패 시 보이는 것)가 약 38초 늦게 나타난다

- **문제**: `storeSnapshotProvider` / `menuSearchIndexProvider` 는 `retry` 설정이 없어 Riverpod 3 기본값(예외 10회, 200ms 시작 2배 증가, 상한 6.4s)이 적용된다. 실패하면 **약 38초 동안 `AsyncLoading`** 이고, 그동안 파생 provider(`whenData`)는 에러를 가린다.
- **재현** (probe P4, `StoreRepositoryImpl` + `FirebaseException(permission-denied)`):
  - 1.6초 시점: `fetchAll` 시도 4회, 스냅샷 `isLoading=true / hasError=true`, 검색 화면 판정은 `s1StoreLoading`(skeleton + `메뉴를 찾고 있어요`).
  - 41초 시점: 시도 11회(최초 1 + 재시도 10), 그제야 `s2StoreError`.
- **영향**:
  - design §1 의 F1-1·F1-2·F1-3·F2-1 ⓑ 가 실제 앱에서는 **38초 뒤에야** 성립한다. 그 사이 사용자에게는 정상 로딩으로 보인다.
  - 비로그인 `permission-denied` -> `로그인이 필요해요` 도 38초 뒤에 나온다. 그 사이 거부될 요청이 10번 더 나간다.
  - 메뉴 인덱스 전체 실패는 출처 N개를 **10번** 더 시도한다 (실패 요청은 doc 과금이 없지만 요청·지연은 곱해진다).
  - 홈 `맞춤 추천` 에러도 같은 시간 지연된다. 기존 구조(`FutureProvider` + `.when`)도 같은 기본값이라 이번 기능이 만든 결함은 아니다. 그러나 이번 기능이 F1/F2 ⓑ 표를 근거로 "읽기 실패 시 보이는 것" 을 보증했다.
- **테스트가 못 본 이유**: 위젯·provider 테스트가 모두 `overrideWith` 로 실패를 즉시 `AsyncError` 로 주입한다.
- **제안 수정 방향**: 두 provider 에 `retry: (_, _) => null` (또는 짧은 횟수 상한) 지정. 재시도는 이미 `다시 시도` 버튼이 맡는다.

---

## 1순위 4항목 판정

### 1. 가격 누출 — PASS (독립 전수 확인)

- `price`, `원`, `금액`, `won`, `₩`, `krw`, `cost`, `할인`, `discount`, `basePrice`, `PriceFormatter`, `amount`, `qoin`, `포인트` 를 검색 관련 전 파일(entity, usecase 2, providers 2, search 디렉터리 전체, `store_list_states`, 추천 화면·섹션)에서 grep -> **코드 중 해당 표현 0건**. 나온 것은 주석(`가격·할인·품절·별점 없음`, `질의 원문`)뿐이다.
- `MenuSearchHitEntity` 필드: `menuItemId / menuName / menuImageUrl / mainCategoryCode / storeId / storeName / distanceKm / source`. 숫자 필드는 `distanceKm` 하나(거리). `_hit()` 는 `item.basePrice` 를 읽지 않는다.
- `MenuSearchResultTile` 이 읽는 필드는 `menuName / storeName / distanceKm / mainCategoryCode / menuImageUrl` 뿐. 접근성 라벨(`메뉴명, 매장명, 거리, 카테고리. 탭하면 매장 메뉴 화면으로 이동`)·Tooltip(`닫기` 하나)에도 숫자 표현이 없다.
- 오히려 범위 안내가 `가격과 판매 여부는 매장 화면에서 확인해 주세요` 로 **가격을 안 보여주는 이유를 말한다.**
- 이동 후 `StoreMenuPage`/`MenuItemCard` 는 정식 머지(`priceOverride` 반영) 가격을 보여준다. 정상.

### 2. 메뉴 상세 직행 — PASS

- `search/` 와 `home/` 아래에 `MenuItemDetailPage`·`menuItemDetailProvider` 참조 0건. 결과 탭은 `_openStore(store, hit:)` -> `StoreMenuPage` 한 경로뿐.
- 딥링크 인프라가 없다 (`app_links`·`uni_links`·`onGenerateRoute`·`pushNamed`·`go_router` 0건).
- 뒤로가기 후 상태: 검색 화면은 `searchQueryProvider`(autoDispose) 상태를 유지하고, `StoreMenuPage.dispose` 가 전역 카테고리를 `null` 로 되돌린다 (이 화면이 바꾼 경우만).
- 하이라이트 카드 탭 -> `MenuItemDetailPage` 는 **머지 목록의 항목**을 여는 정상 경로다. 검색 인덱스 항목이 직접 열리는 길은 없다.
- 부수 확인: 결과 행 탭에서 `storesById[hit.storeId]` 가 null 이면 **아무 일도 일어나지 않는다**(조용한 no-op). 인덱스와 `storesById` 가 같은 스냅샷에서 나오므로 현재는 도달하기 어렵다. 보류-7 참조.

### 3. 하이라이트 띠 — **부분 FAIL** (FAIL-1)

| 한계 | 재현 | 결과 |
|---|---|---|
| L2 excluded (머지 목록에 없음) | probe W5 | `이 매장에서는 판매하지 않는 메뉴일 수 있어요` 정상 노출 |
| L5 품절 | probe W4 | 띠는 `검색한 메뉴  {이름}` (정상 — 목록에 있으므로). **품절 표시는 `MenuItemCard` 의 품절 배지가 맡는다.** 커밋 메시지·`implementation.md` 의 "띠가 L2·L5 를 알리는 유일한 지점" 은 L5 에 한해 부정확하다 (띠가 아니라 카드 배지가 L5 를 알린다). 사용자에게 문제는 없고 문서 정정만 필요 |
| 정상 판매 메뉴 | probe W2, W7, W3 | **오경보 3경로** (FAIL-1) |

즉 "L2 에서 뜨는가" 는 PASS, "L2 가 아닐 때 안 뜨는가" 는 FAIL.

### 4. 통합 빈 상태 / 12상태 — PASS (13번째 상태는 없다. 단, 13번째에 준하는 거짓 문구 1건은 보류-1)

독립 열거. 질의 2글자 이상에서 S(매장) x M(메뉴) 입력 공간:

- S ∈ {로딩, 에러, 데이터0, 데이터>0}
- M ∈ {로딩, 에러, 데이터0, 데이터>0, 부분실패(결과>0), 부분실패(결과0)}
- S 가 로딩/에러면 M 은 무관하다 (구현: 둘 다 S 만 본다 — design 도 동일). 메뉴 인덱스가 스냅샷을 기다리므로 S 로딩이면 M 도 로딩이라 구분이 무의미하다.
- 나머지 2 x 5 = 10 + S 로딩 1 + S 에러 1 = **12**. 모든 조합이 `resolveSearchView` 의 분기에 정확히 하나씩 대응한다.
  - S>0 x 부분실패(결과>0) -> `s7`, S>0 x 부분실패(결과0) -> `s7` (`q` 가 있어 한 줄 `메뉴가 없어요` + 부분 실패 줄)
  - S0 x 부분실패(결과>0) -> `s9` (`_menuSection` 이 부분 실패 줄을 포함), S0 x 부분실패(결과0) -> `s12`
- **통합 빈 상태(`s10`/`s12`)는 `menuAsync` 가 `hasValue` 일 때만 도달**한다 (`menuLoading`/`menuError` 분기가 앞서 return). 로딩·에러에서 `(0)` 이나 "결과 없음" 이 나오는 경로는 없다. probe P4 에서 재시도 중에도 `s1`(로딩)이지 통합 빈 상태가 아니었다 (FAIL-3 의 지연은 있으나 거짓은 아니다).
- 입력 공간 밖의 이음새 2건을 추가로 확인했다.
  - 1글자 -> 2글자 전환: `menuSearchResultsProvider` 가 1글자에서 `AsyncData(empty)` 를 돌려주고 인덱스를 구독하지 않는다. 2글자가 되는 순간 구독하므로 "구독 전 empty 가 통합 빈 상태로 새는" 경로는 없다 (판정이 길이 분기를 먼저 한다).
  - 스냅샷이 값을 가진 채 재로딩: `hasValue` 우선이라 값 유지 (P8: 검색 화면 pull-to-refresh 중 판정 열이 `s4 -> s4` 로 skeleton 깜빡임 없음).
- 단, **상태는 맞는데 그 상태가 하는 말이 틀린 경우**가 하나 있다: 반경 10km 이내 후보 매장이 0곳 또는 30곳 미만이어도 `가까운 매장 30곳의 메뉴에서 찾았어요` 라고 말한다 (보류-1).

---

## 설계 우려 5건 판정

| # | 우려 | 판정 | 근거 |
|---|---|---|---|
| 1 | 전역 `selectedMainCategoryProvider` 가 기존 진입에서 매장 간 누수 | **기존 결함 확인, 심각도 Low-Medium, 이번 기능의 FAIL 아님** | probe W6: 매장 A 에서 `tea` 선택 후 매장 B 진입 시 `tea` 가 선택된 채 열린다 (`녹차`만 보임). B 에 `tea` 가 없으면 `filteredMenuItemsProvider` 가 무시해 전체를 보여주되 **탭은 아무것도 선택되지 않은 모양**이다. 빈 화면은 아니다. 검색 경로는 `dispose` 에서 `null` 로 되돌려 새지 않는다. 단 **되돌리기가 이전 누수 값을 덮어쓴다**(무해). 이 누수가 FAIL-1 의 (3)(4) 경로를 만든다 -> 원인 제거(family 화 또는 화면 진입 시 reset)를 후속 task 로 권고 |
| 2 | `전체보기` 44px 로 헤더 행 ~22px 증가 | **보류(Low, 시각)** | `SectionTitle` 의 `Row` 가 trailing 44px 에 맞춰 커져 제목이 11px 내려오고 제목-카드 간격이 12 -> 약 23px 가 된다. 다른 섹션(제목-카드 12)과 불일치. 또 카테고리 칩 토글로 건수가 5 경계를 넘나들면 헤더 높이가 22px 점프해 카드 목록이 위아래로 움직인다. design §2-b 가 44 터치 영역을 요구했으므로 spec 위반은 아니다. 제안: 시각 높이는 유지하고 히트 영역만 확장(`InkWell` + 음수 마진/`OverflowBox`) |
| 3 | `storesByIdProvider` 가 스냅샷 기반이 되어 20km 밖 매장도 lookup | **의도된 개선, 회귀 아님 (PASS)** | probe P7: 이전 `storesById` = `nearbyStoresProvider`(반경 20km, 최대 10건), 이후 = 100건(20km 밖 10곳 포함). `frequent_stores_section` 은 `e.store != null` 인 항목만 그리므로 **이전에는 가까운 10곳 밖의 자주 가는 매장이 조용히 사라졌고**, 이제 나온다. `자주 찾는 매장`의 *후보*는 주문 이력에서 오므로 "추천 대상 확대" 가 아니라 "누락 해소" 다. `frequent_menu_items_section._openStore` 의 `store == null -> return`(눌러도 반응 없음)도 같이 해소된다. 다만 변경 효과가 `implementation.md` 에만 있고 테스트가 없다 -> 회귀 테스트 1건 권고 |
| 4 | 브랜드 매장 점포 한정 메뉴(`scope=store`) 미검색 — 화면이 알리는가 | **알리지 않는다 -> 보류-2** | 범위 안내는 `가까운 매장 30곳의 메뉴에서 찾았어요` / `가격과 판매 여부는 매장 화면에서 확인해 주세요` 뿐. L1(점포 한정 메뉴 제외)은 어디에도 없다. 사용자가 점포 한정 메뉴를 검색하면 매장명은 걸려도 메뉴는 `일치하는 메뉴가 없어요` 이고 그 아래 `찾았어요` 가 붙는다. spec §2.3 가 L1 을 "해소는 §7 F2" 로 두었고 §3.2 의 고정 문구에도 없으므로 spec 위반은 아니다. 문구 한 줄로 줄일 수 있는 거짓이라 후속 우선순위 높음 |
| 5 | 매장 100건 절단(D7) 미접촉 | **PASS** | `fetchAll(limit: 100)` 및 `getApprovedStores(limit = 100)` 기본값 유지. `docs/backlog.md` 트리거 변경 없음. 스냅샷이 같은 상한에 묶인다는 점이 `implementation.md` §10 에 기록됨 |

---

## 읽기 실측 재현 (4순위)

probe 는 `StoreRepositoryImpl` 을 실제로 쓰고 `StoreRemoteDataSource.fetchAll` 에 카운터를 건 fake 를 끼웠다. 홈 화면이 watch 하는 provider 전부(`nearby / filtered / preview / full / count / storesById`)를 `listen` 한 상태에서 측정했다. 100개 승인 매장 fixture.

| 시나리오 | 이전(코드상) | 개발자 보고 | 내 재현 |
|---|---|---|---|
| 홈 진입 | 200 docs | 100 | `fetchAll` **1회 / 100 docs** (P1a) |
| **카테고리 칩 토글 x3 + 정렬 변경** | 토글당 100 | 0 | **추가 0** (P1b: fetchAll 1 유지) |
| 첫 메뉴 검색 | — | 17쿼리 / 55 docs | 출처 **17회**(개인 15 + 브랜드 2) 재현 (P2a). **55 docs 는 fake 가 매장당 3개·브랜드당 5개를 돌려주도록 만든 값**이라 실서버 수치가 아니다 |
| 두 번째 검색 | — | 0 | 0 (P2) |

**"토글 0" 은 정말 0이다.** 숨은 재요청 경로를 provider 그래프와 호출처 grep 으로 확인했다.

- 토글은 `selectedCategoriesProvider` 만 바꾸고(`category_filter_section.dart` 의 ref 호출은 watch/read 한 쌍뿐), `filteredStoresProvider` 는 스냅샷을 **구독만** 한다.
- `invalidate(storeSnapshotProvider)` 호출처는 홈 pull-to-refresh, 추천 전체보기 pull-to-refresh, 각 `다시 시도`, 검색 화면 refresh 뿐이다. 토글 경로에는 없다.
- 홈 진입 후 스냅샷은 non-autoDispose 라 탭 전환·화면 재진입에도 재요청하지 않는다.

그러나 같은 측정에서 개발자가 보고하지 않은 사실 두 가지가 나왔다.

1. **홈 당겨서 새로고침 1회 = `fetchAll` 2회 (200 docs)** (P1c: 1 -> 3). `_onRefresh` 가 `allowAndFetch()`(위치 provider 상태 변경 -> 스냅샷 자동 재빌드) 후 `invalidate(storeSnapshotProvider)` 를 또 호출해 이중으로 읽는다. 이전 구조는 nearby/filtered 가 각각 같은 일을 겪어 코드상 그 이상이었으므로 **개선이지 회귀는 아니다.** 다만 "새로고침 1회 = 100 docs" 라는 인상을 주는 문서 서술은 부정확하다. 보류-3.
2. **홈 새로고침 후 첫 메뉴 검색에서 17쿼리가 다시 나간다** (P2c: 17 -> 34). 인덱스는 스냅샷을 watch 하므로 스냅샷이 다시 읽히면 인덱스도 버려지고 다음 검색 때 재생성된다. 검색 화면을 닫은 상태에서는 **즉시 재빌드하지 않고**(P2b: 17 유지) 다음 구독 때 만든다. spec L4(`pull-to-refresh / 화면 재진입 시 invalidate`)와 일치하는 동작이다. **PASS** — 다만 개발자 질문 "다시 만들어지는 게 맞는 동작인가" 의 답은 "맞다. 후보 매장 거리·집합이 바뀌었을 수 있기 때문이다".

---

## 3순위 — 작업표와 다른 곳 5건

| 항목 | 판정 | 근거 |
|---|---|---|
| `filter` 가 limit 없이 전체 반환, provider 가 30행으로 자름 — 총 일치 수/표시 수 표시 | **PASS** | `total = all.length`, `rows = take(30)`. 헤더 `메뉴 (total)` 와 `메뉴 {total}개 중 30개만 보여드려요` 가 같은 `total` 한 곳. 정렬이 거리순이라 잘리는 쪽은 먼 매장이다. 주의: `total` 단위는 **행(메뉴 x 매장)** 인데 문구는 `메뉴 N개` — 같은 메뉴를 10개 매장이 팔면 `메뉴 (10)` (보류-6) |
| `initialMainCategoryCode` 가 첫 프레임 직후 적용 — 잘못된 카테고리 깜빡임 | **조건부 FAIL (FAIL-1 의 (4))** | 메뉴 스트림이 로딩이면 shimmer 라 안전. **스트림이 이미 살아 있고 전역에 이전 선택이 남은 경우** 1프레임 동안 이전 카테고리 목록 + `판매하지 않는` 띠가 그려진다 (W3). `implementation.md` 의 "첫 프레임은 shimmer 구간" 서술은 이 경우 틀리다 |
| 인덱스 non-autoDispose, 스냅샷 재읽기 시 재생성 | **PASS** | 위 읽기 실측 2번 |
| 비로그인 `permission-denied` 처리 | **보류 (수동) + FAIL-3** | 변환 자체(`FirebaseException -> PermissionDeniedException`)는 `getApprovedStores` 에만 있고, 검색 화면이 그 타입을 분기해 `로그인이 필요해요` 를 그린다 (코드 확인). 홈은 로그아웃 감지 시 로그인 화면으로 이동하므로 이 경로가 실제로 열리는 조건은 토큰 만료·세션 레이스 정도다. 열린다 해도 FAIL-3 때문에 38초 뒤에야 보인다. 또 한 번 에러가 캐시되면 재로그인 후에도 `storeSnapshotProvider` 가 에러 상태로 남는다 (non-autoDispose, 사용자 변경 비구독) |
| 150ms 페이드 미구현 — 매장 섹션 위치·스크롤 | **PASS** | 위젯 테스트(`tester.getTopLeft(find.text('매장 (1)'))` 불변)가 메뉴 도착 전후를 비교. 메뉴는 매장 섹션 아래에만 붙는다. 검색 화면 pull-to-refresh 중에도 값이 유지되어 skeleton 로 갈아끼우지 않는다 (P8). 페이드 부재는 design 대비 **미구현 1건**으로 기록하되 기능 영향 없음 |

---

## 5순위 — 표면 인벤토리 15행 (ⓑ 실동작)

| 행 | ⓑ 구현 확인 | 판정 |
|---|---|---|
| F1-1 검색 매장 | `s2StoreError`/`shortError` -> `_storeErrorBlock` 이 검색 영역 전체 교체, 입력창 유지, 메뉴 섹션 미렌더, `다시 시도` -> `invalidate(storeSnapshotProvider)` | PASS (단 **실패 후 38초 뒤** — FAIL-3) |
| F1-2 홈 미리보기 | `stores.when(error: StoreListError)`, 고정 문구(`$e` 제거 확인), `total == null` 이면 헤더 건수 없음 | PASS (FAIL-3 동일) |
| F1-3 전체보기 | `hasValue` 우선 -> `hasError` -> skeleton. 칩·정렬 유지, 건수 줄은 shimmer 바 | PASS |
| F1-4 헤더 건수 | `recommendedTotalCountProvider` = `filteredStoresProvider.asData?.value.length`, 없으면 null -> 미표기 | PASS |
| F1-5 `전체보기`/더 보기 | 같은 provider, `total != null && total > 5` | PASS |
| F1-6 `전체 n곳` | 같은 provider, 로딩이면 shimmer | PASS |
| F2-1 메뉴 결과/에러/부분 실패 | `s6/s11` -> `MenuErrorCard`(인덱스만 invalidate), `s7/s9/s12` -> `MenuPartialFailureRow`. probe P5: 부분 실패 재시도 시 `s7 rows=22 refreshing=true` 로 **행 유지**, 완료 후 `s4 rows=30` | PASS (FAIL-3 동일) |
| F2-2 `메뉴 (n)` | 로딩·에러·1글자는 `MenuSectionHeader` 만, 건수는 `SearchViewModel.menuTotal` 한 곳 | PASS |
| F2-3 통합 빈 상태 | `resolveSearchView` 단독, 메뉴 확정일 때만 | PASS |
| F2-4 1글자 안내 | `MenuMinLengthPlate`, 인덱스 미구독 (probe로 읽기 0 재확인 불필요 — 기존 테스트가 호출 0 단언) | PASS |
| F2-5 범위 안내 | `s4/s5/s7/s9` 에서만. `s6/s11`(에러)·`s3/s8`(로딩)·1글자에는 없음 | PASS (문구 정확성은 보류-1) |
| F2-6 이동 후 | `StoreMenuPage` 기존 로딩/에러. 에러 메시지에 `err.toString()` 이 그대로 노출되는 기존 결함이 이 화면에 남아 있다 (이번 변경 범위 밖, 보류-8) | PASS (기존 동작) |
| F3-1 최근 검색어 | 세션 메모리, 제출·결과 탭 기록, 10건, 정규화 중복 끌어올림 | PASS |
| F4-1 거리 | 스냅샷 `distanceKm`, null 이면 카드 `-`, 메뉴 행은 거리 생략 | PASS |
| F4-2 위치 미확정 | 스냅샷이 `userLocationProvider.future` 를 기다림 -> F1 로딩과 동일 | PASS |

인벤토리에 **없는 표면**: `StoreMenuPage` 의 하이라이트 띠(`이 매장이 이 메뉴를 파는가` 라는 사실을 말하는 표면)는 표에 행이 없었다. 그 결과 띠의 판정 출처(`filtered`)가 검증되지 않은 채 구현됐다 (FAIL-1). 표에 `F5 — 매장 판매 여부` 행(띠 / 카드 품절 배지 / 목록 존재 여부)을 추가하라.

---

## PASS 항목

### 기능 검증
- [x] 홈 검색창 탭 -> `SearchPage` push, 문구 불변 (`home_header.dart`)
- [x] 정규화 `trim -> 소문자 -> 공백 제거` 한 곳 (`SearchNormalizer`), 매장은 1글자부터·메뉴는 2글자부터
- [x] 매장 정렬: 이름 매칭 그룹 위, 주소 매칭 아래, 그룹 내 거리순. 주소 매칭만 `subtitle` 표기
- [x] 메뉴 한 행 = 메뉴 x 매장, 거리순 -> 가나다, 30행 상한 + 안내
- [x] 가격 비표시 (1순위 #1)
- [x] 메뉴 상세 직행 없음 (1순위 #2)
- [x] 최근 검색어: 세션 메모리, 10건, 개별/전체 삭제
- [x] 홈 `맞춤 추천` 5건 미리보기 + 헤더 전체 건수 + `전체보기` + `N곳 더 보기`, 5건 이하면 둘 다 숨김
- [x] `RecommendedStoresPage`: 홈과 같은 provider/칩 공유, 거리순/등급순, 당겨서 새로고침
- [x] 홈 읽기: 진입 100 docs, 토글 0
- [x] 메뉴 인덱스: 출처 단위(브랜드 distinct + 개인 매장) `get()`, 세션 캐시, 후보 = 10km·30곳
- [x] 스냅샷 파생 순수 함수가 기존 Repository 규칙과 동일 (`getNearbyStores`/`getStoresByCategories` 대비 승인 필터·거리 정렬·반경·카테고리 any 매칭 대조)
- [x] 12상태 판정 단일 함수, 통합 빈 상태는 메뉴 확정 시에만

### 아키텍처 / 코드 품질
- [x] Firebase import 는 `lib/data` 에만 (`store_repository_impl` 의 `FirebaseException` 포함). 신규 presentation/domain 파일 0건
- [x] `Color(0x...)` 0건, 색상 전부 `AppColors`
- [x] Repository interface 는 domain, 구현은 data, DataSource 는 `get()` 만
- [x] 신규 쿼리는 `.orderBy('displayOrder').get()` 만 — `where`/`collectionGroup` 없음. Rules·indexes 무수정 (`brands/*/menuItems`, `stores/*/menuItems` read 규칙이 `isSignedIn()` 이라 기존 stream 과 동일하게 허용)
- [x] D7 (`limit 100`) 미접촉
- [x] 홈 에러의 `$e` 노출 제거
- [x] `전체보기` 터치 영역 44px

### 디자인 시스템
- [x] 신규 토큰 0, 상태 UI 문구 design §3-c 와 일치

---

## 보류 항목

1. **[우선순위 높음] 범위 안내 `가까운 매장 30곳의 메뉴에서 찾았어요` 가 실제 검색 범위와 다를 수 있다.** 후보는 `distanceKm <= 10km` 상위 30곳이다. probe W9a: 10km 안에 매장이 0곳이면(예: 사용자가 모든 매장에서 10km 이상 떨어짐) **0곳을 검색하고도 통합 빈 상태에 "30곳의 메뉴에서 찾았어요" 가 붙는다.** W9b: 3곳뿐이어도 "30곳". 문구는 spec §3.2 고정 문구와 글자 그대로라 FAIL 로 올리지 않았다. 제안: 인덱스에 실제 검색한 매장 수를 실어 `가까운 매장 {n}곳(10km 이내)` 로 말하고, 0곳이면 별도 안내.
2. **[높음] L1(점포 한정 메뉴 제외) 미고지.** 설계 우려 4 참조. 범위 안내에 `점포 한정 메뉴는 포함되지 않을 수 있어요` 한 구절.
3. 홈 pull-to-refresh 가 `fetchAll` 을 2회 읽는다 (200 docs). `allowAndFetch` 성공 경로에서는 `invalidate` 가 중복. 실기기 확인 필요 (probe 는 위치 fake 사용). 개선이지 회귀 아님.
4. 실기기 필요: 텍스트 1.5x, 접근성 낭독(design §8), 키보드 올라온 상태의 스크롤·`onDrag` dismiss, 한글 IME 조합 중 debounce — 자동 검증 불가.
5. 비로그인 `permission-denied` 화면은 실제 도달 경로가 거의 없어 수동 확인 대상. 도달 시 FAIL-3 의 지연과, 에러 캐시가 재로그인 후에도 남는 문제(`다시 시도` 를 눌러야 풀림)가 같이 나타난다.
6. `메뉴 (n)` / `메뉴 N개 중 30개` 의 단위는 **행(메뉴 x 매장)** 이다. 같은 메뉴를 여러 매장이 팔면 개수가 부풀어 보인다. spec 이 "한 행 = 메뉴 x 매장" 으로 확정했으므로 문구만 `결과 (n)` 등으로 바꿀지 설계자 판단.
7. 결과 행 탭에서 `storesById[hit.storeId] == null` 이면 **조용한 no-op** (`search_page.dart` `_menuSection`). 현재는 같은 스냅샷에서 나오므로 도달하기 어렵지만, 도달하면 사용자는 반응 없는 행을 본다. 방어 코드 또는 스낵바 권고.
8. 이 기능이 보내는 목적지 화면(`StoreMenuPage._ErrorView`)이 여전히 `err.toString()` 원문을 노출한다. 이번 사이클이 홈에서 고친 `$e` 노출과 같은 부류의 기존 결함. 이번 범위 밖이므로 후속 task.

---

## 설계자 전달 메시지

- 테스트가 모두 통과하는 상태에서 **오경보 1건(FAIL-1), 빈 화면 1건(FAIL-2), 실패 표시 지연 1건(FAIL-3)** 이 나왔다. 셋 다 "provider 를 override 하거나 `AsyncValue` 를 손으로 만드는" 기존 테스트의 사각지대였다.
- FAIL-1 과 FAIL-2 는 **새 기능이 기존 전역 UI 상태(`selectedMainCategoryProvider`, `selectedSubCategoryIdProvider`)와 기존 필터 규칙(`filteredMenuItemsProvider` 의 활성 카테고리 필터)에 기대면서** 생겼다. 검색 인덱스의 필터 기준과 매장 화면의 필터 기준이 같은 사실("이 메뉴는 이 매장에서 보이는가")을 서로 다르게 판정한다. 인벤토리 표에 이 사실의 행이 없었던 것이 근본 원인이다.
- 읽기 비용의 정당성(홈 200 -> 100, 토글 0)은 **독립 재현으로 확인됐다.** 이 기능의 존재 이유는 유효하다.
- spec 위반이 아니라 "참인 말을 하고 있는가" 의 문제가 보류-1/2 에 있다. 범위 안내 문구는 한 곳 수정으로 둘 다 줄일 수 있다.

---

## 재작업 우선순위

1. **FAIL-1** — `foundName` 을 `allItems` 기준으로, 서브카테고리 clear, 첫 프레임 정정 (developer, 소규모)
2. **FAIL-3** — 두 provider 에 `retry` 상한 (developer, 2줄 + 테스트)
3. **FAIL-2** — 활성 카테고리 필터 일치 또는 `initialMainCategoryCode` 가드 (developer, 소규모)
4. 보류-1, 2 — 범위 안내 문구 정직화 (designer 문구 확정 -> developer)
5. 인벤토리 표에 `F5 매장 판매 여부` 행 추가 (designer)

## 후속 task 후보

- `selectedMainCategoryProvider`/`selectedSubCategoryIdProvider` 를 매장 단위(family 또는 화면 스코프)로 분리 — 설계 우려 1, FAIL-1 의 (3)(4), FAIL-2 의 `effectiveMain` 결함의 공통 원인
- 홈 pull-to-refresh 이중 읽기 제거 (보류-3)
- 인덱스에 `searchedStoreCount` 노출 (보류-1)
- 전체 앱 Riverpod `retry` 정책 정리 (FAIL-3 는 홈 전체에 해당)
- `StoreMenuPage._ErrorView` 예외 원문 노출 제거 (보류-8)
- spec §7 F2 (CF 비정규화 `menuSearchKeywords`) — L1·L2·L5 와 FAIL-2 계열을 근본 해소
