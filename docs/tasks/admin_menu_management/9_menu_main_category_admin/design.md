# sub-phase 9 — menu_main_category_admin 디자인 명세

> **상태**: DRAFT — 2026-05-03
>
> **spec.md 기준**: `docs/tasks/admin_menu_management/9_menu_main_category_admin/spec.md` (APPROVED, 결정 1~4 + 4a/b/c/d Lite 확정)

---

## 참조한 디자인

- Figma: 없음 (Qradar 디자인 시스템 + 기존 화면 톤 기반 신규 설계)
- 기존 화면 레퍼런스:
  - `lib/presentation/admin/more/admin_more_page.dart` — `_Tile` 패턴 직접 재사용
  - `docs/tasks/admin_menu_management/1_brand_master/design/admin_module.md` — AdminMorePage, AdminPendingQueuePage 패턴
  - `lib/presentation/customer/order/store/widgets/main_category_tabs.dart` — 현재 TabBar 구현 참조
  - `lib/presentation/brand/master_menu/master_menu_form_page.dart` — 카테고리 칩 현재 구현 참조
- 색상 토큰: `lib/core/theme/app_colors.dart`

---

## 전체 화면 목록

| 영역 | 화면 / 컴포넌트 | 유형 |
|---|---|---|
| A1 | AdminMorePage — "메인 카테고리 관리" ListTile 추가 | 기존 화면 수정 |
| A2 | AdminMainCategoryListPage | 신규 |
| A3 | AdminMainCategoryFormPage | 신규 |
| A4 | MainCategoryDeleteDialog | 신규 |
| B | MainCategoryDeactivateConfirmDialog | 신규 (4d Lite) |
| C | 메뉴 폼 3종 비활성 카테고리 경고 라벨 | 기존 화면 수정 (4d Lite) |
| D | 메뉴 리스트 카드 비활성 marker | **적용하지 않음** (사유 하단 명기) |
| E | customer MainCategoryTabs 가변 N개 정책 | 기존 위젯 수정 |

---

## 영역 A — Admin 카테고리 관리 화면

### A1. AdminMorePage — "메인 카테고리 관리" ListTile 추가

기존 `admin_more_page.dart` 의 `ListView` 에 타일 1개를 추가한다.

#### 추가 위치

"로그아웃" 타일 위, 목록 최상단. 운영 기능 그룹이 상단에 오고 계정/앱 정보 그룹이 하단에 오는 정보 위계.

```
ListView
  ├─ Padding(fromLTRB 20,4,20,16) — "더보기" 제목
  ├─ [신규] _Tile '메인 카테고리 관리'  ← 추가
  ├─ _Tile '로그아웃'
  └─ _Tile '앱 정보'
```

#### 신규 Tile 명세

기존 `_Tile` 위젯 그대로 재사용:

| 속성 | 값 |
|---|---|
| icon | `Icons.category_rounded` |
| title | `'메인 카테고리 관리'` |
| subtitle | `null` |
| onTap | `Navigator.push → AdminMainCategoryListPage` |
| trailing | `Icons.chevron_right_rounded` (size 18, `AppColors.textMuted`) — onTap 있으면 자동 표시 |

---

### A2. AdminMainCategoryListPage

- 파일: `lib/presentation/admin/menu_categories/admin_main_category_list_page.dart`
- 역할: 메인 카테고리 목록. displayOrder asc 정렬. active 토글 / 편집 / 삭제.

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
| title | `'메인 카테고리 관리'` |
| titleTextStyle | fontSize 17, w700, `AppColors.textHeading` |
| backgroundColor | `AppColors.background` |
| surfaceTintColor | `Colors.transparent` |
| elevation | 0 |
| actions | 없음 |

#### Body

- `ListView.builder` + `Padding(horizontal 16, top 12, bottom 80)`
  - bottom 80: FAB 와 겹치지 않도록 확보
- 데이터: `mainCategoriesAllProvider` (inactive 포함, displayOrder asc)
- 각 항목: `MainCategoryListItem` (하단 명세)
- 항목 간격: `SizedBox(height: 8)`

#### FAB

| 속성 | 값 |
|---|---|
| 배경 | `AppColors.primary` |
| 아이콘 | `Icons.add_rounded`, `AppColors.onPrimary`, size 24 |
| shadow | `AppColors.primary` alpha 0.3, blurRadius 8, offset (0, 4) |
| onTap | `Navigator.push → AdminMainCategoryFormPage(editItem: null)` |
| 위치 | 우하단 (기본 floatingActionButton) |

#### MainCategoryListItem

