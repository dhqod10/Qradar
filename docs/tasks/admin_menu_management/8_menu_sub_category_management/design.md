# sub-phase 8 — menu_sub_category_management 디자인 명세

> **상태**: DRAFT — 2026-05-03
>
> **spec.md 기준**: `docs/tasks/admin_menu_management/8_menu_sub_category_management/spec.md` (APPROVED, 결정 1~7 + 검증 정책 옵션 2 확정)

---

## 참조한 디자인

- Figma: 없음 (Qradar 디자인 시스템 + 기존 화면 톤 기반 신규 설계)
- 기존 화면 레퍼런스:
  - `docs/tasks/admin_menu_management/9_menu_main_category_admin/design.md` — list/form/dialog 컴포넌트 패턴 전면 차용
  - `lib/presentation/brand/more/brand_more_page.dart` — `_Tile` 패턴 재사용
  - `lib/presentation/owner/my_store/my_store_page.dart` — "메뉴 관리" 영역 CTA 패턴 참조
  - `lib/presentation/brand/master_menu/master_menu_form_page.dart` — 카테고리 칩 위치/스타일 참조
- 색상 토큰: `lib/core/theme/app_colors.dart`

---

## 전체 화면 목록

| 영역 | 화면 / 컴포넌트 | 유형 |
|---|---|---|
| A1 | BrandMorePage — "서브 카테고리 관리" ListTile 추가 | 기존 화면 수정 |
| A2 | BrandSubCategoryListPage | 신규 |
| A3 | BrandSubCategoryFormPage | 신규 |
| A4 | SubCategoryDeleteDialog (brand/owner 공통) | 신규 |
| B1 | MyStorePage "메뉴 관리" 영역 — "분류 관리" 진입 CTA 추가 | 기존 화면 수정 |
| B2 | OwnerStoreSubCategoryListPage | 신규 |
| B3 | OwnerStoreSubCategoryFormPage | 신규 |
| C | 메뉴 폼 3종 sub-category 칩 영역 추가 (SubCategoryChipsSelector) | 기존 화면 수정 |
| D | 가맹점 점주 read-only 정책 (미노출) | 정책 명세 (시각 작업 없음) |
| E | 검증 inline 에러 / dialog 카피 | 카피 명세 |

---

## 영역 A — brand 본사 서브 카테고리 관리 화면

### A1. BrandMorePage — "서브 카테고리 관리" ListTile 추가

기존 `brand_more_page.dart` 의 `ListView` 에 타일 1개를 추가한다.

#### 추가 위치

"메인 카테고리 관리" tile 이 존재하면 그 바로 아래. 없으면 운영 기능 그룹 최상단.

```
ListView
  ├─ Padding(fromLTRB 20,4,20,16) — "더보기" 제목
  ├─ _Tile '메인 카테고리 관리'  (sub-phase 9 기존)
  ├─ [신규] _Tile '서브 카테고리 관리'  ← 추가
  ├─ _Tile '로그아웃'
  └─ _Tile '앱 정보'
```

#### 신규 Tile 명세

기존 `_Tile` 위젯 그대로 재사용:

| 속성 | 값 |
|---|---|
| icon | `Icons.label_rounded` |
| title | `'서브 카테고리 관리'` |
| subtitle | `null` |
| onTap | `Navigator.push → BrandSubCategoryListPage(brandId: currentBrandId)` |
| trailing | `Icons.chevron_right_rounded` (size 18, `AppColors.textMuted`) |

> 진입 가드: 현재 사용자가 brand 본사(역할: brandHq)일 때만 이 타일을 노출. 가맹점 점주(brandAffiliate)에게는 미노출.

---

### A2. BrandSubCategoryListPage

- 파일: `lib/presentation/brand/menu_categories/brand_sub_category_list_page.dart`
- 역할: `brands/{brandId}/subCategories/` 목록. mainCategoryCode 별 섹션 그룹핑. displayOrder asc 정렬. active 토글 / 편집 / 삭제.

#### 레이아웃

```
Scaffold
  ├─ AppBar
  ├─ body: Column
  │         ├─ _MainCategoryFilterChips (상단 고정 칩 필터 바)
  │         └─ Expanded — ListView (섹션 or 필터 결과)
  └─ floatingActionButton: FAB
```

#### AppBar

| 속성 | 값 |
|---|---|
| leading | `Icons.arrow_back_ios_new_rounded`, `AppColors.textBody` |
| title | `'서브 카테고리 관리'` |
| titleTextStyle | fontSize 17, w700, `AppColors.textHeading` |
| backgroundColor | `AppColors.background` |
| surfaceTintColor | `Colors.transparent` |
| elevation | 0 |
| actions | 없음 |

#### 메인 카테고리 필터 칩 바 (`_MainCategoryFilterChips`)

- 위치: AppBar 직하, body 최상단 고정 (ListView 밖 Column 첫 번째 자식)
- `SingleChildScrollView(scrollDirection: Axis.horizontal)` + `Row`
- 패딩: horizontal 16, vertical 10
- 칩 간격: `SizedBox(width: 8)`
- 칩 1개 ("전체") + mainCategoriesActiveProvider 에서 active=true 메인 카테고리 수만큼 칩 생성

**칩 스타일 (선택됨)**:

| 속성 | 값 |
|---|---|
| 배경 | `AppColors.primary` |
| 텍스트 | `AppColors.onPrimary`, fontSize 13, w600 |
| border | 없음 |
| borderRadius | 999 (pill) |
| padding | horizontal 14, vertical 8 |

**칩 스타일 (선택 안 됨)**:

| 속성 | 값 |
|---|---|
| 배경 | `AppColors.surfaceElevated` |
| border | `AppColors.border` 1px |
| 텍스트 | `AppColors.textBody`, fontSize 13, w500 |
| borderRadius | 999 (pill) |
| padding | horizontal 14, vertical 8 |

#### Body — ListView

- `ListView.builder` + `Padding(horizontal 16, top 8, bottom 80)`
  - bottom 80: FAB 와 겹치지 않도록 확보
