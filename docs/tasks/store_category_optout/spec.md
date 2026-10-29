# store_category_optout 기능 명세

가맹점별(매장별) 메인 카테고리 노출 제외 — per-store main category opt-out

- 작성: architect
- 작성일: 2026-10-28
- 상태: 설계 완료 — §0.3 taxonomy 결정 **확정(A: 메인 카테고리로 통일)** 2026-10-28. Phase A·B 모두 진행.

---

## 0. 설계 전 반드시 읽을 것 (핵심 발견)

### 0.1 기능명 결정

요청대로 `store_category_optout` 유지. opt-out(제외 목록) 방식·매장(store) 단위·점주 제어라는 세 성격을 모두 담아 적합. 조정하지 않는다.

### 0.2 두 개의 서로 다른 카테고리 택소노미가 존재한다 (코드 확인)

이 기능의 모든 난점은 여기서 나온다. 코드에 **이름이 비슷하지만 전혀 다른 두 카테고리 체계**가 공존한다.

| | A. 메인 카테고리 (mainCategory) | B. 매장 검색 카테고리 (menuCategories) |
|---|---|---|
| 값 | `mainCategories/{id}` 문서 id = **코드** (`coffee` / `nonCoffee` / `dessert` / `bakery` …) | `MenuCategories.all` = **한글 마케팅 문자열 12개** (`추천메뉴` / `커피` / `푸드/디저트` / `MD상품` …) |
| 소유 | admin (전역 enum 기반) | 점주 수동 선택 (store_form_page / store_core_form_page 의 칩) |
| 저장 | `menuItem.mainCategoryCode` 가 참조 | `stores.menuCategories: List<String>` |
| 소비처 | 매장 메뉴 탭 (`storeAvailableMainCategoriesProvider`) | 홈/검색 "카테고리로 매장 찾기" 필터 (`filteredStoresProvider`, `getStoresByCategories`) |
| 파일 | `lib/domain/entities/main_category_entity.dart`, `main_category_providers.dart` | `lib/core/constants/menu_categories.dart`, `home_providers.dart:145`, `get_stores_by_categories_use_case.dart:27` |

**두 체계는 1:1로 매핑되지 않는다.** `추천메뉴` 같은 값은 메인 카테고리에 대응물이 아예 없고, seed 데이터(`phase1_seed_data.dart:104,261`)는 `menuCategories` 에 `['coffee','nonCoffee','dessert']` 라는 **코드값**을 넣어 둬서 — 점주 폼이 넣는 한글값과도 이미 불일치한다. 즉 `stores.menuCategories` 는 지금도 오염된 필드다.

> 사용자 확정 결정 4("기존 수동 `menuCategories` 를 '보유 메뉴 카테고리 자동 파생 − excludedMainCategories' 로 정렬")는 **두 택소노미를 하나로 통합**하는 것을 전제로 해야 성립한다. 자동 파생값은 B(한글) 가 아니라 A(코드) 체계이기 때문이다. 이는 홈 필터 칩 구성(마케팅 12종 → admin 메인 카테고리 3~4종)을 바꾸는 **제품/UX 결정**이다.

### 0.3 ✅ 택소노미 결정 — 확정 (2026-10-28, 사용자)

**검색 필터를 어느 택소노미로 통일할 것인가? → A(메인 카테고리)로 통일 확정.**

- **A(메인 카테고리)로 통일.** 홈/검색 칩을 `mainCategoriesActiveProvider` 의 label 로 바꾸고, 매장은 "보유 메뉴 mainCategoryCode ∩ active − excludedMainCategories" 를 검색용 파생 필드에 **CF 로 denormalize**. 매장 메뉴 탭과 검색이 같은 체계·같은 소스가 되어 결정 4("디저트 끈 매장은 디저트 검색에 안 뜬다")가 구조적으로 성립. 단일 진실원 달성.
- (기각) B(마케팅 12종) 유지 — excludedMainCategories(코드)와 교집합이 안 맞아 결정 4 불성립.

