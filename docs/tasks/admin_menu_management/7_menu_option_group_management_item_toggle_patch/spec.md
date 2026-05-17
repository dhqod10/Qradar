# sub-phase 7 patch — menu_option_group_management_item_toggle_patch 기능 명세

> **상태**: DRAFT — architect 결정 1~5 확정. designer/developer/tester 분배 가능.
>
> **umbrella 단일 진실원**: `admin_menu_management/spec.md` 의 결정 J (핵심/운영 필드 분리) 와 데이터 모델 (`MenuItemEntity.disabledOptionGroupIds` / `disabledOptionItemIds`) 을 따른다.
>
> **선행 phase**:
> - sub-phase 5 (`owner_options_soldout`) — `MenuItemEntity.disabledOptionItemIds` 필드 + `compositeId = '{groupId}_{itemId}'` 포맷 + `MenuOptionDisableSheet` 인라인 시트 도입.
> - sub-phase 7 (`menu_option_group_management`) — `OptionGroupSelector` 위젯 + 메뉴 폼 3종의 옵션 그룹 selector 통합.
>
> 본 patch 는 **sub-phase 7 의 메뉴 폼 selector 보강** 이다. 메뉴 폼(`MasterMenuFormPage` / `BrandStoreOnlyMenuFormPage` / `OwnerStoreMenuFormPage`) 에서 옵션 그룹을 체크할 때, **그 그룹 안의 개별 항목까지 메뉴별로 ON/OFF 토글** 가능하게 한다. 결정 A안에 따라 **sub-phase 5 의 인라인 시트 (`MenuOptionDisableSheet`) 와 둘 다 유지** 하며, 같은 필드 (`disabledOptionItemIds`) 를 공유한다.

---

## 개요

- **목적**:
  1. 메뉴 폼 안의 `OptionGroupSelector` 가 옵션 그룹 체크 시 그 그룹의 항목까지 항목 단위 ON/OFF 토글을 노출하도록 확장한다.
  2. 메뉴 폼 submit 시 그룹 단위 (`disabledOptionGroupIds`) 와 항목 단위 (`disabledOptionItemIds`) 두 필드 모두 새 정의/수정으로 매핑한다.
  3. sub-phase 5 의 카드 인라인 시트 (`MenuOptionDisableSheet`) 와 두 흐름이 **같은 필드** 를 건드리는 점을 명시적 정합으로 보장한다.
  4. **마스터 메뉴/브랜드 점포 한정 메뉴** 의 `_hasOperationFieldChange` 비교 함수에 `disabledOptionGroupIds` / `disabledOptionItemIds` 를 포함시켜 운영 필드 변경 시 status pending 회귀 없이 즉시 반영되게 한다 (결정 J 정합).
- **작업 유형**: 기존 기능 보강 (UI 확장 + 폼 매핑 + 변경 분석 함수 보강). 도메인/데이터 변경 없음.
- **영향 범위**:
  - 화면(공통): `OptionGroupSelector` 위젯 — 그룹 체크 시 그 그룹의 항목 list (label + priceDelta + ON/OFF Switch) 노출 영역 신규 추가. 또는 **신규 `OptionGroupItemTogglePanel` 위젯 분리 후 selector 가 합성** (결정 3 참조).
  - 화면(brand 본사 마스터 메뉴): `MasterMenuFormPage`
    - prefill: `_disabledOptionGroupIds` / `_disabledOptionItemIds` 상태 신설 (등록 모드 = 빈 배열, 수정/복제 = source 값 복사).
    - submit: 위 두 필드를 `MenuItemEntity` 에 매핑.
    - `_hasOperationFieldChange`: 두 필드 비교 추가.
  - 화면(brand 본사 점포 한정 메뉴): `BrandStoreOnlyMenuFormPage` — 위와 동일 (`_hasOperationFieldChange` 비교 추가).
  - 화면(owner 개인 매장 메뉴): `OwnerStoreMenuFormPage`
    - prefill: 동일 (현재 `_source?.disabledOptionGroupIds` / `_source?.disabledOptionItemIds` 가 submit 단계에서만 보존되고 있음 → state 로 끌어올려 selector 와 연동).
    - submit: state 기반으로 매핑 (기존 source 보존 코드 제거).
    - `_hasChanged`: 두 필드 비교 추가.
  - Domain: **변경 없음** (`disabledOptionGroupIds` / `disabledOptionItemIds` 는 sub-phase 5 시점에 도입 완료).
  - Data: **변경 없음** (`MenuItemModel` 의 두 필드는 이미 직렬화 지원).
  - Presentation 공통: `OptionGroupSelector` 의 콜백 시그니처 확장 (그룹 토글 + 항목 토글) 또는 컨트롤러형 분리.
  - 공통 컴포넌트: 위 위젯 외 변경 없음. sub-phase 5 의 `MenuOptionDisableSheet` 그대로 유지.
  - 라우팅: 변경 없음.
  - 권한 / 환경 설정: 변경 없음.
  - 테스트:
    - 회귀: sub-phase 5 인라인 시트, sub-phase 7 메뉴 폼 selector, customer 측 옵션 시트 노출.
    - 신규: 메뉴 폼 항목 ON/OFF 토글 + 동일 메뉴 인라인 시트의 동기화 (둘 다 같은 필드 건드림), 마스터 메뉴의 운영 필드 변경 시 status pending 회귀 미발생, 등록 시 모든 항목 default ON.
