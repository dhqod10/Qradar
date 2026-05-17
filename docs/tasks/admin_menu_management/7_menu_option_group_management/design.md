# sub-phase 7 — menu_option_group_management 디자인 명세

> **상태**: DRAFT — 2026-05-03
>
> **spec.md 기준**: `docs/tasks/admin_menu_management/7_menu_option_group_management/spec.md` (APPROVED, 결정 1~9 + 결정 보너스 모두 확정)

---

## 참조한 디자인

- Figma: 없음 (Qradar 디자인 시스템 + 기존 화면 톤 기반 신규 설계)
- 기존 화면 레퍼런스:
  - `docs/tasks/admin_menu_management/8_menu_sub_category_management/design.md` — list/form/dialog 컴포넌트 패턴 전면 차용 (패턴 선행 phase)
  - `docs/tasks/admin_menu_management/9_menu_main_category_admin/design.md` — active 토글 / DeleteDialog / FormSection 패턴
  - `lib/presentation/brand/more/brand_more_page.dart` — `_Tile` 패턴 재사용
  - `lib/presentation/owner/my_store/my_store_page.dart` — "메뉴 관리" 영역 CTA 패턴 참조
- 색상 토큰: `lib/core/theme/app_colors.dart`

---

## 전체 화면 목록

| 영역 | 화면 / 컴포넌트 | 유형 |
|---|---|---|
| A1 | BrandMorePage — "옵션 그룹 관리" ListTile 추가 | 기존 화면 수정 |
| A2 | BrandOptionGroupListPage | 신규 |
| A3 | BrandOptionGroupFormPage | 신규 |
| A4 | OptionGroupDeleteDialog (brand / owner 공통) | 신규 |
| B1 | MyStorePage "메뉴 관리" 영역 — "옵션 그룹 관리" 진입 추가 | 기존 화면 수정 |
| B2 | OwnerStoreOptionGroupListPage | 신규 |
| B3 | OwnerStoreOptionGroupFormPage | 신규 |
| C | 메뉴 폼 3종 OptionGroupSelector 갱신 | 기존 위젯 수정 |
| D | customer 옵션 시트 fetch 정책 회귀 | 정책 명세 (시각 변경 없음) |
| E | OptionItemListEditor 핵심 위젯 | 신규 공통 위젯 |

---

## 영역 A — brand 본사 옵션 그룹 관리 화면

### A1. BrandMorePage — "옵션 그룹 관리" ListTile 추가

기존 `brand_more_page.dart` 의 `ListView` 에 타일 1개를 추가한다.

#### 추가 위치

"서브 카테고리 관리" tile 이 존재하면 그 바로 아래. 없으면 "메인 카테고리 관리" 아래.

```
ListView
  ├─ Padding(fromLTRB 20,4,20,16) — "더보기" 제목
  ├─ _Tile '메인 카테고리 관리'   (sub-phase 9 기존)
  ├─ _Tile '서브 카테고리 관리'   (sub-phase 8 기존)
  ├─ [신규] _Tile '옵션 그룹 관리'  ← 추가
  ├─ _Tile '로그아웃'
  └─ _Tile '앱 정보'
```

#### 신규 Tile 명세

기존 `_Tile` 위젯 그대로 재사용:

| 속성 | 값 |
|---|---|
| icon | `Icons.tune_rounded` |
| title | `'옵션 그룹 관리'` |
| subtitle | `null` |
| onTap | `Navigator.push → BrandOptionGroupListPage(brandId: currentBrandId)` |
| trailing | `Icons.chevron_right_rounded` (size 18, `AppColors.textMuted`) |

> 진입 가드: 현재 사용자가 brand 본사(역할: brandHq) 일 때만 이 타일을 노출. brand 가맹점 점주(brandAffiliate) / admin 에게는 미노출.

---

### A2. BrandOptionGroupListPage

- 파일: `lib/presentation/brand/option_groups/brand_option_group_list_page.dart`
- 역할: `brands/{brandId}/optionGroups/` 목록. displayOrder asc 정렬. active 토글 / 편집 / 삭제.

#### 레이아웃

```
Scaffold
  ├─ AppBar
  ├─ body: ListView
  └─ floatingActionButton: FAB
```

#### AppBar

| 속성 | 값 |
|---|---|
| leading | `Icons.arrow_back_ios_new_rounded`, `AppColors.textBody` |
| title | `'옵션 그룹 관리'` |
| titleTextStyle | fontSize 17, w700, `AppColors.textHeading` |
| backgroundColor | `AppColors.background` |
| surfaceTintColor | `Colors.transparent` |
| elevation | 0 |
| actions | 없음 |

#### Body — ListView

- `ListView.builder` + `Padding(horizontal 16, top 8, bottom 80)`
  - bottom 80: FAB 와 겹치지 않도록 확보
- 데이터: `brandOptionGroupsProvider({brandId, activeOnly: false})` (inactive 포함, displayOrder asc)
- 각 항목: `OptionGroupListItem` (하단 명세)
- 항목 간격: `SizedBox(height: 8)`

#### OptionGroupListItem

```
Card
  └─ Padding(horizontal 4, vertical 2)
       └─ ListTile
            ├─ leading: _OrderBadge(displayOrder)
            ├─ title: Row
            │    ├─ Text(name)
            │    ├─ SizedBox(width: 6)
            │    ├─ _SelectionTypeBadge(selectionType)
            │    └─ (required == true) _RequiredMarker
            ├─ subtitle: Column (crossAxisAlignment: start, spacing: 2)
            │    ├─ _UsageChip(scope, id) — "사용 중 N개"
            │    └─ _ItemCountChip(items.length) — "항목 N개"
            ├─ trailing: Row
            │    ├─ OptionGroupActiveSwitch(entity)
            │    ├─ SizedBox(width: 4)
            │    └─ PopupMenuButton
            └─ onTap: Navigator.push → BrandOptionGroupFormPage(editItem: entity)
```

**Card 스타일** (sub-phase 8 패턴 동일):

| 속성 | 값 |
|---|---|
| 배경 | `AppColors.surfaceElevated` |
| border | `AppColors.border` 1px |
| borderRadius | 14 |
| shadow | `AppColors.primary` alpha 0.04 |

**`_OrderBadge(displayOrder)`**:

