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

---
---

# 2차 (검색 개정 — 매장 실제 제공 메뉴 + 가격·품절 + 상세 직행)

> 위 1차 절은 이력이다. 충돌 시 이 절이 이긴다. 기준: spec §15 / design §13 / implementation §12, 구현 커밋 `726b671`.

## 2차 테스트 일시 / 방법

- 2026-10-26, 커밋 `726b671`, working tree clean.
- 의뢰자가 재실행해 확인한 항목은 **다시 돌리지 않았다**: analyze 0 / test 544 / Rules 341 / rules·indexes 무수정 / 신규 `.where(` 는 Dart 리스트 필터 / 임시 파일 0.
- **테스트가 못 보는 것**을 찾기 위해 저장소 밖(스크래치패드)에 probe 를 만들어 실제 provider 그래프 + 실제 위젯 + 실제 리포지토리로 재현했다 (개발자 테스트의 `_World` 데이터 소스 fake 를 복사해 시나리오를 추가). 검증 후 전부 삭제했다. 저장소 변경은 이 파일뿐이다. 운영 Firestore 접근 없음, 배포 없음.

## 2차 전체 결과

- PASS: 17개
- FAIL: 2개 (Medium 1, Low 1)
- 보류: 9개

가장 먼저 고칠 것: **FAIL-4** (13번째 상태 — fan-out 상한에 걸려 일부 매장을 못 읽었는데 검증 통과 행이 0건이면 `일치하는 메뉴가 없어요` 라고 말한다).

---

## 2차 1순위 — 라이브 회귀 2건 (독립 재현)

### R-A `_mergeForBrandStore` 교체: 동작 변화 0 — PASS

- 교체 전 구현(`726b671^` 의 `_mergeForBrandStore` 중 override 적용부)을 **내가 직접 옮겨** 새 구현(`applyOverrideForCustomer`)과 비교했다 (개발자 테스트와 별개의 스크립트).
- 조합: master status(3) x master visible(2) x master soldOut(2) x master disabledGroup(2) x override 유무 x override status(3) x excluded(2) x priceOverride(null/0/3500) x soldOut(2) x disabledGroup(2) x disabledItem(2) = **6,912 조합, 차이 0건.**
- 비자명한 규칙 직접 확인 (priceOverride 3500, excluded, soldOut, disabledItem 이 모두 설정된 override 1건):
  - `pending`  -> price 4000(무시) / soldOut true(적용) / disabledItem 적용 / 제외 안 됨
  - `rejected` -> 동일 (핵심 필드 무시, 운영 필드 적용)
  - `approved` -> `null` (excluded)
- 마스터 자체의 `approved && visible` 필터는 이 함수 밖(머지 목록 선행 필터)에 그대로 남아 있다. 정렬·병합 순서 불변.

### R-B `watchById` override 머지 — PASS (보류 2건 별도)

- 실제 `MenuItemRepositoryImpl` + 실제 화면으로 4개 표면 교차 확인 (아래 교차 일치 표). 승인 override 가격 3,500 / 마스터 4,000 일 때 카드 = 상세 = 담기 합계 = 3,500.
- pending override(가격 9,999 + soldOut): **가격은 무시(마스터 5,000), 품절은 적용** — 검색 행, 매장 카드, 상세 모두 같다.
- 개인 매장(case A): `brandId` 가 비면 `storeStream` 만 반환하고 override 를 구독하지 않는다 (코드 + 개발자 테스트 + `CloneOwnerStoreMenuUseCase` 의 owner 리포지토리는 `masterDs == null` 이라 이 분기 자체를 안 탄다).
- override 스트림 실패는 `Rx.combineLatest3` 이 에러로 전파 -> `.when(error)` -> `_ErrorView`. 마스터 가격 폴백 없음.
- 소비자 전수 확인: `watchById` 는 customer `menuItemDetailProvider` 와 owner 개인 매장 clone 두 곳뿐. owner/brand 화면이 이 변경된 경로를 타지 않는다.
- Rules: `stores/*/menuOverrides/*` 는 `isSignedIn()` 이라 단건 구독도 허용 (목록 머지가 이미 같은 컬렉션을 구독 중이었다).

---

## 2차 교차 일치 (4곳 직접 대조) — PASS

실제 그래프 probe 에서 (매장 s1, 마스터 m1 4,000 / m3 5,000):