```
Card
  └─ Padding(horizontal 4, vertical 2)
       └─ ListTile
            ├─ leading: _OrderBadge(displayOrder)
            ├─ title: Text(label)
            ├─ subtitle: _UsageChip(categoryId)  ← "사용 중 N개"
            ├─ trailing: Row
            │              ├─ MainCategoryActiveSwitch(entity)
            │              ├─ SizedBox(width: 4)
            │              └─ PopupMenuButton
            └─ onTap: Navigator.push → AdminMainCategoryFormPage(editItem: entity)
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

**`MainCategoryActiveSwitch`**:

- `Switch.adaptive`
- active=true: `AppColors.primary` (thumbColor), `AppColors.primaryBright` alpha 0.3 (trackColor)
- active=false: `AppColors.textMuted` (thumbColor), `AppColors.surface` (trackColor)
- onChanged:
  - true → false 방향: `MainCategoryDeactivateConfirmDialog` 노출 (B 영역)
  - false → true 방향: 즉시 `ToggleMainCategoryActiveUseCase(id, true)` 호출. 확인 불필요.

**PopupMenuButton**:

- 아이콘: `Icons.more_vert_rounded`, size 20, `AppColors.textMuted`
- 항목:
  - `'편집'` — `Navigator.push → AdminMainCategoryFormPage(editItem: entity)`
  - `'삭제'` — `MainCategoryDeleteDialog` 노출

#### 인터랙션 상세

| 동작 | 반응 |
|---|---|
| ListTile 탭 | `AdminMainCategoryFormPage(editItem: entity)` push |
| Switch 탭 (true→false) | `MainCategoryDeactivateConfirmDialog` 표시. 취소 시 switch 원상복구. 확인 시 토글 실행 |
| Switch 탭 (false→true) | 즉시 토글. SnackBar `'카테고리를 활성화했어요'` |
| PopupMenu '편집' | `AdminMainCategoryFormPage(editItem: entity)` push |
| PopupMenu '삭제' | `MainCategoryDeleteDialog(entity: entity)` 표시 |
| FAB '+' 탭 | `AdminMainCategoryFormPage(editItem: null)` push |

#### 토글 성공/실패 피드백

| 케이스 | 피드백 |
|---|---|
| active=true 성공 | SnackBar `'카테고리를 활성화했어요'` |
| active=false 성공 (DeactivateDialog 확인 후) | SnackBar `'카테고리를 비활성화했어요'` |
| 토글 실패 | SnackBar `'처리에 실패했어요. 다시 시도해주세요'` + switch 원상복구 |

---

### A2 상태별 UI

#### Loading

- 4개 shimmer `MainCategoryListItem` skeleton
- skeleton 구성:
  ```
  Card
    └─ ListTile
         ├─ leading: Container(36×36, radius 8) — shimmer
         ├─ title: Container(너비 120, 높이 14) — shimmer
         └─ subtitle: Container(너비 72, 높이 10) — shimmer
  ```
- shimmer base: `AppColors.surface`, highlight: `AppColors.surfaceElevated`

#### Error

```
Center
  └─ Column (mainAxisSize: min, spacing: 12)
       ├─ Icon(Icons.error_outline_rounded, size 48, AppColors.error)
       ├─ Text('카테고리 목록을 불러오지 못했어요', fontSize 16, w600, AppColors.textHeading)
       ├─ Text('잠시 후 다시 시도해주세요', fontSize 13, AppColors.textMuted)
       └─ TextButton('다시 시도', AppColors.primary)
```

#### Empty

```
Center
  └─ Column (mainAxisSize: min, spacing: 12)
       ├─ Icon(Icons.category_outlined, size 48, AppColors.textMuted)
       ├─ Text('등록된 카테고리가 없어요', fontSize 16, w600, AppColors.textHeading)
       ├─ Text('아래 버튼으로 첫 카테고리를 추가해보세요', fontSize 13, AppColors.textMuted)
       └─ (FAB 가 이미 표시되므로 별도 CTA 버튼 불필요)
```

---

### A3. AdminMainCategoryFormPage

- 파일: `lib/presentation/admin/menu_categories/admin_main_category_form_page.dart`
- 역할: 등록 / 수정 통합 폼. `editItem: MainCategoryEntity?` 로 분기.

#### 레이아웃

```
Scaffold
  ├─ AppBar
  └─ body: SingleChildScrollView
              └─ Padding(horizontal 20, vertical 24)
                   └─ Column (spacing: 20)
                        ├─ [섹션] ID 입력 (등록 모드만 편집 가능)
                        ├─ [섹션] label 입력
                        ├─ [섹션] displayOrder 입력
                        ├─ [섹션] active 스위치
                        ├─ SizedBox(height: 16)
                        └─ [버튼 Row] 취소 / 저장
```

#### AppBar

| 속성 | 값 |
|---|---|
| leading | `Icons.arrow_back_ios_new_rounded` |
| title | 등록: `'카테고리 추가'` / 수정: `'카테고리 수정'` |
| titleTextStyle | fontSize 17, w700, `AppColors.textHeading` |
| backgroundColor | `AppColors.background` |
| elevation | 0 |

#### 섹션 스타일 공통 (`_FormSection`)

```
Column (crossAxisAlignment: start, spacing: 6)
  ├─ Text(라벨, fontSize 12, w600, AppColors.textMuted)
  └─ [입력 위젯]