- 데이터: `brandSubCategoriesProvider({brandId, mainId: selectedMain})` (inactive 포함, displayOrder asc)
- **전체 선택 시**: mainCategory 를 섹션 헤더로 그룹핑하여 표시
- **특정 메인 카테고리 선택 시**: 해당 main 의 sub 만 평면 리스트로 표시 (섹션 헤더 없음)
- 각 항목: `SubCategoryListItem` (하단 명세)
- 항목 간격: `SizedBox(height: 8)`

**섹션 헤더 (`_SectionHeader`)** — "전체" 선택 시만 표시:

```
Padding(top: 16, bottom: 6, left: 4)
  └─ Text(mainCategoryLabel, fontSize 12, w700, AppColors.primary)
```

#### SubCategoryListItem

```
Card
  └─ Padding(horizontal 4, vertical 2)
       └─ ListTile
            ├─ leading: _OrderBadge(displayOrder)
            ├─ title: Text(name)
            ├─ subtitle: _UsageChip(subCategoryId) — "사용 중 N개"
            ├─ trailing: Row
            │              ├─ SubCategoryActiveSwitch(entity)
            │              ├─ SizedBox(width: 4)
            │              └─ PopupMenuButton
            └─ onTap: Navigator.push → BrandSubCategoryFormPage(editItem: entity)
```

**Card 스타일**:

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

**subtitle — `_UsageChip`**:

- 기본: `'사용 중 {N}개'`, fontSize 12, `AppColors.textMuted`
- N=0: `'사용 없음'`, fontSize 12, `AppColors.textMuted`
- loading 중: 너비 60, 높이 12 shimmer bar (`AppColors.surface` → `AppColors.surfaceElevated`)
- 에러: `'-'`, fontSize 12, `AppColors.textMuted`

**`SubCategoryActiveSwitch`**:

- `Switch.adaptive`
- active=true: `AppColors.primary` (thumbColor), `AppColors.primaryBright` alpha 0.3 (trackColor)
- active=false: `AppColors.textMuted` (thumbColor), `AppColors.surface` (trackColor)
- onChanged:
  - true → false 방향: 즉시 `ToggleSubCategoryActiveUseCase(id, false)` 호출 (메인 카테고리와 달리 영향 데이터 다이얼로그 없음. 비활성화는 가볍게 처리)
  - false → true 방향: 즉시 `ToggleSubCategoryActiveUseCase(id, true)` 호출

**PopupMenuButton**:

- 아이콘: `Icons.more_vert_rounded`, size 20, `AppColors.textMuted`
- 항목:
  - `'편집'` — `Navigator.push → BrandSubCategoryFormPage(editItem: entity)`
  - `'삭제'` — `SubCategoryDeleteDialog` 노출

#### FAB

| 속성 | 값 |
|---|---|
| 배경 | `AppColors.primary` |
| 아이콘 | `Icons.add_rounded`, `AppColors.onPrimary`, size 24 |
| shadow | `AppColors.primary` alpha 0.3, blurRadius 8, offset (0, 4) |
| onTap | `Navigator.push → BrandSubCategoryFormPage(editItem: null, brandId: brandId)` |
| 위치 | 우하단 (기본 floatingActionButton) |

#### 인터랙션 상세

| 동작 | 반응 |
|---|---|
| 필터 칩 탭 | selectedMain 변경 → ListView 재빌드. 칩 스타일 갱신 |
| ListTile 탭 | `BrandSubCategoryFormPage(editItem: entity)` push |
| Switch 탭 (true→false) | 즉시 비활성화. SnackBar `'분류를 비활성화했어요'` |
| Switch 탭 (false→true) | 즉시 활성화. SnackBar `'분류를 활성화했어요'` |
| Switch 토글 실패 | SnackBar `'처리에 실패했어요. 다시 시도해주세요'` + switch 원상복구 |
| PopupMenu '편집' | `BrandSubCategoryFormPage(editItem: entity)` push |
| PopupMenu '삭제' | `SubCategoryDeleteDialog(entity: entity)` 표시 |
| FAB '+' 탭 | `BrandSubCategoryFormPage(editItem: null)` push |

---

### A2 상태별 UI

#### Loading

- 4개 shimmer `SubCategoryListItem` skeleton
- skeleton 구성:
  ```
  Card
    └─ ListTile
         ├─ leading: Container(36×36, radius 8) — shimmer
         ├─ title: Container(너비 100, 높이 14) — shimmer
         └─ subtitle: Container(너비 64, 높이 10) — shimmer
  ```
- shimmer base: `AppColors.surface`, highlight: `AppColors.surfaceElevated`
- 필터 칩 바 shimmer: 너비 56×28 pill 3개, `AppColors.surface` → `AppColors.surfaceElevated`

#### Error

```
Center
  └─ Column (mainAxisSize: min, spacing: 12)
       ├─ Icon(Icons.error_outline_rounded, size 48, AppColors.error)
       ├─ Text('분류 목록을 불러오지 못했어요', fontSize 16, w600, AppColors.textHeading)
       ├─ Text('잠시 후 다시 시도해주세요', fontSize 13, AppColors.textMuted)
       └─ TextButton('다시 시도', AppColors.primary)
```

#### Empty

```
Center
  └─ Column (mainAxisSize: min, spacing: 12)
       ├─ Icon(Icons.label_outline_rounded, size 48, AppColors.textMuted)
       ├─ Text('등록된 분류가 없어요', fontSize 16, w600, AppColors.textHeading)
       ├─ Text('아래 버튼으로 첫 서브 카테고리를 추가해보세요', fontSize 13, AppColors.textMuted)
       └─ (FAB 가 이미 표시되므로 별도 CTA 버튼 불필요)
```

---

### A3. BrandSubCategoryFormPage

- 파일: `lib/presentation/brand/menu_categories/brand_sub_category_form_page.dart`
- 역할: 등록 / 수정 통합 폼. `editItem: SubCategoryEntity?` 로 분기. brandId 컨텍스트 필수.

