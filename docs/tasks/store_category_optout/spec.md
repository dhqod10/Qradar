# store_category_optout 기능 명세

가맹점별(매장별) 메인 카테고리 노출 제외 — per-store main category opt-out

- 작성: architect
- 작성일: 2026-10-28
- 상태: Phase A **구현·배포 완료**(커밋 e6f889f, firestore.rules 배포). Phase B **상세 설계 확정 — §12** 2026-10-29. developer 착수 대기.

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

---

## 12. Phase B 상세 설계 (검색 택소노미 통합 · menuCategories 은퇴 · CF 파생) — 확정 2026-10-29

Phase A(가맹점별 메인 카테고리 노출 제외)는 이미 구현·배포 완료다. Phase B 는 "검색이 쓰는 택소노미를 메인 카테고리(A 체계)로 통일(§0.3)" 을 이행한다. 아래 §12.1~§12.9 는 developer 가 플래그한 미결 설계 결정(implementation.md §미구현/보류)을 모두 확정한다.

### 12.0 전제 — availableMainCategories 의 freshness 등급은 "soft" 다 (설계를 가르는 핵심 통찰)

**이 필드를 소비하는 곳은 홈 "카테고리로 매장 찾기" 칩 필터 하나뿐이다.** 매장 메뉴 탭과 메뉴명 검색은 **Phase A 에서 이미** `excludedMainCategories` 를 클라이언트에서 즉시 반영한다(store doc watch 차집합 + `isMenuShownOnStoreScreen(excludedCategoryIds)`). 따라서:

- `availableMainCategories` 가 잠시 stale 해도 **매장 진입 시 탭은 항상 정확**하다(Phase A). 최악은 "방금 디저트를 끈 매장이 홈의 '디저트' 필터에 잠깐 더 뜬다" — 들어가면 디저트 탭은 없다. **자기교정되는 발견(discovery) 지연**이지 돈·권한·정합성 게이트가 아니다.
- 그러므로 **초단위 즉시성이 불필요**하다. 이 등급 차이가 fan-out 비용 전략을 정한다(아래 §12.1). 반대로 Phase A 의 store-local 즉시성은 이미 확보돼 있어 Phase B 가 끌어내릴 필요가 없다.

> 결제 게이트(`verifyTossPayment` canSellNow / 금액 게이트)는 이 필드를 **읽지 않는다.** 검색 노출용 파생값이므로 권한·금액 판정 입력이 아니다(§12.6).

### 12.1 결정 1 — availableMainCategories 파생 소스 설계 (fan-out)

#### 12.1.1 저장 위치 — `stores/{storeId}.availableMainCategories` 필드 (별도 문서 아님) ✅

- 근거: 검색/홈은 `store_repository_impl.getStoresByCategories` / `filteredStoresProvider` 가 **매장 문서만** 로드(`fetchAll`)하고 메뉴를 로드하지 않는다. 읽는 문서에 denormalize 하면 **검색 시점 추가 읽기 0**. `averageScore`/`reviewCount`(`onReviewWritten`)와 **동일 패턴**.
- 별도 문서(예: `stores/{id}/derived/categories`)는 검색이 매장당 문서 1건을 더 읽어야 해 fan-out 읽기만 늘고 이득이 없다. 기각.
- 값 체계 = **A(메인 카테고리 코드)**. mainCategory 문서 id 와 동일(`'coffee'`/`'dessert'`…).

#### 12.1.2 파생식 (단일 진실원 = `MenuItemRepositoryImpl.watchByStore` 의 머지 규칙)

```
availableMainCategories(store)
  = { visibleMenu.mainCategoryCode
        | visibleMenu ∈ watchByStore(store) }     # 개인: stores/{s}/menuItems · 가맹: 마스터+override 머지 ∪ store-scope
    ∩ activeMainCategoryIds                        # mainCategories active == true
    − store.excludedMainCategories                 # Phase A 운영 필드(점주 opt-out)
```