→ **Phase A·B 모두 진행.** `menuCategories` 는 폐기, 검색 칩은 admin 메인 카테고리로 통일. admin 은 메인 카테고리를 늘릴 수 있으므로(메인 카테고리 관리 화면) 검색 세분화가 필요하면 카테고리 추가로 대응한다.

### 0.4 함께 확정된 범위 경계 (2026-10-28, 사용자 논의)

- **서브 카테고리는 현행 유지** (브랜드/가맹점이 각자 관리, 중앙화 안 함). 근거: 서브 카테고리는 "매장 내 메뉴 구성(display)" 레이어이고 매장-교차 검색에 쓰이지 않는다(업계 표준: POS/메뉴 섹션은 가맹점 자율). 브랜드 내 일관성은 brand-scoped subCategories 공유로 이미 보장됨. **본 과제 범위 밖.**
- **메인 카테고리 소유권은 변경 없음** — 지금도 admin 전용(Rules). 브랜드/가맹점은 메뉴 등록 시 선택만. 본 과제는 "검색이 이 메인 카테고리를 쓰게 통일 + 매장별 opt-out 추가"일 뿐, 소유권 모델은 그대로.
- **검색 동의어(synonym) 레이어는 별도 backlog 과제.** 유저 어휘 다양성("탄산"으로 "에이드" 찾기)은 카테고리 중앙화로 풀리지 않고 메뉴명 검색 + 동의어 확장(Uber Eats query-understanding 방식)으로 풀어야 함. 본 과제 비범위.

---

## 1. 개요

- **목적**: 점주가 자기 매장에서 특정 메인 카테고리(예: 디저트)를 "안 판다"고 콕 집어 끌 수 있게 한다. 끈 카테고리는 매장 메뉴 탭에서 사라지고(= 그 카테고리 메뉴 전부 숨김), 브랜드가 나중에 그 카테고리 마스터 메뉴를 추가해도 다시 나타나지 않는다(sticky). 검색에서도 그 카테고리로는 노출되지 않는다.
- **작업 유형**: 신규 필드 추가 + 기존 파생 로직 수정 + (Phase B) 검색 택소노미 통합·마이그레이션
- **제어 주체**: 점주(owner). 브랜드/admin 강제 아님.
- **반영**: 즉시(운영 필드). admin 재승인 불필요.

### 역할 흐름 / 라이프사이클 상의 위치

- `role_flows.md` — owner 의 "매장 운영 정보 수정" 흐름(즉시 반영, status 무변동)에 **카테고리 on/off** 액션 1개 추가. customer 의 "매장 진입 → 메뉴 탭 탐색" 및 "홈/검색 카테고리 필터" 흐름의 결과 집합이 바뀐다.
- `entity_lifecycle.md` — store status 전이에 **영향 없음**. excludedMainCategories 는 운영 필드라 `approved` 유지, pending 회귀 없음. menuItem status 전이에도 영향 없음(카테고리 제외는 메뉴 문서를 건드리지 않고 "보임" 계산만 바꾼다).

### 영향 범위

- 화면: 점주 운영 폼(`store_operation_form_page.dart`)에 카테고리 토글 섹션 신규 / 매장 메뉴 탭 빈 상태 / (Phase B) 홈·검색 카테고리 칩
- Domain: `StoreEntity`(필드 1개), `UpdateStoreOperationFieldsUseCase`(필드 전달), (Phase B) `GetStoresByCategoriesUseCase`
- Data: `StoreModel`(매퍼 전체), `toFirestoreForOperationUpdate`, `store_remote_data_source`(operation update 맵), (Phase B) 검색 파생 필드 + CF
- Presentation: `storeAvailableMainCategoriesProvider`, `filteredMenuItemsProvider`, (Phase B) `filteredStoresProvider`·검색 providers
- 공통: `core/utils/store_menu_visibility.dart`(판정에 excluded 반영 검토)
- 라우팅: 변경 없음(기존 운영 폼 내 섹션)
- 권한/환경: `firestore.rules` stores update 화이트리스트 + CF-전담 필드, `data_ownership.md §2.5` 갱신
- 테스트: 파생 로직 단위테스트, Rules 하네스(create/update 교차), (Phase B) 마이그레이션

