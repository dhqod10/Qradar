# sub-phase 9 — menu_main_category_admin 기능 명세

> **상태**: APPROVED — 사용자 결정 1~4 + 4a/b/c/d Lite 확정 (2026-05-03). 4d Heavy 범위는 Follow-up 으로 분리.
>
> **umbrella 단일 진실원**: `admin_menu_management/spec.md` 의 데이터 모델 / 권한 매트릭스를 따른다.
>
> 본 sub-phase 는 sub-phase 1 (brand_master) ~ sub-phase 8 (sub-category) 위에 쌓인다. 메인 카테고리(coffee/nonCoffee/dessert) 를 **글로벌 admin CRUD 가능한 동적 데이터** 로 전환한다.

---

## 개요

- **목적**: 메뉴의 메인 카테고리(현재 `MainCategoryCode` enum 3개 hard-coded — coffee / nonCoffee / dessert)를 **admin 이 글로벌로 추가/수정/비활성화 가능한 동적 컬렉션** 으로 전환한다. 기존 enum 기반 데이터(메뉴 폼 칩, customer 매장 메뉴 탭, sub-category 의 메인 분류)를 동적 fetch 기반으로 마이그레이션한다.
- **작업 유형**: 리팩터링 + 신규 기능 (도메인 + 데이터 + 다수 화면 + admin CRUD UI 신규)
- **영향 범위**:
  - 화면(admin): `AdminMainCategoryListPage` (신규), `AdminMainCategoryFormPage` (신규), `MainCategoryDeactivateConfirmDialog` (신규 — 4d Lite 영향 데이터 N/M 표시)
  - 화면(brand): `MasterMenuFormPage` 의 `_categories` 칩 → 동적 fetch 로 전환 + **(4d Lite) 비활성 카테고리 선택 시 경고 라벨**
  - 화면(brand): `BrandStoreOnlyMenuFormPage` 의 `_categories` 칩 → 동적 fetch 로 전환 + **(4d Lite) 비활성 카테고리 선택 시 경고 라벨**
  - 화면(owner): `OwnerStoreMenuFormPage` 의 `_categories` 칩 → 동적 fetch 로 전환 + **(4d Lite) 비활성 카테고리 선택 시 경고 라벨**
  - 화면(brand/owner): **(4d Lite, 옵션) 메뉴 리스트 카드** — 비활성 카테고리에 묶인 메뉴 시각 marker (designer 결정)
  - 화면(customer): `MainCategoryTabs` (`_all` 하드코딩 3개) → 동적 fetch 기반으로 전환 (확정 4b — inactive 카테고리 제외)
  - Domain: `MainCategoryEntity` (신규), `MainCategoryRepository` (신규), `MainCategoryCode` enum **제거**(또는 deprecated wrapper). `MenuItemEntity.mainCategoryCode` / `SubCategoryEntity.mainCategoryCode` 타입 변경 (enum → String id)
  - Data: `MainCategoryModel` (신규), `MainCategoryRemoteDataSource` (신규), `MainCategoryRepositoryImpl` (신규). `MenuItemModel.mainCategory` / `SubCategoryModel.mainCategory` 매핑 그대로 유지 (이미 string)
  - Presentation: `presentation/admin/menu_categories/` 트리 신설, `presentation/admin/more/admin_more_page.dart` 에 진입 타일 추가
  - 라우팅: 변경 없음 (admin scaffold 내부 push)
  - 권한 / 환경 설정: admin role 만 CRUD. 기타 role 은 read-only stream
  - 테스트: 기존 customer / brand / owner 메뉴 폼 + customer 매장 메뉴 탭 회귀
- **비범위** (이번 작업에서 명시적으로 제외):
  - **부 카테고리(`subCategories`) CRUD** → sub-phase 8 별건. 본 sub-phase 는 메인 카테고리만 다룬다.
  - **옵션 그룹 CRUD** → sub-phase 7 별건.
  - **`MenuCategories.all`** (12개 string 리스트) — 매장의 `menuCategories(List<String>)` 와 customer 홈 카테고리 필터에서 사용. **본 sub-phase 와 별개 도메인** (매장 분류용 태그) 이므로 손대지 않는다. 이 부분의 동적화는 별도 phase 후보.
  - 메인 카테고리 **이미지 / 배너 / 색상 토큰** — 이번엔 label / displayOrder / active 까지만. 시각 토큰은 다음 phase.
  - **다국어 label** (label 을 1언어 string 으로만 저장). i18n 도입 시 `labels: {ko, en}` 으로 확장 가능한 구조만 잡고 본 sub-phase 는 ko 단일.
  - **삭제 시 cascade 정책** 의 **자동 마이그레이션** (예: 카테고리 삭제 시 메뉴 mainCategoryCode 일괄 변경 batch). UI 차단 정책으로 우선 보호 (아래 결정 4 참조).

---

## 의존 phase / 진입 조건

- **의존 phase**:
  - sub-phase 1 (brand_master): `MenuItemEntity` 의 mainCategoryCode 필드 / `MainCategoryCode` enum 모두 sub-phase 1 산출물.
  - sub-phase 8 (sub-category admin): 부 카테고리 형태/admin CRUD 패턴이 본 sub-phase 의 참고 모델. 동일 admin scaffold/패턴 재사용.
- **진입 조건**:
  - 위 두 sub-phase APPROVED + 안정 상태.
  - 결정 1~4 + 4a/b/c/d Lite **사용자 확정 완료 (2026-05-03)**.
  - Firestore 시드 스크립트(또는 1회성 admin 계정 시드 액션)로 기존 enum 3개를 `mainCategories/coffee` / `mainCategories/nonCoffee` / `mainCategories/dessert` 문서로 시드 가능.

---

## 핵심 결정 포인트 (확정)

> 4개 결정 모두 **사용자 확정 (2026-05-03)**. 4d 는 Lite 범위만 본 phase 포함, Heavy 범위는 Follow-up.

