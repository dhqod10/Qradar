# search_keyword_enhancement (검색 고도화) 기능 명세

## 개요

- 목적: 매장 검색을 **키워드 배열 비정규화(denormalization) + Firestore `array-contains-any`** 기반으로 전환해, "클라이언트가 전 매장을 받아 와서 걸러내는" 현재 구조의 **매장 수 상한(스냅샷 100건)** 한계를 없애고, 서버 측 질의로 확장 가능한 검색 기반을 만든다.
- 작업 유형: 기존 기능 수정 + 신규 데이터/CF 구조 추가 (파생 필드 1개 + CF 트리거 + backfill).
- 핵심 전제: **b안(키워드 배열 denormalization) 은 사용자 확정.** 본 spec 은 b안을 **MVP 범위로 최소 구현** 하고 확장 여지만 남긴다.
- 영향 범위:
  - 화면: customer 검색 화면 (`SearchPage`) — **레이아웃 변경 없음**, 결과 질의 경로만 교체. (UI 카피/빈 상태 문구 검토만)
  - Domain: `StoreEntity`(필드 1개 추가), `SearchStoresUseCase`(질의 방식 전환), Repository 인터페이스(검색 메서드 1개 추가).
  - Data: `StoreModel`(필드 매핑), `StoreRemoteDataSource`(array-contains-any 질의), `StoreRepositoryImpl`.
  - Presentation: `searchStoreResultsProvider` 재배선(스냅샷 파생 → 질의 기반 FutureProvider).
  - 공통 유틸: `SearchKeywordTokenizer`(신규, 순수 Dart) — 질의·색인 토큰화 **단일 진실원**.
  - Firebase: `stores/{id}.searchKeywords` 파생 필드, CF 트리거 2개 + backfill callable 1개, `firestore.rules` 가드, 단일 필드 인덱스.
  - 권한 / 환경: Rules 화이트리스트/create 가드 (파생 필드 클라이언트 쓰기 차단).
  - 테스트: Rules 하네스, 토크나이저 단위 테스트, backfill 멱등성.
- 비범위 (§1-비범위 참조): 메뉴 키워드 검색의 denormalization, 초성/오타/영한 혼용, 서버 정렬·페이지네이션, AND 매칭.

---

## 0. 결정 필요 (사용자 확인 — 권고안 포함)

> architect 는 아래를 **권고안대로 진행하는 것**을 전제로 spec 을 작성했다. 사용자가 다르게 결정하면 해당 섹션을 갱신한다.

