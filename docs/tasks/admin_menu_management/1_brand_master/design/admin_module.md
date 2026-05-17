# Admin 모듈 디자인 명세

> 파일 위치: `lib/presentation/admin/`
> 참조: owner_scaffold.dart (BottomNav 패턴), owner_more_page.dart (_Tile 패턴), common_components.md

---

## 1. AdminScaffold

- 파일: `presentation/admin/admin_scaffold.dart`
- 역할: admin role 사용자의 메인 Scaffold. 2탭 BottomNav (sub-phase 1 기준).

### 탭 구성

| 인덱스 | 라벨 | 아이콘 | 페이지 |
|---|---|---|---|
| 0 | `'승인 큐'` | `Icons.pending_actions_rounded` | `AdminPendingQueuePage` |
| 1 | `'더보기'` | `Icons.more_horiz_rounded` | `AdminMorePage` |

> sub-phase 2/3 에서 탭이 추가될 예정. 현재 2탭 고정.

### Scaffold 스타일

owner_scaffold.dart 와 동일 구조 채택.

- backgroundColor: `AppColors.background`
- extendBody: true
- body: `IndexedStack`

### BottomNav 스타일

```
Container
  ├─ decoration: color AppColors.surface, border-top AppColors.surfaceElevated 1px
  └─ SafeArea (top: false)
       └─ SizedBox (height: 72)
            └─ Row (mainAxisAlignment: spaceAround)
                 └─ [각 탭] _AdminNavItem
```

`_AdminNavItem`:
- 탭 영역: `Expanded` + `GestureDetector (HitTestBehavior.opaque)`
- 아이콘 size: 24
- 활성 아이콘 색: `AppColors.accent`
- 비활성 아이콘 색: `AppColors.textMuted`
- 라벨 fontSize: 11, w500
- 활성 라벨 색: `AppColors.textHeading`
- 비활성 라벨 색: `AppColors.textMuted`
- 아이콘~라벨 gap: 4

---

## 2. AdminPendingQueuePage

- 파일: `presentation/admin/approval/admin_approval_queue_page.dart`
- 역할: 승인 대기 목록. 상단 세그먼트 컨트롤로 브랜드 승인 / 마스터 메뉴 승인 분리.

### 레이아웃

- Scaffold
- 배경: `AppColors.background`
- AppBar:
  - title: `'승인 큐'`, fontSize 17, w700, `AppColors.textHeading`
  - backgroundColor: `AppColors.background`
  - surfaceTintColor: transparent
  - elevation: 0
  - bottom: 세그먼트 탭 바 (`PreferredSize` 래핑)

### 세그먼트 탭 바

```
PreferredSize (preferredSize: Size.fromHeight(44))
  └─ Container (border-bottom AppColors.border 1px)
       └─ Row
            ├─ _SegTab('브랜드 승인', index: 0)
            └─ _SegTab('마스터 메뉴 승인', index: 1)
```

`_SegTab` 스타일:
- `Expanded` + `InkWell`
- 높이: 44
- 선택 상태:
  - 텍스트: `AppColors.primary`, fontSize 14, w700
  - 하단 언더라인: `AppColors.primary` 2px, 너비 전체
- 비선택 상태:
  - 텍스트: `AppColors.textMuted`, fontSize 14, w500
  - 언더라인: 없음
- 배경: `AppColors.background`

### body

- `IndexedStack` (세그먼트에 따라 교체)
  - index 0: `_BrandPendingList`
  - index 1: `_MasterMenuPendingList`

### _BrandPendingList

- `ListView.builder` + `Padding(horizontal 16, vertical 8)`
- 데이터: `WatchPendingBrandsUseCase` stream (submittedAt desc 정렬)
- 각 항목: `_BrandQueueTile`

### _BrandQueueTile

```
Card (AppColors.surfaceElevated, radius 14, border AppColors.border 1px)
  └─ ListTile (contentPadding: horizontal 16 vertical 8)
       ├─ leading: ClipRRect (radius 8, 52×52) ← 브랜드 로고
       ├─ title: Text(브랜드 이름, fontSize 15, w600, AppColors.textHeading)
       ├─ subtitle: Column
       │              ├─ Text('제출: {submittedAt yyyy.MM.dd HH:mm}', fontSize 12, AppColors.textMuted)
       │              └─ (approvedAt != null) Text('수정 대기', fontSize 11, w600, AppColors.warning)
       ├─ trailing: Row
       │              ├─ ApprovalStatusBadge(status)
       │              └─ Icon(Icons.chevron_right_rounded, 18, AppColors.textMuted)
       └─ onTap: Navigator.push → AdminBrandApprovalDetailPage
```