### 비범위

- 브랜드/admin 이 매장 카테고리를 **강제로** 끄는 기능 (결정 2: 점주 전용)
- opt-in(허용 목록) 방식 (결정 1: opt-out 만)
- per-item `menuOverrides.excluded` 의 동작 변경 (독립 유지 — §5)
- 메인 카테고리 자체(admin `mainCategories/{id}`) 의 CRUD
- 매장 운영 정보 변경 이력 전반(`audit_trail.md` A2) — §8 참조

---

## 2. 데이터 모델

### 2.1 신규 필드 (owner 쓰기, 운영 필드)

`stores/{storeId}`:

```
excludedMainCategories: List<String>   // 점주가 끈 메인 카테고리 코드 목록
```

- 값은 **A(메인 카테고리 코드)** 체계 (`'dessert'` 등). mainCategory 문서 id 와 동일.
- 기본값 = **빈 목록** = "메뉴가 있는 카테고리 전부 노출"(opt-out 기본). 부재도 빈 목록으로 해석(legacy 안전).
- sticky: 한 번 끄면 그 코드가 목록에 남아, 나중에 해당 카테고리 메뉴가 생겨도 계속 숨김.
- admin 이 그 카테고리를 전역 비활성화해도 목록에서 **제거하지 않는다**(dormant 보관). 재활성화 시 여전히 제외 상태 유지.

### 2.2 StoreEntity (domain)

```dart
@Default([]) List<String> excludedMainCategories,
```

- 위치: `imageUrls` / `notice` 등 운영 필드 묶음 옆.

### 2.3 StoreModel (data) — 4곳 모두 손본다

- 필드 선언 + 생성자 기본값 `const []`
- `fromFirestore`: `(data['excludedMainCategories'] as List?)?.whereType<String>().toList() ?? const []` (legacy 부재 → 빈 목록)
- `fromEntity` / `toEntity`: 패스스루
- `toFirestoreForOperationUpdate`: `'excludedMainCategories': excludedMainCategories` 추가 **(여기만)**
- `toFirestoreForCreate` / `toFirestoreForBrandCreate` / `toFirestoreForCoreUpdate`: **넣지 않는다**(운영 필드라 create 는 기본값, core update 는 무관). qoinAccrualRate 가 읽기전용으로 어느 맵에도 안 들어가는 것과 동일한 규율.

### 2.4 (Phase B) 검색용 파생 필드 — CF 전담 쓰기

`stores/{storeId}`:

```
availableMainCategories: List<String>   // = (보유 메뉴 mainCategoryCode ∩ active) − excludedMainCategories
```

- **CF 가 쓴다**(클라이언트 쓰기 금지). `averageScore`/`reviewCount` 가 `onReviewWritten` 전담인 것과 같은 집계 패턴. 근거: `data_ownership.md §3` — "A(메뉴/카테고리)가 쓴 문서로 B(store) 소유 문서의 집계값을 갱신하면 CF".
- 소비처: 검색/홈 필터. StoreModel 에 읽기 전용으로 추가, 어느 client `toFirestore*` 맵에도 넣지 않는다.
- `menuCategories` 는 이 필드로 **대체 후 제거**(§6 결정).

---

## 3. 레이어 설계

### Domain
- Entity: `StoreEntity.excludedMainCategories`
- UseCase: `UpdateStoreOperationFieldsUseCase` 재사용(새 UseCase 불필요 — 운영 필드 묶음에 합류). docstring 의 운영 필드 목록에 excludedMainCategories 추가.
- (Phase B) `GetStoresByCategoriesUseCase` / `filterByCategories` 가 `availableMainCategories` 를 보도록 수정.
- Repository Interface: 변경 없음(`updateStoreOperationFields` 그대로).