| # | 결정 항목 | 권고안 | 짧은 트레이드오프 |
|---|---|---|---|
| **D1** | **지금 질의 경로까지 바꿀까?** 현재 매장 검색은 홈이 이미 불러온 스냅샷(≤100건)에서 **부분일치(substring)** 로 공짜로 걸러낸다(추가 읽기 0). 테스트 매장 1개 규모에선 `array-contains-any` 로 바꾸면 질의마다 읽기가 +1 생기고 substring 이 **prefix 매칭으로 바뀐다**(아래 D3). 이득은 매장이 **스냅샷 상한(100건)을 넘길 때** 비로소 나온다. | **데이터 기반(필드+CF+backfill)과 질의 경로를 이번에 함께 전환** 한다. 런칭 전에 end-to-end 로 한 번 검증해 두는 편이 낫고, 롤백 위험이 낮다. | 대안: 필드·CF·backfill 만 깔아 두고(groundwork) 질의는 스냅샷 substring 유지 → 매장이 100건에 근접하면 그때 질의만 스위치. "지금 당장 득이 없다" 가 걸리면 이 대안. |
| **D2** | **검색 대상 범위** | **매장 검색만** (매장명 + 브랜드명 + 메인카테고리 라벨). **메뉴명 검색은 denormalization 범위에서 제외**(Phase 2) — 현재 클라이언트 fan-out 메뉴 검색은 **그대로 유지**. | 메뉴까지 넣으면 collectionGroup 키워드 인덱스 + 브랜드/매장 메뉴 쓰기마다 CF 트리거가 필요해 CF 표면이 크게 는다. 테스트 규모에선 현재 fan-out 으로 충분. |
| **D3** | **토큰화 수준 (매칭 의미)** | **MVP: 공백분할 + 소문자 정규화 + 단어별 prefix + 공백제거 전체문자열 prefix.** 질의는 단어 분할 후 각 단어 정규화 → `array-contains-any`. | prefix 방식이라 "앞에서부터 타이핑"(아메→아메리카노)과 "붙여 타이핑"(아이스아메리카노)은 잡지만 **단어 중간 substring(메리카)·초성·오타는 못 잡는다**(현 substring 대비 약간의 후퇴). 전부 잡으려면 n-gram 폭증 → 과도설계. |
| **D4** | **키워드 쓰기 경로** | **CF 전담 파생** (`availableMainCategories` 패턴 준용): 클라이언트 쓰기 금지(화이트리스트 제외 + create 가드), CF 트리거가 산출, backfill 로 치유. | 대안은 geohash 처럼 "저장 시 클라이언트가 함께 쓰는 파생". 그러나 브랜드명은 매장 payload 에 없어(브랜드 문서 조회 필요) 클라이언트로는 불완전하고, 토크나이저를 Dart/TS 양쪽에 중복해야 하며 키워드 스터핑(경쟁사 검색어로 노출 위조) 여지가 생긴다. → CF 전담 권고. |
| **D5** | **인덱스 / 정렬·페이지네이션 조합** | **단일 필드 `array-contains-any` 만** (복합 인덱스 불필요). 승인(approved) 필터·거리 정렬은 **현행대로 클라이언트**. 검색 결과는 `.limit(N)` 로 캡, **서버 정렬/페이지네이션 없음**. | `where(status==approved)` 나 `orderBy` 를 질의에 넣으면 복합 인덱스가 필요해진다. store_list_pagination 의 geohash 거리순과 검색은 **별개 질의 경로**로 두고 섞지 않는다(섞으면 복합 인덱스+정렬 충돌). 과도 → 범위 밖. |
| **D6** | **backfill 방식** | admin callable **`backfillStoreSearchKeywords`** — `dryRun` 기본, 400건 청크 배치, `migrationHistory` 1건. `backfillAvailableMainCategories`/`backfillStoreGeohash` 구조 준용(멱등·상시 도구). landing/console '백필 도구' 페이지에 버튼 1개 추가(§작업분배 비고). | 대안 없음(기존 패턴 그대로). |

---

## 1. 현재 검색 구현 조사 결과 (코드 기준)

### 진입점과 데이터 흐름

- 화면: `lib/presentation/customer/search/search_page.dart` → 상태는 `search_providers.dart` 의 `searchViewModelProvider` 하나로 렌더.
- 질의 정규화: `lib/core/utils/search_normalizer.dart` — **`trim → 소문자 → 모든 공백 제거` 후 `contains`(부분일치)**. 매장·메뉴 검색이 모두 이 하나만 쓴다. 초성·오타·영한 혼용은 **현재도 비범위**(주석 §5.4).

### 매장 검색 (현재)

- `searchStoreResultsProvider` = `storeSnapshotProvider` **파생**(추가 읽기 0).
- `storeSnapshotProvider`(`home_providers.dart:112`) = `getApprovedStores(limit:100)` = `StoreRemoteDataSource.fetchAll(limit:100)` 1회. 홈·주변·필터·검색이 **전부 이 스냅샷 하나**에서 파생.
- 매칭: `SearchStoresUseCase.compute` — `name` + `address` 에 대해 `SearchNormalizer.matches`(정규화 후 **substring**). 이름 매칭이 주소 매칭보다 항상 위, 각 그룹은 거리 오름차순 보존.

### 메뉴 검색 (현재)