로고 없으면 Placeholder (`AppColors.surface` 배경 + `Icons.storefront_rounded` size 24 `AppColors.textMuted`)

### _MasterMenuPendingList

- `ListView.builder` + `Padding(horizontal 16, vertical 8)`
- 데이터: `WatchPendingMasterMenuItemsUseCase` stream (collectionGroup, submittedAt desc)
- 각 항목: `_MasterMenuQueueTile`

### _MasterMenuQueueTile

```
Card (AppColors.surfaceElevated, radius 14, border AppColors.border 1px)
  └─ ListTile (contentPadding: horizontal 16 vertical 8)
       ├─ leading: ClipRRect (radius 8, 52×52) ← 메뉴 이미지
       ├─ title: Text(메뉴 이름, fontSize 15, w600, AppColors.textHeading)
       ├─ subtitle: Column
       │              ├─ Text('브랜드: {brandId}', fontSize 12, AppColors.textMuted)
       │              ├─ Text('제출: {submittedAt yyyy.MM.dd HH:mm}', fontSize 12, AppColors.textMuted)
       │              └─ (approvedAt != null) Text('수정 대기', fontSize 11, w600, AppColors.warning)
       ├─ trailing: Row
       │              ├─ ApprovalStatusBadge(status)
       │              └─ Icon(Icons.chevron_right_rounded, 18, AppColors.textMuted)
       └─ onTap: Navigator.push → AdminMasterMenuApprovalDetailPage
```

메뉴 이미지 없으면 Placeholder (`AppColors.surface` 배경 + `Icons.local_cafe_outlined` size 24 `AppColors.textMuted`)

### 정렬 기준

- 두 리스트 모두 `submittedAt` 내림차순 (최근 제출이 상단)
- 동일 시각의 경우 `name` 오름차순 (secondary sort)

### 빈 상태

- 각 세그먼트별 Empty 패턴: [common_components.md - Empty](common_components.md)
- 화면별 문구는 common_components.md Empty 표 참조

### 로딩 상태

- 3개 shimmer `_QueueTile` skeleton (leading 52×52 원형 + 텍스트 2줄)
- base: `AppColors.surface`, highlight: `AppColors.surfaceElevated`

### 에러 상태

- collectionGroup 인덱스 누락 케이스 포함 공통 Error 패턴
- 에러 설명: `'데이터를 불러오는 데 실패했어요.\n인덱스 설정이 필요할 수 있습니다.'` (콘솔 안내 로그는 개발자가 추가)

---

## 3. AdminBrandApprovalDetailPage

- 파일: `presentation/admin/approval/admin_brand_approval_detail_page.dart`
- 역할: 브랜드 승인 상세 — 브랜드 정보 + 제출 메타 + 승인/반려 액션

### 레이아웃

- Scaffold
- 배경: `AppColors.background`
- AppBar:
  - leading: `Icons.arrow_back_ios_new_rounded`
  - title: `'브랜드 승인 심사'`, fontSize 17, w700, `AppColors.textHeading`
  - backgroundColor: `AppColors.background`, elevation 0
- body: `SingleChildScrollView`
- bottomNavigationBar: `ApprovalActionsBar` (이미 처리된 경우 숨김 또는 비활성)

### 주요 섹션 (위→아래)

```
Column
  ├─ SizedBox(height: 16)
  ├─ [섹션] 브랜드 로고 + 이름 + status 배지 (강조 형태)
  ├─ SizedBox(height: 16)
  ├─ [섹션] 브랜드 설명
  ├─ SizedBox(height: 16)
  ├─ [섹션] 제출 정보
  ├─ SizedBox(height: 16)
  └─ (rejected 시) [섹션] 기존 반려 사유
```

### 브랜드 로고 + 이름 섹션

```
Padding(horizontal 20)
  └─ Row (crossAxisAlignment: center)
       ├─ ClipRRect (radius 14, 80×80) ← 로고 이미지
       ├─ SizedBox(width: 16)
       └─ Column
            ├─ Text(브랜드 이름, fontSize 22, w700, AppColors.textHeading)
            ├─ SizedBox(height: 8)
            └─ ApprovalStatusBadge (status, 큰 배지 variant)
```

### 브랜드 설명 섹션