### 결정 1. enum 유지 vs 제거 — **확정: (A) enum 완전 제거**

| 안 | 설명 | 평가 |
|---|---|---|
| (A) enum 제거 | `MenuItemEntity.mainCategoryCode: String` (Firestore doc id). enum 파일 삭제. customer/brand/owner 모두 동적 fetch | **확정** — 단순. 동적 데이터의 목적과 정합. 마이그레이션 1회 |
| (B) enum + doc 병행 | default 3개는 enum, 추가는 doc only | 복잡성 폭증. enum 추가 시마다 코드 빌드 필요 — 동적화 의미 상실 |
| (C) string-typed wrapper class | `MainCategoryCode` 를 `String id` 를 감싸는 클래스로 | 변경 라인은 적지만 의미 없음 (label/asString 같은 정적 메서드가 사라지므로 결국 String 과 동일) |

**확정 결정 이유**:
- 동적 데이터로 만드는 목적 자체가 "코드 변경 없이 admin 이 추가/수정" 이므로 enum 유지는 모순.
- 마이그레이션 1회 (enum.asString 값을 그대로 doc id 로 시드) 만 하면 기존 menuItem 의 `mainCategory: 'coffee'` 값이 그대로 새 doc 의 id 와 매칭됨 → 기존 데이터 무수정.
- `MenuItemEntity.mainCategoryCode: String` 으로 변경. 필드명은 그대로 두되 의미는 "메인 카테고리 doc id" 로 재정의. (필드명 자체를 `mainCategoryId` 로 rename 하는 옵션도 있으나, Firestore 필드명/저장값 무수정 정책 + diff 최소화 위해 entity 필드명 유지 — 호출처 차이는 타입만 변경됨)
- `label` 은 entity 가 모르고 Repository fetch 결과 (`MainCategoryEntity.label`) 로 표시. 호출처는 id → label 매핑 stream 을 watch.

**기각된 안의 처리**:
- (B) enum + doc 병행은 복잡성/유지비 대비 이득 없음 — 기각.
- (C) wrapper class 는 동적화가 아닌 단순 typedef 이므로 의미 없음 — 기각.

---

### 결정 2. 마이그레이션 — **확정: (A) admin 첫 진입 자동 1회 시드 (idempotent)**

- 기존 menuItem 의 `mainCategory` 필드값은 `'coffee'` / `'nonCoffee'` / `'dessert'` 문자열로 이미 저장돼 있음.
- 신규 `mainCategories/{id}` 컬렉션에 위 3개와 **동일 id** 로 doc 시드:
  ```text
  mainCategories/coffee     { label: '커피',   displayOrder: 0, active: true }
  mainCategories/nonCoffee  { label: '논커피', displayOrder: 1, active: true }
  mainCategories/dessert    { label: '디저트', displayOrder: 2, active: true }
  ```
- 시드 시점:
  - **확정 (A)**: `MainCategoryRemoteDataSource.seedDefaultsIfEmpty()` 메서드. **admin 페이지 첫 진입 시** 컬렉션이 비었으면 1회 실행 (idempotent — 컬렉션 비었을 때만 실행).
  - (기각) 방법 B: 별도 admin "시드" 버튼 (수동).
  - (기각) 방법 C: Firebase Functions (배포 시 자동) — 본 sub-phase 비범위 (Phase 1 MVP 는 Firestore Functions 미사용).
- **menuItem.mainCategory / subCategory.mainCategory 필드 무수정** — id 가 그대로 호환되므로 자동 마이그레이션 불필요.

**리스크 (확정 4c 로 처리)**:
- 기존 prod / dev DB 에 `'coffee'` / `'nonCoffee'` / `'dessert'` 외의 값이 들어간 menuItem 존재 가능성. 이전 hotfix 노트(`MainCategoryCode.fromString` default → `coffee`) 로 봤을 때 silent fallback 으로 잘못 박힌 doc 있을 수 있음. **tester 가 일회성 데이터 audit (확정 4c)**.

---

### 결정 3. admin UI 위치 — **확정: `AdminMorePage` 의 신규 ListTile**

- `AdminScaffold` 는 2탭 (승인 큐 / 더보기) 구조. 메인 카테고리 관리는 운영 빈도 낮음 → "더보기" 탭에 진입 타일 추가.
- 라우팅 흐름:
  ```text
  AdminScaffold > 더보기 탭
    → AdminMorePage 의 "메인 카테고리 관리" Tile
       → AdminMainCategoryListPage (Navigator.push)
          → "+" 버튼 → AdminMainCategoryFormPage (등록)
          → list item tap → AdminMainCategoryFormPage (수정)
          → list item swipe / "삭제" 버튼 → 삭제 다이얼로그
  ```
- 동일 패턴으로 sub-phase 8 부 카테고리 관리 타일도 같은 위치에 둔다 (이미 둘 수 있다면). 본 sub-phase 는 메인 카테고리 타일만 추가.

**기각된 안**:
- 별도 3번째 탭으로 추가 — admin 진입 빈도 낮은 운영 기능을 메인 탭으로 올리는 것은 정보 위계 부적합.

---

### 결정 4. 삭제 정책 — **확정: (B) 사용 중이면 삭제 차단 + active=false 비활성화 허용**

| 정책 | 설명 | 평가 |
|---|---|---|
| (A) cascade 삭제 | 메인 카테고리 삭제 시 그 카테고리의 menuItem / subCategory 모두 삭제 | 위험. 운영 실수로 다수 메뉴 소실 가능 |
| (B) **삭제 차단 + active 토글** | 카테고리 사용 중(menuItem 또는 subCategory 1개 이상 참조)이면 hard delete 차단. UI 에 "사용 중 X개" 표시 + active=false 토글 만 허용 | **확정** — 안전. customer 화면은 active=true 만 표시, admin 은 inactive 도 보임 |
| (C) 미분류 이동 | 삭제 시 그 카테고리의 menuItem 들을 "기타" 카테고리로 batch 이동 | "기타" 카테고리 자체가 또다른 마법값. 명확하지 않음 |