| 시나리오 | 검색 행 | 매장 카드 | 상세 가격 | 담기 합계 | 품절 |
|---|---|---|---|---|---|
| m1: approved override 가격 3,500 | 3,500원 | 3500 | 3,500원 | 3,500원 | 아니오 (4곳 동일) |
| m3: **pending** override 가격 9,999 + soldOut | 5,000원 + `품절` | 5000 / soldOut true | 5,000원 + `품절` 버튼 + 안내 plate | 5,000원(muted) | 예 (4곳 동일) |

- `formatKrw` 는 **한 곳이 아니다**: 검색 행 2회(보이는 글자 + 접근성 label), 카드 2회, 상세 3회. 전부 같은 필드(`basePrice`)를 넘기므로 값이 갈라질 구멍은 없다. 다만 커밋 메시지의 "한 곳에서만" 은 부정확하다 (보류-9).
- 담기 합계는 `basePrice + 옵션 Σ` 이므로 필수 옵션 자동 선택(`primeRequiredDefaults`)이 있는 메뉴는 첫 화면부터 기본가보다 크다. 기존 동작이며 기본가 성분은 일치한다.

---

## 2차 FAIL 항목

### FAIL-4 [Medium] 13번째 상태: fan-out 상한에 걸리고 검증 통과 행이 0건이면 `일치하는 메뉴가 없어요` 라고 말한다

- **문제**: R4 상한(10곳) 밖 브랜드 매장의 행은 버려지고 `fanOutTruncated=true` 가 되지만, 이 플래그는 **행이 1건 이상일 때만** `isTruncated` 로 안내 문구(`검색 범위를 좁혀 보세요`)에 쓰인다. 가까운 10곳이 전부 그 메뉴를 `excluded` 했고 11번째 이후 매장이 팔고 있으면 결과 0건 -> `resolveSearchView` 가 `s10UnifiedEmpty`(또는 s5) 로 판정해 `'아이스' 와 일치하는 …없어요` 를 그린다. **읽지 못한 매장에 대해 "없다" 고 단정한다.**
- **위치**: `lib/presentation/customer/search/providers/search_providers.dart` `resolveSearchView` (truncated 를 보지 않음), `search_page.dart` (`s5`/`s10` 분기가 `fanOutTruncated` 를 안 봄)
- **재현** (probe I, 실제 그래프): 브랜드 매장 12곳(가까운 순 s1..s12), s1..s10 이 m1·m3 를 approved `excluded`, s11·s12 는 정상 판매. 질의 `아이스` -> `view=s10UnifiedEmpty rows=0 total=0 fanOutTruncated=true`.
- **왜 중요한가**: 1차 FAIL-1·FAIL-2 와 같은 부류("화면이 모르는 것을 아는 척한다"). spec 이 상태 12개를 확정한 뒤 `truncated` 라는 새 축이 추가됐는데 상태 판정표가 이 축을 반영하지 않았다 -> 이 축 x 빈 결과 조합이 표에 없다.
- **도달 가능성**: 낮다 (가맹점 10곳 이상이 한 반경에 있고 전부 제외해야 함). 그러나 프로덕션에서 가맹점이 늘수록 "가까운 매장들이 일부 메뉴를 빼는" 구성은 자연스럽다. 비용 대비 수정이 작다.
- **제안 수정 방향**: 빈 결과 + `fanOutTruncated` 이면 통합 빈 상태 대신 `검색 범위를 좁혀 보세요. 일부 매장의 메뉴는 보여드리지 못했어요` 를 보여주거나(부분 실패 줄 재사용), `isPartial` 에 truncated 를 합산해 s7/s12 로 보낸다. 상태표(design §1/§13)에 `truncated x empty` 행 추가.
- **테스트 추가 권고**: 위 probe 를 회귀로 (기존 R4 테스트는 행이 남는 경우만 본다).

### FAIL-5 [Low] 인벤토리 누락 — 홈 `자주 찾는 메뉴` 카드가 가격을 말하는데 표에 없고, 판매 중이 아니면 `0원` 이다