#### 레이아웃

```
Scaffold
  ├─ AppBar
  └─ body: SingleChildScrollView
              └─ Padding(horizontal 20, vertical 24)
                   └─ Column (spacing: 20)
                        ├─ [섹션] 메인 카테고리 선택
                        ├─ [섹션] 이름 입력 (중복 검증 포함)
                        ├─ [섹션] 정렬 순서 입력
                        ├─ [섹션] 활성화 스위치
                        ├─ SizedBox(height: 16)
                        └─ [버튼 Row] 취소 / 저장
```

#### AppBar

| 속성 | 값 |
|---|---|
| leading | `Icons.arrow_back_ios_new_rounded` |
| title | 등록: `'서브 카테고리 추가'` / 수정: `'서브 카테고리 수정'` |
| titleTextStyle | fontSize 17, w700, `AppColors.textHeading` |
| backgroundColor | `AppColors.background` |
| elevation | 0 |

#### 섹션 스타일 공통 (`_FormSection`)

sub-phase 9 `AdminMainCategoryFormPage` 의 `_FormSection` 패턴 동일:

```
Column (crossAxisAlignment: start, spacing: 6)
  ├─ Text(라벨, fontSize 12, w600, AppColors.textMuted)
  └─ [입력 위젯]
```

#### 메인 카테고리 선택 섹션

- 라벨: `'메인 카테고리'`
- `mainCategoriesActiveProvider` 에서 active=true 카테고리만 칩으로 나열 (inactive 는 등록 모드에서 제외)
- **수정 모드**에서 현재 entity 의 mainCategoryCode 가 inactive 이면 해당 칩도 inactive 스타일로 포함
- 칩 래핑: `Wrap(spacing: 8, runSpacing: 8)`

**칩 스타일 (선택됨)**:

| 속성 | 값 |
|---|---|
| 배경 | `AppColors.primary` |
| 텍스트 | `AppColors.onPrimary`, fontSize 13, w600 |
| borderRadius | 999 (pill) |
| padding | horizontal 14, vertical 8 |

**칩 스타일 (선택 안 됨)**:

| 속성 | 값 |
|---|---|
| 배경 | `AppColors.surfaceElevated` |
| border | `AppColors.border` 1px |
| 텍스트 | `AppColors.textBody`, fontSize 13, w500 |
| borderRadius | 999 (pill) |
| padding | horizontal 14, vertical 8 |

**inactive 메인 카테고리 칩 (수정 모드 전용)**:

| 속성 | 값 |
|---|---|
| 배경 | `AppColors.warning` alpha 0.12 |
| border | `AppColors.warning` alpha 0.5 / 1px |
| 텍스트 색 | `AppColors.warning` |
| 텍스트 | `'{label} (비활성)'` |
| 우측 아이콘 | `Icons.warning_amber_rounded`, size 14, `AppColors.warning` |
| onTap | disabled (IgnorePointer) |

- 유효성: 메인 카테고리 미선택 시 저장 버튼 disabled

#### 이름 입력 섹션

- 라벨: `'분류 이름'`
- `TextFormField`
  - hint: `'예: 에스프레소, 콜드브루, 시즌 한정'`
  - maxLength: 10 (counter 표시: true)
  - 배경: `AppColors.surfaceElevated`
  - border: `AppColors.border` → 포커스: `AppColors.primary`
  - 텍스트: `AppColors.textBody`
  - errorStyle: `AppColors.error`
  - helperText: `'최대 10자'`, fontSize 11, `AppColors.textMuted`
  - 유효성: 비어있으면 `'이름을 입력해주세요'`
- **중복 검증 inline 에러 영역** (디바운스 300ms):
  - 조회 중: helperText 영역에 `CircularProgressIndicator(size: 12, color: AppColors.primary)` + `' 확인 중...'`, fontSize 11, `AppColors.textMuted`
  - 중복 없음: helperText 영역 `'사용 가능한 이름이에요'`, fontSize 11, `AppColors.success` (조회 완료 1~2초 후 helperText 로 복귀)
  - 중복 있음: errorText `'이미 같은 이름의 분류가 있어요'`, fontSize 11, `AppColors.error`

#### 정렬 순서 입력 섹션

- 라벨: `'정렬 순서'`
- `TextFormField`
  - hint: `'0, 1, 2 ...'`
  - keyboardType: `TextInputType.number`
  - inputFormatters: 숫자만 허용
  - 배경: `AppColors.surfaceElevated`
  - border: `AppColors.border` → 포커스: `AppColors.primary`
  - helperText: `'숫자가 낮을수록 앞에 표시돼요'`, fontSize 11, `AppColors.textMuted`
  - 유효성: 비어있으면 `'순서를 입력해주세요'`, 음수 불가

#### 활성화 스위치 섹션

```
Row (mainAxisAlignment: spaceBetween)
  ├─ Column (crossAxisAlignment: start)
  │    ├─ Text('활성화', fontSize 15, w500, AppColors.textBody)
  │    └─ Text('비활성화 시 메뉴 폼과 고객 화면에서 숨겨져요', fontSize 12, AppColors.textMuted)
  └─ Switch.adaptive
       ├─ active: AppColors.primary (thumbColor), AppColors.primaryBright alpha 0.3 (trackColor)
       └─ inactive: AppColors.textMuted (thumbColor), AppColors.surface (trackColor)
```

#### 버튼 Row

```
Row (spacing: 12)
  ├─ Expanded — OutlinedButton '취소'
  └─ Expanded — ElevatedButton '저장'
```

**취소 버튼**:
- 배경: `AppColors.surfaceElevated`
- border: `AppColors.border`
- 텍스트: `AppColors.textBody`, fontSize 15, w600
- borderRadius: 12
- height: 52
- onTap: `Navigator.pop`

