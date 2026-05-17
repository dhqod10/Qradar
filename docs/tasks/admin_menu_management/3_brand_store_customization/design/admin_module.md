# Admin 모듈 디자인 명세 — sub-phase 3 (brand_store_customization)

> 파일 위치: `lib/presentation/admin/approval/`
> 참조: sub-phase 1 `admin_module.md`, sub-phase 2 `admin_module.md`, designer_guide.md

---

## 디자인 결정사항 요약

- **AdminApprovalQueuePage 4탭 확장 (U1)**: AppBar 타이틀을 `'승인'` 으로 통일하고 세그먼트 라벨은 짧게 — `'브랜드'` / `'메뉴'` / `'매장'` / `'매장 커스텀'`. 기존 탭 위치 변경 없음. 사용자 결정으로 라벨 일관성 + 가독성 모두 확보.
- **매장 커스텀 탭 본문 구조**: 탭 본문 상단에 inline sub-segment (가격 오버라이드 / 점포 한정 메뉴) 고정 Row 배치. AppBar PreferredSize 중첩 미채택 — 이유: 2-depth AppBar 는 모바일 공간을 과도하게 소비하고, 탭 내부 sub-segment 방식이 시각적으로 충분히 구분된다.
- **AdminPendingStoresPage 브랜드 매장 카드 분기**: sub-phase 2 와 동일 파일에 `store.brandId != null` 분기 추가 (`StoreScopeBadge.brand(brandName)`).
- **AdminStoreApprovalDetailPage 브랜드 매장 케이스**: 매장 승인 상세에 활성 마스터 메뉴 chip 리스트 섹션 추가.

---

## 1. AdminApprovalQueuePage (수정 — AppBar 타이틀 통일 + 세그먼트 4탭화)

- 파일: `presentation/admin/approval/admin_approval_queue_page.dart`
- 변경 1: **AppBar 타이틀 `'승인'` 으로 통일** (sub-phase 2 까지의 `'관리자 승인 큐'` 등에서 변경)
- 변경 2: 세그먼트 탭 바 라벨 4개 모두 짧은 단어로 통일 (`'브랜드'` / `'메뉴'` / `'매장'` / `'매장 커스텀'`) + 매장 커스텀 탭 인덱스 3 신규 추가

### AppBar

- title: `'승인'`, fontSize 17, w700, `AppColors.textHeading`
- 4탭 모두 "OO 승인" 의미를 AppBar 타이틀이 흡수하므로 세그먼트는 카테고리 키워드만.

### 세그먼트 탭 바 (4탭, 짧은 라벨)

```
PreferredSize (preferredSize: Size.fromHeight(44))
  └─ Container (border-bottom: AppColors.border 1px)
       └─ Row
            ├─ _SegTab('브랜드', index: 0)          ← 기존 라벨에서 '승인' 제거
            ├─ _SegTab('메뉴', index: 1)             ← 기존 '마스터 메뉴 승인' 단축
            ├─ _SegTab('매장', index: 2)             ← 기존 '매장 승인' 단축
            └─ _SegTab('매장 커스텀', index: 3)      ← 신규 추가
```

`_SegTab` 스타일: sub-phase 1 / 2 동일 (선택 = `AppColors.primary` w600 + 2px 언더라인 / 비선택 = `AppColors.textMuted` w500).

라벨이 짧아져 fontSize 14 유지 가능 (기존 13 으로 줄였던 결정 번복).

### body — IndexedStack 확장

```
IndexedStack
  ├─ index 0: _BrandPendingList               ← 기존 그대로
  ├─ index 1: _MasterMenuPendingList          ← 기존 그대로
  ├─ index 2: AdminPendingStoresPage          ← sub-phase 2 그대로 (브랜드 매장 분기 보강 포함)
  └─ index 3: _StoreCustomizationSection      ← 신규 (sub-segment 포함 위젯)
```

### pending count 뱃지

sub-phase 1/2 의 BadgedSegmentControl 패턴과 동일하게 매장 커스텀 탭에도 pending count 뱃지 노출.
count = `pendingOverrides.length + pendingBrandStoreItems.length` (두 큐 합산).