- **비범위** (이번 작업에서 명시적으로 제외):
  - **항목 단위 priceDelta 편집** — 옵션 그룹 CRUD (sub-phase 7) 의 책임. 본 patch 는 ON/OFF 만.
  - **옵션 그룹 자체의 item 정의 변경 (sub-phase 7 의 `OptionItemListEditor`)** — 별 흐름.
  - **항목 drag-drop reordering** — sub-phase 7 Follow-up F3.
  - **항목 단위 active 토글 (Repository 차원, sub-phase 7 Follow-up F4)** — 본 patch 는 메뉴별 disabled 만 다룬다. 그룹 차원 항목 active 는 그룹 폼에서 별도 처리.
  - **customer 측 옵션 시트 UI 변경** — `disabledOptionItemIds` 필드는 이미 customer 옵션 시트에서 사용 중. 회귀 검증만.
  - **MenuOverride (`brandMasterRef` 경로) 의 동일 흐름 통합** — sub-phase 5 시트가 override 도 처리하므로 본 patch 는 메뉴 폼 (`MenuItemEntity` 직접 편집) 만 본다. override 측 동일 정책 확장은 Follow-up 분리.

---

## 의존 phase / 진입 조건

- **의존 phase**:
  - sub-phase 5 — `disabledOptionGroupIds` / `disabledOptionItemIds` 필드 + compositeId 포맷 + 인라인 시트 패턴.
  - sub-phase 7 — `OptionGroupSelector` 위젯 + 메뉴 폼 3종에 selector 통합.
- **진입 조건**: sub-phase 7 APPROVED.

---

## 핵심 결정 (architect 확정)

### 결정 1. UI 정책 — **확정: 그룹 체크 시에만 항목 토글 노출 (계층형 펼침)**

| 안 | 설명 | 채택 |
|---|---|---|
| A (그룹 체크 시 그 아래 항목 list 펼침) | 그룹 미체크면 항목 list 미노출. 그룹 체크 시 그 그룹의 항목들이 label + priceDelta + Switch 형태로 노출됨. | **✅ 확정** |
| B (항상 항목 list 노출, 그룹 미체크 시 항목들 dim) | 항목 list 가 항상 보임. 그룹 미체크 상태에선 dim/disabled. | — |
| C (별도 모달 진입) | selector 옆에 "항목 관리" 버튼 → 모달에서 토글. | — |