**확정 결정 이유**:
- 메인 카테고리는 menuItem 의 핵심 분류 키. 의도치 않은 cascade 는 회복 불가.
- "active=false" 는 신규 메뉴 등록/수정 폼에서 그 카테고리를 선택지에서 제외 + customer/brand/owner 화면 노출 제외하지만, 기존 menuItem 의 mainCategoryCode 값은 보존 → admin 이 다시 active 로 되돌릴 수 있음 (회복 가능).
- "사용 중 0개" 가 된 카테고리는 hard delete 허용.

**삭제 차단 검증 쿼리** (확정 4a):
- menuItem: collectionGroup('menuItems') where mainCategory == catId limit 1 → exists?
- subCategory: collection('subCategories') where mainCategory == catId limit 1 → exists?
- 둘 중 하나라도 exists → 삭제 차단.
- **Firestore 인덱스 1개 추가**: collectionGroup('menuItems') / mainCategory asc — `firestore.indexes.json` 갱신 필요.

**비활성(active=false) 시 customer/brand/owner 동작**:
- 신규 등록 폼: 칩에서 제외 (active=true 만 노출).
- 기존 메뉴 수정 폼: 그 메뉴가 inactive 카테고리에 속해 있으면 칩에 inactive 카테고리도 노출(disabled marker) — 사용자가 다른 카테고리로 옮길 수 있게.
- customer 매장 메뉴 탭(`MainCategoryTabs`): active=true && 매장 메뉴 보유 카테고리만 노출. inactive 카테고리는 menuItem 이 그 카테고리에 묶여 있어도 탭에서 제외 (확정 4b — 사용자 노출 제외).

### 결정 4a — collectionGroup 인덱스 — **확정: 인덱스 1개 추가 OK**

- collectionGroup('menuItems') / mainCategory 인덱스를 `firestore.indexes.json` 에 추가.
- developer 작업 항목에 인덱스 파일 갱신 명시.

### 결정 4b — inactive 카테고리 customer 노출 — **확정: 탭에서 제외**

- customer 매장 메뉴 탭에서 inactive 카테고리는 제외. 그 카테고리에 묶인 매장 메뉴는 customer 가 보지 못함.
- 운영자/점주는 admin 의 비활성 알림 (확정 4d Lite) 을 통해 카테고리 변경 필요성을 인지하고 능동 대응.

### 결정 4c — prod/dev 데이터 audit — **확정: tester 1회 audit**

- tester 가 마이그레이션 직전/직후 `mainCategory` 필드값 분포 audit.
- 'coffee' / 'nonCoffee' / 'dessert' 외 값이 발견되면 architect 재합의.

### 결정 4d (Lite) — inactive 카테고리 운영 알림 — **확정: 본 phase 에 Lite 범위 포함**

본 phase 에 포함하는 Lite 범위 3가지:

1. **admin 비활성화 confirm dialog 영향 데이터 표시**
   - admin 이 카테고리를 active=false 로 토글하거나 비활성화 confirm dialog 진입 시
   - 다이얼로그에 "이 카테고리에 매장 N곳, 메뉴 M개가 연결되어 있어요" 표시
   - 추가 쿼리: collectionGroup('menuItems').where(mainCategory==id) → 메뉴 수 (count aggregate). 매장 수는 메뉴들의 distinct storeId set.size 또는 storeMenuIndex 활용 — Repository 가 캡슐화

2. **점주/브랜드 메뉴 폼: 비활성 카테고리 선택 시 시각 경고**
   - 메뉴 수정 모드에서 그 메뉴의 mainCategoryCode 가 inactive 카테고리이면
   - 폼에 시각적 경고 라벨 / 문구: "이 카테고리는 비활성화되었습니다. 다른 카테고리로 변경해주세요" 노출
   - 적용 폼 3종: `MasterMenuFormPage`, `BrandStoreOnlyMenuFormPage`, `OwnerStoreMenuFormPage`

3. **점주/브랜드 메뉴 리스트: 비활성 카테고리 메뉴 시각 표시 (옵션 — designer 결정)**
   - 메뉴 리스트의 카드도 비활성 카테고리에 묶여있으면 시각적 marker (예: 배지 / dim / 경고 아이콘)
   - 시각 토큰 / 강도는 designer 가 결정

본 phase 비범위 (Heavy 범위 — Follow-up 으로 분리, 아래 "Follow-up / 다음 작업 후보" 섹션 참조):
- FCM 푸시 알림 / 이메일 통보로 매장 운영자에게 적극 알림
- 알림 인프라 (FCM 토큰 관리, sending pipeline, 타임 트리거)

---

## 요구사항

### 기능 요구사항

#### admin (CRUD)
- [ ] `MainCategoryListPage` — 메인 카테고리 목록 (label / displayOrder / active / "사용 중 X개" 표시).
- [ ] `MainCategoryFormPage` — 등록 / 수정 (id, label, displayOrder, active).
  - id 는 등록 시에만 입력 가능. 수정 시 read-only.
  - id 형식 가이드: lowerCamelCase, 영문 + 숫자, 최대 20자. (예: `coffee`, `nonCoffee`, `bakery`, `sandwich`, `juice`)
  - label: 1~10자 한글 / 영문 / 숫자.
  - displayOrder: 정수, 0 이상.
  - active: bool, 기본 true.
- [ ] 삭제: 사용 중 검사 → 0개면 hard delete, 1개 이상이면 차단 + 토스트 "사용 중 N개. 비활성으로만 가능".
- [ ] 비활성 토글: list 에서 직접 active 토글 가능.