### Data
- Model: `StoreModel` 매퍼 4곳(§2.3) + (Phase B) `availableMainCategories` 읽기.
- DataSource: `store_remote_data_source.updateOperationFields` 는 맵을 그대로 쓰므로 코드 변경 없음(맵 생성은 모델이 담당). 확인만.
- Repository Impl: `updateStoreOperationFields` 변경 없음(모델 경유).

### Presentation
- `storeAvailableMainCategoriesProvider`(store_menu_providers.dart:154): 결과에서 `store.excludedMainCategories` 차집합. store doc 를 함께 watch 필요(현재 메뉴만 봄 — §4.1).
- `filteredMenuItemsProvider`(:192): `storeMains` 후보와 `effectiveMain` 폴백 계산 시 excluded 제외(§4.2).
- `store_operation_form_page.dart`: 카테고리 on/off 토글 섹션(designer 설계).
- (Phase B) `filteredStoresProvider`·검색 providers: 칩 소스와 필터 필드 교체.

### 데이터 흐름 (점주 토글 저장)

```text
store_operation_form_page (토글)
  → updateStoreOperationFieldsUseCaseProvider
  → UpdateStoreOperationFieldsUseCase
  → StoreRepository.updateStoreOperationFields
  → StoreRepositoryImpl
  → StoreRemoteDataSource.updateOperationFields (toFirestoreForOperationUpdate)
  → Firestore stores/{id}  (excludedMainCategories 즉시 반영)
      └─(Phase B) onStoreWritten / onMenuWritten CF → availableMainCategories 재계산
```

---

## 4. 매장 메뉴 탭 로직 (Phase A 핵심)

### 4.1 storeAvailableMainCategoriesProvider (store_menu_providers.dart:154)

현재: `(보유 메뉴 mainCategoryCode) ∩ active`. 변경:

```
available = (보유 메뉴 mainCategoryCode ∩ active) − store.excludedMainCategories
```

- store doc 를 provider 안에서 함께 참조해야 한다(현재 메뉴 stream 만 봄). `_storeRemoteDataSourceProvider` 기반 store watch/getById 로 excludedMainCategories 취득(이미 파일에 DS provider 존재). presentation 이 Firebase 직접 import 하지 않도록 **DataSource 경유 유지**.
- active stream 미도달 시 기존대로 보수적 처리.

### 4.2 filteredMenuItemsProvider (store_menu_providers.dart:192) — 선택 폴백

- `storeMains`(화면에 실제 보이는 메뉴의 카테고리 후보)에서 excluded 코드 **제거**.
- `effectiveMain` 규칙: 선택된 main 이 `storeMains`(excluded 반영 후)에 없으면 `null` 로 폴백(= 가용 카테고리 전체 노출). 이미 있는 "다른 매장에서 고른 카테고리 방지" 폴백과 동일 메커니즘에 excluded 한 겹 추가.
- 메뉴 자체 필터에도 `m.mainCategoryCode ∈ excluded` 이면 제외(이중 안전).

### 4.3 공통 판정 함수 검토

`isMenuShownOnStoreScreen(visible, mainCategoryCode, activeCategoryIds)` 에 excluded 를 **인자로 추가**할지, 호출부에서 차집합할지 결정 필요. 권장: 판정 함수에 `excludedCategoryIds` 인자 추가 — 매장 탭·검색 2단계(search_providers.dart:201)가 같은 함수를 쓰므로 "검색엔 걸렸는데 탭엔 없다"를 구조적으로 막는 기존 설계(F5) 를 유지하려면 한 곳에서 excluded 를 반영해야 한다. developer 가 두 호출부 동시 수정.

---

## 5. per-item menuOverrides.excluded 와의 계층 (요청 명시 항목)

