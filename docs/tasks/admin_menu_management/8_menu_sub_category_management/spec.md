# sub-phase 8 — menu_sub_category_management 기능 명세

> **상태**: APPROVED — 사용자 결정 1 / 2 / 6 / 추가 (검증 정책) 모두 확정. 본 spec 은 결정 회신을 반영한 최종안이다.
>
> **umbrella 단일 진실원**: `admin_menu_management/spec.md` 의 데이터 모델 / 권한 매트릭스를 따른다.
>
> **선행 phase**:
> - sub-phase 1 (brand_master) — 마스터 메뉴 / `optionGroupRefs` / `mainCategoryCode` 계열 데이터 모델
> - sub-phase 9 (menu_main_category_admin) — 메인 카테고리 동적 컬렉션 + admin CRUD UI 패턴 (재사용)
>
> 본 sub-phase 는 **메인 카테고리(coffee/nonCoffee/dessert/...) 의 하위** 인 부 카테고리(sub-category) 를 brand 본사 / 개인 매장 점주가 권한에 맞춰 직접 추가/편집/삭제할 수 있게 한다. **글로벌(admin) sub 는 두지 않는다 — 2-tier 모델 (brand / store)**. 동시에 메뉴 폼 3종(Master / BrandStoreOnly / OwnerStoreMenu) 에 **현재 누락된 sub-category 선택 UI** 를 추가한다.

---

## 개요

- **목적**:
  1. 부 카테고리(sub-category — 메인 카테고리 하위 분류, 예: 메인 "커피" 의 sub "에스프레소/콜드브루/라떼") 를 brand 본사 / 개인 매장 점주가 권한에 맞춰 직접 CRUD 할 수 있게 한다.
  2. 메뉴 등록/수정 폼에 **sub-category 선택 UI** 를 추가한다 (현재 폼 3종은 `subCategoryId` 를 보존만 할 뿐 사용자가 선택할 수 없는 상태).
  3. customer 매장 메뉴 탭의 sub-category 칩(`SubCategoryChips`) 은 이미 동적이므로 추가 변경 없음 — 본 phase 는 read 호환만 보장.
  4. **admin 은 본 sub-phase 에서 sub-category CRUD UI 를 다루지 않는다**. admin 측 메뉴 도메인 관리 범위는 sub-phase 9 (메인 카테고리) 에 한정 + sub-category 는 brand/store 자율.
- **작업 유형**: 신규 기능 (CRUD 도메인/데이터 + brand/owner UI 추가) + 기존 메뉴 폼 3종 기능 보강 (sub-category selector 추가).
- **영향 범위**:
  - 화면(brand 본사): **신규 진입점** — `BrandSubCategoryListPage` + `BrandSubCategoryFormPage`. 진입은 `BrandMorePage` tile (결정 2 확정).
  - 화면(owner 개인 매장): **신규 진입점** — `OwnerStoreSubCategoryListPage` + `OwnerStoreSubCategoryFormPage`. 진입은 `MyStorePage` (개인 매장 상세) 의 "메뉴 관리" 영역 (결정 2 확정).
  - 화면(brand 가맹점 점주): read-only — 본사 sub 를 칩에서 보기만 함, CRUD 진입 tile 미노출.
  - 화면(admin): **변경 없음**. `AdminMorePage` 에 sub-category 진입 tile 추가하지 않는다 (결정 1 — 글로벌 sub 자체가 없음). `AdminSubCategoryListPage` / `AdminSubCategoryFormPage` 는 신규 생성하지 않는다.
  - 화면(메뉴 폼 3종): **`MasterMenuFormPage` / `BrandStoreOnlyMenuFormPage` / `OwnerStoreMenuFormPage`** 모두에 sub-category 칩 영역 신규 추가. mainCategory 변경 시 sub-category cascade reset.
  - 화면(customer): `SubCategoryChips` 동작 변경 없음 (read 호환). `subCategoriesProvider` 가 노출하는 sub set 이 매장 컨텍스트(brandId 또는 storeId) 에 따라 brand 또는 store 컬렉션을 그대로 반환하도록 내부 변경.
  - Domain:
    - `SubCategoryEntity` — `scope: SubCategoryScope`, `brandId: String?`, `storeId: String?` 필드 추가.
    - `SubCategoryScope` enum 신규 (`brand` / `store` — 결정 1 (A 2-tier) 확정. master 단계는 두지 않음).
    - `MenuCategoryRepository` 인터페이스 확장: 기존 read + scope 별 stream.
    - 책임 분리: `MenuCategoryRepository` 는 read 전용 + CRUD 는 `SubCategoryRepository` 신규로 분리.
  - Data:
    - `SubCategoryModel` 매핑 확장 (scope/brandId/storeId).
    - `SubCategoryRemoteDataSource` 확장: scope 별 컬렉션 read/write (브랜드 / 매장).
    - `MenuCategoryRepositoryImpl` 의 `watchSubCategories` 가 호출자 컨텍스트(brandId 또는 storeId) 에 따라 해당 scope 만 반환.
    - **글로벌 `subCategories/{id}` 컬렉션은 사용하지 않는다** (생성도, read 도 없음).
  - Presentation: `presentation/brand/menu_categories/`, `presentation/owner/menu_categories/` 신규 트리. `presentation/admin/menu_categories/sub_categories/` 는 **신규 생성하지 않음**.
  - 라우팅: 변경 없음 (Navigator.push 내부 진입).
  - 권한 / 환경 설정: 본 sub-phase 는 **클라이언트 가드만**. Firestore 보안 규칙은 별도 task 로 분리.
  - 테스트:
    - 회귀: 기존 customer 매장 메뉴 탭 sub 칩, 메뉴 폼 3종 (sub-phase 1 / 3 / 4 / 9), sub-phase 9 마이그레이션 호환.
    - 신규: 권한 매트릭스 (brand 본사 / owner 개인 매장 / brand 가맹점 점주) 별 CRUD 동작.
    - **검증 정책 신규**: 같은 scope 내 동일 이름 차단 (UseCase / Repository 레벨).
- **비범위** (이번 작업에서 명시적으로 제외):
  - **글로벌(admin) sub-category** — 결정 1 (A 2-tier) 로 master scope 자체 미도입. admin 측 sub-category CRUD 화면도 미생성.
  - **메인 카테고리 CRUD** — sub-phase 9 완료 영역.
  - **옵션 그룹 CRUD** — sub-phase 7 별건. (메인/sub 카테고리는 분류 도메인. 옵션 그룹은 메뉴 변형 도메인 — 별도 phase).
  - **`MenuCategories.all` (12개 string)** — 매장 분류 태그 (Follow-up F6). 본 sub-phase 와 별개 도메인.
  - **부 카테고리 시각 토큰**(이미지/배너/색상) — label/displayOrder/active 까지만. 시각 토큰은 다음 phase 후보.
  - **다국어 label** — ko 단일 string. i18n 도입 시 확장.
  - **삭제 시 cascade 자동 마이그레이션** — UI 차단 정책으로 우선 보호 (결정 4 참조).
  - **Firestore 보안 규칙 작성** — 본 sub-phase 는 클라이언트 가드만. 보안 규칙은 별도 task.
  - **brand 가맹점 점주가 매장 한정 sub 를 자체 추가** — 본 phase 비범위. 가맹점 점주는 본사 sub 를 read-only 로만 사용. (Follow-up F2)
  - **오타/유사명 자동 감지 (예: '콜드브루' vs '콜드부루')** — NLP / 임베딩 유사도 영역. 본 phase 비범위 (Follow-up F7).
  - **admin 운영 모니터링 / 동의어 정리 도구** — 글로벌 sub 가 없으므로 admin 의 모니터링 / 정리 툴은 별도 phase 후보 (Follow-up F8).
  - **FCM/이메일 등 알림 인프라** — sub-phase 9 4d Heavy 와 동일 후속 phase.

