# Owner 모듈 디자인 명세 — sub-phase 5 (owner_options_soldout)

> 파일 위치:
> - `lib/presentation/owner/my_store/` (갱신)
> - `lib/presentation/owner/store_menu/` (갱신)
> - `lib/presentation/owner/brand_store/` (신규)
>
> 참조:
> - sub-phase 4 `owner_module.md` — `_InlineVisibleToggle`, `OwnerStoreMenuListPage`, `OwnerStoreMenuDetailPage`, `_MenuManagementButton` 패턴
> - sub-phase 3 `brand_module.md` — `BrandStoreCard`, `_BrandStoreInfoBanner` 패턴
> - sub-phase 1 `brand_module.md` — `ApprovalStatusBadge`, `_VisibleToggleButton` 패턴

---

## 1. OwnerMyStorePage 갱신 — 브랜드 매장 CTA 추가

- 파일: `presentation/owner/my_store/my_store_page.dart` (갱신)
- 역할: 기존 CTA 영역에 브랜드 매장 전용 "메뉴 옵션·품절 관리" 버튼 추가. 개인 매장과 상호 배타 노출.

### 변경 범위

기존 레이아웃에서 `_MenuManagementButton` 의 조건부 노출 조건만 변경하고, 브랜드 매장용 버튼을 바로 아래에 추가한다.

```
CustomScrollView
  ...
  ├─ _StoreMetricsSection (기존 그대로)
  ├─ SizedBox(height: 20)
  ├─ _StoreActionButtons (기존 그대로)
  ├─ SizedBox(height: 12)
  ├─ _MenuManagementButton (sub-phase 4 산출 — 노출 조건 변경 없음: brandId==null && approved)
  ├─ _BrandMenuManagementButton (신규 — 노출 조건: brandId!=null && approved)
  ├─ SizedBox(height: 32)
  └─ _DangerZone (기존 그대로)
```

`_MenuManagementButton` 과 `_BrandMenuManagementButton` 사이 간격: `SizedBox(height: 10)`

### _BrandMenuManagementButton (신규 위젯)

- 파일: `presentation/owner/my_store/widgets/brand_menu_management_button.dart` 또는 `my_store_page.dart` 내부 private 위젯
- 노출 조건: `store.brandId != null && store.status == EntityApprovalStatus.approved` 를 **모두 충족**할 때만 렌더링. 불충족 시 `SizedBox.shrink()`.

```
SizedBox (width: double.infinity, height: 52)
  └─ ElevatedButton.icon
       icon: Icon(Icons.tune_rounded, size: 18, color: AppColors.onPrimary)
       label: Text '메뉴 옵션·품절 관리'
       style:
         배경: AppColors.primary
         텍스트: AppColors.onPrimary, fontSize 15, w700
         radius: 14
         elevation: 0
```

- 탭 → `Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerBrandStoreMenusPage(store: store)))`

### Props

```dart
_BrandMenuManagementButton({
  required StoreEntity store,
})
```

### 인터랙션

| 조건 | 렌더링 |
|---|---|
| `store.brandId != null && store.status == approved` | ElevatedButton 노출 |
| `store.brandId == null` | SizedBox.shrink() — 개인 매장에는 비노출 |
| `store.status == pending` | SizedBox.shrink() |
| `store.status == rejected` | SizedBox.shrink() |

---

## 2. OwnerStoreMenuListPage 갱신 — 품절 토글 + 옵션 관리 추가

- 파일: `presentation/owner/store_menu/owner_store_menu_list_page.dart` (갱신)
- 역할: 기존 카드에 `_SoldOutToggle` 추가 + long-press 액션 시트에 "옵션 관리" 항목 추가

### 갱신 범위 개요

| 항목 | 변경 |
|---|---|
| 카드 인라인 토글 영역 | visible 토글 옆에 `_SoldOutToggle` 추가 |
| 카드 상태 시각 | `soldOut == true` 시 error 오버레이 + "품절" 배지 |
| long-press 액션 시트 | "옵션 관리" 항목 추가 |

### OwnerStoreMenuCard 갱신 — 카드 인라인 토글 영역

기존 카드의 이름 Row 에서 `_InlineVisibleToggle` 을 감싸던 Row 를 확장하여 `_SoldOutToggle` 을 추가한다.

