# 공통 컴포넌트 디자인 명세 — sub-phase 3 (brand_store_customization)

> sub-phase 1/2 의 `common_components.md` 를 기반으로 sub-phase 3 에서 추가/확장되는 컴포넌트만 기록한다.
> 기존 컴포넌트 (ApprovalStatusBadge / RejectReasonDialog / ImageUploadField / ApprovalActionsBar) 는 변경 없이 그대로 재사용한다.

---

## 재사용 컴포넌트 (변경 없음)

| 컴포넌트 | 파일 | 재사용 위치 |
|---|---|---|
| `ApprovalStatusBadge` | `presentation/common/widgets/approval_status_badge.dart` | 전 화면 |
| `RejectReasonDialog` | `presentation/common/widgets/reject_reason_dialog.dart` | Admin 상세 페이지 반려 |
| `ApprovalActionsBar` | `presentation/admin/widgets/approval_actions_bar.dart` | Admin 상세 페이지 하단 |
| `ImageUploadField` | `presentation/common/widgets/image_upload_field.dart` | BrandStoreOnlyMenuFormPage / BrandStoreFormPage |

---

## 신규 컴포넌트

---

## 1. StoreScopeBadge — brand 케이스 추가

- 파일: `presentation/admin/widgets/store_scope_badge.dart` (기존 파일 수정)
- 변경: `.brand(brandName)` named constructor 추가 (또는 `isBrand: bool, brandName: String?` prop 방식)

### StoreScopeBadge.brand(brandName)

```
Container (pill)
  └─ Row
       ├─ Icon(Icons.business_rounded, 11, AppColors.primary)
       ├─ SizedBox(width: 4)
       └─ Text('브랜드: {brandName}', fontSize 11, w600, AppColors.primary)
```

### 스타일

| 속성 | personal() 값 | brand(brandName) 값 |
|---|---|---|
| 배경 | `AppColors.info.withOpacity(0.12)` | `AppColors.primary.withOpacity(0.12)` |
| border | 없음 | 없음 |
| radius | 999 (pill) | 999 (pill) |
| height | 22 | 22 |
| padding | horizontal 8, vertical 3 | horizontal 8, vertical 3 |
| 아이콘 | `Icons.storefront_outlined`, 11, `AppColors.info` | `Icons.business_rounded`, 11, `AppColors.primary` |
| 텍스트 | `AppColors.info`, 11, w600 | `AppColors.primary`, 11, w600 |
| 라벨 | `'개인 매장'` | `'브랜드: {brandName}'` |

### 색상 선택 근거

- "개인 매장": 정보성 scope 식별 → `AppColors.info` 톤 (sub-phase 2 확정)
- "브랜드 매장": brand 관계 = 앱의 메인 포인트 → `AppColors.primary` 톤. 프리미엄 감성 강화. `ApprovalStatusBadge` (warning/success/error) 및 "개인 매장" 뱃지와 시각적으로 구분됨.

### Props

```dart
// 방식 A — named constructor (권장)
StoreScopeBadge.personal()
StoreScopeBadge.brand(String brandName)

// 방식 B — prop (대안)
StoreScopeBadge({
  required String label,
  required IconData icon,
  required Color color,
})
```

개발자가 방식 A / B 중 선택 가능. 방식 A 가 호출부에서 의도가 명확하여 권장.

### 사용 위치 (sub-phase 3)

| 화면 | 용도 |
|---|---|
| `BrandStoreCard` | 매장 리스트 카드 내 brand scope 표시 |
| `AdminPendingStoresPage._StoreQueueTile` | brand 매장 카드 분기 |
| `AdminStoreApprovalDetailPage` | 브랜드 매장 상세 섹션 내 |
| `AdminMenuOverrideApprovalDetailPage` SectionB | 매장 정보 섹션 내 brand 표시 |
| `AdminBrandStoreItemApprovalDetailPage` SectionB | 동일 |
| `OwnerMyStorePage._StoreHeaderCard` | brand 매장 점주 화면 overlay |

---

## 2. MasterMenuOverrideCard

- 파일: `presentation/brand/customization/price_override/widgets/master_menu_override_card.dart`
- 역할: 마스터 메뉴 + override 현황을 머지하여 표시하는 카드. `BrandPriceOverrideListPage` 에서 사용.

### 위젯 구조

brand_module.md 의 `MasterMenuOverrideCard` 섹션 참조.

### 변경 미리보기 형식 (확정)

| 상태 | 표시 형식 | 색상 |
|---|---|---|
| override 없음 | `'₩{basePrice}'` | `AppColors.textBody` |
| override 있음, status=approved | `'₩{basePrice}' → '₩{priceOverride}'` | basePrice: textMuted + lineThrough / priceOverride: primary w700 |
| override 있음, status=pending | `'₩{basePrice}'` + `'→ ₩{priceOverride} (검토 중)'` | basePrice: textBody / 검토 중: warning |
| override 있음, status=rejected | `'₩{basePrice}'` (override 미적용) | textBody (approved 아니므로 미적용) |
| excluded=true, status=approved | excluded chip (`AppColors.error`) | |
| excluded=true, status=pending | excluded chip (`AppColors.warning`, `'제외 검토 중'`) | |