---

## 의존 phase / 진입 조건

- **의존 phase**:
  - sub-phase 1 (brand_master): `MenuItemEntity.subCategoryId` 필드 존재.
  - sub-phase 9 (menu_main_category_admin): 메인 카테고리 동적 컬렉션 + admin CRUD UI 패턴(`AdminMainCategoryListPage` 등) 재사용 — UI 컴포넌트 패턴 참조용.
- **진입 조건**:
  - sub-phase 9 APPROVED + 안정.
  - Firestore 인덱스 추가 가능 (`collectionGroup('menuItems') / subCategoryId` asc).

---

## 핵심 결정 (확정)

> 결정 1 / 2 / 6 / 추가(검증) 사용자 회신 반영. 모든 BLOCKING 결정 확정.

### 결정 1. scope 분리 모델 — **확정: A안 (2-tier — brand / store)**

**확정 내용**:
- 글로벌(admin) sub 자체 없음.
- 컬렉션은 다음 두 개만 사용:
  ```text
  brands/{brandId}/subCategories/{id}      # scope: brand    (해당 brand 본사 CRUD, 가맹점 점주 read-only)
  stores/{storeId}/subCategories/{id}      # scope: store    (해당 매장 점주 CRUD — 개인 매장만)
  ```
- admin 은 메인 카테고리(sub-phase 9) 까지만 관리. **서브 카테고리는 brand / store 자율**.
- 신규 brand / 매장은 처음 sub 0개 → 직접 추가하거나, sub 없이 메뉴 등록 가능 (sub 는 선택 사항).
- `SubCategoryEntity` 에 `scope` / `brandId` / `storeId` 필드 추가. `SubCategoryScope` enum 은 **brand / store 두 값만** 가짐.
- 기존 글로벌 `subCategories/{id}` 컬렉션이 만약 운영 환경에 존재한다면 **사용하지 않고 무시**한다 (read 안 함). 마이그레이션은 "기존 글로벌 doc 의 brand 데이터 이관" 시나리오 발생 시 별도 처리 — 현 단계에서는 staging/dev 에 글로벌 doc 이 없으므로 사실상 신규 도입.

**확정 이유** (사용자 결정):
- admin 운영 부담 최소화 + brand / store 자율성 우선.
- 현재까지 글로벌 시즌/공통 분류를 admin 이 일괄 관리할 명확한 운영 시나리오가 없음.
- 글로벌 sub 도입은 운영 데이터/요구가 누적된 시점에 별도 phase 로 재논의 (Follow-up F9).

---

### 결정 2. CRUD 진입 UI 위치 — **확정**

| 역할 | 진입점 | 사유 |
|---|---|---|
| brand 본사 | `BrandMorePage` 의 "부 카테고리 관리" tile | sub-phase 9 admin tile 패턴과 일관. 운영 빈도 낮음 → 더보기 탭 |
| owner 개인 매장 | `MyStorePage` (개인 매장 상세) 의 "메뉴 관리" 영역 안에 "분류 관리" 진입 | 매장 컨텍스트 자동 머지. 매장 미등록 점주는 진입 자체 불가 (자연 차단) |
| brand 가맹점 점주 | **진입 tile 미노출** | read-only — 본사 sub 칩만 표시. CRUD UI 자체를 안 보여줌 |
| admin | **신규 tile 추가 안 함** | 결정 1 — 글로벌 sub 부재. admin 측 sub CRUD 진입점 자체가 비범위 |

**확정 이유**: 잠정안 그대로 사용자가 확정.

---

### 결정 3. 메뉴 폼 sub-category 선택 UI 동작 — **확정**

- 메뉴 폼 3종(`MasterMenuFormPage` / `BrandStoreOnlyMenuFormPage` / `OwnerStoreMenuFormPage`) 에 **sub-category 칩 영역 신규 추가**.
- 위치: 메인 카테고리 칩 직하 (메인 → 부 위계 시각화).
- **cascade 동작**:
  - 메인 카테고리 변경 시 `_selectedSubCategoryId = null` 으로 reset.
  - 메인 카테고리 미선택 시 sub 칩 영역 비활성 (또는 빈 상태 안내 "메인 카테고리를 먼저 선택해주세요").
- **sub 후보 fetch 정책 (2-tier 단일 scope)**:
  | 폼 | 노출되는 sub scope |
  |---|---|
  | `MasterMenuFormPage` (brand 본사 마스터 메뉴) | `brand` (해당 brandId 본사 sub) **만** |
  | `BrandStoreOnlyMenuFormPage` (brand 본사 → 가맹점 한정 메뉴) | `brand` (해당 brandId 본사 sub) **만** |
  | `OwnerStoreMenuFormPage` (개인 매장 점주) | `store` (해당 storeId 매장 한정 sub) **만** |
- sub 는 **선택 사항** — 메뉴마다 sub 가 없을 수도 있음. 폼 valid 검증에는 포함 안 함.
- 수정 모드에서 메뉴의 `subCategoryId` 가 inactive 또는 삭제된 sub 를 가리키면:
  - inactive sub 도 disabled marker 로 노출 + 경고 라벨 ("이 부 카테고리는 비활성화되었습니다. 다른 분류로 변경해주세요").
  - 삭제된 sub 는 칩에서 fallback "삭제됨 — 변경 필요" 시각 표시 + null 로 reset 권장.

---

### 결정 4. 삭제 정책 — **확정: 사용 중이면 hard delete 차단 + active 토글 도입**

- sub-phase 9 메인 카테고리 삭제 정책 (B) 와 동일 패턴.
- `SubCategoryEntity.active` 필드 **이미 존재** — 별 마이그레이션 없음.
- 삭제 차단 검증:
  - menuItem: `collectionGroup('menuItems').where(subCategoryId == id).limit(1)` → exists?
  - 1개 이상 exists → hard delete 차단, 토스트 "사용 중 N개. 비활성으로만 가능".
- 비활성(active=false) 시 동작:
  - 신규 등록 폼: 칩에서 제외.
  - 기존 메뉴 수정 폼: inactive sub 도 disabled marker 로 노출 + 경고 라벨.
  - customer 매장 메뉴 탭(`SubCategoryChips`): active=true 만 노출. inactive sub 는 칩에서 제외.
- **인덱스 필요** — `firestore.indexes.json` 에 `collectionGroup('menuItems')` / `subCategoryId` asc 인덱스 추가.

---

### 결정 5. main → sub 종속 + main 카테고리 비활성/삭제 시 sub cascade — **확정 (잠정안 그대로)**