- **카테고리 제외(coarser) 와 개별 메뉴 제외(finer)는 독립적으로 AND 동작한다.**
- 카테고리가 excluded → 그 카테고리 메뉴는 개별 override 와 무관하게 **전부 숨김**.
- 카테고리가 excluded 아님 → 개별 메뉴는 기존 `applyOverrideForCustomer`(store_menu_visibility.dart) 규칙대로. `override.status==approved && override.excluded` 면 그 1건만 숨김.
- 즉 "보임 = (카테고리 non-excluded) AND (per-item 규칙 통과)". 두 레이어는 서로를 덮어쓰지 않는다. 카테고리 제외는 메뉴 문서/override 를 건드리지 않으므로, 점주가 카테고리를 다시 켜면 개별 override 상태 그대로 복원된다(sticky 하지만 비파괴적).

---

## 6. menuCategories 처리 결정 (요청 명시 항목)

**결정: 대체 후 제거(replace & retire).** (단, 최종 실행은 §0.3 taxonomy 결정에 종속 → Phase B)

| 옵션 | 판정 |
|---|---|
| 유지 | ❌ 결정 4 불충족(교집합 택소노미 불일치) + 이미 오염된 수동 필드 |
| 대체 | ✅ `availableMainCategories`(CF 파생, A 체계)로 대체. 검색=탭 단일 소스 |
| 제거 | ✅ 대체 완료·마이그레이션 후 `menuCategories` 및 점주 수동 칩 삭제 |

근거:
- `menuCategories` 는 (a) 매장 메뉴 탭과 다른 택소노미라 불일치 소스이고 (b) 점주 수동 관리라 실제 메뉴와 어긋나며 (c) seed 와 폼이 서로 다른 값(코드 vs 한글)을 넣어 이미 오염. 단일 진실원 원칙상 "보유 메뉴에서 파생"이 옳다.
- 파생 소유권은 **CF**. 검색은 매장 목록만 로드하고 메뉴를 로드하지 않으므로(store_repository_impl.fetchAll) 매장 문서에 denormalize 가 불가피하고, 여러 쓰기 경로(브랜드 마스터 메뉴 추가·점주 메뉴 CRUD·admin 카테고리 비활성·excluded 변경)가 소스를 바꾸므로 클라이언트-쓰기-시점 파생은 누락 위험이 크다.

### 마이그레이션 필요 여부: **필요 (Phase B, 1회성 CF 콜러블)**

- 이유: 기존 `menuCategories` 는 믿을 수 없고(오염), `availableMainCategories` 는 신규 필드라 기존 매장에 없음.
- 방법: **CF 마이그레이션 콜러블**(admin 트리거). 각 store 에 대해 `(보유 메뉴 mainCategoryCode ∩ active) − excludedMainCategories` 계산 후 `availableMainCategories` set. 클라이언트 파생 재계산은 매장별 메뉴 다건 읽기라 부적합.
- 감사(`audit_trail.md §4-5`): 마이그레이션은 `migrationHistory/{autoId}` 에 **1건 + 영향 매장 수(affected)** 기록. 기존 M1·M2·가격감사 도구와 동일 관행.
- 순서: ① 신규 CF 트리거(availableMainCategories 유지) 배포 → ② 백필 콜러블 1회 → ③ 검색/홈을 availableMainCategories 로 전환 → ④ `menuCategories` 및 점주 수동 칩 제거.

---

## 7. Firestore Rules / 권한 (요청 명시 항목)

### 7.1 변경

- `excludedMainCategories` 를 **owner 운영 필드 화이트리스트에 추가** — `isStoreOwnerFieldUpdate`(firestore.rules:361 `onlyChangedFields` 목록) 와 `isStoreOwnerBrandUpdate`(:399) **양쪽**. 점주·브랜드홀더가 즉시 쓰기 가능, status 무변동.
- (Phase B) `availableMainCategories` 는 **CF 전담**. 어떤 owner/brand 분기 화이트리스트에도 넣지 **않는다**(목록에 없으면 `onlyChangedFields` 가 거부 → 클라이언트 쓰기 차단). `averageScore`/`reviewCount` 와 동급.
- 핵심 필드/승인 메타(`status`/`approvedBy`/`approvedAt`/`rejectedReason`)·Qoin 보호 필드 집합과 **분리** 유지. excludedMainCategories 는 `touchesQoinManaged()` 와 무관.

