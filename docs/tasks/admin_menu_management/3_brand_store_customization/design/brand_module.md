# Brand 모듈 디자인 명세 — sub-phase 3 (brand_store_customization)

> 파일 위치: `lib/presentation/brand/`
> 참조: sub-phase 1 `brand_module.md`, sub-phase 2 `owner_module.md`, designer_guide.md

---

## 디자인 결정사항 요약

- **BrandScaffold 탭 갱신**: sub-phase 1 의 3탭 ("브랜드 정보" / "마스터 메뉴" / "더보기") → 4탭 ("브랜드 정보" / "마스터 메뉴" / "매장" / "더보기"). 매장 탭이 인덱스 2 에 삽입되고 더보기는 인덱스 3 으로 이동한다.
- **BrandStoresPage**: 매장 카드에 `StoreScopeBadge.brand(brandName)` + `ApprovalStatusBadge` 함께 노출.
- **BrandStoreCustomizationPage**: IndexedStack 2탭 (가격 오버라이드 / 점포 한정 메뉴). sub-phase 1 의 인라인 탭 바 패턴 동일.
- **BrandApprovalTrackingPage**: 탭 분리 미채택. 단일 리스트 + 타입 뱃지 방식.

---

## 1. BrandScaffold (수정 — 4탭화)

- 파일: `presentation/brand/brand_scaffold.dart`
- 변경: 매장 탭 (인덱스 2) 삽입. 더보기는 인덱스 3 으로 이동.

### 탭 구성 (4탭)

| 인덱스 | 라벨 | 아이콘 | 페이지 |
|---|---|---|---|
| 0 | `'브랜드 정보'` | `Icons.storefront_rounded` | `BrandInfoPage` |
| 1 | `'마스터 메뉴'` | `Icons.menu_book_rounded` | `MasterMenuListPage` |
| 2 | `'매장'` | `Icons.location_city_rounded` | `BrandStoresPage` |
| 3 | `'더보기'` | `Icons.more_horiz_rounded` | `BrandMorePage` |

### 스타일 변경 없음

sub-phase 1 의 Scaffold / BottomNav / `_BrandNavItem` 스타일 그대로 유지.

---

## 2. BrandStoresPage

- 파일: `presentation/brand/stores/brand_stores_page.dart`
- 역할: 현재 brand 가 운영하는 매장 리스트 + 등록 FAB

### 레이아웃

```
Scaffold
  ├─ backgroundColor: AppColors.background
  ├─ AppBar
  │    - title: '매장 관리', fontSize 17, w700, AppColors.textHeading
  │    - backgroundColor: AppColors.background
  │    - surfaceTintColor: transparent
  │    - elevation: 0
  ├─ body: ListView.builder (padding: horizontal 16, vertical 12)
  │         └─ BrandStoreCard (각 매장)
  └─ floatingActionButton: _AddStoreFAB
```

### _AddStoreFAB

```
FloatingActionButton.extended
  ├─ backgroundColor: AppColors.primary
  ├─ foregroundColor: AppColors.onPrimary
  ├─ icon: Icon(Icons.add_rounded, 20)
  ├─ label: Text('매장 등록', fontSize 14, w600)
  ├─ elevation: 3
  └─ onPressed: Navigator.push → BrandStoreFormPage(mode: create)
```

### 빈 상태 (매장 0개)

```
Center
  └─ Column (mainAxisSize: min)
       ├─ Icon(Icons.location_city_outlined, 56, AppColors.textMuted)
       ├─ SizedBox(height: 20)
       ├─ Text '등록된 매장이 없어요', fontSize 16, w600, AppColors.textHeading
       ├─ SizedBox(height: 8)
       ├─ Text '첫 번째 매장을 등록하고 운영을 시작해보세요.',
       │       fontSize 13, AppColors.textMuted, 중앙 정렬
       ├─ SizedBox(height: 28)
       └─ ElevatedButton.icon
            ├─ backgroundColor: AppColors.primary
            ├─ foregroundColor: AppColors.onPrimary
            ├─ icon: Icon(Icons.add_rounded, 18)
            ├─ label: Text('매장 등록하기', fontSize 14, w600)
            ├─ radius: 12
            ├─ padding: horizontal 24, vertical 14
            └─ onPressed: Navigator.push → BrandStoreFormPage(mode: create)
```

### 로딩 / 에러

| 상태 | UI |
|---|---|
| 로딩 | `Center → CircularProgressIndicator(color: AppColors.primary)` |
| 에러 | 공통 에러 패턴 — 아이콘 `Icons.error_outline_rounded` 48, 제목 `'매장 목록을 불러오지 못했어요'`, 재시도 버튼 `ref.refresh(brandStoresProvider)` |

---

## 3. BrandStoreCard

- 파일: `presentation/brand/stores/widgets/brand_store_card.dart`
- 역할: 매장 리스트 내 개별 카드

### 위젯 구조

