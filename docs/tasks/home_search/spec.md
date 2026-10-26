# 홈 검색 + 추천 매장 더보기 기능 명세

- 작성: 2026-10-26 (architect)
- 계기: `docs/backlog.md` "진입점만 있고 동작 없음" 표 2행 (홈 검색 / 추천 매장 더보기) 동시 해소
- 선행 읽기: `CLAUDE.md` 절대 규칙, `docs/architecture.md`, `docs/processes/role_flows.md`, `docs/processes/audit_trail.md` §4

> ## ⚠️ 이 문서는 2개 판본을 담는다
>
> **§1~§14 는 1차 설계(2026-10-26)이며 그대로 구현·검증·배포되어 현재 동작 중이다.** 커밋 `4d0338d`(spec) → `7d6efbb`(design) → `38f9319`(구현) → `becd3ec`(검증) → `4db3786`(수정) → `e7f5c03`.
>
> **§15 는 2차 개정(2026-10-26, 같은 날 후속)이다.** 사용자 결정 2건으로 검색의 **대상과 목적지**가 바뀐다.
> 1. 검색 대상을 "브랜드 마스터 메뉴" → **"매장에서 실제로 제공하는 메뉴"** 로 바꾼다 (1차 한계 L2 해소)
> 2. 메뉴 결과 탭 → 매장 화면에 머무르지 않고 **메뉴 상세로 직행**한다 (1차 결정 D3 뒤집기)
>
> **충돌 시 §15 가 §1~§14 를 이긴다.** 1차 절은 삭제하지 않고 이력으로 남긴다 — 무엇을 왜 바꿨는지가 근거다.
> §15 가 명시적으로 뒤집는 절: **§2.3 L2 · L5 / §3.2 가격 미표시 / §3.3 전체 / §4.1 가격 필드 금지 / §13 D3**.
> §15 가 그대로 유지하는 절: **§5.3 매장 100건 절단 / §6 이력 / §8 인덱스 0건 / §12 추천 전체보기 / §14**.

---

## 개요

- **목적**: 홈 화면에 남아 있는 `준비 중` SnackBar 두 개를 실제 동작으로 대체한다.
  1. 홈 헤더 검색창 → **매장 + 메뉴 통합 검색 화면**
  2. `맞춤 추천` 섹션의 `전체보기` → **추천 매장 전체 목록 화면**
- **작업 유형**: 신규 기능 (화면 2개 추가) + 기존 홈 provider 구조 리팩터링 (중복 조회 제거)
- **영향 범위**
  - 화면: 신규 `SearchPage`, 신규 `RecommendedStoresPage`, 수정 `home_header.dart`, 수정 `recommended_stores_section.dart`
  - Domain: 신규 Entity 1개, 신규/확장 UseCase 3개, Repository Interface 3개 메서드 추가
  - Data: DataSource 2개에 one-shot fetch 메서드 추가, RepositoryImpl 3개 메서드 구현
  - Presentation: 신규 provider 파일 2개, `home_providers.dart` 구조 변경
  - 공통 컴포넌트: `core/utils/search_normalizer.dart` 신규
  - 라우팅: `Navigator.push` 2건 (명명 라우트 체계 없음 — 기존 방식 유지)
  - 권한 / 환경 설정: **변경 없음** (`firestore.rules` 무수정, `firestore.indexes.json` 무수정 — §8 참조)
- **비범위** (§7 에 후속 과제로 정리)
  - 외부 검색 엔진 (Algolia / Typesense / Elastic) — 사용자 판단 "지금 단계엔 과하다"
  - 초성 검색 (`ㅊㅋ` → 초코), 오타 보정, 자모 분해, 영↔한 혼용(`ame` → 아메리카노), 동의어
  - 서버 측 전문 검색 / Geohash 반경 쿼리
  - 검색어 수집·인기 검색어·검색 로그 저장 (§6 참조 — 서버에 아무것도 쓰지 않는다)
  - 최근 검색어 **영구** 저장 (`shared_preferences` 미도입 — 세션 메모리만)
  - 브랜드명 자체 검색 (매장명에 브랜드명이 안 들어간 가맹점은 미검출 — §5.4)
  - 메뉴 결과 탭 → 해당 메뉴 카드까지 스크롤/하이라이트 (§3.3 결정 D3)
  - 검색 결과 내 등급·카테고리 필터 (주문 탭에는 이미 있음. 홈 검색은 질의 하나로 단순 유지)
  - 주문 탭(`order_providers.dart`)의 자체 `fetchAll` 호출 통합 (§5.3 — 후속)

---

## 1. 현재 상태 (코드 확인 결과)

### 1.1 홈이 매장을 받아오는 경로

| provider | UseCase | Repository | 실제 쿼리 | 읽기 |
|---|---|---|---|---|
| `nearbyStoresProvider` | `GetNearbyStoresUseCase` | `getNearbyStores` | `fetchAll(limit:100)` | 100 |
| `filteredStoresProvider` | `GetStoresByCategoriesUseCase` | `getStoresByCategories` | `fetchAll(limit:100)` | 100 |
| `orderBaseStoresProvider` (주문 탭) | `GetNearbyStoresUseCase` | `getNearbyStores` | `fetchAll(limit:100)` | 100 |

`StoreRemoteDataSource.fetchAll` 은 항상 `orderBy('averageScore', desc).limit(100)` 이다. 거리·카테고리·`status=approved` 필터는 전부 `StoreRepositoryImpl` 에서 클라이언트로 수행한다.

**확인된 낭비**: 홈 진입 1회에 200 reads. 게다가 `filteredStoresProvider` 는 `selectedCategoriesProvider` 를 watch 하므로 **카테고리 칩을 한 번 토글할 때마다 100 reads 가 추가로 발생**한다. 같은 100건을 계속 다시 받는다. 여기에 검색이 자기 조회를 또 붙이면 300 reads 가 된다.

### 1.2 `맞춤 추천` 섹션이 지금 무엇을 뽑는가 — 코드 확인

`filteredStoresProvider` → `getStoresByCategories(categories, location)`:

1. `fetchAll(limit:100)` (averageScore 내림차순 상위 100)
2. `status == approved` 필터
3. `menuCategories` 가 선택된 카테고리와 **하나라도 겹치면** 통과 (OR 조건)
4. 거리 계산 후 **거리 오름차순 정렬**
5. **반경 제한 없음. 개수 제한 없음.**

그리고 `recommended_stores_section.dart` 는 이 리스트를 `for (var i = 0; i < list.length; i++)` 로 **전부 그린다**.

> **핵심 발견**: `맞춤 추천` 섹션은 이미 전체 목록이다. 지금 구조에서 `전체보기` 를 눌러도 보여줄 "더" 가 없다. 따라서 이 과제는 "목록 화면을 새로 만드는 일" 이 아니라 **"홈 섹션을 미리보기로 줄이고, 전체를 별도 화면으로 옮기는 일"** 이다. 홈의 현재 동작이 바뀐다 → §3.4 결정 D4 (사용자 확인 필요).

### 1.3 메뉴 데이터 구조 (검색의 난점)

`MenuItemRepositoryImpl.watchByStore` 가 매장 1곳의 메뉴를 만드는 방식:

- **case A — 개인 매장 (`brandId == null`)**: `stores/{storeId}/menuItems` stream 1개
- **case B — 가맹점 (`brandId != null`)**: `Rx.combineLatest3` 로 stream **3개** 머지
  - `brands/{brandId}/menuItems` (마스터)
  - `stores/{storeId}/menuOverrides` (가격 override / `excluded` / 품절)
  - `stores/{storeId}/menuItems` (점포 한정 추가 메뉴)
- 추가로 `store doc` 을 `getById` 로 한 번 더 읽어 `brandId` 를 판정한다.

즉 "매장 100곳의 메뉴를 다 받아온다" 를 그대로 하면 최악 **100 × (1 + 3) = 400 쿼리 + 상시 listener 300개** 다. 비현실적이라는 사용자 판단이 맞다. §2 가 이 문제를 어떻게 줄였는지 설명한다.

---

## 2. 메뉴 검색을 어떻게 푸는가 (이 과제의 핵심)

### 2.1 두 가지 관찰

**관찰 1 — 메뉴 출처는 매장 수보다 적다.**
가맹점은 메뉴를 **매장이 아니라 브랜드가** 가진다. 같은 브랜드의 매장 20곳은 `brands/{brandId}/menuItems` **한 곳**을 공유한다. 그래서 필요한 쿼리 수는 매장 수가 아니라

```
출처 수 = (후보 매장의 distinct brandId 개수) + (후보 매장 중 brandId == null 인 매장 수)
```

가맹점이 많은 현실에서는 100곳이 **한 자릿수 쿼리**로 줄어든다.

**관찰 2 — 검색에 `menuOverrides` 는 필요 없다.**
`menuOverrides` 가 바꾸는 것은 `priceOverride` / `excluded` / `soldOut` / 비활성 옵션이다. **메뉴 이름은 바꾸지 않는다** (`MenuOverrideModel` 에 `name` 필드가 없다 — 코드 확인). 검색은 이름만 매칭하므로 override 를 읽지 않아도 **매칭 결과는 동일**하다. 영향은 두 가지뿐이고 둘 다 설계로 제거한다.

| override 영향 | 제거 방법 |
|---|---|
| `priceOverride` 로 가격이 다를 수 있다 | **검색 결과에 가격을 표시하지 않는다** (§3.2). 가격은 매장 메뉴 화면이 정식 머지로 보여준다 |
| `excluded` 매장은 그 메뉴를 안 판다 | **결과 탭 → 매장 메뉴 화면으로 이동**한다 (메뉴 상세 직행 금지, §3.3). 매장 화면은 정식 머지를 수행하므로 없는 메뉴면 애초에 안 보인다 |

### 2.2 설계 — 출처 단위 1회 로드 + 세션 캐시 (Lazy Menu Index)

```
사용자가 검색창에 2글자 이상 입력 (debounce 250ms)
  ↓
매장 결과: 이미 메모리에 있는 매장 스냅샷에서 즉시 필터 → 바로 렌더 (추가 읽기 0)
  ↓                                       (메뉴 인덱스를 기다리지 않는다)
메뉴 인덱스 provider 가 처음 호출됨 (세션당 1회, keepAlive)
  ↓
후보 매장 = 스냅샷에서 거리 오름차순 상위 K(=30)곳, searchRadiusKm(=10km) 이내
  ↓
출처로 묶기
  - distinct brandId  → brands/{brandId}/menuItems  one-shot get()  (브랜드당 1회)
  - brandId == null   → stores/{storeId}/menuItems  one-shot get()  (매장당 1회)
  ↓
클라이언트 필터: status == approved && visible == true
  ↓
(브랜드 메뉴) × (그 브랜드의 후보 매장) 으로 전개 → MenuSearchHitEntity 목록
  ↓
메모리에 보관 (ref.keepAlive). 이후 모든 질의는 추가 읽기 0
```

**핵심 성질**

- 메뉴 읽기는 **검색을 실제로 시도한 사용자에게만, 세션당 1회** 발생한다. 홈 진입만으로는 0이다.
- stream 이 아니라 `get()` 이다. 상시 listener 를 만들지 않는다.
- `brandId` 판정을 위해 store doc 을 다시 읽지 않는다 — `StoreEntity.brandId` 가 스냅샷에 이미 있다.
- 쿼리 문장은 **기존 stream 과 완전히 동일**하다 (`orderBy('displayOrder')`). `where` 를 추가하지 않으므로 **새 인덱스가 필요 없다** (§8).

### 2.3 이 설계가 포기하는 것 (spec 에 남기는 한계)

> **2차 개정 결과**: **L2 해소**, **L5 해소**(품절을 표시한다), **L4 축소**(상세 화면이 실시간 데이터로 교정한다), **L1·L3 유지**. 재평가는 §15.9.

| # | 한계 | 사유 / 영향 |
|---|---|---|
| L1 | **가맹점의 점포 한정 메뉴(`scope=store` on 브랜드 매장)는 검색되지 않는다** | 이것까지 넣으면 브랜드 매장도 매장당 1쿼리가 되어 §2.1 관찰 1 의 이득이 사라진다. 점포 한정 메뉴는 전체 메뉴에서 소수이고, 매장 화면에서는 정상 노출된다. 해소는 §7 F2 |
| L2 | `excluded` 된 마스터 메뉴가 그 매장 결과로 뜰 수 있다 | 탭하면 매장 메뉴 화면으로 가고 거기엔 없다. 가격 미표시(§3.2)로 금전적 오인은 없다. 해소는 §7 F2 |
| L3 | 반경 10km · 상위 30곳 밖의 매장 메뉴는 검색되지 않는다 | 메뉴 섹션 하단에 범위 안내 문구를 고정 노출한다 (§3.2) |
| L4 | 세션 중 메뉴가 바뀌어도 반영되지 않는다 (스냅샷 캐시) | 메뉴 변경 빈도 대비 수용. pull-to-refresh / 화면 재진입 시 invalidate |
| L5 | 품절 메뉴도 결과에 뜬다 (`soldOut` 은 override 측) | 결과는 "이 매장이 이 메뉴를 판다" 까지만 보장한다. 매장 화면이 품절을 표시한다 |

### 2.4 왜 다른 안을 쓰지 않았는가

| 대안 | 기각 사유 |
|---|---|
| 매장별 `watchByStore` 전수 구독 | 최악 400 쿼리 + listener 300개. 사용자 판단대로 비현실적 |
| `collectionGroup('menuItems')` + `orderBy('name').startAt/endAt` 접두 검색 | (a) **접두사만** 매칭된다 — "아메리카노" 로 "아이스 아메리카노" 가 안 나온다. 한글 검색 기대와 정면 충돌 (b) `brands/*` 결과를 매장으로 전개하려면 brand→매장 역매핑이 또 필요 (c) collectionGroup 복합 인덱스 신규 필요 → **지난 배포 인덱스 누락 사고와 같은 위험** |
| `collectionGroup('menuOverrides').where('excluded','==',true)` 로 L2 해소 | collection **group** scope 단일 필드 인덱스를 새로 선언해야 한다. 인덱스 0개 원칙을 깨면서 얻는 것이 작다 |
| CF 가 `stores/{id}.menuSearchKeywords` 배열을 유지 (비정규화) | **장기적으로는 이게 정답이다.** 추가 읽기 0, 전개 불필요, L1·L2 전부 해소. 다만 CF 신규 + 백필 + 메뉴 쓰기 경로 전부에 트리거 필요 → 이번 과제 범위를 넘는다. §7 F2 로 승격 |

---

## 3. 요구사항

### 3.1 검색 진입 / 입력

- [ ] 홈 헤더 `_HomeSearchBox` 탭 → `SearchPage` push (`_showSearchComingSoon` 제거)
- [ ] **`_HomeSearchBox` 의 문구 `매장이나 메뉴 검색` 은 수정하지 않는다.** 홈의 박스는 편집 불가 탭 타겟으로 남기고, 실제 입력은 `SearchPage` 상단의 자체 입력창에서 받는다
- [ ] `SearchPage` 진입 시 입력창 autofocus + 키보드 즉시 표시
- [ ] 좌상단 뒤로가기, 입력창 우측 `×` (질의 초기화)
- [ ] 입력 debounce **250ms** 후 질의 반영 (주문 탭 `order_store_search` 와 동일)
- [ ] 질의 정규화: `trim` → 소문자화 → **공백 전부 제거**. 대상 문자열도 같은 규칙으로 정규화 후 `contains`
  - `아이스아메리카노` 로 `아이스 아메리카노` 가 잡히고 그 역도 잡힌다
