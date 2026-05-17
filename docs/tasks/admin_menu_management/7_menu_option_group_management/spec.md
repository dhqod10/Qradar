# sub-phase 7 — menu_option_group_management 기능 명세

> **상태**: APPROVED — 결정 1~9 모두 사용자 확정 완료. designer/developer/tester 분배 가능.
>
> **umbrella 단일 진실원**: `admin_menu_management/spec.md` 의 데이터 모델 / 권한 매트릭스를 따른다.
>
> **선행 phase**:
> - sub-phase 1 (brand_master) — `MenuItemEntity.optionGroupRefs` 필드, `OptionGroupSelector` 위젯, S2 검증 (마스터 메뉴는 master scope 만 허용 → 본 phase 에서 master ∪ brand 로 갱신).
> - sub-phase 1 patch (brand_master_option_selector_patch) — 마스터/개인 매장 메뉴 폼에 옵션 selector 도입.
> - sub-phase 4 (owner_personal_menu) — 개인 매장 메뉴 폼 + master/store 양쪽 옵션 그룹 머지 selector.
> - sub-phase 5 (owner_options_soldout) — 점주 옵션 비활성 토글 + `getOptionGroupsForMenuItem` filter.
> - sub-phase 8 (menu_sub_category_management) — 2-tier (brand/store) CRUD + 권한 매트릭스 + 약한 검증 (`옵션 2`) 패턴 — **본 phase 는 이 패턴을 옵션 그룹에 그대로 이식**.
> - sub-phase 9 (menu_main_category_admin) — 동적 카테고리 컬렉션 + 사용 중 검사 + active 토글 + delete 차단 패턴.
>
> 본 sub-phase 는 **옵션 그룹 (예: "샷 추가" 그룹 + 그 안의 "1샷/2샷" 항목들)** 을 brand 본사 / 개인 매장 점주가 권한에 맞춰 직접 추가/편집/삭제할 수 있게 한다. **admin 은 본 sub-phase 에서 옵션 그룹 CRUD UI 를 다루지 않는다** (sub-phase 8/9 와 동일).

---

## 개요

- **목적**:
  1. 옵션 그룹 (이름 / 선택 타입 / required / 항목 list / displayOrder / active) 을 brand 본사 / 개인 매장 점주가 권한에 맞춰 직접 CRUD 할 수 있게 한다.
  2. 메뉴 폼 3종(`MasterMenuFormPage` / `BrandStoreOnlyMenuFormPage` / `OwnerStoreMenuFormPage`) 의 옵션 그룹 selector 노출 정책을 신규 scope 모델 (master ∪ brand 또는 master ∪ store) 에 맞게 갱신한다.
  3. customer 측 옵션 시트 / 메뉴 상세 옵션 선택의 read 동작을 새 scope 모델 기준으로 회귀 보장한다 (master 항상 포함 + 매장 컨텍스트 brand/store 머지).
  4. **admin 은 본 sub-phase 에서 옵션 그룹 CRUD UI 를 다루지 않는다** (sub-phase 8/9 정책 통일).
- **작업 유형**: 신규 기능 (CRUD 도메인/데이터 + brand/owner UI 추가) + 기존 메뉴 폼 selector 갱신 + 기존 customer 측 read 정책 호환 보장.
- **영향 범위**:
  - 화면(brand 본사): **신규 진입점** — `BrandOptionGroupListPage` + `BrandOptionGroupFormPage`. 진입은 `BrandMorePage` tile (sub-phase 8 패턴).
  - 화면(owner 개인 매장): **신규 진입점** — `OwnerStoreOptionGroupListPage` + `OwnerStoreOptionGroupFormPage`. 진입은 `MyStorePage` "메뉴 관리" 영역.
  - 화면(brand 가맹점 점주): read-only — 본사 옵션 그룹을 customer/메뉴 상세에서 보기만 함. CRUD 진입 tile 미노출.
  - 화면(admin): **변경 없음**. `AdminMorePage` 에 옵션 그룹 진입 tile 신규 추가하지 않음.
  - 화면(메뉴 폼 3종): **selector 노출 정책 갱신** — 결정 1 (B-3 / 2-tier + legacy master read-only) 에 따라 selector 가 노출하는 출처 set 변경. `OptionGroupSelector` 위젯의 master/store 섹션 헤더 카피 갱신.
  - 화면(`BrandStoreOnlyMenuFormPage`): **현재 옵션 selector 가 통합되지 않은 상태** (`optionGroupRefs: (editItem ?? sourceForClone)?.optionGroupRefs ?? []` — 보존만). 본 phase 에서 selector 통합 + 신규 scope 정책 적용.
  - 화면(customer): `MenuItemDetailPage` / `MenuOptionDisableSheet` — 옵션 그룹 read 정책 결정 1 (B-3) 에 따라 갱신. master 항상 포함 + 매장 컨텍스트 brand/store 머지. UI 자체 변경은 최소.
  - Domain:
    - `OptionScope` enum 확장 — `master` (legacy, read-only fallback), `brand` (신규 CRUD), `store` (기존 CRUD) 세 값 유지. `master` 는 deprecated marker 만, 신규 doc 생성 안 함.
    - `OptionGroupEntity` — `brandId: String?` 필드 추가 (scope == brand 일 때 채움). `storeId` 유지.
    - `OptionRepository` 확장: 기존 read 메서드 + scope 별 stream + CRUD + `findDuplicateName` + `countUsage`.
    - 책임 분리: `OptionRepository` 는 read 전용 + CRUD 는 `OptionGroupRepository` 신규로 분리 (sub-phase 8 패턴 동일).
  - Data:
    - `OptionGroupModel` 매핑 확장 (scope/brandId 추가, fromFirestore 의 path resolver 갱신).
    - `OptionRemoteDataSource` 확장 — scope 별 컬렉션 read/write/delete/findDuplicateName/countUsage.
    - `OptionRepositoryImpl` / `OptionGroupRepositoryImpl` (신규).
  - Presentation: `presentation/brand/option_groups/`, `presentation/owner/option_groups/` 신규 트리. `presentation/admin/option_groups/` 는 **신규 생성하지 않음**.
  - 라우팅: 변경 없음 (Navigator.push 내부 진입).
  - 권한 / 환경 설정: 본 sub-phase 는 **클라이언트 가드만**. Firestore 보안 규칙은 별도 task 로 분리 (sub-phase 8 F1 와 동일 정책).
  - 테스트:
    - 회귀: 기존 메뉴 폼 3종, customer 메뉴 상세, sub-phase 5 옵션 비활성 토글, 옵션 disable 시트, S2 검증.
    - 신규: 권한 매트릭스 (brand 본사 / owner 개인 매장 / brand 가맹점 점주) 별 CRUD 동작, 검증 정책 (옵션 2), 항목 list 동적 추가/삭제 동작.
- **비범위** (이번 작업에서 명시적으로 제외):
  - **admin 옵션 그룹 CRUD UI** — 결정 5 확정 (admin 미관리). admin 측 진입점/페이지 신규 생성 안 함.
  - **메뉴 카테고리 (main / sub) CRUD** — sub-phase 8/9 완료 영역.
  - **옵션 항목 reordering (drag-drop)** — Follow-up F3.
  - **옵션 항목 priceDelta 일괄 변경 / 시즌 가격** — Follow-up F8.
  - **외부 알림 (옵션 그룹 변경 시 가맹점 알림)** — Follow-up F5.
  - **옵션 항목 단위 active toggle** (그룹 단위만 본 phase 범위) — Follow-up F4.
  - **다국어 label** (i18n) — Follow-up F9.
  - **시드 마이그레이션 자동화 (existing `optionGroups/og_master_*` → 신 scope 컬렉션 이관)** — 결정 1 (B-3) 에 따라 보존만. 폐기 작업은 Follow-up F6.
  - **Firestore 보안 규칙 작성** — 별 task (Follow-up F1).
  - **오타/유사명 자동 감지** (예: "샷 추가" vs "샷추가") — Follow-up F7.
  - **메인 카테고리 종속 정책 (옵션 그룹 ↔ 적용 가능 메인 카테고리)** — 결정 1 추가 확정 (A안 / 현재 구조 유지). `applicableMainCategories` 메타 필드 도입 안 함. 메뉴별 점주 수동 체크. **자동 필터 / suggested filter 는 Follow-up F10**.

---

## 의존 phase / 진입 조건