```
Card
  ├─ color: AppColors.surfaceElevated
  ├─ borderRadius: 14
  ├─ border: AppColors.border 1px
  ├─ elevation: 0
  ├─ shadow: AppColors.primary.withOpacity(0.04) blurRadius 8
  └─ InkWell (radius: 14, onTap: → BrandStoreCustomizationPage)
       └─ Padding(horizontal 16, vertical 14)
            └─ Column (crossAxisAlignment: start)
                 ├─ Row
                 │    ├─ Expanded
                 │    │    └─ Text(매장이름, fontSize 15, w600, AppColors.textHeading,
                 │    │              maxLines 1, overflow ellipsis)
                 │    └─ ApprovalStatusBadge(status: store.status,
                 │                            isRevision: store.approvedAt != null)
                 ├─ SizedBox(height: 6)
                 ├─ Row
                 │    ├─ Icon(Icons.location_on_outlined, 13, AppColors.textMuted)
                 │    ├─ SizedBox(width: 3)
                 │    └─ Expanded
                 │         └─ Text(store.address, fontSize 12, AppColors.textMuted,
                 │                   maxLines 1, overflow ellipsis)
                 ├─ SizedBox(height: 8)
                 └─ Row
                      ├─ StoreScopeBadge.brand(brandName)   ← primary 톤
                      └─ Spacer
                      └─ Row
                           ├─ Text('커스텀 관리', fontSize 12, w500, AppColors.primaryBright)
                           └─ Icon(Icons.chevron_right_rounded, 14, AppColors.primaryBright)
```

### 카드 여백

- 카드 간 `SizedBox(height: 10)`
- 마지막 카드 아래 `SizedBox(height: 80)` (FAB 가림 방지)

---

## 4. BrandStoreFormPage

- 파일: `presentation/brand/stores/brand_store_form_page.dart`
- 역할: brand 가 매장 신규 등록 / 핵심 필드 수정
- 진입 경로:
  - `BrandStoresPage` FAB / 빈 상태 CTA → 신규 등록 모드
  - (미래) 매장 정보 수정 → 수정 모드 (본 sub-phase 비범위)

### AppBar

```
AppBar
  ├─ backgroundColor: AppColors.background
  ├─ elevation: 0
  ├─ leading: IconButton(Icons.close_rounded, AppColors.textHeading)
  │             onPressed: Navigator.pop
  └─ title: Text('매장 등록', fontSize 17, w700, AppColors.textHeading)
```

### 검수 안내 배너 (폼 최상단)

sub-phase 2 `StoreCoreFormPage` 의 검수 안내 배너 동일 패턴.

```
Container
  ├─ decoration:
  │    color: AppColors.info.withOpacity(0.08)
  │    borderRadius: 12
  │    border: AppColors.info.withOpacity(0.3) 1px
  └─ Padding(horizontal 14, vertical 10)
       └─ Row
            ├─ Icon(Icons.info_outline_rounded, 16, AppColors.info)
            ├─ SizedBox(width: 8)
            └─ Expanded
                 └─ Text('아래 매장 정보는 관리자 검토 후 반영돼요.',
                          fontSize 12, AppColors.info, height 1.4)
```

### 섹션 A — 핵심 필드

섹션 헤더:
```
Text('매장 기본 정보', fontSize 13, w700, AppColors.textMuted)
SizedBox(height: 12)
```

필드 순서:

1. **매장명** (`_FormField`, 필수, maxLength 30, label `'매장명'`, placeholder `'매장 이름을 입력해주세요'`)
2. `SizedBox(height: 20)`
3. **주소 + 좌표** (`_AddressSearchTile` — sub-phase 2 패턴 재사용, 필수)
4. `SizedBox(height: 8)` + 주소 수동 입력 텍스트 필드
5. `SizedBox(height: 20)`
6. **카테고리** (`_CategoryMultiSelect` — sub-phase 2 패턴 재사용, 필수)
7. `SizedBox(height: 20)`
8. **사업자등록번호** (`_FormField`, 선택, keyboardType: number, label `'사업자등록번호'`, placeholder `'000-00-00000'`)

### 섹션 B — 마스터 메뉴 선택 (U2)

섹션 헤더:
```
SizedBox(height: 28)
Divider(color: AppColors.border, height: 1)
SizedBox(height: 24)
Row
  ├─ Text('운영할 마스터 메뉴 선택', fontSize 13, w700, AppColors.textMuted)
  └─ Spacer
  └─ Text('미선택 메뉴는 이 매장에서 제외됩니다', fontSize 11, AppColors.textMuted)
SizedBox(height: 12)
```

`MasterMenuChipMultiSelect` 위젯:

```
Wrap (spacing: 8, runSpacing: 8)
  └─ for each masterMenuItem:
       FilterChip
         ├─ selected: enabledIds.contains(item.id)
         ├─ label: Text(item.name, fontSize 13, w500)
         ├─ selected 스타일:
         │    배경: AppColors.primary
         │    텍스트: AppColors.onPrimary
         │    border: 없음
         └─ unselected 스타일:
              배경: AppColors.surfaceElevated
              border: AppColors.border 1px
              텍스트: AppColors.textBody
```

마스터 메뉴 0개일 때 안내:
```
Container
  ├─ decoration: AppColors.surface 배경, radius 10, border AppColors.border 1px
  └─ Padding(16)
       └─ Text '등록된 마스터 메뉴가 없어요. 마스터 메뉴를 먼저 등록해주세요.',
                fontSize 13, AppColors.textMuted, 중앙 정렬
```

전체 선택 / 해제 버튼:
```
Row (mainAxisAlignment: end)
  └─ TextButton
       label: (전체 선택 상태이면) '전체 해제' / (아니면) '전체 선택'
       style: AppColors.primaryBright, fontSize 12, w600
```