- "visible menu" 판정은 **이미 TS 포팅이 존재**한다 — `functions/src/menuVisibility.ts applyOverrideForCustomer` / `classifyCartMenu`(override.excluded=제외, status 분기 포함). **재포팅 금지, 재사용**(payment_price_authority 가드 5 와 동일 규율: 판정은 이 파일 1곳).
- 신규 순수 함수 `functions/src/availableCategories.ts` → `computeAvailableMainCategories({ storeOwnMenus, brandMasterMenus, storeOverrides, activeCodes, excludedByStore }): string[]`. `applyOverrideForCustomer` 를 import 해서 각 마스터 메뉴의 노출 여부를 판정하고, 살아남은 메뉴의 `mainCategoryCode` 를 모아 ∩active −excluded. **Dart `watchByStore` 머지 시맨틱을 그대로 미러**(개인/가맹 분기 포함). 단위 테스트 대상(읽기 0 순수).

#### 12.1.3 소스 → 트리거 → 재계산 범위 매트릭스

| # | 바뀌는 소스 | 트리거(신규) | 재계산 범위 | 비용 |
|---|---|---|---|---|
| ① | 브랜드 마스터 메뉴 (`brands/{b}/menuItems/{id}`) 추가/삭제/`mainCategoryCode` 변경/승인·visible 변경 | `onBrandMasterMenuWritten` (`onDocumentWritten`) | **관련성 diff 통과 시에만** `brandId==b` 매장 전체 fan-out | 중 (diff 게이트로 희소화) |
| ② | store menuOverride (`stores/{s}/menuOverrides/{id}`) | `onStoreMenuOverrideWritten` | 매장 s 1건 | 저 |
| ③ | store.excludedMainCategories (Phase A 필드) | `onStoreOptoutWritten` (`stores/{s}`) | 매장 s 1건 | 저 |
| ③' | store 자기 메뉴 (`stores/{s}/menuItems/{id}`, 개인 매장 또는 store-scope 메뉴) | `onStoreOwnMenuWritten` | 매장 s 1건 | 저 |
| ④ | mainCategories active 토글 (`mainCategories/{id}`, admin) | `onMainCategoryActiveWritten` | **active 플립 시에만** 전 매장 fan-out | 고 (극히 희소) |

재계산 단위 함수 `recomputeStore(storeId)`:
1. store doc 읽기(brandId / excludedMainCategories) — 트리거 payload 로 이미 있으면 재사용.
2. active mainCategory id 집합 — 호출당 1회 읽어 캐시(`mainCategories` where active).
3. store 자기 `menuItems` 서브컬렉션 읽기.
4. brandId 있으면 `brands/{b}/menuItems`(마스터) + `stores/{s}/menuOverrides` 읽기 — 마스터는 **브랜드 fan-out 1회당 1번 읽어 매장 루프에서 공유**.
5. `computeAvailableMainCategories(...)` → `availableMainCategories` 계산.
6. **계산값 == 저장값이면 write 생략**(churn·트리거 재발화 방지), 다르면 `stores/{s}.update({availableMainCategories})`.

#### 12.1.4 멱등 / 정합성 / 루프 안전

- **루프 가드(③ 핵심)**: `onStoreOptoutWritten` 는 자신이 `stores/{s}.availableMainCategories` 를 되쓰므로 재발화한다. `onMenuPriceWritten` 의 diff 패턴처럼 **소스 필드(`excludedMainCategories`·`brandId`)가 바뀐 경우에만** 진행하고, `availableMainCategories` 만 바뀐 diff 는 즉시 return. 추가로 §12.1.3-6 의 "같으면 write 생략" 이 2차 방어.
- **①④ diff 게이트**: ① 은 before/after 의 `mainCategoryCode`·존재(생성/삭제)·승인/visible 가 **카테고리 집합에 영향 없으면 return**(가격·이름만 바뀐 편집은 fan-out 안 함 → 대부분 편집이 무비용). ④ 는 `active` 필드가 **실제 플립**된 경우에만 진행.
- **전량 재계산 = 멱등**: `recomputeStore` 는 증분이 아니라 소스에서 다시 계산하므로 `onReviewWritten` 처럼 시드 오염·누락이 자기교정되고 재전달(at-least-once)에 안전.
- **배치**: fan-out 쓰기는 400건 청크 배치(`migrateStoreApprovalMeta` 패턴). 타임아웃 `timeoutSeconds` 상향.
- 실패는 `console.error` 후 swallow(트리거 재시도 폭주 방지) — freshness soft(§12.0)라 수용. 누락은 다음 소스 변경 또는 백필(§12.2)이 치유.

#### 12.1.5 fan-out 비용 상한 · 가맹점 수 가정 (⚠️ 사용자 확인 필요 — §12.9)