- `Container(width 36, height 36, radius 8)`
- 배경: `AppColors.surface`
- 텍스트: displayOrder 값, fontSize 14, w700, `AppColors.textMuted`
- 중앙 정렬

**title Text**:

- fontSize 15, w600
- active=true: `AppColors.textHeading`
- active=false: `AppColors.textMuted` (dim 처리로 inactive 구분)

**`_SelectionTypeBadge(selectionType)`**:

- `Container(padding: horizontal 8, vertical 3, radius 6)`
- single: 배경 `AppColors.info` alpha 0.12, 텍스트 `'단일'` fontSize 11, w600, `AppColors.info`
- multi: 배경 `AppColors.primary` alpha 0.12, 텍스트 `'다중'` fontSize 11, w600, `AppColors.primary`

**`_RequiredMarker`**:

- `Icon(Icons.star_rounded, size 12, AppColors.accent)`
- 필수 옵션임을 시각화

**`_UsageChip`** (subtitle 첫 줄):

- 기본: `'사용 중 {N}개'`, fontSize 12, `AppColors.textMuted`
- N=0: `'사용 없음'`, fontSize 12, `AppColors.textMuted`
- loading 중: 너비 60, 높이 12 shimmer bar (`AppColors.surface` → `AppColors.surfaceElevated`)
- 에러: `'-'`, fontSize 12, `AppColors.textMuted`

**`_ItemCountChip`** (subtitle 두 번째 줄):

- `'항목 {N}개'`, fontSize 12, `AppColors.textMuted`
- N=0: `'항목 없음'`, fontSize 12, `AppColors.warning`

**`OptionGroupActiveSwitch`**:

- `Switch.adaptive`
- active=true: `AppColors.primary` (thumbColor), `AppColors.primaryBright` alpha 0.3 (trackColor)
- active=false: `AppColors.textMuted` (thumbColor), `AppColors.surface` (trackColor)
- onChanged:
  - true → false: 즉시 `ToggleOptionGroupActiveUseCase(scope, id, false)` 호출
  - false → true: 즉시 `ToggleOptionGroupActiveUseCase(scope, id, true)` 호출
  - 피드백: SnackBar `'옵션 그룹을 비활성화했어요'` / `'옵션 그룹을 활성화했어요'`
  - 실패: SnackBar `'처리에 실패했어요. 다시 시도해주세요'` + switch 원상복구

**PopupMenuButton**:

- 아이콘: `Icons.more_vert_rounded`, size 20, `AppColors.textMuted`
- 항목:
  - `'편집'` — `Navigator.push → BrandOptionGroupFormPage(editItem: entity)`
  - `'삭제'` — `OptionGroupDeleteDialog` 노출

#### FAB

| 속성 | 값 |
|---|---|
| 배경 | `AppColors.primary` |
| 아이콘 | `Icons.add_rounded`, `AppColors.onPrimary`, size 24 |
| shadow | `AppColors.primary` alpha 0.3, blurRadius 8, offset (0, 4) |
| onTap | `Navigator.push → BrandOptionGroupFormPage(editItem: null, brandId: brandId)` |
| 위치 | 우하단 (기본 floatingActionButton) |

#### 인터랙션 상세

| 동작 | 반응 |
|---|---|
| ListTile 탭 | `BrandOptionGroupFormPage(editItem: entity)` push |
| Switch 탭 (true→false) | 즉시 비활성화. SnackBar `'옵션 그룹을 비활성화했어요'` |
| Switch 탭 (false→true) | 즉시 활성화. SnackBar `'옵션 그룹을 활성화했어요'` |
| Switch 토글 실패 | SnackBar `'처리에 실패했어요. 다시 시도해주세요'` + switch 원상복구 |
| PopupMenu '편집' | `BrandOptionGroupFormPage(editItem: entity)` push |
| PopupMenu '삭제' | `OptionGroupDeleteDialog(entity: entity)` 표시 |
| FAB '+' 탭 | `BrandOptionGroupFormPage(editItem: null)` push |

---

### A2 상태별 UI

#### Loading

- 4개 shimmer `OptionGroupListItem` skeleton
- skeleton 구성:
  ```
  Card
    └─ ListTile
         ├─ leading: Container(36×36, radius 8) — shimmer
         ├─ title: Container(너비 120, 높이 14) — shimmer
         └─ subtitle: Column
              ├─ Container(너비 64, 높이 10) — shimmer
              └─ Container(너비 48, 높이 10) — shimmer
  ```
- shimmer base: `AppColors.surface`, highlight: `AppColors.surfaceElevated`

#### Error

```
Center
  └─ Column (mainAxisSize: min, spacing: 12)
       ├─ Icon(Icons.error_outline_rounded, size 48, AppColors.error)
       ├─ Text('옵션 그룹 목록을 불러오지 못했어요', fontSize 16, w600, AppColors.textHeading)
       ├─ Text('잠시 후 다시 시도해주세요', fontSize 13, AppColors.textMuted)
       └─ TextButton('다시 시도', AppColors.primary)
```

#### Empty

```
Center
  └─ Column (mainAxisSize: min, spacing: 12)
       ├─ Icon(Icons.tune_outlined, size 48, AppColors.textMuted)
       ├─ Text('등록된 옵션 그룹이 없어요', fontSize 16, w600, AppColors.textHeading)
       ├─ Text('아래 버튼으로 첫 옵션 그룹을 추가해보세요', fontSize 13, AppColors.textMuted)
       └─ (FAB 가 이미 표시되므로 별도 CTA 버튼 불필요)
```

---

### A3. BrandOptionGroupFormPage

- 파일: `lib/presentation/brand/option_groups/brand_option_group_form_page.dart`
- 역할: 등록 / 수정 통합 폼. `editItem: OptionGroupEntity?` 로 분기. brandId 컨텍스트 필수.

#### 레이아웃

```
Scaffold
  ├─ AppBar
  └─ body: SingleChildScrollView
              └─ Padding(horizontal 20, vertical 24)
                   └─ Column (spacing: 20)
                        ├─ [섹션] 이름 입력 (중복 검증 포함)
                        ├─ [섹션] 선택 타입 (single / multi)
                        ├─ [섹션] 필수 여부
                        ├─ [섹션] 정렬 순서
                        ├─ [섹션] 활성화 스위치
                        ├─ [섹션] 옵션 항목 목록 (OptionItemListEditor)
                        ├─ SizedBox(height: 16)
                        └─ [버튼 Row] 취소 / 저장
```