### 섹션 C — 운영 필드

섹션 헤더:
```
SizedBox(height: 28)
Divider(color: AppColors.border, height: 1)
SizedBox(height: 24)
Row
  ├─ Text('운영 정보 (선택)', fontSize 13, w700, AppColors.textMuted)
  └─ Spacer
  └─ Container (pill)
       └─ Text('즉시 반영', fontSize 11, w600, AppColors.success)
       └─ (배경: AppColors.success.withOpacity(0.12))
SizedBox(height: 12)
```

즉시 반영 안내 배너:
```
Container
  ├─ decoration:
  │    color: AppColors.success.withOpacity(0.08)
  │    borderRadius: 12
  │    border: AppColors.success.withOpacity(0.3) 1px
  └─ Padding(horizontal 14, vertical 10)
       └─ Row
            ├─ Icon(Icons.check_circle_outline_rounded, 16, AppColors.success)
            ├─ SizedBox(width: 8)
            └─ Expanded
                 └─ Text('운영 정보는 등록 즉시 반영돼요.',
                          fontSize 12, AppColors.success, height 1.4)
```

운영 필드 순서:
1. **대표 이미지** (`ImageUploadField` — sub-phase 1 재사용)
2. `SizedBox(height: 20)`
3. **전화번호** (`_FormField`, keyboardType: phone, label `'전화번호'`, placeholder `'010-0000-0000'`)
4. `SizedBox(height: 20)`
5. **영업시간** (`_BusinessHoursPicker` — sub-phase 2 재사용)
6. `SizedBox(height: 20)`
7. **소개** (`_FormField`, maxLength 200, maxLines 4, label `'매장 소개'`)

### ListView padding

`EdgeInsets.fromLTRB(20, 12, 20, 120)`

### _SubmitBar (하단 고정 저장 버튼)

sub-phase 2 `StoreCoreFormPage._SubmitBar` 재사용.

```
SafeArea
  └─ Container(padding: horizontal 20 vertical 12)
       └─ SizedBox(width: double.infinity, height: 52)
            └─ ElevatedButton
                 ├─ 활성: backgroundColor AppColors.primary, 텍스트 AppColors.onPrimary, w700, 16
                 ├─ disabled: backgroundColor AppColors.surface, 텍스트 AppColors.textMuted
                 ├─ radius: 14
                 └─ label: '검토 요청 보내기'
```

저장 성공: SnackBar `'검토 요청을 보냈어요'` (AppColors.primary.withOpacity(0.9) 배경, AppColors.onPrimary 텍스트) + Navigator.pop

저장 중: 버튼 내부 `CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2)` + 버튼 disabled

---

## 5. BrandStoreCustomizationPage

- 파일: `presentation/brand/customization/brand_store_customization_page.dart`
- 역할: 매장 커스텀 진입점 (가격 오버라이드 / 점포 한정 메뉴 2탭)

### AppBar

```
AppBar
  ├─ backgroundColor: AppColors.background
  ├─ elevation: 0
  ├─ surfaceTintColor: transparent
  ├─ leading: IconButton(Icons.close_rounded, AppColors.textHeading)
  └─ title: Text(store.name, fontSize 17, w700, AppColors.textHeading)
```

### 인라인 탭 바 (sub-phase 1 패턴 동일)

```
PreferredSize (preferredSize: Size.fromHeight(44))
  └─ Container (border-bottom: AppColors.border 1px)
       └─ Row
            ├─ _CustTab('가격 오버라이드', index: 0)
            └─ _CustTab('점포 한정 메뉴', index: 1)
```

`_CustTab` 스타일 (sub-phase 1 `_SegTab` 동일):
- `Expanded` + `InkWell`
- 높이: 44
- 활성: 텍스트 `AppColors.primary` w600, 하단 2px 언더라인 `AppColors.primary`
- 비활성: 텍스트 `AppColors.textMuted` w500
- 텍스트 fontSize: 14
- 중앙 정렬

### body — IndexedStack

```
IndexedStack
  ├─ index 0: BrandPriceOverrideListPage(storeId: store.id)
  └─ index 1: BrandStoreOnlyMenuListPage(storeId: store.id)
```

---

## 6. BrandPriceOverrideListPage (탭 A 내부 콘텐츠)

- 파일: `presentation/brand/customization/price_override/brand_price_override_list_page.dart`
- 역할: 마스터 메뉴 리스트 + override 적용 현황
- 최상위: `Widget` (BrandStoreCustomizationPage 의 IndexedStack 자식 — Scaffold 없음)

### 레이아웃

```
Column
  ├─ (상단 안내 배너 — 선택적)
  └─ Expanded
       └─ ListView.builder (padding: horizontal 16, vertical 12)
            └─ MasterMenuOverrideCard (각 마스터 메뉴)
```

### 빈 상태

```
Center
  └─ Column
       ├─ Icon(Icons.menu_book_outlined, 56, AppColors.textMuted)
       ├─ SizedBox(height: 20)
       ├─ Text '마스터 메뉴를 먼저 등록해주세요', fontSize 16, w600, AppColors.textHeading
       ├─ SizedBox(height: 8)
       └─ Text '마스터 메뉴 탭에서 메뉴를 등록하면 이곳에서 가격을 조정할 수 있어요.',
                fontSize 13, AppColors.textMuted, 중앙 정렬
```