- sub 는 항상 main 한 개에 속함 (`mainCategoryCode: String` 필드 — 이미 존재).
- main 카테고리가 sub-phase 9 정책에 따라 hard delete 되는 경우:
  - sub-phase 9 의 main 삭제 차단 정책으로 main 의 sub 가 1개 이상이면 main 도 삭제 안 됨 → cascade 미발생.
  - main 이 hard delete 되려면 그 main 의 sub 가 모두 사라진 상태. 즉 **main 삭제 시 cascade 불필요**.
- main 이 active=false 가 되면:
  - main 자체는 보존. sub 들도 보존 (sub.active 는 별 토글).
  - customer 매장 메뉴 탭은 sub-phase 9 정책에 따라 inactive main 카테고리를 탭에서 제외 → 그 main 의 sub 칩도 자동 미표시.
- **추가 결정 없음**.

---

### 결정 6. brand vs store sub 충돌 / 노출 규칙 — **확정 (2-tier 단순화)**

| 폼 | 노출 sub scope |
|---|---|
| `MasterMenuFormPage` | `brand` (해당 brandId) |
| `BrandStoreOnlyMenuFormPage` | `brand` (해당 brandId) |
| `OwnerStoreMenuFormPage` | `store` (해당 storeId) |
| customer `SubCategoryChips` | 매장 컨텍스트 자동 분기: 가맹점 매장이면 `brand`(매장 doc 의 brandId), 개인 매장이면 `store`(storeId) |

**머지 알고리즘** (Repository 책임 — 단일 scope read 로 단순화):
```text
fetchSubCategories(mainCategoryId, {brandId?, storeId?}):
  if storeId != null:
      return collection('stores/{storeId}/subCategories').where(mainCategory==id, active==true)
  if brandId != null:
      return collection('brands/{brandId}/subCategories').where(mainCategory==id, active==true)
  return []  // 매장 컨텍스트 미상 → 빈 결과 (safety)
```
- customer 측은 매장 doc 에서 brandId 유무로 매장 종류 구분 → 그에 따라 brand 또는 store 컬렉션 read.
- 가맹점 매장의 경우 store sub 는 만들 수 없고(본 phase 비범위), brand sub 만 있으므로 자동으로 단일 scope read.
- 개인 매장의 경우 brandId == null 이므로 store sub 만 노출.

---

### 결정 7. main → sub 종속 cascade — **확정 (결정 5 와 통합)**

- 결정 5 결론과 동일. main 삭제 시 cascade 불필요.
- main active=false 시 sub 는 그대로 보존. customer 측은 main 필터로 자연 제외.

---

### 추가 결정 — 검증 정책 — **확정: 옵션 2 (약한 검증)**

- **같은 scope 내 동일 이름 차단**:
  - 한 brand 안에서 동일 이름 sub 못 만듦 (`brands/{brandId}/subCategories/` 안에서).
  - 한 store 안에서도 동일 (`stores/{storeId}/subCategories/` 안에서).
  - 비교 방식: 정확 일치 — **대소문자 무시 + 앞뒤 공백 trim** 적용 (`name.trim().toLowerCase()` 비교).
  - 같은 mainCategoryCode 안에서만 비교할지 / scope 전체에서 비교할지 → **scope 전체에서 비교**. (예: 한 brand 의 메인 "커피" 와 메인 "디저트" 양쪽에 똑같이 "시즌" 이라는 sub 를 두는 케이스도 차단.) 사유: scope 안에서 sub label 의 식별성을 사용자가 1회 보장.
- **다른 scope 간** (예: brand 'A' 의 'sub-X' vs brand 'B' 의 'sub-X', brand 'A' 의 'sub-X' vs store 'S' 의 'sub-X') 은 **허용**. scope 자체가 격리됨.
- 검증 위치:
  - **Repository / UseCase 레벨** 에서 검증.
  - `UpsertSubCategoryUseCase` 진입 시 → `SubCategoryRepository.findDuplicateName({scope, brandId?, storeId?, name, excludeId?})` 호출.
  - 같은 scope 안에 동일 normalized name 존재 + 자기 자신(excludeId) 이 아니면 → `DuplicateSubCategoryNameException` throw.
  - **excludeId** 는 수정 모드에서 자기 doc 자기 비교 회피용.
- 폼 단 추가 검증:
  - 입력 시점 디바운스 lookup 으로 즉시 중복 표시 (designer 카피 — "이미 같은 이름의 분류가 있어요").
  - submit 시 race 방지 — UseCase 가 최종 차단.
- **오타/유사명 (예: '콜드브루' vs '콜드부루')** 자동 감지 → 본 phase 비범위. NLP/임베딩 영역. **Follow-up F7**.
- **admin 모니터링 / 동의어 정리 도구** → 본 phase 비범위 (글로벌 sub 부재 + 운영 데이터 누적 후 별 phase). **Follow-up F8**.

---

### 결정 보너스. Repository 책임 분할 — **확정: 분리**

- `MenuCategoryRepository` (기존) → read 만. customer / 메뉴 폼이 사용.
- `SubCategoryRepository` (신규) → CRUD + scope 별 stream + 중복 이름 lookup. brand 본사 / owner 가 사용.
- 두 repo 모두 같은 `SubCategoryRemoteDataSource` 를 공유.

---

## 요구사항

### 기능 요구사항

#### brand 본사 (brand scope CRUD)
- [ ] `BrandSubCategoryListPage` — `brands/{brandId}/subCategories/{id}` 목록.
  - mainCategoryCode 별로 그룹핑(또는 필터 칩) — UI: designer 결정.
  - 각 item: label / mainCategoryCode badge / displayOrder / active toggle / "사용 중 N개" 표시 / 편집 / 삭제.
- [ ] `BrandSubCategoryFormPage` — 등록/수정 (id, mainCategoryCode, name, displayOrder, active).
  - id 등록 시 입력, 수정 시 read-only.
  - mainCategoryCode 는 `mainCategoriesActiveProvider` 에서 active=true 만 선택지로 노출 (단 수정 모드에서 현재 main 이 inactive 면 disabled marker 로 노출).
  - name: 1~10자.
  - displayOrder: 정수, 0 이상.
  - **중복 이름 lookup (디바운스)** — 같은 brand 안에 normalized name 일치하는 다른 sub 가 있으면 inline 에러.
- [ ] 삭제: 사용 중 검사. 사용 중이면 차단 + 토스트.
- [ ] 비활성 토글: list 직접 토글.
- [ ] brand 가맹점 점주는 진입 tile 자체가 미노출 (가드).

#### owner 개인 매장 (store scope CRUD)
- [ ] `OwnerStoreSubCategoryListPage` — `stores/{storeId}/subCategories/{id}` 목록.
- [ ] `OwnerStoreSubCategoryFormPage` — 위와 동일 폼 + 같은 store 안 중복 이름 검증.
- [ ] 진입 가드: 매장이 개인 매장(brandId == null) 이고 점주 본인 매장일 때만.
- [ ] 가맹점(brandId != null) 점주는 진입 tile 자체가 미노출.