**확정 세부**:
- 그룹 체크박스는 기존 `CheckboxListTile` 유지.
- 체크된 그룹의 카드 하단에 항목 list 영역 펼침 (sub-phase 5 인라인 시트와 시각 패턴 일치).
- 항목 row = label + priceDelta 텍스트 + 우측 `Switch.adaptive` (`activeThumbColor: AppColors.primary`, `inactiveThumbColor: AppColors.error`).
- 그룹 체크 해제 시 항목 영역 collapse. `disabledOptionItemIds` 의 해당 그룹 compositeId 들은 **그대로 유지** (재체크 시 복원). 즉 그룹 토글이 항목 상태를 파괴하지 않음.
- **이유**: 사용자 멘탈 모델 "그룹을 켰을 때만 항목 세부 제어가 의미 있다" 와 일치. B 안 (항상 노출 + dim) 은 항목 다수 그룹에서 시각적 노이즈가 크고, 신규 등록 시 미선택 그룹의 항목들이 다 보이면 혼란. C 안 (모달) 은 sub-phase 5 인라인 시트와 중복되어 사용자 동선이 분산됨.

---

### 결정 2. 항목 토글 default — **확정: 기본 ON (활성)**

| 안 | 설명 | 채택 |
|---|---|---|
| A (기본 ON) | 등록 시 모든 항목 활성. 점주가 명시적으로 OFF 한 항목만 `disabledOptionItemIds` 에 들어감. | **✅ 확정** |
| B (기본 OFF) | 등록 시 모든 항목 비활성. 점주가 명시적으로 ON 한 항목만 활성. | — |

**확정 세부**:
- 신규 메뉴 등록 시 `disabledOptionItemIds` 는 빈 배열로 시작.
- 수정 모드는 `source.disabledOptionItemIds` 그대로 prefill.
- 옵션 그룹 폼 (sub-phase 7) 에서 추가된 새 항목은 해당 메뉴의 `disabledOptionItemIds` 에 자동으로 들어가지 않음 → 기본 ON.
- **이유**: 점주 운영 부담 최소화 (기본값 = 그룹의 모든 항목 사용 가능). 기본 OFF 는 신규 항목 추가 시마다 모든 메뉴에서 활성화해야 하는 운영 부담 발생.

---

### 결정 3. 위젯 분리 — **확정: 기존 `OptionGroupSelector` 확장 + 내부 헬퍼 위젯 분리**

| 안 | 설명 | 채택 |
|---|---|---|
| A (기존 `OptionGroupSelector` 확장 단일 위젯) | 한 위젯 안에 그룹 체크박스 + 항목 토글 영역 통합. props 추가. | **✅ 확정** |
| B (신규 `OptionGroupItemSelector` 위젯 분리) | `OptionGroupSelector` 는 그대로 두고 별도 위젯 신설 후 메뉴 폼이 합성. | — |
| C (`OptionGroupSelector` + 내부 private `_OptionItemToggleList`) | 외부 API 는 기존 selector 유지. 내부에서 항목 list 영역만 private 위젯으로 분리. | (실질 채택 형태) |

**확정 세부**:
- 외부 노출 위젯은 `OptionGroupSelector` 1개로 유지 (메뉴 폼 3종 호출부 변경 최소화).
- 내부 구조는 다음 private 위젯으로 분리:
  - `_GroupItemTogglePanel`: 그룹이 체크되었을 때 그 그룹의 항목 list (Switch 포함) 렌더.
  - `_OptionItemToggleRow`: 항목 1개 row (label + priceDelta + Switch).
- `OptionGroupSelector` 의 **새 prop**:
  - `disabledOptionItemIds: List<String>` (현재 disabled 된 compositeId 목록).
  - `onDisabledItemsChanged: ValueChanged<List<String>>` (변경 콜백).
  - `disabledOptionGroupIds: List<String>` (현재 disabled 된 그룹 id 목록).
  - `onDisabledGroupsChanged: ValueChanged<List<String>>` (변경 콜백).
- **호환성**: 기존 `selectedIds` / `onChanged` 는 그대로 유지 (그룹 선택 = `optionGroupRefs` 후보). 새 prop 4 개는 default 값으로 빈 배열 / no-op 콜백을 두어 점진 도입.
- 그룹 단위 ON/OFF 의미 분리:
  - `selectedIds`: 이 메뉴가 사용하는 옵션 그룹 (= `optionGroupRefs` 의 source).
  - `disabledOptionGroupIds`: 사용은 하지만 운영 상 일시 비활성 (sub-phase 5 정의).
  - 본 patch 메뉴 폼 UI 는 `selectedIds` 만 그룹 체크박스로 보여주고, **그룹 단위 disabled 토글은 메뉴 폼에서 노출하지 않음** (sub-phase 5 인라인 시트의 역할로 유지).
  - 결과: 메뉴 폼에선 그룹 체크 = 사용 여부, 항목 Switch = 항목별 disabled. 그룹 단위 disabled 는 sub-phase 5 시트에서만 토글 가능.