CTA 없음 (마스터 메뉴 탭은 다른 BrandScaffold 탭에 존재).

### 로딩 / 에러

| 상태 | UI |
|---|---|
| 로딩 | `Center → CircularProgressIndicator(color: AppColors.primary)` |
| 에러 | 공통 에러 패턴, 제목 `'메뉴 목록을 불러오지 못했어요'` |

---

## 7. MasterMenuOverrideCard (공통 컴포넌트 — 여기 정의)

- 파일: `presentation/brand/customization/price_override/widgets/master_menu_override_card.dart`
- 역할: 마스터 메뉴 + override 현황 표시. 탭 → `BrandPriceOverrideFormPage`

### 위젯 구조

```
Card
  ├─ color: AppColors.surfaceElevated
  ├─ borderRadius: 14
  ├─ border: AppColors.border 1px
  ├─ elevation: 0
  ├─ shadow: AppColors.primary.withOpacity(0.04) blurRadius 8
  └─ InkWell(radius: 14, onTap: → BrandPriceOverrideFormPage)
       └─ Padding(horizontal 16, vertical 14)
            └─ Column (crossAxisAlignment: start)
                 ├─ Row
                 │    ├─ Expanded
                 │    │    └─ Text(마스터 메뉴 이름, fontSize 15, w600, AppColors.textHeading)
                 │    └─ (override 존재 시) ApprovalStatusBadge(override.status,
                 │                              isRevision: override.approvedAt != null)
                 ├─ SizedBox(height: 6)
                 ├─ _PriceRow          ← 가격 미리보기
                 ├─ SizedBox(height: 8)
                 └─ Row
                      ├─ (override.excluded == true) _ExcludedChip
                      └─ Spacer
                      └─ Icon(Icons.chevron_right_rounded, 16, AppColors.textMuted)
```

### _PriceRow — 가격 미리보기 형식

override 없거나 status=pending/rejected 인 경우:
```
Row
  └─ Text('₩{basePrice}', fontSize 14, w500, AppColors.textBody)
```

override.priceOverride 있고 status=approved 인 경우 (확정 변경):
```
Row
  ├─ Text('₩{basePrice}', fontSize 13, AppColors.textMuted,
  │       decoration: TextDecoration.lineThrough)
  ├─ SizedBox(width: 6)
  ├─ Text('→', fontSize 13, AppColors.textMuted)
  ├─ SizedBox(width: 6)
  └─ Text('₩{priceOverride}', fontSize 14, w700, AppColors.primary)
```

override.priceOverride 있고 status=pending 인 경우 (검토 중):
```
Row
  ├─ Text('₩{basePrice}', fontSize 13, AppColors.textBody, w500)
  ├─ SizedBox(width: 8)
  └─ Text('→ ₩{priceOverride} (검토 중)', fontSize 12, AppColors.warning, w500)
```

### _ExcludedChip

```
Container (pill)
  ├─ decoration:
  │    color: AppColors.error.withOpacity(0.10)
  │    borderRadius: 999
  ├─ padding: horizontal 8, vertical 3
  └─ Row
       ├─ Icon(Icons.remove_circle_outline_rounded, 11, AppColors.error)
       ├─ SizedBox(width: 3)
       └─ Text('이 매장 제외', fontSize 11, w600, AppColors.error)
```

excluded=true 이고 status=pending 이면 뱃지 색: `AppColors.warning` 톤으로 (`'제외 검토 중'`)
excluded=true 이고 status=approved 이면 `AppColors.error` 톤 (`'이 매장 제외'`)

---

## 8. BrandPriceOverrideFormPage

- 파일: `presentation/brand/customization/price_override/brand_price_override_form_page.dart`
- 역할: 단일 마스터 메뉴의 가격 오버라이드 등록 / 수정

### AppBar

```
AppBar
  ├─ backgroundColor: AppColors.background
  ├─ elevation: 0
  ├─ leading: IconButton(Icons.close_rounded, AppColors.textHeading)
  └─ title: Text('가격 오버라이드', fontSize 17, w700, AppColors.textHeading)
```

### 마스터 메뉴 정보 카드 (read-only)

```
Container
  ├─ decoration:
  │    color: AppColors.surface
  │    borderRadius: 12
  │    border: AppColors.border 1px
  └─ Padding(16)
       └─ Column (crossAxisAlignment: start)
            ├─ Text('마스터 메뉴', fontSize 12, w600, AppColors.textMuted)
            ├─ SizedBox(height: 8)
            ├─ Text(masterMenu.name, fontSize 16, w700, AppColors.textHeading)
            ├─ SizedBox(height: 4)
            └─ Text('기준 가격: ₩{basePrice}', fontSize 13, AppColors.textBody, w500)
```

### PriceOverrideInput 위젯 (공통 컴포넌트)

`presentation/brand/customization/widgets/price_override_input.dart`