- [ ] 매장 검색은 **1글자부터**, 메뉴 검색은 **2글자부터** 동작 (정규화 후 길이 기준)
- [ ] 최근 검색어: **세션 메모리** 최대 10건, 질의 비었을 때 노출, 탭하면 재검색, 개별 `×` 삭제 + `전체 삭제`. 앱 종료 시 사라진다 (영구 저장은 비범위)

### 3.2 검색 결과 화면

- [ ] 결과는 **섹션 2개**: `매장 (n)` → `메뉴 (n)` 순서. 한쪽이 0건이면 그 섹션 헤더까지 숨긴다
- [ ] **매장 섹션**
  - 대상 필드: `name` **+** `address` (§5.4 결정 D1)
  - 정렬: **이름 매칭이 주소 매칭보다 항상 위**. 같은 그룹 내에서는 거리 오름차순
  - 주소만 매칭된 항목은 카드에 매칭된 주소 한 줄을 보조 표기 (designer 판단)
  - 카드: 기존 `RecommendedStoreCard` **재사용** (`store_card.dart`)
  - 탭 → `StoreMenuPage(store: ...)` (기존 홈/주문 탭과 동일)
- [ ] **메뉴 섹션**
  - 대상 필드: `MenuItemEntity.name` 만 (`description` 은 비범위 — 노이즈)
  - 한 행 = (메뉴 1개 × 매장 1개). 같은 메뉴를 파는 매장이 여럿이면 **매장별로 각각 한 행**
  - 행 내용: 메뉴 이미지(없으면 placeholder) / 메뉴명 / `매장명 · 거리`
  - **가격을 표시하지 않는다** (§2.1 관찰 2)
  - 정렬: 거리 오름차순 → 같으면 메뉴명 가나다
  - 표시 상한 **30행** (초과 시 하단에 "검색 범위를 좁혀 보세요" 안내)
  - 섹션 하단 고정 안내: `가까운 매장 30곳의 메뉴에서 찾았습니다` (L3 를 사용자에게 알린다)
  - 탭 → **`StoreMenuPage`** (§3.3)
- [ ] 결과 화면에서 pull-to-refresh → 매장 스냅샷 + 메뉴 인덱스 둘 다 invalidate

### 3.3 메뉴 결과 탭 시 이동 (결정 D3) — **🚫 2차 개정으로 폐기. §15.8 을 따른다**

> 이 절의 "메뉴 상세 직행 금지" 는 **"안 파는 메뉴를 주문 가능한 것처럼 보여준다"** 는 전제에서 나왔다. §15.1 이 그 전제를 제거하므로 금지도 함께 사라진다. 아래는 이력이다.

- [ ] 메뉴 행 탭 → `StoreMenuPage(store: matchedStore)` 로 이동한다. **`MenuItemDetailPage` 직행은 금지한다**
  - 이유: `menuItemDetailProvider` → `watchById` 는 매장 서브컬렉션에 없으면 **브랜드 마스터로 폴백**한다. 즉 `excluded` 로 그 매장이 안 파는 메뉴도 상세가 열린다. 검색 인덱스가 머지 전 데이터이므로 직행은 "안 파는 메뉴를 주문 가능한 것처럼" 보여줄 수 있다
- [ ] 이동 시 매칭된 메뉴의 `mainCategoryCode` 를 넘겨 **해당 카테고리 탭이 선택된 상태**로 진입한다
  - `StoreMenuPage` 에 `initialMainCategoryCode` (nullable) 파라미터를 추가하고, 기존 호출부는 미지정(현행 동작 유지)
  - 해당 카드까지 **스크롤·하이라이트는 비범위** (후속 §7 F4)

### 3.4 추천 매장 더보기 (결정 D4)

- [ ] 홈 `맞춤 추천` 섹션은 **상위 5건만** 그린다 (현재 전체 → 미리보기로 변경)
- [ ] 섹션 헤더 카운트는 **전체 건수**를 유지한다 (`맞춤 추천 (23)` 인데 5건만 보이는 형태 — 더보기 동기가 생긴다)
- [ ] 전체 건수가 5 이하면 `전체보기` 버튼을 숨긴다
- [ ] `전체보기` 탭 → `RecommendedStoresPage` push (`_showComingSoon` 제거)
- [ ] `RecommendedStoresPage`
  - **홈과 동일한 기준의 전체 목록**이다 (같은 provider 를 공유 — 별개 추천 로직을 만들지 않는다)
  - 상단에 `CategoryFilterSection` 과 **동일한 카테고리 칩**을 노출하고 `selectedCategoriesProvider` 를 공유한다. 여기서 바꾸면 홈에도 반영된다 (스냅샷 공유 덕분에 추가 읽기 0)
  - 정렬 토글: `거리순`(기본, 현행 동작) / `등급순`(`averageScore` 내림차순, 동점이면 거리)
  - **페이징 없음.** 목록은 `fetchAll(limit:100)` 상한에 묶여 최대 100행이다. `ListView.builder` 로 충분하다 (§5.2)
  - 카드: `RecommendedStoreCard` 재사용. 탭 → `StoreMenuPage`

### 3.5 상태 요구사항

| 영역 | loading | error | empty |
|---|---|---|---|
| 매장 섹션 | 스냅샷 미도달 → shimmer 3행 (`recommended_stores_section.dart` 의 `_RecommendedLoading` 패턴 재사용) | 섹션 내 에러 + `다시 시도` → 스냅샷 invalidate | `'{질의}' 와 일치하는 매장이 없어요` |
| 메뉴 섹션 | 인덱스 빌드 중 → shimmer 2행 + `메뉴를 찾고 있어요`. **매장 섹션은 이미 렌더된 상태여야 한다** | **섹션만** 에러 + `다시 시도` → 메뉴 인덱스만 invalidate. 매장 결과는 그대로 유지 | `'{질의}' 와 일치하는 메뉴가 없어요` |
| 질의 0글자 | — | — | 최근 검색어 + `매장 이름, 주소, 메뉴로 찾아보세요` |
| 질의 1글자 | 매장 검색은 동작 | — | 메뉴 섹션 자리에 `메뉴는 두 글자부터 찾아요` |
| 양쪽 0건 | — | — | 섹션 분리 없이 통합 빈 상태 1개 (질의 echo + 범위 안내) |
| 추천 전체 화면 | shimmer | 재시도 | 카테고리 미일치 → 기존 `_EmptyRecommended` 문구 재사용 |
| 위치 권한 거부 | — | — | 기존 폴백(서울 시청) 그대로. 거리 표기는 폴백 기준이며 홈의 기존 SnackBar 안내가 이미 있다 |

---

## 4. 데이터 모델

### 4.1 Entity (신규 1개)

`lib/domain/entities/menu_search_hit_entity.dart` (freezed)

| 필드 | 타입 | 설명 |
|---|---|---|
| `menuItemId` | `String` | 메뉴 문서 ID (브랜드 마스터면 마스터 ID) |
| `menuName` | `String` | 표시용 원본 이름 |
| `menuImageUrl` | `String` | 없으면 `''` |
| `mainCategoryCode` | `String` | `StoreMenuPage.initialMainCategoryCode` 로 전달 |
| `storeId` | `String` | 매칭된 매장 |
| `storeName` | `String` | 표시용 |
| `distanceKm` | `double?` | 스냅샷의 값 그대로 |
| `source` | `MenuHitSource` | `brandMaster` / `storeOwn` — 디버깅·후속 F2 판단용 |

`MenuHitSource` 는 `lib/domain/entities/menu_search_hit_entity.dart` 안에 enum 으로 함께 둔다.

**가격 필드를 일부러 넣지 않는다.** 넣으면 override 미반영 가격이 UI 에 샐 수 있다 (§2.1).

> **🚫 2차 개정으로 뒤집힘.** override 를 읽게 되어 "틀릴 수 있다" 가 사라졌다. `basePrice` / `soldOut` 을 추가한다 — 근거와 조건은 **§15.5**.

### 4.2 DTO / Model

**신규 없음.** `StoreModel` / `MenuItemModel` / `MenuOverrideModel` 모두 무수정. 기존 `fromFirestore` 를 그대로 쓴다.

### 4.3 Firestore 스키마

**변경 없음.** 새 필드·새 컬렉션·마이그레이션 모두 없다. 이 기능은 **읽기 전용**이다.

---

## 5. 성능과 한계 (수치)

### 5.1 읽기 횟수 — before / after

매장 문서 1건을 **약 1.5KB** (name/address/imageUrls/businessHours/closedDates 포함 추정), 매장당 메뉴를 **20건**, 메뉴 문서 1건을 **약 0.5KB** 로 잡는다.

| 시나리오 | 현재 | 이 설계 적용 후 |
|---|---|---|
| 홈 진입 | **200 reads** (nearby 100 + filtered 100) | **100 reads** (스냅샷 1회) |
| 카테고리 칩 1회 토글 | **+100 reads** 매번 | **0 reads** |
| 카테고리 5회 토글한 세션 | 200 + 500 = **700 reads** | **100 reads** |
| 추천 전체보기 진입 | (불가) | **0 reads** (스냅샷 공유) |
| 매장만 검색 | (불가) | **0 reads** (스냅샷 공유) |
| 메뉴 검색 첫 시도 | (불가) | **+쿼리 1~30회 / 약 100~600 reads** (§5.2) |
| 같은 세션 두 번째 메뉴 검색 | (불가) | **0 reads** |

> 검색 기능을 **추가**하면서 홈의 읽기가 오히려 **200 → 100** 으로 줄고, 카테고리 토글의 100 reads 가 사라진다. 사용자 결정 "같은 데이터를 세 번 받아오지 않게" 가 이 표의 두 번째 열이다.

### 5.2 메뉴 인덱스 비용 (K = 30, 반경 10km)

| 후보 매장 구성 | 쿼리 수 | 문서 수 | 전송량 | 체감 |
|---|---|---|---|---|
| 전부 가맹점, 브랜드 3개 | **3** | 약 60 | 약 30KB | 0.3초 미만 |
| 가맹점 20(브랜드 3) + 개인 10 | **13** | 약 260 | 약 130KB | 0.5초 안팎 |
| 전부 개인 매장 30곳 (최악) | **30** | 약 600 | 약 300KB | 1.0~1.5초 |

병렬 `Future.wait` 기준. 최악 30쿼리는 Firestore 동시 연결로 흡수된다. **세션당 1회**이므로 사용자는 보통 첫 메뉴 검색에서만 이 지연을 본다.

### 5.3 클라이언트 필터링이 견디는 한계 — 수치

**CPU 는 전혀 문제가 아니다.** 100건 문자열 `contains` 는 0.1ms 미만, 1,000건도 1ms 미만이다. 먼저 깨지는 것은 두 곳이다.

| 지표 | 안전 | 주의 | 전환 필요 |
|---|---|---|---|
| **approved 매장 수** | ~300건 (약 450KB, 콜드 1초 미만) | 300~1,000건 (약 1.5MB, 콜드 2~4초) | **1,000건 초과** |
| 메뉴 인덱스 문서 수 | ~600건 | 600~2,000건 | **2,000건 초과** (세션당 1MB) |
| 메뉴 인덱스 쿼리 수 | ~30 | 30~60 | **60 초과** |

**그러나 가장 먼저 깨지는 것은 전송량이 아니라 정확성이다.**

> `fetchAll` 은 `limit(100)` 이다. **approved 매장이 101곳이 되는 순간, `averageScore` 하위 매장은 홈·주문 탭·검색 어디에서도 보이지 않는다.** 신규 매장은 `reviewCount == 0` → `averageScore == 0` 이라 정확히 이 절단선 아래로 떨어진다. 즉 **매장 101번째부터 "새로 승인된 매장이 검색되지 않는" 버그가 조용히 발생한다.**
>
> 이 절단은 이번 과제가 만든 것이 아니라 **이미 존재한다** (`getNearbyStores` / `getStoresByCategories` 가 둘 다 `limit:100`). 다만 검색을 붙이면 "검색했는데 있는 매장이 안 나온다" 로 사용자에게 드러난다.
>
> **전환 트리거: approved 매장 수가 80곳에 도달하면 §7 F1 을 착수한다.** (100 이 아니라 80 — 여유를 둔다)

주문 탭의 `orderBaseStoresProvider` 는 이번 통합 대상이 아니다 (별 화면·별 수명). 홈 통합 후에도 주문 탭 진입 시 100 reads 가 따로 발생한다. §7 F3.

### 5.4 한글 검색의 현실 — 무엇을 하고 무엇을 안 하는가

**하는 것**
- 부분 문자열 포함(`contains`) — `메리카` 로 `아메리카노` 가 잡힌다
- 대소문자 무시 — `ADE` ↔ `ade`
- **공백 무시** — `아이스 아메리카노` ↔ `아이스아메리카노`
- 매장 이름 + 주소

**하지 않는 것 (비범위 — 명시)**
- **초성 검색**: `ㅇㅇㅋ` → 아이스아메리카노 ❌. 자모 분해 라이브러리가 필요하고 오탐이 많다
- **오타 보정 / 편집거리**: `아메리카누` ❌
- **영↔한 혼용**: `americano` → 아메리카노 ❌, `ㅏㅡㄷ...` 자판 오입력 변환 ❌
- **동의어·약어**: `아아` → 아이스 아메리카노 ❌ (한국 카페 앱에서 체감이 큰 항목이다. §7 F5 에서 수동 별칭 테이블로 다룰 수 있다)
- **형태소 분석 / 어간 추출**

> `contains` 로 충분한가: **매장명·메뉴명 검색에는 충분하다.** 한국어 매장명·메뉴명은 짧고 사용자가 보이는 글자를 그대로 입력한다. 부족해지는 지점은 `아아` 같은 **구어 약어**이고, 이것은 검색 엔진을 바꿔도 해결되지 않는다(별칭 데이터 문제다). 따라서 "초성·오타 때문에 Algolia 가 필요하다" 는 추론은 성립하지 않는다 — §7 F5 참조.
- **주소 검색의 노이즈**: 주소가 `서울특별시 ...` 로 시작하므로 `서울` 두 글자면 거의 전 매장이 매칭된다. 그래서 (a) 이름 매칭을 항상 위로 정렬하고, (b) 섹션 헤더에 건수를 노출해 사용자가 범위를 인지하게 한다. 주소 매칭 자체를 끄는 선택지는 §9 D1.

---

## 6. 이력 / 감사 추적 (`audit_trail.md` §4 체크리스트)