- **의존 phase**:
  - sub-phase 1 (`MenuItemEntity.optionGroupRefs`, `OptionGroupRef(scope, id)`, S2 검증) — S2 정책 갱신 (결정 8: master ∪ brand / master ∪ brand ∪ store).
  - sub-phase 4 (`OptionGroupSelector` 의 master/store 양쪽 머지 패턴) — 결정 6 에 따라 master 호환 머지 흐름 유지.
  - sub-phase 5 (`getOptionGroupsForMenuItem` disabled filter — read flow 영향 검사).
  - sub-phase 8 — 2-tier 권한/검증/active 토글 패턴.
  - sub-phase 9 — 사용 중 검사 패턴.
- **진입 조건**:
  - sub-phase 8 / 9 APPROVED + 안정.
  - Firestore 인덱스 추가 가능 (`collectionGroup('menuItems') / optionGroupRefs.id` — Firestore 는 array 필드의 nested index 한계 있음 → 결정 4 의 PoC 영역).

---

## 핵심 결정 (모두 사용자 확정)

> sub-phase 8 / 9 와의 일관성을 우선으로, 옵션 그룹 도메인 특수성 (= 글로벌 시드 데이터 존재 / `MenuItemEntity` 의 `optionGroupRefs.scope` 가 이미 사용 중 / customer fetch 호환) 을 별도 변수로 정리.

---

### 결정 1. scope 모델 — **확정: B-3 (2-tier brand/store + legacy master read-only)**

| 안 | 설명 | 채택 |
|---|---|---|
| A (3-tier — legacy global read-only + brand + store) | 기존 `optionGroups/{id}` 글로벌 시드 read-only 보존 + 신규 brand/store CRUD 추가 | — |
| B-1 (2-tier — 시드 즉시 마이그레이션) | 기존 시드를 brand 시드로 복제 + menuItem.ref scope 일괄 변환 | — |
| B-2 (2-tier — 시드 폐기) | 기존 시드 폐기 + 신규 brand 가 직접 추가 | — |
| **B-3 (2-tier + legacy compat)** | legacy `optionGroups/{id}` read-only 호환 유지 + 신규 brand/store CRUD. 기존 시드 (`og_master_shot/syrup/temperature`) 그대로 보존. | **✅ 확정** |
| C (3-tier — legacy + brand + store, master 우선 노출) | A 와 동일 + 메뉴 폼 selector master + 자기 scope 머지 | — |

**확정 세부**:
- 기존 시드 (`optionGroups/og_master_shot`, `og_master_syrup`, `og_master_temperature`) **그대로 보존**.
- admin 측 신규 CRUD UI 없음. **글로벌 옵션 그룹의 신규 추가는 dev/배포 시드로만 채운다** (운영 인터페이스 없음).
- 메뉴의 기존 master scope `optionGroupRefs` 정상 동작 보장 (read 호환).
- 신규 등록은 `brand` (브랜드 본사) 또는 `store` (개인 매장 점주) 로만.
- `master` 컬렉션은 read-only deprecated marker — 신규 doc 생성 불가, 수정도 불가 (UI 없음).

**B-3 채택 사유**:
- 운영 인터페이스가 없는 글로벌 시드를 즉시 마이그레이션하는 부담 회피.
- 기존 메뉴의 `optionGroupRefs[scope=master]` 데이터가 그대로 살아있어 회귀 비용 0.
- admin 미관리 결정과 정합 (글로벌은 코드 시드, 운영은 brand/store).
- 향후 운영 안정화 후 Follow-up F6 에서 폐기 가능.

---

### 결정 1 추가. 메인 카테고리 종속 정책 — **확정: A안 (현재 구조 유지)**

| 안 | 설명 | 채택 |
|---|---|---|
| **A** (현재 구조 유지) | 옵션 그룹에 메인 카테고리 종속 메타 없음. 점주가 메뉴 등록/수정 시 메뉴별로 적절한 옵션 그룹을 수동 체크. | **✅ 확정** |
| B (`applicableMainCategories` 메타 필드 도입) | 옵션 그룹에 "이 옵션이 적용 가능한 main 카테고리" list 메타 추가. 메뉴 폼 selector 가 자동 필터링. | — (Follow-up F10) |

**확정 세부**:
- `OptionGroupEntity` 에 `applicableMainCategories` 필드 **추가하지 않는다**.
- 메뉴 등록/수정 시 점주가 sub-phase 1 patch 의 `OptionGroupSelector` 흐름 그대로 — 모든 옵션 그룹이 노출되며 점주가 메뉴별로 수동 체크.
- **에이드 메뉴에 "샷 추가" 옵션을 안 체크하는 책임은 점주에게 있다** (UI 자동 필터링 안 함).
- Follow-up F10 에서 자동 필터 / suggested filter 로 발전 가능 (운영 데이터 누적 후 결정).

**A안 채택 사유**:
- 옵션 그룹이 적용 가능한 메인 카테고리 set 을 데이터로 정형화하기에는 운영 패턴이 미성숙 (브랜드별/매장별 다양).
- 점주의 자율 판단을 우선. 잘못 체크하면 메뉴별로 옵션이 어색해질 뿐 데이터 정합성 문제는 없음.
- 메타 필드를 도입하면 UI/검증/마이그레이션 비용 증가. 지금 단계는 정책 단순성 우선.

---

### 결정 2. `OptionScope` enum 확장 — **확정: 3개 값 유지 (master deprecated + brand + store)**

```dart
enum OptionScope {
  /// @deprecated — legacy global. 본 phase 이후 새 doc 생성 안 함.
  /// 기존 menuItem.optionGroupRefs 호환 read 만.
  master,
  brand,  // 신규 CRUD
  store;  // 기존 CRUD
  // ... fromString / asString 갱신
}
```

- 결정 1 (B-3) 에 따라: `master` 는 read-only fallback marker 로만 유지. 새 doc 생성 안 함.
- `brand` 신규 추가 — `brands/{brandId}/optionGroups/{id}`.
- `store` 기존 그대로 — `stores/{storeId}/optionGroups/{id}`.
- 신규 등록 UseCase 에서는 `master` scope 입력 차단 (UseCase 레벨 가드 + 폼에서 노출 안 함).

---

### 결정 3. CRUD UI 진입 위치 — **확정 (sub-phase 8 패턴 재사용)**

| 역할 | 진입점 | 사유 |
|---|---|---|
| brand 본사 | `BrandMorePage` 의 "옵션 그룹 관리" tile | sub-phase 8 admin tile 패턴과 일관. 운영 빈도 낮음 → 더보기 탭. |
| owner 개인 매장 | `MyStorePage` (개인 매장 상세) 의 "메뉴 관리" 영역 안에 "옵션 그룹 관리" 진입 | 매장 컨텍스트 자동 박힘. 매장 미등록 점주는 진입 자체 불가. |
| brand 가맹점 점주 | **진입 tile 미노출** | read-only — 본사 옵션 그룹만 사용. CRUD UI 자체 미노출. |
| admin | **신규 tile 추가 안 함** | 결정 5 — 글로벌 옵션 그룹은 코드 시드 / admin 미관리. |

---

### 결정 4. 삭제 정책 — **확정: hard delete 차단 + active 토글 (sub-phase 8/9 패턴)**

- `OptionGroupEntity` 에 `active: bool` 필드 신규 추가.
- 사용 중 검사 — **A안 (객체 매칭) 시도 + dev 검증 후 fallback (B안: 평면 ID list) 결정**:
  - **A안 (1순위)**: `collectionGroup('menuItems').where('optionGroupRefs', arrayContains: {scope, id}).limit(1)` — Firestore 의 `arrayContains` 가 nested map 객체를 정확히 매칭하는지 PoC.
  - **B안 fallback (호환 안 될 때만)**: 메뉴 doc 에 `optionGroupRefIds: List<String>` (평면 ID) 필드 추가 + `arrayContains: id` 로 검색.
- developer 단계의 PoC: A안 직렬화/매칭 호환 검증. 호환 시 A안 채택 / 안 되면 B안 적용 (메뉴 repository 의 set merge 시 평면 list 자동 동기화).
- 사용 중 1개 이상 → hard delete 차단 + 토스트 "사용 중 N개. 비활성으로만 가능".
- active=false 시:
  - 신규 메뉴 폼 selector 칩에서 제외.
  - 기존 메뉴 수정 폼: inactive 그룹은 disabled marker + 경고 라벨.
  - customer 메뉴 상세: active=true 만 노출. inactive 는 자연 제외.
- 인덱스: `firestore.indexes.json` 에 `collectionGroup('menuItems') / optionGroupRefs` array index 검토. B안 fallback 시 `optionGroupRefIds` 자동 인덱스 호환.

---

### 결정 5. admin 미관리 정책 — **확정: admin 옵션 그룹 CRUD 미도입 (sub-phase 8/9 와 통일)**