**이유**:
- 외부 호출부 (3개 메뉴 폼) 의 호출 변경 면적 최소화.
- 내부 분리로 단위 테스트성/가독성 확보.
- 그룹 단위 disabled 와 그룹 사용 여부 (`selectedIds`) 의 의미 차이가 한 화면에 두 컨트롤로 나오면 혼란 → 그룹 단위 disabled 는 인라인 시트(운영 중 빠른 토글) 에 위임.

---

### 결정 4. 운영 필드 분리 (결정 J 정합) — **확정: `_hasOperationFieldChange` 에 `disabledOptionGroupIds` + `disabledOptionItemIds` 비교 추가**

| 안 | 설명 | 채택 |
|---|---|---|
| A (`_hasOperationFieldChange` 에 두 필드 비교 추가 — 마스터/브랜드-점포한정 메뉴 폼) | 운영 필드 변경으로 분류 → status pending 회귀 없이 `updateMasterMenuItemOperationUseCase` / `updateStoreOnlyMenuOperationUseCase` 호출. | **✅ 확정** |
| B (`_hasCoreFieldChange` 에 두 필드 비교 추가) | 핵심 필드 변경 → admin 재승인 필요. | — |
| C (비교에서 제외 — 변경 없음 처리) | 현재 상태 유지. 두 필드 변경 만으로는 submit 효과 없음. | — |

**확정 세부**:
- umbrella `spec.md` 결정 J 의 운영 필드 정의 (`tags`, `displayOrder`, `imageUrl`, `disabledOption*`, `soldOut`) 에 따라 `disabledOptionGroupIds` / `disabledOptionItemIds` 는 운영 필드.
- 대상 폼:
  - `MasterMenuFormPage._hasOperationFieldChange` 보강.
  - `BrandStoreOnlyMenuFormPage._hasOperationFieldChange` 보강.
  - `OwnerStoreMenuFormPage._hasChanged` (이 폼은 결정 J 분기 없이 단일 update — `disabledOption*` 비교만 추가하면 됨).
- 비교 함수 헬퍼: 기존 `_listEquals(List<String>, List<String>)` 가 순서 민감. `disabledOption*` 는 순서 불변 → set 비교 또는 정렬 후 비교 권장:
  - 안 A: 정렬 후 `_listEquals`.
  - 안 B: `Set<String>` 변환 후 `setEquals` (collection 패키지).
  - architect 권장: **정렬 후 `_listEquals`** (collection 패키지 의존 추가 불필요, 기존 헬퍼 재사용).
- 검증: 두 필드만 변경 시 → `hasCoreChange == false`, `hasOperationChange == true` → operation usecase 호출 → status 보존 + 즉시 반영.
- UseCase / Repository 단에서는 변경 없음 (`updateMasterMenuItemOperationUseCase` / `updateStoreOnlyMenuOperationUseCase` 가 이미 두 필드 포함된 entity 를 받아 그대로 저장).

**이유**:
- umbrella 결정 J 와 정합. disabled* 는 운영 빈도가 높고 위험성이 낮음 → 즉시 반영.
- C 안 (변경 없음 처리) 은 사용자가 폼에서 항목 OFF 후 저장 눌러도 반영 안 됨 → UX 손상.
- B 안 (핵심 필드) 은 admin 재승인이 트리거되어 비합리. disabled 변경마다 admin 승인 요청은 운영 부담.

---

### 결정 5. customer 측 영향 — **확정: 변경 없음 (회귀 검증만)**

| 안 | 설명 | 채택 |
|---|---|---|
| A (변경 없음) | `disabledOptionItemIds` 는 이미 customer 옵션 시트 / 옵션 fetch 단계에서 사용 중. 본 patch 는 입력 채널만 추가. | **✅ 확정** |