- **문제**: `FrequentMenuCard` 는 `PriceFormatter.formatKrw(entity.basePrice)` 를 **무조건** 그린다. `basePrice` 는 `GetFrequentMenuItemsUseCase` 가 머지된 매장 메뉴 목록에서 찾은 값이고, **찾지 못하면 0** (`int basePrice = 0`). 따라서 (a) 메뉴 스트림이 아직 emit 전인 매장, (b) 그 매장이 지금은 제외(excluded)했거나 삭제한 메뉴는 **`0원`** 으로 보인다. 품절·판매 중단 표시도 없다.
- **위치**: `lib/domain/usecases/get_frequent_menu_items_use_case.dart` (~L77), `lib/presentation/customer/home/widgets/frequent_menu_items_section.dart` (~L211)
- **성격**: **사전 존재 결함**이다 (이번 커밋이 만든 것이 아님). 그러나 design §13-7 은 "ⓑ 가 빈 칸인 행은 없다" 로 인벤토리 완결을 선언했고, 이 표면은 "이 매장이 이 메뉴를 얼마에 파는가" 를 말하는 표면인데 F5 어디에도 없다. 1차 FAIL-1·2 의 근본 원인(행 누락)이 2차에도 한 건 남아 있다. 가격은 머지 목록 값이라 override 가격과는 일치한다 (불일치가 아니라 "없을 때의 0원" 문제).
- **제안 수정 방향**: 조회 실패/미도달이면 가격 줄을 숨긴다 (`0원` 금지). 제외된 메뉴는 카드에서 빼거나 `판매하지 않아요` 로. 인벤토리에 `F5-13 홈 자주 찾는 메뉴 가격` 행 추가 (ⓑ: 목록 미도달 시 가격 줄 숨김).

---

## 2차 PASS 항목

### 라이브 화면 (1순위)
- [x] R-A `_mergeForBrandStore` 교체 동작 변화 0 (6,912 조합 독립 재현)
- [x] R-B `watchById` 3-스트림 머지, 카드 == 상세, 개인 매장 불변, override 실패 -> 에러(폴백 없음)
- [x] D9 매장 카드 품절 탭 허용 — 상세에서 같은 품절 상태 (probe G)

### 이 기능이 조용히 틀린 것을 보이는 지점 (2순위)
- [x] 교차 일치 4곳 (위 표)
- [x] **R1 깜빡임 없음**: 느린 네트워크 + 일시 실패 후 성공(override 1회 실패 -> 0.8초 재시도) 시퀀스가 `로딩 -> 데이터` **한 번**이다 (probe H1: `s8…Loading -> s9…Data(rows=4)`, 에러·부분 실패가 비치지 않는다). 재시도 중 `isLoading` 을 실패로 확정하지 않는 분기가 실제로 동작한다.
- [x] **R6 행 단위 폐기**: 가격만 비운 행이 생기는 분기가 없다. 검증 실패 매장 행은 `continue`, 상한 밖 행도 `continue`. 개인·점포 한정 행은 override 가 없으므로 통과(올바름).
- [x] **품절 판정 순서**: 상세 `enabled = !soldOut && ready && !_busy`, 품절이면 `onPressed: null`(탭 자체가 안 됨) + `_onAddPressed` 가 즉시 return. 품절일 때 필수 옵션 미선택 토스트가 뜨는 경로 없음. (참고: `!ready` 토스트 분기는 `enabled` 에 `ready` 가 있어 원래부터 도달 불가 — 기존 데드 코드.)
- [x] **`_DeletedView` 도달 경로 전수** (`watchById == null`): ① case B 승인된 excluded ② 마스터 문서 삭제 ③ 점포 한정 메뉴 삭제(둘 다 null) ④ 개인 매장 메뉴 문서 삭제 ⑤ 매장 문서 자체가 없음(`brandId` 조회 null -> store 스트림만 -> null). 진입점은 `StoreMenuPage` 의 카드 탭 / 자동 push 둘뿐이다. 문구 `이 매장에서는 판매하지 않는 메뉴예요 / 메뉴가 내려갔거나 판매가 중단됐을 수 있어요` 는 ①~⑤ 전부에 참이다. 에러(브랜드 조회 예외, 스트림 에러)는 `_ErrorView` 로 가서 이 문구를 쓰지 않는다. `매장 메뉴 보기`: 바로 아래가 그 매장 `StoreMenuPage` 면 pop, 아니면 교체 — 상세는 항상 매장 화면 위에서만 열리므로 교체 분기는 사실상 방어 코드.