**저장 버튼**:
- 배경: `AppColors.primary`
- 텍스트: `AppColors.onPrimary`, fontSize 15, w600
- borderRadius: 12
- height: 52
- disabled 조건: 폼 유효성 불통과 또는 중복 이름 에러 발생 시 (`AppColors.textMuted` 배경, `AppColors.onPrimary` alpha 0.5 텍스트)
- loading 중: `CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2)` 텍스트 대체
- onTap: `UpsertSubCategoryUseCase` 호출

#### 저장 성공/실패 피드백

| 케이스 | 피드백 |
|---|---|
| 등록 성공 | SnackBar `'분류를 추가했어요'` + `Navigator.pop` |
| 수정 성공 | SnackBar `'분류를 수정했어요'` + `Navigator.pop` |
| 실패 (중복 이름 race) | SnackBar `'이미 같은 이름의 분류가 있어요. 다른 이름을 사용해주세요'` (폼 유지) |
| 실패 (네트워크) | SnackBar `'처리에 실패했어요. 다시 시도해주세요'` (폼 유지) |

---

### A4. SubCategoryDeleteDialog (brand / owner 공통)

- 파일: `lib/presentation/common/widgets/menu_categories/sub_category_delete_dialog.dart`
- 역할: 서브 카테고리 삭제 확인. 사용 중 여부에 따라 분기. brand/owner 양쪽에서 재사용.

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
            ├─ Text('분류 삭제', fontSize 16, w700, AppColors.textHeading)
            └─ Text(entity.name, fontSize 13, AppColors.textMuted)
```

#### 본문 — 케이스 분기

**로딩 상태 (usageCount 조회 중)**:

```
Row (spacing: 8)
  ├─ SizedBox(16×16) — CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)
  └─ Text('확인 중...', fontSize 13, AppColors.textMuted)
```

**케이스 1: 사용 중 (usageCount >= 1) — 삭제 차단**

```
Column (spacing: 12)
  ├─ Container (background: AppColors.error alpha 0.08, radius 10, padding 14)
  │    └─ Text
  │         '이 분류를 사용 중인 메뉴가 {N}개 있어요.\n메뉴를 다른 분류로 먼저 변경해주세요.'
  │         fontSize 13, AppColors.textBody
  └─ Text
       '분류를 숨기려면 비활성화를 사용하세요.'
       fontSize 12, AppColors.textMuted
```

**케이스 2: 사용 없음 (usageCount == 0) — 삭제 가능**

```
Text
  '이 분류를 삭제할까요? 삭제 후에는 되돌릴 수 없어요.'
  fontSize 13, AppColors.textBody
```

#### 버튼 Row

**케이스 1 (차단)**:

```
Row (spacing: 12)
  ├─ Expanded — OutlinedButton '취소'
  └─ Expanded — ElevatedButton '비활성으로 전환' (AppColors.warning 배경, AppColors.onPrimary 텍스트)
```

"비활성으로 전환" 탭 시: 다이얼로그 닫고 → `ToggleSubCategoryActiveUseCase(id, false)` 직접 호출 (재확인 다이얼로그 없음 — 삭제 의도에서 비활성화로 전환하는 흐름이므로).

**케이스 2 (삭제 가능)**:

```
Row (spacing: 12)
  ├─ Expanded — OutlinedButton '취소'
  └─ Expanded — ElevatedButton '삭제' (AppColors.error 배경, AppColors.onPrimary 텍스트)
```

"삭제" 탭 시: `DeleteSubCategoryUseCase(id)` 호출 → 성공 시 pop + SnackBar `'분류를 삭제했어요'`

**버튼 공통 스타일**:

| 속성 | 취소 버튼 | 액션 버튼 |
|---|---|---|
| 배경 | `AppColors.surfaceElevated` | 케이스별 상이 |
| border | `AppColors.border` | 없음 |
| 텍스트 색 | `AppColors.textBody` | `AppColors.onPrimary` |
| fontSize | 14, w600 | 14, w600 |
| borderRadius | 10 | 10 |
| height | 44 | 44 |

**로딩 상태 버튼**: 케이스 분기 미결정 → 두 버튼 모두 disabled (`AppColors.textMuted` 배경). 취소만 활성 유지하여 UX 차단 최소화.

> 디자이너 결정: 삭제 다이얼로그에서 "비활성으로 전환" 시 DeactivateConfirmDialog 를 다시 띄우지 않는다. sub-phase 9 메인 카테고리 DeleteDialog 와 동일 패턴.

---

## 영역 B — owner 개인 매장 서브 카테고리 관리 화면

### B1. MyStorePage "메뉴 관리" 영역 — "분류 관리" 진입 추가

기존 MyStorePage 의 "메뉴 관리" 섹션 안에 ListTile 형식 CTA 를 추가한다.

#### 추가 위치

"메뉴 관리" 섹션 내부, 기존 "메뉴 목록" 또는 메뉴 등록 CTA 아래에 위치:

```
"메뉴 관리" 섹션
  ├─ (기존) 메뉴 목록 / 등록 CTA
  └─ [신규] _StoreTile '분류 관리'  ← 추가
```

#### 신규 진입 명세

기존 MyStorePage 의 `_StoreTile` 또는 `ListTile` 패턴 재사용:

| 속성 | 값 |
|---|---|
| icon | `Icons.label_rounded` |
| title | `'분류 관리'` |
| subtitle | `'내 매장만의 메뉴 분류를 만들어요'` |
| subtitleStyle | fontSize 12, `AppColors.textMuted` |
| onTap | `Navigator.push → OwnerStoreSubCategoryListPage(storeId: currentStoreId)` |
| trailing | `Icons.chevron_right_rounded` (size 18, `AppColors.textMuted`) |

> 진입 가드: store.brandId == null (개인 매장) 이고 본인 매장일 때만 노출. 가맹점 점주(brandId != null)는 이 tile 미노출.

---

### B2. OwnerStoreSubCategoryListPage

- 파일: `lib/presentation/owner/menu_categories/owner_store_sub_category_list_page.dart`
- 역할: `stores/{storeId}/subCategories/` 목록. brand 화면과 동일 구조.

#### 레이아웃

A2 `BrandSubCategoryListPage` 와 동일 구조. storeId 컨텍스트만 다름.

```
Scaffold
  ├─ AppBar (title: '분류 관리')
  ├─ body: Column
  │         ├─ _MainCategoryFilterChips
  │         └─ Expanded — ListView
  └─ floatingActionButton: FAB