```
Row
  ├─ Expanded — Text (메뉴 이름, fontSize 15, w700, AppColors.textHeading, maxLines 1, overflow: ellipsis)
  ├─ SizedBox(width: 8)
  ├─ _InlineVisibleToggle (sub-phase 4 산출 — 변경 없음, activeColor: AppColors.primary)
  ├─ SizedBox(width: 4)
  └─ _SoldOutToggle (신규 — activeColor: AppColors.error)
```

> 두 스위치 사이 간격: `SizedBox(width: 4)` — 너무 좁지 않게, 너무 벌어지지 않게.
> 화면 너비가 작은 기기에서 텍스트가 밀릴 수 있으므로 `Expanded` 로 텍스트가 줄어들도록 한다.

### OwnerStoreMenuCard 갱신 — soldOut 상태 시각

카드 전체를 `Stack` 으로 감싸거나, `Container` decoration 으로 조건부 오버레이를 구현한다.

```
Stack
  ├─ [기존 카드 콘텐츠] (변경 없음)
  └─ (soldOut == true) Positioned.fill
       └─ Container
            decoration:
              color: AppColors.error.withOpacity(0.06)
              borderRadius: 16
```

배지 영역 (soldOut/hidden 중 하나만 노출):

```
(카드 콘텐츠 Row 아래 또는 이름 Row 내부 leading 영역)
if soldOut == true:
  _SoldOutBadge
elif visible == false:
  _HiddenBadge

_SoldOutBadge:
  Container
    decoration: color AppColors.error.withOpacity(0.12), radius 6, border AppColors.error.withOpacity(0.3) 1px
    Padding(horizontal 6, vertical 2)
      Text '품절' (fontSize 10, w700, AppColors.error)

_HiddenBadge:
  Container
    decoration: color AppColors.textMuted.withOpacity(0.12), radius 6
    Padding(horizontal 6, vertical 2)
      Text '비공개' (fontSize 10, w600, AppColors.textMuted)
```

배지 위치: 메뉴 이름 Row 에서 `Expanded(Text)` 바로 오른쪽, `_InlineVisibleToggle` 왼쪽.

```
Row
  ├─ Expanded — Text (메뉴 이름 ...)
  ├─ SizedBox(width: 4)
  ├─ if soldOut → _SoldOutBadge
     elif !visible → _HiddenBadge
  ├─ SizedBox(width: 8)
  ├─ _InlineVisibleToggle
  ├─ SizedBox(width: 4)
  └─ _SoldOutToggle
```

### OwnerStoreMenuCard 갱신 — Long-press 액션 시트

기존 액션 시트에 "옵션 관리" 항목 추가. 위치: "편집" 위 (최상단, 자주 쓰는 운영 액션 강조).

```
Container (AppColors.surfaceElevated, radius-top 20)
  └─ SafeArea
       └─ Padding(horizontal 16, vertical 8)
            └─ Column
                 ├─ _BottomSheetHandle (8×4 둥근 바, AppColors.border)
                 ├─ SizedBox(height: 8)
                 ├─ ListTile '옵션 관리'                    ← 신규 추가 (최상단)
                 │    leading: Icon(Icons.tune_rounded, AppColors.primary)
                 │    title: Text('옵션 관리', fontSize 15, AppColors.textBody)
                 │    onTap: → showModalBottomSheet → MenuOptionDisableSheet
                 ├─ Divider(height: 1, color: AppColors.border)
                 ├─ ListTile '편집' (기존 그대로)
                 ├─ ListTile '복제' (기존 그대로)
                 └─ ListTile '삭제' (기존 그대로)
```

### 인터랙션 정리 (갱신분)

| 동작 | 반응 |
|---|---|
| 품절 토글 ON | `_SoldOutToggle.onChanged(true)` → `ToggleSoldOutForPersonalMenuUseCase` 즉시 호출 → 카드 error 오버레이 + "품절" 배지 |
| 품절 토글 OFF | `_SoldOutToggle.onChanged(false)` → UseCase 호출 → 오버레이 / 배지 제거 |
| 토글 실패 | 이전 값으로 UI 원복 + SnackBar `'변경에 실패했어요'` |
| 액션 시트 "옵션 관리" | `showModalBottomSheet` → `MenuOptionDisableSheet(storeId, menuItem, menuType: personal)` |

---

## 3. OwnerStoreMenuDetailPage 갱신 — 품절 토글 + 옵션 관리 추가