- `AdminMorePage` 에 신규 진입 tile 추가 안 함.
- 글로벌 옵션 그룹 (`optionGroups/{id}`) 은 read-only 호환만 (B-3). **신규 doc 추가는 dev/배포 시드 코드로만**.
- admin 모니터링 (분포 audit / 사용 통계) 은 Follow-up F11.

---

### 결정 6. 메뉴 폼 selector 노출 정책 — **확정 (B-3 기준, master 호환 포함)**

| 폼 | 노출되는 옵션 그룹 출처 | 비고 |
|---|---|---|
| `MasterMenuFormPage` (brand 본사 마스터 메뉴) | `master` ∪ `brand` (해당 brandId) | 신규 등록 시 master/brand 모두 선택 가능 (master 는 legacy 시드 호환). |
| `BrandStoreOnlyMenuFormPage` (brand 본사 → 가맹점 한정 메뉴) | `master` ∪ `brand` (해당 brandId) | **selector 신규 통합** + master/brand 머지. |
| `OwnerStoreMenuFormPage` (개인 매장 점주) | `master` ∪ `store` (해당 storeId) | 개인 매장은 brand 없음. master/store 머지. |
| customer `MenuItemDetailPage` / `MenuOptionDisableSheet` | 매장 컨텍스트 자동 머지 — 가맹점 매장이면 `master` ∪ `brand`(매장 doc 의 brandId), 개인 매장이면 `master` ∪ `store`(storeId) | master 항상 포함 — legacy 시드 호환. |

**핵심 변경 (sub-phase 1 대비)**:
- 기존: 마스터 메뉴는 `master` only / 개인 매장은 `master` ∪ `store`.
- 갱신: 마스터 메뉴는 `master` ∪ `brand` / BrandStoreOnly 도 `master` ∪ `brand` (신규) / 개인 매장은 `master` ∪ `store` (변경 없음).
- selector 섹션 헤더 카피: 기존 "마스터 옵션" / "매장 옵션" → 본 phase 에서는 "기본 옵션" (master) / "브랜드 옵션" (brand) / "매장 옵션" (store) — designer 카피 결정.

---

### 결정 7. 옵션 그룹 도메인 필드 (form 입력 항목) — **확정**

```dart
@freezed
abstract class OptionGroupEntity with _$OptionGroupEntity {
  const factory OptionGroupEntity({
    required String id,
    required OptionScope scope,    // brand | store | (deprecated) master
    String? brandId,                // scope == brand 일 때 채움 (신규)
    String? storeId,                // scope == store 일 때 채움 (기존)
    required String name,           // 1~30 자
    required OptionSelectionType selectionType, // single | multi
    @Default(false) bool required,
    @Default(<OptionItemEntity>[]) List<OptionItemEntity> items,
    @Default(0) int displayOrder,
    @Default(true) bool active,    // 신규 — sub-phase 9 패턴
    DateTime? createdAt,            // 신규
    DateTime? updatedAt,            // 신규
  }) = _OptionGroupEntity;
}
```

폼 입력 항목 (브랜드 / 개인 매장 동일):
- **이름**: 1~30 자, 검증 정책 — 결정 9.
- **선택 타입**: single / multi — 라디오 vs 체크박스.
- **required**: 스위치.
- **displayOrder**: 정수, 0 이상.
- **active**: 스위치.
- **items list** (동적 추가/삭제):
  - 각 item: id (**자동 생성** — uuid 짧은 ID, 신규 등록 시 자동 / 수정 시 보존), label (1~20 자), priceDelta (정수, **음수 허용**).
  - 추가/삭제 버튼.
  - 항목 reordering (drag-drop) — **본 phase 비범위 (Follow-up F3)**.

**확정 세부**:
- **항목 id 자동 생성** (uuid 짧은 ID, 예: `nanoid` 8~10자) — 신규 추가 / 수정 시 보존.
- **priceDelta 음수 허용** — 할인/쿠폰 케이스 (예: "사이즈 다운 -500원", "쿠폰 적용 -1000원"). 0 도 가능.
- **그룹 name max length 30**.
- **item label max length 20**.

---

### 결정 8. S2 검증 정책 갱신 — **확정 (결정 6 와 통합)**

- **이전 (sub-phase 1)**: 마스터 메뉴는 `optionGroupRefs[scope=master]` 만 허용.
- **갱신 (본 phase)**:
  - 마스터 메뉴 (`MasterMenuItemRepositoryImpl`): `master` ∪ `brand` 허용. `store` ref 차단.
  - BrandStoreOnly 메뉴 (`BrandStoreOnlyMenuRepositoryImpl`): `master` ∪ `brand` 허용. `store` ref 차단.
  - 개인 매장 메뉴 (`OwnerStoreMenuRepositoryImpl`): `master` ∪ `brand` ∪ `store` 허용 (실제 사용 set 은 매장 컨텍스트 따라 — 개인 매장이면 brand 없으니 master ∪ store / 가맹점 매장이면 master ∪ brand ∪ store 가 가능하나 본 phase 는 개인 매장만 다룸).
- 검증 위치: 각 메뉴 repository 의 `_validateOptionGroupScope`.
- **legacy `master` ref 보존**: 신규 ref 추가 시에도 `master` 허용 (B-3 호환). 기존 메뉴의 `master` ref 는 그대로 사용 가능.

---

### 결정 9. 검증 정책 — **확정 (옵션 2 / 약한 검증 — sub-phase 8 와 동일)**

- **같은 scope 내 동일 이름 차단**:
  - 한 brand 안에서 동일 이름 옵션 그룹 못 만듦 (`brands/{brandId}/optionGroups/` 내).
  - 한 store 안에서도 동일 (`stores/{storeId}/optionGroups/` 내).
  - normalize: `name.trim().toLowerCase()`.
  - active 무관 비교 (active=false 옵션 그룹도 동일 이름 재사용 차단).
- **다른 scope 간** (예: brand A vs brand B, brand A vs store S, brand vs master) → **허용**.
- 검증 위치: Repository / UseCase 레벨.
  - `UpsertOptionGroupUseCase` 진입 시 `OptionGroupRepository.findDuplicateName({scope, brandId?, storeId?, name, excludeId?})` 호출.
  - 일치 시 `DuplicateOptionGroupNameException` throw.
- 폼 단 추가 검증:
  - 입력 시점 디바운스 lookup → inline 에러 라벨 ("이미 같은 이름의 옵션 그룹이 있어요").
  - submit 시 race 방지 — UseCase 가 최종 차단.
- **항목 단위 검증** — **한 그룹 내 items label 중복 차단** (단순 normalize 정확 일치). client-side validation only.
- 오타/유사명 자동 감지 → **Follow-up F7**.

---

### 결정 보너스. Repository 책임 분할 — **확정 (sub-phase 8 패턴 동일)**

- `OptionRepository` (기존, read 전용) → customer 측 사용. read 시 deprecated `master` 호환 read 도 그대로 유지 (B-3 호환).
- `OptionGroupRepository` (신규, CRUD) → brand 본사 / owner 사용.
- 두 repo 모두 같은 `OptionRemoteDataSource` 를 공유.

---

## 요구사항

### 기능 요구사항

#### brand 본사 (brand scope CRUD)
- [ ] `BrandOptionGroupListPage` — `brands/{brandId}/optionGroups/{id}` 목록.
  - 각 item: name / selectionType badge / required marker / items 개수 / displayOrder / active toggle / "사용 중 N개" 표시 / 편집 / 삭제.
- [ ] `BrandOptionGroupFormPage` — 등록/수정 (id, name, selectionType, required, items list, displayOrder, active).
  - id 자동 생성 (uuid 짧은 ID). 수정 시 보존.
  - name: 1~30자.
  - displayOrder: 정수, 0 이상.
  - **items list 동적 추가/삭제** — 각 item 의 id (자동) / label (1~20 자) / priceDelta (정수, 음수 허용) 입력. 한 그룹 내 label 중복 차단.
  - **중복 이름 lookup (디바운스)** — 같은 brand 내 normalized name 일치하는 다른 그룹 있으면 inline 에러.
- [ ] 삭제: `countUsage` → 사용 중이면 차단 + 다이얼로그.
- [ ] 비활성 토글: list 직접 토글.
- [ ] brand 가맹점 점주는 진입 tile 자체가 미노출 (가드).

#### owner 개인 매장 (store scope CRUD)
- [ ] `OwnerStoreOptionGroupListPage` — `stores/{storeId}/optionGroups/{id}` 목록.
- [ ] `OwnerStoreOptionGroupFormPage` — 위와 동일 폼 + 같은 store 안 중복 이름 검증.
- [ ] 진입 가드: 매장이 개인 매장(brandId == null) 이고 점주 본인 매장일 때만.
- [ ] 가맹점(brandId != null) 점주는 진입 tile 자체가 미노출.