뱃지 스타일:
- 배경: `AppColors.warning`, radius: 999
- 텍스트: `AppColors.onPrimary`, fontSize 10, w700
- 위치: 라벨 텍스트 우측 상단

---

## 2. _StoreCustomizationSection (매장 커스텀 탭 본문)

- 역할: 매장 커스텀 탭(index 3)의 본문. 내부에 sub-segment Row + IndexedStack.
- 최상위: `Widget` (AdminApprovalQueuePage IndexedStack 의 자식 — Scaffold 없음)

### 레이아웃

```
Column (crossAxisAlignment: stretch)
  ├─ _CustomizationSubSegmentBar   ← sub-segment Row (가격 오버라이드 / 점포 한정 메뉴)
  └─ Expanded
       └─ IndexedStack
            ├─ index 0: AdminPendingMenuOverridesPage
            └─ index 1: AdminPendingBrandStoreItemsPage
```

### _CustomizationSubSegmentBar

```
Container
  ├─ color: AppColors.background
  ├─ border-bottom: AppColors.border 0.5px
  └─ Row (height: 40)
       ├─ _SubSegTab('가격 오버라이드', index: 0)
       └─ _SubSegTab('점포 한정 메뉴', index: 1)
```

`_SubSegTab` 스타일:
- `Expanded` + `InkWell`
- 높이: 40 (메인 세그먼트 44 보다 작게 — 2-depth 구분)
- 활성: 텍스트 `AppColors.primaryBright` w600, 하단 2px 언더라인 `AppColors.primaryBright`
- 비활성: 텍스트 `AppColors.textMuted` w400
- 텍스트 fontSize: 13
- 중앙 정렬

> 메인 세그먼트(`AppColors.primary`)와 sub-segment(`AppColors.primaryBright`)를 다른 색으로 구분해 2-depth 계층을 시각화한다.

각 sub-segment 에도 pending count 소형 뱃지 (선택적 — 구현 시 provider 분리 필요):
- 배경: `AppColors.warning`, radius 999, height 16
- 텍스트: `AppColors.onPrimary`, fontSize 9, w700

---

## 3. AdminPendingMenuOverridesPage

- 파일: `presentation/admin/approval/admin_pending_menu_overrides_page.dart`
- 역할: `menuOverrides.status='pending'` 전체 리스트 (collectionGroup query)
- 최상위: `Widget` (IndexedStack 자식 — Scaffold 없음)

### 레이아웃

```
Column
  └─ Expanded
       └─ ListView.builder (padding: horizontal 16, vertical 8)
            └─ _MenuOverrideTile (각 override)
```

### _MenuOverrideTile

```
Card
  ├─ color: AppColors.surfaceElevated
  ├─ borderRadius: 14
  ├─ border: AppColors.border 1px
  ├─ elevation: 0
  ├─ shadow: AppColors.primary.withOpacity(0.04) blurRadius 8
  └─ InkWell(onTap: → AdminMenuOverrideApprovalDetailPage)
       └─ Padding(horizontal 16, vertical 14)
            └─ Column (crossAxisAlignment: start)
                 ├─ Row
                 │    ├─ Expanded
                 │    │    └─ Text(매장명, 15, w600, AppColors.textHeading, maxLines 1)
                 │    └─ ApprovalStatusBadge(override.status,
                 │                           isRevision: override.approvedAt != null)
                 ├─ SizedBox(height: 4)
                 ├─ Row
                 │    ├─ Icon(Icons.menu_book_outlined, 12, AppColors.textMuted)
                 │    ├─ SizedBox(width: 4)
                 │    └─ Text(마스터 메뉴 이름, 13, AppColors.textBody, maxLines 1)
                 ├─ SizedBox(height: 6)
                 ├─ _OverrideSummaryRow          ← 변경 내용 요약
                 ├─ SizedBox(height: 4)
                 └─ Text('제출: {submittedAt yyyy.MM.dd HH:mm}', 12, AppColors.textMuted)
```