| # | 항목 | 판정 |
|---|---|---|
| 1 | 돈 · 권한 · 정책 값을 바꾸는가? | **아니다.** 이 기능은 Firestore 에 **단 한 건도 쓰지 않는다.** `config` / `qoinAccrualRate` / `role` / `brandId` / 가격 / 승인 상태 어느 것도 건드리지 않는다. 따라서 **설정 변경 이력은 불필요하며, 그 사유는 "쓰기 경로가 아예 없음" 이다** |
| 2 | 덮어쓰기로 사라지는 값이 있는가? | **없다.** 읽기 전용. 새 필드·마이그레이션 없음 |
| 3 | 거래/기록 문서가 정책 값을 참조만 하는가? | 해당 없음(거래 문서를 만들지 않는다). 다만 **관련 위험을 설계로 차단했다** — 검색 결과에 `priceOverride` 미반영 가격을 띄우면 사용자가 그 가격으로 주문된다고 오인한다. 그래서 **가격을 아예 표시하지 않는다**(§2.1). 결제 시점 가격 박제는 기존 주문 흐름 책임이며 이 기능이 바꾸지 않는다 |
| 4 | "누가" 가 기록되는가? | 운영자 행위가 없다. 기록 대상 없음 |
| 5 | 일괄 처리(batch)가 있는가? | **없다.** 모든 Firestore 접근이 `get()` 읽기다. `WriteBatch` 미사용 |
| 6 | CF 로그에 의존하는가? | **아니다.** Cloud Function 을 쓰지도, 그 로그를 근거로 삼지도 않는다 |

**추가로 명시** — 검색어는 **수집하지 않는다.**
- 서버에 검색 질의를 쓰지 않는다 (`searchLogs` 류 컬렉션 없음). Analytics 이벤트도 보내지 않는다.
- 최근 검색어는 **단말 세션 메모리**에만 있고 앱을 닫으면 사라진다.
- 인기 검색어 / 검색 전환율 같은 기능은 **검색어를 개인과 묶어 서버에 쌓는 결정**이므로, 필요해지면 별도 task 에서 개인정보 판단과 함께 설계한다. 이번 spec 은 그 문을 열지 않는다.

`role_flows.md`: customer 의 **탐색(진입) 흐름 안쪽**에만 끼어든다. 역할 전이 없음, 신규 진입 경로 없음.
`entity_lifecycle.md`: **status 전이를 하나도 유발하지 않는다.** `order` / `store` / `brand` / `menuItem` / `refund` 모두 무관. 단, 검색은 `status == approved` 매장·메뉴만 노출한다는 **읽기 측 게이트를 지킨다** (`StoreRepositoryImpl._filterApproved` 와 동일 규칙).
`data_ownership.md`: 소유권·권한 매트릭스 변경 없음. CF 신규 없음. 모든 읽기가 기존 `allow read: if isSignedIn()` 안에서 이뤄진다 (`stores`, `stores/{id}/menuItems`, `brands/{id}/menuItems` 모두 확인).

---

## 7. 후속 과제 (한계를 넘었을 때 무엇으로 바꾸는가)

| # | 과제 | 착수 트리거 | 내용 |
|---|---|---|---|
| **F1** | **`fetchAll(limit:100)` 절단 해소** | **approved 매장 80곳** | 가장 급한 후속이다. (a) 1차: `where('status','==','approved')` 서버 필터 + `limit` 상향 — 복합 인덱스 신규 필요 (b) 2차: Geohash 반경 쿼리로 전환 (`store_remote_data_source.dart` 주석이 이미 예고). **Algolia 보다 먼저 와야 한다** |
| **F2** | 메뉴 검색 키워드 비정규화 (CF) | 메뉴 인덱스 쿼리 60 초과, 또는 L1·L2 민원 발생 | CF 가 마스터·점포한정·override 를 머지해 `stores/{id}.menuSearchKeywords: string[]` 를 유지. 메뉴 검색이 **추가 읽기 0** 이 되고 L1(점포 한정 미검출)·L2(excluded 오출현)가 동시에 사라진다. 백필 + 메뉴·override 쓰기 경로 전체 트리거 필요 |
| **F3** | 주문 탭 스냅샷 통합 | 언제든 (소) | `orderBaseStoresProvider` 를 공유 스냅샷 파생으로 교체 → 주문 탭 진입 100 reads 제거 |
| **F4** | 메뉴 결과 → 해당 카드 스크롤·하이라이트 | UX 요청 시 (소) | `StoreMenuPage` 에 `initialMenuItemId` 추가 + `GlobalKey`/`Scrollable.ensureVisible` + 1회 강조 애니메이션 |
| **F5** | 메뉴 별칭 테이블 | `아아` 류 민원 | `mainCategories` 또는 신규 `searchAliases` 컬렉션에 `별칭 → 정식 메뉴명` 수동 매핑. **검색 엔진 교체보다 효과가 크고 비용이 낮다** |
| **F6** | 외부 검색 엔진 (Algolia / Typesense) | F1·F2·F5 를 다 하고도 부족할 때 | 초성·오타·형태소까지 필요해지는 시점. 사용자 판단 "지금 단계엔 과하다" — **이번 범위 아님** |
| **F7** | 최근 검색어 영구 저장 | 언제든 (소) | `shared_preferences` 도입 필요 (현재 pubspec 에 없음) |

---

## 8. 필요한 Firestore 인덱스 / Rules

### 8.1 인덱스

> **신규 인덱스: 0건. `firestore.indexes.json` 을 수정하지 않는다.**

근거 — 이 기능이 날리는 쿼리 전부:

| 쿼리 | 어디서 | 인덱스 |
|---|---|---|
| `stores orderBy averageScore desc limit 100` | `StoreRemoteDataSource.fetchAll` (기존 재사용) | 단일 필드 — **자동** |
| `stores/{id}/menuItems orderBy displayOrder` | 신규 one-shot. **기존 `streamByStore` 와 동일 문장** | 단일 필드 — **자동** |
| `brands/{id}/menuItems orderBy displayOrder` | 신규 one-shot. **기존 `streamByBrand` 와 동일 문장** | 단일 필드 — **자동** |

`status` / `visible` 필터는 **전부 클라이언트에서** 한다. 문서 수가 거의 같아 비용 차이가 없고, 서버 `where` 를 붙이면 `menuItems` 복합 인덱스가 새로 필요해진다.

### 8.2 developer 에게 주는 강제 조건 (지난 인덱스 누락 사고 재발 방지)

- [ ] 신규 메뉴 one-shot 쿼리에 **`where` 를 추가하지 않는다.** `orderBy('displayOrder')` 만 쓴다
- [ ] **`collectionGroup` 쿼리를 쓰지 않는다**
- [ ] 위를 어기게 되면 → `firestore.indexes.json` 에 복합 인덱스를 추가하고 **`firebase deploy --only firestore:indexes` 를 앱 배포보다 먼저** 수행한 뒤, 그 사실을 `implementation.md` 에 적는다
- [ ] tester 는 **인덱스 에러(`failed-precondition`)가 콘솔에 찍히지 않음**을 명시적으로 확인한다

### 8.3 Security Rules

> **`firestore.rules` 수정 없음.** 읽는 경로 전부가 이미 `allow read: if isSignedIn()` 이다.

- `stores/{storeId}` — line 294 `allow read: if isSignedIn()`
- `stores/{storeId}/menuItems/{id}` — line 407 `allow read: if isSignedIn()`
- `brands/{brandId}/menuItems/{id}` — line 501 `allow read: if isSignedIn()`

**단, 비로그인 사용자는 검색할 수 없다.** 이것은 이 기능의 제약이 아니라 기존 Rules 그대로다 (홈의 매장 목록도 로그인 전에는 뜨지 않는다). 비로그인 분기를 새로 만들지 않는다.

---

## 9. 레이어 설계

### 9.1 Domain

**Entity (신규 1)**
- `lib/domain/entities/menu_search_hit_entity.dart` — `MenuSearchHitEntity` (freezed) + `MenuHitSource` enum

**UseCase**
- `lib/domain/usecases/get_approved_stores_use_case.dart` **(신규)** — `call({required UserLocation location, int limit = 100})` → 스냅샷 1회 조회
- `lib/domain/usecases/search_stores_use_case.dart` **(신규)** — **순수 compute static**. `SearchStoresUseCase.compute({required List<StoreEntity> stores, required String normalizedQuery})` → 이름 매칭 그룹 + 주소 매칭 그룹을 순서대로 이어 반환. I/O 없음
- `lib/domain/usecases/search_menu_items_use_case.dart` **(신규)** — 두 부분
  - `Future<List<MenuSearchHitEntity>> buildIndex({required List<StoreEntity> candidateStores})` — 출처 묶기 + 병렬 fetch + 전개 (§2.2)
  - `static List<MenuSearchHitEntity> filter({required List<MenuSearchHitEntity> index, required String normalizedQuery, int limit = 30})` — 순수 compute
- 기존 `GetNearbyStoresUseCase` / `GetStoresByCategoriesUseCase` 에 **순수 static 보조 메서드 추가**
  - `GetNearbyStoresUseCase.withinRadius(stores, radiusKm, limit)`
  - `GetStoresByCategoriesUseCase.filterByCategories(stores, categories)`
  - 두 메서드의 필터·정렬 규칙은 현재 Repository 구현과 **동일해야 한다.** 기존 `call()` 은 주문 탭 호환을 위해 그대로 남긴다
  - 선례: `GetFrequentStoresUseCase.compute` / `GetFrequentMenuItemsUseCase.compute` 가 이미 같은 패턴이다

> compute 를 UseCase 의 static 으로 두는 이유: 필터·정렬은 **비즈니스 규칙**이므로 domain 에 있어야 하고, **캐시는 수명 관리**이므로 presentation(Riverpod) 에 있어야 한다. 이 분리를 어기면 Repository 에 캐시가 들어가 마이그레이션 때 걸림돌이 된다.

**Repository Interface**
- `lib/domain/repositories/store_repository.dart` — 추가
  - `Future<List<StoreEntity>> getApprovedStores({required UserLocation location, int limit});`
    - `status == approved` 필터 + 거리 계산 + 거리 오름차순. **반경 제한·카테고리 제한 없음.** 기존 두 메서드와 동일한 `_filterApproved` / `_attachDistance` 를 재사용한다
- `lib/domain/repositories/menu_item_repository.dart` — 추가
  - `Future<List<MenuItemEntity>> fetchStoreMenusOnce(String storeId);`
- `lib/domain/repositories/master_menu_item_repository.dart` — 추가
  - `Future<List<MenuItemEntity>> fetchBrandMasterMenusOnce(String brandId);`

> 기존 `getNearbyStores` / `getStoresByCategories` 는 **삭제하지 않는다** (주문 탭이 쓴다). `@Deprecated` 도 붙이지 않는다 — F3 에서 정리한다.

### 9.2 Data

**DataSource**
- `store_remote_data_source.dart` — **무수정.** `fetchAll(limit:100)` 그대로 재사용
- `menu_item_remote_data_source.dart` — 추가
  - `Future<List<MenuItemModel>> fetchByStore(String storeId)` — `_menuItems(storeId).orderBy('displayOrder').get()`. **`streamByStore` 와 같은 문장의 one-shot 판**
- `master_menu_item_remote_data_source.dart` — 추가
  - `Future<List<MenuItemModel>> fetchAllByBrand(String brandId)` — `_menuItemsCol(brandId).orderBy('displayOrder').get()`. **`streamByBrand` 와 같은 문장의 one-shot 판**

**Repository Implementation**
- `store_repository_impl.dart` — `getApprovedStores` 구현. 기존 private 헬퍼(`_filterApproved` / `_attachDistance`) 재사용. **기존 두 메서드의 동작은 1바이트도 바꾸지 않는다**
- `menu_item_repository_impl.dart` — `fetchStoreMenusOnce` 구현 (단순 위임 + `toEntity`). **머지(`_mergeForBrandStore`)를 타지 않는다.** override 를 읽지 않는 것이 §2.1 의 설계 의도다
- `master_menu_item_repository_impl.dart` — `fetchBrandMasterMenusOnce` 구현

**status / visible 필터 위치**: `SearchMenuItemsUseCase.buildIndex` (domain). Repository 는 원본을 그대로 돌려준다 — 기존 `watchByStore` 가 case A 에서 필터를 안 하고 customer 측 provider 가 거르는 것과 같은 관례를 따른다.

### 9.3 Presentation

**Core util (신규)**
- `lib/core/utils/search_normalizer.dart`
  - `String normalize(String raw)` — `trim` → `toLowerCase` → 모든 공백 제거
  - `bool matches(String target, String normalizedQuery)` — `normalize(target).contains(normalizedQuery)`
  - 순수 Dart. Flutter 의존 금지. 매장·메뉴 양쪽이 **반드시 이 하나만** 쓴다

**`home_providers.dart` 구조 변경 (핵심 — 세 번 받아오지 않게)**

```dart
// 신규 — 홈 전체가 공유하는 단 하나의 매장 스냅샷
final storeSnapshotProvider = FutureProvider<List<StoreEntity>>((ref) async {
  final location = await ref.watch(userLocationProvider.future);
  return ref.watch(getApprovedStoresUseCaseProvider)(location: location);
});

// 변경 — FutureProvider → 스냅샷 파생 Provider<AsyncValue<...>>
final nearbyStoresProvider   = /* storeSnapshotProvider + GetNearbyStoresUseCase.withinRadius */;
final filteredStoresProvider = /* storeSnapshotProvider + GetStoresByCategoriesUseCase.filterByCategories */;
```

- `filteredStoresProvider` 가 `selectedCategoriesProvider` 를 watch 하더라도 **재조회가 발생하지 않는다** (파생 compute 뿐). 카테고리 토글 100 reads 가 사라지는 지점이다
- **`AsyncValue` 를 반환하는 형태는 유지한다.** 두 provider 의 **타입이 `FutureProvider` → `Provider<AsyncValue<List<StoreEntity>>>` 로 바뀐다.** 구독 측 `.when(...)` 코드는 그대로 동작하지만 **`ref.invalidate` 대상이 달라진다**
- `recommendation_providers.dart` 의 `storesByIdProvider` 는 `nearbyStoresProvider`(반경 20km 제한) 대신 **`storeSnapshotProvider`** 를 보게 바꾼다 → 자주 찾는 매장이 20km 밖이어서 lookup 이 실패하던 경우가 줄어든다 (부수 개선)
- `home_page.dart` `_onRefresh` 의 `ref.invalidate(nearbyStoresProvider)` / `invalidate(filteredStoresProvider)` 를 **`ref.invalidate(storeSnapshotProvider)` 1개로** 교체
- `recommended_stores_section.dart` / `nearby_stores_section.dart` 의 에러 UI 재시도 버튼도 `storeSnapshotProvider` invalidate 로 교체