#### read (메뉴 폼 3종 + customer)
- [ ] `OptionRepository` 기존 read API 호환 유지 + 결정 1 = B-3 기준 `master` legacy fallback read 보존.
- [ ] 메뉴 폼 3종 selector 갱신 (master 항상 포함 + scope 머지):
  - `MasterMenuFormPage`: `master` ∪ `brand` 머지 노출.
  - `BrandStoreOnlyMenuFormPage`: **selector 신규 통합** + `master` ∪ `brand` 머지.
  - `OwnerStoreMenuFormPage`: `master` ∪ `store` 머지 노출.
  - 빈 상태: "옵션 그룹이 없어요 — 옵션 그룹 관리 화면에서 추가해보세요" + (가능 시) 진입 CTA.
  - inactive 옵션 그룹 (수정 모드): disabled marker + 경고 라벨.
- [ ] customer `MenuItemDetailPage` / `MenuOptionDisableSheet`:
  - 옵션 그룹 read 정책 결정 1 (B-3) 따라 갱신. `getOptionGroupsForMenuItem` 의 ref scope 별 분기 갱신.
  - 매장 컨텍스트(brandId / storeId) 따라 master ∪ (brand 또는 store) 컬렉션 read.
  - `master` legacy ref 가 있으면 legacy `optionGroups/{id}` 에서 read (호환).

#### 검증 정책 (신규)
- [ ] `OptionGroupRepository.findDuplicateName({scope, brandId?, storeId?, name, excludeId?})` 구현.
- [ ] `UpsertOptionGroupUseCase` 가 upsert 직전 lookup → 존재 시 `DuplicateOptionGroupNameException`.
- [ ] 폼: 디바운스(약 300ms) lookup 결과 inline 에러 + submit 시 UseCase 최종 차단.
- [ ] 항목 label 중복 (한 그룹 내) — client-side validation, submit 시 차단.

#### S2 / S2-store / S2-storeOnly 검증
- [ ] 마스터 메뉴 repository upsert: `optionGroupRefs[scope ∈ {master, brand}]` 만 허용. `store` 차단.
- [ ] BrandStoreOnly 메뉴 repository upsert: 동일 (master ∪ brand).
- [ ] 개인 매장 메뉴 repository upsert: `optionGroupRefs[scope ∈ {master, store}]` 만 허용 (개인 매장은 brand 없음).

#### 마이그레이션 / 호환
- [ ] 기존 `optionGroups/{id}` 글로벌 시드 (og_master_shot 등) 처리 — **B-3 확정**: 그대로 보존, read-only.
- [ ] 기존 `MenuItemEntity.optionGroupRefs[scope=master]` 데이터 호환 — read 정상. 신규 등록은 brand/store 로만.
- [ ] 인덱스 검증 — `arrayContains: {scope, id}` query 의 Firestore 인덱스 / 직렬화 호환 (결정 4 PoC).

### UI 요구사항
- [ ] `BrandMorePage` 에 "옵션 그룹 관리" tile 추가.
- [ ] `MyStorePage` "메뉴 관리" 영역에 "옵션 그룹 관리" 진입 추가.
- [ ] `BrandOptionGroupListPage` / `OwnerStoreOptionGroupListPage` 디자인 (designer 산출물).
- [ ] 폼 페이지 2종 디자인 — items list 동적 입력 영역 (가장 신규/복잡한 영역).
- [ ] 메뉴 폼 3종 selector 빈 상태 / inactive 경고 라벨 / scope 별 섹션 헤더 카피.
- [ ] customer `MenuItemDetailPage` 옵션 영역 변경 없음 (read 정책만 갱신).
- [ ] **admin 측 신규 UI 없음**.

### 상태 요구사항
- [ ] loading: stream 첫 emit 전 — shimmer / placeholder.
- [ ] error: stream error → retry.
- [ ] empty: 옵션 그룹 0개 — brand/owner 는 "+ 추가" 안내. 메뉴 폼은 "옵션 그룹 없음 — 메뉴는 옵션 없이 등록 가능" 안내.

---

## 데이터 모델

### Entity (Domain)

```dart
// lib/domain/entities/option_scope.dart (확장)
enum OptionScope {
  /// @deprecated — legacy global. 새 doc 생성 안 함. 기존 menuItem.optionGroupRefs 호환만.
  master,
  brand,  // 신규
  store;
  // ... fromString / asString 갱신
}
```

```dart
// lib/domain/entities/option_group_entity.dart (확장)
@freezed
abstract class OptionGroupEntity with _$OptionGroupEntity {
  const factory OptionGroupEntity({
    required String id,
    required OptionScope scope,
    String? brandId,    // 신규
    String? storeId,    // 기존
    required String name,
    required OptionSelectionType selectionType,
    @Default(false) bool required,
    @Default(<OptionItemEntity>[]) List<OptionItemEntity> items,
    @Default(0) int displayOrder,
    @Default(true) bool active,    // 신규
    DateTime? createdAt,            // 신규
    DateTime? updatedAt,            // 신규
  }) = _OptionGroupEntity;
}
```

`OptionItemEntity` — 변경 없음 (id / label / priceDelta). priceDelta 음수 허용은 model/repository 단 검증 정책으로만 — entity 시그니처는 그대로 (int).

`OptionGroupRef` — 변경 없음 (scope / id). scope 가 enum 확장 따라 자동 호환.

### Model (Data)

| 컬렉션 | scope | doc 필드 (공통) | 추가 필드 |
|---|---|---|---|
| `optionGroups/{id}` (legacy) | master (deprecated) | name, selectionType, required, items, displayOrder | scope='master', active=true (default) |
| `brands/{brandId}/optionGroups/{id}` (신규) | brand | (동일) | scope='brand', brandId={parent}, active, createdAt, updatedAt |
| `stores/{storeId}/optionGroups/{id}` (기존) | store | (동일) | scope='store', storeId={parent}, active (신규 필드), createdAt/updatedAt (신규) |

- `OptionGroupModel` 매핑 확장 — `brandId` / `active` / `createdAt` / `updatedAt` + path resolver.
- `FirestorePaths` 확장 — `brandOptionGroupsPath(brandId)` 신규 헬퍼.

**메뉴 doc 보조 필드 (결정 4 fallback B안 채택 시)**:
- `menuItems/{id}.optionGroupRefIds: List<String>` — 각 ref 의 id 만 평면 list. set merge 시 `optionGroupRefs` 와 자동 동기화. arrayContains 자동 인덱스 호환.
- A안 (객체 매칭) PoC 통과 시 이 필드 미도입.

### Repository

#### OptionRepository (read, 확장)
```dart
abstract class OptionRepository {
  // 기존 — deprecated master 호환 read
  Future<OptionGroupEntity?> getMasterOptionGroup(String id);

  // 신규
  Future<OptionGroupEntity?> getBrandOptionGroup({
    required String brandId,
    required String id,
  });
  Future<OptionGroupEntity?> getStoreOptionGroup({
    required String storeId,
    required String id,
  });

  /// 메뉴 ref 기반 fetch — scope 별 분기 + master 호환.
  Future<List<OptionGroupEntity>> getOptionGroupsForMenuItem(
    MenuItemEntity menuItem, {
    String? brandId,    // 신규 — 가맹점 매장이면 storeId.brandId
    Set<String> disabledGroupIds = const {},
    Set<String> disabledItemIds = const {},
  });
}
```

#### OptionGroupRepository (CRUD, 신규)
```dart
abstract class OptionGroupRepository {
  Stream<List<OptionGroupEntity>> watchByScope({
    required OptionScope scope,
    String? brandId,
    String? storeId,
    bool activeOnly = false,
  });

  Future<OptionGroupEntity?> findById({
    required OptionScope scope,
    required String id,
    String? brandId,
    String? storeId,
  });

  Future<OptionGroupEntity?> findDuplicateName({
    required OptionScope scope,
    required String name,
    String? brandId,
    String? storeId,
    String? excludeId,
  });

  Future<void> upsert(OptionGroupEntity entity);

  Future<void> delete({
    required OptionScope scope,
    required String id,
    String? brandId,
    String? storeId,
  });

  /// 사용 중 검사. menuItem.optionGroupRefs 참조 수.
  Future<int> countUsage({
    required OptionScope scope,
    required String id,
  });
}
```

### MenuItemEntity / `optionGroupRefs`