### 전환 / 라우팅 (4순위) — 시뮬레이션 수준 PASS, 실기기는 보류
- [x] 매장 화면이 보이지 않는 동안 아래 검색 행이 탭되지 않는다 (probe B: 두 번째 행 탭 후에도 `StoreMenuPage` 라우트 1개, ModalBarrier 가 막음).
- [x] iOS 스와이프 백 (variant iOS, 실제 라우트): 상세 완료 후 스와이프 -> 스와이프 도중 매장 화면 opacity 1(검색이 비치지 않음) -> 상세 pop, 상세 재열림 없음 -> 다시 스와이프 -> 매장 pop, 검색 유지 (probe C).
- [x] 상세 전환 중(`animation != completed`)에는 스와이프 백이 아예 시작되지 않는다 -> "reveal 전에 스와이프" 경로가 없다 (probe C2).
- [x] 다른 진입점(매장 화면에서 직접 카드 탭, 매장 결과 탭)은 `MaterialPageRoute` 그대로이고 `_wrapSeamless` 는 `seamlessEntry=false` 면 `scaffold` 를 그대로 반환한다. iOS 스와이프 백 정상 (probe E).
- [x] `PageRoute` + `MaterialRouteTransitionMixin` 직접 정의: 플랫폼 전환 유지, `opaque:false` 인 동안 접근성은 ModalBarrier 의 `BlockSemantics` 가, 숨김 동안의 매장 화면 시맨틱은 `AnimatedOpacity(0)` 가 제외한다.

### 쿼리 실측 (5순위) — 독립 재현
- [x] 카운팅 fake 로 `SearchMenuItemsUseCase.buildIndex` + `planVerification` 을 직접 실행 (후보 30곳 = 개인 15 + 브랜드 매장 15 / 브랜드 2개): 1단계 **32 쿼리** (브랜드 마스터 2 + 매장 자체 메뉴 30), 일치 브랜드 매장 15곳 -> 2단계 **10 쿼리**(상한, `truncated=true`), 합계 **42**. 개발자 값과 일치.
- 이 모델은 **브랜드가 2개뿐**이다. 1단계 쿼리 = `distinct 브랜드 수 + 후보 매장 수(<=30)` 이므로 후보 30곳이 **서로 다른 브랜드 30개**인 이론 최악은 **60 + 10 = 70** 으로 spec §5.3 전환선(60)을 넘는다. 현실 모델(브랜드 2~3개)이면 여유는 **18 쿼리(42 -> 60)**, 가맹점 20곳 트리거(`backlog.md`) 도달 시 1단계가 이미 `브랜드 + 20 + 개인` 이므로 같은 크기다. spec §15 의 "최악 27" 은 D10 이전 계산이라 낡았다 (개발자도 인정). **판정: 현재 운영(가맹점 2곳)에서는 +2 로 무해, 여유 18, 트리거는 가맹점 수와 브랜드 다양성 둘 다에 걸려 있다.**
- 쿼리 수 외에 **문서 읽기 수**는 2단계가 override 컬렉션 전체를 읽으므로 `10 x (매장당 override 문서 수)` 다 (오버라이드가 마스터 대부분에 걸린 매장이면 수백). 쿼리 수만으로 비용을 말하면 과소평가된다 -> 보류-6.
- [x] 인덱스 0: 신규 one-shot 은 `.orderBy('displayOrder').get()` 과 `.get()`, 상세는 문서 단건 `snapshots()`. rules/indexes 무수정.

### 표면 인벤토리 F5-5 ~ F5-12 의 ⓑ (6순위)
- [x] F5-5/6 행 가격·품절: 검증 실패 = 행 없음 (R6 코드·probe 일치)
- [x] F5-7 상세 가격: 3-스트림 중 override 실패 = `_ErrorView` (실제 리포지토리 테스트 + 코드)
- [x] F5-8/9 상세 품절·합계: 로딩 중 바텀 바 없음, 합계는 상세 `basePrice` 기준
- [x] F5-10 `_DeletedView`: 에러를 "판매하지 않아요" 로 말하지 않음 (위 전수)
- [x] F5-11 자동 열림 판정: 로딩 투명 + 250ms 스크림 + 3초 폴백 (probe) — 에러 시 3초 동안 투명 (보류-7)
- [x] F5-12 카테고리 태그: 1차 그대로
- **인벤토리에서 빠진 사실**: FAIL-4(상태표의 `truncated x empty`), FAIL-5(홈 `자주 찾는 메뉴` 가격). 그 외 가격·품절을 말하는 표면(장바구니 라인, 주문 상세)은 "담은 시점/주문 시점의 값" 을 말하는 표면이라 F5(현재 판매 상태)와 다른 사실이다 — spec F8(범위 밖)에서 다룬다.