`_OverrideSummaryRow`:
- priceOverride 있음: `Row → Text('₩{basePrice}', 12, AppColors.textMuted, lineThrough) + ' → ' + Text('₩{priceOverride}', 12, w600, AppColors.primary)`
- excluded=true: `Row → Icon(Icons.remove_circle_outline, 12, AppColors.error) + Text(' 이 매장 제외', 12, AppColors.error, w600)`
- 둘 다 있으면 Column 으로 두 Row 표시

trailing: `Icon(Icons.chevron_right_rounded, 18, AppColors.textMuted)`

### 빈 상태

```
Center
  └─ Column
       ├─ Icon(Icons.price_change_outlined, 56, AppColors.textMuted)
       ├─ SizedBox(height: 20)
       ├─ Text '승인 대기 중인 가격 오버라이드가 없어요', 16, w600, AppColors.textHeading
       ├─ SizedBox(height: 8)
       └─ Text '새로운 가격 변경 요청이 들어오면 여기에 표시돼요.',
                13, AppColors.textMuted, 중앙 정렬
```

### 로딩 / 에러

| 상태 | UI |
|---|---|
| 로딩 | `Center → CircularProgressIndicator(color: AppColors.primary)` |
| 에러 | 공통 에러 패턴, 제목 `'데이터를 불러오는 데 실패했어요.'`, 재시도 `ref.refresh(pendingMenuOverridesProvider)` |

---

## 4. AdminMenuOverrideApprovalDetailPage

- 파일: `presentation/admin/approval/admin_menu_override_approval_detail_page.dart`
- 역할: 가격 오버라이드 상세 + 승인 / 반려
- 참조: sub-phase 1 `AdminMasterMenuApprovalDetailPage` 패턴 재사용

### 레이아웃

```
Scaffold
  ├─ backgroundColor: AppColors.background
  ├─ AppBar
  │    - title: '오버라이드 검토', fontSize 17, w700, AppColors.textHeading
  │    - backgroundColor: AppColors.background, elevation 0
  │    - leading: Icons.arrow_back_ios_rounded
  ├─ body: CustomScrollView
  │         └─ SliverList
  │              ├─ SectionA — 상태 배너
  │              ├─ SectionB — 매장 정보
  │              ├─ SectionC — 마스터 메뉴 정보
  │              ├─ SectionD — 변경 내용
  │              ├─ SectionE — 제출 정보
  │              └─ SizedBox(height: 100)    ← ApprovalActionsBar 가림 방지
  └─ bottomNavigationBar: ApprovalActionsBar (pending 일 때만)
```

### SectionA — 상태 배너 (approved / rejected 시 노출)

sub-phase 1 의 상태 배너 패턴 동일.
- approved: 배경 `AppColors.success.withOpacity(0.10)`, border `AppColors.success.withOpacity(0.3)`, 아이콘 `Icons.check_circle_rounded`, 텍스트 `'승인되었어요'`
- rejected: 배경 `AppColors.error.withOpacity(0.10)`, border `AppColors.error.withOpacity(0.3)`, 아이콘 `Icons.cancel_rounded`, 텍스트 `'반려되었어요'`
- pending: 배너 미노출

### SectionB — 매장 정보

```
_DetailSection(title: '매장 정보')
  └─ _InfoRow('매장명', store.name)
  └─ _InfoRow('주소', store.address)
  └─ _InfoRow('브랜드', brandName)     ← StoreScopeBadge.brand(brandName) 인라인
```

### SectionC — 마스터 메뉴 정보

```
_DetailSection(title: '마스터 메뉴')
  └─ _InfoRow('메뉴명', masterMenu.name)
  └─ _InfoRow('기준 가격', '₩{masterMenu.basePrice}')
```

### SectionD — 변경 내용 (핵심)

