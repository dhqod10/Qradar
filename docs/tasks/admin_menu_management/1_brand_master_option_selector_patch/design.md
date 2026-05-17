# 마스터 메뉴 옵션 그룹 선택 UI 보강 (patch) 디자인 명세

## 참조한 디자인

- spec.md: `docs/tasks/admin_menu_management/1_brand_master_option_selector_patch/spec.md`
- 기존 화면: `lib/presentation/brand/master_menu/master_menu_form_page.dart`
- 참고 위젯: `lib/presentation/brand/master_menu/widgets/option_group_selector.dart`
- owner 패턴 참고: `lib/presentation/owner/store_menu/owner_store_menu_form_page.dart` (L454-462)
- Figma: 없음 (기존 폼의 시각 정합 우선)

---

## 디자인 결정사항

### 1. 배치 위치 — 카테고리 아래, 태그 위 (architect 안 A 채택)

**확정**: `_divider` + `_sectionLabel('옵션 그룹')` + `OptionGroupSelector` 를 카테고리 섹션과 태그 섹션 사이에 배치한다.

**근거**:
- `optionGroupRefs` 는 결정 J 에서 **핵심 필드**로 분류된다. 카테고리 역시 핵심 필드이며, 둘 다 "이 메뉴가 무엇인가"를 정의하는 신원 속성이다. 인접 배치가 필드 의미상 자연스럽다.
- 태그 / VisibilityToggle / 노출 순서는 운영 필드 그룹이다. 핵심 필드 블록(이름 / 설명 / 가격 / 카테고리 / 옵션 그룹)과 운영 필드 블록(태그 / 노출 / 순서)이 divider 를 기준으로 시각적으로 구분된다.
- owner 폼은 노출 순서 다음에 옵션 그룹을 배치했으나, 그것은 store scope 가 함께 있는 구조상의 이유였다. brand 폼은 master only 이므로 핵심 필드 근처에 두는 것이 더 명확하다.

**확정 후 폼 섹션 순서**:
```
메뉴 이미지
────────────────
메뉴 이름 / 메뉴 설명
────────────────
기본 가격
────────────────
카테고리          ← 핵심 필드 블록
────────────────
옵션 그룹         ← 이번 patch 추가 위치 (신규)
────────────────
태그              ← 운영 필드 블록
VisibilityToggle
────────────────
노출 순서
```

---

### 2. 섹션 헤더 라벨 — "옵션 그룹" 채택

**확정**: `_sectionLabel('옵션 그룹')` 을 그대로 사용한다.

**근거**:
- owner 폼과 동일 라벨 (`_SectionHeader(label: '옵션 그룹')`) 을 사용해 브랜드/점주 양측에서 일관된 용어를 유지한다.
- "메뉴 옵션" 은 고객 화면의 옵션 선택 UI 와 혼동될 여지가 있다.
- "추가 옵션" 은 '선택 사항'이라는 뉘앙스를 주므로 핵심 필드 성격과 맞지 않는다.
- 필수 표시(`*`) 는 붙이지 않는다. `optionGroupRefs` 는 옵션 필드이며 빈 배열로 등록 가능하다.

---

### 3. 로딩 상태 — 빈 영역으로 자연스럽게 채워짐 (owner 패턴 동일)

**확정**: `brandMasterOptionGroupsProvider` 가 `AsyncLoading` 인 동안 `OptionGroupSelector` 영역을 `asData?.value ?? []` 폴백으로 빈 배열 상태로 렌더링한다. 별도 shimmer / 인디케이터를 추가하지 않는다.

**근거**:
- 폼 전체는 즉시 조작 가능 상태여야 한다. 옵션 그룹 로딩이 폼 진입을 블록하면 안 된다.
- Firestore `fetchAllMaster()` 는 매우 빠른 쿼리이므로 로딩 깜빡임이 거의 없다.
- owner 폼과 완전히 동일한 UX 패턴 유지.
- 로딩 중에는 OptionGroupSelector 내부가 빈 상태 메시지("등록된 옵션 그룹이 없어요")로 표시된 후 데이터 로드 완료 시 자연스럽게 목록으로 교체된다.