#### read (메뉴 폼 3종 + customer)
- [ ] `MenuCategoryRepository.watchSubCategories` 가 매장 컨텍스트(brandId 또는 storeId) 에 따라 단일 scope read.
- [ ] 메뉴 폼 3종 sub-category 칩 영역 신규 추가:
  - main 선택 시 sub 칩 영역 활성.
  - main 변경 시 selected sub reset.
  - inactive sub fallback (수정 모드): disabled marker + 경고 라벨.
- [ ] customer `SubCategoryChips` — 단일 scope 결과 기반 동작 보장 (회귀 검증만).

#### 검증 정책 (신규)
- [ ] `SubCategoryRepository.findDuplicateName({scope, brandId?, storeId?, name, excludeId?})` 구현.
  - normalize: `name.trim().toLowerCase()`.
  - 같은 scope 내에서 active 무관 모든 doc 비교 (active=false 인 sub 도 동일 이름 재사용 차단 — 단순화).
  - excludeId 가 일치하면 자기 자신은 후보에서 제외.
- [ ] `UpsertSubCategoryUseCase` 가 upsert 직전 `findDuplicateName` 호출 → 존재 시 `DuplicateSubCategoryNameException` throw.
- [ ] 폼 페이지: 디바운스(약 300ms) lookup 결과로 inline 에러 라벨 + submit 시 UseCase 최종 차단.

#### 마이그레이션 / 호환
- [ ] 기존 `subCategories/{id}` (글로벌) 컬렉션이 dev/staging 에 존재할 가능성 점검 — 존재한다면 본 phase 에서는 read 하지 않으며, 데이터 이관 시나리오는 별 task 로 분리.
- [ ] 신규 brand / 매장은 처음 sub 0개 — 메뉴 등록은 sub 없이 정상 가능.

### UI 요구사항
- [ ] `BrandMorePage` 에 "부 카테고리 관리" tile 추가.
- [ ] `MyStorePage` "메뉴 관리" 영역에 "분류 관리" 진입 추가.
- [ ] `BrandSubCategoryListPage` / `OwnerStoreSubCategoryListPage` 디자인 (designer 산출물).
- [ ] 폼 페이지 2종 디자인 + 중복 이름 inline 에러 카피.
- [ ] 메뉴 폼 3종에 sub-category 칩 영역 추가 — 메인 카테고리 칩 직하. 빈 상태 / inactive 경고 라벨 / cascade reset 시각 처리 (designer).
- [ ] customer `SubCategoryChips` — 변경 없음.
- [ ] **admin 측 신규 UI 없음**.

### 상태 요구사항
- [ ] loading: stream 첫 emit 전 — shimmer / placeholder.
- [ ] error: stream error → retry.
- [ ] empty: sub 0개 — brand/owner 는 "+ 추가" 안내. 메뉴 폼은 "분류 없음 — 메뉴는 sub 없이 등록 가능" 안내.

---

## 데이터 모델

### Entity (Domain)

```dart
// lib/domain/entities/sub_category_scope.dart (신규)
enum SubCategoryScope {
  brand,  // 'brands/{brandId}/subCategories/{id}'
  store;  // 'stores/{storeId}/subCategories/{id}'

  static SubCategoryScope fromString(String? v) {
    switch (v) {
      case 'store': return SubCategoryScope.store;
      case 'brand':
      default:      return SubCategoryScope.brand;
    }
  }
  String get asString => name;
}
```

```dart
// lib/domain/entities/sub_category_entity.dart (확장)
@freezed
abstract class SubCategoryEntity with _$SubCategoryEntity {
  const factory SubCategoryEntity({
    required String id,
    required String mainCategoryCode,
    required String name,
    @Default(0) int displayOrder,
    @Default(true) bool active,
    // ── 신규 ─────────────────────────────────────────
    required SubCategoryScope scope,
    String? brandId,  // scope == brand 일 때 채움
    String? storeId,  // scope == store 일 때 채움
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _SubCategoryEntity;
}
```

> scope 는 default 값을 두지 않는다 (master 가 사라졌으므로 fallback 필요 없음). 모든 doc 은 brand 또는 store 컬렉션 경로에서 read 되며 path resolver 가 scope 를 결정.

### Model (Data)

| 컬렉션 | scope | doc 필드 (공통) | 추가 필드 |
|---|---|---|---|
| `brands/{brandId}/subCategories/{id}` | brand | mainCategory, name, displayOrder, active | scope='brand', brandId={parent} |
| `stores/{storeId}/subCategories/{id}` | store | (동일) | scope='store', storeId={parent} |

- `SubCategoryModel` 에 `scope` / `brandId` / `storeId` 필드 + `fromFirestore` 시 doc 경로(parent.parent.id) 에서 brandId/storeId 추출 + scope 결정.

### MenuCategoryRepository (read, 확장)

```dart
abstract class MenuCategoryRepository {
  /// 메인 카테고리 안의 sub stream (단일 scope).
  /// [brandId] / [storeId] 둘 중 하나만 채워서 호출.
  /// - storeId 가 채워지면 store scope read.
  /// - brandId 만 채워지면 brand scope read.
  /// - 둘 다 null 이면 빈 결과 stream.
  Stream<List<SubCategoryEntity>> watchSubCategories(
    String mainCategoryId, {
    String? brandId,
    String? storeId,
    bool activeOnly = true,
  });
}
```

### SubCategoryRepository (CRUD, 신규)

```dart
abstract class SubCategoryRepository {
  /// 단일 scope 조회 (brand/owner 각자 자기 scope 만).
  Stream<List<SubCategoryEntity>> watchByScope({
    required SubCategoryScope scope,
    String? brandId,    // scope == brand 일 때 필수
    String? storeId,    // scope == store 일 때 필수
    String? mainCategoryId, // null 이면 전체 main 의 sub.
    bool activeOnly = false,
  });

  Future<SubCategoryEntity?> findById({
    required SubCategoryScope scope,
    required String id,
    String? brandId,
    String? storeId,
  });

  /// 같은 scope 내에서 normalized name 이 동일한 doc 검색.
  /// excludeId 가 주어지면 그 id 는 후보에서 제외 (수정 모드).
  /// 반환값이 not null 이면 중복 존재.
  Future<SubCategoryEntity?> findDuplicateName({
    required SubCategoryScope scope,
    required String name,
    String? brandId,
    String? storeId,
    String? excludeId,
  });

  Future<void> upsert(SubCategoryEntity entity);

  Future<void> delete({
    required SubCategoryScope scope,
    required String id,
    String? brandId,
    String? storeId,
  });

  /// 사용 중 검사. menuItem.subCategoryId 참조 수.
  Future<int> countUsage(String subCategoryId);
}
```

### MenuItemEntity / SubCategoryEntity 외 변경

- `MenuItemEntity.subCategoryId: String?` — **변경 없음**. 이미 존재.
- 메뉴 폼 3종 — UI 변경 (sub 칩 추가). 도메인 변경 없음.

---

## 레이어 설계