```
Column (crossAxisAlignment: start)
  ├─ Text('변경할 가격', fontSize 13, w600, AppColors.textBody)
  ├─ SizedBox(height: 8)
  ├─ TextField
  │    ├─ keyboardType: TextInputType.number
  │    ├─ decoration:
  │    │    - background: AppColors.surfaceElevated
  │    │    - border: AppColors.border 1px, radius 12
  │    │    - focusBorder: AppColors.primary 1px
  │    │    - hint: '₩{basePrice}' (마스터 가격 placeholder)
  │    │    - hintStyle: AppColors.textMuted
  │    │    - prefix: Text('₩', fontSize 16, AppColors.textBody)
  │    │    - suffix: Text('원', fontSize 14, AppColors.textMuted)
  │    └─ inputFormatters: NumberTextInputFormatter (천 단위 콤마)
  └─ (priceOverride 입력 중일 때) 미리보기 Row:
       SizedBox(height: 8)
       Row
         ├─ Text('₩{basePrice}', fontSize 13, AppColors.textMuted,
         │       decoration: TextDecoration.lineThrough)
         ├─ SizedBox(width: 6)
         ├─ Icon(Icons.arrow_forward_rounded, 14, AppColors.textMuted)
         ├─ SizedBox(width: 6)
         └─ Text('₩{입력값}', fontSize 14, w700, AppColors.primary)
```

### ExcludedToggle 위젯 (공통 컴포넌트)

`presentation/brand/customization/widgets/excluded_toggle.dart`

```
Container
  ├─ decoration:
  │    color: AppColors.surfaceElevated
  │    borderRadius: 12
  │    border: AppColors.border 1px
  └─ Padding(16)
       └─ Row
            ├─ Column (flex 1)
            │    ├─ Text '이 매장에서 메뉴 제외', fontSize 14, w600, AppColors.textHeading
            │    └─ Text '활성화하면 이 매장 메뉴에서 해당 메뉴가 표시되지 않아요.',
            │              fontSize 12, AppColors.textMuted, height 1.4
            └─ Switch(
                 value: excluded,
                 activeColor: AppColors.error,
                 activeTrackColor: AppColors.error.withOpacity(0.20),
                 inactiveTrackColor: AppColors.surface,
               )
```

도움말 텍스트 (excluded=true 일 때):
```
SizedBox(height: 8)
Container
  └─ Padding(horizontal 12, vertical 8)
       └─ Row
            ├─ Icon(Icons.info_outline_rounded, 14, AppColors.warning)
            └─ Text ' 제외 처리도 관리자 검토 후 반영됩니다.',
                      fontSize 12, AppColors.warning
  decoration: color AppColors.warning.withOpacity(0.08), radius 8
```

### 폼 레이아웃 순서

```
ListView (padding: EdgeInsets.fromLTRB(20, 16, 20, 120))
  ├─ 마스터 메뉴 정보 카드 (read-only)
  ├─ SizedBox(height: 20)
  ├─ PriceOverrideInput
  ├─ SizedBox(height: 20)
  ├─ ExcludedToggle
  └─ SizedBox(height: 16)
```

### _SubmitBar

```
ElevatedButton
  ├─ 활성: AppColors.primary 배경, AppColors.onPrimary, w700, 16
  ├─ disabled: AppColors.surface, AppColors.textMuted
  ├─ label: '검토 요청 보내기'
  └─ radius: 14
```

저장 성공: SnackBar `'검토 요청을 보냈어요'` + Navigator.pop

---

## 9. BrandStoreOnlyMenuListPage (탭 B 내부 콘텐츠)

- 파일: `presentation/brand/customization/store_only_menu/brand_store_only_menu_list_page.dart`
- 역할: 점포 한정 추가 메뉴 리스트. sub-phase 1 `MasterMenuListPage` 패턴과 유사.
- 최상위: `Widget` (IndexedStack 자식 — Scaffold 없음)

### 레이아웃

```
Column
  ├─ Expanded
  │    └─ ListView.builder (padding: horizontal 16, vertical 12)
  │         └─ _StoreOnlyMenuCard (각 점포 한정 메뉴)
  └─ (FAB 역할) — 탭 B 진입 시 BrandStoreCustomizationPage 에서 FAB 표시
```

> **FAB 배치 방식**: `BrandStoreCustomizationPage` 가 `floatingActionButton` 을 IndexedStack 현재 인덱스에 따라 교체. index=1 일 때 FAB 표시.

```
// BrandStoreCustomizationPage 의 Scaffold.floatingActionButton
_currentIndex == 1
  ? FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      icon: Icon(Icons.add_rounded, 20),
      label: Text('메뉴 추가', fontSize 14, w600),
      onPressed: → BrandStoreOnlyMenuFormPage(mode: create)
    )
  : null
```

### _StoreOnlyMenuCard

```
Card
  ├─ color: AppColors.surfaceElevated
  ├─ borderRadius: 14
  ├─ border: AppColors.border 1px
  ├─ elevation: 0
  └─ Padding(horizontal 16, vertical 14)
       └─ Row
            ├─ (imageUrl 있으면) ClipRRect(radius 8, 52×52, Image.network) /
            │   (없으면) Container(52×52, radius 8, AppColors.surface,
            │              Icon(Icons.fastfood_outlined, 24, AppColors.textMuted))
            ├─ SizedBox(width: 12)
            ├─ Expanded
            │    └─ Column (crossAxisAlignment: start)
            │         ├─ Row
            │         │    ├─ Expanded — Text(메뉴이름, 15, w600, AppColors.textHeading)
            │         │    └─ ApprovalStatusBadge(status, isRevision: approvedAt != null)
            │         ├─ SizedBox(height: 4)
            │         └─ Text('₩{basePrice}', 13, AppColors.textBody, w500)
            └─ PopupMenuButton (Icons.more_vert_rounded, AppColors.textMuted)
                 └─ items:
                      ├─ '편집' → BrandStoreOnlyMenuFormPage(mode: edit, menu: item)
                      ├─ '복제' → BrandStoreOnlyMenuFormPage(mode: duplicate, menu: item)
                      └─ '삭제' → _DeleteConfirmDialog
```