---

### 4. 에러 상태 — 빈 배열 폴백 (명시적 에러 UI 없음)

**확정**: `brandMasterOptionGroupsProvider` 가 `AsyncError` 인 경우에도 `asData?.value ?? []` 폴백을 그대로 사용한다. 옵션 그룹 영역에 에러 전용 UI(재시도 버튼 등)를 추가하지 않는다.

**근거**:
- 네트워크 에러 시에도 폼의 다른 필드는 정상 사용 가능해야 한다. 옵션 그룹 없이도 메뉴 등록은 허용된다(비즈니스 규칙).
- 별도 에러 UI 추가 시 UX 복잡도 증가 대비 실익이 낮다.
- 에러 상태에서는 OptionGroupSelector 가 빈 상태 메시지("등록된 옵션 그룹이 없어요")를 표시하게 되므로 사용자는 이상을 인지할 수 있다.
- owner 폼과 동일 패턴.

---

### 5. 빈 상태 — OptionGroupSelector 기본 메시지 그대로 사용

**확정**: master 옵션 그룹 0건일 때 `OptionGroupSelector` 의 내장 메시지("등록된 옵션 그룹이 없어요")를 그대로 사용한다. 폼 차원의 추가 안내 CTA(예: "admin에게 옵션 그룹 시드 요청") 는 본 patch 비범위.

**근거**:
- 현재 Firestore 에 master 시드 3건(`og_master_shot`, `og_master_syrup`, `og_master_temperature`) 이 이미 존재하므로 실제 빈 상태는 드물다.
- admin 안내 CTA 는 후속 UX 개선(spec 비범위)으로 처리한다.

---

### 6. "X개 선택됨" 피드백 배지 — 추가하지 않음

**확정**: 옵션 그룹 섹션 헤더 옆에 "X개 선택됨" 배지를 추가하지 않는다.

**근거**:
- OptionGroupSelector 내부 CheckboxListTile 이 이미 선택 상태를 명확하게 표시하므로, 헤더의 카운터 배지는 중복 정보다.
- 카테고리 / 태그 섹션도 선택 카운터 배지를 사용하지 않으므로 시각 정합을 유지한다.
- 폼이 길어질수록 스크롤로 옵션 그룹 섹션이 가려질 수 있어 요약 정보가 유용하나, 이는 추후 폼 리뷰 영역 개선 시 검토한다.

---

### 7. `_canSubmit` 조건 — 변경 없음

**확정**: `_canSubmit` 에 옵션 그룹 선택 조건을 추가하지 않는다.

**근거**:
- `optionGroupRefs` 는 필수 필드가 아니다. 옵션 없는 메뉴 등록이 비즈니스상 허용된다.
- 현재 `_canSubmit` = 이미지 + 이름 + 가격 > 0 + 카테고리 선택. 이 조건으로 충분하다.

---

## 화면 구성

### MasterMenuFormPage — 변경 범위

기존 화면에서 옵션 그룹 섹션만 추가된다. 나머지 레이아웃은 완전히 동일.

**변경 전 섹션 순서**:
```
메뉴 이미지 → 메뉴 이름 / 메뉴 설명 → 기본 가격 → 카테고리 → 태그 → VisibilityToggle → 노출 순서
```

**변경 후 섹션 순서**:
```
메뉴 이미지 → 메뉴 이름 / 메뉴 설명 → 기본 가격 → 카테고리 → [옵션 그룹] → 태그 → VisibilityToggle → 노출 순서
```

- 레이아웃: `SingleChildScrollView > Column`
- 배경: `AppColors.background`
- 가로 padding: 20 (기존 동일)
- AppBar: 변경 없음