### Props

```dart
MasterMenuOverrideCard({
  required MasterMenuItemEntity masterMenu,
  MenuOverrideEntity? override,
  required VoidCallback onTap,
})
```

---

## 3. PriceOverrideInput

- 파일: `presentation/brand/customization/widgets/price_override_input.dart`
- 역할: 가격 오버라이드 입력 필드. `BrandPriceOverrideFormPage` 에서 사용.

### 위젯 구조 (brand_module.md 참조)

brand_module.md 의 `PriceOverrideInput` 섹션 참조.

### Props

```dart
PriceOverrideInput({
  required int basePriceForPlaceholder,
  int? initialValue,
  required ValueChanged<int?> onChanged,
})
```

- `basePriceForPlaceholder`: TextField hint 에 `'₩{basePrice}'` 로 표시
- `initialValue`: 기존 override 수정 시 pre-fill
- `onChanged`: 입력 값 변화 시 콜백. 입력 없으면 null 전달.

### 미리보기 노출 조건

- 입력 값이 있고 (`priceOverride != null`) basePriceForPlaceholder 와 다를 때 노출
- 입력 값 == basePrice 이면 미리보기 미노출 (의미 없는 오버라이드)
- 입력 값 == null 이면 미리보기 미노출

---

## 4. ExcludedToggle

- 파일: `presentation/brand/customization/widgets/excluded_toggle.dart`
- 역할: 메뉴 제외 여부 토글. `BrandPriceOverrideFormPage` 에서 사용.

### 위젯 구조 (brand_module.md 참조)

brand_module.md 의 `ExcludedToggle` 섹션 참조.

### Props

```dart
ExcludedToggle({
  required bool value,
  required ValueChanged<bool> onChanged,
})
```

### 도움말 노출 조건

- `value == true` 일 때 토글 아래에 경고 컨테이너 노출.
- `value == false` 일 때 도움말 미노출.

---

## 5. MasterMenuChipMultiSelect

- 파일: `presentation/brand/widgets/master_menu_chip_multi_select.dart`
- 역할: 마스터 메뉴 multi-select chip. `BrandStoreFormPage` 의 섹션 B 에서 사용.

### 위젯 구조

```
Column (crossAxisAlignment: start)
  ├─ (마스터 메뉴 0개) — 안내 컨테이너
  └─ (마스터 메뉴 있음)
       ├─ Row (mainAxisAlignment: end)
       │    └─ TextButton(전체 선택 / 전체 해제, AppColors.primaryBright)
       └─ Wrap (spacing: 8, runSpacing: 8)
            └─ for each masterMenuItem:
                 FilterChip (...)   ← brand_module.md 스타일 참조
```

### Props

```dart
MasterMenuChipMultiSelect({
  required List<MasterMenuItemEntity> masterMenuItems,
  required Set<String> enabledIds,        // 현재 선택된 메뉴 id Set
  required ValueChanged<Set<String>> onChanged,
})
```

### 로딩 / 에러

- 마스터 메뉴 로딩 중: `Center → CircularProgressIndicator(color: AppColors.primary)` (Wrap 자리에 노출)
- 에러: 안내 텍스트 `'마스터 메뉴를 불러오지 못했어요.'` + 재시도 버튼

---

## 6. 공통 상태 UI (sub-phase 3 신규 화면)

sub-phase 1/2 공통 패턴을 본 sub-phase 신규 화면에도 동일 적용.

### 로딩

모든 신규 화면: `Center → CircularProgressIndicator(color: AppColors.primary)`

### 에러

공통 에러 위젯 구조 (sub-phase 1/2 패턴 동일):

```
Padding(all 24)
  └─ Center
       └─ Column
            ├─ Icon(Icons.error_outline_rounded, 48, AppColors.error)
            ├─ SizedBox(height: 16)
            ├─ Text '{에러 제목}', 16, w700, AppColors.textHeading
            ├─ SizedBox(height: 8)
            ├─ Text '일시적인 오류가 발생했어요.\n잠시 후 다시 시도해주세요',
            │         13, AppColors.textMuted, 중앙 정렬
            ├─ SizedBox(height: 24)
            └─ ElevatedButton '다시 시도'
                 - backgroundColor: AppColors.primary
                 - 텍스트: AppColors.onPrimary, w600
                 - radius: 12
                 - padding: horizontal 24 vertical 12
```

화면별 에러 제목 및 재시도 방식:

| 화면 | 에러 제목 | 재시도 |
|---|---|---|
| `BrandStoresPage` | `'매장 목록을 불러오지 못했어요'` | `ref.refresh(brandStoresProvider)` |
| `BrandPriceOverrideListPage` | `'메뉴 목록을 불러오지 못했어요'` | `ref.refresh(menuOverridesByStoreProvider)` |
| `BrandStoreOnlyMenuListPage` | `'메뉴를 불러오지 못했어요'` | `ref.refresh(storeOnlyMenusProvider)` |
| `BrandApprovalTrackingPage` | `'내역을 불러오지 못했어요'` | `ref.refresh(approvalTrackingProvider)` |
| `AdminPendingMenuOverridesPage` | `'데이터를 불러오는 데 실패했어요.'` | `ref.refresh(pendingMenuOverridesProvider)` |
| `AdminPendingBrandStoreItemsPage` | `'데이터를 불러오는 데 실패했어요.'` | `ref.refresh(pendingBrandStoreItemsProvider)` |
| `AdminMenuOverrideApprovalDetailPage` | `'정보를 불러오지 못했어요.'` | `Navigator.pop` |
| `AdminBrandStoreItemApprovalDetailPage` | `'정보를 불러오지 못했어요.'` | `Navigator.pop` |