- `MenuItemEntity.optionGroupRefs: List<OptionGroupRef>` — 변경 없음.
- `OptionGroupRef.scope` 가 `master` (legacy 호환) / `brand` / `store` 중 하나.
- 마이그레이션: 결정 1 = B-3 확정 → 신규 등록은 brand/store 로 작성. legacy `master` ref 는 read 호환만 유지 + 신규 메뉴 폼에서 master 옵션 그룹 선택 시에도 master ref 그대로 박힘 (master 시드는 read-only 보존).

---

## 레이어 설계

### Domain
- Entity:
  - `OptionScope` enum 확장 (`brand` 추가, `master` deprecated marker 주석).
  - `OptionGroupEntity` 필드 확장 (`brandId` / `active` / `createdAt` / `updatedAt`).
- UseCase:
  - `WatchOptionGroupsByScopeUseCase` (신규).
  - `FindOptionGroupByIdUseCase` (신규 — 폼 prefill).
  - `UpsertOptionGroupUseCase` (신규 — 내부에서 `findDuplicateName` 호출 후 차단 + scope=master 입력 차단).
  - `DeleteOptionGroupUseCase` (신규 — countUsage 후 0 이면 delete, 아니면 throw).
  - `ToggleOptionGroupActiveUseCase` (신규).
  - `CountOptionGroupUsageUseCase` (신규).
  - `FindDuplicateOptionGroupNameUseCase` (신규 — 폼 디바운스 lookup 용).
- Repository Interface:
  - `OptionRepository` (기존, signature 확장).
  - `OptionGroupRepository` (신규).
- Domain Error:
  - `OptionGroupInUseException` (신규).
  - `DuplicateOptionGroupNameException` (신규).
  - `DuplicateOptionItemLabelException` (신규 — 폼 단 client validation 용).

### Data
- Model: `OptionGroupModel` 필드 확장 + path resolver.
- DataSource: `OptionRemoteDataSource` 확장:
  - 기존 `getMaster`, `getStore`, `fetchAllMaster`, `fetchAllStore`, `upsertMaster`, `upsertStore` 유지.
  - 신규: `getBrand`, `streamByScope`, `findDuplicateName`, `upsertBrand`, `delete({scope, id, brandId, storeId})`, `countUsage`.
- Repository Implementation:
  - `OptionRepositoryImpl` (기존, signature 확장 — `getOptionGroupsForMenuItem` 의 brandId 파라미터 + scope 별 분기 + master 호환).
  - `OptionGroupRepositoryImpl` (신규).

### Presentation
- Provider:
  - `optionGroupRepositoryProvider` (신규).
  - brand 본사용: `brandOptionGroupsProvider({brandId, activeOnly})` family.
  - owner 개인 매장용: `ownerStoreOptionGroupsProvider({storeId, activeOnly})` family.
  - `optionGroupUsageProvider.family<int, ({OptionScope scope, String id})>` (list "사용 중 N개" 표시).
  - `findDuplicateOptionGroupNameProvider.family<…, DuplicateNameQuery>` (폼 디바운스 lookup).
  - 메뉴 폼 selector 용 머지 provider: `selectorOptionGroupsProvider` family — 결정 6 의 scope 머지를 wrapping.
- Page:
  - `BrandOptionGroupListPage` / `BrandOptionGroupFormPage` (신규).
  - `OwnerStoreOptionGroupListPage` / `OwnerStoreOptionGroupFormPage` (신규).
- Widget:
  - 공통: `OptionGroupListItem`, `OptionGroupDeleteDialog`, `OptionGroupActiveSwitch`, `OptionGroupFormFields` (`presentation/common/widgets/option_groups/`).
  - **신규 핵심: `OptionItemListEditor`** — 한 그룹 내 항목 동적 추가/삭제/편집 위젯. id (자동) / label / priceDelta (음수 허용) 입력. label 중복 inline 에러.
- 기존 widget 변경:
  - `OptionGroupSelector` (`brand/master_menu/widgets/`) — section header 카피 (master / brand / store 분리) + inactive 옵션 그룹 disabled marker + master scope 호환 처리.
  - `BrandMorePage` — "옵션 그룹 관리" tile 추가.
  - `MyStorePage` — "메뉴 관리" 영역에 "옵션 그룹 관리" 진입 추가.
  - `MasterMenuFormPage` / `BrandStoreOnlyMenuFormPage` / `OwnerStoreMenuFormPage` — selector 노출 정책 갱신 + (BrandStoreOnly) selector 신규 통합.
  - `MenuItemDetailPage` (customer) — `optionGroupsForMenuItemProvider` 갱신 (brandId 파라미터 추가, customer 측 storeProvider 의 brandId 활용).
  - `MenuOptionDisableSheet` — 동일 갱신.
  - `AdminMorePage` — **변경 없음**.

### 라우팅
- 변경 없음. Navigator.push 내부 진입.

---

## 데이터 흐름

### brand 본사 옵션 그룹 등록 (중복 이름 검증 포함)
```text
BrandOptionGroupFormPage (brandId 컨텍스트)
  → onChanged(name) → debounce 300ms → FindDuplicateOptionGroupNameUseCase(scope=brand, brandId, name, excludeId=editId?)
     ↓ duplicate 존재 시 inline 에러 라벨
  → onSubmit
     → UpsertOptionGroupUseCase(entity[scope=brand, brandId])
        → 내부에서 findDuplicateName 재호출 (race 방지)
        → exists → DuplicateOptionGroupNameException throw
        → 없음 → OptionGroupRepository.upsert
                → OptionRemoteDataSource.upsertBrand (brands/{brandId}/optionGroups/{id})
                → Firestore set merge
```

### owner 개인 매장 옵션 그룹 등록
```text
OwnerStoreOptionGroupFormPage (storeId 컨텍스트)
  → 동일 흐름. entity.scope = store, entity.storeId = storeId
  → DataSource → stores/{storeId}/optionGroups/{id}
```

### 메뉴 폼 selector fetch (예: MasterMenuFormPage)
```text
MasterMenuFormPage
  → ref.watch(selectorOptionGroupsProvider({brandId: profile.brandId, scopes: {master, brand}}))
  → OptionRepository.fetchAllMaster() + OptionGroupRepository.watchByScope(scope=brand, brandId, activeOnly=true)
  → 두 stream/list 머지 + active=true 만 + sort
  → selector build (master / brand 섹션 분리)
  → 수정 모드 + editItem.optionGroupRefs 에 inactive ref 있으면 disabled marker 로 함께 표시
```

### customer 메뉴 상세 옵션 fetch (storeId 컨텍스트)
```text
MenuItemDetailPage
  → storeProvider 로 매장 doc 가짐 (brandId 포함)
  → store.brandId 가 null 이 아니면 → 가맹점 매장 → master ∪ brand fetch
     store.brandId 가 null 이면 → 개인 매장 → master ∪ store fetch
  → ref.watch(optionGroupsForMenuItemProvider({menuItem, brandId, storeId}))
  → repository.getOptionGroupsForMenuItem(menuItem, brandId, storeId)
     → ref.scope == master → getMasterOptionGroup(ref.id) (legacy 호환)
     → ref.scope == brand → getBrandOptionGroup(brandId, ref.id)
     → ref.scope == store → getStoreOptionGroup(storeId, ref.id)
  → 결과 list → UI
```

### 사용 중 검사 (delete 시)
```text
OptionGroupDeleteDialog
  → CountOptionGroupUsageUseCase({scope, id})
  → OptionGroupRepository.countUsage
  → DataSource:
     [A안 PoC] collectionGroup('menuItems').where('optionGroupRefs', arrayContains: {scope, id}).count()
     [B안 fallback] collectionGroup('menuItems').where('optionGroupRefIds', arrayContains: id).count()
       (메뉴 doc 의 optionGroupRefIds 평면 필드 사용 — set merge 시 자동 동기화)
  → > 0 이면 차단 + 다이얼로그 "사용 중 N개. 비활성으로만 가능"
  → 0 이면 delete 허용
```

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| read stream error | 에러 UI + retry (invalidate). |
| upsert 실패 (네트워크) | snackbar 토스트 + form 유지. |
| **upsert 시 동일 이름 존재 (`DuplicateOptionGroupNameException`)** | submit 차단 + form inline 에러 ("이미 같은 이름의 옵션 그룹이 있어요"). 디바운스 lookup 도 같은 라벨. |
| **항목 label 중복 (`DuplicateOptionItemLabelException`)** | client-side. items list 영역 inline 에러 라벨. |
| delete 시 사용 중 (`OptionGroupInUseException`) | 다이얼로그 차단 + "사용 중 N개. 비활성으로만 가능". |
| 컬렉션 empty (옵션 그룹 0개) | brand/owner: "+ 추가" CTA. 메뉴 폼: "옵션 그룹 없음 — 옵션 없이 등록 가능". |
| 메뉴 폼 수정 모드 — 옵션 그룹이 inactive | disabled marker + 경고 라벨 ("이 옵션 그룹은 비활성화되었습니다"). 선택 해제 권장. |
| menuItem.optionGroupRefs 가 어디에도 없는 id | customer 옵션 영역에서 자연 제외. tester audit 영역. |
| brand 가맹점 점주가 옵션 그룹 CRUD 시도 (코드 우회) | UseCase 단 권한 체크 throw + 클라이언트 단 진입 차단. 보안 규칙은 별 task. |
| S2 검증 위반 (`brand` 메뉴에 store ref 등) | 메뉴 repository upsert 시 `ArgumentError` (기존 패턴 유지). |
| UseCase 가 scope=master 입력 받았을 때 (신규 등록 시) | `ArgumentError` throw — master 는 read-only. |