### 빈 상태

```
Center
  └─ Column
       ├─ Icon(Icons.restaurant_menu_outlined, 56, AppColors.textMuted)
       ├─ SizedBox(height: 20)
       ├─ Text '점포 한정 메뉴가 없어요', 16, w600, AppColors.textHeading
       ├─ SizedBox(height: 8)
       └─ Text '이 매장에서만 판매할 특별 메뉴를 추가해보세요.',
                13, AppColors.textMuted, 중앙 정렬
```

### 로딩 / 에러

| 상태 | UI |
|---|---|
| 로딩 | `Center → CircularProgressIndicator(color: AppColors.primary)` |
| 에러 | 공통 에러 패턴, 제목 `'메뉴를 불러오지 못했어요'` |

---

## 10. BrandStoreOnlyMenuFormPage

- 파일: `presentation/brand/customization/store_only_menu/brand_store_only_menu_form_page.dart`
- 역할: 점포 한정 메뉴 등록 / 수정 / 복제. sub-phase 1 `BrandMasterMenuFormPage` 패턴 거의 동일.
- mode: `create` / `edit` / `duplicate`

### AppBar

```
AppBar
  ├─ backgroundColor: AppColors.background
  ├─ elevation: 0
  ├─ leading: IconButton(Icons.close_rounded, AppColors.textHeading)
  └─ title: Text(
       create: '점포 한정 메뉴 등록',
       edit: '메뉴 수정',
       duplicate: '메뉴 복제',
       fontSize 17, w700, AppColors.textHeading)
```

### 섹션 A — 핵심 필드

안내 배너: sub-phase 1 `BrandMasterMenuFormPage` 의 검수 안내 배너 동일.

필드:
1. **대표 이미지** (`ImageUploadField`)
2. **메뉴명** (`_FormField`, 필수, maxLength 40)
3. **가격** (`_FormField`, 필수, keyboardType: number, prefix `'₩'`)
4. **카테고리** (`_CategoryMultiSelect`)
5. **옵션 그룹** (`OptionGroupRefPicker` — sub-phase 1 재사용)
6. **설명** (`_FormField`, 선택, maxLines 4, maxLength 200)

### 섹션 B — 운영 필드

즉시 반영 배너: sub-phase 1 패턴 동일.

필드:
1. **태그** (Wrap of FilterChip, 선택)
2. **노출 여부** (`_VisibleToggle` Switch, 기본 true)
3. **표시 순서** (`_FormField`, keyboardType: number, 선택)

### 주의 (spec U3 + 결정 J)

- `scope='store'`, `brandId`, `storeId` 는 UI 에 노출하지 않는다. 자동 박힘.
- 핵심 필드 변경 → status=pending 회귀
- 운영 필드 변경 → 즉시 반영 (status 보존)
- 두 섹션 변경이 혼합된 경우 → `UpdateStoreOnlyMenuCoreUseCase` 호출 (status=pending 회귀)

### _SubmitBar

```
ElevatedButton
  ├─ create: label '등록하기'
  ├─ edit: label '수정 요청'
  ├─ duplicate: label '복제 등록'
  └─ 스타일: AppColors.primary / AppColors.onPrimary / radius 14
```

저장 성공: SnackBar `'검토 요청을 보냈어요'` + Navigator.pop

운영 필드만 변경 후 저장: SnackBar `'즉시 반영되었습니다'` + Navigator.pop

---

## 11. BrandApprovalTrackingPage

- 파일: `presentation/brand/approval_tracking/brand_approval_tracking_page.dart`
- 역할: brand 가 제출한 모든 항목의 status 모니터링 (단일 통합 리스트)

### AppBar

```
AppBar
  ├─ backgroundColor: AppColors.background
  ├─ elevation: 0
  └─ title: Text('제출 내역', fontSize 17, w700, AppColors.textHeading)
```

> **진입 경로 확정**: `BrandMorePage` 안의 메뉴 항목 `'검토 현황'` 으로 진입. `Navigator.push` 패턴. BrandScaffold 5탭화 미채택 (탭은 4개 유지 — 검토 현황은 자주 보지 않는 페이지).
>
> `BrandMorePage` 메뉴 항목 추가:
> - `_Tile(icon: Icons.fact_check_rounded, title: '검토 현황', subtitle: '제출한 매장·메뉴·오버라이드 진행 상태', onTap: → BrandApprovalTrackingPage push)`
> - 위치: 더보기 페이지 상단 (앱 정보 / 로그아웃 위에 배치)
> - 톤: sub-phase 1 의 `BrandMorePage._Tile` 패턴 그대로 (`AppColors.surfaceElevated` 배경, radius 12)

### 안내 배너 (상단)