#### read (전 role)
- [ ] `MainCategoryRepository.watchAll(activeOnly: bool)` — active=true 만 / 전체 stream.
- [ ] customer 매장 메뉴 탭: `MainCategoryTabs` 가 동적 카테고리 stream 을 watch. activeOnly=true.
- [ ] brand / owner 메뉴 폼 칩: 동적 카테고리 stream watch. activeOnly=true (단 수정 모드에서 메뉴가 inactive 카테고리에 속해 있으면 그 카테고리도 disabled chip 으로 노출).

#### 마이그레이션
- [ ] `mainCategories` 컬렉션 시드: enum 3개 동일 id 로 (default seed).
- [ ] enum (`MainCategoryCode`) 사용처 전수 제거 또는 deprecated 처리.

### UI 요구사항
- [ ] `AdminMorePage` 에 "메인 카테고리 관리" tile 추가.
- [ ] `AdminMainCategoryListPage` — 디자인 가이드 신규 (designer 산출물).
- [ ] `AdminMainCategoryFormPage` — 디자인 가이드 신규.
- [ ] **(4d Lite) `MainCategoryDeactivateConfirmDialog`** — 영향 데이터 ("매장 N곳, 메뉴 M개") 표시. designer 신규.
- [ ] **(4d Lite) 메뉴 폼 3종 (Master/BrandStoreOnly/OwnerStoreMenu) 비활성 카테고리 경고 라벨** — 시각/카피 designer 정의.
- [ ] **(4d Lite, 옵션) 점주/브랜드 메뉴 리스트 카드 비활성 marker** — designer 적용 결정.
- [ ] customer 화면 — 시각적 변경 없음 (label/순서/inactive 제외 외).

### 상태 요구사항
- [ ] loading: stream 첫 emit 전 — shimmer 또는 placeholder.
- [ ] error: stream error — 에러 화면 + retry.
- [ ] empty: 카테고리 0개 — admin 은 "+ 추가" 안내, customer/brand/owner 는 "분류가 없습니다" + 운영팀 안내.

---

## 데이터 모델

### Entity (Domain)

```dart
// lib/domain/entities/main_category_entity.dart
@freezed
abstract class MainCategoryEntity with _$MainCategoryEntity {
  const factory MainCategoryEntity({
    required String id,           // 'coffee', 'nonCoffee', 'dessert', 'bakery'...
    required String label,        // '커피', '논커피', '디저트', '베이커리'...
    @Default(0) int displayOrder, // 정렬 순서. asc.
    @Default(true) bool active,   // false 면 신규 폼 / customer 노출 제외
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _MainCategoryEntity;
}
```

### Model (Data, Firestore `mainCategories/{id}`)

```text
mainCategories/{id}
  - label: string
  - displayOrder: number
  - active: bool
  - createdAt: timestamp
  - updatedAt: timestamp
```

`MainCategoryModel.fromFirestore` / `toFirestore` / `toEntity` / `fromEntity` 모두 평이.

### MenuItemEntity 변경

- `mainCategoryCode: MainCategoryCode` → `mainCategoryCode: String`
- 필드명 / Firestore 저장 키 (`mainCategory`) 변경 없음. 의미만 "메인 카테고리 doc id" 로 재정의.

### SubCategoryEntity 변경

- `mainCategoryCode: MainCategoryCode` → `mainCategoryCode: String`
- 동일하게 의미만 재정의.

### MainCategoryCode enum

- **제거** (결정 1 채택 시).
- 호출처:
  - `lib/domain/entities/main_category_code.dart` — 파일 삭제.
  - `MenuItemModel.toEntity()` 의 `MainCategoryCode.fromString(...)` → 직접 string 사용.
  - `SubCategoryModel.toEntity()` 동일.
  - `MenuCategoryRepository.watchSubCategories(MainCategoryCode main)` → `(String mainCategoryId)`.
  - `WatchSubCategoriesUseCase` 시그니처 변경.
  - `subCategoriesProvider` family parameter 변경.
  - 메뉴 폼 3종 `_categories` 하드코딩 제거 → stream watch.
  - `MainCategoryTabs._all` 제거 → props 로 카테고리 list 받음.
  - `selectedMainCategoryProvider` 의 build 기본값 — `MainCategoryCode.coffee` → `null` 또는 첫 active 카테고리 id (lazy 초기화 필요. 아래 "데이터 흐름" 참조).
  - `storeAvailableMainCategoriesProvider` — `Set<MainCategoryCode>` → `Set<String>`.

---

## 레이어 설계

### Domain
- Entity: `MainCategoryEntity` (신규).
- UseCase:
  - `WatchMainCategoriesUseCase(activeOnly)` — read.
  - `UpsertMainCategoryUseCase` — admin 등록/수정.
  - `DeleteMainCategoryUseCase(id)` — 사용 중 검사 + delete (Repository 가 검사 책임).
  - `ToggleMainCategoryActiveUseCase(id, active)` — list 에서 직접 토글.
  - (선택) `CountMainCategoryUsageUseCase(id)` — list 에 "사용 중 X개" 표시용.
- Repository Interface: `MainCategoryRepository`
  ```dart
  abstract class MainCategoryRepository {
    Stream<List<MainCategoryEntity>> watchAll({bool activeOnly = false});
    Future<MainCategoryEntity?> findById(String id);
    Future<void> upsert(MainCategoryEntity entity); // admin only
    Future<void> delete(String id);                  // admin only — 내부에서 사용 중 검사
    Future<int> countUsage(String id);               // menuItem + subCategory 사용 합계
    Future<void> seedDefaultsIfEmpty();              // 1회성 시드
  }
  ```
- Domain Error:
  - `MainCategoryInUseException` — delete 시 사용 중인 경우 throw.