- `menuSearchIndexProvider`(세션 캐시) → 반경 내 가까운 상위 N개 후보 매장의 메뉴를 **출처 단위 1회 `get()`** fan-out (브랜드 마스터 `brands/{b}/menuItems` + 매장 `stores/{s}/menuItems`), `SearchNormalizer.matches(menuName)` 로 필터, 2단계 override 검증.
- 즉 메뉴 검색은 **이미 서브컬렉션을 질의**하지만 키워드 배열이 아니라 "메뉴명 substring" 이다.

### 홈 카테고리 필터와의 관계

- `get_stores_by_categories` / `filteredStoresProvider` = 같은 스냅샷에서 `availableMainCategories`(**CF 전담 파생**, `store_category_optout` Phase B) 를 `array-contains` 로(클라 측 `.any`) 필터. 검색과 독립.

### 한계 (명확화)

1. **매장 수 상한**: 검색은 스냅샷(`fetchAll(100)`)만 본다. **101번째 매장부터는 검색에 영원히 안 걸린다.** ← b안이 해결하는 핵심.
2. **부분일치는 되지만 공짜가 아니다**: substring 이 되는 이유는 전 매장을 클라이언트로 끌어와서다. 매장 수가 늘면 비용·지연이 선형 증가.
3. **초성·오타·영한 혼용 불가** (현재도 비범위).
4. **메뉴 검색 fan-out 비용**: 후보 매장 수에 비례해 읽기가 는다(별도 범위, 이번 비범위).

### 기존 파생필드 패턴 (준용 대상)

| 파생필드 | 쓰기 주체 | 근거 |
|---|---|---|
| `stores.position`(geohash) | **클라이언트 파생**(`StoreModel.positionField`, toFirestore 포함, 화이트리스트 `position`) | `location` 이 같은 payload 에 있고 비민감·자가입력 동급 |
| `stores.availableMainCategories` | **CF 전담**(`onStoreOwnMenuWritten` 등 5 트리거 + `backfillAvailableMainCategories`) + 화이트리스트 제외 + create 가드(`rules:354`) | 서브컬렉션/브랜드 교차 집계 + 검색 노출 위조 차단 |

→ `searchKeywords` 는 **브랜드명(교차 조회) 포함 + 노출 위조 차단**이 필요하므로 **`availableMainCategories` 패턴(CF 전담)** 을 따른다 (D4).

---

## 2. 요구사항

### 기능 요구사항

- [ ] F1. `stores/{id}` 에 파생 필드 `searchKeywords: string[]` 추가. 출처 = 매장명 + (가맹점이면) 브랜드명 + `menuCategories` 라벨. (D2)
- [ ] F2. 키워드 산출은 **CF 전담**: 매장 문서의 `name`/`brandId`/`menuCategories` 변경 시, 그리고 브랜드 `name` 변경 시(산하 매장 fan-out) 자동 재계산. (D4)
- [ ] F3. 토큰화는 `SearchKeywordTokenizer`(순수 Dart) **와 동일 규칙의 TS 구현**(CF) 이 산출. 규칙 불일치가 생기지 않도록 양쪽 규칙을 §4 에 **명문화**하고 양쪽에 동일 테스트 벡터를 둔다.
- [ ] F4. 매장 검색 질의를 `array-contains-any(searchKeywords, queryTokens)` 로 전환. (D1·D3·D5)
- [ ] F5. 승인 필터(approved)·거리 정렬·결과 재정렬(이름 매칭 우선)은 **클라이언트 유지**. (현행 동작 보존)
- [ ] F6. 기존 매장 소급: admin callable `backfillStoreSearchKeywords`(dryRun 기본, migrationHistory 1건). (D6)
- [ ] F7. 메뉴 검색(클라이언트 fan-out)은 **변경하지 않는다**. (D2)

### UI 요구사항

- [ ] U1. `SearchPage` 레이아웃·`SearchView` 상태 enum 은 **유지**. 결과 공급 provider 내부만 교체.
- [ ] U2. 빈 상태/에러 문구는 현행 재사용. 단, 매칭이 prefix 기반으로 바뀌어 "결과 없음" 빈도가 달라질 수 있으니 **문구 검토만**(디자이너 선택적).

### 상태 요구사항

