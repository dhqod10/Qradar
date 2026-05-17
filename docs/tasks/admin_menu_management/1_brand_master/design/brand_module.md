# Brand 모듈 디자인 명세

> 파일 위치: `lib/presentation/brand/`
> 참조: Phase 1a design.md (메뉴 폼 톤), owner_scaffold.dart (BottomNav 패턴), owner_more_page.dart (_Tile 패턴)

---

## 1. BrandScaffold

- 파일: `presentation/brand/brand_scaffold.dart`
- 역할: brand role 사용자의 메인 Scaffold. 3탭 BottomNav.
- 탭 구성 (sub-phase 1 기준):

| 인덱스 | 라벨 | 아이콘 | 페이지 |
|---|---|---|---|
| 0 | `'브랜드 정보'` | `Icons.storefront_rounded` | `BrandInfoPage` |
| 1 | `'마스터 메뉴'` | `Icons.menu_book_rounded` | `MasterMenuListPage` |
| 2 | `'더보기'` | `Icons.more_horiz_rounded` | `BrandMorePage` |

> 매장 탭은 sub-phase 3 에서 인덱스 2 에 삽입 (더보기는 인덱스 3 으로 이동).

### Scaffold 스타일

- backgroundColor: `AppColors.background`
- extendBody: true (BottomNav 투명 처리로 콘텐츠 확장)
- body: `IndexedStack` (탭 간 상태 유지)

### BottomNav 스타일

owner_scaffold.dart `_OwnerBottomNav` 동일 패턴 적용.

```
Container
  ├─ decoration: color AppColors.surface, border-top AppColors.surfaceElevated 1px
  └─ SafeArea (top: false)
       └─ SizedBox (height: 72)
            └─ Row (mainAxisAlignment: spaceAround)
                 └─ [각 탭] _BrandNavItem
```

`_BrandNavItem`:
- 탭 영역: `Expanded` + `GestureDetector (HitTestBehavior.opaque)`
- 아이콘 size: 24
- 활성 아이콘 색: `AppColors.accent`
- 비활성 아이콘 색: `AppColors.textMuted`
- 라벨 fontSize: 11, w500
- 활성 라벨 색: `AppColors.textHeading`
- 비활성 라벨 색: `AppColors.textMuted`
- 아이콘~라벨 gap: 4

### _BrandIdMissingView

- brandId == null 케이스 → body 전체를 공통 컴포넌트 `_BrandIdMissingView` 로 교체 (BottomNav 숨김)
- 상세 스펙: [common_components.md - 권한 없음](common_components.md)

---

## 2. BrandInfoPage

- 파일: `presentation/brand/brand_info/brand_info_page.dart`
- 역할: 본인 브랜드의 현재 상태(로고/이름/설명/status) 표시 + 수정 진입

### 레이아웃

- Scaffold → `CustomScrollView`
- 배경: `AppColors.background`
- SafeArea: top/bottom 모두 적용
- AppBar: `SliverAppBar` (pinned: false, floating: true)
  - title: `'브랜드 정보'`, fontSize 17, w700, `AppColors.textHeading`
  - backgroundColor: `AppColors.background`
  - surfaceTintColor: transparent
  - elevation: 0
  - actions: 수정 버튼 (`Icons.edit_rounded` 또는 `TextButton '수정'`)

### 주요 섹션 (위→아래)

1. **브랜드 카드** — 로고 + 이름 + 설명 + status 배지
2. **제출 정보 섹션** — 제출일 / 처리일 (approved / rejected 일 때)
3. **반려 사유 섹션** — `rejected` 상태일 때만 노출

### 브랜드 카드 상세

```
Card (AppColors.surfaceElevated, radius 16, border AppColors.border 1px)
  └─ Padding (16)
       └─ Column
            ├─ Row
            │    ├─ ClipRRect (radius 12, size 72×72)  ← 브랜드 로고 이미지
            │    │    └─ [imageUrl 있으면] Image.network / [없으면] Placeholder
            │    ├─ SizedBox(width: 16)
            │    └─ Expanded
            │         ├─ Text (브랜드 이름, fontSize 18, w700, AppColors.textHeading)
            │         ├─ SizedBox(height: 6)
            │         └─ ApprovalStatusBadge (status)
            ├─ SizedBox(height: 16)
            ├─ Divider (AppColors.border, height: 1)
            ├─ SizedBox(height: 16)
            └─ Text (설명, fontSize 14, w400, AppColors.textBody)
```