```

AppBar / SubCategoryListItem / FAB / 필터 칩 / shimmer / 상태 UI 모두 A2 동일.

- FAB onTap: `Navigator.push → OwnerStoreSubCategoryFormPage(editItem: null, storeId: storeId)`
- ListTile onTap: `OwnerStoreSubCategoryFormPage(editItem: entity)`

#### 상태별 UI

A2 와 동일 (loading / error / empty 문구 동일).

---

### B3. OwnerStoreSubCategoryFormPage

- 파일: `lib/presentation/owner/menu_categories/owner_store_sub_category_form_page.dart`
- 역할: store scope 등록 / 수정 통합 폼. storeId 컨텍스트 필수.

#### 레이아웃 및 섹션

A3 `BrandSubCategoryFormPage` 와 동일 구조. storeId 컨텍스트만 다름.

- 메인 카테고리 선택, 이름 입력(중복 검증), 정렬 순서, 활성화 스위치, 버튼 Row 모두 동일.
- 중복 검증: 같은 store scope 안에서 normalized name 비교 (`FindDuplicateSubCategoryNameUseCase(scope=store, storeId)`).
- AppBar title — 등록: `'분류 추가'`, 수정: `'분류 수정'`

#### 성공/실패 피드백

A3 와 동일 카피.

---

## 영역 C — 메뉴 폼 3종 sub-category 칩 영역 (SubCategoryChipsSelector)

### 적용 화면

1. `lib/presentation/brand/master_menu/master_menu_form_page.dart`
2. `lib/presentation/brand/customization/store_only_menu/brand_store_only_menu_form_page.dart`
3. `lib/presentation/owner/store_menu/owner_store_menu_form_page.dart`

### 위치

메인 카테고리 칩 영역(`_FormSection('메인 카테고리')`) 의 **직하** 에 sub-category 칩 영역 추가.

```
[기존] _FormSection('메인 카테고리')
  └─ Wrap(칩들)

[신규] _FormSection('서브 카테고리')   ← 여기 추가
  └─ SubCategoryChipsSelector(...)
```

### SubCategoryChipsSelector 위젯

- 파일: `lib/presentation/common/widgets/sub_category_chips_selector.dart`
- Props:
  - `selectedSubCategoryId: String?`
  - `subCategories: List<SubCategoryEntity>` (외부에서 provider 결과 전달)
  - `isLoading: bool`
  - `onSelected: ValueChanged<String?>` (null = 선택 해제)

#### 칩 렌더링 구조

```
Column (crossAxisAlignment: start, spacing: 8)
  ├─ Text('서브 카테고리', fontSize 12, w600, AppColors.textMuted)  ← 섹션 라벨
  └─ [상태에 따라 분기]
       ├─ (메인 미선택) → _SubHintText('메인 카테고리를 먼저 선택해주세요')
       ├─ (loading) → shimmer bar
       ├─ (empty — sub 0개) → _SubHintText('이 분류에 서브 카테고리가 없어요 · sub 없이 등록 가능해요')
       └─ (data) → Wrap(spacing: 8, runSpacing: 8)
                       └─ chips (선택됨 / 선택 안 됨 / inactive 경고)
```

**`_SubHintText`**:

```
Container
  ├─ padding: horizontal 12, vertical 10
  ├─ decoration: radius 10, background AppColors.surface, border AppColors.border 1px
  └─ Text(text, fontSize 12, AppColors.textMuted)
```

#### 칩 스타일 상세

**선택됨 (active sub)**:

| 속성 | 값 |
|---|---|
| 배경 | `AppColors.primary` |
| 텍스트 | `AppColors.onPrimary`, fontSize 13, w600 |
| borderRadius | 999 (pill) |
| padding | horizontal 14, vertical 8 |
| onTap | 재탭 시 선택 해제 (selectedSubCategoryId = null) |

**선택 안 됨 (active sub)**:

| 속성 | 값 |
|---|---|
| 배경 | `AppColors.surfaceElevated` |
| border | `AppColors.border` 1px |
| 텍스트 | `AppColors.textBody`, fontSize 13, w500 |
| borderRadius | 999 (pill) |
| padding | horizontal 14, vertical 8 |
| onTap | 선택 → selectedSubCategoryId 갱신 |

**inactive sub (수정 모드 prefill 전용)**:

| 속성 | 값 |
|---|---|
| 배경 | `AppColors.warning` alpha 0.12 |
| border | `AppColors.warning` alpha 0.5 / 1px |
| 텍스트 색 | `AppColors.warning` |
| 텍스트 | `'{name} (비활성)'` |
| 우측 아이콘 | `Icons.warning_amber_rounded`, size 14, `AppColors.warning` |
| onTap | disabled (IgnorePointer) |

> inactive sub 칩 직하 경고 라벨 (`InactiveSubCategoryWarningLabel`):

```
Padding(top: 4)
  └─ Row (spacing: 6)
       ├─ Icon(Icons.warning_amber_rounded, size 14, AppColors.warning)
       └─ Text('이 분류는 비활성화되었습니다. 다른 분류로 변경해주세요.', fontSize 11, w500, AppColors.warning)
```

**삭제된 sub fallback (수정 모드 — DB에서 못 찾은 경우)**:

```
Container (배경: AppColors.error alpha 0.08, border: AppColors.error alpha 0.4 / 1px, radius 999, padding: horizontal 14, vertical 8)
  └─ Row (spacing: 6)
       ├─ Icon(Icons.broken_image_outlined, size 14, AppColors.error)
       └─ Text('삭제된 분류 — 변경 필요', fontSize 13, AppColors.error)