```
_DetailSection(title: '변경 내용')
  └─ (priceOverride != null)
       _ChangeRow('가격 변경')
         └─ Row
              ├─ Text('₩{basePrice}', 14, AppColors.textMuted, lineThrough)
              ├─ Text(' → ', 14, AppColors.textMuted)
              └─ Text('₩{priceOverride}', 16, w700, AppColors.primary)
  └─ (excluded == true)
       _ChangeRow('메뉴 제외')
         └─ Row
              ├─ Icon(Icons.remove_circle_rounded, 18, AppColors.error)
              └─ Text(' 이 매장에서 제외', 14, w600, AppColors.error)
```

### SectionE — 제출 정보

```
_DetailSection(title: '처리 정보')
  └─ _InfoRow('제출자', override.submittedBy ?? '-')
  └─ _InfoRow('제출일', override.submittedAt?.format('yyyy.MM.dd HH:mm') ?? '-')
  └─ (approved) _InfoRow('승인자', override.approvedBy ?? '-')
  └─ (approved) _InfoRow('승인일', override.approvedAt?.format('yyyy.MM.dd HH:mm') ?? '-')
  └─ (rejected) _InfoRow('반려 사유', override.rejectedReason ?? '사유 없음')
               (rejectedReason 은 AppColors.error 텍스트로 강조)
```

### ApprovalActionsBar (하단)

sub-phase 1 `ApprovalActionsBar` 재사용.
- `onApprove`: `ApproveMenuOverrideUseCase` → SnackBar `'승인했어요'` + pop
- `onReject`: `RejectReasonDialog` → `RejectMenuOverrideUseCase` → SnackBar `'반려했어요'` + pop
- `approved` / `rejected` 상태 → `ApprovalActionsBar` 미노출 (SectionA 배너로 대체)

### 로딩 / 에러

| 상태 | UI |
|---|---|
| 로딩 | `Center → CircularProgressIndicator(color: AppColors.primary)` |
| 에러 | 공통 에러 패턴, 제목 `'정보를 불러오지 못했어요.'`, 재시도 `Navigator.pop` (돌아가기) |

---

## 5. AdminPendingBrandStoreItemsPage

- 파일: `presentation/admin/approval/admin_pending_brand_store_items_page.dart`
- 역할: `scope=store && brandId != null && status='pending'` 점포 한정 메뉴 리스트 (collectionGroup query)
- 최상위: `Widget` (IndexedStack 자식 — Scaffold 없음)

### _BrandStoreItemTile

```
Card
  ├─ color: AppColors.surfaceElevated
  ├─ borderRadius: 14
  ├─ border: AppColors.border 1px
  ├─ elevation: 0
  └─ InkWell(onTap: → AdminBrandStoreItemApprovalDetailPage)
       └─ Padding(horizontal 16, vertical 14)
            └─ Row
                 ├─ (imageUrl 있으면) ClipRRect(radius 8, 56×56, Image.network) /
                 │   (없으면) Container(56×56, radius 8, AppColors.surface,
                 │              Icon(Icons.restaurant_menu_outlined, 24, AppColors.textMuted))
                 ├─ SizedBox(width: 12)
                 ├─ Expanded
                 │    └─ Column (crossAxisAlignment: start)
                 │         ├─ Row
                 │         │    ├─ Expanded — Text(메뉴 이름, 15, w600, AppColors.textHeading)
                 │         │    └─ ApprovalStatusBadge(status, isRevision: approvedAt != null)
                 │         ├─ SizedBox(height: 4)
                 │         ├─ Row
                 │         │    ├─ Icon(Icons.storefront_outlined, 12, AppColors.textMuted)
                 │         │    └─ Text(' {매장명}', 12, AppColors.textMuted)
                 │         ├─ SizedBox(height: 2)
                 │         ├─ Text('₩{basePrice}', 13, w500, AppColors.textBody)
                 │         └─ Text('제출: {submittedAt}', 12, AppColors.textMuted)
                 └─ Icon(Icons.chevron_right_rounded, 18, AppColors.textMuted)
```

### 빈 상태

```
Center
  └─ Column
       ├─ Icon(Icons.check_circle_outline_rounded, 56, AppColors.textMuted)
       ├─ SizedBox(height: 20)
       ├─ Text '승인 대기 중인 점포 한정 메뉴가 없어요', 16, w600, AppColors.textHeading
       ├─ SizedBox(height: 8)
       └─ Text '새로운 점포 한정 메뉴 등록 요청이 들어오면 여기에 표시돼요.',
                13, AppColors.textMuted, 중앙 정렬
```