- 파일: `presentation/owner/store_menu/owner_store_menu_detail_page.dart` (갱신)
- 역할: 상세 페이지에 품절 상태 시각 + PopupMenuButton 에 "옵션 관리" 항목 추가

### 갱신 범위 개요

| 항목 | 변경 |
|---|---|
| AppBar PopupMenuButton | "옵션 관리" 항목 추가 |
| 이미지 영역 오버레이 | `soldOut == true` 시 "품절" 오버레이 배지 |
| 기본 정보 섹션 | `_InfoRow('품절 여부', ...)` 추가 |

### AppBar PopupMenuButton 갱신

```
PopupMenuButton (아이콘: Icons.more_vert_rounded, color: AppColors.textHeading)
  ├─ PopupMenuItem '옵션 관리'                              ← 신규 추가 (최상단)
  │    탭 → showModalBottomSheet → MenuOptionDisableSheet(storeId, item, menuType: personal)
  ├─ PopupMenuItem '수정' (기존 그대로)
  ├─ PopupMenuItem '복제' (기존 그대로)
  └─ PopupMenuItem '삭제' (기존 그대로, textStyle: AppColors.error)
```

### 이미지 영역 soldOut 오버레이

`soldOut == true` 일 때 이미지 위에 반투명 오버레이 + "품절" 라벨 표시.

```
Stack
  ├─ [이미지 영역] (기존 그대로 — width 전체, height 220)
  └─ (soldOut == true) Positioned.fill
       └─ Container
            decoration: color AppColors.error.withOpacity(0.45), borderRadius: 0 (이미지 영역 맞춤)
            └─ Center
                 └─ Container
                      decoration: color AppColors.error, radius 8
                      Padding(horizontal 16, vertical 8)
                        Text '품절' (fontSize 18, w700, AppColors.onPrimary, letterSpacing: 1)
```

### 기본 정보 섹션 갱신 — 카테고리/태그 _DetailSectionCard

기존 `_InfoRow('메뉴 노출', ...)` 아래에 품절 상태 Row 추가:

```
_DetailSectionCard
  └─ Column
       ├─ _InfoRow('카테고리', ...)
       ├─ SizedBox(height: 8)
       ├─ _InfoRow('노출 순서', '$displayOrder')
       ├─ SizedBox(height: 8)
       ├─ _InfoRow('메뉴 노출', item.visible ? '노출 중' : '숨김')
       ├─ SizedBox(height: 8)
       ├─ _InfoRow('품절 여부', item.soldOut ? '품절' : '판매 중')    ← 신규 추가
       │    value 색상: item.soldOut ? AppColors.error : AppColors.success
       └─ (tags) ...
```

`_InfoRow` 의 value 색상을 조건부 적용할 수 있도록 `_InfoRow` 에 `valueColor` 파라미터 추가 (선택):

```dart
_InfoRow(label, value, {Color? valueColor})
// valueColor 없으면 기존 AppColors.textBody 사용
```

### 인터랙션 정리 (갱신분)

| 동작 | 반응 |
|---|---|
| PopupMenu "옵션 관리" 탭 | `showModalBottomSheet` → `MenuOptionDisableSheet(storeId, item, menuType: personal)` |
| 옵션 시트에서 즉시 저장 | 화면 stream 자동 갱신 |

---

## 4. OwnerBrandStoreMenusPage (신규)

- 파일: `presentation/owner/brand_store/owner_brand_store_menus_page.dart`
- 역할: 브랜드 매장 점주가 자기 매장 메뉴(마스터 ref + 점포 한정)를 보고 품절/옵션 토글
- 참조 패턴: sub-phase 4 `OwnerStoreMenuListPage` 구조 기반 + scope 분기 배지 추가

### 레이아웃

```
Scaffold
  배경: AppColors.background
  AppBar:
    title: '메뉴 관리'
    fontSize 17, w700, AppColors.textHeading
    backgroundColor: AppColors.background, elevation 0, surfaceTintColor: transparent
    leading: Icons.arrow_back_ios_new_rounded, color AppColors.textHeading
  body:
    Column
      ├─ _BrandStoreInfoBanner (안내 배너 — 최상단 고정)
      └─ Expanded
           └─ ListView.builder (padding: EdgeInsets.fromLTRB(16, 8, 16, 32))
                └─ _BrandStoreMenuCard (각 메뉴)
```

FAB 없음 (점주는 메뉴 추가 불가).

### _BrandStoreInfoBanner (안내 배너)