로고 Placeholder:
- 배경: `AppColors.surface`, radius 12
- 아이콘: `Icons.storefront_rounded`, size 32, `AppColors.textMuted`

### 제출 정보 섹션

- 배경: `AppColors.surfaceElevated`, radius 12, border `AppColors.border` 1px, padding 16
- 항목: `_InfoRow(label, value)` 패턴 (owner_more_page _Tile 에서 가져온 row 형태)
  - 라벨: fontSize 12, `AppColors.textMuted`
  - 값: fontSize 13, w500, `AppColors.textBody`
- 표시 항목: `'제출일'` + `'담당자 UID'` (approvedBy) + `'처리일'`
- submittedAt/approvedAt 포맷: `'yyyy.MM.dd HH:mm'`

### 반려 사유 섹션 (rejected 시)

```
Container (배경 AppColors.error.withOpacity(0.06), radius 12, border AppColors.error.withOpacity(0.3) 1px, padding 16)
  └─ Column
       ├─ Row
       │    ├─ Icon(Icons.info_outline_rounded, size 16, AppColors.error)
       │    └─ Text '반려 사유', fontSize 13, w600, AppColors.error
       ├─ SizedBox(height: 8)
       └─ Text (rejectedReason, fontSize 13, AppColors.textBody)
```

### 수정 버튼

- AppBar action: `TextButton('수정')` 또는 `IconButton(Icons.edit_rounded)`
- 텍스트: `AppColors.primary`, fontSize 14, w600
- 탭 → `Navigator.push` → `BrandFormPage(brand: currentBrand)` (수정 모드)
- `pending` 상태일 때도 수정 진입 가능 (재제출 시 pending 유지)

### 빈 상태 (브랜드 미등록)

- 공통 컴포넌트 Empty 패턴 사용: [common_components.md - Empty](common_components.md)
- 화면 전체를 empty 뷰로 교체 (카드 없이)
- CTA '브랜드 등록하기' 탭 → `BrandFormPage(brand: null)` (등록 모드)

### 로딩 상태

- 브랜드 카드 전체: shimmer skeleton (72×72 원형 + 텍스트 3줄 형태)
- base: `AppColors.surface`, highlight: `AppColors.surfaceElevated`

### 에러 상태

- 공통 Error 패턴: [common_components.md - Error](common_components.md)

---

## 3. BrandFormPage

- 파일: `presentation/brand/brand_info/brand_info_form_page.dart`
- 역할: 브랜드 등록(brand == null) / 수정(brand != null) 통합 폼

### 레이아웃

- Scaffold
- 배경: `AppColors.background`
- AppBar:
  - leading: `Icons.close_rounded` (등록 모드) / `Icons.arrow_back_ios_new_rounded` (수정 모드)
  - title: `'브랜드 등록'` / `'브랜드 수정'`
  - backgroundColor: `AppColors.background`, elevation 0
- body: `SingleChildScrollView` + `Padding(horizontal 20)`
- bottomNavigationBar: 제출 버튼 (고정)

### 폼 섹션 (위→아래)

```
Column
  ├─ SizedBox(height: 24)
  ├─ [섹션] 브랜드 로고
  ├─ SizedBox(height: 24)
  ├─ [섹션] 브랜드 이름
  ├─ SizedBox(height: 16)
  ├─ [섹션] 브랜드 소개 (한 줄)
  ├─ SizedBox(height: 16)
  ├─ [섹션] 브랜드 설명
  └─ SizedBox(height: 40) ← 하단 버튼 여백
```

#### 섹션 제목 패턴

- fontSize 13, fontWeight w600, `AppColors.textMuted`
- margin bottom: 8

#### 브랜드 로고 섹션