### 로딩 / 에러

| 상태 | UI |
|---|---|
| 로딩 | `Center → CircularProgressIndicator(color: AppColors.primary)` |
| 에러 | 공통 에러 패턴, 제목 `'데이터를 불러오는 데 실패했어요.'` |

---

## 6. AdminBrandStoreItemApprovalDetailPage

- 파일: `presentation/admin/approval/admin_brand_store_item_approval_detail_page.dart`
- 역할: 점포 한정 메뉴 상세 + 승인 / 반려
- 참조: sub-phase 1 `AdminMasterMenuApprovalDetailPage` 패턴 거의 동일

### 레이아웃

```
Scaffold
  ├─ AppBar: title '메뉴 검토', leading Icons.arrow_back_ios_rounded
  ├─ body: CustomScrollView
  │         └─ SliverList
  │              ├─ SectionA — 상태 배너 (approved/rejected 시)
  │              ├─ SectionB — 매장 정보 (매장명 + 브랜드명 + StoreScopeBadge.brand)
  │              ├─ SectionC — 메뉴 이미지 (있으면 전체 너비, 없으면 미표시)
  │              ├─ SectionD — 메뉴 핵심 정보 (이름 / 가격 / 카테고리 / 설명)
  │              ├─ SectionE — 운영 정보 (visible / displayOrder / tags)
  │              ├─ SectionF — 제출 정보
  │              └─ SizedBox(height: 100)
  └─ bottomNavigationBar: ApprovalActionsBar (pending 일 때만)
```

### SectionC — 메뉴 이미지

```
// imageUrl 있을 때
AspectRatio(aspectRatio: 16/9)
  └─ Image.network(imageUrl, fit: BoxFit.cover)

// imageUrl 없을 때
SizedBox.shrink()
```

### SectionD — 메뉴 핵심 정보

```
_DetailSection(title: '메뉴 정보')
  └─ _InfoRow('메뉴명', menuItem.name)
  └─ _InfoRow('가격', '₩{menuItem.basePrice}')
  └─ _InfoRow('카테고리', menuItem.mainCategoryCode)
  └─ (description 있음) _InfoRow('설명', menuItem.description)
```

### SectionE — 운영 정보

```
_DetailSection(title: '운영 정보')
  └─ _InfoRow('노출 여부', menuItem.visible ? '노출' : '비노출')
  └─ _InfoRow('표시 순서', menuItem.displayOrder.toString())
  └─ (tags 있음) _TagsRow(menuItem.tags)   ← Wrap of Chip
```

### ApprovalActionsBar

sub-phase 1 재사용.
- `onApprove`: `ApproveStoreOnlyMenuUseCase` → SnackBar `'승인했어요'` + pop
- `onReject`: `RejectReasonDialog` → `RejectStoreOnlyMenuUseCase` → SnackBar `'반려했어요'` + pop

---

## 7. AdminPendingStoresPage (수정 — 브랜드 매장 카드 분기)

- 파일: `presentation/admin/approval/admin_pending_stores_page.dart` (기존 파일 수정)
- 변경: `_StoreQueueTile` 의 `StoreScopeBadge` 분기 추가

### _StoreQueueTile 변경

기존 sub-phase 2:
```
// title Row — 기존
StoreScopeBadge(label: '개인 매장')
```

본 sub-phase 수정:
```
// title Row — 분기
store.brandId == null
  ? StoreScopeBadge.personal()
  : StoreScopeBadge.brand(brandName)
```

brandName 조회: tile 내부에서 `ref.watch(brandByIdProvider(store.brandId!))` 구독 → loading 시 `'브랜드 매장'` placeholder.

---

## 8. AdminStoreApprovalDetailPage (수정 — 브랜드 매장 케이스 보강)