```

#### ID 입력 섹션

- 라벨: `'카테고리 코드 (ID)'`
- **등록 모드**: `TextFormField` (편집 가능)
  - hint: `'예: coffee, bakery, juice'`
  - helperText: `'영문·숫자, lowerCamelCase, 최대 20자. 등록 후 변경 불가'`
  - helperStyle: fontSize 11, `AppColors.textMuted`
  - maxLength: 20 (counter 표시: true)
  - inputFormatters: 영문·숫자만 허용 (정규식 `[a-zA-Z0-9]`)
  - 배경: `AppColors.surfaceElevated`
  - border: `AppColors.border` → 포커스: `AppColors.primary`
  - 텍스트: `AppColors.textBody`
  - errorStyle: `AppColors.error`
  - 유효성: 비어있으면 `'코드를 입력해주세요'`, 20자 초과 불가 (maxLength 로 차단)
- **수정 모드**: read-only `Container`
  ```
  Container
    ├─ decoration: radius 12, border AppColors.border 1px, background AppColors.surface
    ├─ padding: horizontal 16, vertical 14
    └─ Row
         ├─ Expanded — Text(entity.id, fontSize 15, AppColors.textMuted)
         └─ Icon(Icons.lock_outline_rounded, size 16, AppColors.textMuted)
  ```
  - 하단 helperText: `'등록된 코드는 변경할 수 없어요'`, fontSize 11, `AppColors.textMuted`

#### label 입력 섹션

- 라벨: `'카테고리 이름'`
- `TextFormField`
  - hint: `'예: 커피, 논커피, 디저트'`
  - maxLength: 10 (counter 표시: true)
  - 배경: `AppColors.surfaceElevated`
  - border: `AppColors.border` → 포커스: `AppColors.primary`
  - 유효성: 비어있으면 `'이름을 입력해주세요'`

#### displayOrder 입력 섹션

- 라벨: `'정렬 순서'`
- `TextFormField`
  - hint: `'0, 1, 2 ...'`
  - keyboardType: `TextInputType.number`
  - inputFormatters: 숫자만 허용
  - 배경: `AppColors.surfaceElevated`
  - border: `AppColors.border` → 포커스: `AppColors.primary`
  - helperText: `'숫자가 낮을수록 앞에 표시돼요'`, fontSize 11, `AppColors.textMuted`
  - 유효성: 비어있으면 `'순서를 입력해주세요'`, 음수 불가

#### active 스위치 섹션

```
Row (mainAxisAlignment: spaceBetween)
  ├─ Column (crossAxisAlignment: start)
  │    ├─ Text('활성화', fontSize 15, w500, AppColors.textBody)
  │    └─ Text('비활성화 시 고객 화면과 메뉴 폼에서 숨겨져요', fontSize 12, AppColors.textMuted)
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
- disabled 조건: 폼 유효성 불통과 시 (`AppColors.textMuted` 배경, `AppColors.onPrimary` alpha 0.5 텍스트)
- loading 중: `CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2)` 텍스트 대체
- onTap: `UpsertMainCategoryUseCase` 호출

#### 저장 성공/실패 피드백

| 케이스 | 피드백 |
|---|---|
| 등록 성공 | SnackBar `'카테고리를 추가했어요'` + `Navigator.pop` |
| 수정 성공 | SnackBar `'카테고리를 수정했어요'` + `Navigator.pop` |
| 실패 (중복 ID) | SnackBar `'이미 사용 중인 코드예요. 다른 코드를 입력해주세요'` |
| 실패 (네트워크) | SnackBar `'처리에 실패했어요. 다시 시도해주세요'` |

---

### A4. MainCategoryDeleteDialog

- 파일: `lib/presentation/admin/menu_categories/widgets/main_category_delete_dialog.dart`
- 역할: 카테고리 삭제 확인. 사용 중 여부에 따라 분기.

#### 다이얼로그 공통 스타일

```
Dialog
  └─ Container
       ├─ decoration: radius 16, background AppColors.surfaceElevated
       ├─ padding: 24
       └─ Column (mainAxisSize: min, spacing: 16)
            ├─ [헤더 Row]
            ├─ [본문]
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
            ├─ Text('카테고리 삭제', fontSize 16, w700, AppColors.textHeading)
            └─ Text(entity.label, fontSize 13, AppColors.textMuted)
```

#### 본문 — 케이스 분기

**케이스 1: 사용 중 (usageCount >= 1) — 삭제 차단**

```
Column (spacing: 12)
  ├─ Container (background: AppColors.error alpha 0.08, radius 10, padding 14)
  │    └─ Text
  │         '이 카테고리에 연결된 메뉴가 {N}개 있어요.\n삭제하려면 메뉴를 다른 카테고리로 먼저 이동해주세요.'
  │         fontSize 13, AppColors.textBody
  └─ Text
       '카테고리를 지금 숨기려면 비활성화를 사용하세요.'
       fontSize 12, AppColors.textMuted
```

**케이스 2: 사용 없음 (usageCount == 0) — 삭제 가능**

```
Text
  '이 카테고리를 삭제할까요? 삭제 후에는 되돌릴 수 없어요.'
  fontSize 13, AppColors.textBody
```

**로딩 상태 (usageCount 조회 중)**:

```
Row (spacing: 8)
  ├─ SizedBox(16×16) — CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)
  └─ Text('확인 중...', fontSize 13, AppColors.textMuted)
```

#### 버튼 Row

**케이스 1 (차단)**:

```
Row (spacing: 12)
  ├─ Expanded — OutlinedButton '취소'
  └─ Expanded — ElevatedButton '비활성화로 전환' (AppColors.warning 배경, AppColors.onPrimary 텍스트)
```

"비활성화로 전환" 탭 시: 다이얼로그 닫고 → `ToggleMainCategoryActiveUseCase(id, false)` 호출 → `MainCategoryDeactivateConfirmDialog` 를 **건너뛰고** 직접 비활성화 (이미 삭제 의도에서 전환하는 흐름이므로 재확인 불필요).

> 디자이너 결정: 삭제 시도 → 차단 → "비활성화로 전환" 탭 시 DeactivateConfirmDialog 를 다시 띄우면 UX 가 불필요하게 길어짐. 삭제 다이얼로그가 이미 충분한 의도 확인 역할을 했으므로 직접 비활성화.

**케이스 2 (삭제 가능)**:

```
Row (spacing: 12)
  ├─ Expanded — OutlinedButton '취소'
  └─ Expanded — ElevatedButton '삭제' (AppColors.error 배경, AppColors.onPrimary 텍스트)
```

"삭제" 탭 시: `DeleteMainCategoryUseCase(id)` 호출 → 성공 시 pop + SnackBar `'카테고리를 삭제했어요'`

**버튼 공통 스타일**:

| 속성 | 취소 버튼 | 액션 버튼 |
|---|---|---|
| 배경 | `AppColors.surfaceElevated` | 케이스별 상이 |
| border | `AppColors.border` | 없음 |
| 텍스트 색 | `AppColors.textBody` | `AppColors.onPrimary` |
| fontSize | 14, w600 | 14, w600 |
| borderRadius | 10 | 10 |
| height | 44 | 44 |

---

## 영역 B — MainCategoryDeactivateConfirmDialog (4d Lite 신규)

- 파일: `lib/presentation/admin/menu_categories/widgets/main_category_deactivate_confirm_dialog.dart`
- 역할: admin 이 카테고리 active 를 false 로 토글하기 전 영향 데이터를 보여주는 경고 다이얼로그.
- 진입 지점: `MainCategoryListItem` 의 Switch (true→false), 또는 A4에서 "비활성화로 전환" 탭 시는 **건너뜀** (A4 주석 참조).

### 다이얼로그 구조

```
Dialog
  └─ Container (radius 16, background AppColors.surfaceElevated, padding 24)
       └─ Column (mainAxisSize: min, spacing: 20)
            ├─ [헤더]
            ├─ [영향 데이터 영역]
            ├─ [안내 문구]
            └─ [버튼 Row]
```

### 헤더

```
Row (crossAxisAlignment: start)
  ├─ Icon(Icons.warning_amber_rounded, size 24, AppColors.warning)
  ├─ SizedBox(width: 12)
  └─ Expanded
       └─ Column (crossAxisAlignment: start, spacing: 4)
            ├─ Text('카테고리 비활성화', fontSize 16, w700, AppColors.textHeading)
            └─ Text(entity.label, fontSize 13, w500, AppColors.textMuted)
```

### 영향 데이터 영역

**로딩 상태** (매장 수 / 메뉴 수 fetch 중):

```
Container (background: AppColors.surface, radius 10, padding 16)
  └─ Row (mainAxisAlignment: center, spacing: 8)
       ├─ SizedBox(16×16) — CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)
       └─ Text('영향 범위를 계산하고 있어요...', fontSize 13, AppColors.textMuted)
```

**데이터 표시 상태**:

```
Container (background: AppColors.warning alpha 0.08, radius 10, border: AppColors.warning alpha 0.3 / 1px, padding 16)
  └─ Column (crossAxisAlignment: start, spacing: 8)
       ├─ Text('비활성화하면 영향을 받아요', fontSize 12, w600, AppColors.warning)
       └─ Row (spacing: 24)
            ├─ _ImpactItem(icon: Icons.store_rounded, label: '매장', count: N)
            └─ _ImpactItem(icon: Icons.restaurant_menu_rounded, label: '메뉴', count: M)
```

**`_ImpactItem`**:

```
Column (crossAxisAlignment: start, spacing: 2)
  ├─ Row (spacing: 4)
  │    ├─ Icon(icon, size 14, AppColors.warning)
  │    └─ Text(label, fontSize 11, AppColors.textMuted)
  └─ Text('{count}곳' 또는 '{count}개', fontSize 20, w700, AppColors.textHeading)
```

**N=0, M=0 인 경우**:

```
Container (background: AppColors.surface, radius 10, padding 16)
  └─ Row (spacing: 8)
       ├─ Icon(Icons.check_circle_outline_rounded, size 16, AppColors.success)
       └─ Text('현재 이 카테고리를 사용 중인 메뉴나 매장이 없어요.', fontSize 13, AppColors.textMuted)
```