#### AppBar

| 속성 | 값 |
|---|---|
| leading | `Icons.arrow_back_ios_new_rounded` |
| title | 등록: `'옵션 그룹 추가'` / 수정: `'옵션 그룹 수정'` |
| titleTextStyle | fontSize 17, w700, `AppColors.textHeading` |
| backgroundColor | `AppColors.background` |
| elevation | 0 |

#### 섹션 스타일 공통 (`_FormSection`)

sub-phase 8/9 `_FormSection` 패턴 동일:

```
Column (crossAxisAlignment: start, spacing: 6)
  ├─ Text(라벨, fontSize 12, w600, AppColors.textMuted)
  └─ [입력 위젯]
```

#### 이름 입력 섹션

- 라벨: `'옵션 그룹 이름'`
- `TextFormField`
  - hint: `'예: 샷 추가, 시럽 선택, 사이즈'`
  - maxLength: 30 (counter 표시: true)
  - 배경: `AppColors.surfaceElevated`
  - border: `AppColors.border` → 포커스: `AppColors.primary`
  - 텍스트: `AppColors.textBody`
  - errorStyle: `AppColors.error`
  - helperText: `'최대 30자'`, fontSize 11, `AppColors.textMuted`
  - 유효성: 비어있으면 `'이름을 입력해주세요'`
- **중복 검증 inline 에러 영역** (디바운스 300ms):
  - 조회 중: helperText 영역에 `CircularProgressIndicator(size: 12, color: AppColors.primary)` + `' 확인 중...'`, fontSize 11, `AppColors.textMuted`
  - 중복 없음: helperText 영역 `'사용 가능한 이름이에요'`, fontSize 11, `AppColors.success` (1~2초 후 helperText 로 복귀)
  - 중복 있음: errorText `'이미 같은 이름의 옵션 그룹이 있어요'`, fontSize 11, `AppColors.error`

#### 선택 타입 섹션

- 라벨: `'선택 타입'`
- `SegmentedButton` 또는 두 개의 칩으로 구성

```
Row (spacing: 8)
  ├─ _TypeChip('단일 선택', OptionSelectionType.single)
  └─ _TypeChip('다중 선택', OptionSelectionType.multi)
```

**`_TypeChip` 선택됨**:

| 속성 | 값 |
|---|---|
| 배경 | `AppColors.primary` |
| 텍스트 | `AppColors.onPrimary`, fontSize 13, w600 |
| icon | single: `Icons.radio_button_checked_rounded` / multi: `Icons.check_box_rounded`, `AppColors.onPrimary`, size 16 |
| borderRadius | 10 |
| padding | horizontal 16, vertical 12 |
| height | 44 |

**`_TypeChip` 선택 안 됨**:

| 속성 | 값 |
|---|---|
| 배경 | `AppColors.surfaceElevated` |
| border | `AppColors.border` 1px |
| 텍스트 | `AppColors.textBody`, fontSize 13, w500 |
| icon | single: `Icons.radio_button_unchecked_rounded` / multi: `Icons.check_box_outline_blank_rounded`, `AppColors.textMuted`, size 16 |
| borderRadius | 10 |
| padding | horizontal 16, vertical 12 |
| height | 44 |

- helperText: `'단일: 하나만 선택 (라디오) / 다중: 여러 개 선택 가능 (체크박스)'`, fontSize 11, `AppColors.textMuted`

#### 필수 여부 섹션

```
Row (mainAxisAlignment: spaceBetween)
  ├─ Column (crossAxisAlignment: start, spacing: 2)
  │    ├─ Text('필수 옵션', fontSize 15, w500, AppColors.textBody)
  │    └─ Text('고객이 반드시 선택해야 주문 가능해요', fontSize 12, AppColors.textMuted)
  └─ Switch.adaptive
       ├─ active: AppColors.primary (thumbColor), AppColors.primaryBright alpha 0.3 (trackColor)
       └─ inactive: AppColors.textMuted (thumbColor), AppColors.surface (trackColor)
```

#### 정렬 순서 섹션

- 라벨: `'정렬 순서'`
- `TextFormField`
  - hint: `'0, 1, 2 ...'`
  - keyboardType: `TextInputType.number`
  - inputFormatters: 0 이상 정수만 허용
  - 배경: `AppColors.surfaceElevated`
  - border: `AppColors.border` → 포커스: `AppColors.primary`
  - helperText: `'숫자가 낮을수록 앞에 표시돼요'`, fontSize 11, `AppColors.textMuted`
  - 유효성: 비어있으면 기본값 0 적용 (빈칸으로 저장 가능)

#### 활성화 스위치 섹션

```
Row (mainAxisAlignment: spaceBetween)
  ├─ Column (crossAxisAlignment: start, spacing: 2)
  │    ├─ Text('활성화', fontSize 15, w500, AppColors.textBody)
  │    └─ Text('비활성화 시 메뉴 폼과 고객 화면에서 숨겨져요', fontSize 12, AppColors.textMuted)
  └─ Switch.adaptive (동일 패턴)
```

#### 옵션 항목 섹션

- 라벨: `'옵션 항목'`
- 하단 명세 E (`OptionItemListEditor`) 위젯을 이 섹션에 삽입

#### 버튼 Row

```
Row (spacing: 12)
  ├─ Expanded — OutlinedButton '취소'
  └─ Expanded — ElevatedButton '저장'
```

**취소 버튼**:

| 속성 | 값 |
|---|---|
| 배경 | `AppColors.surfaceElevated` |
| border | `AppColors.border` |
| 텍스트 | `AppColors.textBody`, fontSize 15, w600 |
| borderRadius | 12 |
| height | 52 |
| onTap | `Navigator.pop` |

**저장 버튼**:

| 속성 | 값 |
|---|---|
| 배경 | `AppColors.primary` |
| 텍스트 | `AppColors.onPrimary`, fontSize 15, w600 |
| borderRadius | 12 |
| height | 52 |
| disabled 조건 | 폼 유효성 불통과 또는 중복 이름 에러 또는 label 중복 에러 |
| disabled 스타일 | `AppColors.surface` 배경, `AppColors.textMuted` 텍스트 |
| loading 중 | `CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2)` 텍스트 대체 |