- [ ] loading: 질의 debounce 후 질의 중(현 skeleton 재사용).
- [ ] error: 질의 실패 — `searchReadRetry`(1회 0.8초 재시도, permission-denied 즉시 에러) 정책 준용, `다시 시도` 버튼.
- [ ] empty: `array-contains-any` 결과 0건 → 기존 빈 상태.

---

## 3. 데이터 모델

### Entity — `StoreEntity`

- `searchKeywords: List<String>` (기본 `const []`). **읽기 전용 파생 필드.** 어떤 `toFirestore*` 맵에도 넣지 않는다. (`availableMainCategories` 와 동일 취급)

### Model — `StoreModel`

- `fromFirestore`: `data['searchKeywords']` → `List<String>`(whereType<String>, 부재 시 `const []`). (`availableMainCategories` 매핑과 동형)
- `fromEntity`/`toEntity`: 필드 전달.
- **`toFirestoreForCreate` / `toFirestoreForCoreUpdate` / `toFirestoreForOperationUpdate` / `toFirestoreForBrandCreate` 어디에도 넣지 않는다.** (CF 전담)

### Firestore — `stores/{id}.searchKeywords`

- 타입: `array<string>`, 정규화된 토큰 Set(중복 제거). 방어적 상한 `maxKeywords = 300`(초과 시 잘라내고 CF 로그).
- 쓰기 주체: CF (`recomputeStoreSearchKeywords`) + `backfillStoreSearchKeywords`. 클라이언트 쓰기 금지.

### 질의 토큰 (런타임, 저장 안 함)

- 입력 질의 → 공백분할 → 각 단어 `normalize`(trim·소문자) → 빈 토큰 제거 → 최대 10개(`array-contains-any` 값 상한 고려, Firestore 상한 30 이내 보수적) → `array-contains-any` 값 배열.

---

## 4. 토큰화 규칙 (SearchKeywordTokenizer — 단일 진실원)

> Dart(`lib/core/utils/search_keyword_tokenizer.dart`) 와 CF TS(`functions/src/searchKeywords.ts`) **두 구현이 반드시 동일 결과**. 동일 테스트 벡터를 양쪽에 둔다 (§작업분배/tester).

### 색인 토큰 생성 `buildKeywords(sources: List<String>) -> Set<String>`

각 source 문자열에 대해:
1. `trim` → 소문자화.
2. 연속 공백 1칸 정규화 후 **공백으로 단어 분할**.
3. 각 단어 `w`: `minPrefix(=1) .. w.length` 의 **prefix** 를 모두 추가. (예 `강남점` → `강,강남,강남점`)
4. 추가로 **공백 제거 전체 문자열** `full = 모든공백제거(소문자(source))` 의 `minPrefix .. full.length` prefix 를 추가. (예 `아이스 아메리카노` → `아,아이,…,아이스아메리카노`) — 현 `SearchNormalizer`(공백 제거 substring) 의 "붙여 타이핑" 을 보존.
5. 전부 한 `Set` 으로 합쳐 중복 제거. `maxKeywords` 초과 시 결정적 순서로 잘라낸다.

- `minPrefix = 1` 근거: 현재 매장 검색은 1글자(`shortWithStores`)부터 반응한다 — 보존하려면 1글자 prefix 필요. 비용은 Σ(단어 길이)+Σ(full 길이) 로 매장당 수십~수백 토큰 수준(1MB·배열 제약 내 안전).

### 질의 토큰 `queryTokens(raw: String) -> List<String>`

- `trim → 소문자 → 공백분할`, 각 단어 그대로(내부 공백 없음), 빈 것 제거, 최대 10개.
- 비교: `array-contains-any(searchKeywords, queryTokens)` = **질의 단어 중 하나라도** 매장 키워드에 있으면 히트(OR). 그 뒤 클라이언트가 재정렬(이름-prefix 매칭 우선, 거리 오름차순).

### 명시적 비범위 (현행과 동일)

- 단어 **중간** substring(`메리카`), **초성**(`ㅇㅇ`), **오타 교정**, **영한 혼용**. (`search_normalizer.dart` §5.4 와 일관)