**에러 상태** (fetch 실패):

```
Container (background: AppColors.surface, radius 10, padding 16)
  └─ Text('영향 범위를 확인하지 못했어요. 계속 진행하면 영향이 있을 수 있어요.', fontSize 13, AppColors.textMuted)
```

### 안내 문구

```
Column (crossAxisAlignment: start, spacing: 6)
  ├─ Text('비활성화하면:', fontSize 12, w600, AppColors.textMuted)
  └─ Column (spacing: 4)
       ├─ _BulletText('고객 화면의 카테고리 탭에서 숨겨져요')
       └─ _BulletText('메뉴 폼에서 이 카테고리에 속한 메뉴에 경고가 표시돼요')
```

**`_BulletText`**:

```
Row (crossAxisAlignment: start, spacing: 6)
  ├─ Text('•', fontSize 12, AppColors.textMuted)
  └─ Expanded — Text(text, fontSize 12, AppColors.textMuted)
```

### 버튼 Row

```
Row (spacing: 12)
  ├─ Expanded — OutlinedButton '취소'
  └─ Expanded — ElevatedButton '비활성화'
```

**취소 버튼**: `AppColors.surfaceElevated` 배경, `AppColors.border` 테두리, `AppColors.textBody` 텍스트, fontSize 14, w600, height 44, radius 10. onTap: pop (switch 원상복구는 호출부 책임)

**비활성화 버튼**: `AppColors.warning` 배경, `AppColors.onPrimary` 텍스트, fontSize 14, w600, height 44, radius 10.
- loading 중 (fetch 미완): disabled + `AppColors.textMuted` 배경
- onTap: pop(confirmed: true) → 호출부에서 `ToggleMainCategoryActiveUseCase(id, false)` 실행

---

## 영역 C — 메뉴 폼 3종 비활성 카테고리 경고 라벨 (4d Lite 신규)

적용 화면:
- `lib/presentation/brand/master_menu/master_menu_form_page.dart`
- `lib/presentation/brand/customization/store_only_menu/brand_store_only_menu_form_page.dart`
- `lib/presentation/owner/store_menu/owner_store_menu_form_page.dart`

### 표시 조건

**수정 모드** (`editItem != null`) + 해당 메뉴의 `mainCategoryCode` 가 `mainCategoriesAllProvider` 결과에서 `active == false` 인 경우.

등록 모드 / 복제 모드: 경고 라벨 표시하지 않음 (active=true 카테고리만 칩에 노출되므로 선택 자체가 불가).

### 경고 라벨 위젯 (`InactiveCategoryWarningBanner`)

- 파일: `lib/presentation/common/widgets/inactive_category_warning_banner.dart`
- 3개 폼 공통으로 재사용.

**위치**: 카테고리 칩 영역 바로 위 (칩 섹션 라벨 텍스트와 칩 사이).

```
Container
  ├─ margin: bottom 8
  ├─ decoration: radius 10, background AppColors.warning alpha 0.10, border AppColors.warning alpha 0.4 / 1px
  ├─ padding: horizontal 14, vertical 10
  └─ Row (crossAxisAlignment: center, spacing: 10)
       ├─ Icon(Icons.warning_amber_rounded, size 18, AppColors.warning)
       └─ Expanded
            └─ Text
                 '이 카테고리는 비활성화되었습니다. 다른 카테고리로 변경해주세요.'
                 fontSize 13, w500, AppColors.textBody
```

### inactive 카테고리 칩 표시 정책

수정 모드에서 현재 메뉴의 `mainCategoryCode` 가 inactive 인 경우, 그 카테고리 칩도 목록에 포함시켜 표시하되 **시각적으로 disabled 처리**한다. 사용자가 다른 카테고리로 변경할 수 있도록 다른 칩들은 정상 선택 가능.

**inactive 카테고리 칩 스타일** (현재 선택 중인 inactive 칩):

| 속성 | 값 |
|---|---|
| 배경 | `AppColors.warning` alpha 0.12 |
| border | `AppColors.warning` alpha 0.5 / 1px |
| 텍스트 색 | `AppColors.warning` |
| 텍스트 | `'{label} (비활성)'` |
| radius | pill (999) |
| 우측 아이콘 | `Icons.warning_amber_rounded`, size 14, `AppColors.warning` |
| onTap | disabled (IgnorePointer 처리) — 비활성 칩은 재선택 불가, 다른 칩으로만 변경 가능 |

**active 카테고리 칩 스타일** (기존 디자인 시스템 동일):
- 선택됨: `AppColors.primary` 배경, `AppColors.onPrimary` 텍스트
- 선택 안 됨: `AppColors.surfaceElevated` 배경, `AppColors.border` 테두리, `AppColors.textBody` 텍스트

### 폼 submit 정책

inactive 카테고리를 그대로 둔 채 저장 **가능**. 저장 차단하지 않는다.

> 디자이너 결정 이유: 점주/브랜드 운영자가 바로 다른 카테고리를 선택할 수 없는 상황(대체 카테고리 미정, 운영 판단 보류)에서 저장 차단은 폼 자체를 벗어나지 못하게 하는 과도한 제약. 경고 라벨로 충분히 인지시키고 저장은 허용. 실제 customer 화면에서는 inactive 카테고리 탭이 숨겨지므로 노출 피해는 없음.