- **가정(현 단계 규모)**: 브랜드당 가맹점 ≤ 약 50, 전 매장 ≤ 약 500, 매장당 메뉴·override 각 ≤ 약 200.
- 최악 비용:
  - ① 카테고리-관련 마스터 메뉴 편집 1건: `N가맹점 × (자기메뉴 읽기 + override 읽기)` + 마스터 1회. 50점 기준 수천~1만 읽기. **diff 게이트로 "카테고리 집합을 바꾸는 편집"에만 발생**(가격·이름 편집은 0).
  - ④ admin 카테고리 active 토글 1건: **전 매장**. 500점 기준 수만 읽기. **운영상 극히 드묾**(이미 확인 다이얼로그가 있는 무거운 admin 액션).
- **규모가 가정을 넘으면(예: 브랜드당 수백 가맹)**: 아래 §12.1.6 대안 C(디바운스 스케줄러 + dirty 플래그)로 전환. 본 설계는 그 전환이 가능하도록 `recomputeStore` 순수화 + 백필 콜러블을 동일 코어로 재사용한다.

#### 12.1.6 대안 비교 (권고안 = 트리거 + 백필 하이브리드)

| 안 | 내용 | 판정 |
|---|---|---|
| **A (권고)** | 이벤트 트리거(store-local 즉시 + ①④ diff게이트·청크 fan-out) + 백필(시드·정합) | ✅ store-local 비용 저, ①④ 는 diff 로 희소화. 현 규모에 적합. soft freshness 와 정합 |
| B | 읽기 시점 계산 유지 + 검색 전용 인덱스 분리 | ❌ 검색은 매장 문서만 로드(메뉴 미로드) → 매장별 메뉴 다건 읽기 불가피. §6 에서 이미 기각된 경로 |
| C | 트리거 없이 **주기적(스케줄) 재계산**만 | △ fan-out 동기 비용 없음·단순. staleness=주기. **soft freshness 라 성립.** 규모 초과 시 A 의 fallback 으로 채택(①④ 를 dirty-flag + 디바운스로 대체) |