### 구조 / 코드 품질
- [x] `Color(0x…)` 0건, 신규 색상 토큰 0, 하드코딩 secret 0
- [x] domain/presentation 에 Firebase import 0건. `search_providers.dart` 가 data 클래스를 직접 생성하는 DI 는 기존 customer provider(`store_menu_providers.dart`)와 같은 관례
- [x] `QuantityStepper` 의 `Opacity(1)` 래핑은 카트 화면에 레이어를 만들지 않는다 (기본 `enabled=true`)
- [x] 인벤토리 외 신규 `MenuSearchHitEntity` 필드는 `basePrice`/`soldOut` 둘뿐 (design §13-9.2)

---

## 2차 보류 항목

1. **[P3] 새로고침/`다시 시도` 가 override 재읽기에 실패하면 조용히 오래된 값을 쓴다.** probe H2: 2단계 s2 가 영구 실패하는 상태에서 `invalidate(storeMenuOverridesProvider)` -> Riverpod 3 은 `hasValue=true & hasError=true` 로 이전 값을 유지하고, `menuSearchResultsProvider` 는 `a.hasValue` 를 먼저 보므로 최종 상태가 `rows=4, fail=0, refreshing=false` (부분 실패 안내 없음). spec §15 가 "재시도 중에도 직전 값 유지(hasValue 우선)" 를 명시했으므로 **spec 위반은 아니다**. 다만 "재시도가 끝난 뒤 최종 실패" 의 표시는 spec 이 정하지 않았고, 사용자가 명시적으로 새로고침했는데 낡은 가격을 신선한 것처럼 본다. 상세가 실시간 값으로 덮으므로(L4 축소) 피해는 작다. 설계자 판단 필요: `hasError && !isLoading` 이면 부분 실패로 승격할지.
2. **[P3] 매장 메뉴 스트림 캐시가 낡았을 때의 일회성 자동 열림 판정.** `storeMenuItemsProvider` 는 autoDispose 가 아니라 이전에 방문한 매장은 첫 `data` 가 이전 스냅샷일 수 있다. `_maybeAutoOpen` 은 **첫 data 로 한 번만** 판정(`_autoOpened`)하므로, 직전 방문 이후 메뉴가 새로 판매 시작된 경우 `판매하지 않는 메뉴일 수 있어요` 띠가 잘못 뜨고 자동 열림이 생략될 수 있다. 우리 fake 는 `Stream.value` 라 Riverpod 일시정지/재개 후 Firestore 가 새 스냅샷을 주는 모습을 재현하지 못했다 -> **에뮬레이터 필요**.
3. **[P3] 3초 폴백 이후 데이터가 도착하면 상세가 뒤늦게 자동으로 열린다** (probe A 재현). design §13-4/F5-11 이 "이 경우에 한해 두 번의 전환 수용" 으로 허용한 동작이라 PASS. 단 사용자가 이미 보이는 매장 화면을 보고 있을 때 갑자기 상세가 덮인다.
4. **[P3] developer 가 올린 4건 판정**:
   - 숨겨진 매장 화면의 shimmer 가 투명하게 도는 것: **수용**. 길어야 수백 ms, 3초 폴백이 상한이다.
   - 부분 실패 `다시 시도` 가 1단계(32쿼리)까지 다시 읽음: **개선 권고**. 재시도 1회 = 최대 42 쿼리. `index.failedSourceCount == 0` 이면 2단계만 invalidate 하는 분기가 싸다. FAIL 급은 아니다 (사용자 명시 동작).
   - design §13-5 의 150ms 페이드 미구현: **수용**. §13-11 완료 기준은 "한 번에 전이, 행이 떴다 사라지지 않음" 이고 이는 충족한다.
   - 실기기 미확인: **보류 유지** — 아래 수동 체크리스트.