**신규 provider 파일**
- `lib/presentation/customer/search/providers/search_providers.dart`
  - `searchQueryProvider` — `NotifierProvider<String>` (debounce 적용 후 값). `set` / `clear`
  - `normalizedQueryProvider` — `Provider<String>` (`SearchNormalizer.normalize`)
  - `searchStoreResultsProvider` — `Provider<AsyncValue<List<StoreEntity>>>` ← 스냅샷 + `SearchStoresUseCase.compute`
  - `menuSearchIndexProvider` — `FutureProvider<List<MenuSearchHitEntity>>`
    - 내부에서 `ref.keepAlive()` 호출 (세션 캐시)
    - **`normalizedQuery.length >= 2` 일 때만 호출되도록 UI 가 게이트한다.** provider 자신은 질의를 모른다 (질의가 바뀔 때마다 재빌드되면 캐시 의미가 없다)
    - 후보 = 스냅샷에서 `distanceKm <= searchRadiusKm` 중 상위 `menuSearchStoreLimit` 곳
  - `menuSearchResultsProvider` — `Provider<AsyncValue<List<MenuSearchHitEntity>>>` ← 인덱스 + `SearchMenuItemsUseCase.filter`
  - `recentSearchesProvider` — `NotifierProvider<List<String>>` (세션 메모리, 최대 10, 중복은 맨 앞으로 끌어올림)
- `lib/presentation/customer/home/providers/recommended_stores_providers.dart`
  - `recommendedSortProvider` — `NotifierProvider<RecommendedSort>` (`distance` / `grade`)
  - `recommendedStoresFullProvider` — `Provider<AsyncValue<List<StoreEntity>>>` ← `filteredStoresProvider` + 정렬
  - `recommendedStoresPreviewProvider` — `Provider<AsyncValue<List<StoreEntity>>>` ← full 의 `take(5)`

**Page (신규 2)**
- `lib/presentation/customer/search/search_page.dart`
- `lib/presentation/customer/home/recommended_stores_page.dart`

**Widget**
- 신규 `lib/presentation/customer/search/widgets/search_input_bar.dart` — 실제 입력창 (홈의 `_HomeSearchBox` 와 톤 일치, 문구는 홈과 동일하게 `매장이나 메뉴 검색`)
- 신규 `lib/presentation/customer/search/widgets/menu_search_result_tile.dart`
- **재사용**: `RecommendedStoreCard` (`home/widgets/store_card.dart`) — 매장 결과·추천 전체 양쪽
- **재사용**: `SectionTitle` (`home/widgets/section_title.dart`) — 섹션 헤더 + 건수
- **재사용**: `CategoryFilterSection` (`home/widgets/category_filter_section.dart`) — 추천 전체 화면 상단
- **재사용**: shimmer 로딩·에러·빈 상태 패턴 (`recommended_stores_section.dart` 내부 private 위젯) — 공용화 여부는 developer 판단. 공용화하면 `search/widgets/` 가 아니라 `presentation/common/` 으로 올린다

**수정**
- `home_header.dart` — `_showSearchComingSoon` 삭제, `SearchPage` push. **`_HomeSearchBox` 의 문구·스타일 무수정**
- `recommended_stores_section.dart` — `_showComingSoon` 삭제, `RecommendedStoresPage` push, preview provider 로 교체, 5건 초과일 때만 `전체보기` 노출
- `store_menu_page.dart` — `initialMainCategoryCode` nullable 파라미터 추가 (기존 호출부 미지정 → 현행 동작 유지)

**상수**
- `lib/core/constants/grade_thresholds.dart` 에 추가
  - `static const double searchRadiusKm = 10.0;`
  - `static const int menuSearchStoreLimit = 30;`
  - `static const int menuSearchResultLimit = 30;`
  - `static const int recommendedPreviewCount = 5;`
  - `static const int recentSearchLimit = 10;`
  - `static const int searchDebounceMs = 250;`
  - `static const int menuSearchMinQueryLength = 2;`
  > 상수는 전부 이 파일 한 곳에 둔다. 리터럴을 위젯에 흩뿌리면 §5.3 전환 트리거를 코드에서 찾을 수 없게 된다

### 9.4 레이어 규칙 점검

- [x] `presentation → domain ← data` 유지. 신규 provider 는 UseCase 만 호출한다
- [x] `domain` 순수 Dart. `MenuSearchHitEntity` 는 freezed 만, Firebase import 없음
- [x] Firebase SDK 는 두 DataSource 의 one-shot 메서드 안에만 있다
- [x] 색상은 `AppColors` 만. `Color(0x...)` 금지
- [x] 하드코딩 secret 없음 (네트워크 설정 변경 없음)
- [x] 기존 구조 재사용: `RecommendedStoreCard` / `SectionTitle` / `CategoryFilterSection` / `_filterApproved` / `_attachDistance` / `compute` static 선례

---

## 10. 데이터 흐름

```
[검색]
SearchPage 입력 (debounce 250ms)
  → searchQueryProvider → normalizedQueryProvider (SearchNormalizer)
  │
  ├─ 매장 (추가 읽기 0) ─────────────────────────────────────────────
  │    storeSnapshotProvider ─ (이미 홈에서 로드됨)
  │      → SearchStoresUseCase.compute(stores, q)   [domain, 순수]
  │      → searchStoreResultsProvider → 매장 섹션 렌더
  │
  └─ 메뉴 (q 길이 >= 2 일 때만, 세션 1회) ───────────────────────────
       menuSearchIndexProvider  (ref.keepAlive)
         → 후보 = 스냅샷 거리 <= 10km 상위 30곳
         → SearchMenuItemsUseCase.buildIndex(candidateStores)
             ├─ distinct brandId → MasterMenuItemRepository.fetchBrandMasterMenusOnce
             │                      → MasterMenuItemRemoteDataSource.fetchAllByBrand
             │                      → brands/{brandId}/menuItems .orderBy(displayOrder).get()
             └─ brandId == null  → MenuItemRepository.fetchStoreMenusOnce
                                    → MenuItemRemoteDataSource.fetchByStore
                                    → stores/{storeId}/menuItems .orderBy(displayOrder).get()
         → approved && visible 필터 → 브랜드 메뉴를 해당 브랜드 후보 매장에 전개
         → List<MenuSearchHitEntity>
       → SearchMenuItemsUseCase.filter(index, q, limit:30)   [순수]
       → menuSearchResultsProvider → 메뉴 섹션 렌더

매장 결과 탭 → StoreMenuPage(store)
메뉴 결과 탭 → StoreMenuPage(store, initialMainCategoryCode: hit.mainCategoryCode)

[추천 전체보기]
RecommendedStoresSection 전체보기
  → RecommendedStoresPage
  → recommendedStoresFullProvider
       ← filteredStoresProvider (= storeSnapshotProvider 파생, 추가 읽기 0)
       + recommendedSortProvider (거리순 / 등급순)
  → RecommendedStoreCard 리스트 → StoreMenuPage

[스냅샷 1회]
userLocationProvider (확정)
  → storeSnapshotProvider
  → GetApprovedStoresUseCase
  → StoreRepository.getApprovedStores
  → StoreRepositoryImpl (approved 필터 + 거리 계산 + 거리 정렬)
  → StoreRemoteDataSource.fetchAll(limit:100)
  → Firestore  stores .orderBy(averageScore desc).limit(100)

  파생: nearbyStoresProvider / filteredStoresProvider / searchStoreResultsProvider
       / menuSearchIndexProvider 후보 / storesByIdProvider / recommendedStores*
```

---

## 11. 에러 처리

| 케이스 | 처리 |
|---|---|
| 스냅샷 조회 실패 (네트워크) | 검색·추천 양쪽에서 섹션 에러 + `다시 시도` → `storeSnapshotProvider` invalidate |
| 메뉴 인덱스 **일부** 출처 실패 | `Future.wait` 대신 **출처별로 실패를 흡수**한다. 성공한 출처의 결과만으로 섹션을 그리고, 실패가 1건 이상이면 섹션 하단에 `일부 매장의 메뉴를 불러오지 못했어요` + `다시 시도`. **한 매장의 실패로 메뉴 검색 전체를 죽이지 않는다** |
| 메뉴 인덱스 **전체** 실패 | 메뉴 섹션만 에러 + 재시도. **매장 섹션은 정상 유지** |
| 인덱스 누락(`failed-precondition`) | 이 설계에서는 발생할 수 없다(§8). 발생하면 §8.2 를 어긴 것이다. developer 는 `debugPrint` 로 쿼리와 에러를 남긴다 |
| 권한 거부(`permission-denied`) | 비로그인 상태다. `로그인이 필요해요` + 로그인 유도 (기존 `LoginPage` 흐름 재사용) |
| 위치 권한 거부 | 폴백(서울 시청) 기준 거리로 동작. 기존 홈 SnackBar 안내 유지. **검색 자체는 막지 않는다** |
| 질의가 공백뿐 | 정규화 결과 빈 문자열 → 질의 0글자와 동일 처리 |
| 결과 0건 | §3.5 의 빈 상태 |
| 검색 중 화면 이탈 | provider `autoDispose` 로 입력 상태는 폐기. **`menuSearchIndexProvider` 는 `keepAlive` 라 남는다** (재진입 시 즉시 결과) |

---

## 12. 작업 분배

### designer (먼저)

**UI 변경 있음 — 신규 화면 2개.** 산출물: `docs/tasks/home_search/design.md`

전달할 사항:
- **`_HomeSearchBox` 의 문구 `매장이나 메뉴 검색` 은 바꾸지 않는다.** `SearchPage` 입력창도 같은 문구를 쓴다
- `SearchPage`: 상단 입력창(autofocus, `×`) + 뒤로가기. 결과는 `매장 (n)` / `메뉴 (n)` 2섹션
- 메뉴 결과 행 디자인 — 메뉴 이미지 / 메뉴명 / `매장명 · 거리`. **가격 자리를 만들지 말 것** (§2.1 — 디자인에 자리를 만들면 구현이 채우려 한다)
- 메뉴 섹션 하단 범위 안내 문구(`가까운 매장 30곳의 메뉴에서 찾았습니다`) 배치
- 상태 UI 전부: 질의 0글자(최근 검색어) / 1글자 / 매장 로딩·에러·빈 / 메뉴 로딩·부분실패·에러·빈 / 양쪽 0건 통합 빈 상태
- **매장 결과는 나오고 메뉴는 아직 로딩인 중간 상태**의 레이아웃 (가장 흔한 상태다 — 반드시 그릴 것)
- 최근 검색어 칩/리스트 + 개별 삭제 + 전체 삭제
- `RecommendedStoresPage`: AppBar + 카테고리 칩 + 정렬 토글(`거리순`/`등급순`) + 카드 리스트
- 홈 `맞춤 추천` 섹션의 **5건 미리보기** 형태. 헤더는 전체 건수를 보이는데 5건만 그려지는 상태의 시각적 처리(하단 그라데이션 / `전체보기` 강조 등)
- 재사용 확정: `RecommendedStoreCard`, `SectionTitle`, `CategoryFilterSection`, shimmer 패턴
- 색상은 `AppColors` 만

### developer (design 확정 후)

**구현 항목**
1. `core/utils/search_normalizer.dart`
2. `grade_thresholds.dart` 상수 7개 추가
3. `MenuSearchHitEntity` + `MenuHitSource` (freezed → `dart run build_runner build --delete-conflicting-outputs`)
4. Repository Interface 3개 메서드 + Impl 3개
5. DataSource one-shot 2개 (**기존 stream 과 같은 쿼리 문장**)
6. UseCase 3개 신규 + 기존 2개에 static compute 추가
7. `home_providers.dart` 스냅샷 구조 전환 + 파생 provider 2개
8. `search_providers.dart` / `recommended_stores_providers.dart`
9. `SearchPage` / `RecommendedStoresPage` + 위젯
10. `home_header.dart` / `recommended_stores_section.dart` / `nearby_stores_section.dart` / `home_page.dart` 수정
11. `store_menu_page.dart` `initialMainCategoryCode` 추가

**재사용할 기존 구조**
- `StoreRemoteDataSource.fetchAll` 무수정 재사용
- `StoreRepositoryImpl._filterApproved` / `_attachDistance` 재사용 — 필터 규칙을 다시 쓰지 말 것
- `GetFrequentStoresUseCase.compute` 의 "순수 compute static" 패턴
- `order_providers.dart` 의 debounce·`AsyncValue.whenData` 필터 패턴
- `RecommendedStoreCard` / `SectionTitle` / `CategoryFilterSection` / shimmer

**주의할 레이어 규칙 / 함정**
- `menuSearchIndexProvider` 는 **질의를 watch 하지 않는다.** watch 하면 타이핑마다 재빌드되어 §5.2 비용이 매 글자 발생한다. 질의 게이트는 UI 에서
- `fetchStoreMenusOnce` / `fetchBrandMasterMenusOnce` 는 **머지를 타지 않는다.** `menuOverrides` 를 읽으면 §2.1 의 이득이 사라진다
- `nearbyStoresProvider` / `filteredStoresProvider` 의 **타입이 `FutureProvider` → `Provider<AsyncValue<...>>` 로 바뀐다.** `ref.invalidate` 호출부(`home_page.dart` `_onRefresh`, 두 섹션의 재시도 버튼)를 **전부** `storeSnapshotProvider` 로 고쳐야 한다. 안 고치면 당겨서 새로고침이 조용히 동작하지 않는다
- `where` 금지 / `collectionGroup` 금지 (§8.2)
- 정렬·필터는 `SearchNormalizer` **하나만** 쓴다. 위젯에서 `toLowerCase().contains()` 를 직접 쓰지 말 것
- 가격을 `MenuSearchHitEntity` 에 넣지 말 것
- `flutter analyze` 무경고 + `flutter test` 통과

산출물: 코드 + `docs/tasks/home_search/implementation.md`

### tester

**주요 검증 기준**
- 홈 검색창 탭 → `SearchPage` 진입, autofocus, 문구가 `매장이나 메뉴 검색` 그대로인지
- 매장 검색: 이름 부분 일치 / 주소 일치 / **이름 매칭이 주소 매칭보다 위**인지 / 공백 무시(`아이스 아메리카노` ↔ `아이스아메리카노`) / 1글자 동작
- 메뉴 검색: 2글자 게이트 / **가맹점 매장의 마스터 메뉴가 나오는지** / **개인 매장 메뉴가 나오는지** / 같은 메뉴를 파는 매장이 여럿일 때 매장별 행으로 나오는지
- **메뉴 결과에 가격이 없는지** (있으면 FAIL)
- 메뉴 결과 탭 → 매장 메뉴 화면 + 해당 카테고리 탭 선택됨. **메뉴 상세로 직행하지 않는지** (직행하면 FAIL)
- 추천: 홈이 5건만 그리는지 / 헤더 카운트는 전체인지 / 5건 이하일 때 `전체보기` 숨는지 / 전체 화면이 홈과 같은 목록인지 / 카테고리 칩이 홈과 동기화되는지 / 정렬 토글 동작
- 상태 UI 전부 (§3.5 표 그대로)

**반드시 확인할 예외 케이스**
- **읽기 횟수 회귀 검증 (이 과제의 핵심 지표)**: Firestore 사용량 또는 `debugPrint` 계측으로
  - 홈 진입이 **100 reads 1회**인지 (200 이면 FAIL)
  - **카테고리 칩 토글이 추가 읽기 0 인지** (100 reads 발생하면 FAIL)
  - 추천 전체보기 진입이 **추가 읽기 0** 인지
  - 매장만 검색할 때 **추가 읽기 0** 인지
  - 메뉴 검색 **첫 시도에만** 읽기가 발생하고, 같은 세션 두 번째 질의는 0 인지