```
Container
  ├─ decoration:
  │    color: AppColors.info.withOpacity(0.08)
  │    borderRadius: 12
  │    border: AppColors.info.withOpacity(0.3) 1px
  └─ Padding(horizontal 14, vertical 10)
       └─ Row
            ├─ Icon(Icons.track_changes_rounded, 16, AppColors.info)
            ├─ SizedBox(width: 8)
            └─ Expanded
                 └─ Text('관리자 검토 중인 항목과 최근 처리 결과를 확인할 수 있어요.',
                          fontSize 12, AppColors.info, height 1.4)
```

### _TrackingItemCard (통합 리스트 카드)

타입 구분 뱃지 (카드 상단 Row 좌측):

| 타입 | 라벨 | 아이콘 | 색상 |
|---|---|---|---|
| 매장 | `'매장'` | `Icons.storefront_outlined` | `AppColors.info` |
| 가격 오버라이드 | `'가격 오버라이드'` | `Icons.price_change_outlined` | `AppColors.accent` |
| 점포 한정 메뉴 | `'점포 한정 메뉴'` | `Icons.restaurant_menu_outlined` | `AppColors.primaryBright` |

카드 구조:
```
Card
  ├─ color: AppColors.surfaceElevated
  ├─ borderRadius: 14
  ├─ border: AppColors.border 1px
  ├─ elevation: 0
  └─ Padding(horizontal 16, vertical 14)
       └─ Column (crossAxisAlignment: start)
            ├─ Row
            │    ├─ _TypeBadge(type)       ← 위 표의 타입 뱃지
            │    ├─ Spacer
            │    └─ ApprovalStatusBadge(status, isRevision: approvedAt != null)
            ├─ SizedBox(height: 8)
            ├─ Text(항목 이름, fontSize 14, w600, AppColors.textHeading)
            ├─ SizedBox(height: 4)
            ├─ Text('제출: {submittedAt yyyy.MM.dd HH:mm}', 12, AppColors.textMuted)
            └─ (status == rejected) SizedBox(height: 8)
                                    + _RejectedReasonInline(rejectedReason)
```

`_RejectedReasonInline` (rejected 카드 하단 인라인):
```
Container
  ├─ decoration: AppColors.error.withOpacity(0.06), radius 8, border AppColors.error.withOpacity(0.3) 1px
  └─ Padding(horizontal 12, vertical 8)
       └─ Row (crossAxisAlignment: start)
            ├─ Icon(Icons.info_outline_rounded, 14, AppColors.error)
            ├─ SizedBox(width: 6)
            └─ Expanded
                 └─ Text(rejectedReason ?? '사유가 기록되지 않았어요',
                          fontSize 12, AppColors.error, height 1.4)
```

### 빈 상태

```
Center
  └─ Column
       ├─ Icon(Icons.track_changes_rounded, 56, AppColors.textMuted)
       ├─ SizedBox(height: 20)
       ├─ Text '제출한 내역이 없어요', 16, w600, AppColors.textHeading
       ├─ SizedBox(height: 8)
       └─ Text '매장 등록이나 메뉴 수정을 하면 여기에 표시돼요.',
                13, AppColors.textMuted, 중앙 정렬
```

### 로딩 / 에러

| 상태 | UI |
|---|---|
| 로딩 | `Center → CircularProgressIndicator(color: AppColors.primary)` |
| 에러 | 공통 에러 패턴, 제목 `'내역을 불러오지 못했어요'` |

---

## 12. OwnerMyStorePage — brandId 분기 (U9)

- 파일: `presentation/owner/my_store/my_store_page.dart` (수정)
- 변경 내용: `store.brandId != null` 분기 추가

### brandId == null (개인 매장 — 기존 그대로)

sub-phase 2 의 `OwnerMyStorePage` 그대로. 변경 없음.

### brandId != null (브랜드 매장 — 신규 분기)

`_StoreHeaderCard` 변경:
```
// 기존 하단 overlay Row 에 StoreScopeBadge.brand 추가
Row
  ├─ StoreScopeBadge.brand(brandName)   ← 신규 (primary 톤)
  ├─ SizedBox(width: 6)
  ├─ categories ...
  ├─ Spacer
  ├─ ApprovalStatusBadge(store.status, ...)
  └─ SizedBox(width: 6)
  └─ GradeBadge(...)
```

`_BrandStoreInfoBanner` (신규 — brand 매장 전용 안내):
```
// _StoreHeaderCard 하단, _StoreStatusSection 상단 삽입
Container
  ├─ decoration:
  │    color: AppColors.primary.withOpacity(0.06)
  │    borderRadius: 12
  │    border: AppColors.primary.withOpacity(0.3) 1px
  └─ Padding(horizontal 14, vertical 10)
       └─ Row
            ├─ Icon(Icons.business_rounded, 16, AppColors.primary)
            ├─ SizedBox(width: 8)
            └─ Expanded
                 └─ Text('매장 핵심 정보는 브랜드 본사가 관리해요.',
                          fontSize 12, AppColors.primary, height 1.4)
```

`_StoreActionButtons` 분기:
```
// brandId != null 일 때
// "매장 정보 수정" 버튼 완전 비노출

// "운영 정보 수정" 버튼만 전체 너비로 표시
SizedBox(width: double.infinity, height: 48)
  └─ OutlinedButton.icon
       ├─ border: AppColors.primary.withOpacity(0.4) 1px
       ├─ 텍스트: AppColors.primary, fontSize 14, w600
       ├─ icon: Icons.tune_rounded, AppColors.primary
       ├─ radius: 12
       └─ onPressed: → StoreOperationFormPage(existing: store)
       label: '운영 정보 수정'
```