- `ImageUploadField` (브랜드 로고 variant, height 160×160 정사각)
- 상세: [common_components.md - ImageUploadField](common_components.md)

#### 브랜드 이름 필드

- TextFormField
- maxLength: 30 (카운터 표시)
- 배경: `AppColors.surfaceElevated`
- border: `AppColors.border`, radius 10
- 포커스 border: `AppColors.primary`
- hint: `'브랜드 이름을 입력해주세요'`, `AppColors.textMuted`
- 텍스트: `AppColors.textBody`, fontSize 15
- validation: 공백 시 `'이름을 입력해주세요'` (제출 시점에 체크)

#### 브랜드 소개 (한 줄) 필드

- TextFormField (maxLines: 1)
- maxLength: 60
- hint: `'한 줄 소개를 입력해주세요'`, `AppColors.textMuted`
- 나머지 스타일 동일

#### 브랜드 설명 필드

- TextFormField (maxLines: 5, minLines: 3)
- hint: `'브랜드 설명을 입력해주세요'`, `AppColors.textMuted`
- 나머지 스타일 동일

### 하단 제출 버튼

```
Container (bottomNavigationBar)
  └─ SafeArea (top: false)
       └─ Padding (horizontal 20, vertical 12)
            └─ SizedBox (width: 전체, height: 52)
                 └─ ElevatedButton '제출 (검토 요청)'
```

- 활성:
  - 배경: `AppColors.primary`
  - 텍스트: `AppColors.onPrimary`, fontSize 16, w700
  - radius: 14
- 비활성 (필수 항목 미충족 — 이름 또는 로고 없음):
  - 배경: `AppColors.surface`
  - 텍스트: `AppColors.textMuted`, fontSize 16, w700
  - border: `AppColors.border` 1px
- 로딩 (제출 중):
  - 배경: `AppColors.primary`
  - `SizedBox(20×20) CircularProgressIndicator` (color: `AppColors.onPrimary`, strokeWidth: 2)

### 인터랙션

- 필수: 로고 이미지 + 브랜드 이름 → 충족 시 버튼 활성
- 미충족 시 탭 → `ScaffoldMessenger SnackBar('이름과 로고 이미지를 모두 입력해주세요')`
- 충족 후 탭:
  1. 이미지 업로드 (진행 중 버튼 로딩)
  2. `UpsertBrandUseCase` 호출 → status = pending
  3. 성공 → SnackBar `'검토 요청을 보냈어요'` + `Navigator.pop`
  4. 실패 → SnackBar `'저장에 실패했어요. 다시 시도해주세요'`

---

## 4. MasterMenuListPage

- 파일: `presentation/brand/master_menu/master_menu_list_page.dart`
- 역할: 브랜드의 마스터 메뉴 목록 노출 + CRUD 진입

### 레이아웃

- Scaffold
- 배경: `AppColors.background`
- AppBar:
  - title: `'마스터 메뉴'`, fontSize 17, w700, `AppColors.textHeading`
  - backgroundColor: `AppColors.background`, elevation 0
  - actions: `IconButton(Icons.add_rounded, size 26, AppColors.primary)` → MasterMenuFormPage (등록 모드)
- body: `ListView.builder` (단일 컬럼 리스트, 카드 형태)
- padding: EdgeInsets.fromLTRB(16, 8, 16, 100) (하단 BottomNav 여백)

> 그리드 vs 리스트 결정: **리스트(단일 컬럼)** 채택. status 배지 / 설명 / 가격 / 액션 버튼이 많아 그리드보다 리스트가 정보 밀도 면에서 유리.

### MasterMenuItemCard