5. **[P3] 오프라인/콜드 캐시에서 override 문서 단건 구독**: `streamByStoreAndMaster` 가 `doc.exists` 만 보고 `metadata.isFromCache` 를 보지 않는다. 캐시에 없는 문서는 오프라인에서 "없음(null)" 으로 보여 마스터 가격으로 보일 수 있다 (목록 머지의 `streamByStore` 도 같은 한계라 카드 == 상세는 유지됨). 에뮬레이터/오프라인 확인 필요.
6. **[P3] 비용은 쿼리 수뿐 아니라 문서 수로도 본다** — 2단계는 매장당 override 문서 전체를 읽는다. 가맹점 override 가 많아지면 쿼리 42 로는 안 보이는 비용. 트리거 문서에 문서 수 기준도 한 줄 권고.
7. **[P4] 목록 스트림 에러가 즉시 알려져도 3초 동안 투명 + 스크림** (probe J: 에러 시에도 reveal 은 3초 타이머). design F5-11 은 "에러/3초 초과: reveal" 로 묶어 말한다. Riverpod 자동 재시도(1차 FAIL-3 의 B-1, 전역 정책 대기)가 에러 확정을 늦추므로 어차피 shimmer 가 보인다. B-1 결정과 함께 재평가.
8. **[P4] 실기기 수동 체크리스트**: (a) iOS 실기기에서 상세 위 스와이프 백 도중 매장 화면이 일찍/늦게 비치는지 (b) Android 예측형 뒤로가기 (c) 텍스트 1.5x 에서 검색 행 3행(가격·품절·카테고리 Wrap) 겹침·잘림 (d) 접근성 낭독 `{메뉴명}, {가격}, 품절, …` (e) 저속망에서 250ms 스크림 체감.
9. **[P4] 문서/주석 정합**: ① 커밋 메시지·implementation 의 "`formatKrw` 한 곳" 은 사실이 아니다 (같은 필드를 여러 위젯이 호출). ② `search_menu_items_use_case.dart` 상단 doc 주석(`인덱스는 override 를 읽지 않으므로 가격 필드를 만들지 않는다`)이 낡았다. ③ spec §15 의 `storeMenuOverridesProvider` 는 `autoDispose.family` 인데 구현은 일반 `family` + `SearchPage.dispose` 의 수동 invalidate 다 — implementation §9 류 "작업표와 현실의 차이"에 기록이 없다. ④ `store_menu_page.dart` 는 파일 전체가 재포맷되어 diff 의 절반이 서식 변경이다 (논리 변경 검토를 어렵게 한다).

---

## 2차 설계자 전달 메시지

- 라이브 회귀 2건(`_mergeForBrandStore` 교체, `watchById` override 머지)은 **독립 재현으로 문제 없음**이다. 이번 사이클에서 위험이 가장 컸던 곳이 가장 깨끗했다.
- FAIL 2건 모두 **1차와 같은 패턴**이다: 화면이 모르는 것을 아는 척한다(FAIL-4), 사실을 말하는 표면이 인벤토리에 없다(FAIL-5). FAIL-4 는 R4 가 새로 만든 `truncated` 축이 12상태 판정표에 반영되지 않아서 생겼다 — **새 축이 생기면 상태표의 기존 칸과 교차 점검**하는 항목을 완료 기준에 두길 권한다.
- 개발자 테스트는 이번에 실제 그래프(데이터 소스만 대체)로 작성되어 1차 사각지대를 대부분 닫았다. 남은 사각지대는 **Firestore 스트림의 일시정지/재개/캐시 동작**이며 fake 로는 재현되지 않는다(보류-2, 5). 에뮬레이터 시나리오 1~2개를 수동 점검 항목으로 권한다.

## 2차 재작업 우선순위

1. **FAIL-4** — `truncated x empty` 상태 처리 + 상태표 갱신 (developer 소규모, designer 문구 1줄)
2. **FAIL-5** — 홈 `자주 찾는 메뉴` 가격 `0원` 제거 + 인벤토리 F5-13 추가 (developer 소규모)
3. 보류-1 판단 (설계자) — 재읽기 최종 실패 표시 여부
4. 보류-4 두 번째 — 부분 실패 재시도를 2단계만 (선택)

## 2차 후속 task 후보

- 에뮬레이터 기반 스트림 캐시/오프라인 시나리오 (보류-2, 5)
- 가맹점 20곳 트리거에 "브랜드 다양성(distinct brand 수)·override 문서 수" 지표 추가 (쿼리 이론 최악 70)
- 장바구니·결제 품절 검증 (spec F8, 이미 backlog)