rejected 상태 (`RejectedBanner`):
- brand 매장은 점주 재제출 불가 → `RejectedBanner` 는 사유 노출만, "재제출하기" CTA 미표시
- `RejectedBanner` 를 `props: showResubmit: false` 형태로 호출하거나 brand 매장 전용 read-only 배너 사용

```
// brand 매장 rejected 전용 배너
Container
  ├─ decoration:
  │    color: AppColors.error.withOpacity(0.06)
  │    borderRadius: 14
  │    border: AppColors.error.withOpacity(0.3) 1px
  └─ Padding(horizontal 16, vertical 14)
       └─ Column (crossAxisAlignment: start)
            ├─ Row
            │    ├─ Icon(Icons.cancel_outlined, 18, AppColors.error)
            │    ├─ SizedBox(width: 8)
            │    └─ Text '검토가 반려되었어요', 14, w700, AppColors.error
            ├─ SizedBox(height: 8)
            ├─ Text(rejectedReason ?? '사유가 기록되지 않았어요',
            │         13, AppColors.textBody, height 1.5)
            ├─ SizedBox(height: 10)
            └─ Text '재제출은 브랜드 본사에서 진행됩니다.',
                      12, AppColors.textMuted, italic
```

### brandName 데이터 조회

- `BrandRepository.watchById(store.brandId)` stream → brandName 추출
- `StoreScopeBadge.brand(brandName)` 에 전달
- 로딩 중 (brandEntity 미도착): `StoreScopeBadge.brand('브랜드 매장')` placeholder

---

## 인터랙션 정리 (Brand 모듈)

| 동작 | 반응 |
|---|---|
| `BrandStoresPage` FAB / 빈 상태 CTA | `BrandStoreFormPage(mode: create)` Navigator.push |
| `BrandStoreCard` 탭 | `BrandStoreCustomizationPage(store: store)` Navigator.push |
| `BrandStoreFormPage` 저장 | `SubmitStoreByBrandUseCase` → SnackBar + pop |
| `BrandStoreCustomizationPage` 탭 전환 | IndexedStack index 변경 |
| `MasterMenuOverrideCard` 탭 | `BrandPriceOverrideFormPage(masterMenu, override?)` push |
| `BrandPriceOverrideFormPage` 저장 | `UpsertMenuOverrideCoreUseCase` → SnackBar + pop |
| `_StoreOnlyMenuCard` PopupMenu '편집' | `BrandStoreOnlyMenuFormPage(mode: edit, menu)` push |
| `_StoreOnlyMenuCard` PopupMenu '복제' | `BrandStoreOnlyMenuFormPage(mode: duplicate, menu)` push |
| `_StoreOnlyMenuCard` PopupMenu '삭제' | `_DeleteConfirmDialog` → `DeleteStoreOnlyMenuUseCase` → pop |
| `BrandStoreOnlyMenuFormPage` 저장 (핵심 필드) | `CreateStoreOnlyMenuUseCase` 또는 `UpdateStoreOnlyMenuCoreUseCase` → SnackBar '검토 요청을 보냈어요' + pop |
| `BrandStoreOnlyMenuFormPage` 저장 (운영 필드만) | `UpdateStoreOnlyMenuOperationUseCase` → SnackBar '즉시 반영되었습니다' + pop |
| `OwnerMyStorePage (brand 매장)` "운영 정보 수정" 탭 | `StoreOperationFormPage(existing: store)` push (sub-phase 2 동일) |

---

## 개발자 전달 특이사항 (Brand 모듈)

1. **`BrandStoreFormPage` 의 마스터 메뉴 multi-select**: `WatchMasterMenusByBrandUseCase` 의 stream 결과를 `FilterChip` Wrap 으로 렌더링. 전체 선택 / 해제 버튼은 상태 변수 `Set<String> enabledIds` 로 관리.
2. **미선택 마스터 메뉴 excluded batch seed**: form 저장 시 `SubmitStoreByBrandUseCase` 에 `enabledMasterMenuItemIds` 를 전달. UseCase 내부에서 `MenuOverrideRepository.seedExclusionsForStore` 호출 (U2).
3. **`BrandStoreCustomizationPage` FAB 교체**: Scaffold.floatingActionButton 을 `ValueNotifier<int>` 또는 `currentIndex` state 로 교체. index=0 → null, index=1 → 점포 한정 메뉴 FAB.
4. **`BrandApprovalTrackingPage` 데이터 소스**: 매장 / 가격 오버라이드 / 점포 한정 메뉴 세 stream 을 각각 구독 후 provider 단에서 합산 정렬 (`submittedAt` 내림차순).
5. **`OwnerMyStorePage` brandName 조회**: `store.brandId != null` 분기에서 `ref.watch(brandByIdProvider(store.brandId!))` 를 추가 구독. 로딩 중은 placeholder 라벨 표시.
6. **`_DeleteConfirmDialog`**: `RejectReasonDialog` 패턴과 유사하지만 사유 입력 없이 확인 / 취소 두 버튼만. 배경 `AppColors.surfaceElevated`, radius 16, 확인 버튼 `AppColors.error`.