```
Card (AppColors.surfaceElevated, radius 16, border AppColors.border 1px, shadow AppColors.primary alpha 0.04)
  └─ Padding (12)
       └─ Row
            ├─ ClipRRect (radius 10, 72×72) ← 메뉴 이미지
            ├─ SizedBox(width: 12)
            └─ Expanded
                 ├─ Row
                 │    ├─ Expanded — Text (메뉴 이름, fontSize 15, w700, AppColors.textHeading)
                 │    └─ ApprovalStatusBadge (status, isRevision: approvedAt != null)
                 ├─ SizedBox(height: 4)
                 ├─ Text (설명 1줄 truncate, fontSize 13, AppColors.textMuted, maxLines:1, overflow:ellipsis)
                 ├─ SizedBox(height: 8)
                 ├─ Row
                 │    ├─ Text (기본가 '₩{basePrice}', fontSize 14, w600, AppColors.textHeading)
                 │    └─ Spacer
                 │    └─ _CardActions (복제 / 편집)
                 └─ (tags 있으면) Wrap — TagChip (읽기 전용, 작은 크기)
```

메뉴 이미지 Placeholder:
- 배경: `AppColors.surface`
- 아이콘: `Icons.local_cafe_outlined`, size 28, `AppColors.textMuted`

#### _CardActions (복제 / 편집 아이콘)

- `Row` (gap 4)
- 복제: `IconButton(Icons.copy_rounded, size 20, AppColors.textMuted)` → `MasterMenuFormPage(clone: true, source: item)`
- 편집: `IconButton(Icons.edit_rounded, size 20, AppColors.primary)` → `MasterMenuFormPage(item: item)`

#### Long-press 인터랙션

- 카드 long-press → `BottomSheet` 또는 `showModalBottomSheet` 로 액션 메뉴 노출:
  - `'편집'` → 편집 폼 진입
  - `'복제'` → 복제 폼 진입
  - `'삭제'` (red, AppColors.error) → 삭제 확인 다이얼로그

#### 카드 탭 (단순 탭)

- `MasterMenuDetailPage` 로 이동

### 빈 상태

- 공통 Empty 패턴: [common_components.md - Empty](common_components.md)

### 로딩 상태

- 3개 shimmer 카드 skeleton (72×72 사각 + 텍스트 3줄 형태)

### 에러 상태

- 공통 Error 패턴: [common_components.md - Error](common_components.md)

---

## 5. MasterMenuFormPage

- 파일: `presentation/brand/master_menu/master_menu_form_page.dart`
- 역할: 마스터 메뉴 등록(item == null) / 수정(item != null) / 복제(clone: true, source: item) 통합 폼
- 복제 모드: `source` 를 prefill. id='', name='{원본 이름} 복사', status=null, 승인 메타 reset

### 레이아웃

- Scaffold
- 배경: `AppColors.background`
- AppBar:
  - leading: `Icons.close_rounded` (등록/복제 모드) / `Icons.arrow_back_ios_new_rounded` (수정 모드)
  - title: `'메뉴 등록'` / `'메뉴 수정'` / `'메뉴 복제'`
  - backgroundColor: `AppColors.background`, elevation 0
- body: `SingleChildScrollView` + `Padding(horizontal 20)`
- bottomNavigationBar: 제출 버튼 (고정)

### 폼 섹션 (위→아래)

```
Column
  ├─ SizedBox(height: 16)
  ├─ [섹션] 메뉴 이미지
  ├─ _SectionDivider
  ├─ [섹션] 기본 정보 (이름 / 설명)
  ├─ _SectionDivider
  ├─ [섹션] 가격
  ├─ _SectionDivider
  ├─ [섹션] 카테고리
  ├─ _SectionDivider
  ├─ [섹션] 태그
  ├─ _SectionDivider
  ├─ [섹션] 메뉴 노출
  ├─ _SectionDivider
  ├─ [섹션] 노출 순서
  ├─ _SectionDivider
  ├─ [섹션] 옵션 그룹
  └─ SizedBox(height: 40)
```

`_SectionDivider`: `Divider(height: 32, color: AppColors.border, thickness: 1)`

#### 섹션 헤더 패턴

- fontSize 13, w600, `AppColors.textMuted`, padding bottom 10

#### 메뉴 이미지 섹션

- `ImageUploadField` (메뉴 이미지 variant, height 180)
- 상세: [common_components.md - ImageUploadField](common_components.md)

#### 기본 정보 섹션

- 이름 필드: maxLength 40, 필수
  - hint: `'메뉴 이름을 입력해주세요'`