---

## 작업 분배

### designer

- **UI 변경 필요 여부**: YES (다수).
- **designer 가 다룰 영역 (요약)**:
  1. brand 본사 옵션 그룹 CRUD 화면 2종 (List / Form) + 진입 tile (`BrandMorePage`).
  2. owner 개인 매장 옵션 그룹 CRUD 화면 2종 (List / Form) + 진입 (`MyStorePage` 메뉴 관리 영역).
  3. 메뉴 폼 3종 selector 갱신 (`MasterMenuFormPage` / `BrandStoreOnlyMenuFormPage` 신규 통합 / `OwnerStoreMenuFormPage`) — scope 별 섹션 헤더 카피 / 빈 상태 / inactive marker.
  4. customer 옵션 시트 fetch 정책 변경에 따른 시각 회귀 검증 (UI 변경 없음 / 정책만).
  5. **`OptionItemListEditor` 핵심 위젯** — 항목 동적 추가/삭제/편집 + label 중복 inline 에러 + priceDelta 음수 허용 입력 UX.

- **디자인 산출물** (`design.md` 작성):

  **A. brand 본사 옵션 그룹 관리 화면 (brand scope)** — 신규
  - `BrandMorePage` 에 "옵션 그룹 관리" tile 추가.
  - `BrandOptionGroupListPage`:
    - 헤더 (제목 + "+ 추가" 버튼).
    - list item: name / selectionType badge (single/multi) / required marker / items 개수 / displayOrder / active toggle / "사용 중 N개" / 편집 / 삭제.
    - empty / loading / error 상태.
  - `BrandOptionGroupFormPage`:
    - 등록 / 수정 모드 분기 (id 자동 생성 — UI 노출 안 함).
    - name input (1~30자 카운터) + **중복 이름 inline 에러 라벨 (디바운스 결과)**.
    - selectionType 라디오 (single / multi).
    - required 스위치.
    - displayOrder number input (0 이상).
    - active 스위치.
    - **`OptionItemListEditor` 영역** (가장 신규/복잡한 영역):
      - 헤더 + "+ 항목 추가" 버튼.
      - 각 row: label input (1~20자) / priceDelta input (음수 허용 — 부호 입력 + 단위 표시 "원") / 삭제 아이콘.
      - 빈 상태 ("항목을 추가해주세요").
      - label 중복 inline 에러.
      - reordering 은 본 phase 비범위 — 단순 add/remove.
    - 저장 / 취소 버튼.
  - `OptionGroupDeleteDialog`:
    - 사용 중 N개 표시.
    - "비활성으로 전환" / "취소" / "삭제" 분기.
  - 검증 카피:
    - 디바운스 inline: "이미 같은 이름의 옵션 그룹이 있어요".
    - 항목 label 중복: "같은 이름의 항목이 있어요".
    - submit race 차단: "이름이 이미 존재합니다. 다른 이름을 사용해주세요".

  **B. owner 개인 매장 옵션 그룹 관리 화면 (store scope)** — 신규
  - 진입: `MyStorePage` "메뉴 관리" 영역.
  - 화면 구조 = brand 화면과 동일 패턴. designer 가 brand 의 컴포넌트를 owner 진입점에서 재사용. storeId 컨텍스트는 진입 시점 박힘.

  **C. 메뉴 폼 3종 selector 갱신**
  - 적용 화면: `MasterMenuFormPage`, `BrandStoreOnlyMenuFormPage` (신규 통합), `OwnerStoreMenuFormPage`.
  - **scope 별 섹션 헤더 카피 (designer 결정)**:
    - master scope: "기본 옵션" (legacy 시드 — 모든 메뉴에서 호환).
    - brand scope: "브랜드 옵션" (해당 brand 자산).
    - store scope: "매장 옵션" (해당 매장 자산).
  - 빈 상태 ("옵션 그룹이 없어요 — 옵션 그룹 관리에서 추가하세요" + 진입 CTA).
  - inactive marker (수정 모드 — 회색 + "비활성" 배지).

  **D. customer 메뉴 상세 옵션 시트 fetch 정책 갱신** (UI 변경 없음 / 회귀)
  - `MenuItemDetailPage` 옵션 영역 — read 정책만 갱신, 시각 변경 없음.
  - `MenuOptionDisableSheet` — 동일.
  - designer 는 fetch 결과 (master ∪ brand 또는 master ∪ store) 가 시각적으로 정상 노출되는지 확인.

  **E. admin 영역**
  - **변경 없음**. (결정 5 — admin 미관리.)

- **전달할 사항**:
  - 본 spec 결정 1~9 + 결정 1 추가 (메인 카테고리 종속 정책 = A안) + Qradar 디자인 토큰.
  - sub-phase 8 brand/owner sub-category list/form 디자인 패턴 재사용.
  - sub-phase 9 admin main-category list/form 패턴 재사용.
  - **`OptionItemListEditor`** 는 본 phase 신규 핵심 위젯 — 디자인 우선순위. priceDelta 음수 입력 UX 가 핵심 (부호 토글 / 직접 입력 / 단위 표시).

### developer

- **구현 항목**:
  - **Domain**:
    - `OptionScope` enum 에 `brand` 추가 (master deprecated marker).
    - `OptionGroupEntity` 필드 확장 + freezed 재생성.
    - `OptionRepository` signature 확장 (`getBrandOptionGroup`, `getOptionGroupsForMenuItem(menuItem, brandId, storeId)`).
    - `OptionGroupRepository` interface 신규.
    - UseCase 7개 (WatchByScope / FindById / Upsert / Delete / ToggleActive / CountUsage / FindDuplicateName).
    - `OptionGroupInUseException`, `DuplicateOptionGroupNameException`, `DuplicateOptionItemLabelException`.
  - **Data**:
    - `OptionGroupModel` 필드 확장 + path resolver (brand path 추가).
    - `OptionRemoteDataSource` 확장: brand 메서드 + scope 별 stream/upsert/delete/countUsage/findDuplicateName.
    - `OptionRepositoryImpl` 갱신 (read 정책 + brandId / storeId 파라미터).
    - `OptionGroupRepositoryImpl` 신규.
    - `FirestorePaths.brandOptionGroupsPath(brandId)` 추가.
    - **arrayContains query PoC (결정 4)** — A안 객체 매칭 호환 검증. 호환 안 되면 B안 (`optionGroupRefIds` 평면 list 자동 동기화) 적용 + 메뉴 repository upsert 시점에 자동 채우기.
  - **Presentation (brand/owner CRUD)**:
    - `BrandOptionGroupListPage` / `BrandOptionGroupFormPage`.
    - `OwnerStoreOptionGroupListPage` / `OwnerStoreOptionGroupFormPage`.
    - 공통 위젯: `OptionGroupListItem` / `OptionGroupFormFields` / `OptionGroupDeleteDialog` / **`OptionItemListEditor`** (`presentation/common/widgets/option_groups/`).
    - `BrandMorePage` / `MyStorePage` 진입 tile 추가 + 가맹점 점주 가드.
    - 폼: 디바운스 중복 이름 lookup + items list 동적 추가/삭제 + label 중복 client validation + priceDelta 음수 입력 처리.
    - item id 자동 생성 (uuid 기반 짧은 ID).
  - **Presentation (메뉴 폼 3종)**:
    - `MasterMenuFormPage`: selector 갱신 — master ∪ brand 머지 + scope 별 섹션 + inactive marker.
    - `BrandStoreOnlyMenuFormPage`: **selector 신규 통합** + master ∪ brand 머지.
    - `OwnerStoreMenuFormPage`: selector 갱신 — master ∪ store 머지 + scope 별 섹션.
    - `OptionGroupSelector` 위젯 — scope 별 섹션 헤더 + inactive marker.
  - **Presentation (customer)**:
    - `MenuItemDetailPage` `optionGroupsForMenuItemProvider` 갱신 (brandId / storeId 파라미터 추가).
    - `MenuOptionDisableSheet` 동일 갱신.
  - **Provider**:
    - `optionGroupRepositoryProvider`.
    - `brandOptionGroupsProvider` family (활성/전체).
    - `ownerStoreOptionGroupsProvider` family.
    - `optionGroupUsageProvider`.
    - `findDuplicateOptionGroupNameProvider`.
    - `selectorOptionGroupsProvider` (메뉴 폼 selector 용 scope 머지 wrapping).
  - **메뉴 repository 검증 갱신** (S2):
    - `MasterMenuItemRepositoryImpl._validateOptionGroupScope` — `master` only → `master ∪ brand`.
    - BrandStoreOnly menu repository — 신규 검증 (`master ∪ brand`).
    - OwnerStoreMenu repository — 신규 검증 (`master ∪ store`).
  - **인덱스**:
    - `firestore.indexes.json` — `arrayContains` 자동 인덱스 호환 검증. B안 fallback 시 `optionGroupRefIds` 인덱스 추가.