---

## 5. 레이어 설계

### Domain

- Entity: `StoreEntity.searchKeywords: List<String>` 추가.
- UseCase:
  - `SearchStoresUseCase` — 순수 함수 유지하되 역할 분리:
    - `queryTokens(raw)` 위임(토크나이저).
    - `rankAndFilter({stores, rawQuery})` — 서버가 돌려준 후보 매장을 **이름-prefix 매칭 우선 → 주소/기타 → 거리순** 으로 재정렬(현 `byName`/`byAddress` 순서 규칙 보존). `isAddressOnlyMatch` 유지.
  - **I/O(질의)는 Repository 가 맡는다.** UseCase 는 순수.
- Repository Interface: `StoreRepository.searchStores({required List<String> queryTokens, required UserLocation location, int limit}) -> Future<List<StoreEntity>>` 추가. (approved 필터·거리 계산은 구현체에서 현행 헬퍼 재사용)

### Data

- `StoreModel`: §3 매핑.
- `StoreRemoteDataSource`: `searchByKeywords(List<String> tokens, {int limit})` — `collection('stores').where('searchKeywords', arrayContainsAny: tokens).limit(limit).get()`. (D5: 단일 필드, 복합 인덱스 불필요)
- `StoreRepositoryImpl.searchStores`: 질의 → `_filterApproved`(현행) → `_attachDistance`(현행) → 거리 오름차순 → `toEntity`. permission-denied → `PermissionDeniedException`(현행 패턴).

### Presentation

- `searchStoreResultsProvider` 재배선: `normalizedQueryProvider`(또는 신규 `storeQueryTokensProvider`) 를 watch 하는 **`FutureProvider.autoDispose`** 로 변경. 질의당 1회 읽기, `searchReadRetry` 정책 적용. 결과는 `SearchStoresUseCase.rankAndFilter` 로 재정렬.
  - (D1 대안 선택 시: 이 provider 는 그대로 스냅샷 파생 유지, 필드·CF·backfill 만 랜딩.)
- `SearchView`/`resolveSearchView`/`searchViewModelProvider`: **그대로**. (store/menu AsyncValue 를 받는 시그니처 불변)

### Firebase / CF

- `functions/src/searchKeywords.ts` — 공유 코어:
  - `tokenize(sources)` (Dart 와 동일 규칙), `recomputeStoreSearchKeywords(storeId, afterDoc?)`(매장명+브랜드명+카테고리 라벨 조립 → tokenize → 멱등 쓰기: 같은 값이면 skip), `recomputeBrandSearchStores(brandId)`(fan-out).
- 트리거 (`onSearchKeywordsSourceWritten.ts`, 소프트 freshness·에러 swallow·backfill 치유 — `onAvailableCategoriesWritten` 패턴):
  - `onStoreSearchSourceWritten` (`stores/{id}`): `name`/`brandId`/`menuCategories` diff 또는 생성 시에만 재계산. **`searchKeywords` 만 바뀐 쓰기는 무시(루프 가드)** — `onAvailableCategoriesWritten.storeDocNeedsRecompute` 와 동형 diff 게이트.
  - `onBrandSearchNameWritten` (`brands/{id}`): `name` 변경 시에만 산하 매장 fan-out.
- backfill: `backfillStoreSearchKeywords`(§0 D6). `index.ts` 에 export.
- 인덱스: `stores.searchKeywords` **단일 필드 array 인덱스는 자동 생성**(fieldOverrides 불필요). `firestore.indexes.json` 변경 없음(확인 필요 — 자동 인덱스로 충분). 복합 인덱스 추가 금지(D5).

### Rules (`firestore.rules` — stores 블록)

- create: `availableMainCategories` 가드(line 354) 바로 옆에 `&& !('searchKeywords' in request.resource.data)` 추가.
- update: 운영/핵심 화이트리스트에 `searchKeywords` **를 넣지 않는다** → `onlyChangedFields` 가 거부. (현행 `availableMainCategories` 와 동일 보호)
- audit §4-7 교차 확인: create 거부 + update 거부 + **정상 payload 회귀**(searchKeywords 없는 현 create/update 2종이 계속 통과) 케이스를 하네스에 둔다.