**확정 세부**:
- customer 측 옵션 fetch (sub-phase 5 의 `OptionRepository.getOptionGroupsForMenuItem` filter) 가 `MenuItemEntity.disabledOptionItemIds` 를 이미 적용. 본 patch 가 메뉴 폼에서 같은 필드를 채워 넣을 뿐.
- 회귀 검증 포인트 (tester 단계):
  - 메뉴 폼에서 항목 OFF → 저장 → customer 옵션 시트에서 해당 항목 노출 안 됨.
  - 메뉴 폼에서 항목 ON → 저장 → customer 옵션 시트에 해당 항목 노출됨.
  - sub-phase 5 인라인 시트에서 OFF → customer 결과 동일.
  - 메뉴 폼 + 인라인 시트 양쪽에서 같은 항목을 번갈아 토글 → 마지막 저장 값이 우선 (last-write-wins, 도메인 모델 그대로).

---

## 데이터 모델

### 변경 없음

`MenuItemEntity` 의 다음 두 필드를 그대로 사용한다 (sub-phase 5 도입).

| 필드 | 타입 | 의미 |
|---|---|---|
| `disabledOptionGroupIds` | `List<String>` | 메뉴별 그룹 단위 비활성 (그룹 id 목록) |
| `disabledOptionItemIds` | `List<String>` | 메뉴별 항목 단위 비활성. compositeId 포맷 = `'{groupId}_{itemId}'` |

compositeId 포맷은 sub-phase 5 시점 정의를 그대로 따른다 (`MenuOptionDisableSheet._onItemToggle` 의 `${groupId}_$itemId` 참조).

### Entity / DTO 변경 없음

- `MenuItemEntity` — 변경 없음.
- `MenuItemModel` — 변경 없음 (freezed JsonKey 매핑 기존 유지).
- Repository / DataSource 시그니처 변경 없음.

---

## 레이어 설계

### Domain

- Entity: **변경 없음**.
- UseCase: **변경 없음** — `UpdateMasterMenuItemOperationUseCase` / `UpdateStoreOnlyMenuOperationUseCase` / `UpdateOwnerStoreMenuUseCase` 가 이미 `disabledOption*` 포함된 entity 를 받음.
- Repository Interface: **변경 없음**.

### Data

- Model / DTO: **변경 없음**.
- DataSource: **변경 없음**.
- Repository Implementation: **변경 없음**.

### Presentation

- Provider: **변경 없음**.
- Page:
  - `MasterMenuFormPage` — state 신설 (`_disabledOptionGroupIds`, `_disabledOptionItemIds`), prefill / submit 매핑, `_hasOperationFieldChange` 비교 보강.
  - `BrandStoreOnlyMenuFormPage` — 동일.
  - `OwnerStoreMenuFormPage` — state 신설 + submit 시 state 기반 매핑 (기존 `_source?.disabledOption*` 보존 코드 대체) + `_hasChanged` 보강.
- Widget:
  - `OptionGroupSelector` (`lib/presentation/brand/master_menu/widgets/option_group_selector.dart`) — 새 prop 4개 (`disabledOptionItemIds`, `onDisabledItemsChanged`, `disabledOptionGroupIds`, `onDisabledGroupsChanged`) 추가. 그룹 카드 펼침 영역에서 항목 토글 list 렌더.
  - 내부 private 위젯 `_GroupItemTogglePanel` / `_OptionItemToggleRow` 신설.
  - 위젯 위치: 기존 그대로 (`lib/presentation/brand/master_menu/widgets/`). 마스터/브랜드-점포-한정/owner 3종에서 공통 사용 중이라 마이그레이션 후보지만 본 patch 비범위.

---

## 데이터 흐름

```text
[메뉴 폼 UI]
  ├─ 그룹 체크박스 토글 → setState(_selectedOptionGroupIds)
  ├─ 그룹 카드 펼침 영역의 항목 Switch 토글 → setState(_disabledOptionItemIds)
  └─ 저장 버튼
        ↓
   _submit()
     - MenuItemEntity 생성: { optionGroupRefs, disabledOptionGroupIds: _disabledOptionGroupIds, disabledOptionItemIds: _disabledOptionItemIds, ... }
     - _hasCoreFieldChange / _hasOperationFieldChange 분기
        ↓
   UseCase
     - master / brand store-only: UpdateXxxOperationUseCase (운영 필드만 변경 시) — status 보존
     - owner store: UpdateOwnerStoreMenuUseCase (단일 경로)
        ↓
   Repository (변경 없음)
        ↓
   Firestore
```