### Domain
- Entity: `SubCategoryScope` (신규 enum, brand/store), `SubCategoryEntity` (필드 확장).
- UseCase:
  - `WatchSubCategoriesUseCase` (기존, signature 확장 — `{brandId, storeId, activeOnly}` 추가).
  - `WatchSubCategoriesByScopeUseCase` (신규) — 단일 scope 조회 (brand/owner CRUD 페이지용).
  - `UpsertSubCategoryUseCase` (신규) — **내부에서 `findDuplicateName` 호출 후 차단**.
  - `DeleteSubCategoryUseCase` (신규) — countUsage 후 0 이면 delete, 아니면 throw.
  - `ToggleSubCategoryActiveUseCase` (신규).
  - `CountSubCategoryUsageUseCase` (신규).
  - `FindDuplicateSubCategoryNameUseCase` (신규) — 폼 디바운스 lookup 용.
- Repository Interface:
  - `MenuCategoryRepository` (기존, signature 확장).
  - `SubCategoryRepository` (신규).
- Domain Error:
  - `SubCategoryInUseException` (신규).
  - `DuplicateSubCategoryNameException` (신규).

### Data
- Model: `SubCategoryModel` (필드 확장).
- DataSource: `SubCategoryRemoteDataSource`
  - 기존 `streamByMainCategory` → signature 확장: `{brandId?, storeId?, activeOnly?}`. 둘 중 하나만 채워진 단일 scope read.
  - 신규 `streamByScope({scope, brandId, storeId, mainCategoryId, activeOnly})`.
  - 신규 `findDuplicateName({scope, brandId, storeId, normalizedName, excludeId})` — scope 전체 컬렉션 query.
  - 신규 `upsert(model)` — scope 따라 컬렉션 경로 분기.
  - 신규 `delete({scope, id, brandId, storeId})`.
  - 신규 `countUsage(subCategoryId)` — `collectionGroup('menuItems').where(subCategoryId == id).count()`.
- Repository Implementation:
  - `MenuCategoryRepositoryImpl` (확장 — 단일 scope read 구현).
  - `SubCategoryRepositoryImpl` (신규).

### Presentation
- Provider:
  - 기존 `subCategoriesProvider.family<List<SubCategoryEntity>, String>` (mainCategoryId 만) → `family<…, ({String mainCategoryId, String? brandId, String? storeId})>` 로 확장.
  - `subCategoryRepositoryProvider` (신규).
  - brand 본사용: `brandSubCategoriesProvider({brandId, mainId})`.
  - owner 개인 매장용: `ownerStoreSubCategoriesProvider({storeId, mainId})`.
  - sub 사용 수 provider: `subCategoryUsageProvider.family<int, String>` (list "사용 중 N개" 표시).
  - `findDuplicateSubCategoryNameProvider.family<…, DuplicateNameQuery>` (폼 디바운스 lookup).
- Page:
  - `BrandSubCategoryListPage` / `BrandSubCategoryFormPage` (신규).
  - `OwnerStoreSubCategoryListPage` / `OwnerStoreSubCategoryFormPage` (신규).
- Widget:
  - 공통: `SubCategoryListItem`, `SubCategoryDeleteDialog`, `SubCategoryActiveSwitch`, `SubCategoryFormFields` (brand/owner 두 영역에서 재사용 — `presentation/common/widgets/menu_categories/`).
  - 메뉴 폼 3종 — `SubCategoryChipsSelector` 신규 (`presentation/common/widgets/`).
- 기존 widget 변경:
  - 메뉴 폼 3종 — main 칩 직하 sub 칩 영역 추가. main 변경 시 sub reset.
  - `SubCategoryChips` (customer) — 변경 없음 (props 동일).
  - `BrandMorePage` — "부 카테고리 관리" tile 추가.
  - `MyStorePage` — "메뉴 관리" 영역에 "분류 관리" 진입 추가.
  - `AdminMorePage` — **변경 없음**.

### 라우팅
- 변경 없음. Navigator.push 내부 진입.

---

## 데이터 흐름

### brand 본사 sub 등록 (중복 이름 검증 포함)
```text
BrandSubCategoryFormPage (brandId 컨텍스트)
  → onChanged(name) → debounce 300ms → findDuplicateSubCategoryNameUseCase(scope=brand, brandId, name, excludeId=editId?)
     ↓ duplicate 존재 시 inline 에러 라벨
  → onSubmit
     → UpsertSubCategoryUseCase(entity[scope=brand, brandId])
        → 내부에서 findDuplicateName 재호출 (race 방지)
        → exists → DuplicateSubCategoryNameException throw
        → 없음 → SubCategoryRepository.upsert
                → SubCategoryRemoteDataSource.upsert (brands/{brandId}/subCategories/{id})
                → Firestore set merge
```

### owner 개인 매장 sub 등록
```text
OwnerStoreSubCategoryFormPage (storeId 컨텍스트)
  → 동일 흐름. entity.scope = store, entity.storeId = storeId
  → DataSource → stores/{storeId}/subCategories/{id}
```

### 메뉴 폼 sub 칩 fetch (예: MasterMenuFormPage)
```text
MasterMenuFormPage
  → mainCategoriesAllProvider (이미 있음, sub-phase 9)
  → ref.watch(subCategoriesProvider({mainId, brandId: profile.brandId, storeId: null}))
  → MenuCategoryRepository.watchSubCategories(mainId, brandId: ..., activeOnly: true)
  → DataSource → brands/{brandId}/subCategories where mainCategory==mainId, active==true
  → 칩 build
```

### customer sub 칩 (storeId 컨텍스트)
```text
StoreMenuPage
  → 이미 storeProvider 로 매장 doc 가짐 (brandId 포함)
  → store.brandId 가 null 이 아니면 → 가맹점 매장 → brandId 로 read
     store.brandId 가 null 이면 → 개인 매장 → storeId 로 read
  → ref.watch(subCategoriesProvider({mainId, brandId, storeId}))
  → repository 가 단일 scope read
  → SubCategoryChips 가 결과 props 로 받음 (이미 동작)
```

### 사용 중 검사 (brand/owner 공통)
```text
DeleteDialog
  → countSubCategoryUsageProvider(subId)
  → CountSubCategoryUsageUseCase
  → SubCategoryRepository.countUsage
  → DataSource → collectionGroup('menuItems').where(subCategoryId==id).count()
  → > 0 이면 차단, 0 이면 delete 허용
```

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| read stream error | 에러 UI + retry (invalidate). |
| upsert 실패 (네트워크) | snackbar 토스트 + form 유지. |
| **upsert 시 동일 이름 존재 (`DuplicateSubCategoryNameException`)** | **submit 차단 + form 에 inline 에러 표시 ("이미 같은 이름의 분류가 있어요"). 디바운스 lookup 도 같은 라벨 재사용**. |
| delete 시 사용 중 (`SubCategoryInUseException`) | 다이얼로그 차단 + "사용 중 N개. 비활성으로만 가능". |
| 컬렉션 empty (sub 0개) | brand/owner: "+ 추가" CTA. 메뉴 폼: "분류 없음 — sub 없이 등록 가능" + sub 영역 비활성. |
| 메뉴 폼에서 main 미선택 | sub 칩 영역 비활성 + "메인 카테고리를 먼저 선택해주세요" 안내. |
| 메뉴 폼 수정 모드 — sub 가 inactive 또는 삭제됨 | inactive sub 는 disabled marker + 경고 라벨. 삭제된 sub 는 fallback "삭제된 분류 — 변경 필요". |
| brand 가맹점 점주가 sub CRUD 시도 (코드/링크 우회) | UseCase 단에서 권한 체크 실패 throw + 클라이언트 단 진입 차단 (tile 미노출). 보안 규칙은 별 task. |
| menuItem.subCategoryId 가 brand/store 어디에도 없는 값 | customer 칩에서 자연 제외. tester audit 영역. |
| 시드 race | upsert set merge — idempotent. duplicate 체크는 race 시 두 번째가 에러 (예상 동작). |