---

## 6. 데이터 흐름

```
[색인 쓰기]
  매장/브랜드 소스 변경 (name/brandId/menuCategories)
    → CF 트리거 (diff 게이트) → recomputeStoreSearchKeywords
    → tokenize(sources) → stores/{id}.searchKeywords 멱등 쓰기
  (누락/신규/정합) → admin backfillStoreSearchKeywords (dryRun→실행, migrationHistory 1건)

[검색 읽기]
  SearchPage 입력 → debounce → searchQueryProvider
    → queryTokens(raw)
    → searchStoreResultsProvider (FutureProvider)
    → StoreRepository.searchStores
    → StoreRemoteDataSource.searchByKeywords  [array-contains-any]
    → Firestore stores (단일 필드 인덱스)
    → 구현체: approved 필터 + 거리 계산/정렬
    → SearchStoresUseCase.rankAndFilter (이름 매칭 우선)
    → SearchView 렌더 (기존 enum)
```

---

## 7. 에러 처리

| 케이스 | 처리 |
|---|---|
| 질의 실패(일시) | `searchReadRetry` 1회(0.8초) 재시도 후 에러 → `s2StoreError`/`shortError`, `다시 시도` |
| permission-denied(비로그인) | `PermissionDeniedException` → 로그인 유도(현행) |
| 결과 0건 | 기존 빈 상태(`s5`/`s10` 등). prefix 매칭이라 "없음" 가능성 ↑ — 문구 검토(U2) |
| CF 트리거 누락 | 소프트 freshness: swallow + 다음 소스 변경/`backfill` 가 치유 (검색 노출은 돈·권한 아님) |
| 토크나이저 Dart↔TS 불일치 | 동일 테스트 벡터로 회귀 차단(§작업분배 tester) |
| 질의 단어 10개 초과 | 앞 10개만 사용(상한 보호) |

---

## 8. 이력 / 감사 추적 (audit_trail §4 체크리스트)

| # | 항목 | 판정 |
|---|---|---|
| 1 | 돈·권한·정책 값 변경? | **아니오.** `searchKeywords` 는 검색 색인 파생 필드 — 금액/권한/정책 아님. **설정 변경 이력 불필요(사유 명시).** 단 CF 전담 파생이므로 **클라이언트 쓰기 차단은 필수**(§5 Rules). |
| 2 | 덮어쓰기로 사라지는 값? | **없음.** `searchKeywords` 는 소스(name/brand/category)에서 **100% 재현 가능**(backfill 로 언제든 복원). 소실 우려 없음. (소스인 매장명 변경 이력 = A2, **이번 범위 밖**) |
| 3 | 기록이 정책 값을 참조만? | 해당 없음(거래 문서 아님). |
| 4 | "누가"? | backfill 은 `migrationHistory.executedBy = adminUid` 기록(기존 패턴). 트리거 산출물은 파생이라 행위자 개념 없음. |
| 5 | 일괄 처리? | `backfillStoreSearchKeywords` → `migrationHistory` 1건 + `total`/`affected`(기존 패턴). |
| 6 | CF 로그 의존? | backfill 결과는 Firestore(`migrationHistory`) 에 영구 기록. 트리거 실패는 소프트 freshness(로그 + backfill 치유)로 수용. |
| 7 | create/update 교차 확인? | searchKeywords 는 **create 가드 + update 화이트리스트 제외 + 정상 payload 회귀** 3종 하네스(§5). |

> 결론: **설정 변경 이력 없음 — 사유: 돈/권한/정책 값이 아니고, 소스에서 재현 가능한 검색 색인 파생이라 "언제 누가 왜 바꿨나" 의 증빙 대상이 아니다.**

---

## 9. 작업 분배