---

## 컴포넌트 목록

### 1. 옵션 그룹 섹션 헤더

카테고리 섹션 이후 `_divider()` 로 구분된 다음 섹션의 레이블.

- 역할: 섹션 식별 레이블
- 위젯: `_sectionLabel('옵션 그룹')` (기존 헬퍼 메서드 그대로)
- 텍스트: "옵션 그룹"
- 스타일:
  - fontSize: 13
  - fontWeight: FontWeight.w600
  - color: `AppColors.textMuted`
- 위치: `_divider()` 바로 아래, `SizedBox(height: 8)` 이후 `OptionGroupSelector`
- 필수 표시(`*`): 없음

---

### 2. OptionGroupSelector (기존 위젯 재사용)

`lib/presentation/brand/master_menu/widgets/option_group_selector.dart` 의 기존 위젯을 그대로 사용. 신규 위젯 제작 없음.

- 역할: master scope 옵션 그룹 목록 표시 + 다중 선택
- 호출 방식:
  ```
  OptionGroupSelector(
    optionGroups: masterGroups,   // brandMasterOptionGroupsProvider 결과
    selectedIds: _selectedOptionGroupIds,
    onChanged: (ids) => setState(() => _selectedOptionGroupIds = ids),
  )
  // storeId 미전달 → master only 분기 (S2 보장)
  ```
- `storeGroups` 미전달 (기본값 `const []`) — store scope 없음
- `storeId` 미전달 (기본값 `null`) — S2 보장, `_buildWithSections()` 분기 트리거 안 됨

#### 2-1. 옵션 그룹 아이템 카드 (CheckboxListTile)

- 배경: `AppColors.surfaceElevated`
- border: `AppColors.border` 1px
- borderRadius: 10
- margin-bottom: 8
- padding (horizontal/vertical): 12 / 4
- 체크박스 activeColor: `AppColors.primary`
- 체크박스 checkColor: `AppColors.onPrimary`
- 체크박스 side color: `AppColors.border`
- title 텍스트:
  - fontSize: 14
  - fontWeight: FontWeight.w500
  - color: `AppColors.textBody`
- subtitle 텍스트 ("마스터 옵션"):
  - fontSize: 11
  - color: `AppColors.textMuted`

#### 2-2. 선택 상태 (selected)

- 체크박스 체크됨 (activeColor: `AppColors.primary`, checkColor: `AppColors.onPrimary`)
- 카드 배경 변화 없음 (`AppColors.surfaceElevated` 유지)
- border 변화 없음

> **설계 의도**: 선택 여부는 체크박스로만 표현한다. 카드 배경/border 색상 변화는 추가하지 않는다. 기존 OptionGroupSelector 구현 그대로다.

#### 2-3. 선택 해제 상태 (unselected)

- 체크박스 비어있음 (side: `AppColors.border`)
- 카드 배경: `AppColors.surfaceElevated`

---

### 3. 상태별 UI

#### 3-1. Loading (brandMasterOptionGroupsProvider AsyncLoading)

- **표시 방식**: `asData?.value ?? []` 폴백으로 빈 배열 전달 → `OptionGroupSelector` 가 내장 빈 상태 메시지 표시
- **컴포넌트**: `OptionGroupSelector` 내장 빈 상태 텍스트 (신규 로딩 UI 없음)
- **텍스트**: "등록된 옵션 그룹이 없어요"
- **색상**: `AppColors.textMuted`
- **padding**: vertical 24 (Center + Padding 기존 구조)
- **폼 나머지 영역**: 즉시 정상 사용 가능 (로딩 블로킹 없음)

#### 3-2. Error (brandMasterOptionGroupsProvider AsyncError)