- 파일: `presentation/admin/approval/admin_store_approval_detail_page.dart` (기존 파일 수정)
- 변경: `store.brandId != null` 케이스에 마스터 메뉴 활성 chip 섹션 추가

### 추가 섹션 (store.brandId != null 일 때만 노출)

기존 SectionB (매장 정보) 아래에 삽입:

```
_DetailSection(title: '운영 마스터 메뉴')
  └─ (마스터 메뉴 chip 리스트 — excluded=false 인 메뉴만 → 활성 메뉴)
       Wrap (spacing: 8, runSpacing: 8)
         └─ for each activeMasterMenu:
              Container (pill)
                ├─ decoration:
                │    color: AppColors.primary.withOpacity(0.10)
                │    borderRadius: 999
                │    border: AppColors.primary.withOpacity(0.3) 1px
                └─ Padding(horizontal 10, vertical 5)
                     └─ Text(menu.name, fontSize 12, w500, AppColors.primary)
  └─ (excludedMenus 있음) SizedBox(height: 8)
       Text('제외 메뉴: {N}개', 12, AppColors.textMuted)
```

브랜드 정보 Row 도 추가:
```
_InfoRow('브랜드', brandName)
  └─ Row → StoreScopeBadge.brand(brandName) inline
```

---

## 9. AdminBrandStoreManagementPage

- 파일: `presentation/admin/brand_store_management/admin_brand_store_management_page.dart`
- 역할: admin 이 특정 브랜드 매장의 메뉴 직접 관리 진입
- **진입 경로 확정**: `AdminStoreApprovalDetailPage` 안의 CTA 버튼 `'이 매장 메뉴 관리'` (브랜드 매장 + status=approved 일 때만 노출). admin 더보기 진입은 미채택 — admin 이 매장을 보다가 자연스럽게 그 매장 메뉴를 다듬는 동선이 직관적.

### CTA 배치 (AdminStoreApprovalDetailPage 측)

- `_StoreInfoSection` 하단, `ApprovalActionsBar` 위:
  - `OutlinedButton.icon(Icons.menu_book_rounded, '이 매장 메뉴 관리', onPressed: → AdminBrandStoreManagementPage(storeId, brandId) push)`
  - 노출 조건: `store.status == approved && store.brandId != null`
  - approved 가 아닌 상태에서는 안내: `'승인 후 메뉴 관리가 가능합니다'` (faded)
  - 개인 매장 (`brandId == null`): CTA 자체 비노출 (개인 매장 메뉴 CRUD 는 점주가 sub-phase 4 에서 함)

### AppBar

```
AppBar
  ├─ backgroundColor: AppColors.background
  ├─ elevation: 0
  ├─ leading: Icons.arrow_back_ios_rounded
  └─ title: Text('매장 직접 관리', fontSize 17, w700, AppColors.textHeading)
```

### 안내 배너

```
Container
  ├─ decoration:
  │    color: AppColors.warning.withOpacity(0.08)
  │    borderRadius: 12
  │    border: AppColors.warning.withOpacity(0.3) 1px
  └─ Padding(14)
       └─ Row
            ├─ Icon(Icons.admin_panel_settings_rounded, 16, AppColors.warning)
            ├─ SizedBox(width: 8)
            └─ Text('admin 이 직접 등록하면 즉시 승인 상태로 반영됩니다.',
                      12, AppColors.warning, height 1.4)
```

### 레이아웃

```
ListView (padding: horizontal 16, vertical 12)
  ├─ _StoreInfoCard (매장명 + 브랜드명 — read-only)
  ├─ SizedBox(height: 16)
  ├─ _SectionHeader('가격 오버라이드')
  ├─ _AdminOverrideList (해당 매장의 전체 override 리스트)
  ├─ _AddOverrideButton → AdminMenuOverrideApprovalDetailPage (admin 직접 등록 모드)
  ├─ SizedBox(height: 24)
  ├─ _SectionHeader('점포 한정 메뉴')
  ├─ _AdminStoreMenuList (해당 매장의 점포 한정 메뉴)
  └─ _AddStoreMenuButton → BrandStoreOnlyMenuFormPage (admin 모드 — status=approved 즉시)
```