**권고: A.** store-local(②③③')는 트리거로 즉시, ①④는 diff 게이트 + 청크 배치로 비용을 묶는다. 규모 가정(§12.1.5)이 깨지면 ①④ 트리거만 C(브랜드/전역 dirty 마킹 → 5~15분 디바운스 스케줄 재계산)로 바꾸고 나머지는 유지 — `recomputeStore` 가 순수 코어라 전환이 국소적이다.

### 12.2 결정 2 — 백필(backfill) 마이그레이션

- 신규 **admin 전용 callable** `backfillAvailableMainCategories` (`onCall`, `requireAdmin`, `qoinAdmin.ts` 헬퍼 재사용). `migrateStoreApprovalMeta` 구조를 그대로 따른다.
- `{ dryRun?: boolean = true }` — **dryRun 기본**. dryRun 은 쓰기 0, 각 매장의 `before`(현 저장값 또는 부재)/`after`(계산값)/변경 건수를 리포트.
- 실행: 전 매장을 `recomputeStore` 코어로 계산 → 400건 청크 배치 update → `migrationHistory/{autoId}` **1건** + `affected`(변경된 매장 수)·`total`(전체 수) 기록(audit §4-5/§4-6, `migrationHistory` 는 Cloud Logging 아님).
- **시드 + 정합 재사용**: 신규 매장이 아직 트리거를 안 탔거나 트리거 누락이 의심될 때 다시 돌려도 멱등(전량 재계산).
- 임시 자산 아님(상시 정합 도구) — `auditOrderPriceIntegrity` 처럼 삭제 예정이 아니라, 운영 중 재조정용으로 보존. (판단은 developer 가 index.ts 주석에 명시.)

### 12.3 결정 3 — Rules 가드 + data_ownership §2.5 갱신

- `availableMainCategories` 는 **CF 전담 파생 필드.** 클라이언트가 `stores` **create/update** 로 주입 못 하게 차단:
  - **update**: owner/brand 운영 필드 화이트리스트(`isStoreOwnerFieldUpdate` / `isStoreOwnerBrandUpdate`)에 **넣지 않는다** → `onlyChangedFields` 가 거부. (`averageScore`/`reviewCount` 와 동급.)
  - **create**: `stores` create 분기에 `!('availableMainCategories' in request.resource.data)` 가드 1건 추가 — 검색 노출 위조 방지(§7.2 의 create 가드 방침, audit §4-7 상시 항목: create 는 `onlyChangedFields` 로 보호 안 됨).
- **data_ownership.md §2.5 갱신**:
  - `stores` "Cloud Function 전담" 행에 **`availableMainCategories`** 추가(`averageScore`/`reviewCount` 옆). 트리거 주체 = `onStoreOwnMenuWritten`/`onStoreMenuOverrideWritten`/`onStoreOptoutWritten`/`onBrandMasterMenuWritten`/`onMainCategoryActiveWritten` + `backfillAvailableMainCategories`.
  - §3 Cloud Function 카탈로그에 위 5 트리거 + 백필 콜러블 1행씩 추가.
- 이 필드는 결제·권한 판정 입력이 **아니므로** Qoin 보호 필드 집합·`touchesQoinManaged()` 와 무관, 핵심/승인 메타와도 분리.

### 12.4 결정 4 — 클라이언트 전환 (menuCategories → 메인 카테고리)

| 대상 | 현행 | 전환 후 |
|---|---|---|
| 홈 "카테고리" 칩 (`category_filter_section.dart` + `selectedCategoriesProvider`) | `MenuCategories.all` 12종(한글 마케팅 문자열) | `mainCategoriesActiveProvider` 의 카테고리 — **표시=label, 저장/비교=code(id)** |
| 홈 필터 (`filteredStoresProvider` → `GetStoresByCategoriesUseCase.filterByCategories`) | `store.menuCategories.any(selected.contains)` | `store.availableMainCategories.any(selectedCodes.contains)` |
| 매장 찾기 (`store_repository_impl.getStoresByCategories`) | `m.menuCategories.any(...)` | `m.availableMainCategories.any(...)` |
| 점주 수동 카테고리 칩 (`store_form_page`/`store_core_form_page` 의 menuCategories 선택) | 점주가 수동 선택 | **제거** (파생으로 대체) |
| `stores.menuCategories` 필드 | create/coreUpdate/brandCreate 맵에 존재 | **제거 (2단계: deprecate → 제거)** — 아래 |

- `selectedCategoriesProvider` 초기값(`{MenuCategories.defaultSelected='추천메뉴'}`)은 메인 카테고리에 대응물이 없다 → 초기 선택을 **"전체(빈 선택 = 필터 없음)"** 또는 active 목록의 첫 코드로 재정의. `filterByCategories` 는 빈 선택 시 현재 `const []` 반환이므로, 홈 기본 노출을 "전체 매장" 으로 바꾸려면 빈 선택 의미를 "필터 없음"으로 바꿀지 **UX 결정**(designer/§12.9).
- `StoreModel`: `availableMainCategories` **읽기 전용** 추가(`fromFirestore` 부재→`[]`, 어떤 `toFirestore*` 맵에도 넣지 않음). `menuCategories` 는 **2단계 제거**:
  1. (전환 배포) 소비처를 `availableMainCategories` 로 모두 옮기고, 점주 수동 칩·write 경로 제거. `menuCategories` 는 읽기만 남겨 **deprecate**(아직 문서에 남은 레거시 값 무해).
  2. (후속 정리) `StoreModel`/`StoreEntity` 에서 필드 제거 + create/coreUpdate/brandCreate 맵에서 제거 + data_ownership §2.5 update 화이트리스트에서 `menuCategories` 삭제. 별도 정리 커밋.

### 12.5 결정 5 — 배포 / 전환 순서 (안전) — CF 배포는 **사용자(운영) 수행**

⚠️ CF·Rules 배포는 **프로덕션 반영**이라 사용자가 수행한다(운영 조치). 코드만 먼저 머지하면 배포 전까지 홈 필터가 깨지므로 순서를 고정한다.

1. **(developer)** CF 5 트리거 + `recomputeStore`/`computeAvailableMainCategories` 코어 + 백필 콜러블 + Rules create 가드 구현·머지. **클라이언트 소비처는 아직 `menuCategories` 그대로**(이 커밋은 홈을 깨지 않는다).
2. **(사용자)** `firebase deploy --only functions` — 5 트리거·백필 콜러블 배포. 이 시점부터 모든 소스 변경이 `availableMainCategories` 를 유지.
3. **(사용자)** 백필 콜러블 `{dryRun:true}` → 리포트 확인 → `{dryRun:false}` 실행. 전 매장에 `availableMainCategories` 시드 + `migrationHistory` 1건.
4. **(사용자)** `firebase deploy --only firestore:rules` — create 가드 반영(트리거가 쓰는 필드라 Rules 와 무관하게 CF 는 Admin SDK로 우회하지만, 클라 주입 차단을 위해 배포).
5. **(developer→사용자)** 클라이언트 전환 커밋(§12.4 1단계: 홈/검색 칩·필터를 `availableMainCategories`·메인 카테고리로 교체, 점주 수동 칩 제거) 머지 → 앱 배포. **3이 끝난 뒤에만** — 그래야 전환 시점에 모든 매장이 이미 `availableMainCategories` 를 갖는다.
6. **(후속)** `menuCategories` 필드 물리 제거(§12.4 2단계) 정리 커밋 + 배포.

> **깨짐 방지 핵심**: 소비처 교체(5)는 데이터 시드(3) **이후**. 반대로 하면 전환 직후 모든 매장이 `availableMainCategories` 부재(=빈 목록)로 읽혀 홈 필터가 전부 0건이 된다. "코드-먼저" 금지, "데이터-먼저" 순서를 강제한다.

### 12.6 audit §4 체크리스트 재확인 (Phase B)

| # | 항목 | 판정 |
|---|---|---|
| 1 | 돈·권한·정책 값 변경? | `availableMainCategories` 는 **검색 노출용 파생값**. 돈·권한·정책 값 아님. 소스(점주 excluded·메뉴·active)는 각자 이력 정책을 가짐(Phase A §8 A2 보류, 메뉴=`priceHistory`, 카테고리 active=후속). 파생 자체 전용 이력 **불필요** — 전량 재계산으로 언제든 재생성 가능 |
| 2 | 덮어쓰기 손실 | 파생값은 소스에서 재계산되므로 손실 개념 없음 |
| 3 | 기록 문서가 정책 값 참조만? | 해당 없음(거래/기록 문서 미생성) |
| 4 | "누가" | 백필 `migrationHistory.executedBy=admin uid`. 트리거 쓰기는 시스템(CF) |
| 5 | batch/마이그레이션 | 백필 `migrationHistory` **1건 + affected/total**(§12.2) |
| 6 | CF 로그 의존 | 백필 근거를 Cloud Logging 아닌 `migrationHistory`(Firestore) 영구 기록. 트리거 실패는 로그만(soft·자기교정이라 수용) |
| 7 | 판정 필드 create/update 교차 | `availableMainCategories` 는 권한 판정 입력 아님(§12.6-1). 그래도 §12.3 대로 **create 가드 1건 + update 화이트리스트 제외 + 정상 payload 회귀** 하네스 각 1건 |

### 12.7 결정 6 — 작업 분배

#### designer — **호출 불필요 (조건부)**
- 홈/검색 칩의 **라벨 소스만** 바뀐다(마케팅 12종 → 메인 카테고리 label). 칩 컴포넌트·스타일은 Phase A design.md 에서 재사용 가능(이미 명시). **큰 재디자인 아님 → designer 생략.**
- 단, **2가지는 제품/UX 결정이라 사용자 확인 필요**(§12.9): (a) 홈 기본 선택(현재 "추천메뉴" 대응물 없음 → "전체" vs active 첫 코드), (b) 칩 개수 축소(12→active 메인 카테고리 수, 현재 3~4종)로 홈 체감이 바뀜. 확인 결과가 "칩 배치/빈 선택 UX 변경"을 요구하면 그때 designer 1회 호출.

#### developer — 호출 (Phase B 전체)
- **CF(functions/)**: `availableCategories.ts`(순수 `computeAvailableMainCategories`, `menuVisibility.ts applyOverrideForCustomer` 재사용) + `recomputeStore` + 5 트리거(`onStoreOwnMenuWritten`/`onStoreMenuOverrideWritten`/`onStoreOptoutWritten`/`onBrandMasterMenuWritten`/`onMainCategoryActiveWritten`) + `backfillAvailableMainCategories` 콜러블. index.ts export. diff 게이트·루프 가드·청크 배치(§12.1.4).
- **Rules**: `stores` create 에 `availableMainCategories` 주입 차단 가드(§12.3). update 화이트리스트엔 넣지 않음(현행 유지).
- **data_ownership.md §2.5 / §3** 갱신(§12.3).
- **클라이언트**: `StoreModel.availableMainCategories` 읽기 추가 / 홈 칩·`selectedCategoriesProvider`·`filteredStoresProvider`·`getStoresByCategories` 를 메인 카테고리·`availableMainCategories` 로 교체 / 점주 수동 칩 제거 / `menuCategories` deprecate(§12.4 1단계).
- **레이어 규칙**: presentation 은 Firebase 직접 import 금지(기존 DataSource 경유 유지). CF 는 `menuVisibility.ts` 재포팅 금지(재사용).
- 배포는 하지 않는다(코드 머지까지) — §12.5 의 2·3·4·5 배포는 사용자.

#### tester — developer 후 호출
- `computeAvailableMainCategories` 순수 단위테스트: 개인/가맹, override excluded, soldOut(카테고리엔 영향 없음 확인), ∩active, −excluded 조합. 교차 골든은 `menuVisibility.ts` 계약 재사용.
- diff 게이트: 가격·이름만 바뀐 마스터 메뉴 편집이 fan-out 안 함 / 카테고리 변경·생성·삭제는 함. 루프 가드: `availableMainCategories` 자체 write 가 재발화 안 함.
- 백필 before/after·멱등(두 번 돌려 동일)·`migrationHistory` 1건+affected.
- "디저트 끈 매장이 **홈 '디저트' 필터**에 안 뜸"(트리거·백필 후). 홈 칩 교체 회귀(라벨/code). 빈 선택 동작.
- Rules 하네스: `availableMainCategories` create 주입 거부 / update 화이트리스트 밖 거부 / 정상 payload 회귀.
- (에뮬레이터) 트리거 통합: ①~④ 각각이 올바른 매장 집합을 갱신하는지.

### 12.8 엣지 / 정합성 (Phase B 추가분)

| 케이스 | 처리 |
|---|---|
| 전환 직후 매장에 `availableMainCategories` 부재 | 백필(§12.5-3)이 선행 → 부재 없음. 그래도 `fromFirestore` 부재→`[]`, 홈 필터 0건(안전). 순서 위반이 유일 위험이라 §12.5 로 고정 |
| 점주가 Phase A 로 카테고리 off → 홈 필터 반영 지연 | soft(§12.0). `onStoreOptoutWritten` 가 수초 내 반영. 매장 탭은 이미 즉시 정확 |
| 브랜드가 첫 디저트 마스터 메뉴 추가 | ① diff 게이트 통과(생성) → 산하 매장 fan-out → `availableMainCategories` 에 `dessert` 추가(단, 그 매장이 Phase A 로 excluded 했으면 −excluded 로 안 들어감 = sticky 유지) |
| admin 카테고리 비활성화 | ④ → 전 매장 재계산, ∩active 에서 빠져 홈 필터에서 사라짐. 점주 excluded 목록은 Phase A 규칙대로 보존(재활성 시 여전히 제외) |
| 트리거 누락/실패 | 백필 재실행으로 치유(멱등). soft freshness 라 치명적 아님 |
| 개인(비가맹) 매장 | 자기 `menuItems` 만으로 계산. 동일 경로 |

### 12.9 사용자 확인이 필요한 결정사항 (Phase B)

1. **fan-out 비용 전략 & 가맹점 수 가정 승인(§12.1.5)** — "브랜드당 ≤50, 전 매장 ≤500" 가정과, ①(diff게이트 동기 fan-out)·④(전 매장 재계산) 수용 여부. 규모가 더 크면 §12.1.6 대안 C(디바운스 스케줄러)로 시작할지.
2. **홈 기본 선택 UX(§12.4/§12.7)** — 현재 "추천메뉴"는 메인 카테고리에 없음. 홈 진입 기본을 **"전체 매장(필터 없음)"** 으로 할지, active 메인 카테고리 첫 코드로 할지. (빈 선택 = 필터 없음 의미 변경 동반)
3. **칩 개수 축소 수용(§12.7)** — 홈 칩이 12종 → active 메인 카테고리(현재 3~4종)로 줄어드는 체감 변화. designer 재검토가 필요한 수준인지.
4. **`menuCategories` 물리 제거 시점(§12.4)** — 전환과 같은 릴리스에서 제거할지, deprecate 후 별도 정리 커밋으로 미룰지(권고: 2단계 분리).
5. **백필 콜러블 보존/삭제** — 상시 정합 도구로 보존 권고(임시 아님). 이견 여부.