#### 저장 성공/실패 피드백

| 케이스 | 피드백 |
|---|---|
| 등록 성공 | SnackBar `'옵션 그룹을 추가했어요'` + `Navigator.pop` |
| 수정 성공 | SnackBar `'옵션 그룹을 수정했어요'` + `Navigator.pop` |
| 실패 (중복 이름 race) | SnackBar `'이미 같은 이름의 옵션 그룹이 있어요. 다른 이름을 사용해주세요'` (폼 유지) |
| 실패 (label 중복) | SnackBar `'같은 이름의 항목이 있어요. 확인 후 다시 저장해주세요'` (폼 유지) |
| 실패 (네트워크) | SnackBar `'처리에 실패했어요. 다시 시도해주세요'` (폼 유지) |

---

### A4. OptionGroupDeleteDialog (brand / owner 공통)

- 파일: `lib/presentation/common/widgets/option_groups/option_group_delete_dialog.dart`
- 역할: 옵션 그룹 삭제 확인. 사용 중 여부에 따라 분기. brand/owner 양쪽에서 재사용.
- sub-phase 8 `SubCategoryDeleteDialog` 패턴 동일.

#### 다이얼로그 공통 스타일

```
Dialog
  └─ Container
       ├─ decoration: radius 16, background AppColors.surfaceElevated
       ├─ padding: 24
       └─ Column (mainAxisSize: min, spacing: 16)
            ├─ [헤더 Row]
            ├─ [본문 — 케이스 분기]
            └─ [버튼 Row]
```

| 속성 | 값 |
|---|---|
| 배경 | `AppColors.surfaceElevated` |
| borderRadius | 16 |
| padding | 24 |
| barrierDismissible | true |

#### 헤더

```
Row (crossAxisAlignment: start)
  ├─ Icon(Icons.delete_outline_rounded, size 24, AppColors.error)
  ├─ SizedBox(width: 12)
  └─ Expanded
       └─ Column (crossAxisAlignment: start, spacing: 4)
            ├─ Text('옵션 그룹 삭제', fontSize 16, w700, AppColors.textHeading)
            └─ Text(entity.name, fontSize 13, AppColors.textMuted)
```

#### 본문 — 케이스 분기

**로딩 상태 (usageCount 조회 중)**:

```
Row (spacing: 8)
  ├─ SizedBox(16×16) — CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)
  └─ Text('사용 여부 확인 중...', fontSize 13, AppColors.textMuted)
```

**케이스 1: 사용 중 (usageCount >= 1) — 삭제 차단**

```
Column (spacing: 12)
  ├─ Container (background: AppColors.error alpha 0.08, radius 10, padding 14)
  │    └─ Text
  │         '이 옵션 그룹을 사용 중인 메뉴가 {N}개 있어요.\n메뉴에서 먼저 제거해주세요.'
  │         fontSize 13, AppColors.textBody
  └─ Text
       '옵션 그룹을 숨기려면 비활성화를 사용하세요.'
       fontSize 12, AppColors.textMuted
```

**케이스 2: 사용 없음 (usageCount == 0) — 삭제 가능**

```
Text
  '이 옵션 그룹을 삭제할까요? 삭제 후에는 되돌릴 수 없어요.'
  fontSize 13, AppColors.textBody
```

#### 버튼 Row

**케이스 1 (차단)**:

```
Row (spacing: 12)
  ├─ Expanded — OutlinedButton '취소'
  └─ Expanded — ElevatedButton '비활성으로 전환' (AppColors.warning 배경, AppColors.onPrimary 텍스트)
```

"비활성으로 전환" 탭 시: 다이얼로그 닫고 → `ToggleOptionGroupActiveUseCase(scope, id, false)` 직접 호출 (재확인 다이얼로그 없음 — 삭제 의도에서 비활성화로 전환하는 흐름).

**케이스 2 (삭제 가능)**:

```
Row (spacing: 12)
  ├─ Expanded — OutlinedButton '취소'
  └─ Expanded — ElevatedButton '삭제' (AppColors.error 배경, AppColors.onPrimary 텍스트)
```

"삭제" 탭 시: `DeleteOptionGroupUseCase(scope, id, brandId?, storeId?)` 호출 → 성공 시 pop + SnackBar `'옵션 그룹을 삭제했어요'`

**버튼 공통 스타일**:

| 속성 | 취소 버튼 | 액션 버튼 |
|---|---|---|
| 배경 | `AppColors.surfaceElevated` | 케이스별 상이 |
| border | `AppColors.border` | 없음 |
| 텍스트 색 | `AppColors.textBody` | `AppColors.onPrimary` |
| fontSize | 14, w600 | 14, w600 |
| borderRadius | 10 | 10 |
| height | 44 | 44 |

**로딩 상태 버튼**: 두 버튼 모두 disabled (`AppColors.surface` 배경). 취소만 활성 유지하여 UX 차단 최소화.

> 디자이너 결정: "비활성으로 전환" 시 DeactivateConfirmDialog 를 다시 띄우지 않는다. sub-phase 8/9 패턴과 동일.

---

## 영역 B — owner 개인 매장 옵션 그룹 관리 화면

### B1. MyStorePage "메뉴 관리" 영역 — "옵션 그룹 관리" 진입 추가

기존 MyStorePage 의 "메뉴 관리" 섹션 안에 ListTile 형식 CTA 를 추가한다.

#### 추가 위치

"메뉴 관리" 섹션 내부, "분류 관리" CTA (sub-phase 8 기존) 아래:

```
"메뉴 관리" 섹션
  ├─ (기존) 메뉴 목록 / 등록 CTA
  ├─ (기존 sub-phase 8) _StoreTile '분류 관리'
  └─ [신규] _StoreTile '옵션 그룹 관리'  ← 추가
```

#### 신규 StoreTile 명세

기존 `_StoreTile` 위젯 그대로 재사용:

| 속성 | 값 |
|---|---|
| icon | `Icons.tune_rounded` |
| title | `'옵션 그룹 관리'` |
| subtitle | `'매장 전용 옵션을 추가하고 관리해요'` |
| onTap | `Navigator.push → OwnerStoreOptionGroupListPage(storeId: currentStoreId)` |
| trailing | `Icons.chevron_right_rounded` (size 18, `AppColors.textMuted`) |

> 진입 가드: `brandId == null` (개인 매장) + 본인 매장일 때만 노출. 가맹점(brandId != null) 점주에게는 미노출.

---

### B2. OwnerStoreOptionGroupListPage

- 파일: `lib/presentation/owner/option_groups/owner_store_option_group_list_page.dart`
- 역할: `stores/{storeId}/optionGroups/` 목록. A2 (`BrandOptionGroupListPage`) 와 동일 구조.

#### 레이아웃 / 컴포넌트

A2 와 동일. 아래 항목만 차이:

| 항목 | brand (A2) | owner (B2) |
|---|---|---|
| AppBar title | `'옵션 그룹 관리'` | `'옵션 그룹 관리'` (동일) |
| 데이터 provider | `brandOptionGroupsProvider({brandId})` | `ownerStoreOptionGroupsProvider({storeId})` |
| FAB onTap | `BrandOptionGroupFormPage(brandId)` | `OwnerStoreOptionGroupFormPage(storeId)` |
| ListTile onTap | `BrandOptionGroupFormPage(editItem)` | `OwnerStoreOptionGroupFormPage(editItem)` |
| 파일 경로 | `brand/option_groups/` | `owner/option_groups/` |

상태별 UI (Loading / Error / Empty) — A2 동일 카피 사용.

---

### B3. OwnerStoreOptionGroupFormPage

- 파일: `lib/presentation/owner/option_groups/owner_store_option_group_form_page.dart`
- 역할: owner 개인 매장 옵션 그룹 등록/수정. storeId 컨텍스트 필수.
- A3 (`BrandOptionGroupFormPage`) 와 동일 레이아웃 / 컴포넌트 / 카피.

| 항목 | brand (A3) | owner (B3) |
|---|---|---|
| AppBar title | `'옵션 그룹 추가'` / `'옵션 그룹 수정'` | 동일 |
| 중복 검증 scope | `scope=brand, brandId` | `scope=store, storeId` |
| 저장 UseCase | `UpsertOptionGroupUseCase(scope=brand)` | `UpsertOptionGroupUseCase(scope=store)` |

---

## 영역 C — 메뉴 폼 3종 OptionGroupSelector 갱신

### C1. OptionGroupSelector 위젯 공통 변경사항

기존 `OptionGroupSelector` 위젯의 섹션 헤더 카피 + 항목 노출 정책을 갱신한다.

#### 섹션 헤더 카피 (확정값)

| scope | 헤더 카피 |
|---|---|
| master | `'기본 옵션'` |
| brand | `'브랜드 옵션'` |
| store | `'매장 옵션'` |

#### 섹션 헤더 스타일

```
Padding(top: 16, bottom: 6, left: 4)
  └─ Text(헤더 카피, fontSize 12, w700, AppColors.primary)
```

#### inactive 옵션 그룹 — disabled marker (수정 모드 전용)

수정 모드에서 `editItem.optionGroupRefs` 에 inactive 그룹이 포함된 경우:

```
Stack
  └─ OptionGroupChip (disabled: true)
       └─ 우측 상단 소형 Container
            ├─ background: AppColors.warning alpha 0.12
            ├─ border: AppColors.warning alpha 0.5 / 1px
            ├─ radius: 6
            └─ Text('비활성', fontSize 9, w600, AppColors.warning)
```

비활성 옵션 그룹 칩:

| 속성 | 값 |
|---|---|
| 배경 | `AppColors.warning` alpha 0.08 |
| border | `AppColors.warning` alpha 0.4 / 1px |
| 텍스트 색 | `AppColors.warning` |
| alpha | 0.7 (dim) |
| onTap | 비선택으로만 전환 가능 (재선택 불가, 이미 선택된 상태로 표시하되 추가 선택 불가) |

비활성 marker 하단 경고 라벨 (칩 아래, 섹션 하단):

```
Padding(top: 8, left: 4)
  └─ Row (spacing: 4)
       ├─ Icon(Icons.warning_amber_rounded, size 12, AppColors.warning)
       └─ Text('이 옵션 그룹은 비활성화되었습니다.', fontSize 11, AppColors.warning)
```

#### 빈 상태 (해당 scope 에 옵션 그룹이 없는 경우)

```
Padding(vertical: 16)
  └─ Column (mainAxisSize: min, spacing: 8)
       ├─ Text('옵션 그룹이 없어요', fontSize 14, w500, AppColors.textBody)
       └─ Text('옵션 그룹 관리 화면에서 추가해보세요', fontSize 12, AppColors.textMuted)
```

- master scope 는 read-only 이므로 빈 상태 시 CTA 버튼 미표시.
- brand / store scope 빈 상태 시 진입 CTA 버튼 표시 (조건부):

```
TextButton.icon(
  icon: Icon(Icons.tune_rounded, size 14, AppColors.primaryBright),
  label: Text('옵션 그룹 관리', fontSize 12, AppColors.primaryBright),
  onTap: Navigator.push → 해당 scope 관리 페이지
)
```

---

### C2. MasterMenuFormPage — selector 갱신

- 파일: `lib/presentation/brand/master_menu/master_menu_form_page.dart`
- 변경: 기존 master scope 만 → `master ∪ brand` 머지 노출.
- provider: `selectorOptionGroupsProvider({brandId: profile.brandId, scopes: {master, brand}})`
- 섹션 헤더: "기본 옵션" (master) + "브랜드 옵션" (brand) 두 섹션으로 분리 표시.
- 수정 모드 inactive 처리: 기존 편집 아이템의 optionGroupRefs 중 inactive 그룹 → disabled marker.

---

### C3. BrandStoreOnlyMenuFormPage — selector 신규 통합

- 파일: `lib/presentation/brand/store_only_menu/brand_store_only_menu_form_page.dart`
- 변경: **selector 가 통합되지 않은 상태** → 본 phase 에서 신규 통합.
- provider: `selectorOptionGroupsProvider({brandId: profile.brandId, scopes: {master, brand}})`
- 섹션 헤더: "기본 옵션" (master) + "브랜드 옵션" (brand).
- 기존 `optionGroupRefs` 보존값은 prefill 로 처리.