병행 흐름 (sub-phase 5 인라인 시트):

```text
[카드 인라인 시트 (MenuOptionDisableSheet)]
  └─ 동일한 disabledOptionItemIds 필드 즉시 저장 (메뉴 폼과 별개 진입 동선)
```

두 흐름 모두 같은 필드를 건드린다. 마지막 저장 값이 우선 (도메인 단순 덮어쓰기).

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| 그룹 미체크 상태에서 그룹 unfold | 자동으로 collapse, 변경 없음 |
| 그룹 체크 후 항목 OFF 후 그룹 체크 해제 → 다시 체크 | `_disabledOptionItemIds` 의 해당 compositeId 들은 유지 (체크 재토글이 항목 상태를 파괴하지 않음) |
| 옵션 그룹이 inactive (sub-phase 7) 인데 기존 선택됨 | 기존 sub-phase 7 정책 유지 (inactive 칩 + 해제만 가능). 항목 토글 영역 노출 여부는 selector 가 결정: inactive 칩은 펼침 영역 미노출 (선택 해제만 가능하므로 항목 운영 불가) |
| 옵션 그룹의 items 가 비어 있음 | 그룹 체크 시 펼침 영역에 "이 그룹에 항목이 없어요" 안내 (designer 가 확정) |
| 저장 실패 (network) | 기존 폼 에러 처리 (`showErrorDialog`) 그대로 — disabled* 만 변경 시도 동일 |

---

## 작업 분배

### designer

- **UI 변경 필요 여부**: 있음 (그룹 카드 펼침 영역 + 항목 row + 항목 빈 상태).
- **디자인 산출물**: `docs/tasks/admin_menu_management/7_menu_option_group_management_item_toggle_patch/design.md`
- **전달할 사항**:
  - sub-phase 5 의 `MenuOptionDisableSheet` 의 항목 row 시각 패턴 (label + priceDelta + Switch) 을 그대로 메뉴 폼 내부에 이식하되, **카드형 구조** (그룹 체크박스가 있는 카드 안 펼침 영역) 로 통합 표현.
  - 그룹 체크 시 펼침 애니메이션 (선택적, 가벼운 expand). 그룹 미체크 → 펼침 영역 미렌더.
  - 항목 row 좌측에 label / priceDelta (sub-phase 5 패턴 = `+₩300` 또는 `-₩100`), 우측에 `Switch.adaptive` (active = primary, inactive = error). disabled 항목은 label `lineThrough` + textMuted.
  - 항목 0개 그룹의 펼침 영역 빈 상태 텍스트 카피.
  - 색/간격 토큰: AppColors 전용. 외부 패딩/마진 sub-phase 5 시트와 시각적 일관성 유지.
  - 마스터 메뉴 / 브랜드 점포 한정 / owner 개인 매장 3 폼 모두 동일한 selector → 한 번의 design 으로 3 폼 공통.
  - inactive 그룹 칩 (sub-phase 7 `_InactiveGroupChip`) 의 펼침 영역 처리 명시 (펼치지 않음).

### developer