### Data
- Model: `MainCategoryModel`.
- DataSource: `MainCategoryRemoteDataSource`
  - `streamAll({activeOnly})` — orderBy(displayOrder).
  - `getById(id)`.
  - `upsert(model)` — set with merge.
  - `delete(id)` — delete (Repository 가 사용 중 검사 후 호출).
  - `countUsage(id)` — collectionGroup('menuItems').where(mainCategory == id).limit(1) + collection('subCategories').where(mainCategory == id).limit(1) 를 count 또는 exists 결합. **잠정**: `int.count` 가 비싸므로 limit(1) 두 번으로 사용 여부만 확인 (사용/미사용 boolean 으로 충분 — 정확한 N 은 list 에 noisy. 단 list UI 에 "X개" 가 필요하면 진짜 count 쿼리 사용. Firestore aggregate `count()` 사용 가능 — Phase 1 MVP 에서 가용).
  - `seedDefaultsIfEmpty()` — collection 이 empty 면 batch 로 3개 doc 시드.
- Repository Implementation: `MainCategoryRepositoryImpl`.
  - `delete(id)`: countUsage > 0 → `MainCategoryInUseException`. 0 이면 dataSource.delete.

### Presentation

- Provider:
  - `mainCategoryRepositoryProvider`.
  - `watchMainCategoriesProvider({activeOnly})` — StreamProvider.
  - `mainCategoriesActiveProvider` — `watchMainCategoriesProvider(activeOnly: true)` shorthand.
  - `mainCategoriesAllProvider` — admin 용 (inactive 포함).
  - `mainCategoryUsageProvider.family<int, String>` — list 에서 사용 중 X개 표시.
- Page:
  - `AdminMainCategoryListPage`.
  - `AdminMainCategoryFormPage`.
- Widget:
  - admin: `MainCategoryListItem`, `MainCategoryDeleteDialog`, `MainCategoryActiveSwitch`.
- 기존 widget 변경:
  - `MainCategoryTabs` — `availableCategories: Set<String>` + `categories: List<MainCategoryEntity>` props 받게 변경. `_all` 제거.
  - 메뉴 폼 3종 — `_categories` 하드코딩 제거. `mainCategoriesActiveProvider` watch + 수정 모드 inactive fallback.
- 기존 provider 변경:
  - `selectedMainCategoryProvider`: `Notifier<MainCategoryCode>` → `Notifier<String?>`.
    - build 기본값: null. 첫 카테고리 stream 도착 시 page-level effect 가 `select(firstActive.id)`. (또는 family `<String, String storeId>` 로 전환해서 매장 단위로 첫 카테고리 자동 선택)
  - `subCategoriesProvider.family<List<SubCategoryEntity>, MainCategoryCode>` → `family<…, String>`.
  - `storeAvailableMainCategoriesProvider` → `Set<String>`.

### 라우팅
- 변경 없음. admin scaffold 내부 push.

---

## 데이터 흐름

### admin 등록
```text
AdminMainCategoryFormPage
  → upsertMainCategoryProvider
  → UpsertMainCategoryUseCase
  → MainCategoryRepository
  → MainCategoryRepositoryImpl
  → MainCategoryRemoteDataSource.upsert
  → Firestore mainCategories/{id} set merge
```

### admin 삭제
```text
AdminMainCategoryListPage (delete 버튼)
  → DeleteDialog "사용 중 N개" 검사 후
  → deleteMainCategoryProvider
  → DeleteMainCategoryUseCase
  → MainCategoryRepositoryImpl.delete (countUsage 후 0 이면 delete)
  → MainCategoryInUseException 시 토스트 / 차단
```

### customer 매장 메뉴 탭
```text
StoreMenuPage
  → mainCategoriesActiveProvider.watch
  → MainCategoryTabs(categories: data, availableCategories: storeAvailableMainCategoriesProvider, selected: selectedMainCategoryProvider)
  → onSelect → selectedMainCategoryProvider.select(id)
```

### brand/owner 메뉴 폼 칩
```text
MasterMenuFormPage initState
  → ref.read(mainCategoriesActiveProvider).future 또는 build 시 ref.watch
  → 칩 build 에서 fetch 결과 사용
  → 수정 모드: editItem.mainCategoryCode 가 inactive 카테고리이면, mainCategoriesAllProvider 에서 해당 doc 1개를 추가로 머지
```

### 기본 선택값 초기화
- `selectedMainCategoryProvider` 의 초기값이 null 이고 첫 카테고리가 stream 으로 늦게 도착하므로, `StoreMenuPage` 가 first non-null data 시 1회만 `select(firstActive.id)` 하는 effect 추가.
- 또는 `selectedMainCategoryProvider` 를 `family<String?, String storeId>` 로 만들고 build 시 `mainCategoriesActiveProvider.future` 의 첫 element 로 초기화 (단 future 의존이라 복잡. effect 권장).

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| read stream error | 에러 UI + retry. invalidate 로 재구독 |
| upsert 실패 (네트워크) | snackbar 에러 토스트 + form 유지 |
| delete 시 사용 중 (`MainCategoryInUseException`) | 다이얼로그 차단 + "사용 중 N개. 비활성으로만 가능" + active=false 제안 버튼 |
| 카테고리 0개 (empty) | admin: "+ 추가" CTA. customer/brand/owner: "분류가 없습니다" 안내 + 운영팀 문의 |
| inactive 카테고리에 속한 메뉴 (수정 모드) | 폼 칩에 inactive label 표시(disabled marker) + "다른 카테고리로 옮기세요" 가이드 텍스트 |
| 시드 race (두 admin 동시 첫 진입) | seedDefaultsIfEmpty 가 batch.set with merge 이므로 idempotent — 중복 doc 발생하지 않음 |
| menuItem `mainCategory` 가 mainCategories 컬렉션에 없는 값 | customer 매장 메뉴 탭에서 그 메뉴 제외 (필터 통과 안 됨). admin 진단용 audit 쿼리 — tester 영역 |

---

## 작업 분배

### designer