- **표시 방식**: `asData?.value ?? []` 폴백으로 빈 배열 전달 → 로딩 상태와 동일하게 빈 상태 메시지 표시
- **컴포넌트**: `OptionGroupSelector` 내장 빈 상태 텍스트
- **텍스트**: "등록된 옵션 그룹이 없어요"
- **색상**: `AppColors.textMuted`
- **재시도 버튼**: 없음
- **에러 전용 아이콘**: 없음
- **폼 나머지 영역**: 정상 사용 가능

#### 3-3. Empty (master 옵션 그룹 0건 정상 응답)

- **표시 방식**: `OptionGroupSelector` 내장 빈 상태 텍스트
- **텍스트**: "등록된 옵션 그룹이 없어요"
- **스타일**:
  - fontSize: 13
  - color: `AppColors.textMuted`
  - padding: vertical 24 / Center
- **다음 행동 안내**: 없음 (admin CTA 는 본 patch 비범위)
- **폼 제출 가능 여부**: 옵션 그룹 없이도 `_canSubmit` 조건을 충족하면 제출 가능

#### 3-4. Success (옵션 그룹 N건 노출)

- **표시 방식**: `_buildGroupList(masterGroups, isStore: false)` — CheckboxListTile 목록
- **각 아이템**: 2-1, 2-2, 2-3 항목 참조
- **스크롤**: `shrinkWrap: true` + `NeverScrollableScrollPhysics` (폼 전체 스크롤에 포함)
- **선택 상태**: 체크박스 체크됨 (activeColor `AppColors.primary`, checkColor `AppColors.onPrimary`)
- **토글 반응**: `setState(() => _selectedOptionGroupIds = ids)` 로 즉각 반영

---

## 인터랙션

| 동작 | 반응 |
|---|---|
| 옵션 그룹 카드 탭 | `OptionGroupSelector._toggle(id)` 호출 → `onChanged` → 부모 `setState` → 체크박스 즉각 갱신 |
| 이미 선택된 카드 탭 | 선택 해제 (토글) |
| 폼 스크롤 | 옵션 그룹 영역 포함 전체 폼 스크롤 (NeverScrollableScrollPhysics 로 내부 스크롤 없음) |
| 옵션 그룹 선택 후 submit | `_selectedOptionGroupIds` → `optionGroupRefs` 매핑 (`OptionScope.master` 강제) → UseCase 전달 |
| 수정 모드에서 옵션 그룹 변경 후 submit | `_hasCoreFieldChange` true → `updateMasterMenuItemCore` → SnackBar "수정 사항이 검토 대기 중입니다" |
| 수정 모드에서 옵션 그룹 무변경, 운영 필드만 변경 후 submit | `_hasCoreFieldChange` false → `updateMasterMenuItemOperation` → SnackBar "즉시 반영되었습니다" |

---

## 섹션 divider / 간격 명세

카테고리 섹션 이후부터 옵션 그룹 섹션까지의 위젯 트리:

```
// 카테고리 Wrap (기존)
_divider()                        // height: 32, color: AppColors.border, thickness: 1
_sectionLabel('옵션 그룹')         // fontSize:13 / w600 / AppColors.textMuted
SizedBox(height: 8)
OptionGroupSelector(              // 옵션 그룹 목록 또는 빈 상태 메시지
  optionGroups: masterGroups,
  selectedIds: _selectedOptionGroupIds,
  onChanged: ...,
)
_divider()                        // 태그 섹션 구분
_sectionLabel('태그')              // 기존
```

---

## AppColors 토큰 사용 요약

| 요소 | 토큰 |
|---|---|
| 섹션 헤더 레이블 텍스트 | `AppColors.textMuted` |
| 옵션 그룹 카드 배경 | `AppColors.surfaceElevated` |
| 옵션 그룹 카드 border | `AppColors.border` |
| 체크박스 activeColor | `AppColors.primary` |
| 체크박스 checkColor | `AppColors.onPrimary` |
| 체크박스 side color | `AppColors.border` |
| 아이템 title 텍스트 | `AppColors.textBody` |
| 아이템 subtitle 텍스트 ("마스터 옵션") | `AppColors.textMuted` |
| 빈 상태 / 로딩 / 에러 메시지 텍스트 | `AppColors.textMuted` |
| divider 색상 | `AppColors.border` |