---

### C4. OwnerStoreMenuFormPage — selector 갱신

- 파일: `lib/presentation/owner/store_menu/owner_store_menu_form_page.dart`
- 변경: 기존 `master ∪ store` 머지 유지. scope 헤더 카피만 갱신.
- 섹션 헤더: "기본 옵션" (master) + "매장 옵션" (store).
- 수정 모드 inactive 처리: 동일.

---

## 영역 D — customer 옵션 시트 fetch 정책 회귀

- `MenuItemDetailPage` / `MenuOptionDisableSheet` — **시각 변경 없음**.
- read 정책 갱신 (코드 레벨): `optionGroupsForMenuItemProvider` 에 `brandId` 파라미터 추가.
- 매장 컨텍스트 자동 머지:
  - 가맹점(brandId != null): `master ∪ brand` fetch
  - 개인 매장(brandId == null): `master ∪ store` fetch
- UI 출력: 정상 노출만 보장. 디자인 변경사항 없음.
- inactive 옵션 그룹은 자연 제외 (`active=true` 만 표시).

---

## 영역 E — OptionItemListEditor 핵심 위젯

- 파일: `lib/presentation/common/widgets/option_groups/option_item_list_editor.dart`
- 역할: 한 옵션 그룹 내 항목(OptionItemEntity) 목록을 동적으로 추가/삭제/편집하는 위젯.
- spec 확정: drag-drop reordering 은 Follow-up F3 (비범위).

### 전체 구조

```
Column (crossAxisAlignment: stretch, spacing: 0)
  ├─ [항목 0] _OptionItemRow
  ├─ [항목 1] _OptionItemRow
  ├─ ...
  ├─ _ItemDivider (항목 간 구분선)
  ├─ _EmptyState (항목 0개일 때만)
  └─ _AddItemButton ('+ 항목 추가' 버튼)
```

### E1. 빈 상태 (`_EmptyState`) — 항목 0개

```
Container (padding: vertical 16, margin: vertical 8)
  └─ Column (mainAxisSize: min, spacing: 8, horizontal center)
       ├─ Icon(Icons.list_alt_rounded, size 32, AppColors.textMuted)
       └─ Text('아직 옵션 항목이 없어요', fontSize 13, AppColors.textMuted)
```

### E2. `_OptionItemRow` — 항목 1개

```
Padding(vertical: 8)
  └─ Row (crossAxisAlignment: center, spacing: 8)
       ├─ Expanded(flex: 3) — label 입력창
       ├─ SizedBox(width: 8)
       ├─ _PriceDeltaField — priceDelta 입력 영역
       ├─ SizedBox(width: 4)
       └─ IconButton(Icons.delete_outline_rounded, size 20, AppColors.error alpha 0.7)
```

#### label 입력창

- `TextFormField`
  - hint: `'항목 이름'`
  - maxLength: 20 (counter 표시: false — 공간 절약)
  - 배경: `AppColors.surfaceElevated`
  - border: `AppColors.border` 1px, radius 10 → 포커스: `AppColors.primary` 1.5px
  - 텍스트: `AppColors.textBody`, fontSize 14
  - hint 색: `AppColors.textMuted`
  - contentPadding: horizontal 12, vertical 10
- **label 중복 inline 에러**:
  - 중복 감지(같은 그룹 내): 해당 입력창 border `AppColors.error` 1.5px + 아이콘 우측에 `Icon(Icons.error_outline_rounded, size 14, AppColors.error)`
  - 에러 라벨: 입력창 바로 아래 `Text('같은 이름의 항목이 있어요', fontSize 11, AppColors.error)`
  - 중복 판정: client-side. normalize(label.trim().toLowerCase()) 비교. 실시간 (onChanged).

#### `_PriceDeltaField` — priceDelta 음수 허용 입력 UX

핵심 디자인 결정: **부호 토글 버튼 + 숫자 입력창 + 단위 텍스트** 조합.

```
Row (crossAxisAlignment: center, spacing: 4)
  ├─ _SignToggleButton ('+' / '-')
  ├─ SizedBox(width 4)
  ├─ SizedBox(width: 72) — 숫자 입력창
  └─ Text('원', fontSize 13, w500, AppColors.textMuted)
```

**`_SignToggleButton`**:

| 속성 | 양수(+) 상태 | 음수(-) 상태 |
|---|---|---|
| 배경 | `AppColors.success` alpha 0.12 | `AppColors.error` alpha 0.12 |
| border | `AppColors.success` alpha 0.5 / 1px | `AppColors.error` alpha 0.5 / 1px |
| 텍스트 | `'+'`, fontSize 15, w700, `AppColors.success` | `'-'`, fontSize 15, w700, `AppColors.error` |
| size | 32×32 |
| radius | 8 |
| onTap | 부호 토글 (양수 ↔ 음수 전환) |
| 피드백 | 탭 시 배경 잠시 더 진하게 (InkWell splash) |

> 초기 상태: '+' (양수). priceDelta 편집 시 기존 값에서 부호 복원.

**숫자 입력창**:

- `TextFormField`
  - hint: `'0'`
  - keyboardType: `TextInputType.number`
  - inputFormatters: 0 이상 정수만 허용 (음수는 부호 토글로 처리하므로 숫자 입력창은 절댓값만)
  - 배경: `AppColors.surfaceElevated`
  - border: `AppColors.border` 1px, radius 10 → 포커스: `AppColors.primary` 1.5px
  - 텍스트: `AppColors.textBody`, fontSize 14, 우측 정렬
  - contentPadding: horizontal 10, vertical 10
  - width: 72px (SizedBox 감쌈)

**단위 텍스트**:

- `'원'`, fontSize 13, w500, `AppColors.textMuted`

**priceDelta 표현 규칙**:

| 부호 | 숫자 값 | 최종 priceDelta | 표시 (목록/selector에서) |
|---|---|---|---|
| + | 500 | +500 | `'+500원'` |
| - | 500 | -500 | `'-500원'` |
| + 또는 - | 0 | 0 | `'0원'` (무료) |

> priceDelta = 0 일 때는 부호 무관 0 으로 저장. 부호 토글 상태 유지하되 저장값은 0.