```
_AdminDetailSectionCard (horizontal 20)
  └─ Text (description, fontSize 14, AppColors.textBody, 최대 5줄, 넘으면 전체 표시)
```

`_AdminDetailSectionCard`: `Container(AppColors.surfaceElevated, radius 14, border AppColors.border 1px, padding 16, margin horizontal 20)`

### 제출 정보 섹션

```
_AdminDetailSectionCard
  ├─ _InfoRow('제출자 UID', submittedBy)
  ├─ _InfoRow('제출 시각', submittedAt yyyy.MM.dd HH:mm)
  └─ (approvedAt != null) _InfoRow('이전 처리 시각', approvedAt yyyy.MM.dd HH:mm)
```

`_InfoRow`:
- `Row(mainAxisAlignment: spaceBetween)`
- 라벨: fontSize 12, `AppColors.textMuted`
- 값: fontSize 13, w500, `AppColors.textBody`
- padding: vertical 6
- 구분선: `Divider(height: 1, color: AppColors.border)` (마지막 항목 제외)

### 반려 사유 섹션 (현재 rejected 일 때)

```
_AdminDetailSectionCard (border: AppColors.error.withOpacity(0.3) 1px, 배경: AppColors.error.withOpacity(0.04))
  ├─ Row
  │    ├─ Icon(Icons.info_outline_rounded, 16, AppColors.error)
  │    └─ Text '기존 반려 사유', fontSize 13, w600, AppColors.error
  ├─ SizedBox(height: 8)
  └─ Text(rejectedReason, fontSize 13, AppColors.textBody)
```

### ApprovalActionsBar 조건

- `status == pending` → `ApprovalActionsBar` 정상 노출
- `status == approved` → `ApprovalActionsBar` 숨김 + 상단에 `'이미 승인된 브랜드입니다'` informational 뱃지 (backgroundColor: `AppColors.success.withOpacity(0.1)`, 텍스트 `AppColors.success`)
- `status == rejected` → `ApprovalActionsBar` 숨김 + `'반려된 브랜드입니다. 재제출을 기다리세요'` informational 뱃지 (backgroundColor: `AppColors.error.withOpacity(0.1)`, 텍스트 `AppColors.error`)

### 인터랙션

- '승인' 탭:
  1. `ApproveBrandUseCase` 호출
  2. 성공 → SnackBar `'브랜드를 승인했어요'` + `Navigator.pop`
  3. 실패 → SnackBar `'처리에 실패했어요. 다시 시도해주세요'`

- '반려' 탭:
  1. `RejectReasonDialog` 노출
  2. 사유 입력 후 '반려 확정' → `RejectBrandUseCase` 호출
  3. 성공 → SnackBar `'반려 처리되었습니다'` + `Navigator.pop`
  4. 실패 → SnackBar `'처리에 실패했어요. 다시 시도해주세요'`

### 로딩 상태

- body 전체: shimmer skeleton (80×80 원형 + 텍스트 블록 2개)

### 에러 상태

- 공통 Error 패턴: [common_components.md - Error](common_components.md)

---

## 4. AdminMasterMenuApprovalDetailPage

- 파일: `presentation/admin/approval/admin_master_menu_approval_detail_page.dart`
- 역할: 마스터 메뉴 승인 상세 — 메뉴 정보 + 제출 메타 + 승인/반려 액션

### 레이아웃

- Scaffold
- 배경: `AppColors.background`
- AppBar:
  - leading: `Icons.arrow_back_ios_new_rounded`
  - title: `'메뉴 승인 심사'`, fontSize 17, w700, `AppColors.textHeading`
  - backgroundColor: `AppColors.background`, elevation 0
- body: `SingleChildScrollView`
- bottomNavigationBar: `ApprovalActionsBar` (status 조건 동일)

### 주요 섹션 (위→아래)

```
Column
  ├─ [섹션] 메뉴 이미지 (전체 너비, height 200)
  ├─ SizedBox(height: 16)
  ├─ [섹션] 메뉴 이름 + status 배지 + 브랜드 ID
  ├─ SizedBox(height: 8)
  ├─ [섹션] 설명
  ├─ SizedBox(height: 16)
  ├─ [섹션] 가격 + 카테고리 + 태그 + 노출 순서 + visible
  ├─ SizedBox(height: 16)
  ├─ [섹션] 옵션 그룹
  ├─ SizedBox(height: 16)
  ├─ [섹션] 제출 정보
  └─ (rejected 시) [섹션] 기존 반려 사유
```

### 메뉴 이미지 섹션