- **인덱스 에러 부재**: 콘솔에 `failed-precondition` / `The query requires an index` 가 **한 번도** 찍히지 않는지. 메뉴 검색을 가맹점·개인 매장 둘 다 포함된 상태로 실행해 확인
- 당겨서 새로고침 후 목록·검색 결과가 실제로 갱신되는지 (provider 타입 변경 누락 탐지)
- 비로그인 상태 진입 → `permission-denied` 가 에러 UI 로 처리되는지 (raw 예외 노출 FAIL)
- 위치 권한 거부 → 폴백 거리로 검색 동작, 거리 `-` 표기 깨지지 않는지
- 메뉴 인덱스 **일부 실패**: 네트워크를 중간에 끊어 일부 출처만 실패시켰을 때 **성공분이 그려지고 매장 섹션이 살아 있는지**
- 승인되지 않은 매장(`pending`/`rejected`)과 `status != approved` / `visible == false` 메뉴가 **결과에 절대 안 나오는지**
- 한글 비범위 확인: 초성(`ㅇㅇㅋ`) · 오타 · 영한 혼용(`americano`) 이 **안 나오는 것이 정상**임을 FAIL 로 적지 말 것 (§5.4)
- `flutter analyze` / `flutter test`

산출물: `docs/tasks/home_search/test_report.md`

---

## 13. 사용자 확인이 필요한 결정사항

설계상 확정했으나 사용자가 뒤집을 수 있는 항목이다. 특히 **D4 는 홈의 현재 동작을 바꾼다.**

| # | 결정 | 선택지 | spec 채택 (권장) |
|---|---|---|---|
| **D1** | 매장 검색 대상 필드 | (a) 이름만 (b) **이름 + 주소, 이름 우선 정렬** | **(b)**. 비용 0, `강남` 같은 지명 질의를 받는다. 대신 `서울` 2글자가 거의 전부를 매칭하는 노이즈를 감수한다(§5.4). 노이즈가 싫으면 (a) 로 내리면 되고, 코드 변경은 compute 한 줄이다 |
| **D2** | 메뉴 검색 후보 범위 | (a) 10km / 30곳 (b) 5km / 15곳 (c) 20km / 50곳 | **(a)**. 최악 30쿼리·600 reads·1.5초(§5.2). 상수 1개로 바꿀 수 있게 격리했다 |
| **D3** | 메뉴 결과 탭 목적지 | (a) **매장 메뉴 화면 + 카테고리 탭 선택** (b) 매장 화면 + 해당 카드로 스크롤·하이라이트 (c) 메뉴 상세 직행 | **(a)**. (c) 는 `excluded` 메뉴를 주문 가능한 것처럼 보여줄 수 있어 **채택하지 않는다**(§3.3). (b) 는 UX 가 더 좋지만 작업량이 늘어 F4 로 미뤘다 — **지금 (b) 로 올리라고 하면 범위에 넣을 수 있다** |
| **D4** | **홈 `맞춤 추천` 을 5건 미리보기로 줄인다** | (a) **홈 5건 + 전체보기** (b) 홈은 지금처럼 전체, 전체보기는 정렬/필터가 추가된 별도 화면 (c) 홈 10건 | **(a)**. 지금 홈 섹션은 이미 전체 목록이어서(§1.2) 줄이지 않으면 `전체보기` 가 의미 없다. **홈 스크롤 길이가 짧아지는 체감 변화가 생긴다** — 이 변화를 원치 않으면 (b) 다 |
| **D5** | 최근 검색어 저장 범위 | (a) **세션 메모리** (b) `shared_preferences` 영구 저장 | **(a)**. (b) 는 **신규 패키지 도입**이 필요하다(현재 pubspec 에 없음). 영구 저장을 원하면 F7 로 분리하는 편이 안전하다 |
| **D6** | 주문 탭 스냅샷 통합을 이번에 할지 | (a) **안 한다 (F3)** (b) 같이 한다 | **(a)**. 주문 탭은 반경·상한이 다르고(`10km`/`50`) 자체 등급 필터가 있어 회귀 범위가 커진다. 통합하면 주문 탭 진입 100 reads 가 추가로 사라진다 — **같이 하라고 하면 작업량 소(小)다** |
| **D7** | `fetchAll(limit:100)` 절단(F1)을 이번에 손댈지 | (a) **후속 (approved 매장 80곳 트리거)** (b) 지금 `where status==approved` + limit 상향 | **(a)**. (b) 는 **복합 인덱스 신규 배포**가 필요해 "인덱스 0건" 원칙과 충돌한다. 다만 **이것이 §5.3 의 가장 먼저 깨지는 지점**이므로 트리거를 수치로 못 박아 뒀다 |

---

## 14. 완료 기준

- [ ] 요구사항(§3)이 모두 구현되었거나 보류 사유가 명시됨
- [ ] `design.md` 작성 완료 (UI 변경 있음 — 생략 불가)
- [ ] `implementation.md` 작성 완료
- [ ] `test_report.md` 작성 완료
- [ ] 홈 `준비 중` SnackBar **2건이 코드에서 사라짐** (`home_header.dart` / `recommended_stores_section.dart`)
- [ ] `docs/backlog.md` "진입점만 있고 동작 없음" 표 2행이 **완료 처리**되고, F1~F7 이 backlog 에 등재됨
- [ ] `firestore.indexes.json` / `firestore.rules` **무수정** 확인 (수정했다면 §8.2 절차를 밟았음을 implementation.md 가 증명)
- [ ] 읽기 횟수 회귀 검증 통과 (§12 tester 핵심 지표)
- [ ] `flutter analyze` 무경고 / `flutter test` 통과
- [ ] FAIL 항목 없음 또는 후속 과제로 분리

---
---

# §15. 2차 개정 — 매장이 실제로 제공하는 메뉴 검색 + 상세 직행

- 개정: 2026-10-26 (architect)
- 기준 코드: `e7f5c03` (working tree clean). 1차 구현이 **배포돼 동작 중**인 상태에서의 개정이다
- **전제 변화**: 1차 설계 때 없던 `isMenuShownOnStoreScreen` (`lib/core/utils/store_menu_visibility.dart`) 가 검증·수정 과정에서 생겼다. 검색 결과 필터 · 매장 화면 목록 · 안내 띠가 **같은 함수**를 쓴다. 이 개정은 그 원칙을 **override 영역까지 확장**하는 작업이다

## 15.0 확정된 사용자 결정 (뒤집지 않는다)

| # | 결정 | 1차에서 무엇이 바뀌는가 |
|---|---|---|
| **U1** | 검색 대상 = **매장에서 실제로 활성화된 메뉴** | 1차는 브랜드 마스터만 읽어 `excluded` 한 메뉴도 결과에 나왔다 (L2). 이제 `menuOverrides` 를 반영한다 |
| **U2** | 메뉴 결과 탭 → **메뉴 상세 직행** (매장 화면을 깔고 그 위에) | 1차 D3("상세 직행 금지")를 뒤집는다 |

**U2 의 분기 (코디네이터-사용자 합의 — 그대로 구현한다)**

| 상황 | 동작 |
|---|---|
| 매장이 그 메뉴를 판다 | 매장 화면을 깔고 그 위에 **상세 직행** (뒤로가기 → 매장 화면) |
| 품절이다 | 상세로 가되 **품절 표시 + 담기 비활성** |
| 매장에 없다 | 매장 화면 + `이 매장에서는 판매하지 않는 메뉴일 수 있어요` 띠 (1차 구현 유지) |

---

## 15.1 2단계 안 — **확정한다.** 근거와 수정 1건

코디네이터 제안:

```
1단계  마스터 + 개인매장 메뉴로 후보를 뽑는다      (현행, 실측 17쿼리 / 55 docs)
2단계  결과에 등장한 매장만 골라 override 를 읽는다  (보통 1~3곳)
```

### 결론: **채택한다.** 더 나은 안은 없다

세 가지를 비교했다. 기준은 **"메뉴를 한 번 검색한 사용자가 지불하는 비용"** 이다.

| 안 | 첫 검색 쿼리 | 첫 검색 문서 | 판정 |
|---|---|---|---|
| (a) **2단계 (제안)** | **18~20** (최악 27) | **85~145** (최악 355) | **채택** |
| (b) 1단계에서 모든 브랜드 후보의 override 를 함께 읽기 (eager) | 32 | 505 | 기각 — 쿼리 1.7배, 문서 **5.8배**. 그 비용을 **검색어와 무관하게 전원이** 낸다 |
| (c) `collectionGroup('menuOverrides').where('excluded','==',true)` 로 전역 제외 집합 1쿼리 | 18 | 수백~수천 (전체 매장분) | 기각 — **collection group 단일 필드 인덱스 신규 필요**(§8 인덱스 0건 전제 파괴) + 매장이 늘면 문서 수가 선형 증가. §2.4 에서 이미 같은 이유로 기각했다 |

(b) 가 (a) 보다 훨씬 비싼 이유는 **`seedExclusionsForStore` 때문**이다. 매장 등록 시 **미선택 마스터 메뉴 전부를 `excluded=true` 문서로 심는다** (`menu_override_remote_data_source.dart`). 즉 브랜드 매장 1곳의 `menuOverrides` 문서 수는 그 브랜드의 **마스터 메뉴 수에 비례**한다 — 작은 컬렉션이 아니다. 후보 브랜드 매장 15곳에 eager 로 붙으면 그 컬렉션을 15번 전부 읽는다. 2단계는 **실제로 일치한 1~3곳만** 읽는다.

### 제안에 대한 수정 1건 — **2단계는 L1 을 고칠 수 없다**

코디네이터가 "2단계에서 점포 한정 메뉴를 같이 읽으면 L1 이 해소된다" 고 보았지만, **구조적으로 불가능하다.**

> 2단계는 **1단계에서 이미 일치한 매장**만 본다. 브랜드 매장의 점포 한정 메뉴(`stores/{id}/menuItems`, `scope=store`)는 1단계에서 **읽히지 않으므로 애초에 일치할 수 없다.** 그 메뉴만 가진 매장은 2단계 대상 집합에 들어오지도 않는다. 2단계에 `menuItems` 읽기를 추가해도 **이미 다른 메뉴로 걸린 매장의 점포 한정 메뉴만** 추가로 보일 뿐이라, "검색되는 메뉴" 가 질의와 무관하게 들쭉날쭉해진다 — 더 나쁘다.

L1 을 고치려면 **1단계에서** 브랜드 후보 매장의 `stores/{id}/menuItems` 를 읽어야 한다 → 실측 기준 **+15쿼리 (17 → 32)**. 문서 수는 거의 늘지 않지만(점포 한정 메뉴는 소수) 쿼리가 2배가 되고, 그 비용 역시 전원이 낸다.

**판단: L1 은 이번에도 해소하지 않는다.** (a) 2단계로는 불가능하고 (b) 1단계 해소는 쿼리 2배인데 (c) 대상이 가장 희소한 메뉴 분류다. **§7 F2(CF 비정규화)가 L1·L2 를 함께 없애는 정답이며, 이번 개정은 L2 만 선취한다.** → 사용자 확인 **D10**.

---

## 15.2 핵심 아키텍처 요구 — 판정을 복제하지 말고 **확장**한다

2단계에서 `excluded` / `priceOverride` / `soldOut` 을 적용할 때, 그 규칙을 검색 쪽에 **다시 쓰면 안 된다.** 규칙은 이미 `MenuItemRepositoryImpl._mergeForBrandStore` 안에 있고, 거기엔 **비자명한 분기**가 있다.

```
핵심 필드 (excluded / priceOverride)  →  override.status == approved 일 때만 적용
운영 필드 (soldOut / disabledOption*) →  status 무관 즉시 적용
```

이 분기를 검색 쪽에 손으로 옮기면 **"검색에 걸렸는데 매장 화면에는 없다"** 가 되돌아온다. `isMenuShownOnStoreScreen` 이 막으려 했던 바로 그 결함이고, 이번엔 승인 대기 중인 override 라는 더 찾기 어려운 형태로 나타난다.

### 요구: 순수 함수 1개를 추출하고, 세 경로가 그것만 쓴다

```
lib/core/utils/store_menu_visibility.dart  (기존 파일에 추가 — 같은 책임이다)

/// 브랜드 매장의 마스터 메뉴 1건에 그 매장의 override 를 적용한다.
/// 반환 null = 이 매장은 이 메뉴를 팔지 않는다 (excluded).
MenuItemEntity? applyOverrideForCustomer({
  required MenuItemEntity master,
  required MenuOverrideEntity? override,   // 없으면 master 그대로
})
```

- 핵심 필드는 `override.status == approved` 일 때만, 운영 필드는 status 무관 — **현재 `_mergeForBrandStore` 와 100% 동일한 분기**
- 이 함수를 쓰는 곳 **3개, 전부**
  1. `MenuItemRepositoryImpl._mergeForBrandStore` (매장 화면 목록) — 기존 로직을 **이 함수 호출로 교체**
  2. `MenuItemRepositoryImpl.watchById` case B (메뉴 상세) — **현재 override 를 아예 적용하지 않는다. §15.6a 결함**
  3. 메뉴 검색 2단계 (`SearchMenuItemsUseCase` 또는 신규 verify UseCase)
- `domain` 순수 Dart (Firebase import 없음). 기존 `isMenuShownOnStoreScreen` 과 같은 파일·같은 성격
- **1 번 교체는 라이브 매장 화면을 건드린다.** 동작이 1바이트도 바뀌지 않아야 한다 → §15.14 tester 에 before/after 동치 검증을 못 박았다

> 판정 함수가 **2개**(노출 여부 + override 적용)가 되고, 둘 다 한 파일에 있다. 이것이 1차의 `isMenuShownOnStoreScreen` 이 세운 원칙의 자연스러운 확장이다. 새 파일을 만들어 흩뿌리지 않는다.

---

## 15.3 비용 추정 (1차 실측과 비교)

**1차 실측 기준값** (`implementation.md` §5 / `test_report.md`): 후보 30곳 = 개인 15 + 브랜드 15(브랜드 2개) → **17쿼리 / 55 docs**.
(55 docs 는 fake 가 매장당 3개·브랜드당 5개를 돌려준 값이며 실서버 수치가 아니다. 아래 문서 수도 같은 성격의 추정이다 — **쿼리 수가 비교 가능한 지표다**.)

### 15.3.1 첫 메뉴 검색

| 단계 | 쿼리 | 문서 (브랜드 마스터 30개 가정) | 비고 |
|---|---|---|---|
| 1단계 (변경 없음) | **17** | 55 | 개인 15 + 브랜드 2. **1차와 동일** |
| 2단계 — 일치 매장 중 **브랜드 매장만** | **+1~3** | +30~90 | 매장당 `menuOverrides` 전체 1쿼리. 개인 매장은 override 가 존재하지 않아 **0쿼리** |
| **합계 (전형)** | **18~20** | **85~145** | 1차 대비 **+1~3쿼리 (+6~18%)** |
| **합계 (최악 — fan-out 상한 10)** | **27** | **355** | §15.4 의 상한이 보장하는 천장 |