```

칩 직하 fallback 라벨:

```
Padding(top: 4)
  └─ Text('연결된 분류가 삭제됐어요. 다른 분류를 선택해주세요.', fontSize 11, AppColors.error)
```

#### cascade reset 시각 처리

메인 카테고리 변경 시:

1. selectedSubCategoryId = null 즉시 reset
2. sub 칩 영역: 이전 칩들이 `AnimatedSwitcher(duration: 150ms, curve: Curves.easeOut)` 로 fade-out → loading → 새 sub 칩 fade-in
3. sub 영역 전체가 null→loading→data 흐름이므로 별도 skeleton 필요

**cascade reset loading shimmer**:

```
Wrap(spacing: 8, runSpacing: 8)
  └─ [3개] Container(너비 72, 높이 34, radius 999) — shimmer
```

shimmer base: `AppColors.surface`, highlight: `AppColors.surfaceElevated`

#### 메인 미선택 시 sub 영역

메인 카테고리 selectedMainCategoryCode 가 null 인 경우:

```
_SubHintText('메인 카테고리를 먼저 선택해주세요')
```

- sub 칩 영역 전체를 Opacity(0.5) 처리 + IgnorePointer 로 탭 불가
- `_SubHintText` 는 위 스타일 동일

#### sub 0개 (empty) 상태

메인 선택 완료 + 해당 main 의 active sub 가 0개:

```
_SubHintText('이 분류에 서브 카테고리가 없어요 · sub 없이 등록 가능해요')
```

#### sub 폼 유효성

sub 선택은 필수 아님. `_canSubmit` 조건에서 sub 선택 여부를 검사하지 않는다.

---

## 영역 D — 가맹점 점주 read-only 정책

### 정책 명세 (시각 작업 없음)

- **BrandMorePage**: 가맹점 점주(brandAffiliate 역할)에게는 "서브 카테고리 관리" tile 미노출. 조건: `currentUserRole == UserRole.brandAffiliate` 이면 해당 tile 빌드 생략.
- **MyStorePage**: 가맹점 점주(store.brandId != null) 이면 "분류 관리" tile 미노출. 조건: `store.brandId != null` → tile 빌드 생략.
- 메뉴 폼에서 가맹점 점주가 사용하는 폼은 별도 폼이므로 sub 칩은 brand scope sub 가 자동 노출 (read-only 칩, 선택 가능 — 메뉴 저장 시 subCategoryId 반영).

> 가맹점 점주가 sub CRUD 페이지에 직접 URL/코드 우회로 접근 시도할 경우 UseCase 단에서 권한 체크 실패 → DeveloperNote 참조 (보안 규칙은 별 task).

---

## 영역 E — 검증 inline 에러 / dialog 카피

### 폼 디바운스 inline 에러

| 상태 | 위치 | 카피 | 색상 |
|---|---|---|---|
| 조회 중 | helperText | `'확인 중...'` + spinner | `AppColors.textMuted` |
| 중복 없음 | helperText | `'사용 가능한 이름이에요'` | `AppColors.success` |
| 중복 있음 | errorText | `'이미 같은 이름의 분류가 있어요'` | `AppColors.error` |

- 디바운스 interval: 300ms
- 조회 중 상태에서는 저장 버튼 disabled

### submit 시 race 차단

UseCase 가 최종 `DuplicateSubCategoryNameException` throw 시:

- 폼 유지
- SnackBar: `'이미 같은 이름의 분류가 있어요. 다른 이름을 사용해주세요'`
- 이름 입력 필드에 errorText: `'이미 같은 이름의 분류가 있어요'`
- SnackBar 배경: `AppColors.error`, 텍스트: `AppColors.onPrimary`

### 삭제 차단 토스트

사용 중 sub 삭제 시도 차단 (DeleteDialog 에서 표시, 별도 toast 불필요 — 다이얼로그 자체가 차단 안내):

- 다이얼로그 본문: `'이 분류를 사용 중인 메뉴가 {N}개 있어요.\n메뉴를 다른 분류로 먼저 변경해주세요.'`
- 보조 문구: `'분류를 숨기려면 비활성화를 사용하세요.'`

---

## 상태별 UI 총괄

### BrandSubCategoryListPage / OwnerStoreSubCategoryListPage

| 상태 | 표시 방식 | 문구 |
|---|---|---|
| loading | 4개 shimmer skeleton (ListTile 형태) + 필터 칩 shimmer | — |
| error | 중앙 Icon(error) + 텍스트 + retry 버튼 | `'분류 목록을 불러오지 못했어요'` |
| empty | 중앙 Icon(label_outline) + 텍스트 | `'등록된 분류가 없어요'` |
| data | SubCategoryListItem 목록 (섹션 그룹핑 or 평면) | — |

### BrandSubCategoryFormPage / OwnerStoreSubCategoryFormPage

| 상태 | 표시 방식 |
|---|---|
| 저장 중 | 저장 버튼 내부 `CircularProgressIndicator` |
| 저장 성공 | SnackBar + pop |
| 저장 실패 (중복 이름) | SnackBar + errorText 표시 (폼 유지) |
| 저장 실패 (네트워크) | SnackBar (폼 유지) |
| 디바운스 조회 중 | helperText spinner |

### SubCategoryDeleteDialog

| 상태 | 표시 방식 |
|---|---|
| loading (usageCount 조회 중) | spinner + 버튼 disabled (취소만 활성) |
| 사용 중 (N>=1) | error 톤 컨테이너 + 비활성으로 전환 버튼 |
| 사용 없음 (N=0) | 단순 확인 + 삭제 버튼 |

### SubCategoryChipsSelector (메뉴 폼 3종)

| 상태 | 표시 방식 |
|---|---|
| 메인 미선택 | `_SubHintText` + 영역 dimmed |
| loading (메인 변경 직후) | shimmer pill 3개 |
| empty | `_SubHintText` (sub 0개 안내) |
| data (active sub 있음) | 칩 목록 |
| inactive sub prefill (수정 모드) | warning 스타일 칩 + 경고 라벨 |
| 삭제된 sub fallback (수정 모드) | error 스타일 칩 + fallback 라벨 |

---

## 인터랙션 정의

| 동작 | 반응 |
|---|---|
| BrandMorePage "서브 카테고리 관리" 탭 | `Navigator.push(BrandSubCategoryListPage)` |
| MyStorePage "분류 관리" 탭 | `Navigator.push(OwnerStoreSubCategoryListPage)` |
| 필터 칩 탭 | selectedMain 변경 → sub 목록 재필터링. 전체 칩 탭 시 섹션 그룹핑 표시 |
| ListItem 탭 | FormPage(editItem: entity) push |
| Switch 탭 (active 토글) | 즉시 toggle UseCase 호출. 성공/실패 SnackBar |
| PopupMenu '편집' | FormPage(editItem: entity) push |
| PopupMenu '삭제' | SubCategoryDeleteDialog 표시 |
| DeleteDialog "비활성으로 전환" | 다이얼로그 닫고 직접 비활성화 UseCase 호출 |
| DeleteDialog "삭제" | DeleteSubCategoryUseCase 호출 |
| FormPage "저장" | UpsertSubCategoryUseCase 호출. 성공 시 pop |
| FormPage "취소" | Navigator.pop |
| FAB '+' 탭 | FormPage(editItem: null) push |
| 이름 입력 (디바운스 300ms) | FindDuplicateSubCategoryNameUseCase 호출 → inline 에러/성공 표시 |
| 메뉴 폼 메인 카테고리 변경 | selectedSubCategoryId = null reset + sub 칩 AnimatedSwitcher fade (150ms) |
| sub 칩 탭 (active) | selectedSubCategoryId 갱신 |
| sub 칩 재탭 (선택 중) | selectedSubCategoryId = null (선택 해제) |
| inactive sub 칩 탭 | 무반응 (IgnorePointer) |

---

## Figma 대비 변경사항

| 항목 | 기존 / Figma 없음 | Qradar 적용 |
|---|---|---|
| 기존 화면 없음 | — | Qradar 디자인 시스템 + sub-phase 9 패턴 신규 적용 |
| 메인 카테고리 필터 | sub-phase 9 에 없음 | brand/owner 목록에 필터 칩 바 추가 (섹션 그룹핑과 겸용) |
| Sub active 토글 비활성화 확인 | — | 단순 즉시 토글 (메인 카테고리와 달리 DeactivateConfirmDialog 없음 — sub 는 영향 범위가 작음) |
| 메뉴 폼 sub 칩 cascade | 없음 | AnimatedSwitcher 150ms fade 전환 |
| inactive sub 경고 | 없음 | warning 스타일 칩 + 직하 경고 라벨 |
| 삭제된 sub fallback | 없음 | error 스타일 칩 + fallback 라벨 |

---

## 개발자 전달 특이사항

### 카피 확정값

| 위치 | 확정 문구 |
|---|---|
| BrandMorePage 타일 | `'서브 카테고리 관리'` |
| MyStorePage 분류 관리 tile subtitle | `'내 매장만의 메뉴 분류를 만들어요'` |
| FormPage AppBar (등록, brand) | `'서브 카테고리 추가'` |
| FormPage AppBar (수정, brand) | `'서브 카테고리 수정'` |
| FormPage AppBar (등록, owner) | `'분류 추가'` |
| FormPage AppBar (수정, owner) | `'분류 수정'` |
| 이름 필드 hint | `'예: 에스프레소, 콜드브루, 시즌 한정'` |
| 이름 필드 helperText | `'최대 10자'` |
| displayOrder helperText | `'숫자가 낮을수록 앞에 표시돼요'` |
| active 스위치 부설명 | `'비활성화 시 메뉴 폼과 고객 화면에서 숨겨져요'` |
| 등록 성공 SnackBar | `'분류를 추가했어요'` |
| 수정 성공 SnackBar | `'분류를 수정했어요'` |
| 삭제 성공 SnackBar | `'분류를 삭제했어요'` |
| 활성화 성공 SnackBar | `'분류를 활성화했어요'` |
| 비활성화 성공 SnackBar | `'분류를 비활성화했어요'` |
| 처리 실패 SnackBar | `'처리에 실패했어요. 다시 시도해주세요'` |
| 중복 이름 inline errorText | `'이미 같은 이름의 분류가 있어요'` |
| 중복 이름 SnackBar (race 차단) | `'이미 같은 이름의 분류가 있어요. 다른 이름을 사용해주세요'` |
| 디바운스 조회 중 helperText | `'확인 중...'` |
| 중복 없음 helperText | `'사용 가능한 이름이에요'` |
| 경고 라벨 (inactive sub, 메뉴 폼) | `'이 분류는 비활성화되었습니다. 다른 분류로 변경해주세요.'` |
| fallback 라벨 (삭제된 sub, 메뉴 폼) | `'연결된 분류가 삭제됐어요. 다른 분류를 선택해주세요.'` |
| DeleteDialog 헤더 | `'분류 삭제'` |
| DeleteDialog 차단 본문 | `'이 분류를 사용 중인 메뉴가 {N}개 있어요.\n메뉴를 다른 분류로 먼저 변경해주세요.'` |
| DeleteDialog 차단 보조 | `'분류를 숨기려면 비활성화를 사용하세요.'` |
| DeleteDialog 삭제 가능 본문 | `'이 분류를 삭제할까요? 삭제 후에는 되돌릴 수 없어요.'` |
| 목록 empty 제목 | `'등록된 분류가 없어요'` |
| 목록 empty 부설명 | `'아래 버튼으로 첫 서브 카테고리를 추가해보세요'` |
| 목록 error 제목 | `'분류 목록을 불러오지 못했어요'` |
| 목록 error 부설명 | `'잠시 후 다시 시도해주세요'` |
| 메뉴 폼 sub 영역 — 메인 미선택 | `'메인 카테고리를 먼저 선택해주세요'` |
| 메뉴 폼 sub 영역 — sub 0개 | `'이 분류에 서브 카테고리가 없어요 · sub 없이 등록 가능해요'` |

### 구현 시 주의사항

1. **공통 위젯 추출**: brand/owner 가 동일한 `SubCategoryListItem`, `SubCategoryDeleteDialog`, `SubCategoryActiveSwitch`, `SubCategoryFormFields` 를 공유한다. `lib/presentation/common/widgets/menu_categories/` 에 위치시킬 것.

2. **brand vs owner 구분**: ListPage / FormPage 는 별도 파일이지만 내부 공통 위젯을 사용. brandId / storeId / scope 를 props 로 주입받아 UseCase 호출 시 scope 결정.

3. **sub active 토글 단순화**: 메인 카테고리(sub-phase 9) 에서는 비활성화 시 DeactivateConfirmDialog 를 띄웠지만, sub-category 에서는 영향 범위가 메뉴 수준에 그치고 DeleteDialog 에서 이미 비활성화 전환 분기를 제공하므로 list 에서의 switch 는 즉시 토글. 별도 confirm dialog 없음.

4. **SubCategoryChipsSelector 독립 위젯**: `lib/presentation/common/widgets/sub_category_chips_selector.dart`. MasterMenuFormPage / BrandStoreOnlyMenuFormPage / OwnerStoreMenuFormPage 세 곳에서 재사용. 각 폼이 외부 provider 결과를 전달하는 방식 (위젯 내부에서 직접 provider watch 하지 않고, props 로 주입).

5. **cascade reset AnimatedSwitcher**: 메인 카테고리 변경 시 `AnimatedSwitcher(duration: Duration(milliseconds: 150), transitionBuilder: FadeTransition)` 로 sub 칩 영역 전환. 이전 칩 → shimmer → 새 칩 흐름.

6. **inactive sub merge 로직**: 수정 모드에서 메뉴의 `subCategoryId` 가 active sub 목록에 없으면 `SubCategoryRepository.findById` 로 찾아 inactive 확인. 없으면 삭제된 sub 로 판단 → fallback 칩 표시.

7. **삭제된 sub fallback 칩**: 별도 `SubCategoryEntity` 없이 `subCategoryId` 문자열만으로 fallback 칩 렌더링. 칩 tap disabled.

8. **디바운스 조회 중 저장 버튼 처리**: `_isDuplicateChecking` 플래그로 저장 버튼 disabled. 조회 완료 후 중복 없음이 확인되면 버튼 활성화.

9. **`_UsageChip` 개별 비동기 로딩**: `SubCategoryListItem` 이 `subCategoryUsageProvider.family(subCategoryId)` 를 watch. 각 아이템이 독립적으로 loading/error/data 상태를 가진다.

10. **필터 칩 "전체" 탭 시 섹션 헤더 표시**: selectedMain == null 이면 mainCategoryCode 로 그룹핑한 섹션 헤더를 ListView 안에 삽입. mainCategoryLabel 은 `mainCategoriesAllProvider` 결과에서 조회.

11. **가맹점 점주 진입 가드**: `BrandMorePage` 에서 타일 조건부 빌드. `MyStorePage` 에서 `store.brandId != null` 이면 "분류 관리" tile 미빌드. UseCase 단 권한 가드는 developer 가 spec.md 를 따라 구현 (보안 규칙은 별 task).

12. **admin 측 변경 없음**: `AdminMorePage` 에 서브 카테고리 관련 tile 추가 없음. 확인 필요.

13. **sub-phase 9 패턴 재사용 범위**:
    - `_OrderBadge` 위젯 — 동일 스타일 재사용
    - `_UsageChip` 패턴 — sub usage count 로 동일 적용
    - DeleteDialog 구조 / 버튼 스타일 — 동일
    - FormPage 섹션 스타일 (`_FormSection`) — 동일
    - `InactiveCategoryWarningBanner` — sub 경고용으로 유사한 `InactiveSubCategoryWarningLabel` (inline 라벨 형태, 별도 위젯)

### 재사용할 기존 컴포넌트

| 컴포넌트 | 재사용 위치 |
|---|---|
| `brand_more_page.dart` `_Tile` | BrandMorePage 신규 타일 — 동일 위젯 재사용 |
| `my_store_page.dart` `_StoreTile` 또는 `ListTile` 패턴 | MyStorePage 분류 관리 진입 |
| `InactiveCategoryWarningBanner` (sub-phase 9) | 메뉴 폼 메인 카테고리 비활성 경고 (기존 재사용 그대로) |
| `AppColors` 토큰 전체 | 신규 모든 화면 |

### 신규 생성이 필요한 공통 위젯

| 위젯 | 파일 위치 |
|---|---|
| `SubCategoryListItem` | `lib/presentation/common/widgets/menu_categories/sub_category_list_item.dart` |
| `SubCategoryDeleteDialog` | `lib/presentation/common/widgets/menu_categories/sub_category_delete_dialog.dart` |
| `SubCategoryActiveSwitch` | `lib/presentation/common/widgets/menu_categories/sub_category_active_switch.dart` |
| `SubCategoryFormFields` | `lib/presentation/common/widgets/menu_categories/sub_category_form_fields.dart` |
| `SubCategoryChipsSelector` | `lib/presentation/common/widgets/sub_category_chips_selector.dart` |
| `InactiveSubCategoryWarningLabel` | `lib/presentation/common/widgets/inactive_sub_category_warning_label.dart` |

### AppColors 토큰 요약 (본 디자인에서 사용한 토큰)

`AppColors.primary`, `AppColors.primaryBright`, `AppColors.onPrimary`, `AppColors.background`, `AppColors.surface`, `AppColors.surfaceElevated`, `AppColors.border`, `AppColors.textHeading`, `AppColors.textBody`, `AppColors.textMuted`, `AppColors.warning`, `AppColors.error`, `AppColors.success`