- **재사용할 기존 구조**:
  - sub-phase 8 brand/owner sub-category CRUD 패턴 (List / Form / DeleteDialog / Provider 구조).
  - sub-phase 4 `OptionGroupSelector` 의 master/store 양쪽 머지 패턴 (master ∪ brand / master ∪ store 로 일반화).
  - sub-phase 9 main-category active 토글 + countUsage 패턴.
  - `FirestorePaths` brand/store 경로 헬퍼.
- **주의할 레이어 규칙**:
  - Firebase import 는 `data/` 만.
  - presentation 은 UseCase / Repository interface 만 알 것.
  - `OptionGroupEntity` freezed 재생성 — `dart run build_runner build --delete-conflicting-outputs`.
  - 가맹점 점주의 store CRUD 차단은 클라이언트 단 (UseCase 가드 + 진입 tile 미노출). 보안 규칙은 별 task.
  - **단일 PR 머지** — entity 필드 확장 + 메뉴 폼 호출처 + customer read 정책이 동시에 깨질 수 있어 일괄 머지.
  - **검증 정책 (옵션 2)** — UseCase 가 race 방지 책임. 폼은 UX 보조용 디바운스만.
  - **`arrayContains: {scope, id}` query PoC** — Firestore 직렬화 호환 우선 확인. 호환 안 되면 B안 (`optionGroupRefIds: List<String>` 평면 필드) 일괄 적용. 메뉴 upsert 경로에서 자동 동기화 코드 함께 머지.
  - **priceDelta 음수 허용** — 폼 입력 + model 직렬화 + UI 표시 모두 음수 케이스 검증 (예: "-500", "-1000원" 노출).
  - **item id 자동 생성** — `uuid` 패키지 또는 `nanoid` 사용. dependencies 추가 시 `pubspec.yaml` 갱신.

### tester

- **주요 검증 기준**:
  - **마이그레이션 / 호환 검증 (B-3)**:
    - 신규 brand 의 옵션 그룹 0개 상태에서 메뉴 폼 진입 → master 시드만 노출 + "옵션 그룹 없음" 안 뜸 (master 가 있으니).
    - 기존 메뉴의 `optionGroupRefs[scope=master]` 데이터가 customer 메뉴 상세에서 정상 read (legacy 호환).
    - 기존 시드 (`og_master_shot/syrup/temperature`) 가 그대로 read 됨.
    - master 컬렉션은 코드/UI 어디서도 신규 doc 생성 안 됨.
  - **read 동작 (메뉴 폼 selector)**:
    - `MasterMenuFormPage`: master ∪ brand 노출 (섹션 분리) + inactive marker.
    - `BrandStoreOnlyMenuFormPage`: master ∪ brand 노출 (selector 신규 통합 검증).
    - `OwnerStoreMenuFormPage`: master ∪ store 노출.
    - 저장 후 `MenuItemEntity.optionGroupRefs` 가 사용자 선택값 + 적절한 scope (선택한 그룹의 scope 그대로) 으로 박힘.
  - **CRUD 동작 (brand/owner)**:
    - brand 본사: 자기 brandId 만 CRUD 가능.
    - owner 개인 매장: 자기 storeId 만 CRUD 가능.
    - items list 동적 추가/삭제 정상 + label 중복 차단.
    - **priceDelta 음수 입력 정상** (예: -500 저장/표시/메뉴 옵션 적용 시 가격 차감).
    - 사용 중 옵션 그룹 hard delete 시도 → 차단 + 다이얼로그.
    - 사용 0개 옵션 그룹 hard delete → 정상.
    - active=false → 신규 폼 selector 에서 제외 + customer 영역에서 제외, 기존 메뉴는 보존.
    - item id 자동 생성 정상 (uuid 형식 / 수정 시 보존).
  - **검증 정책 (옵션 2) 검증**:
    - 같은 brand 안에서 동일 이름 옵션 그룹 등록 시도 → 차단 + inline 에러.
    - 같은 brand 안에서 대소문자/공백만 다른 이름 등록 시도 → 차단.
    - 다른 brand 간 동일 이름 → 허용.
    - brand 옵션 그룹 vs store 옵션 그룹 동일 이름 → 허용 (scope 격리).
    - master vs brand 동일 이름 → 허용 (master 는 별도 scope).
    - 수정 모드에서 자기 자신의 이름 그대로 저장 → 정상 (excludeId).
    - 한 그룹 내 항목 label 중복 → submit 차단 (client validation).
    - 디바운스 lookup race: 빠르게 타이핑 + submit → UseCase 가 최종 차단.
  - **권한 매트릭스 검증**:
    - brand 본사만 자기 brandId 의 brand scope CRUD.
    - 가맹점 점주는 brand 옵션 그룹 CRUD UI 자체가 미노출.
    - owner 개인 매장 점주만 자기 storeId 의 store scope CRUD.
    - admin 은 옵션 그룹 CRUD 진입 tile 자체가 없음 (회귀 — `AdminMorePage` 변경 없음 확인).
    - **UseCase 가 scope=master 신규 입력 받으면 ArgumentError**.
  - **S2 검증 갱신**:
    - 마스터 메뉴 upsert: master ∪ brand ref 허용. store ref 차단.
    - BrandStoreOnly upsert: master ∪ brand ref 허용. store ref 차단.
    - 개인 매장 메뉴 upsert: master ∪ store ref 허용. brand ref 차단.
  - **회귀 테스트**:
    - sub-phase 1 (brand_master) — 마스터 메뉴 등록/수정 정상 (master ref 보존 + brand 신규 추가 가능).
    - sub-phase 1 patch — 옵션 selector 정상 (scope 머지 변경 후).
    - sub-phase 4 (owner_personal_menu) — 개인 매장 메뉴 폼 정상.
    - sub-phase 5 (owner_options_soldout) — disable 토글 / `getOptionGroupsForMenuItem` filter 정상.
    - sub-phase 8 (sub_category) / 9 (main_category) — 충돌 없음.
    - customer 메뉴 상세 옵션 영역 — 정상 fetch (가맹점 매장 = master ∪ brand, 개인 매장 = master ∪ store).
    - 옵션 disable 시트 — 정상 fetch.
- **반드시 확인할 예외 케이스**:
  - menuItem.optionGroupRefs 가 어떤 컬렉션에도 없는 id 일 때 customer / 메뉴 폼 동작 (자연 제외 / fallback 라벨).
  - 메뉴 폼 수정 모드 — 일부 옵션 그룹 inactive + 일부 active 가 섞여 있을 때 UI 동작.
  - **`arrayContains` query PoC 결과**: A안 객체 매칭 통과 / 실패 시 B안 (`optionGroupRefIds`) 적용 — countUsage 정확성 검증.
  - 시드 race / upsert 동시성 (set merge — idempotent + duplicate 체크 race 시 두 번째 실패).
  - 가맹점 점주 사용자가 직접 link/route 우회로 brand CRUD 페이지 접근 시도.
  - **priceDelta 음수 케이스 — 메뉴 옵션 적용 시 cart 계산 정합성** (이중 음수 / 음수 합산).
  - audit: 기존 menuItem.optionGroupRefs 분포 — master / brand / store / 알 수 없음 비율. tester `test_report.md` 에 분포 명시. 이상 doc 발견 시 architect 보고.

---

## 마이그레이션 단계 (단계별 / 단일 PR 권장)

> 단일 PR 머지. 부분 PR 시 entity 필드 확장 + 호출처 다수 깨짐.
>
> **B-3 확정 — 시드 마이그레이션 utility 불필요. legacy `optionGroups/{id}` 그대로 보존.**