- **일치 매장이 전부 개인 매장이면 2단계 비용은 0 이다.** 가장 흔한 질의(동네 카페 이름·메뉴)가 여기에 해당한다
- `docs/tasks/home_search/spec.md §5.3` 의 전환선 **"메뉴 인덱스 쿼리 60 초과"** 는 최악 27 에서도 유지된다. 코디네이터가 우려한 "+60쿼리로 전환선에 바로 닿는다" 는 **eager 안(b)의 특성이고, 2단계 안은 거기에 닿지 않는다**

### 15.3.2 같은 세션 안에서의 반복 검색

| 상황 | 추가 비용 |
|---|---|
| 1단계 인덱스 재사용 | **0** (세션 캐시 — 1차와 동일) |
| 이미 2단계를 거친 매장이 또 일치 | **0** (매장 단위 캐시) |
| 새 매장이 일치 | **+1쿼리** |
| 검색 화면을 닫고 다시 들어옴 | 1단계 **0** / 2단계 **다시 1~3쿼리** (§15.5 조건 2 — 가격·품절 신선도를 방문 단위로 보장하는 대가) |
| 홈 pull-to-refresh 후 첫 검색 | 1차와 동일하게 스냅샷·인덱스 재생성 (**17쿼리**) + 2단계 1~3 |

---

## 15.4 행이 사라지는 깜빡임 — 금지하고, 어떻게 막는지 못 박는다

코디네이터 질문: *"1단계 결과를 먼저 보여주고 2단계로 걸러내면 행이 사라지는 깜빡임이 생기지 않는가."* → **생긴다. 그래서 금지한다.**

이 코드베이스에는 이미 같은 판단의 선례가 있다. `menuSearchResultsProvider` 는 활성 카테고리를 모르는 동안 행을 보여주지 않고 로딩으로 둔다 — 주석 그대로 *"활성 카테고리를 모르는 동안 행을 먼저 보여주면 나중에 사라질 수 있으므로 로딩으로 둔다"*. **2단계도 같은 규칙을 따른다.**

### 규칙

- [ ] **R1 — 사라지는 것은 금지, 늘어나는 것도 금지.** 2단계가 끝나기 전에는 **메뉴 섹션 전체를 로딩(shimmer)으로 둔다.** 1단계 행을 먼저 그리지 않는다
- [ ] **R2 — 매장 섹션은 영향받지 않는다.** 매장 결과는 1차와 동일하게 읽기 0으로 즉시 렌더된다. 메뉴 섹션만 기다린다 (1차 상태표 `s3StoresMenuLoading` 그대로)
- [ ] **R3 — 2단계는 1라운드트립이다.** 일치 매장을 모아 `Future.wait` 1회. "모자라면 더 읽는" 폭포식 재시도를 하지 않는다 (지연이 누적되고 상태가 늘어난다)
- [ ] **R4 — fan-out 상한 10곳.** 1단계 일치 행을 거리 오름차순으로 훑어 **distinct 브랜드 매장 10곳**까지만 2단계를 돌린다. 상한 밖 매장의 행은 **표시하지 않고** 기존 `isTruncated` 를 세워 `검색 범위를 좁혀 보세요` 를 띄운다. 넓은 질의(`아` 2글자 등)에서 쿼리가 폭발하지 않게 하는 천장이다
- [ ] **R5 — `total` 의 의미가 바뀐다.** 1차 `total` = 1단계 일치 수. 2차 `total` = **검증을 통과한 일치 수**. 헤더 `메뉴 (n)` 의 n 이 "실제로 살 수 있는 수" 가 된다. R4 로 잘린 분은 n 에 포함하지 않고 `isTruncated` 로만 알린다
- [ ] **R6 — 2단계 실패한 매장의 행은 버린다.** 그 매장을 `failedSourceCount` 로 세어 기존 부분 실패 상태(`s7StoresMenuPartial`)를 재사용한다. **검증 못 한 행을 "일단 보여주기" 는 하지 않는다** — 가격을 함께 표시하는 이번 개정에서는 특히 금지다 (§15.5 조건 2)

### 체감 지연

2단계는 **1~3쿼리 / 1라운드트립**이다. 1단계(17쿼리)가 이미 끝난 뒤이고, 메뉴 섹션은 그 동안 shimmer 였다. 추가 지연은 **대략 100~300ms**, 최악(10쿼리)에도 1라운드트립이라 수백 ms 수준이다. **1차에서 사용자가 이미 보고 있던 shimmer 가 조금 길어지는 것**이고, 새로운 종류의 대기가 생기는 것이 아니다.

---

## 15.5 가격 표시 — **표시한다.** 1차 결정을 명시적으로 뒤집는다

### 1차가 금지한 이유와, 그 이유가 사라졌다는 것

1차 `§4.1` / `MenuSearchHitEntity` 주석 / design 은 **"숫자 칸을 예약조차 하지 말라"** 고 못 박았다. 이유는 관행이 아니라 **"우리가 보여줄 가격이 틀릴 수 있다"** 였다 — 인덱스가 `menuOverrides` 를 읽지 않아 `priceOverride` 가 반영되지 않았기 때문이다.

**2단계가 override 를 읽는다. 그 이유가 사라졌다. 따라서 금지도 해제한다.**

### 왜 "그냥 해제" 가 아니라 "표시한다" 인가

배달앱 관행 자료는 근거로 쓰지 않는다 (코디네이터가 조사했고 **검색 결과 화면의 가격 노출을 직접 비교한 자료가 없었다**). 우리 조건으로만 판단한다.

- **① 사용자 결정 U1 의 목적이 가격을 포함한다.** "그 매장에서 실제로 제공하는 메뉴" 를 보여주기로 했는데, 가맹점 가격은 매장마다 다를 수 있다(`priceOverride` 가 존재하는 이유다). **같은 메뉴가 매장별로 여러 행으로 나오는 화면**(1차 §3.2 — 메뉴×매장 1행)에서 가격이 없으면, 사용자는 그 행들을 **구별할 수단이 거리뿐**이다. 가격은 이 화면에서 장식이 아니라 **행을 고르는 축**이다
- **② 대안이 더 나쁘다.** 가격을 숨기면 사용자는 행마다 들어가 보고 뒤로 나오기를 반복한다. U2(상세 직행)와 합쳐지면 그 왕복이 더 잦아진다
- **③ 매장 화면과 같은 값·같은 표기가 된다.** 2단계는 `applyOverrideForCustomer` 로 매장 화면 목록과 **같은 함수**를 통과한 값이다. `MenuItemCard` 는 `PriceFormatter.formatKrw(basePrice)` 를 꾸밈 없이 쓴다 → 검색 행도 **같은 표기**를 쓴다 (옵션 추가금 전 기본가, `~` 같은 접미사 없음). 두 화면이 다른 숫자를 보여줄 가능성이 구조적으로 없다

### 표시 조건 2개 (이것이 지켜지지 않으면 표시하지 않는다)

- **조건 1 — 신선도를 방문 단위로 묶는다.** 1단계 인덱스는 세션 캐시를 유지하되(1차 L4 그대로), **2단계 override 캐시는 검색 화면 수명(`autoDispose`)** 으로 둔다. 화면을 다시 열면 일치 매장의 override 를 다시 읽는다 — 비용 1~3쿼리로 **가격·품절이 "이번 방문 시점" 기준**이 된다. 세션 내내 캐시하면 30분 전 가격을 숫자로 보여주게 되는데, 그건 1차가 금지한 상황과 실질적으로 같다 → 사용자 확인 **D12**
- **조건 2 — 검증 못 한 행에는 가격을 쓰지 않는다. 행 자체를 안 그린다.** R6 과 같은 규칙이다. "가격만 비우고 행은 보여주기" 를 허용하면 1차가 막은 구멍이 다시 열린다

### 함께 표시하는 것 / 하지 않는 것

- **표시**: 기본가 (`basePrice`), **품절 배지** (§15.6)
- **미표시**: 할인·별점·리뷰 수·옵션 최저가 — 1차의 "숫자 칸을 예약하지 않는다" 는 **이 항목들에는 그대로 유효하다.** 해제한 것은 가격 하나다

→ 사용자 확인 **D8**.

---

## 15.6 품절 처리 — 상세 화면에 **없는 것**을 어떻게 할지

코디네이터 지적이 정확하다. `menu_item_detail_page.dart` (767줄) 와 그 위젯에 **`soldOut` 이 단 한 번도 등장하지 않는다** (grep 재확인). 격자 카드(`menu_item_card.dart`)에는 `_soldOutOverlay` + 탭 비활성 + 회색 처리가 있는데 **상세로 들어가면 그 신호가 전부 사라지고 `담기` 가 멀쩡히 활성된다.**

조사하면서 **더 깊은 결함 1건**을 찾았다. 아래 (a) 가 그것이다.

### (a) 데이터 결함 — 상세 화면은 override 를 **아예** 적용하지 않는다 ⚠️

`menuItemDetailProvider` → `WatchMenuItemDetailUseCase` → `MenuItemRepositoryImpl.watchById`:

```
case B(브랜드 매장): combineLatest2(store 메뉴 doc, brand 마스터 doc) → (s ?? m)
                     ^^^ menuOverrides 를 구독하지 않는다
```

즉 **브랜드 매장의 마스터 메뉴 상세 화면은 `priceOverride` · `soldOut` · `disabledOption*` 를 전부 무시한다.**

> **이것은 검색이 만든 문제가 아니다. 매장 화면 → 메뉴 탭으로 들어가는 기존 라이브 경로에도 이미 존재한다.**
> 결과: 목록 카드는 override 가 적용된 가격·품절을 보여주는데, 그 카드를 누르면 상세에서 **마스터 가격**이 뜨고 **품절 표시가 사라지며**, 점주가 끈 옵션이 다시 선택 가능해진다. `담기` 가격도 마스터 기준으로 계산된다.
> **U2(상세 직행)를 이 상태로 올리면 "품절 메뉴를 주문 가능한 것처럼 보여준다" 가 그대로 발생한다.** U2 의 전제조건이므로 이번 범위에 **포함한다.**

**수정**: `watchById` case B 를 `combineLatest3` 으로 바꿔 `stores/{storeId}/menuOverrides/{menuItemId}` **문서 1건 스트림**을 합치고, §15.2 의 `applyOverrideForCustomer` 를 통과시킨다.
- `excluded` → `null` 반환 → 상세는 "이 매장에서 판매하지 않음" 처리 (§15.7)
- 문서 단건 구독이므로 쿼리 비용은 **상세 1회 진입당 listener 1개**. 인덱스 불필요
- 개인 매장(case A)은 변화 없다
→ 사용자 확인 **D13**.

### (b) UI 설계 — 품절 상태를 상세에 들인다

`soldOut == true` 일 때:

| 영역 | 설계 |
|---|---|
| 대표 이미지 | **`품절` 오버레이.** `menu_item_card.dart` 의 `_soldOutOverlay` 와 **같은 톤**. designer 가 공용 위젯으로 올릴지 판단 (올리면 `presentation/common/`) |
| 메뉴명 / 가격 | 카드와 동일하게 **`AppColors.textMuted` 로 낮춘다** (카드가 이미 `soldOut ? textMuted : ...` 분기를 쓴다 — 같은 규칙) |
| 옵션 그룹 영역 | **비활성** — 흐리게 + 탭 무시. `primeRequiredDefaults` 자동 선택은 그대로 돌아도 무해하나, 합계가 의미 없으므로 시각적으로 꺼둔다 |
| 수량 스테퍼 | **비활성** |
| 하단 `_BottomAction` | 합계 행은 유지(회색). 버튼 라벨 **`품절`** + `onPressed: null` + disabled 색 |
| 비활성 사유 구분 | 현재 `담기` 비활성은 **required 옵션 미선택** 하나뿐이고 누르면 토스트가 뜬다. **품절은 최우선 조건이며 토스트를 띄우지 않는다** (누를 수 없다). `enabled` 판정에 `soldOut` 을 **첫 조건**으로 넣는다 |
| 즐겨찾기(하트) | **품절과 무관하게 동작 유지.** 품절은 일시적이다 |

### (c) 검색 결과 행의 품절

- 1차 L5("품절 메뉴도 결과에 뜬다")는 **표시로 해소**한다 — 행에 **`품절` 배지**를 달고 텍스트를 낮춘다. 행을 숨기지 않는다 (매장 화면도 숨기지 않는다 — `isMenuShownOnStoreScreen` 은 `soldOut` 을 보지 않는다. 그 기준을 따른다)
- **품절 행도 탭하면 상세로 간다** (U2 분기표 2행). 그런데 **매장 화면의 품절 카드는 `onTap: null` 로 탭이 막혀 있다** → 같은 메뉴가 **검색에서는 열리고 매장 화면에서는 안 열리는** 불일치가 생긴다
  - 권장: 상세가 품절을 제대로 처리하게 되는 이번 개정과 함께 **매장 화면 품절 카드도 탭을 허용**해 규칙을 하나로 만든다 — **"품절은 볼 수 있고 담을 수 없다"**
  - → 사용자 확인 **D9**

### (d) 범위 밖이지만 적어두는 위험 — 장바구니·결제에 품절 검증이 없다

`soldOut` 을 읽는 곳을 전수 조사했다. `lib/domain/usecases/toggle_sold_out_use_case.dart` (점주 토글) 와 매장 화면 카드뿐이다. **장바구니·주문 생성·결제 어디에도 품절 검증이 없다.** 담은 뒤 품절된 메뉴가 그대로 결제까지 간다. 이번 개정이 만든 문제가 아니고 범위도 아니지만, **상세에서 `담기` 를 막는 것만으로는 구멍이 닫히지 않는다** → §15.16 **F8**.

---

## 15.7 매장이 팔지 않는 메뉴 / 삭제된 메뉴로 들어갔을 때

2단계가 `excluded` 를 걸러내므로 이 경로는 **드물어지지만 사라지지 않는다** — 1단계 인덱스는 세션 캐시라, 인덱스를 만든 뒤 매장이 메뉴를 내리면 행이 남아 있을 수 있다 (L4).

| 경로 | 동작 |
|---|---|
| 검색 행 탭 → 매장 화면에 그 메뉴가 **있다** | 상세 직행 (U2 1행) |
| 검색 행 탭 → 매장 화면 목록에 **없다** | **상세로 올리지 않는다.** 매장 화면에 머물며 1차 구현의 `_SearchedMenuBand` 가 `이 매장에서는 판매하지 않는 메뉴일 수 있어요` 를 띄운다 (U2 3행 = 1차 유지) |
| 상세에 들어간 뒤 override 가 `excluded` 로 바뀌었다 / 메뉴가 삭제됐다 | `watchById` 가 `null` → 기존 `_DeletedView`. 문구는 `이 매장에서는 판매하지 않는 메뉴예요` + **`매장 메뉴 보기`** 액션 (뒤로가기와 같은 결과이지만 명시적 출구를 준다) |