---

## 작업 분배

### designer

- **UI 변경 필요 여부**: YES (다수).
- **디자인 산출물** (`design.md` 작성):

  **A. brand 본사 부 카테고리 관리 화면 (brand scope)** — 신규
  - `BrandMorePage` 의 "부 카테고리 관리" tile 추가.
  - `BrandSubCategoryListPage`:
    - 헤더 (제목 + "+ 추가" 버튼).
    - **mainCategoryCode 그룹핑/필터** UI (designer 결정 — 칩 필터 vs 섹션 헤더 vs 펼침 패널).
    - list item: name / mainCategoryCode badge / displayOrder / active toggle / "사용 중 N개" / 편집 / 삭제.
    - empty / loading / error 상태.
  - `BrandSubCategoryFormPage`:
    - 등록 / 수정 모드 분기.
    - id input (등록만, 수정 시 read-only).
    - mainCategoryCode 칩 선택 (`mainCategoriesAllProvider` watch — sub-phase 9 패턴 재사용).
    - name input (1~10자 카운터) + **중복 이름 inline 에러 라벨 (디바운스 결과)**.
    - displayOrder number input.
    - active switch.
    - 저장 / 취소 버튼.
  - `SubCategoryDeleteDialog`:
    - 사용 중 N개 표시.
    - "비활성으로 전환" / "취소" / "삭제" 분기.
  - **검증 dialog 카피** (신규):
    - 디바운스 inline: "이미 같은 이름의 분류가 있어요" (또는 동등한 카피).
    - submit 시 race 차단 dialog: "이름이 이미 존재합니다. 다른 이름을 사용해주세요" 등.
    - 카피 톤은 Qradar 친절·짧게 (designer 최종 카피 결정).

  **B. owner 개인 매장 부 카테고리 관리 화면 (store scope)** — 신규
  - 진입: `MyStorePage` 의 "메뉴 관리" 영역에 "분류 관리" 진입.
  - 화면 구조는 brand 화면과 동일 패턴 — designer 가 brand 의 컴포넌트를 owner 진입점에서 재사용. storeId 컨텍스트는 진입 시점에 박힘.
  - 같은 store 안 중복 이름 검증 inline 에러 카피 동일.

  **C. 메뉴 폼 3종 sub-category 칩 영역 (신규)**
  - 적용 화면: `MasterMenuFormPage`, `BrandStoreOnlyMenuFormPage`, `OwnerStoreMenuFormPage`.
  - 위치: 메인 카테고리 칩 직하.
  - 빈 상태 ("메인 카테고리를 먼저 선택해주세요" / "이 분류에 sub-category 가 없어요").
  - cascade reset 애니메이션 / 시각 피드백.
  - inactive sub 경고 라벨 (수정 모드).
  - 출처 marker(brand vs store) 는 단일 scope 만 노출하므로 **불필요** (2-tier 단순화로 제거됨).

  **D. 가맹점 점주 read-only 표시**
  - 가맹점 점주의 `OwnerStoreMenuFormPage` 진입 자체가 본사가 만든 폼이 아니므로 별 처리 불필요. 가맹점 점주가 보는 customer 매장 메뉴 탭 sub 칩은 본사 brand sub 가 자동 노출됨 (read 단일 scope).
  - 가맹점 점주 화면에 "분류 관리" 진입 tile 미노출 — 미노출 자체가 시각 정책.

  **E. admin 영역 변경 없음** — 신규 디자인 산출물 없음. (결정 1 — 글로벌 sub 미도입.)

- **전달할 사항**:
  - 본 spec 결정 1 (2-tier) / 2 / 3 / 6 + 추가 결정 (검증 정책) + Qradar 디자인 토큰.
  - sub-phase 9 admin 화면 디자인 (`AdminMainCategoryListPage` 등) 의 list/form/dialog 컴포넌트 패턴 재사용.
  - 메뉴 폼 3종은 sub-phase 9 의 메인 카테고리 칩 위치/스타일 직하에 sub 칩 영역.

### developer

- **구현 항목**:
  - **Domain**:
    - `SubCategoryScope` enum (신규, brand/store).
    - `SubCategoryEntity` 필드 확장 (scope/brandId/storeId/createdAt/updatedAt).
    - `MenuCategoryRepository` signature 확장 (단일 scope read).
    - `SubCategoryRepository` interface (신규, `findDuplicateName` 포함).
    - UseCase: WatchSubCategories / WatchSubCategoriesByScope / Upsert / Delete / ToggleActive / CountUsage / FindDuplicateName.
    - `SubCategoryInUseException`, `DuplicateSubCategoryNameException`.
  - **Data**:
    - `SubCategoryModel` 매핑 확장 + 다중 컬렉션 path resolver.
    - `SubCategoryRemoteDataSource` 단일 scope stream / scope 별 upsert/delete/countUsage / findDuplicateName.
    - `MenuCategoryRepositoryImpl` 단일 scope read 구현.
    - `SubCategoryRepositoryImpl` (신규).
  - **Presentation (brand/owner CRUD)**:
    - `BrandSubCategoryListPage` / `BrandSubCategoryFormPage`.
    - `OwnerStoreSubCategoryListPage` / `OwnerStoreSubCategoryFormPage`.
    - 공통 위젯: `SubCategoryListItem` / `SubCategoryFormFields` / `SubCategoryDeleteDialog` (`presentation/common/widgets/menu_categories/`).
    - `BrandMorePage` / `MyStorePage` 진입 tile / CTA 추가.
    - 가맹점 점주 가드 — `BrandMorePage` tile 은 본사 사용자만 노출, `MyStorePage` 진입은 store.brandId == null 일 때만 노출.
  - **Presentation (메뉴 폼 3종)**:
    - `SubCategoryChipsSelector` 위젯 (공통).
    - `MasterMenuFormPage` / `BrandStoreOnlyMenuFormPage` / `OwnerStoreMenuFormPage` 에 sub 칩 영역 + cascade reset + inactive 경고 라벨 + 저장 시 `subCategoryId` 반영 (현재 `baseItem?.subCategoryId` 보존만 → 사용자 선택값 사용).
  - **Provider**:
    - `subCategoryRepositoryProvider`.
    - `menuCategoryRepositoryProvider` (signature 변경 — 기존 호출처 일괄 수정).
    - `subCategoriesProvider` family parameter 확장 (mainId + brandId? + storeId?).
    - brand/owner 별 list provider.
    - `subCategoryUsageProvider`.
    - `findDuplicateSubCategoryNameProvider`.
  - **인덱스**:
    - `firestore.indexes.json` 에 `collectionGroup('menuItems') / subCategoryId` asc 인덱스 추가 (결정 4 — 사용 중 검사용).
  - **마이그레이션**:
    - 기존 글로벌 `subCategories/{id}` 컬렉션은 read 하지 않음. (운영 데이터 이관은 별 task.)
    - 신규 brand/매장 sub 0개 상태에서도 메뉴 폼 정상 동작.