---

## Figma 대비 변경사항

| 항목 | 기존안 / Figma | Qradar 적용 |
|---|---|---|
| Figma 레퍼런스 | 없음 (신규 섹션) | 기존 폼 패턴 그대로 준용 |
| 배치 위치 | architect 후보 A/B/C | A 확정 (카테고리 ↔ 태그 사이) |
| 섹션 헤더 라벨 | "옵션 그룹" 잠정 | "옵션 그룹" 확정 (owner 폼과 동일) |
| 로딩 UI | shimmer 또는 인디케이터 잠정 | 빈 상태 메시지 fallback (owner 패턴 동일) |
| 에러 UI | 명시적 에러 + 재시도 버튼 잠정 | 빈 상태 fallback (단순 UX 우선) |
| 선택 카운터 배지 | 검토 대상 | 추가 안 함 (CheckboxListTile 으로 충분) |
| `_canSubmit` 조건 | 옵션 그룹 조건 추가 여부 검토 | 추가 안 함 (optionGroupRefs 는 선택 필드) |

---

## 개발자 전달 특이사항

### 재사용할 기존 구조 (신규 위젯 제작 없음)

- `_sectionLabel(String text)` — 기존 헬퍼 메서드 그대로 사용. 수정 불필요.
- `_divider()` — 기존 헬퍼 메서드 그대로 사용. 수정 불필요.
- `OptionGroupSelector` — 기존 위젯 그대로 import + 배치. 위젯 내부 수정 불필요.

### provider 호출 방식

build 메서드 내에서 `ref.watch(brandMasterOptionGroupsProvider)` 로 구독 후 `asData?.value ?? []` 폴백을 사용한다. 에러/로딩 분기 처리는 별도로 하지 않는다.

```
// build() 내에서
final masterGroups =
    ref.watch(brandMasterOptionGroupsProvider).asData?.value ?? [];
```

### OptionGroupSelector 호출 시 주의사항

`storeId` 를 절대 전달하지 않는다 (S2 보장). `storeGroups` 도 전달하지 않는다 (기본값 `const []`). `optionGroups` named parameter 에만 `masterGroups` 를 전달한다.

### 상태 필드 prefill (initState)

수정/복제 모드에서 `_selectedOptionGroupIds` 를 `source?.optionGroupRefs.map((r) => r.id).toList() ?? []` 로 초기화한다.

### submit 시 매핑

기존 `optionGroupRefs: baseItem?.optionGroupRefs ?? []` 를 삭제하고 `_selectedOptionGroupIds` 에서 `OptionGroupRef(scope: OptionScope.master, id: id)` 로 매핑한다. 항상 `master` scope 강제.

### `_hasCoreFieldChange` 변경 없음

L118-122 의 기존 옵션 그룹 ID 셋 비교 로직은 변경하지 않는다. 본 patch 로 실제 입력값이 채워지면 기존 로직이 자연스럽게 동작한다.

### import 추가 필요

```
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/presentation/brand/master_menu/widgets/option_group_selector.dart';
```

`brandMasterOptionGroupsProvider` import 는 기존 `brand_master_menu_providers.dart` 경로에 추가되므로 별도 import 파일 추가 없음.

### `build_runner` 불필요

freezed / json_serializable 갱신 없음. `dart run build_runner build` 불필요.

### 후속 작업 (본 patch 비범위)

- 옵션 그룹 빈 상태에서 admin 안내 CTA — 추후 UX 개선
- "X개 선택됨" 헤더 배지 — 추후 폼 리뷰 영역 개선 시 검토
- `displayOrder` 재정렬 UI — 추후 결정