> **"있다/없다" 판정은 반드시 `isMenuShownOnStoreScreen` 으로 한다.** 검색 화면이 자체 판정을 들고 상세를 올리면 1차가 세운 단일 판정이 깨진다. 즉 **매장 화면이 먼저 목록을 확정한 뒤 그 결과로 상세를 올린다** (§15.8).

### L4(세션 캐시 staleness)는 직행으로 **교정된다**

코디네이터 질문에 대한 답: **그렇다.** 상세 화면은 `watchById`(+ §15.6a 의 override 스트림) 로 **실시간 구독**이다. 캐시된 행이 가리키는 가격·품절·존재 여부가 상세에 들어간 **그 순간 서버 값으로 덮인다.** 그래서

- 검색 행의 가격이 낡았어도 → 상세에서 올바른 가격을 본다 (담기·결제는 상세 값으로 간다)
- 품절이 됐는데 행에 배지가 없어도 → 상세에서 `품절` + 담기 비활성을 본다
- 메뉴가 내려갔어도 → 매장 화면 목록에 없으므로 상세가 열리지 않는다 (위 표 2행)

**L4 는 "결과 목록이 몇 분 낡을 수 있다" 로 축소되고, "낡은 정보로 주문된다" 는 경로는 닫힌다.** 이것이 §15.5 에서 가격 표시를 허용할 수 있는 또 하나의 근거다.

---

## 15.8 메뉴 결과 탭 — 구현 명세 (1차 §3.3 대체)

```
메뉴 행 탭
  ↓
① 매장 화면을 push 한다 — StoreMenuPage(
      store: matchedStore,
      initialMainCategoryCode: hit.mainCategoryCode,   // 1차 구현 그대로
      highlightMenuItemId: hit.menuItemId,             // 1차 구현 그대로
      autoOpenMenuItemId: hit.menuItemId,              // ★ 신규
   )
  ↓
② 매장 화면이 메뉴 목록을 확정한다 (filteredMenuItemsProvider = isMenuShownOnStoreScreen 적용)
  ↓
③ autoOpenMenuItemId 가 그 목록에 있으면 → 첫 프레임 직후 MenuItemDetailPage 를 그 위에 push
   없으면 → push 하지 않고 _SearchedMenuBand 가 안내 띠를 띄운다 (현행)
```

- [ ] **매장 화면을 깔고 그 위에 상세를 올린다.** 뒤로가기 한 번 → 매장 화면, 두 번 → 검색 화면. U2 1행의 "뒤로가기 → 매장 화면" 이 자동으로 성립한다
- [ ] 자동 push 는 **딱 한 번**이다. 상세에서 뒤로 나온 뒤 다시 열리면 사용자가 빠져나올 수 없다 → `_StoreMenuPageState` 에 `_autoOpened` 플래그 (기존 `_appliedInitialCategory` / `_highlightDismissed` 와 같은 패턴)
- [ ] push 시점은 **목록 확정 후**다. 메뉴 stream 로딩(shimmer) 중에는 올리지 않는다. 위젯 빌드 중 `Navigator` 호출 금지 — `initState` 의 `Future.microtask` 가 아니라 **`ref.listen` 으로 목록이 data 가 되는 순간**에 올린다 (1차 `initialMainCategoryCode` 는 microtask 로 충분했지만 이건 목록을 기다려야 한다)
- [ ] `highlightMenuItemId` 는 **그대로 둔다.** 상세에서 뒤로 나왔을 때 매장 화면에서 그 카드가 강조돼 있어야 "내가 찾던 그 메뉴" 가 유지된다
- [ ] 품절 메뉴도 자동 push 한다 (U2 2행). 상세가 §15.6b 로 품절을 표시한다
- [ ] 매장 결과(메뉴가 아닌) 탭은 **1차 그대로** — 매장 화면까지만

---

## 15.9 한계 재평가 (1차 §2.3 대비)

| # | 1차 한계 | 2차 결과 |
|---|---|---|
| **L1** | 브랜드 매장의 점포 한정 메뉴 미검색 | **유지.** 2단계로는 구조적으로 불가능하고 1단계 해소는 쿼리 2배 (§15.1). → F2 |
| **L2** | `excluded` 메뉴가 그 매장 결과로 뜰 수 있다 | **해소.** 2단계가 `applyOverrideForCustomer` 로 걸러낸다. U1 의 목적 그대로 |
| **L3** | 반경 10km · 상위 30곳 밖 미검색 | **유지.** 범위 안내 문구도 1차 그대로 |
| **L4** | 세션 캐시 staleness | **축소.** 2단계 override 는 **방문 단위로 재읽기**(§15.5 조건 1), 상세는 실시간 구독으로 교정(§15.7). 남는 것은 "목록의 메뉴 구성이 몇 분 낡을 수 있다" |
| **L5** | 품절 메뉴도 결과에 뜬다 | **해소(표시로).** `품절` 배지 + 상세 품절 처리 (§15.6). 숨기지는 않는다 — 매장 화면과 같은 기준 |
| **L6** | *(신규)* 2단계 fan-out 상한 10곳 밖의 일치 행은 표시되지 않는다 | R4 의 천장. `isTruncated` 로 사용자에게 알린다 |

---

## 15.10 인덱스 / Rules — **0건 전제가 깨지지 않는다**

> ### 신규 인덱스: **0건.** `firestore.indexes.json` 을 이번에도 수정하지 않는다.
> ### Rules 변경: **없음.**

| 추가되는 쿼리 | 형태 | 인덱스 |
|---|---|---|
| 2단계: `stores/{id}/menuOverrides` 전체 | `_overrideCol(storeId).get()` — **`where` 없음.** 기존 `streamByStore` 와 **같은 문장**의 one-shot 판 | **불필요** |
| 상세(§15.6a): `stores/{id}/menuOverrides/{menuItemId}` | **문서 단건** `.snapshots()` | **불필요** |

- `menuOverrides` 는 `stores/{id}` 하위 **컬렉션**이다. collection **group** 쿼리를 쓰지 않으므로 group scope 인덱스 선언이 필요 없다 — §15.1 에서 대안 (c) 를 기각한 이유가 이것이다
- **Rules**: `stores/{storeId}/menuOverrides/{masterMenuItemId}` 는 `allow read: if isSignedIn()` (`firestore.rules` line 416, 확인). 1차에서 읽던 세 경로와 같은 조건이다

### developer 강제 조건 (1차 §8.2 를 이어받아 확장)

- [ ] 2단계 override 쿼리에 **`where` 를 붙이지 않는다** (`excluded == true` 로 줄이고 싶어지지만, 문서 수 절감보다 인덱스 선언 비용·누락 위험이 크다)
- [ ] **`collectionGroup` 을 쓰지 않는다** (1차와 동일)
- [ ] 위를 어기면 → `firestore.indexes.json` 추가 + **`firebase deploy --only firestore:indexes` 를 앱 배포보다 먼저** + `implementation.md` 에 기록
- [ ] tester 는 품절·가격·excluded 를 **모두 포함한 가맹점 매장**으로 검색해 `failed-precondition` 이 콘솔에 **한 번도** 찍히지 않음을 확인한다

---

## 15.11 이력 / 감사 추적 재확인 (`audit_trail.md` §4)

**1차 §6 의 판정이 그대로 유지된다. 이 개정도 Firestore 에 단 한 건도 쓰지 않는다.**

| # | 항목 | 판정 |
|---|---|---|
| 1 | 돈·권한·정책 값을 바꾸는가 | **아니다.** `menuOverrides` 를 **읽기만** 한다. 가격·품절·`excluded` 를 쓰는 주체는 brand/owner 흐름이며 이 개정이 건드리지 않는다. 따라서 설정 변경 이력 불필요 — 사유는 **"쓰기 경로가 아예 없음"** (1차와 동일) |
| 2 | 덮어쓰기로 사라지는 값 | **없다.** 새 필드·마이그레이션 없음 |
| 3 | 기록 문서가 정책 값을 참조만 하는가 | **이번 개정의 핵심 항목이다.** 1차는 "틀릴 수 있는 가격을 아예 안 보여준다" 로 회피했고, 2차는 **"그 시점의 매장 실제 가격을 읽어서 보여준다"** 로 바꿨다. 다만 **검색 화면의 가격은 표시용이고 어떤 기록에도 박제되지 않는다.** 결제 시 주문 문서에 박제되는 값은 기존 주문 흐름이 상세·장바구니 경로에서 확정하며, 이 개정은 그 경로를 바꾸지 않는다. §15.6a 수정으로 **상세의 가격이 오히려 정확해지므로**(마스터 가격 → 매장 실제 가격) 박제되는 값의 정확성은 **개선된다** |
| 4 | "누가" 가 기록되는가 | 운영자 행위 없음. 기록 대상 없음 |
| 5 | 일괄 처리(batch) | **없다.** 모든 접근이 `get()` / `snapshots()` 읽기 |
| 6 | CF 로그 의존 | **없다.** CF 미사용 |

**검색어 비수집 원칙도 1차 그대로**다 — 서버 미기록, Analytics 미전송, 최근 검색어는 단말 세션 메모리.

`entity_lifecycle.md`: status 전이 **유발 없음**. 단 `override.status == approved` 분기를 **읽기 측에서 정확히 지키는 것**이 이번 개정의 요구다 (§15.2).
`data_ownership.md` / `role_flows.md`: 소유권·권한·역할 전이 변경 없음.

---

## 15.12 레이어 설계 변경 (파일 단위)

### Domain

| 파일 | 변경 |
|---|---|
| `core/utils/store_menu_visibility.dart` | **`applyOverrideForCustomer` 추가** (§15.2). 순수 Dart |
| `domain/entities/menu_search_hit_entity.dart` | `MenuSearchHitEntity` 에 **`basePrice` (int)** + **`soldOut` (bool)** 추가. **"가격 필드를 두지 않는다" 주석을 삭제하고 뒤집은 사유를 적는다** (§15.5). `MenuSearchIndex` 는 1단계 산출물이므로 그대로 |
| `domain/usecases/search_menu_items_use_case.dart` | 2단계 검증 추가. `Future<VerifiedMenuHits> verify({required List<MenuSearchHitEntity> stage1Hits, required int storeFanOutLimit})` — 일치 행의 distinct 브랜드 매장(거리순 상한 R4)만 override 조회 → `applyOverrideForCustomer` → 제외/가격/품절 반영. 개인 매장 행은 그대로 통과. 반환에 `failedStoreCount` / `truncated` 포함 |
| `domain/repositories/menu_override_repository.dart` | **`Future<List<MenuOverrideEntity>> fetchByStoreOnce(String storeId);` 추가** |
| `domain/repositories/menu_item_repository.dart` | 변경 없음 (`watchById` 시그니처 불변 — 내부 머지만 바뀐다) |

### Data

| 파일 | 변경 |
|---|---|
| `data/datasources/remote/menu_override_remote_data_source.dart` | **`Future<List<MenuOverrideModel>> fetchByStore(String storeId)` 추가** — `_overrideCol(storeId).get()`. **`streamByStore` 와 같은 문장** (인덱스 0건의 근거) |
| `data/repositories/menu_override_repository_impl.dart` | `fetchByStoreOnce` 구현 (단순 위임 + `toEntity`). **ownership 검증을 붙이지 않는다** — customer 읽기 경로다 |
| `data/repositories/menu_item_repository_impl.dart` | ① `_mergeForBrandStore` 를 `applyOverrideForCustomer` 호출로 **교체**(동작 동일) ② **`watchById` case B 를 `combineLatest3` 으로 바꿔 override 문서 스트림 합침**(§15.6a) |

### Presentation

| 파일 | 변경 |
|---|---|
| `customer/search/providers/search_providers.dart` | ① `storeMenuOverridesProvider` **신규** — `FutureProvider.autoDispose.family<List<MenuOverrideEntity>, String>` (매장 단위 캐시, **검색 화면 수명**). 선례: `recommendation_providers.dart` 의 `_menuItemsByStoreProvider` 가 **동적 집합을 watch 하는 같은 패턴**이다 ② `menuSearchResultsProvider` 에 2단계 결합 — 1단계 filter 후 distinct 브랜드 매장(R4 상한)의 override 를 watch, **전부 도달 전에는 `AsyncLoading`**(R1) ③ `MenuSearchResults.total` 의 의미 변경(R5) + `failedSourceCount` 에 2단계 실패 합산(R6) |
| `customer/search/widgets/menu_search_result_tile.dart` | 가격 텍스트 추가(`PriceFormatter.formatKrw`, **`MenuItemCard` 와 같은 표기**) + `품절` 배지 + 품절 시 textMuted |
| `customer/order/store/store_menu_page.dart` | `autoOpenMenuItemId` 파라미터 + `_autoOpened` 플래그 + 목록 확정 후 1회 push (§15.8). **품절 카드 탭 허용** (D9 확정 시) |
| `customer/order/menu/menu_item_detail_page.dart` | 품절 UI 전면 (§15.6b) — 이미지 오버레이 / 텍스트 톤 / 옵션·수량 비활성 / `_BottomAction` 라벨 `품절` + 비활성 / `_DeletedView` 문구·액션 |
| `customer/search/search_page.dart` | `_openStore` 가 `autoOpenMenuItemId` 를 넘김 |

### 상수

`core/constants/grade_thresholds.dart` 에 추가
- `static const int menuSearchVerifyStoreLimit = 10;` (R4 fan-out 상한)

**레이어 규칙 점검**: `applyOverrideForCustomer` 는 순수 Dart(Firebase import 없음) / Firestore 접근은 DataSource 안에만 / 색상은 `AppColors` 만 / 새 패키지 없음 / 새 인덱스·Rules 없음.

---

## 15.13 상태 요구사항 추가 (1차 §3.5 / design 12상태 보존)

**1차의 `SearchView` 17상태 enum 과 `resolveSearchView` 단일 판정 함수를 그대로 쓴다. 새 상태를 만들지 않는다.** 2단계는 기존 상태에 다음과 같이 매핑된다.

| 2단계 상황 | 매핑되는 기존 상태 |
|---|---|
| 2단계 진행 중 | `s3StoresMenuLoading` / `s8NoStoresMenuLoading` (1단계 로딩과 **같은 shimmer**. 사용자에게 두 단계를 노출하지 않는다) |
| 2단계 일부 매장 실패 | `s7StoresMenuPartial` / `s12UnifiedEmptyPartial` — 기존 `일부 매장의 메뉴를 불러오지 못했어요` + `다시 시도` |
| 2단계 전부 실패 (일치 매장이 전부 브랜드 매장이고 전멸) | `s6StoresMenuError` / `s11NoStoresMenuError` |
| 2단계 후 검증된 행이 0 (전부 `excluded`) | `s5StoresMenuEmpty` / `s10UnifiedEmpty` — **`'{질의}' 와 일치하는 메뉴가 없어요`.** "있었는데 걸렀다" 를 사용자에게 설명하지 않는다 (그 매장이 안 파는 것이 사실이다) |
| R4 상한으로 잘림 | 기존 `isTruncated` → `검색 범위를 좁혀 보세요` |