### 빈 상태

공통 빈 상태 위젯 구조:

```
Center
  └─ Column (mainAxisSize: min)
       ├─ Icon({화면별 아이콘}, 56, AppColors.textMuted)
       ├─ SizedBox(height: 20)
       ├─ Text '{화면별 제목}', 16, w600, AppColors.textHeading
       ├─ SizedBox(height: 8)
       ├─ Text '{화면별 설명}', 13, AppColors.textMuted, 중앙 정렬
       └─ (CTA 있음) SizedBox(height: 28) + ElevatedButton / TextButton
```

화면별 빈 상태 정의:

| 화면 | 아이콘 | 제목 | 설명 | CTA |
|---|---|---|---|---|
| `BrandStoresPage` | `Icons.location_city_outlined` | `'등록된 매장이 없어요'` | `'첫 번째 매장을 등록하고 운영을 시작해보세요.'` | `'매장 등록하기'` → `BrandStoreFormPage` |
| `BrandPriceOverrideListPage` | `Icons.menu_book_outlined` | `'마스터 메뉴를 먼저 등록해주세요'` | `'마스터 메뉴 탭에서 메뉴를 등록하면 이곳에서 가격을 조정할 수 있어요.'` | 없음 |
| `BrandStoreOnlyMenuListPage` | `Icons.restaurant_menu_outlined` | `'점포 한정 메뉴가 없어요'` | `'이 매장에서만 판매할 특별 메뉴를 추가해보세요.'` | 없음 (FAB 로 대체) |
| `BrandApprovalTrackingPage` | `Icons.track_changes_rounded` | `'제출한 내역이 없어요'` | `'매장 등록이나 메뉴 수정을 하면 여기에 표시돼요.'` | 없음 |
| `AdminPendingMenuOverridesPage` | `Icons.price_change_outlined` | `'승인 대기 중인 가격 오버라이드가 없어요'` | `'새로운 가격 변경 요청이 들어오면 여기에 표시돼요.'` | 없음 |
| `AdminPendingBrandStoreItemsPage` | `Icons.check_circle_outline_rounded` | `'승인 대기 중인 점포 한정 메뉴가 없어요'` | `'새로운 점포 한정 메뉴 등록 요청이 들어오면 여기에 표시돼요.'` | 없음 |

---

## 디자인 시스템 일관성 체크리스트

본 sub-phase 신규 컴포넌트가 sub-phase 1/2 와 일관성을 유지하는지 확인:

| 항목 | sub-phase 1/2 | sub-phase 3 |
|---|---|---|
| 카드 radius | 14 | 14 (동일) |
| 카드 border | `AppColors.border` 1px | `AppColors.border` 1px (동일) |
| 카드 배경 | `AppColors.surfaceElevated` | `AppColors.surfaceElevated` (동일) |
| 다이얼로그 radius | 16 | 16 (동일, RejectReasonDialog 재사용) |
| AppBar 스타일 | background, elevation 0 | 동일 |
| 메인 세그먼트 탭 높이 | 44 | 44 (동일) |
| sub-segment 탭 높이 | 없음 | 40 (신규, 메인보다 4px 작게) |
| 선택된 세그먼트 | `AppColors.primary` + 2px 언더라인 | 동일 |
| 선택된 sub-segment | 없음 | `AppColors.primaryBright` + 2px 언더라인 |
| status 색 (pending) | `AppColors.warning` alpha 0.15 배경 | 동일 |
| status 색 (approved) | `AppColors.success` alpha 0.15 배경 | 동일 |
| status 색 (rejected) | `AppColors.error` alpha 0.15 배경 | 동일 |
| 로딩 방식 | `CircularProgressIndicator` | `CircularProgressIndicator` (동일) |
| 로딩 색 | `AppColors.primary` (admin) / `AppColors.accent` (owner) | admin: `AppColors.primary`, brand: `AppColors.primary` |
| 에러 아이콘 | `Icons.error_outline_rounded`, size 48 | 동일 |
| 빈 상태 아이콘 | size 56 | size 56 (동일) |
| SnackBar — 핵심 필드 성공 | `AppColors.primary.withOpacity(0.9)` 배경 | 동일 |
| SnackBar — 운영 필드 성공 | `AppColors.success.withOpacity(0.9)` 배경 | 동일 |
| SnackBar — 실패 | `AppColors.error` 배경 | 동일 |
| FAB 배경 | `AppColors.primary` | 동일 |
| FAB 아이콘 / 텍스트 | `AppColors.onPrimary` | 동일 |