> 이 페이지는 admin 전용이므로 status=approved 즉시 박힘 안내를 상단 배너로 강조한다. 실제 status 강제는 UseCase / Repository 레이어 담당 (UI 는 안내만).

---

## 인터랙션 정리 (Admin 모듈)

| 동작 | 반응 |
|---|---|
| `AdminApprovalQueuePage` '매장 커스텀' 탭 탭 | IndexedStack index 3 전환 → `_StoreCustomizationSection` |
| `_CustomizationSubSegmentBar` '가격 오버라이드' | sub-IndexedStack index 0 → `AdminPendingMenuOverridesPage` |
| `_CustomizationSubSegmentBar` '점포 한정 메뉴' | sub-IndexedStack index 1 → `AdminPendingBrandStoreItemsPage` |
| `_MenuOverrideTile` 탭 | `AdminMenuOverrideApprovalDetailPage(storeId, masterMenuItemId)` push |
| `_BrandStoreItemTile` 탭 | `AdminBrandStoreItemApprovalDetailPage(storeId, menuItemId)` push |
| `AdminMenuOverrideApprovalDetailPage` 승인 | `ApproveMenuOverrideUseCase` → SnackBar `'승인했어요'` + pop |
| `AdminMenuOverrideApprovalDetailPage` 반려 | `RejectReasonDialog` → `RejectMenuOverrideUseCase` → SnackBar `'반려했어요'` + pop |
| `AdminBrandStoreItemApprovalDetailPage` 승인 | `ApproveStoreOnlyMenuUseCase` → SnackBar `'승인했어요'` + pop |
| `AdminBrandStoreItemApprovalDetailPage` 반려 | `RejectReasonDialog` → `RejectStoreOnlyMenuUseCase` → SnackBar `'반려했어요'` + pop |
| approved / rejected 상태 상세 페이지 | `ApprovalActionsBar` 미노출, 상태 배너 노출 |

---

## 개발자 전달 특이사항 (Admin 모듈)

1. **세그먼트 4탭 시 글자 크기**: 4탭이 되면 각 탭 라벨이 좁아지므로 `_SegTab` 텍스트 fontSize를 기존 14 → 13 으로 조정한다. 탭 라벨이 잘리지 않도록 확인 필요.
2. **`_StoreCustomizationSection` 상태 관리**: sub-segment 의 현재 인덱스를 `ValueNotifier<int>` 또는 별도 `StateProvider<int>` 로 관리한다. `AdminApprovalQueuePage` 의 `_currentIndex` 와 별도 상태여야 한다.
3. **`AdminPendingMenuOverridesPage` / `AdminPendingBrandStoreItemsPage` 의 collectionGroup query 에러 처리**: U4 패턴 — 인덱스 누락 시 콘솔 안내 로그 + 에러 위젯 재시도. `handleError` + `debugPrint` (sub-phase 1 S4 패턴).
4. **`AdminPendingStoresPage` 브랜드 매장 카드의 brandName 조회**: 리스트 내 각 tile 이 개별적으로 `ref.watch(brandByIdProvider(brandId))` 구독. 로딩 중 placeholder `'브랜드 매장'` 표시.
5. **`AdminBrandStoreManagementPage` 진입 경로**: admin 내부에서 어떤 진입 경로를 확정할지 개발자가 admin 더보기 탭 또는 매장 상세에서 추가 CTA 로 구현. 본 디자인에서는 페이지 구조만 정의.
6. **`ApprovalActionsBar` 재사용 확인**: sub-phase 1 `ApprovalActionsBar` 에 `onApprove` / `onReject` callback 이 이미 정의되어 있으므로 callback 교체만으로 재사용 가능.
7. **`_InfoRow` / `_DetailSection` 공통 위젯**: sub-phase 1 의 `AdminMasterMenuApprovalDetailPage` 내부 `_InfoRow` 를 별도 공통 위젯으로 추출하거나 동일 패턴을 복사 적용. 향후 리팩터링 시 `presentation/admin/widgets/` 로 이동 권장.