### 7.2 audit §4-7 교차 확인 (create vs update)

- `onlyChangedFields` 는 **update 전용**. `excludedMainCategories` 는 권한 판정 입력이 아니므로 create 악용 위험은 낮지만, Rules 하네스에 **create 케이스**(create payload 에 포함 시 거부되지 않고 기본 동작)와 **정상 update 허용 회귀 케이스**를 각각 1건 둔다.
- `availableMainCategories`(Phase B)는 결제·권한 판정에 쓰지 않으므로 게이트 입력 아님. 그래도 **create 에 클라이언트가 임의 주입하지 못하도록** create 가드 1건 추가(검색 노출 위조 방지).

### 7.3 data_ownership.md §2.5 갱신 지점 (명시)

- update 화이트리스트 문자열에 `excludedMainCategories` 추가.
- "Cloud Function 전담" 행에 `availableMainCategories` (`onStoreMenuAggregated` 류 트리거) 추가 — `averageScore`/`reviewCount` 옆.
- 개인/가맹 매장 공통 적용임을 주석.

---

## 8. 이력 / 감사 추적 (audit_trail.md §4 체크리스트)

| # | 항목 | 판정 |
|---|---|---|
| 1 | 돈·권한·정책 값을 바꾸는가 → 설정 변경 이력 기본값 | excludedMainCategories 는 **매장 노출 운영 토글**(temporaryClosed/isOpen 과 같은 class). 돈·권한·정책 값 아님. **전용 변경 이력 미도입** — 사유: `audit_trail.md A2`("매장 운영 정보 변경 이력") 가 아직 미설계 버킷이고, 이 필드는 그 버킷 소속. A2 설계 시 함께 편입 권고. (돈/discoverability 영향은 있으나 점주 self-service·가역·본인 UI 가시) |
| 2 | 덮어쓰기로 사라지는 값 | excludedMainCategories 는 목록 덮어쓰기. 손실 민감도 낮음(점주가 자기 UI 에서 재확인·복구 가능). #1 과 동일 처리 |
| 3 | 기록 문서가 정책 값을 참조만 하는가 | 해당 없음(거래/기록 문서 미생성) |
| 4 | "누가" 기록 | 운영 필드라 전용 이력 없음(#1). Phase B CF 쓰기는 `changedBy`=시스템 |
| 5 | batch/마이그레이션 | Phase B 백필 → `migrationHistory` 1건 + `affected`(§6) |
| 6 | CF 로그 의존 | 백필 근거를 Cloud Logging 아닌 `migrationHistory`(Firestore)에 영구 기록 |

> 거래 이력과 설정 변경 이력은 다르다(§2). 이 기능은 거래를 만들지 않고, 설정 변경 이력은 A2 버킷으로 명시 보류한다. **보류 사유를 spec 에 남겼다.**

---

## 9. 작업 분배

### Phase A — opt-out 필드 + 매장 메뉴 탭 (taxonomy 결정과 독립, 바로 진행 가능)

#### designer — **호출 필요**
- 사유: 점주 운영 폼에 **신규 UI 섹션**(카테고리 on/off 목록). 기존 폼에 없는 컴포넌트.
- 산출물: `design.md` — 카테고리 토글 목록(스위치 or 체크박스), "끄면 손님에게 이 카테고리가 안 보여요" 안내, 전부 끈 경우 경고, 매장 메뉴 탭 **빈 상태(모든 카테고리 제외)** UI.
- 전달: 색상 `AppColors` 만. 기존 `_InstantNoticeBanner`/`_TemporaryClosedToggle` 톤 재사용. 토글 목록 소스 = `mainCategoriesActiveProvider`(label 표시, code 저장).

#### developer — designer 후 호출
- StoreEntity/StoreModel(§2.2–2.3), UpdateStoreOperationFieldsUseCase docstring
- `storeAvailableMainCategoriesProvider`·`filteredMenuItemsProvider`·`isMenuShownOnStoreScreen` excluded 반영(§4)
- `store_operation_form_page.dart` 토글 섹션
- `firestore.rules` 두 화이트리스트에 excludedMainCategories 추가(§7.1) + 하네스 케이스(§7.2)
- 재사용: 운영 필드 저장 경로 전체(새 UseCase/Repo 메서드 금지). 레이어 규칙: presentation 은 DataSource 경유로 store 읽기(Firebase 직접 import 금지).

#### tester — developer 후 호출
- excluded 차집합 단위테스트(탭 available / filtered / 폴백)
- 엣지(§10) 전부
- Rules 하네스: excludedMainCategories update 허용 + 정상 payload 회귀 + create 케이스
- 즉시 반영(재승인 없음, status 무변동) 확인

### Phase B — 검색 일관화 (§0.3 taxonomy 결정 확정 후)

- developer: `availableMainCategories` 파생 CF(트리거) + 백필 콜러블(`migrationHistory`) + 검색/홈 칩·필터 교체 + `menuCategories` 제거
- tester: 마이그레이션 before/after, "디저트 끈 매장이 디저트 검색에 안 뜸", 홈 칩 교체 회귀
- designer: 홈/검색 칩이 마케팅 12종 → 메인 카테고리로 바뀌는 UX 재검토(칩 라벨/개수 변화)

---

## 10. 에러 / 엣지 처리

| 케이스 | 처리 |
|---|---|
| 제외한 카테고리에 나중에 메뉴가 생김(브랜드 마스터 추가) | sticky — 계속 숨김. 재노출하려면 점주가 토글 off. (기능의 핵심 의도) |
| 제외한 카테고리의 메뉴가 전부 사라짐 | excluded 코드는 그대로 보관(dormant). 무해, 재등장 시 다시 숨김 |
| admin 이 그 카테고리를 전역 비활성화 | active 교집합에서 이미 빠짐. excluded 목록은 유지 → 재활성화해도 제외 상태 보존 |
| 전 카테고리를 다 끔(빈 메뉴 화면) | 매장 메뉴 탭 **빈 상태 UI**(designer). 매장은 이름/주소 검색·주변 매장으론 여전히 도달 가능. 검색 카테고리 매칭만 0 |
| 보고 있던 선택 카테고리가 방금 제외됨 | `filteredMenuItemsProvider` 폴백: 선택 main 이 가용 집합(excluded 반영)에 없으면 null → 가용 전체 노출(§4.2) |
| legacy 매장(필드 부재) | 빈 목록 해석 = 전부 노출(기존 동작 보존) |
| 개인(비가맹) 매장 | **동일 필드 적용**(일관성). 개인 매장도 자기 메뉴 카테고리를 끌 수 있음. 의미는 약하지만 코드 분기 없이 단일 경로 유지 |

---

## 11. 완료 기준

- [ ] (Phase A) excludedMainCategories 운영 필드로 즉시 반영, status 무변동
- [ ] (Phase A) 매장 메뉴 탭에서 제외 카테고리·그 메뉴 전부 숨김, 폴백 정상
- [ ] (Phase A) per-item 제외와 독립 동작(§5)
- [ ] (Phase A) Rules 두 화이트리스트 + 하네스(update 허용/회귀/create) 통과
- [ ] (Phase A) `design.md` / `implementation.md` / `test_report.md` 작성
- [ ] (Phase B, taxonomy 결정 후) availableMainCategories CF + 백필(migrationHistory) + 검색/홈 전환 + menuCategories 제거
- [ ] audit §4 체크리스트 6항목 통과(설정 변경 이력 보류 사유 명시 — §8)
- [ ] FAIL 없음 또는 후속 분리