- `ClipRRect(radius 0)` 전체 너비, height 200
- imageUrl 없으면: `AppColors.surface` 배경 + `Icons.local_cafe_outlined` size 56 `AppColors.textMuted` 중앙

### 메뉴 이름 + status 배지 섹션

```
Padding(horizontal 20)
  └─ Column (crossAxisAlignment: start)
       ├─ Row
       │    ├─ Expanded — Text(메뉴 이름, fontSize 22, w700, AppColors.textHeading)
       │    └─ ApprovalStatusBadge(status, 큰 배지 variant)
       ├─ SizedBox(height: 6)
       └─ Text('브랜드 ID: {brandId}', fontSize 12, AppColors.textMuted)
```

### 메뉴 정보 섹션

`_AdminDetailSectionCard`:
- `_InfoRow('기본가', '₩{basePrice}')` — 가격 bold 처리 (w700)
- `_InfoRow('카테고리', '{mainCategory} > {subCategoryId ?? '없음'}')` 
- `_InfoRow('노출 순서', '{displayOrder}')` 
- `_InfoRow('노출 상태', visible ? '노출 중' : '숨김')` 
- (tags 있으면) 태그 Wrap — 읽기 전용 chip

### 옵션 그룹 섹션

`_AdminDetailSectionCard`:
- 섹션 헤더: `'연결된 옵션 그룹'`, fontSize 13, w600, `AppColors.textMuted`
- 각 옵션 그룹: `ListTile(title: 옵션 그룹 이름, subtitle: '마스터 옵션')` (border `AppColors.border` 1px, radius 8, margin bottom 6)
- 없으면: `'연결된 옵션 그룹 없음'`, `AppColors.textMuted`

### 제출 정보 섹션

`_AdminDetailSectionCard`:
- `_InfoRow('제출자 UID', submittedBy)`
- `_InfoRow('브랜드 ID', brandId)`
- `_InfoRow('제출 시각', submittedAt yyyy.MM.dd HH:mm)`
- `(approvedAt != null)` `_InfoRow('이전 처리 시각', approvedAt yyyy.MM.dd HH:mm)`

### 반려 사유 섹션 (AdminBrandApprovalDetailPage 와 동일 스타일)

### ApprovalActionsBar 조건

- `status == pending` → 정상 노출
- `status == approved` → 숨김 + `'이미 승인된 메뉴입니다'` informational 뱃지 (`AppColors.success` 톤)
- `status == rejected` → 숨김 + `'반려된 메뉴입니다. 재제출을 기다리세요'` informational 뱃지 (`AppColors.error` 톤)

informational 뱃지 스타일 (AdminBrandApprovalDetailPage 와 동일 — approved=success / rejected=error 통일):
- `Container(color.withOpacity(0.1), radius 10, padding horizontal 16 vertical 10)`
- 텍스트: 같은 `color` (success 또는 error), fontSize 13, w500, 중앙 정렬
- margin: horizontal 20, bottom 16

### 인터랙션

- AdminBrandApprovalDetailPage 와 동일 패턴
- '승인' → `ApproveMasterMenuItemUseCase` + SnackBar `'메뉴를 승인했어요'` + pop
- '반려' → `RejectReasonDialog` → `RejectMasterMenuItemUseCase` + SnackBar `'반려 처리되었습니다'` + pop

### 로딩 상태

- body 전체: shimmer skeleton (전체 너비 height 200 박스 + 텍스트 블록 3개)

### 에러 상태

- 공통 Error 패턴: [common_components.md - Error](common_components.md)

---

## 5. AdminMorePage

- 파일: `presentation/admin/more/admin_more_page.dart`
- 역할: placeholder. 로그아웃 / 앱 정보만 제공.

### 레이아웃

- Scaffold → `SafeArea` → `ListView`
- padding: `EdgeInsets.symmetric(vertical: 24)`
- 배경: `AppColors.background`
- owner_more_page.dart `_Tile` 패턴 동일하게 재사용

### 항목

```
ListView
  ├─ Padding(fromLTRB 20,4,20,16) — Text '더보기' (fontSize 20, w700, AppColors.textHeading)
  ├─ _Tile '로그아웃' (icon: Icons.logout_rounded, onTap: signOut)
  └─ _Tile '앱 정보' (icon: Icons.info_outline_rounded, subtitle: 'Qradar v0.1.0')
```

`_Tile` 스타일: owner_more_page.dart 동일 — 별도 구현 없이 공통 위젯으로 추출하거나 동일 코드 복사 허용.