```
Container
  decoration:
    color: AppColors.info.withOpacity(0.08)
    border-bottom: AppColors.info.withOpacity(0.25) 1px
  Padding(horizontal 16, vertical 12)
    Row
      ├─ Icon(Icons.info_outline_rounded, size 16, AppColors.info)
      ├─ SizedBox(width: 10)
      └─ Expanded
           └─ Text(
                '점주는 품절과 옵션 비활성화만 가능해요. 메뉴 추가/수정은 브랜드 본사에서 관리합니다.',
                fontSize 12, AppColors.info, height 1.5
              )
```

### _BrandStoreMenuCard

```
Card (AppColors.surfaceElevated, radius 16, border AppColors.border 1px, shadow AppColors.primary.withOpacity(0.04))
  └─ InkWell (radius 16, onTap: 없음 — 브랜드 매장 점주는 상세 편집 불가)
       └─ Padding(12)
            └─ Row
                 ├─ ClipRRect (radius 10, 72×72) ← 메뉴 이미지 (read-only)
                 ├─ SizedBox(width: 12)
                 └─ Expanded
                      ├─ Row
                      │    ├─ [스코프 배지] _ScopeBadge (brand or store)
                      │    ├─ SizedBox(width: 6)
                      │    ├─ Expanded — Text (메뉴 이름, fontSize 15, w700, AppColors.textHeading, maxLines 1, overflow: ellipsis)
                      │    ├─ SizedBox(width: 4)
                      │    ├─ if soldOut → _SoldOutBadge
                      │    ├─ SizedBox(width: 8)
                      │    └─ _SoldOutToggle (activeColor: AppColors.error)   ← visible 토글 없음
                      ├─ SizedBox(height: 4)
                      ├─ Text (설명 1줄, fontSize 13, AppColors.textMuted, maxLines 1, overflow: ellipsis)
                      ├─ SizedBox(height: 8)
                      └─ Row
                           ├─ Text ('₩{basePrice}', fontSize 14, w600, AppColors.textHeading)
                           │    (priceOverride 있으면 '₩{priceOverride}' — 머지된 값)
                           └─ Spacer
                           └─ _BrandCardActions (옵션 관리 버튼만)
```

#### _ScopeBadge

마스터 메뉴 ref(scope=brand) 와 점포 한정 메뉴(scope=store) 를 구분하는 배지.

```
_ScopeBadge.brand:
  Container
    decoration: color AppColors.primary.withOpacity(0.10), radius 6
    Padding(horizontal 6, vertical 2)
      Text '마스터' (fontSize 10, w600, AppColors.primary)

_ScopeBadge.storeOnly:
  Container
    decoration: color AppColors.accent.withOpacity(0.10), radius 6
    Padding(horizontal 6, vertical 2)
      Text '매장 한정' (fontSize 10, w600, AppColors.accent)
```

#### _BrandCardActions (옵션 관리 단일 버튼)

```
IconButton(
  icon: Icon(Icons.tune_rounded, size 20, AppColors.primary),
  tooltip: '옵션 관리',
  onTap: → showModalBottomSheet → MenuOptionDisableSheet(storeId, menuItem, menuType 분기)
)
```

편집 / 복제 / 삭제 아이콘 없음.

#### 메뉴 이미지 Placeholder

- sub-phase 4 패턴 동일:
  - 배경: `AppColors.surface`, radius 10, 72×72
  - 아이콘: `Icons.local_cafe_outlined`, size 28, `AppColors.textMuted`

#### soldOut 상태 시각

```
Stack
  ├─ [카드 콘텐츠] (기존)
  └─ (soldOut == true) Positioned.fill
       └─ Container
            decoration: color AppColors.error.withOpacity(0.06), radius 16
```

#### excluded 처리 (W7 결정)

override 의 `excluded == true` (admin 승인된 경우) 인 마스터 메뉴 ref 는 카드 비노출 또는 "매장 제외됨" 안내로 처리.

**채택: 카드 비노출** (머지 결과 watchByStore 가 excluded=approved 인 항목을 제외하여 반환하므로, 화면 단에서는 별도 처리 불필요).  
단, 혹시 머지 결과에 포함될 경우를 대비해 카드 단에서도 방어 처리:

```
if (item.excluded == true && item.excludedApproved == true)
  return SizedBox.shrink(); // 또는 개발자 판단에 따라 "매장 제외됨" 읽기 전용 행 표시
```

### Long-press 액션 시트