- **재사용할 기존 구조**:
  - sub-phase 9 admin CRUD 패턴 (`AdminMainCategoryListPage` / `AdminMainCategoryFormPage` / `MainCategoryDeleteDialog` / `mainCategoriesAllProvider`).
  - `FirestorePaths` 의 brands/stores 경로 헬퍼.
  - 옵션 그룹 sub-phase 1 patch 의 `OptionGroupSelector` 패턴 (메뉴 폼에 selector 추가하는 위치/시각 패턴).
- **주의할 레이어 규칙**:
  - Firebase import 는 `data/` 만.
  - presentation 은 UseCase / Repository interface 만 알 것.
  - `SubCategoryEntity` freezed 재생성 — `dart run build_runner build --delete-conflicting-outputs`.
  - 가맹점 점주의 store CRUD 차단은 클라이언트 단 (UseCase 가드 + 진입 tile 미노출). 보안 규칙은 별 task.
  - 단일 PR 머지 — sub-category entity 필드 확장 + customer/메뉴 폼 호출처 수정이 동시에 필요.
  - **검증 정책 (옵션 2)** — UseCase 가 race 방지 차단을 책임진다. 폼은 UX 보조용 디바운스만.

### tester

- **주요 검증 기준**:
  - **마이그레이션 / 호환 검증**:
    - 신규 brand 의 sub 0개 상태에서 메뉴 폼 진입 → "분류 없음 — sub 없이 등록 가능" 정상 노출.
    - 기존 메뉴의 `subCategoryId` 가 brand/store 어디에도 없으면 customer 칩에서 자연 제외 + 메뉴 수정 폼은 fallback 라벨.
  - **read 동작 (메뉴 폼 sub 칩)**:
    - `MasterMenuFormPage`: brand sub 만 노출.
    - `BrandStoreOnlyMenuFormPage`: brand sub 만 노출.
    - `OwnerStoreMenuFormPage`: store sub 만 노출.
    - main 변경 시 sub 칩 cascade reset.
    - 수정 모드 + inactive sub: disabled marker + 경고 라벨.
    - 저장 후 `MenuItemEntity.subCategoryId` 가 사용자 선택값으로 박힘.
  - **CRUD 동작 (brand/owner)**:
    - brand 본사: brand scope. 본사 본인 brandId 만 CRUD 가능.
    - owner 개인 매장: 자기 storeId 만 CRUD 가능.
    - 등록 시 main 카테고리 inactive 면 칩에서 제외 (또는 disabled).
    - 사용 중 sub hard delete 시도 → 차단 + 다이얼로그.
    - 사용 0개 sub hard delete → 정상.
    - active=false → 신규 폼 칩에서 제외 + customer 탭에서 제외, 기존 메뉴는 보존.
  - **검증 정책 (옵션 2) 검증**:
    - 같은 brand 안에서 동일 이름 sub 등록 시도 → 차단 + inline 에러.
    - 같은 brand 안에서 대소문자/공백만 다른 이름 등록 시도 → 차단 (예: "콜드브루" vs " 콜드브루 " vs "COLD브루").
    - 다른 brand 간 동일 이름 → 허용.
    - brand sub 와 store sub 동일 이름 → 허용 (scope 격리).
    - 수정 모드에서 자기 자신의 이름 그대로 저장 → 정상 (excludeId).
    - 디바운스 lookup race: 빠르게 타이핑 + submit → UseCase 가 최종 차단.
  - **권한 매트릭스 검증**:
    - brand 본사만 자기 brandId 의 brand scope CRUD.
    - 가맹점 점주는 brand sub CRUD UI 자체가 미노출 (진입 tile 없음).
    - owner 개인 매장 점주만 자기 storeId 의 store scope CRUD.
    - brand 가맹점 점주가 store sub CRUD 시도 → 차단 (UseCase 가드).
    - admin 은 sub-category CRUD 진입 tile 자체가 없음 (회귀 — `AdminMorePage` 변경 없음 확인).
  - **회귀 테스트**:
    - sub-phase 1 (brand_master) — 마스터 메뉴 등록/수정 시 sub 칩 추가됐어도 기존 흐름 정상.
    - sub-phase 3 (brand_store_customization) — store-only 메뉴 폼 정상.
    - sub-phase 4 (owner_personal_menu) — 개인 매장 메뉴 폼 정상.
    - sub-phase 9 (메인 카테고리) — 충돌 없음. 메인 inactive 시 sub 도 자연 미노출.
    - customer 매장 메뉴 탭 — sub 칩 회귀 (가맹점은 brand sub, 개인 매장은 store sub 동작).
- **반드시 확인할 예외 케이스**:
  - menuItem.subCategoryId 가 어떤 컬렉션에도 없는 id 일 때 customer / 메뉴 폼 동작 (자연 제외 / fallback 라벨).
  - main 카테고리 inactive 상태에서 sub CRUD 시도 (등록 폼에서 main 후보 제외 정상).
  - 메뉴 폼 main 변경 → sub reset 정상 (이전 sub id 가 자동 비워지는지).
  - 시드 race / upsert 동시성 (set merge — idempotent + duplicate 체크 race 시 두 번째 실패).
  - 가맹점 점주 사용자가 직접 link/route 우회로 brand CRUD 페이지 접근 시도 (가능한지 점검).
  - audit: 기존 menuItem.subCategoryId 분포 — 글로벌 sub id 외에 다른 값이 있는지. tester `test_report.md` 에 분포 명시. 이상 doc 발견 시 architect 보고.

---

## 마이그레이션 단계 (단계별 / 단일 PR)

> 단일 PR 로 한 번에 머지. 부분 PR 시 entity 필드 확장 + 호출처 다수 깨짐.