- **UI 변경 필요 여부**: YES.
- **디자인 산출물** (`design.md` 작성):

  **A. admin 카테고리 관리 화면들 (메인)**
  - `AdminMorePage` 의 "메인 카테고리 관리" tile (sub-phase 8 부 카테고리 tile 과 동일 패턴/위치 협의).
  - `AdminMainCategoryListPage`:
    - 헤더 (제목 + "+ 추가" 버튼)
    - list item: label / displayOrder / active toggle / "사용 중 N개" / 우측 chevron / swipe 삭제 또는 우측 메뉴
    - empty 상태
    - loading shimmer
    - error 화면
  - `AdminMainCategoryFormPage`:
    - 등록 모드 / 수정 모드 분기
    - id input (등록만, 형식 가이드 표시 / 수정 시 read-only)
    - label input (1~10자 카운터)
    - displayOrder number input
    - active switch
    - 저장 / 취소 버튼
  - `MainCategoryDeleteDialog`:
    - 사용 중 N개 표시
    - "비활성으로 전환" / "취소" 버튼 (사용 중일 때)
    - "삭제" / "취소" 버튼 (사용 0개일 때)

  **B. (4d Lite — 신규) 비활성화 confirm dialog: 영향 데이터 표시**
  - `MainCategoryDeactivateConfirmDialog` (admin):
    - active=true → false 토글 또는 confirm 진입 시 표시
    - 헤더 + 카테고리 label
    - **영향 데이터 표시** ("이 카테고리에 매장 N곳, 메뉴 M개가 연결되어 있어요")
    - 비활성화 시 customer 노출 제외 + 점주/브랜드 메뉴 폼에서 경고 라벨이 표시된다는 안내 문구
    - "비활성화" / "취소" 버튼 (위험 감지 톤)
    - loading 상태 (count aggregate fetch 중)

  **C. (4d Lite — 신규) 점주/브랜드 메뉴 폼: 비활성 카테고리 경고 라벨**
  - 적용 화면 3종: `MasterMenuFormPage`, `BrandStoreOnlyMenuFormPage`, `OwnerStoreMenuFormPage`
  - 수정 모드에서 그 메뉴의 mainCategoryCode 가 inactive 카테고리일 때:
    - 카테고리 칩 영역 위(또는 인접) **경고 라벨 / 배너**: "이 카테고리는 비활성화되었습니다. 다른 카테고리로 변경해주세요"
    - 칩에 inactive 카테고리도 disabled marker 로 노출 (선택은 가능, 단 시각으로 구분)
    - 톤: warning (Qradar 시스템 색 토큰 활용 — designer 가 적합 토큰 선정)

  **D. (4d Lite — 옵션) 점주/브랜드 메뉴 리스트: 비활성 카테고리 메뉴 시각 marker**
  - 메뉴 카드가 비활성 카테고리에 묶여 있으면 시각적 표시
  - 형태 (배지 / dim / 경고 아이콘 / 행 좌측 strip 등) 는 **designer 가 결정**
  - 적용/생략 여부도 designer 가 결정 (정보 위계상 과도하면 생략 가능 — `design.md` 에 사유 명기)

  **E. 기타 결정 사항**
  - customer `MainCategoryTabs` — 가변 개수(N) 시 가로 스크롤 / 균등 분할 정책 결정
- **전달할 사항**:
  - 본 spec 결정 1~4 + 4a/b/c/d Lite (확정) + Qradar 디자인 토큰 (`AppColors`).
  - sub-phase 8 admin 화면 디자인이 있다면 동일 패턴 재사용.
  - 4d Lite (B/C/D) 는 신규 항목 — designer 가 시각/카피 정의.

### developer

- **구현 항목**:
  - `MainCategoryEntity` (freezed)
  - `MainCategoryModel` (fromFirestore / toFirestore / toEntity / fromEntity)
  - `MainCategoryRemoteDataSource` (streamAll / getById / upsert / delete / countUsage / seedDefaultsIfEmpty)
  - `MainCategoryRepository` interface + `MainCategoryRepositoryImpl`
  - `MainCategoryInUseException`
  - UseCase 5개 (Watch / Upsert / Delete / ToggleActive / CountUsage)
  - DI providers (admin 영역에 추가)
  - `AdminMainCategoryListPage` + `AdminMainCategoryFormPage` + `MainCategoryDeleteDialog`
  - **(4d Lite) `MainCategoryDeactivateConfirmDialog`** (영향 데이터 N/M 표시)
    - Repository 에 `countDetailedUsage(id)` 추가 — `(menuCount, distinctStoreCount)` 반환 (count aggregate 사용)
    - admin list / form 의 active toggle 또는 비활성화 진입 지점에서 dialog 호출
  - **(4d Lite) 점주/브랜드 메뉴 폼 3종 경고 라벨** — `MasterMenuFormPage`, `BrandStoreOnlyMenuFormPage`, `OwnerStoreMenuFormPage`
    - 수정 모드 + 현재 mainCategoryCode 가 inactive (mainCategoriesAllProvider 에서 active=false 로 발견) 일 때 경고 위젯 노출
  - **(4d Lite, 옵션) 점주/브랜드 메뉴 리스트 카드 시각 marker** — designer 결정에 따라 적용
  - `AdminMorePage` tile 추가
  - `FirestorePaths.mainCategories = 'mainCategories'` 추가
  - **(확정 4a) Firestore 인덱스 갱신**: `firestore.indexes.json` 에 collectionGroup('menuItems') / mainCategory asc 인덱스 추가 + 배포 가이드 `implementation.md` 에 명기
  - **마이그레이션 (1회성)**:
    - `MainCategoryCode` enum 제거 (또는 deprecated)
    - `MenuItemEntity.mainCategoryCode` 타입 String 으로 변경 + freezed 재생성
    - `SubCategoryEntity.mainCategoryCode` 타입 String 으로 변경 + freezed 재생성
    - `MenuItemModel.toEntity` / `fromEntity` 의 `MainCategoryCode.fromString` / `.asString` 호출 제거
    - `SubCategoryModel` 동일
    - `MenuCategoryRepository.watchSubCategories(String)` 시그니처 변경
    - `WatchSubCategoriesUseCase` 시그니처 변경
    - `subCategoriesProvider` family String 으로 변경
    - `selectedMainCategoryProvider` 를 `Notifier<String?>` 로 변경 + 첫 카테고리 자동 선택 effect
    - `storeAvailableMainCategoriesProvider` 반환 타입 변경
    - `MainCategoryTabs` props 변경 (categories list 받음)
    - 메뉴 폼 3종 칩 영역을 `mainCategoriesActiveProvider` watch + inactive fallback 머지로 변경
    - 매핑되지 않은 `mainCategory` 값에 대한 customer 측 방어 (필터 제외) 1줄 추가
  - 기존 시드 스크립트가 있다면 `mainCategories` 시드 추가 또는 `seedDefaultsIfEmpty` 첫 진입 자동.