```text
[Step 1] 도메인 + 데이터 인프라
  - lib/domain/entities/option_scope.dart 확장 (brand 추가, master deprecated marker)
  - lib/domain/entities/option_group_entity.dart 필드 확장 + freezed 재생성
  - lib/domain/repositories/option_repository.dart signature 확장 (brandId/storeId 파라미터)
  - lib/domain/repositories/option_group_repository.dart 신규
  - lib/core/errors/option_group_in_use_exception.dart 신규
  - lib/core/errors/duplicate_option_group_name_exception.dart 신규
  - lib/core/errors/duplicate_option_item_label_exception.dart 신규
  - lib/data/models/option_group_model.dart 필드 확장 + path resolver
  - lib/data/datasources/remote/option_remote_data_source.dart 확장 (brand 메서드 + scope 별 CRUD)
  - lib/data/repositories/option_repository_impl.dart 갱신
  - lib/data/repositories/option_group_repository_impl.dart 신규
  - UseCase 7개 신규
  - DI providers
  - lib/core/constants/firestore_paths.dart — brandOptionGroupsPath 추가
  - firestore.indexes.json — arrayContains 호환 검증 / 필요 시 인덱스 추가
  - **arrayContains query PoC** — A안 객체 매칭 호환 / 호환 안 되면 B안 평면 list 도입

[Step 2] S2 검증 갱신 + 메뉴 폼 selector 갱신
  - master_menu_item_repository_impl S2: master only → master ∪ brand
  - brand_store_only_menu repository S2 신규 (master ∪ brand)
  - owner_store_menu repository S2 갱신 (master ∪ store)
  - MasterMenuFormPage selector — master ∪ brand 머지 + 섹션 헤더
  - BrandStoreOnlyMenuFormPage selector 신규 통합 (master ∪ brand)
  - OwnerStoreMenuFormPage selector — master ∪ store 머지 + 섹션 헤더
  - OptionGroupSelector 위젯 — scope 별 섹션 + inactive marker

[Step 3] brand / owner CRUD 화면
  - presentation/brand/option_groups/ 신규
  - presentation/owner/option_groups/ 신규
  - 각 영역에 List / Form / DeleteDialog + OptionItemListEditor (priceDelta 음수 허용 입력 UX 포함)
  - 진입 tile / CTA 추가 (BrandMorePage / MyStorePage)
  - 가맹점 점주 진입 가드
  - 폼: 디바운스 중복 이름 lookup + items list 동적 + label 중복 client validation + item id 자동 생성

[Step 4] customer 회귀 보장
  - optionGroupsForMenuItemProvider 갱신 (brandId / storeId 파라미터)
  - MenuItemDetailPage / MenuOptionDisableSheet 호출 부 갱신
  - getOptionGroupsForMenuItem 의 ref scope 별 분기 + master 호환

[Step 5] 검증 (B-3 — 시드 마이그레이션 utility 없음)
  - flutter analyze 0 error
  - flutter test 전체 통과
  - 수동 회귀 — sub-phase 1/1patch/4/5/8/9 화면 정상
  - 권한 매트릭스 (brand 본사/가맹점 점주/개인 매장 점주) 동작
  - admin 측 변경 없음 회귀 (AdminMorePage 진입점 그대로)
  - 검증 정책 — 같은 scope 동일 이름 차단 / 다른 scope 허용 정상
  - countUsage 정확성 (arrayContains query 호환 — A안 또는 B안)
  - menuItem.optionGroupRefs audit (분포 + 매칭 정합성)
  - master 시드 read-only 보존 — 신규 doc 생성 시도 차단 확인
  - priceDelta 음수 케이스 cart 계산 정합성
  - Firestore 인덱스 배포 확인
```

---

## 완료 기준

- [x] 사용자가 결정 1~9 회신 완료 → spec APPROVED
- [ ] `design.md` 작성 (designer) — A/B/C/D 4개 영역 반영 (E admin 영역은 변경 없음)
- [ ] `implementation.md` 작성 (developer) + `flutter analyze` 0 error + `flutter test` 통과
- [ ] 옵션 그룹 CRUD 2-tier (brand/owner) 정상 동작
- [ ] 메뉴 폼 3종 selector master ∪ scope 머지 노출 + 저장 시 optionGroupRefs scope 갱신
- [ ] customer 메뉴 상세 옵션 영역 정상 fetch (가맹점 = master ∪ brand, 개인 매장 = master ∪ store)
- [ ] sub-phase 1 / 1patch / 4 / 5 / 8 / 9 회귀 PASS
- [ ] menuItem.optionGroupRefs audit 통과
- [ ] Firestore 인덱스 / arrayContains query 호환 확인 (A안 또는 B안 fallback)
- [ ] 권한 매트릭스 검증 (brand 본사/가맹점 점주/개인 매장 점주) PASS
- [ ] 검증 정책 (같은 scope 동일 이름 차단 / 다른 scope 허용 / items label 중복 차단) PASS
- [ ] priceDelta 음수 케이스 cart 정합성 PASS
- [ ] master 시드 read-only 보존 — 신규 doc 생성 차단 확인
- [ ] `test_report.md` FAIL 없음 또는 후속 작업으로 분리

---

## Follow-up / 다음 작업 후보

본 sub-phase 7 의 비범위로 분리된 항목 + 향후 phase 후보.

### F1. Firestore 보안 규칙 강화

본 phase 는 클라이언트 가드만. 보안 규칙으로:
- `brands/{brandId}/optionGroups` write 가 그 brand 의 본사 uid 만 가능.
- `stores/{storeId}/optionGroups` write 가 그 매장 owner uid 만 가능.
- legacy `optionGroups/{id}` write 차단 (read 만 허용).
별 phase.

### F2. 가맹점 점주가 매장 한정 옵션 그룹 추가

본 phase 는 가맹점 점주 read-only. 운영 데이터 검토 후 도입 결정.

### F3. 옵션 항목 reordering (drag-drop)

폼의 items list 영역에 drag handle + reorder. 단순 add/remove 외 추가 기능. **본 phase 비범위**.

### F4. 옵션 항목 단위 active toggle

현재는 그룹 단위 active 만. 항목 단위 비활성 (특정 사이즈 sold out 등) 은 별 도메인. **본 phase 비범위**.

### F5. 옵션 그룹 변경 시 가맹점 알림

본사 옵션 그룹 변경 시 가맹점 점주에게 알림 (FCM / 이메일). sub-phase 8/9 의 4d Heavy 와 묶음.

### F6. legacy `optionGroups/{id}` 폐기 (B-3 의 다음 단계)

운영 안정화 후 → legacy 컬렉션의 시드를 각 brand 시드로 이관 + menuItem.optionGroupRefs scope 일괄 변환 + `OptionScope.master` enum 제거. 별 phase + dev/staging utility 작성.

### F7. 오타/유사명 자동 감지

검증 정책 옵션 2 의 한계. 임베딩 유사도 / 편집 거리 기반 탐지. sub-phase 8 F7 와 묶음.

### F8. 옵션 항목 priceDelta 일괄 변경 / 시즌 가격

운영자 편의. 별 phase.

### F9. 다국어 label (i18n)

옵션 그룹 / 옵션 항목 label 다국어. i18n 도입 phase 와 묶음.

### F10. `applicableMainCategories` 자동 필터 (결정 1 추가의 다음 단계)

본 phase 에서 A안 (현재 구조 유지) 채택. 운영 데이터 누적 후:
- 옵션 그룹에 `applicableMainCategories: List<String>` 메타 필드 도입.
- 메뉴 폼 selector 가 메뉴의 main 카테고리에 따라 자동 필터링 (예: 에이드 메뉴에는 "샷 추가" 안 노출).
- 또는 suggested filter (점주 추천 칩, 끄면 전체 노출).
- 마이그레이션: 기존 옵션 그룹의 메타 필드는 빈 set (= 모든 카테고리 적용 가능) 으로 시작.
별 phase. UX 패턴 + 데이터 정형화 검토 필요.

### F11. admin 옵션 그룹 모니터링 / 분포 audit

본 phase 결정 5: admin 옵션 그룹 CRUD 미관리. 운영 안정화 후:
- admin 측 read-only 모니터링 페이지 (`AdminMorePage` tile 신규).
- 글로벌/brand/store 별 옵션 그룹 개수 / 사용 분포 / 비활성 그룹 수.
- 이상 데이터 (orphan ref 등) audit 도구.
- 신규 글로벌 시드 추가는 여전히 코드/배포로만 (운영 인터페이스 없음).
별 phase.