### designer — **선택적(권고: 생략 가능)**
- UI 레이아웃 변경 없음(`SearchPage`/`SearchView` 유지).
- 전달: prefix 매칭 전환으로 "결과 없음" 문구가 더 자주 노출될 수 있으니 **빈 상태 카피만 검토**. 신규 화면/흐름 없음 → design.md 는 "UI 변경 없음, 카피 검토만" 수준이면 충분.

### developer
- 구현 항목:
  1. `SearchKeywordTokenizer`(Dart, 순수) + 동일 규칙 TS(`searchKeywords.ts`).
  2. `StoreEntity`/`StoreModel` 필드 추가(읽기 전용, toFirestore 제외).
  3. `StoreRemoteDataSource.searchByKeywords` + `StoreRepository.searchStores` + 구현체.
  4. `SearchStoresUseCase`(queryTokens/rankAndFilter) + `searchStoreResultsProvider` 재배선(FutureProvider).
  5. CF 트리거 2개(`onStoreSearchSourceWritten`/`onBrandSearchNameWritten`) + 공유 코어 + `backfillStoreSearchKeywords` + `index.ts` export.
  6. `firestore.rules` create 가드 + 화이트리스트 유지(제외).
  7. `firestore.indexes.json`: 복합 인덱스 **추가하지 않음**(단일 필드 자동). 확인만.
- 재사용 기존 구조: `availableMainCategories`(CF 트리거·backfill·Rules 가드) 패턴, `backfillStoreGeohash`/`backfillAvailableMainCategories` 골격, `searchReadRetry`, `_filterApproved`/`_attachDistance`.
- 레이어 규칙: domain/presentation 에서 Firebase import 금지. 토크나이저는 순수 Dart. 파생 필드는 어떤 toFirestore 맵에도 넣지 않는다.
- 비고(연계): landing/console '백필 도구' 페이지(`landing/console/assets/console-data.js` 등)에 `backfillStoreSearchKeywords` 버튼 1개 추가(기존 geohash/availableMainCategories 버튼과 동형, dryRun 토글). **landing 수정은 별도 커밋 규칙 준수** — 본 작업과 분리 가능.

### tester
- 주요 검증: array-contains-any 질의 결과, 이름-prefix 매칭 우선 재정렬, 거리순, approved 필터 유지.
- 토크나이저 **Dart↔TS 동일 결과** 벡터(한글 공백분할/prefix/공백제거 full, 소문자, 중복제거, maxKeywords 상한).
- Rules 하네스: searchKeywords **create 거부 / update 거부 / 정상 payload 회귀**(§4-7).
- backfill: dryRun 쓰기 0, 멱등(두 번 실행 동일), migrationHistory 1건.
- 예외: 질의 실패 재시도/permission-denied, 결과 0건 빈 상태, 질의 단어 10개 초과.
- 회귀: 메뉴 검색(fan-out) 동작 **불변** 확인.

---

## 10. 완료 기준

- [ ] F1~F7 구현 또는 보류 사유 명시.
- [ ] 토크나이저 Dart/TS 동일 테스트 벡터 통과.
- [ ] Rules 하네스(create 거부/update 거부/정상 회귀) 통과.
- [ ] backfill dryRun/멱등/migrationHistory 검증.
- [ ] `design.md` 작성(또는 "UI 변경 없음, 카피 검토만" 명시).
- [ ] `implementation.md` 작성.
- [ ] `test_report.md` 작성, FAIL 없음(있으면 후속 분리).
- [ ] 메뉴 검색 회귀 없음.

---

## 부록 A. 확장 여지 (이번에 하지 않음)

- **Phase 2 메뉴 키워드 검색**: `brands/{id}/menuItems`·`stores/{id}/menuItems` 에 `searchKeywords` + collectionGroup array 인덱스 + 메뉴 쓰기 트리거. 현재 fan-out 을 대체.
- 초성/오타/영한 혼용(정규화 사전·자모 분해).
- 서버 정렬·페이지네이션(복합 인덱스, geohash 와 조합 시 재설계 필요 — D5).
- AND 매칭(현재 OR + 클라 재정렬).
- 외부 전문검색엔진(Algolia/Typesense) 로의 이관.