```text
[Step 1] 도메인 + 데이터 인프라
  - lib/domain/entities/sub_category_scope.dart (신규, brand/store)
  - lib/domain/entities/sub_category_entity.dart 필드 확장 + freezed 재생성
  - lib/domain/repositories/sub_category_repository.dart (신규, findDuplicateName 포함)
  - lib/domain/repositories/menu_category_repository.dart signature 확장 (단일 scope)
  - lib/core/errors/sub_category_in_use_exception.dart (신규)
  - lib/core/errors/duplicate_sub_category_name_exception.dart (신규)
  - lib/data/models/sub_category_model.dart 필드 확장 + path resolver (brand/store only)
  - lib/data/datasources/remote/sub_category_remote_data_source.dart 확장 (2-tier)
  - lib/data/repositories/menu_category_repository_impl.dart 단일 scope read 구현
  - lib/data/repositories/sub_category_repository_impl.dart (신규)
  - UseCase 7개 신규/확장 (Watch / WatchByScope / Upsert / Delete / ToggleActive / CountUsage / FindDuplicateName)
  - DI providers
  - firestore.indexes.json: collectionGroup('menuItems') / subCategoryId asc 인덱스 추가

[Step 2] 메뉴 폼 sub 칩 영역 (3종)
  - lib/presentation/common/widgets/sub_category_chips_selector.dart (신규)
  - MasterMenuFormPage / BrandStoreOnlyMenuFormPage / OwnerStoreMenuFormPage
    - main 칩 직하에 sub 칩 영역 추가
    - cascade reset 로직
    - 저장 시 subCategoryId 사용자 선택값 반영 (기존 baseItem 보존 → 사용자 선택)
    - inactive sub 경고 라벨 (수정 모드)

[Step 3] brand / owner CRUD 화면
  - presentation/brand/menu_categories/ 신규 (brand scaffold 진입점)
  - presentation/owner/menu_categories/ 신규 (owner my_store 진입점)
  - 각 영역에 List / Form / DeleteDialog
  - 진입 tile / CTA 추가 (BrandMorePage / MyStorePage)
  - 가맹점 점주 진입 가드 (currentUserProfile.brandId != null && store.brandId != null → store CRUD 미노출)
  - 폼에 디바운스 중복 이름 lookup + inline 에러 라벨

[Step 4] customer 회귀 보장
  - subCategoriesProvider family parameter 확장 → 매장 컨텍스트(storeId/brandId) 단일 scope read
  - SubCategoryChips 호출 부 (StoreMenuPage) 변경 없음 — provider 결과 동일

[Step 5] 검증
  - flutter analyze 0 error
  - flutter test 전체 통과
  - 수동 회귀 — sub-phase 1/3/4/9 화면 정상
  - 권한 매트릭스 (brand 본사/가맹점 점주/개인 매장 점주) 동작
  - admin 측 변경 없음 회귀 (AdminMorePage 진입점 그대로)
  - 검증 정책 — 같은 scope 동일 이름 차단 / 다른 scope 허용 정상
  - menuItem.subCategoryId audit (분포 + 매칭 정합성)
  - Firestore 인덱스 배포 확인
```

---

## 사용자 확인 필요 항목 (요약 — 모두 확정)

| # | 결정 포인트 | 확정 결과 |
|---|---|---|
| 1 | scope 분리 모델 | **A안 — 2-tier (brand / store). 글로벌(admin) sub 없음** |
| 2 | brand 본사 진입 위치 | `BrandMorePage` tile (확정) |
| 2 | owner 개인 매장 진입 위치 | `MyStorePage` "메뉴 관리" 영역 (확정) |
| 2 | admin 측 진입 | **신규 없음** (글로벌 sub 부재) |
| 3 | 메뉴 폼 sub 선택 UI / cascade | 신규 추가 + main 변경 시 reset + sub 는 선택 사항 |
| 4 | 삭제 정책 | hard delete 차단 + active 토글 |
| 5 | main → sub cascade | sub-phase 9 main 삭제 차단 정책으로 자동 보호 |
| 6 | scope 별 메뉴 폼 노출 sub | Master/BrandStoreOnly: brand 만. OwnerStoreMenu: store 만 (단일 scope) |
| 7 | main 카테고리 비활성/삭제 시 sub cascade | 결정 5 와 통합 — cascade 미발생 |
| 추가 | 검증 정책 (옵션 2 — 약한 검증) | **같은 scope 내 동일 normalized name (대소문자/공백 무시) 차단. 다른 scope 간 허용. 오타/유사명 자동 감지는 비범위 (Follow-up)** |
| 보너스 | Repository 책임 분할 | `MenuCategoryRepository` (read) + `SubCategoryRepository` (CRUD) 분리 |

---

## 완료 기준

- [x] 사용자가 결정 1 / 2 / 6 / 검증 정책 회신 → spec APPROVED 격상
- [ ] `design.md` 작성 (designer) — A/B/C/D 4개 영역 반영 (E admin 영역은 변경 없음)
- [ ] `implementation.md` 작성 (developer) + `flutter analyze` 0 error + `flutter test` 통과
- [ ] sub-category CRUD 2-tier (brand/owner) 정상 동작
- [ ] 메뉴 폼 3종 sub 칩 동작 + 저장 시 subCategoryId 반영
- [ ] customer 매장 메뉴 탭 sub 칩 회귀 PASS
- [ ] sub-phase 1 / 3 / 4 / 9 회귀 PASS
- [ ] menuItem.subCategoryId audit 통과
- [ ] Firestore 인덱스 배포 확인
- [ ] 권한 매트릭스 검증 (brand 본사/가맹점 점주/개인 매장 점주) PASS
- [ ] 검증 정책 (같은 scope 동일 이름 차단 / 다른 scope 허용) PASS
- [ ] `test_report.md` FAIL 없음 또는 후속 작업으로 분리

---

## Follow-up / 다음 작업 후보

본 sub-phase 8 의 비범위로 분리된 항목 + 향후 phase 후보.

### F1. Firestore 보안 규칙 강화

본 phase 는 클라이언트 가드만. 보안 규칙으로 `brands/{brandId}/subCategories` write 가 그 brand 의 본사 uid 만 가능하도록 + `stores/{storeId}/subCategories` write 가 그 매장 owner uid 만 가능하도록 강화 필요. **별 phase**.

### F2. 가맹점 점주가 매장 한정 sub 추가하는 시나리오

본 phase 는 가맹점 점주 read-only. 운영 데이터 / 사용자 요구 검토 후 도입 결정. 도입 시 `stores/{storeId}/subCategories` 가 가맹점 매장에서도 활용 가능 — 단 본사 sub 와 가맹점 자체 sub 의 섞임 정책 (3-tier 머지) 재합의 필요.

### F3. 부 카테고리 시각 토큰 (이미지 / 색상)

본 sub-phase 비범위. label/displayOrder/active 까지만. 시각 토큰 도입 phase 후보.

### F4. label 다국어화 (i18n)

`labels: {ko, en}` 구조. i18n 도입 phase 와 묶임.

### F5. sub-category 비활성 운영 알림 (4d Heavy 와 묶음)

sub-phase 9 의 4d Heavy 와 동일 인프라 (FCM/이메일) 위에 sub-category 도 운영 알림 추가 후보.

### F6. `MenuCategories.all` (12개 string) 동적화

매장 분류 태그. 본 sub-phase 와 별개 도메인. **별 phase 후보**.

### F7. 오타 / 유사명 자동 감지 (NLP / 임베딩)

검증 정책 옵션 2 (약한 검증) 의 한계. '콜드브루' vs '콜드부루' 같은 유사명을 normalized 정확 일치만으로 못 잡음. 임베딩 유사도 / 편집 거리 기반 탐지 + 사용자 확인 다이얼로그 도입 후보. **별 phase**.

### F8. admin 운영 모니터링 / 동의어 정리 도구

글로벌 sub 부재로 본 phase 비범위. brand/store 가 자율로 만들어내는 sub 의 분포 / 중복 / 유사명 통계를 admin 이 모니터링하고, 동의어 그룹핑 / 권장 정리 액션을 제공하는 도구. 운영 데이터 누적 후 도입 검토. **별 phase**.

### F9. 글로벌 (master) sub 재도입 검토

운영 데이터/요구가 누적된 시점에 admin 이 시즌/공통 분류를 일괄 제공하는 시나리오 재논의. 도입 시 본 spec 의 결정 1 을 3-tier 로 격상. **별 phase 후보**.