**추가 요구**
- [ ] `resolveSearchView` 는 **계속 유일한 판정 함수**여야 한다. 2단계용 분기를 위젯에 심지 않는다
- [ ] 1차 원칙 유지 — `hasValue` 우선: 재시도 중에도 직전 값이 있으면 행을 유지한다 (R1 과 모순되지 않는다. R1 은 *검증 전 행을 처음부터 그리지 말라*는 것이고, 이쪽은 *이미 검증된 행을 지우지 말라*는 것이다)

---

## 15.14 작업 분배 (2차)

### designer

**UI 변경 있음.** 산출물: `docs/tasks/home_search/design.md` **에 개정 절을 추가**한다 (1차 design 을 덮지 않는다 — spec 과 같은 방식).

- **메뉴 검색 행에 가격을 넣는다.** 1차 design 이 못 박은 *"숫자 칸을 예약조차 하지 말라"* 를 **가격 하나에 대해서만** 해제한다. 근거는 §15.5. **할인·별점·리뷰 수·옵션 최저가 칸은 여전히 만들지 않는다**
- 가격 표기는 **`MenuItemCard` 와 동일**: `PriceFormatter.formatKrw(basePrice)`, 접미사 없음. 두 화면의 숫자가 달라 보이면 안 된다
- 메뉴 검색 행 **`품절` 배지** + 품절 시 텍스트 톤 낮추기 (카드의 `soldOut ? textMuted : ...` 규칙 재사용)
- **메뉴 상세 품절 상태 전체** (§15.6b 표) — 이미지 오버레이 / 옵션·수량 비활성 표현 / 하단 `담기` → `품절` 비활성. `_soldOutOverlay` 를 `presentation/common/` 으로 올릴지 판단
- `_DeletedView` 문구·액션 변경 (`이 매장에서는 판매하지 않는 메뉴예요` + `매장 메뉴 보기`)
- **상세 자동 열림의 전환 느낌** — 검색 행 탭 → 매장 화면 → 상세가 연달아 쌓인다. 두 번 깜빡이지 않게 할 방법(매장 화면 push 애니메이션 생략 등) 판단
- **품절 카드 탭 허용 시**(D9) 매장 화면 카드의 "눌릴 수 있지만 품절" 시각 처리
- 로딩 중 메뉴 섹션은 **1차 shimmer 그대로**. 2단계를 위한 새 로딩 표현을 만들지 않는다 (§15.13)

### developer

**구현 순서를 지킨다 — 아래 1→2 를 먼저 끝내고 검증한 뒤 3 이후로 간다.** 1·2 는 라이브 화면을 건드린다.

1. `applyOverrideForCustomer` 추출 + `_mergeForBrandStore` 교체 — **동작 변화 0** (§15.2)
2. `watchById` case B override 머지 (§15.6a) — **기존 매장 화면 → 상세 경로의 결함 수정**
3. `menuOverrides` one-shot (DataSource → Repository IF → Impl)
4. `SearchMenuItemsUseCase.verify` 2단계 + `MenuSearchHitEntity` 에 `basePrice` / `soldOut` (freezed 재생성)
5. `storeMenuOverridesProvider` + `menuSearchResultsProvider` 결합 (R1~R6)
6. 메뉴 상세 품절 UI (§15.6b)
7. `autoOpenMenuItemId` + 자동 push (§15.8)
8. 검색 행 가격·품절 표시

**재사용할 기존 구조**
- `recommendation_providers.dart` 의 `_menuItemsByStoreProvider` — **동적 storeId 집합을 watch 하는 패턴의 선례**
- `menu_item_card.dart` 의 `_soldOutOverlay` / `soldOut ? textMuted : ...` 분기
- 1차 `SearchView` / `resolveSearchView` / `_SearchedMenuBand` / `highlightMenuItemId`
- `MenuOverrideRemoteDataSource.streamByStore` 의 쿼리 문장 (one-shot 이 같아야 인덱스 0건이 성립)

**함정**
- `_mergeForBrandStore` 의 **approved 분기(핵심 필드) vs status 무관(운영 필드)** 를 손으로 다시 쓰지 말 것. 함수 1개만 쓴다 (§15.2)
- 2단계 override 조회에 **`where` 금지 / `collectionGroup` 금지** (§15.10)
- **검증 전 행을 그리지 말 것** (R1). "일단 보여주고 거르기" 는 가격을 함께 띄우는 이번 개정에서 치명적이다
- `storeMenuOverridesProvider` 는 **autoDispose** 다 (방문 단위 신선도). 1단계 `menuSearchIndexProvider` 는 **non-autoDispose 유지** — 섞지 말 것
- 자동 push 는 **목록 확정 후 1회**. `initState` 에서 올리면 shimmer 위에 쌓이고, 플래그가 없으면 뒤로가기가 막힌다 (§15.8)
- 상세 `담기` 비활성 사유에 **`soldOut` 을 첫 조건으로**. required 미선택 토스트가 품절에 뜨면 안 된다
- `flutter analyze` 무경고 / `flutter test` 통과

산출물: 코드 + `implementation.md` **개정 절**

### tester

**최우선 — 라이브 회귀 2건**
- [ ] **`applyOverrideForCustomer` 추출이 매장 화면 목록을 바꾸지 않았는지.** 교체 전/후 동일 데이터로 같은 목록·같은 가격·같은 품절이 나오는지. 특히 **`status != approved` 인 override**: `priceOverride`/`excluded` 는 **무시**되고 `soldOut`/`disabledOption*` 는 **적용**되어야 한다 (뒤집히면 FAIL). 단위 테스트 필수
- [ ] **`watchById` override 머지가 기존 경로를 고쳤는지.** 매장 화면 → 메뉴 탭 진입 시 상세 가격이 **목록 카드의 가격과 같아야 한다**. 개정 전에는 달랐다 (마스터 가격). 개인 매장(case A)은 변화 없어야 한다

**2차 기능**
- [ ] 가맹점이 `excluded` 한 메뉴가 **검색 결과에 안 나오는지** (L2 해소 — 1차에서는 나왔다)
- [ ] 검색 행 가격이 **매장 화면 카드 가격과 일치**하는지. `priceOverride` 가 있는 매장에서 **마스터 가격이 아닌 매장 가격**이 나오는지
- [ ] 품절 메뉴가 **행에 `품절` 배지와 함께 나오고**, 탭하면 상세가 열리고, 상세에서 **`담기` 가 비활성이며 토스트가 안 뜨는지**
- [ ] 품절 아닌 메뉴 탭 → **매장 화면이 깔리고 그 위에 상세**. 뒤로가기 1회 → 매장 화면(강조 카드 유지), 2회 → 검색 화면
- [ ] **상세에서 뒤로 나온 뒤 상세가 다시 열리지 않는지** (무한 재진입 FAIL)
- [ ] 매장 화면 목록에 없는 메뉴 → **상세가 안 열리고** `판매하지 않는 메뉴일 수 있어요` 띠
- [ ] **행이 사라지는 깜빡임이 없는지** (R1). 느린 네트워크에서 메뉴 섹션이 shimmer → 결과로 **한 번만** 전이하는지. 행이 떴다가 줄어들면 **FAIL**
- [ ] 일치 매장이 10곳을 넘는 넓은 질의 → `isTruncated` 안내가 뜨고 쿼리가 **10을 넘지 않는지** (R4)
- [ ] 2단계 일부 실패 → 성공분이 그려지고 부분 실패 안내가 뜨는지. **매장 섹션은 살아 있는지**

**읽기 실측 (1차 `home_search_providers_test.dart` 하네스 확장)**
- [ ] 첫 메뉴 검색: 1단계 **17쿼리 유지** + 2단계 **일치 브랜드 매장 수만큼**. 개인 매장만 일치하면 **2단계 0쿼리**
- [ ] 같은 세션 같은 매장 재일치 → **0쿼리**
- [ ] 검색 화면 재진입 → 1단계 0 / 2단계 **다시 조회** (의도된 동작, §15.5 조건 1)
- [ ] 전체 쿼리가 **27(최악)을 넘지 않는지**

**인덱스**
- [ ] 가맹점(override·품절·excluded 포함) 검색 전 과정에서 `failed-precondition` / `requires an index` 가 **한 번도** 찍히지 않는지

산출물: `test_report.md` **개정 절**

---

## 15.15 사용자 확인이 필요한 결정 (2차)

사용자 결정 U1·U2 는 뒤집지 않았다. 아래는 그 결정을 구현하려면 **추가로 정해야 하는** 것들이다.

| # | 결정 | 선택지 | 권장 |
|---|---|---|---|
| **D8** | **검색 행에 가격을 표시할지** | (a) **표시** (b) 미표시 유지 | **(a)**. 1차가 금지한 이유("틀릴 수 있다")가 2단계로 사라졌고, 같은 메뉴가 매장별로 여러 행 나오는 화면에서 가격은 **행을 고르는 축**이다 (§15.5). 단 조건 2개(방문 단위 신선도 / 검증 못 한 행은 아예 미표시)가 붙는다. **1차 design 의 "숫자 칸 금지" 를 가격 하나에 대해 명시적으로 해제하는 결정이다** |
| **D9** | **품절 메뉴 탭 규칙을 통일할지** | (a) **검색 행·매장 카드 모두 탭 허용** — "품절은 볼 수 있고 담을 수 없다" (b) 검색 행만 허용(매장 카드는 현행 탭 차단 유지) | **(a)**. (b) 는 같은 메뉴가 검색에서는 열리고 매장 화면에서는 안 열리는 불일치를 남긴다. (a) 는 매장 화면 카드 1곳의 `onTap` 수정 — 작업량 소. **다만 라이브 동작 변경이다** |
| **D10** | **L1(브랜드 매장 점포 한정 메뉴)을 이번에 포함할지** | (a) **미포함 — F2 로** (b) 1단계에 브랜드 매장 `menuItems` 추가 | **(a)**. 2단계로는 구조적으로 불가능하고(§15.1), 1단계 해소는 **쿼리 17 → 32 (2배)** 를 전원이 지불한다. 대상은 가장 희소한 메뉴 분류다 |
| **D11** | 2단계 fan-out 상한 | (a) **10곳** (b) 5곳 (c) 무제한 | **(a)**. 최악 27쿼리로 §5.3 전환선(60) 아래. (c) 는 `아` 같은 2글자 질의에서 쿼리가 폭발한다 |
| **D12** | override 캐시 수명 | (a) **검색 화면 수명 (재진입 시 재조회, 1~3쿼리)** (b) 세션 캐시 (재조회 0) | **(a)**. 가격을 숫자로 띄우기로 했으므로(D8) 신선도를 방문 단위로 묶는다. (b) 는 30분 전 가격을 숫자로 보여줄 수 있어 **1차가 금지한 상황과 실질적으로 같다** |
| **D13** | **`watchById` override 머지 수정을 포함할지** | (a) **포함 (필수)** (b) 검색 직행용 별도 provider 를 만들어 상세 기존 경로는 건드리지 않음 | **(a)**. 이것은 **검색과 무관하게 이미 존재하는 결함**이다 — 목록 카드와 상세가 다른 가격을 보여주고, 상세에서 품절 표시가 사라진다(§15.6a). U2 의 전제조건이기도 하다. (b) 는 같은 화면에 데이터 경로를 2개 만드는 선택이라 **권장하지 않는다** |

### 뒤집지 않고 올리는 지적 2건

- **① 2단계는 L1 을 해소할 수 없다** (§15.1). 코디네이터 가정과 다르다. L1 을 이번에 없애려면 1단계를 바꿔야 하고 쿼리가 2배가 된다 → D10
- **② 메뉴 상세는 지금 override 를 아예 적용하지 않는다** (§15.6a). 품절 UI 부재보다 **범위가 넓은 결함**이다 — 가격·품절·비활성 옵션 셋 다 틀리고, **검색이 아닌 기존 매장 화면 경로에서도 이미 틀리고 있다**. 품절 UI만 올리고 이것을 두면 "품절 표시는 생겼는데 여전히 안 뜬다"(override 의 soldOut 을 못 보니까) 가 된다 → D13

---

## 15.16 후속 과제 갱신 (1차 §7 에 이어서)

| # | 과제 | 트리거 | 내용 |
|---|---|---|---|
| **F2** | 메뉴 검색 키워드 비정규화 (CF) — **우선순위 상승** | 메뉴 인덱스 쿼리 60 초과, 또는 L1 민원 | 1차에서는 L1·L2 를 함께 없애는 과제였다. **2차가 L2 를 선취했으므로 F2 의 남은 값은 L1 해소 + 추가 읽기 0 이다.** 2단계 도입으로 쿼리가 18~27 로 올라가 60 선에 **더 가까워졌다** — 전환 여유가 줄었다는 사실을 기록한다 |
| **F8** | **장바구니·결제 품절 검증** *(신규)* | **출시 전 점검 권장** | `soldOut` 을 읽는 곳이 점주 토글과 매장 화면 카드뿐이다. **장바구니·주문 생성·결제 어디에도 품절 검증이 없다** (§15.6d). 담은 뒤 품절된 메뉴가 결제까지 간다. 상세에서 `담기` 를 막는 것으로는 닫히지 않는다. 서버(CF) 측 주문 생성 검증이 정석 |
| **F9** | 상세 화면 `excluded`/삭제 처리 문구 정비 *(신규)* | 언제든 (소) | `_DeletedView` 가 "삭제됨" 과 "이 매장이 안 팖" 을 같은 화면으로 처리한다. 사용자에게는 다른 사건이다 |
| F1 / F3~F7 | 1차 §7 그대로 | — | **F1(매장 100건 절단, 승인 매장 80곳 트리거)이 여전히 가장 급한 후속이다.** 이번 개정은 그 절단을 건드리지 않았다 |

---

## 15.17 완료 기준 (2차)

- [ ] §15.0 U1 — `excluded` 메뉴가 검색 결과에 **나오지 않는다** (1차 L2 해소, 실데이터로 확인)
- [ ] §15.0 U2 — 메뉴 결과 탭이 U2 분기표 3행 그대로 동작한다
- [ ] `applyOverrideForCustomer` 가 **3곳 전부**에서 쓰이고, 어느 경로에도 머지 규칙 복제가 없다 (§15.2)
- [ ] **매장 화면 목록 회귀 없음** — 교체 전/후 동일 (단위 테스트 포함)
- [ ] **매장 화면 카드 가격 == 상세 가격** (개정 전에는 달랐다, §15.6a)
- [ ] 메뉴 상세에 품절 상태가 있고 `담기` 가 비활성이다 (§15.6b)
- [ ] **행이 사라지는 깜빡임이 없다** (R1, 느린 네트워크 확인)
- [ ] 첫 메뉴 검색 쿼리가 **1단계 17 + 2단계(일치 브랜드 매장 수)** 이고 **최악 27 을 넘지 않는다**
- [ ] `firestore.indexes.json` / `firestore.rules` **무수정** (§15.10)
- [ ] `design.md` / `implementation.md` / `test_report.md` **에 개정 절이 추가**됨 (1차 내용을 덮지 않음)
- [ ] `docs/backlog.md` 에 **F8(장바구니·결제 품절 검증)** 등재
- [ ] `flutter analyze` 무경고 / `flutter test` 통과
- [ ] FAIL 없음 또는 후속으로 분리