- **구현 항목**:
  1. `OptionGroupSelector` 확장:
     - 새 prop 4 개 (`disabledOptionItemIds`, `onDisabledItemsChanged`, `disabledOptionGroupIds`, `onDisabledGroupsChanged` — 후자는 본 patch 메뉴 폼 UI 에선 노출 안 하지만 향후 확장용 자리 확보 차원에서만 추가하거나 보류 가능. **architect 권장: 본 patch 에선 `disabledOptionItemIds` / `onDisabledItemsChanged` 2 개만 추가** — 그룹 단위 disabled 토글 UI 는 sub-phase 5 시트에 위임이라는 결정 3 와 정합).
     - 그룹 카드 펼침 영역에 항목 list 렌더 (체크된 그룹만).
     - inactive 그룹 칩은 펼침 영역 미렌더 (해제만 가능).
     - 항목 row = `_OptionItemToggleRow` (private).
  2. `MasterMenuFormPage`:
     - `_disabledOptionGroupIds` / `_disabledOptionItemIds` state 추가.
     - prefill (등록 = 빈 배열, 수정/복제 = source 복사).
     - selector 호출에 새 prop 연결.
     - submit 시 entity 매핑 — `disabledOptionGroupIds: _disabledOptionGroupIds`, `disabledOptionItemIds: _disabledOptionItemIds`.
     - `_hasOperationFieldChange` 비교 보강 (정렬 후 `_listEquals`).
  3. `BrandStoreOnlyMenuFormPage`: 위와 동일.
  4. `OwnerStoreMenuFormPage`:
     - 위와 동일 + `_hasChanged` 보강 (현재 비교 누락).
     - 기존 `disabledOptionGroupIds: _source?.disabledOptionGroupIds ?? []` 코드 대체.
  5. 정렬 후 `_listEquals` 헬퍼 추가 (또는 set 비교 유틸).
- **재사용할 기존 구조**:
  - sub-phase 5 의 compositeId 포맷 (`'{groupId}_{itemId}'`).
  - sub-phase 5 의 `MenuOptionDisableSheet` 항목 row 디자인 패턴.
  - sub-phase 7 의 `OptionGroupSelector` 카드 구조.
  - 기존 `UpdateMasterMenuItemOperationUseCase` / `UpdateStoreOnlyMenuOperationUseCase` / `UpdateOwnerStoreMenuUseCase`.
- **주의할 레이어 규칙**:
  - 도메인 / 데이터 변경 없음. 모든 변경은 `presentation` 안.
  - Firebase 직접 import 금지 (변경 없음 — 본 patch 가 새로 추가하지 않음).
  - `AppColors` 만 사용.
  - sub-phase 5 인라인 시트와 메뉴 폼 selector 가 같은 필드를 건드린다는 점을 implementation.md 에 명시.

### tester

- **주요 검증 기준**:
  - **UI 회귀**:
    - 메뉴 폼 selector 의 그룹 체크박스 동작 (기존 sub-phase 7 회귀).
    - 그룹 체크 시 항목 토글 list 노출 / 미체크 시 collapse.
    - 항목 Switch 토글 (UI 만) — 상태 반영 즉시.
    - inactive 그룹 칩 펼침 영역 미노출.
  - **데이터 정합**:
    - 신규 메뉴 등록 시 `disabledOptionItemIds == []` 로 저장됨 (default ON).
    - 수정 모드 진입 시 source 값 prefill 됨.
    - 항목 OFF → 저장 → Firestore 에 compositeId 들어감 확인.
    - 항목 ON → 저장 → Firestore 에서 compositeId 제거됨 확인.
  - **결정 J 정합**:
    - 마스터 메뉴: 두 필드만 변경 → `UpdateMasterMenuItemOperationUseCase` 호출 → status 보존 (pending 회귀 X). admin 승인 화면에 재진입 안 함.
    - 브랜드 점포 한정 메뉴: 동일 — `UpdateStoreOnlyMenuOperationUseCase` 호출.
    - owner 개인 매장 메뉴: 단일 update — 즉시 반영.
  - **sub-phase 5 시트 동기화**:
    - 메뉴 폼에서 항목 OFF 후 저장 → 같은 메뉴의 sub-phase 5 인라인 시트 진입 시 해당 항목 OFF 상태로 노출됨.
    - 반대로 인라인 시트에서 OFF 후 메뉴 폼 진입 시 OFF 상태 prefill 됨.
    - 두 흐름 모두 같은 entity 필드 사용 확인.
  - **customer 회귀**:
    - 메뉴 폼에서 항목 OFF → customer 옵션 시트에 해당 항목 노출 안 됨.
    - 항목 ON → 노출됨.