**priceDelta 표시 위젯 (목록/selector 에서)** — `_PriceDeltaLabel`:

- `'+500원'`: fontSize 12, w600, `AppColors.success`
- `'-500원'`: fontSize 12, w600, `AppColors.error`
- `'0원'`: fontSize 12, w500, `AppColors.textMuted`

#### 삭제 버튼

- `IconButton(icon: Icons.delete_outline_rounded, color: AppColors.error alpha 0.7, size: 20)`
- 탭 시: 해당 항목 즉시 목록에서 제거 (undo 없음)
- 항목이 1개 남았을 때도 삭제 가능 (0개 허용)

### E3. `_AddItemButton` — '+ 항목 추가' 버튼

```
TextButton.icon(
  icon: Icon(Icons.add_circle_outline_rounded, size 16, AppColors.primary),
  label: Text('항목 추가', fontSize 13, w600, AppColors.primary),
  style: 배경 AppColors.primary alpha 0.06, radius 10, padding horizontal 16 vertical 10
  onTap: items list 에 새 빈 OptionItemEntity 추가 (id 자동 생성, label: '', priceDelta: 0)
)
```

- 위치: 항목 목록 하단 고정.
- 최대 항목 수 제한 없음 (spec 미정의). 단, 화면 스크롤로 처리.

### E4. 인터랙션 상세

| 동작 | 반응 |
|---|---|
| '+ 항목 추가' 탭 | 목록 최하단에 새 빈 row 추가. 새 row 의 label 입력창 자동 포커스. |
| 부호 토글 탭 | '+' ↔ '-' 전환. 입력창 값 유지. priceDelta 부호만 전환. |
| label 입력 | 같은 그룹 내 normalize 비교 → 중복이면 즉시 inline 에러 표시. |
| 숫자 입력 | 절댓값만 허용. priceDelta = 부호 × 숫자. |
| 삭제 버튼 탭 | 해당 row 즉시 제거. 나머지 label 중복 검사 재실행. |
| 항목 0개 상태 | `_EmptyState` 표시. '+ 항목 추가' 버튼 유지. |

> cascade reset 없음. 옵션 그룹은 메인 카테고리 종속이 없으므로 항목 변경이 다른 필드를 리셋하지 않는다.

---

## 검증 카피 확정값

| 위치 | 카피 |
|---|---|
| 이름 입력 — 중복 inline 에러 | `'이미 같은 이름의 옵션 그룹이 있어요'` |
| 이름 입력 — 확인 중 | `'확인 중...'` |
| 이름 입력 — 사용 가능 | `'사용 가능한 이름이에요'` |
| label 입력 — 중복 inline 에러 | `'같은 이름의 항목이 있어요'` |
| DeleteDialog — 사용 중 차단 본문 | `'이 옵션 그룹을 사용 중인 메뉴가 {N}개 있어요.\n메뉴에서 먼저 제거해주세요.'` |
| DeleteDialog — 사용 중 차단 부연 | `'옵션 그룹을 숨기려면 비활성화를 사용하세요.'` |
| DeleteDialog — 삭제 가능 본문 | `'이 옵션 그룹을 삭제할까요? 삭제 후에는 되돌릴 수 없어요.'` |
| DeleteDialog — 비활성 전환 버튼 | `'비활성으로 전환'` |
| selector — inactive marker 경고 | `'이 옵션 그룹은 비활성화되었습니다.'` |
| selector — 빈 상태 | `'옵션 그룹이 없어요'` |
| selector — 빈 상태 부연 | `'옵션 그룹 관리 화면에서 추가해보세요'` |
| Switch 비활성화 SnackBar | `'옵션 그룹을 비활성화했어요'` |
| Switch 활성화 SnackBar | `'옵션 그룹을 활성화했어요'` |
| Switch 실패 SnackBar | `'처리에 실패했어요. 다시 시도해주세요'` |
| 등록 성공 SnackBar | `'옵션 그룹을 추가했어요'` |
| 수정 성공 SnackBar | `'옵션 그룹을 수정했어요'` |
| 삭제 성공 SnackBar | `'옵션 그룹을 삭제했어요'` |
| 메뉴 폼 empty (brand/store) | `'옵션 그룹 없음 — 옵션 없이 등록 가능'` |

---

## 인터랙션 요약표

| 영역 | 동작 | 반응 |
|---|---|---|
| ListPage | ListTile 탭 | FormPage(editItem) push |
| ListPage | Switch 토글 | ToggleUseCase 즉시 호출 + SnackBar |
| ListPage | PopupMenu '편집' | FormPage(editItem) push |
| ListPage | PopupMenu '삭제' | DeleteDialog 표시 |
| ListPage | FAB 탭 | FormPage(editItem: null) push |
| FormPage | 이름 onChanged | 300ms 디바운스 → 중복 lookup → inline 에러 or 성공 |
| FormPage | 선택 타입 칩 탭 | selectionType 전환 |
| FormPage | 필수/활성 Switch | 즉시 상태 전환 |
| FormPage | 저장 탭 | UpsertUseCase → 성공: pop + SnackBar / 실패: 폼 유지 + SnackBar |
| FormPage | 취소 탭 | Navigator.pop |
| DeleteDialog | 사용 중 — '비활성으로 전환' 탭 | 다이얼로그 닫기 + ToggleActive(false) |
| DeleteDialog | 사용 없음 — '삭제' 탭 | DeleteUseCase → pop + SnackBar |
| OptionItemListEditor | '+ 항목 추가' 탭 | 새 row 추가 + 자동 포커스 |
| OptionItemListEditor | 부호 토글 탭 | 부호 전환 (cascade reset 없음) |
| OptionItemListEditor | label onChanged | client-side 중복 검사 → inline 에러 |
| OptionItemListEditor | 삭제 버튼 탭 | 해당 row 즉시 제거 |
| selector | inactive 칩 탭 | 선택 해제만 가능 (재선택 차단) |

---

## 상태별 UI 요약

### Loading

| 위치 | 표시 방식 |
|---|---|
| ListPage body | 4개 shimmer OptionGroupListItem skeleton |
| _UsageChip | 너비 60, 높이 12 shimmer bar |
| DeleteDialog 조회 중 | spinner + `'사용 여부 확인 중...'` |
| selector 로딩 | shimmer pill 3개 |