수정/복제/삭제 없음. "옵션 관리" 만 노출.

```
Container (AppColors.surfaceElevated, radius-top 20)
  └─ SafeArea
       └─ Padding(horizontal 16, vertical 8)
            └─ Column
                 ├─ _BottomSheetHandle (8×4 둥근 바, AppColors.border)
                 ├─ SizedBox(height: 8)
                 └─ ListTile '옵션 관리'
                      leading: Icon(Icons.tune_rounded, AppColors.primary)
                      title: Text('옵션 관리', fontSize 15, AppColors.textBody)
                      onTap: → showModalBottomSheet → MenuOptionDisableSheet
```

### 상태별 UI

#### Loading

```
Column
  ├─ _BrandStoreInfoBanner (항상 표시)
  └─ Expanded
       └─ Center
            └─ CircularProgressIndicator(color: AppColors.primary)
```

#### Error

```
Column
  ├─ _BrandStoreInfoBanner
  └─ Expanded
       └─ Center
            └─ Column
                 ├─ Icon(Icons.error_outline_rounded, 48, AppColors.error)
                 ├─ SizedBox(height: 16)
                 ├─ Text '메뉴를 불러오지 못했어요' (fontSize 16, w700, AppColors.textHeading)
                 ├─ SizedBox(height: 8)
                 ├─ Text '잠시 후 다시 시도해주세요' (fontSize 13, AppColors.textMuted)
                 ├─ SizedBox(height: 24)
                 └─ ElevatedButton '다시 시도'
                      배경: AppColors.primary, 텍스트: AppColors.onPrimary
                      radius: 12, onTap: → ref.refresh(ownerBrandStoreMenusProvider(storeId))
```

#### Empty (메뉴 0건)

```
Column
  ├─ _BrandStoreInfoBanner
  └─ Expanded
       └─ Center
            └─ Column
                 ├─ Icon(Icons.menu_book_outlined, size 56, AppColors.textMuted)
                 ├─ SizedBox(height: 20)
                 ├─ Text '아직 등록된 메뉴가 없어요' (fontSize 16, w600, AppColors.textHeading)
                 ├─ SizedBox(height: 8)
                 └─ Text '브랜드 본사에서 마스터 메뉴를 추가하면 여기에 표시돼요.'
                         (fontSize 13, AppColors.textMuted, 중앙 정렬)
```

### 인터랙션 정리

| 동작 | 반응 |
|---|---|
| 카드 탭 | 반응 없음 (read-only 화면 — 개별 탭 시 옵션 관리 아이콘으로 안내) |
| 카드 long-press | 액션 시트 ("옵션 관리" 만) |
| 품절 토글 ON (마스터 ref) | `ToggleSoldOutForOverrideUseCase` 호출 (override upsert) |
| 품절 토글 ON (점포 한정) | `ToggleSoldOutForBrandStoreOnlyMenuUseCase` 호출 |
| 품절 토글 실패 | UI 원복 + SnackBar `'변경에 실패했어요'` |
| 옵션 관리 아이콘 탭 | `showModalBottomSheet` → `MenuOptionDisableSheet(storeId, menuItem, menuType 분기)` |

---

## 5. 화면 흐름 요약 (sub-phase 5 전체)

```
OwnerMyStorePage
  ├─ (brandId==null && approved) → _MenuManagementButton '메뉴 관리'
  │    └─ OwnerStoreMenuListPage (sub-phase 4 + 5 갱신)
  │         ├─ visible 토글 (_InlineVisibleToggle — 기존)
  │         ├─ 품절 토글 (_SoldOutToggle — 신규)
  │         ├─ 카드 long-press → 액션 시트
  │         │    └─ '옵션 관리' → MenuOptionDisableSheet(menuType: personal)
  │         └─ 카드 탭 → OwnerStoreMenuDetailPage (갱신)
  │              └─ PopupMenu '옵션 관리' → MenuOptionDisableSheet(menuType: personal)
  │
  └─ (brandId!=null && approved) → _BrandMenuManagementButton '메뉴 옵션·품절 관리'
       └─ OwnerBrandStoreMenusPage (신규)
            ├─ 안내 배너 (고정)
            ├─ 카드: 마스터 ref / 점포 한정 구분 배지
            ├─ 품절 토글 (_SoldOutToggle — 신규)
            └─ 카드 long-press / 옵션 아이콘 → MenuOptionDisableSheet(menuType 분기)
```