- **반드시 확인할 예외 케이스**:
  - 옵션 그룹이 정의된 items 가 0개일 때 펼침 영역 빈 상태 카피.
  - 그룹 체크 해제 후 재체크 시 이전 OFF 상태 복원 (`disabledOptionItemIds` 의 해당 compositeId 들 유지 — 그룹 토글이 항목 disabled 를 파괴하지 않음).
  - 그룹이 inactive (sub-phase 7) 상태일 때 펼침 영역 미노출 + 선택 해제만 가능.
  - 옵션 그룹 폼 (sub-phase 7) 에서 항목 추가 / 삭제 후 해당 그룹을 사용하는 메뉴의 `disabledOptionItemIds` 의 stale compositeId 처리 — **본 patch 비범위** (sub-phase 7 도메인 책임). tester 는 stale compositeId 가 있어도 UI 가 깨지지 않는지만 확인.
  - 두 필드 모두 변경 없고 다른 핵심 필드도 변경 없을 때 → 저장 버튼 누르면 `pop` 만 발생 (UseCase 호출 안 함).
  - mounted 가드 / `_isLoading` 중복 호출 방지.

---

## 마이그레이션 단계

도메인 / 데이터 변경 없음 → 마이그레이션은 **UI / 폼 매핑 보강만**.

1. **Step 1 (designer)**: `design.md` 작성 — 항목 토글 영역 시각 패턴, 그룹 카드 펼침 동작, 항목 row 디자인, 빈 상태 카피.
2. **Step 2 (developer)**:
   - 2-a. `OptionGroupSelector` 확장 (새 prop 추가 + 내부 항목 토글 렌더).
   - 2-b. 메뉴 폼 3종에 state / prefill / submit / 변경 분석 함수 보강.
   - 2-c. `implementation.md` 작성.
   - 2-d. `flutter analyze` / 빌드 검증.
3. **Step 3 (tester)**:
   - 메뉴 폼 selector 회귀 + 항목 토글 신규 케이스 + sub-phase 5 시트 동기화 + customer 회귀 + 결정 J 정합.
   - `test_report.md` 작성.
4. **Step 4 (architect 재검토)**: FAIL 없으면 patch 완료. FAIL 있으면 해당 역할 재호출.

---

## 완료 기준

- [ ] 결정 1~5 모두 spec 에 명시 및 구현 반영
- [ ] `design.md` 작성 완료 — 항목 토글 영역 디자인 확정
- [ ] `OptionGroupSelector` 새 prop 2 개 (`disabledOptionItemIds`, `onDisabledItemsChanged`) 추가됨
- [ ] 메뉴 폼 3종 모두 state / prefill / submit / 변경 분석 함수 보강됨
- [ ] `MasterMenuFormPage._hasOperationFieldChange` / `BrandStoreOnlyMenuFormPage._hasOperationFieldChange` 에 `disabledOption*` 비교 추가됨 (결정 J 정합)
- [ ] `OwnerStoreMenuFormPage._hasChanged` 에 `disabledOption*` 비교 추가됨
- [ ] sub-phase 5 인라인 시트와 두 흐름이 같은 필드 건드림 — 동기화 회귀 확인됨
- [ ] customer 옵션 시트 회귀 확인됨 (변경 없음 / 노출만 확인)
- [ ] `implementation.md` 작성 완료
- [ ] `test_report.md` 작성 완료 — FAIL 없음 또는 후속 작업으로 분리됨
- [ ] `flutter analyze` 통과

---

## 산출물 위치

- `docs/tasks/admin_menu_management/7_menu_option_group_management_item_toggle_patch/spec.md` ← 본 문서
- `docs/tasks/admin_menu_management/7_menu_option_group_management_item_toggle_patch/design.md` ← designer
- `docs/tasks/admin_menu_management/7_menu_option_group_management_item_toggle_patch/implementation.md` ← developer
- `docs/tasks/admin_menu_management/7_menu_option_group_management_item_toggle_patch/test_report.md` ← tester

---

## 다음 단계

1. **designer 호출** — UI 변경 (그룹 카드 펼침 영역 + 항목 row + 빈 상태) 디자인 확정. `design.md` 작성.
2. designer 완료 후 **developer 호출** — `OptionGroupSelector` 확장 + 메뉴 폼 3종 보강. `implementation.md` 작성.
3. developer 완료 후 **tester 호출** — 회귀 + 신규 토글 + 결정 J 정합 + sub-phase 5 시트 동기화 + customer 회귀 검증. `test_report.md` 작성.
4. tester 완료 후 **architect 재검토** — FAIL 없으면 patch 완료.