- **재사용할 기존 구조**:
  - sub-phase 8 부 카테고리 admin CRUD 패턴 (참조). 동일 admin scaffold + Repository + UseCase 형태.
  - `FirestorePaths.subCategories` 패턴 재사용.
- **주의할 레이어 규칙**:
  - Firebase import 는 `data/` 에서만.
  - presentation 은 UseCase / Repository interface 만 알 것.
  - `MainCategoryEntity` 는 freezed, 순수 Dart.
  - 매핑 마이그레이션은 enum 제거 → 빌드 깨짐 → `dart run build_runner build --delete-conflicting-outputs` → analyze 0 error 까지 한 번에 완료. 부분 PR 금지.

### tester

- **주요 검증 기준**:
  - **마이그레이션 검증**:
    - 시드 후 `mainCategories` 컬렉션에 3 doc (coffee/nonCoffee/dessert) 존재. 기존 enum 의 label 과 동일.
    - 기존 menuItem 의 `mainCategory` 값 audit — 'coffee'/'nonCoffee'/'dessert' 외 값 존재 여부. 발견 시 architect 재합의.
    - 기존 subCategory 의 `mainCategory` 값 audit 동일.
  - **read 동작**:
    - customer `StoreMenuPage` — 기존 3 카테고리 그대로 노출. label / 순서 admin 가 변경 시 즉시 반영.
    - brand `MasterMenuFormPage` — 기존 3 칩 그대로. admin 가 추가 시 즉시 반영.
    - owner `OwnerStoreMenuFormPage` 동일.
    - brand `BrandStoreOnlyMenuFormPage` 동일.
  - **CRUD 동작**:
    - 등록: id 'bakery' 추가 → 모든 메뉴 폼에 즉시 노출.
    - 수정: label '커피' → '☕커피' 변경 → 모든 화면 라벨 즉시 변경.
    - displayOrder 변경 → customer 탭 순서 변경.
    - active=false → 신규 폼 칩에서 제외, customer 탭에서 제외, 그러나 그 카테고리에 속한 기존 menuItem 존재해도 보존.
    - 사용 중 카테고리 hard delete 시도 → 차단 + 다이얼로그.
    - 사용 0개 카테고리 hard delete → 정상 삭제.
  - **회귀 테스트**:
    - sub-phase 1 (brand_master) 의 마스터 메뉴 등록/수정/복제 — 카테고리 칩 정상.
    - sub-phase 4 (owner_personal_menu) 의 owner 메뉴 폼 — 정상.
    - sub-phase 3 (brand_store_customization) 의 brand store-only 메뉴 폼 — 정상.
    - sub-phase 8 (sub-category) 와 충돌 없음 — sub-category 의 mainCategory 참조 String 으로 호환.
  - **(4d Lite 회귀)**:
    - 비활성화 confirm dialog 가 매장 수 N / 메뉴 수 M 을 정확히 표시하는가 (count aggregate 정확성).
    - 메뉴 폼 3종 (Master / BrandStoreOnly / OwnerStoreMenu) 수정 모드에서 inactive 카테고리에 속한 메뉴 진입 시 경고 라벨 노출.
    - 메뉴 리스트 (옵션 적용 시) 시각 marker 정상.
    - 비활성 후 admin 이 다시 active=true 로 토글했을 때 경고 라벨/marker 즉시 사라짐.
- **반드시 확인할 예외 케이스**:
  - menuItem `mainCategory` 가 mainCategories 컬렉션에 없는 값일 때 customer 화면 동작 (필터 제외 — UI 깨지지 않음).
  - inactive 카테고리에 속한 메뉴 수정 모드 — 폼이 그 카테고리를 보여주는가 + 경고 라벨 노출.
  - 시드 race — 동시 첫 진입 시 중복 doc 미발생.
  - 컬렉션 empty 상태 (시드 전) — admin / customer / brand / owner 각 화면 동작.
  - 권한: admin 외 role 이 mainCategories CRUD API 호출 시 차단 (Firestore 보안 규칙은 별도 task — 본 sub-phase 는 클라이언트 가드만).
  - **(확정 4c) audit 결과를 `test_report.md` 에 명시** — `mainCategory` 필드 분포 (값별 doc 수). 'coffee'/'nonCoffee'/'dessert' 외 값 발견 시 architect 에게 즉시 보고.

---

## 마이그레이션 단계 (단계별 / 단일 PR)

> 단일 PR 로 한 번에 머지. 부분 PR 시 빌드 깨짐 (enum 제거 → 호출처 다수 깨짐).