---

## 영역 D — 메뉴 리스트 카드 비활성 marker (designer 결정)

**결정: 적용하지 않음.**

**사유**:

1. **정보 위계 과부하**: 메뉴 리스트 카드는 이미 이름 / 가격 / 이미지 / 품절 상태 등 운영 정보를 표시한다. 비활성 카테고리 marker 를 카드에 추가하면 한 카드에 상태 정보가 중첩되어 시각 노이즈가 심해진다.

2. **운영 빈도**: 카테고리 비활성화는 드문 이벤트다. 비활성 카테고리에 속한 메뉴는 소수이고, 그 상태는 일시적이다 (점주/브랜드가 경고 라벨을 보고 카테고리를 변경하면 해소). 리스트 전체에 marker 를 상시 표시할 실익이 낮다.

3. **접근 경로**: 메뉴 폼(C 영역)에서 수정 모드 진입 시 경고 라벨이 명확히 노출된다. 리스트에서 먼저 인지하는 경로가 없어도 폼 진입 시 즉시 안내된다.

4. **4d Heavy 분리 원칙**: 본 phase 는 passive 알림(화면 진입 시 인지)까지만 포함. 적극적인 리스트 전체 marker 는 Heavy 범위에 준하는 UI 변경으로 판단.

Follow-up 으로 필요 시 카드 좌측 `AppColors.warning` 2px strip 또는 카드 우상단 `Icons.warning_amber_rounded` 아이콘 배지 형태로 추가 검토 가능.

---

## 영역 E — customer MainCategoryTabs 가변 N개 정책

현재: 3개 고정 (`_all` 상수 목록). 이번 변경: `List<MainCategoryEntity>` 를 props 로 받아 동적 렌더링.

### 가로 스크롤 vs 균등 분할 결정

**결정: 가로 스크롤 채택.**

**근거**:
- 기존 3개: `Expanded` 로 균등 분할하면 각 탭 너비 = 화면 1/3. 3개일 때 적절.
- N개 (4개 이상): 균등 분할 유지 시 탭 너비가 좁아져 한글 라벨이 잘리거나 fontSize 축소가 발생함.
- 탭이 5개 이상 추가될 가능성 있음 (admin 이 자유롭게 추가 가능한 구조).
- 가로 스크롤은 N개에 무관하게 각 탭 너비를 일정하게 유지.

### 탭 너비 정책

- 각 탭: `minWidth` 80, 실제 너비는 `max(80, label 너비 + 32)` 방식.
- 전체 탭 합산 너비가 화면 너비 이하이면: 탭들을 `mainAxisAlignment: start` 로 배치 (여백 생겨도 좌정렬. 균등 채우기는 비활성).
- 전체 탭 합산 너비가 화면 너비 초과 시: 가로 스크롤 활성.

> 즉 3개일 때는 기존 균등 분할과 시각적으로 거의 동일하고, N이 늘어도 자연스럽게 스크롤로 전환.

### 스크롤 방식

- `ScrollableTabBar` 또는 `SingleChildScrollView(scrollDirection: Axis.horizontal)` + `Row`
- 스크롤바: 숨김 (`NeverScrollableScrollPhysics` 적용하지 않고, `ScrollbarTheme` 또는 `Scrollbar(thumbVisibility: false)`)
- 선택된 탭이 뷰포트 밖으로 나갔을 때 `scrollController.animateTo()` 로 자동 스크롤 (탭 선택 시 보이도록).

### 탭 스타일 유지

기존 `_Tab` 스타일 그대로 유지:

| 상태 | 스타일 |
|---|---|
| 선택됨 | `AppColors.primary` 텍스트, 2.5px 하단 바 |
| 비선택 | `AppColors.textMuted` 텍스트 |
| disabled (매장 메뉴 없음) | `AppColors.textMuted` alpha 0.4, IgnorePointer |

탭 컨테이너:
- height: 48 (기존 동일)
- border-bottom: `AppColors.border` 1px (기존 동일)
- 배경: `AppColors.background` (기존 동일)

---

## 상태별 UI 총괄

### AdminMainCategoryListPage

| 상태 | 표시 방식 | 문구 |
|---|---|---|
| loading | 4개 shimmer skeleton (ListTile 형태) | — |
| error | 중앙 Icon(error) + 텍스트 + retry 버튼 | `'카테고리 목록을 불러오지 못했어요'` |
| empty | 중앙 Icon(category_outlined) + 텍스트 | `'등록된 카테고리가 없어요'` |
| data | MainCategoryListItem 목록 | — |

### AdminMainCategoryFormPage

| 상태 | 표시 방식 |
|---|---|
| 저장 중 | 저장 버튼 내부 `CircularProgressIndicator` |
| 저장 성공 | SnackBar + pop |
| 저장 실패 | SnackBar (폼 유지) |

### MainCategoryDeactivateConfirmDialog