- 설명 필드: maxLines 3, minLines 2, 선택
  - hint: `'메뉴 설명을 입력해주세요 (선택)'`
- 스타일: BrandFormPage 입력창 패턴 동일

#### 가격 섹션

- TextFormField (keyboardType: number)
- prefix: `Text('₩ ', fontSize 15, AppColors.textMuted)`
- hint: `'0'`
- 필수 (0보다 큰 값)

#### 카테고리 섹션

메인 카테고리 선택:
```
Wrap (spacing 8)
  └─ [각 mainCategory] FilterChip 스타일 (TagChipsSelector 패턴 동일)
```
메인 카테고리 목록: `'커피'`, `'논커피'`, `'에이드'`, `'스무디'`, `'티'`, `'기타'`
- 단일 선택 (선택된 것 하나만 primary, 나머지 비활성)

서브 카테고리 선택 (mainCategory 선택 후 노출):
- `DropdownButtonFormField<String>` 또는 chip 그룹
- hint: `'서브 카테고리 (선택)'`
- 배경: `AppColors.surfaceElevated`, border `AppColors.border`, radius 10

#### 태그 섹션

- `TagChipsSelector` 위젯 사용
- 상세: [common_components.md - TagChipsSelector](common_components.md)

#### 메뉴 노출 섹션

- `VisibilityToggle` 위젯 사용
- 상세: [common_components.md - VisibilityToggle](common_components.md)

#### 노출 순서 섹션

- TextFormField (keyboardType: number)
- hint: `'0'`
- 도움말: `'숫자가 낮을수록 앞에 노출됩니다'`, fontSize 12, `AppColors.textMuted`

#### 옵션 그룹 섹션

- `OptionGroupSelector` 위젯 사용
- 상세: [common_components.md - OptionGroupSelector](common_components.md)
- S2 가드: store scope 옵션 미노출

### 하단 제출 버튼

- BrandFormPage 동일 패턴
- 활성 조건: 이미지 + 이름 + 가격(>0) + mainCategory 선택 완료
- 버튼 텍스트: `'제출 (검토 요청)'`
- 수정 모드 재제출: SnackBar `'수정 사항이 검토 대기 중입니다'`
- 등록/복제 모드: SnackBar `'검토 요청을 보냈어요'`
- 두 경우 모두 `Navigator.pop` 으로 목록 복귀

### priceOverride 보존 알림 다이얼로그 (수정 모드 + 가격 변경 시)

- 저장 전 `CountStoresUsingPriceOverrideUseCase` 결과(N) 확인 후 표시
- 현재 N=0 이어도 다이얼로그 표시 (spec S8)
- 스타일: RejectReasonDialog 와 동일 radius/배경 (radius 16, `AppColors.surfaceElevated`)
- 내용:
  - title: `'가격 변경 안내'`, fontSize 16, w700, `AppColors.textHeading`
  - content: `'현재 N개 매장에 가격 재정의가 적용되어 있습니다.\n이 메뉴를 수정하면 해당 매장에 영향이 없습니다.'` (N=0 이면 `'현재 적용 중인 매장이 없습니다.'`)
  - 버튼: `TextButton('취소')` / `ElevatedButton('확인 후 제출', AppColors.primary)`

---

## 6. MasterMenuDetailPage

- 파일: `presentation/brand/master_menu/master_menu_detail_page.dart`
- 역할: 마스터 메뉴 상세 읽기 전용 뷰 + 수정 / 복제 / 삭제 진입

### 레이아웃

- Scaffold
- 배경: `AppColors.background`
- AppBar:
  - leading: `Icons.arrow_back_ios_new_rounded`
  - title: 메뉴 이름 (fontSize 16, w700, `AppColors.textHeading`, overflow: ellipsis)
  - backgroundColor: `AppColors.background`, elevation 0
  - actions: `PopupMenuButton` (⋮ 아이콘)
    - 항목: `'수정'` / `'복제'` / `'삭제'` (색: `AppColors.error`)
- body: `SingleChildScrollView`

### 주요 섹션 (위→아래)