shimmer: base `AppColors.surface`, highlight `AppColors.surfaceElevated`

### Error

| 위치 | 표시 방식 |
|---|---|
| ListPage | Center Column — error 아이콘 + 설명 + 재시도 버튼 |
| FormPage 저장 실패 | SnackBar (폼 유지) |
| _UsageChip 에러 | `'-'` 텍스트 |

재시도: `TextButton('다시 시도', AppColors.primary)` → provider invalidate.

### Empty

| 위치 | 표시 방식 |
|---|---|
| ListPage | Center Column — 아이콘 + 안내 문구 (FAB 별도 표시) |
| OptionItemListEditor | `_EmptyState` — 아이콘 + 안내 문구 |
| selector (scope 별) | 빈 상태 텍스트 + (brand/store) 진입 CTA |

---

## Figma 대비 변경사항

| 항목 | 기존 / Figma | Qradar 적용 |
|---|---|---|
| Figma 레퍼런스 | 없음 (신규 화면) | Qradar 디자인 시스템 + sub-phase 8/9 패턴 |
| priceDelta 입력 방식 | 미정 | 부호 토글 버튼 + 절댓값 숫자 입력 + '원' 단위 |
| 음수 priceDelta 표시 | 미정 | `AppColors.error` 텍스트 (`'-500원'`) |
| 양수 priceDelta 표시 | 미정 | `AppColors.success` 텍스트 (`'+500원'`) |
| 섹션 헤더 카피 | "마스터 옵션" / "매장 옵션" | "기본 옵션" / "브랜드 옵션" / "매장 옵션" |

---

## 개발자 전달 특이사항

### 1. 공통 위젯 추출 — `presentation/common/widgets/option_groups/`

아래 위젯은 brand / owner 양쪽에서 재사용하므로 공통 위젯 디렉토리에 만든다:

| 위젯 파일 | 역할 |
|---|---|
| `option_group_list_item.dart` | OptionGroupListItem (card + listTile 조합) |
| `option_group_delete_dialog.dart` | OptionGroupDeleteDialog |
| `option_group_active_switch.dart` | OptionGroupActiveSwitch |
| `option_item_list_editor.dart` | OptionItemListEditor (본 phase 핵심 신규 위젯) |

`OptionGroupListItem` 은 brand/owner 의 Provider 만 달리 주입하면 동일 UI 사용 가능.

### 2. OptionItemListEditor — priceDelta 음수 허용 구현 주의사항

- 숫자 입력창은 `TextInputType.number` + `FilteringTextInputFormatter.digitsOnly` (양수만 입력).
- priceDelta 실제 저장값 = 부호 상태 × 숫자 입력값. 부호는 별도 `bool isNegative` 상태 변수로 관리.
- priceDelta == 0 이면 부호 토글 상태 무관하게 0 으로 저장 (음수 0 없음).
- 수정 모드 prefill: `entity.priceDelta < 0` 이면 `isNegative = true` + 입력창 값 = `entity.priceDelta.abs()`.
- `_PriceDeltaLabel` 은 별도 위젯으로 추출하여 OptionGroupSelector 칩 내부에도 재사용.

### 3. sub-phase 8/9 패턴 차용 여부

| 패턴 | 차용 여부 | 비고 |
|---|---|---|
| DeleteDialog (사용 중 차단 + 비활성 전환) | 차용 | OptionGroupDeleteDialog |
| active Switch 토글 (즉시 반영) | 차용 | OptionGroupActiveSwitch |
| FormSection 레이아웃 | 차용 | _FormSection |
| _OrderBadge | 차용 | displayOrder 표시 |
| _UsageChip | 차용 (확장) | 사용 중 N개 — countUsage provider |
| 중복 이름 dibaounce + inline 에러 | 차용 | 300ms debounce |
| 저장 버튼 loading / disabled 스타일 | 차용 | 동일 |

### 4. BrandStoreOnlyMenuFormPage selector 신규 통합

- 현재 `optionGroupRefs` 보존만 — 본 phase 에서 `OptionGroupSelector` 위젯 신규 통합.
- 기존 `editItem?.optionGroupRefs ?? []` prefill 유지하면서 selector UI 추가.
- MasterMenuFormPage 와 동일 `master ∪ brand` 머지 provider 사용.

### 5. S2 검증 갱신

- `MasterMenuItemRepositoryImpl` / `BrandStoreOnlyMenuRepositoryImpl`: `master ∪ brand` 허용, `store` 차단.
- `OwnerStoreMenuRepositoryImpl`: `master ∪ store` 허용, `brand` 차단 (단, 개인 매장 컨텍스트).
- 각 repository 의 `_validateOptionGroupScope` 메서드 갱신.

### 6. OptionGroupSelector 섹션 헤더 카피 교체

기존 `'마스터 옵션'` → `'기본 옵션'`, `'매장 옵션'` 유지, `'브랜드 옵션'` 신규 추가.
헤더 카피는 `OptionScope` enum 확장에 맞춰 switch-case 로 처리.

### 7. AppColors 토큰 요약

| 용도 | 토큰 |
|---|---|
| 양수 priceDelta 표시 | `AppColors.success` |
| 음수 priceDelta 표시 | `AppColors.error` |
| 0원 priceDelta 표시 | `AppColors.textMuted` |
| inactive 옵션 그룹 border/텍스트 | `AppColors.warning` |
| single 타입 badge | `AppColors.info` |
| multi 타입 badge | `AppColors.primary` |
| required marker 아이콘 | `AppColors.accent` |
| 부호 '+' 버튼 | `AppColors.success` alpha 계열 |
| 부호 '-' 버튼 | `AppColors.error` alpha 계열 |

### 8. 후속 작업 (Follow-up)

| Follow-up | 내용 |
|---|---|
| F3 | OptionItemListEditor drag-drop reordering |
| F4 | 옵션 항목 단위 active toggle |
| F5 | 옵션 그룹 변경 시 가맹점 알림 |
| F6 | legacy master 시드 폐기 마이그레이션 |
| F7 | 오타/유사명 자동 감지 |
| F10 | applicableMainCategories 자동 필터 |
| F11 | admin 옵션 그룹 분포 audit 모니터링 |