| 상태 | 표시 방식 |
|---|---|
| loading (fetch 중) | 영향 데이터 영역에 spinner + 비활성화 버튼 disabled |
| 데이터 있음 (N>0 또는 M>0) | warning 톤 컨테이너 + 수치 표시 |
| 데이터 없음 (N=0, M=0) | success 톤 안내 |
| fetch 에러 | 에러 안내 문구 (버튼은 활성 유지 — 경고 충분히 전달했으므로) |

### customer MainCategoryTabs

| 상태 | 표시 방식 |
|---|---|
| loading | 너비 60×16 shimmer bar 3개 (탭 위치에) |
| error | `'분류를 불러올 수 없어요'` + 운영팀 문의 안내 (탭 영역에 작게) |
| empty | `'카테고리가 없습니다'` 텍스트 (탭 영역) |
| data | 동적 탭 |

---

## 인터랙션 정의

| 동작 | 반응 |
|---|---|
| AdminMorePage "메인 카테고리 관리" 탭 | `Navigator.push(AdminMainCategoryListPage)` |
| ListItem 탭 | `Navigator.push(AdminMainCategoryFormPage(editItem: entity))` |
| Switch true→false | `MainCategoryDeactivateConfirmDialog` 표시. 취소: switch 복구. 확인: 토글 실행 |
| Switch false→true | 즉시 토글. SnackBar 확인 |
| PopupMenu '편집' | `Navigator.push(AdminMainCategoryFormPage(editItem: entity))` |
| PopupMenu '삭제' | `MainCategoryDeleteDialog(entity)` 표시 |
| DeleteDialog "비활성화로 전환" | 다이얼로그 닫고 직접 비활성화 (DeactivateConfirmDialog 건너뜀) |
| DeleteDialog "삭제" | `DeleteMainCategoryUseCase` 호출 |
| FormPage "저장" | `UpsertMainCategoryUseCase` 호출. 성공 시 pop |
| FormPage "취소" | `Navigator.pop` |
| DeactivateConfirmDialog "비활성화" | pop(confirmed: true) → 호출부에서 toggle 실행 |
| DeactivateConfirmDialog "취소" | pop(confirmed: false) → switch 원상복구 |
| MainCategoryTabs 탭 선택 | `selectedMainCategoryProvider.select(id)` + 선택 탭 자동 스크롤 |

---

## Figma 대비 변경사항

| 항목 | 기존 / Figma 없음 | Qradar 적용 |
|---|---|---|
| 기존 화면 없음 | — | Qradar 디자인 시스템 + admin_module.md 패턴 신규 적용 |
| MainCategoryTabs 균등 분할 | `Expanded` 3개 고정 | 가로 스크롤 + minWidth 80 탭으로 전환 |
| inactive 카테고리 칩 | 없음 (기존 active=true 3개 고정) | warning 톤 disabled chip + 경고 라벨 추가 |
| 메뉴 리스트 카드 marker | — | 적용하지 않음 (사유: 영역 D 참조) |

---

## 개발자 전달 특이사항

### 카피 확정값

| 위치 | 확정 문구 |
|---|---|
| AdminMorePage 타일 | `'메인 카테고리 관리'` |
| FormPage AppBar (등록) | `'카테고리 추가'` |
| FormPage AppBar (수정) | `'카테고리 수정'` |
| ID 필드 helperText | `'영문·숫자, lowerCamelCase, 최대 20자. 등록 후 변경 불가'` |
| displayOrder helperText | `'숫자가 낮을수록 앞에 표시돼요'` |
| 수정 모드 ID read-only helperText | `'등록된 코드는 변경할 수 없어요'` |
| active 스위치 부설명 | `'비활성화 시 고객 화면과 메뉴 폼에서 숨겨져요'` |
| 등록 성공 SnackBar | `'카테고리를 추가했어요'` |
| 수정 성공 SnackBar | `'카테고리를 수정했어요'` |
| 삭제 성공 SnackBar | `'카테고리를 삭제했어요'` |
| 활성화 성공 SnackBar | `'카테고리를 활성화했어요'` |
| 비활성화 성공 SnackBar | `'카테고리를 비활성화했어요'` |
| 처리 실패 SnackBar | `'처리에 실패했어요. 다시 시도해주세요'` |
| 중복 ID 에러 SnackBar | `'이미 사용 중인 코드예요. 다른 코드를 입력해주세요'` |
| 경고 라벨 (폼 3종) | `'이 카테고리는 비활성화되었습니다. 다른 카테고리로 변경해주세요.'` |
| DeactivateDialog 헤더 | `'카테고리 비활성화'` |
| DeactivateDialog 영향 데이터 라벨 | `'비활성화하면 영향을 받아요'` |
| DeactivateDialog 안내1 | `'고객 화면의 카테고리 탭에서 숨겨져요'` |
| DeactivateDialog 안내2 | `'메뉴 폼에서 이 카테고리에 속한 메뉴에 경고가 표시돼요'` |
| DeactivateDialog loading | `'영향 범위를 계산하고 있어요...'` |
| DeactivateDialog N=0,M=0 | `'현재 이 카테고리를 사용 중인 메뉴나 매장이 없어요.'` |
| DeactivateDialog fetch 실패 | `'영향 범위를 확인하지 못했어요. 계속 진행하면 영향이 있을 수 있어요.'` |
| DeleteDialog 차단 본문 | `'이 카테고리에 연결된 메뉴가 {N}개 있어요.\n삭제하려면 메뉴를 다른 카테고리로 먼저 이동해주세요.'` |
| DeleteDialog 차단 보조 | `'카테고리를 지금 숨기려면 비활성화를 사용하세요.'` |
| DeleteDialog 삭제 가능 본문 | `'이 카테고리를 삭제할까요? 삭제 후에는 되돌릴 수 없어요.'` |
| ListItem empty | `'등록된 카테고리가 없어요'` |
| ListItem empty 부설명 | `'아래 버튼으로 첫 카테고리를 추가해보세요'` |