1. **이미지 영역** — 전체 너비, height 220, `ClipRRect(radius 0)` (상단 AppBar 이어지는 느낌)
   - imageUrl 없으면: `AppColors.surface` 배경 + `Icons.local_cafe_outlined` size 56 `AppColors.textMuted` 중앙
2. **상태 + 기본 정보 섹션**
3. **카테고리 / 태그 섹션**
4. **가격 섹션**
5. **옵션 그룹 섹션**
6. **제출 메타 섹션** (submittedAt / approvedAt / rejectedReason)
7. **반려 사유 섹션** (rejected 시)

### 상태 + 기본 정보 섹션

```
Padding(16)
  └─ Column
       ├─ Row
       │    ├─ Expanded — Text(이름, fontSize 20, w700, AppColors.textHeading)
       │    └─ ApprovalStatusBadge(status, isRevision)
       ├─ SizedBox(height: 8)
       └─ Text(설명, fontSize 14, AppColors.textBody)
```

### 카테고리 / 태그 섹션

```
_DetailSectionCard
  ├─ _InfoRow('카테고리', '$mainCategory > $subCategory')
  ├─ _InfoRow('노출 순서', '$displayOrder')
  ├─ _InfoRow('메뉴 노출', visible ? '노출 중' : '숨김')
  └─ (tags 있으면) Wrap — TagChip (읽기 전용)
```

`_DetailSectionCard`: `Container(AppColors.surfaceElevated, radius 12, border AppColors.border 1px, padding 16, margin horizontal 16)`

### 가격 섹션

```
_DetailSectionCard
  └─ Row
       ├─ Text('기본가', fontSize 13, AppColors.textMuted)
       └─ Text('₩{basePrice}', fontSize 18, w700, AppColors.textHeading)
```

### 옵션 그룹 섹션

- 선택된 옵션 그룹 리스트 (읽기 전용)
- 각 항목: `ListTile` (title: 옵션 그룹 이름, subtitle: `'마스터 옵션'`, trailing: 없음)
- 옵션 그룹 없으면: `'선택된 옵션 그룹 없음'`, fontSize 13, `AppColors.textMuted`

### 액션 (PopupMenuButton)

- `'수정'` → `MasterMenuFormPage(item: item)` push
- `'복제'` → `CloneMasterMenuItemUseCase` → `MasterMenuFormPage(clone: true, source: clonedItem)` push
- `'삭제'` → 삭제 확인 다이얼로그

### 삭제 확인 다이얼로그

- 스타일: radius 16, `AppColors.surfaceElevated` 배경
- title: `'메뉴를 삭제할까요?'`, fontSize 16, w700
- content: `'이 메뉴를 삭제하면 N개 매장에서 제거됩니다.'` (N=0 이면 `'현재 연결된 매장이 없습니다.'`)
- 버튼: `TextButton('취소')` / `ElevatedButton('삭제', AppColors.error 배경, AppColors.onPrimary 텍스트)`
- 삭제 성공: SnackBar `'메뉴가 삭제되었습니다'` + `Navigator.pop` (상세 페이지 pop)

---

## 7. BrandMorePage

- 파일: `presentation/brand/more/brand_more_page.dart`
- 역할: 로그아웃 / 앱 정보 placeholder. owner_more_page.dart `_Tile` 패턴 그대로 재사용.

### 레이아웃

- Scaffold → `SafeArea` → `ListView`
- padding: `EdgeInsets.symmetric(vertical: 24)`
- 배경: `AppColors.background`

### 항목

```
ListView
  ├─ Padding(fromLTRB 20,4,20,16) — Text '더보기' (fontSize 20, w700, AppColors.textHeading)
  ├─ _Tile '로그아웃' (icon: Icons.logout_rounded, onTap: signOut)
  └─ _Tile '앱 정보' (icon: Icons.info_outline_rounded, subtitle: 'Qradar v0.1.0')
```

`_Tile` 스타일: owner_more_page.dart 동일 (`ListTile` + `chevron_right_rounded` trailing, `AppColors.textDark` title, `AppColors.textMuted` subtitle)