```text
[Step 1] 컬렉션 + 시드 인프라
  - lib/domain/entities/main_category_entity.dart 신규
  - lib/data/models/main_category_model.dart 신규
  - lib/data/datasources/remote/main_category_remote_data_source.dart 신규
  - lib/domain/repositories/main_category_repository.dart 신규
  - lib/data/repositories/main_category_repository_impl.dart 신규
  - lib/core/errors/main_category_in_use_exception.dart 신규
  - FirestorePaths.mainCategories 추가
  - UseCase 5개 신규 (Watch / Upsert / Delete / ToggleActive / CountUsage)
  - (4d Lite) Repository.countDetailedUsage(id) → (menuCount, distinctStoreCount) 추가
  - DI providers 신규
  - (확정 4a) firestore.indexes.json 에 collectionGroup('menuItems') / mainCategory asc 인덱스 추가

[Step 2] enum 제거 + 타입 마이그레이션 + 메뉴 폼 경고 라벨 (4d Lite)
  - MenuItemEntity.mainCategoryCode: MainCategoryCode → String
  - SubCategoryEntity.mainCategoryCode: MainCategoryCode → String
  - freezed 재생성
  - MenuItemModel / SubCategoryModel 매핑에서 enum 호출 제거
  - MenuCategoryRepository / WatchSubCategoriesUseCase 시그니처 변경
  - subCategoriesProvider family parameter String 으로
  - selectedMainCategoryProvider Notifier<String?> 로
  - storeAvailableMainCategoriesProvider Set<String> 으로
  - MainCategoryTabs props 변경
  - 메뉴 폼 3종 _categories 하드코딩 제거 → mainCategoriesActiveProvider 사용
  - **(4d Lite) 메뉴 폼 3종 (Master/BrandStoreOnly/OwnerStoreMenu) 에 비활성 카테고리 경고 라벨 추가**
  - **(4d Lite, 옵션) 점주/브랜드 메뉴 리스트 카드 시각 marker** — designer 적용 결정 시
  - lib/domain/entities/main_category_code.dart 삭제

[Step 3] admin UI + 비활성화 confirm dialog (4d Lite)
  - AdminMainCategoryListPage 신규
  - AdminMainCategoryFormPage 신규
  - MainCategoryDeleteDialog 신규
  - **(4d Lite) MainCategoryDeactivateConfirmDialog 신규 — 영향 데이터 N/M 표시**
  - AdminMorePage 에 tile 추가

[Step 4] 시드 자동화
  - admin 첫 진입 시 seedDefaultsIfEmpty 호출 (확정 결정 2 — A 채택)

[Step 5] 검증
  - flutter analyze 0 error
  - flutter test 전체 통과
  - 수동 회귀 — sub-phase 1/3/4/8 화면 정상
  - (4d Lite 회귀) 메뉴 폼 3종 + 메뉴 리스트 + 비활성화 dialog 동작 확인
  - audit — 기존 menuItem.mainCategory 값 분포 (확정 4c)
  - (확정 4a) Firestore 인덱스 배포 확인 + 삭제 차단 쿼리 실측
```

---

## 완료 기준

- [x] 사용자가 결정 1~4 확정 + 사용자 확인 항목 4a~4c + 4d Lite 답변 (2026-05-03)
- [ ] `design.md` 작성 (designer) — A/B/C/D/E 5개 영역 모두 반영
- [ ] `implementation.md` 작성 (developer) + `flutter analyze` 0 error + `flutter test` 통과
- [ ] `mainCategories` 컬렉션 시드 후 customer / brand / owner / admin 4 영역 모두 정상 동작
- [ ] (4d Lite) admin 비활성화 confirm dialog + 메뉴 폼 3종 경고 라벨 + (옵션) 메뉴 리스트 marker 동작 확인
- [ ] menuItem / subCategory audit 통과 (또는 발견된 이상 doc 정리 / 사유 문서화)
- [ ] enum `MainCategoryCode` 제거 (또는 deprecated 합의)
- [ ] (확정 4a) Firestore 인덱스 배포 확인 + 삭제 차단 동작
- [ ] sub-phase 1 / 3 / 4 / 8 회귀 PASS
- [ ] `test_report.md` FAIL 없음 또는 후속 작업으로 분리

---

## Follow-up / 다음 작업 후보

본 sub-phase 9 의 비범위로 분리된 항목 + 향후 phase 후보. **본 phase 완료 후 별도 phase 로 진행**.

### F1. 4d Heavy — 외부 알림 인프라 (FCM 푸시 / 이메일)

**배경**: sub-phase 9 의 4d Lite 는 admin/점주/브랜드가 화면에 들어왔을 때 인지하는 **passive 알림** 까지 다룸. inactive 카테고리에 묶여 운영 중인 매장 메뉴를 운영자가 화면 진입 없이도 인지하도록 **active 알림** 이 필요해질 수 있음.

**범위 (예시)**:
- admin 이 카테고리를 비활성화하면 그 카테고리에 묶인 메뉴를 보유한 매장 운영자에게 FCM push 또는 이메일 알림
- "X 카테고리가 비활성화되었습니다. 메뉴 N개의 카테고리를 변경해주세요" 메시지 + 매장 메뉴 리스트로 deeplink
- 알림 인프라:
  - FCM 토큰 등록 / 갱신 / 만료 처리
  - 알림 sending pipeline (Firebase Functions 또는 백엔드 큐)
  - 타임 트리거 (즉시 / 24시간 후 리마인더 등)
  - 이메일 발송 인프라 (선택)
- 사용자별 알림 수신 동의 / 채널 설정 (sub-phase 별건)

**진입 조건**:
- sub-phase 9 종료 후 inactive 카테고리 사용 빈도 / 운영자 문의 빈도 데이터 확보 후 ROI 판단.
- Firebase Functions / 알림 인프라 phase (Phase 1 MVP 외부) 결정 후 후속 sub-phase 화.

### F2. 메인 카테고리 시각 토큰 (이미지 / 배너 / 색상)

본 sub-phase 9 비범위. label / displayOrder / active 까지만. 향후 카테고리별 시각 토큰 도입 phase.

### F3. label 다국어화 (i18n)

`labels: {ko, en}` 구조 확장. i18n 도입 phase 와 묶여 진행.

### F4. `MenuCategories.all` (12개 string) 동적화

매장의 `menuCategories(List<String>)` / customer 홈 카테고리 필터 — 본 sub-phase 와 별개 도메인 (매장 분류 태그). 별도 phase 후보.