### 구현 시 주의사항

1. **`_UsageChip` 개별 비동기 로딩**: `MainCategoryListItem` 이 `mainCategoryUsageProvider.family(categoryId)` 를 watch. 각 아이템이 독립적으로 loading/error/data 상태를 가진다. Provider 가 아직 로딩 중이면 shimmer bar 표시.

2. **Switch 원상복구 패턴**: `MainCategoryListItem` 내부에서 `switch.onChanged` 시 `ToggleMainCategoryActiveUseCase` 가 실패하면 즉시 `setState` 로 switch 값을 이전 상태로 되돌려야 한다. 낙관적 UI 업데이트가 아닌 확정 후 업데이트 방식 권장.

3. **DeactivateConfirmDialog 결과 처리**: `showDialog` 의 반환값 `bool?` 로 confirmed 여부를 받는다. `true` 이면 `ToggleMainCategoryActiveUseCase(id, false)` 실행. `null` 또는 `false` 이면 switch 원상복구.

4. **`InactiveCategoryWarningBanner` 공통 위젯**: 3개 폼이 동일 위젯을 재사용한다. `lib/presentation/common/widgets/inactive_category_warning_banner.dart` 에 위치.

5. **inactive 칩 머지 로직**: 수정 모드에서 `mainCategoriesActiveProvider` 결과에 없는 카테고리(inactive)를 `mainCategoriesAllProvider` 에서 찾아 칩 목록에 추가. 이 칩은 `IgnorePointer` 처리 + warning 스타일. 이미 다른 active 카테고리를 선택했으면 inactive 칩 제거해도 무방 (선택 해제 시 재표시 불필요).

6. **MainCategoryTabs 스크롤 컨트롤러**: 선택된 탭이 변경될 때 `ScrollController.animateTo()` 로 해당 탭이 뷰포트 내 중앙에 오도록 자동 스크롤. `duration: 200ms`, `curve: Curves.easeOut` 권장.

7. **DeleteDialog "비활성화로 전환" 분기**: 이 버튼은 `MainCategoryDeactivateConfirmDialog` 를 **띄우지 않고** 직접 `ToggleMainCategoryActiveUseCase(id, false)` 를 호출한다. 삭제 다이얼로그 자체가 충분한 경고를 포함했으므로 추가 confirm 불필요.

8. **`_OrderBadge` displayOrder 0-base**: 화면 표시는 entity.displayOrder 그대로 표시 (0, 1, 2...). 1-base 변환 없음.

9. **폼 3종 submit 정책**: inactive 카테고리를 선택한 상태로 저장 가능. `_canSubmit` 조건에서 카테고리 active 여부를 검사하지 않는다. 경고 라벨만 표시.

10. **admin 첫 진입 시드**: `AdminMainCategoryListPage` 의 `initState` 또는 `ref.watch` 이전에 `seedDefaultsIfEmpty()` 호출. 화면 진입 → 시드 → stream 데이터 도착 흐름이므로 loading 상태가 자연스럽게 표시됨.

### 재사용할 기존 컴포넌트

| 컴포넌트 | 재사용 위치 |
|---|---|
| `admin_more_page.dart` `_Tile` | AdminMorePage 신규 타일 — 동일 위젯 그대로 사용 |
| `AppColors` 토큰 전체 | 신규 모든 화면 |
| 기존 `_Tab` 스타일 | MainCategoryTabs — 스타일 유지, ScrollableTabBar 로 래핑만 변경 |

### 신규 생성이 필요한 공통 위젯

| 위젯 | 파일 위치 |
|---|---|
| `InactiveCategoryWarningBanner` | `lib/presentation/common/widgets/inactive_category_warning_banner.dart` |

### AppColors 토큰 요약 (본 디자인에서 사용한 토큰)

`AppColors.primary`, `AppColors.primaryBright`, `AppColors.onPrimary`, `AppColors.background`, `AppColors.surface`, `AppColors.surfaceElevated`, `AppColors.border`, `AppColors.textHeading`, `AppColors.textBody`, `AppColors.textMuted`, `AppColors.warning`, `AppColors.error`, `AppColors.success`, `AppColors.accent`
