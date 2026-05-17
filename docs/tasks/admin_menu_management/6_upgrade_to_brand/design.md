# sub-phase 6 — upgrade_to_brand 디자인 명세

> **상태**: 작성 완료
>
> **참조 sub-phase**: sub-phase 1 (brand_master) / sub-phase 2 (store_registration_approval) / sub-phase 3 (brand_store_customization)
>
> **디자인 시스템 단일 진실원**: [docs/agents/designer_guide.md](../../../agents/designer_guide.md)

---

## 참조한 디자인

- Figma: 없음 (Qradar 디자인 시스템 + 기존 화면 톤 기반)
- 기존 화면 패턴:
  - `lib/presentation/customer/more/widgets/upgrade_to_owner_section.dart` — CTA 섹션 패턴
  - `lib/presentation/customer/more/widgets/upgrade_to_owner_dialog.dart` — 전환 확인 다이얼로그 패턴
  - sub-phase 1 `BrandInfoPage` — 브랜드 카드 + 섹션 구조
  - sub-phase 2 `StoreCoreFormPage` — 폼 필드 패턴
  - sub-phase 3 `BrandStoresPage` — 가맹점 리스트 카드 패턴
- 색상 토큰: `lib/core/theme/app_colors.dart`

---

## 핵심 디자인 결정사항

### 1. UpgradeToBrandSection 톤 차별 — `AppColors.primary` 채택

점주 섹션(`UpgradeToOwnerSection`)은 `AppColors.accent` 톤을 사용한다. 브랜드 섹션은 `AppColors.primary` 톤으로 차별한다.

이유: brand = 프랜차이즈 본사를 운영하는 최상위 사업자 역할. 앱의 메인 포인트(`AppColors.primary`) 를 부여하여 "더 강한 사업자 역할"이라는 시각적 위계를 명확히 한다. `AppColors.accent` (Qoin, 별점, 프리미엄) 와의 혼용 방지.

### 2. 브랜드 섹션 아이콘 — `Icons.domain_rounded` 채택

`Icons.business_rounded` (sub-phase 3 의 `StoreScopeBadge.brand` 에서 사용) 와 구분하기 위해 `Icons.domain_rounded` 을 채택한다. 다중 건물/본사 이미지가 "프랜차이즈 본사" 개념에 부합한다.

### 3. StoreCoreFormPage brandKey 토글 — Switch 채택

spec V3 의 토글 후보 중 `SwitchListTile` 방식을 채택한다 (spec V3 의 기본안 (a)). 이유: 기본값이 OFF (개인 매장) 임이 직관적으로 전달된다. SegmentedControl은 "개인 매장"이 default라는 개념을 약화시킨다. 모바일 단일 폼 안에서 두 옵션을 병렬로 나열하면 입력 흐름이 끊긴다.

### 4. brandKey 표시 형식 — 모노스페이스 + 복사 버튼 채택

`FontFamily: monospace` (`TextStyle(fontFamily: 'monospace')`) 로 가독성 확보. 복사 버튼 (`Icons.copy_rounded`) 을 brandKey 텍스트 우측에 배치한다 (spec V9 의 "선택" 항목을 채택).

### 5. BrandStoresPage 빈 상태 — 안내 2줄 채택

빈 상태에서 "아직 등록된 가맹점이 없어요" + "점주가 브랜드 키를 입력해 매장을 등록하면 여기에 표시됩니다" 2줄 안내를 제공한다. brand 가 FAB 으로 직접 등록하는 것이 불가능함을 명시적으로 알려야 한다.

---

## 화면 1 — `UpgradeToBrandSection` (신규)

- 파일: `lib/presentation/customer/more/widgets/upgrade_to_brand_section.dart`
- 노출 조건: `role == 'customer'` 일 때만. `UpgradeToOwnerSection` 아래 위치.
- 역할: 더보기 페이지에서 브랜드 전환 CTA 진입점 제공.

### 레이아웃

```
Container (margin: LTRB(20, 0, 20, 24))
  ├─ decoration:
  │    gradient: LinearGradient(
  │      begin: topLeft, end: bottomRight,
  │      colors: [AppColors.surfaceElevated, AppColors.surface]
  │    )
  │    borderRadius: 16
  │    border: AppColors.primary.withValues(alpha: 0.3) 1px
  └─ Material (color: transparent, borderRadius: 16)
       └─ InkWell (borderRadius: 16, onTap: _onTap)
            └─ Padding(16)
                 └─ Row
                      ├─ [아이콘 컨테이너] 40×40 원형
                      ├─ SizedBox(width: 12)
                      ├─ Expanded → Column (텍스트)
                      └─ Icon(chevron_right, 20, AppColors.textMuted)
```

### 아이콘 컨테이너

```
Container
  ├─ size: 40×40
  ├─ decoration: BoxShape.circle
  │    color: AppColors.primary.withValues(alpha: 0.12)
  └─ Icon(Icons.domain_rounded, size: 20, color: AppColors.primary)
```

### 텍스트

- 제목: `'브랜드 운영자이신가요?'`
  - fontSize: 15, fontWeight: w700, color: `AppColors.textHeading`
- 부제: `'마스터 메뉴를 관리하고 가맹점을 통합 운영하세요'`
  - fontSize: 12, color: `AppColors.textMuted`
  - SizedBox(height: 2) 제목과 부제 사이

### 점주 섹션과의 차이

| 항목 | 점주 섹션 | 브랜드 섹션 |
|---|---|---|
| 보더 색 | `AppColors.accent` alpha 0.3 | `AppColors.primary` alpha 0.3 |
| 아이콘 배경 | `AppColors.accent` alpha 0.15 | `AppColors.primary` alpha 0.12 |
| 아이콘 색 | `AppColors.accent` | `AppColors.primary` |
| 아이콘 | `Icons.storefront_rounded` | `Icons.domain_rounded` |
| 제목 | `'점주이신가요?'` | `'브랜드 운영자이신가요?'` |
| 부제 | `'매장을 등록하고 Qrator를 만나보세요'` | `'마스터 메뉴를 관리하고 가맹점을 통합 운영하세요'` |
| margin top | `16` | `0` (점주 섹션 직하단에 붙음) |

### 상태

- default: 위 스펙 그대로
- onTap ripple: `InkWell` 기본 ripple (borderRadius: 16)
- 로딩/에러 없음 (탭 → 다이얼로그 → UseCase 호출. 섹션 자체에는 로딩 상태 없음)

---

## 화면 2 — `UpgradeToBrandDialog` (신규)

- 파일: `lib/presentation/customer/more/widgets/upgrade_to_brand_dialog.dart`
- 노출: `UpgradeToBrandSection` 탭 → `showUpgradeToBrandDialog(context)` 호출
- 패턴: `UpgradeToOwnerDialog` 와 동일 구조. 아이콘 / 색 / 텍스트만 차별.

### 레이아웃

```
Dialog
  ├─ backgroundColor: AppColors.surfaceElevated
  ├─ shape: RoundedRectangleBorder(borderRadius: 20)
  ├─ insetPadding: horizontal 32
  └─ Padding(LTRB 24, 28, 24, 20)
       └─ Column(mainAxisSize: min)
            ├─ [아이콘 원형] 56×56
            ├─ SizedBox(height: 20)
            ├─ [제목 텍스트]
            ├─ SizedBox(height: 12)
            ├─ [본문 텍스트]
            ├─ SizedBox(height: 24)
            └─ Row [취소 / 전환하기 버튼]
```

### 아이콘 원형

```
Container
  ├─ size: 56×56
  ├─ decoration: BoxShape.circle
  │    gradient: LinearGradient(
  │      begin: topLeft, end: bottomRight,
  │      colors: [AppColors.primary, AppColors.primaryLight]
  │    )
  └─ Icon(Icons.domain_rounded, color: AppColors.onPrimary, size: 28)
```

### 텍스트

- 제목: `'브랜드로 전환하시겠어요?'`
  - fontSize: 18, fontWeight: w700, color: `AppColors.textHeading`
  - textAlign: center
- 본문: `'브랜드 정보 등록 후 관리자 승인을 거쳐 마스터 메뉴를 등록할 수 있어요.\n점주는 가맹점에서 브랜드 키를 입력해 본인 매장을 등록할 수 있어요.'`
  - fontSize: 13, height: 1.5, color: `AppColors.textBody`
  - textAlign: center

### 버튼 Row

```
Row
  ├─ Expanded
  │    └─ TextButton '취소'
  │         - padding: vertical 14
  │         - borderRadius: 12
  │         - 텍스트: fontSize 15, w600, AppColors.textMuted
  │         - onPressed: Navigator.pop(false)
  ├─ SizedBox(width: 8)
  └─ Expanded
       └─ FilledButton '전환하기'
            - backgroundColor: AppColors.primary
            - foregroundColor: AppColors.onPrimary
            - padding: vertical 14
            - borderRadius: 12
            - 텍스트: fontSize 15, w700
            - onPressed: Navigator.pop(true)
```

### 점주 다이얼로그와의 차이

| 항목 | 점주 다이얼로그 | 브랜드 다이얼로그 |
|---|---|---|
| 아이콘 배경 | `AppColors.accent` gradient | `AppColors.primary → AppColors.primaryLight` gradient |
| 아이콘 색 | `Colors.white` (onPrimary 동일) | `AppColors.onPrimary` |
| 아이콘 | `Icons.storefront_rounded` | `Icons.domain_rounded` |
| 제목 | `'점주로 전환하시겠어요?'` | `'브랜드로 전환하시겠어요?'` |
| 본문 | 점주 전환 안내 | 브랜드 전환 + 가맹점 등록 안내 |
| 확인 버튼 배경 | `AppColors.accent` | `AppColors.primary` |
| 확인 버튼 텍스트 색 | `AppColors.textDark` | `AppColors.onPrimary` |
| 확인 버튼 라벨 | `'점주로 전환'` | `'전환하기'` |

---

## 화면 3 — `BrandInfoPage` 갱신 (brandKey 노출)

- 파일: `lib/presentation/brand/brand_info/brand_info_page.dart`
- 변경: 기존 브랜드 카드 하단에 brandKey 영역 추가. sub-phase 1 의 섹션 구조 유지.

### brandKey 섹션 위치

브랜드 카드 (`_BrandCard`) 내부. 설명 텍스트 아래에 `Divider` + brandKey Row 추가.

```
Card (AppColors.surfaceElevated, radius 16, border AppColors.border 1px)
  └─ Padding(16)
       └─ Column
            ├─ [로고 + 이름 + ApprovalStatusBadge] (기존 그대로)
            ├─ SizedBox(height: 16)
            ├─ Divider(color: AppColors.border, height: 1)
            ├─ SizedBox(height: 16)
            ├─ Text(설명, 기존 그대로)
            ├─ SizedBox(height: 16)
            ├─ Divider(color: AppColors.border, height: 1)
            └─ SizedBox(height: 16)
                 └─ _BrandKeyRow  ← 신규
```

### `_BrandKeyRow` 상세

**status == approved + brandKey 비어 있지 않을 때:**

```
Row(crossAxisAlignment: center)
  ├─ Column(crossAxisAlignment: start)
  │    ├─ Text('브랜드 키',
  │    │        fontSize: 12, color: AppColors.textMuted)
  │    ├─ SizedBox(height: 4)
  │    └─ Text(brandKey,   // 예: 'BR-A2B3C4D5'
  │             fontSize: 15, fontWeight: w600,
  │             color: AppColors.textHeading,
  │             fontFamily: 'monospace')
  ├─ Spacer
  └─ IconButton
       ├─ icon: Icon(Icons.copy_rounded, size: 18, color: AppColors.primary)
       ├─ tooltip: '복사'
       └─ onPressed: [클립보드 복사 + SnackBar '복사됐어요']
```

**안내 문구 (brandKey 아래):**

```
Padding(top: 8)
  └─ Text('이 키를 점주에게 공유하면 가맹점 등록 시 사용할 수 있어요',
           fontSize: 11, color: AppColors.textMuted, height: 1.4)
```

**status == pending 또는 brandKey 비어 있을 때:**

```
Row(crossAxisAlignment: center)
  ├─ Icon(Icons.lock_clock_rounded, size: 16, color: AppColors.textMuted)
  ├─ SizedBox(width: 8)
  └─ Text('관리자 승인 후 브랜드 키가 발급됩니다',
           fontSize: 13, color: AppColors.textMuted)
```

**status == rejected 일 때:**

- `_BrandKeyRow` 미노출. 반려 사유 섹션만 표시 (기존 sub-phase 1 패턴 그대로).

### SnackBar 피드백

- `'복사됐어요'`
- backgroundColor: `AppColors.primary`
- 텍스트 색: `AppColors.onPrimary`
- duration: 2초

---

## 화면 4 — `StoreCoreFormPage` 갱신 (brandKey 토글 + 필드)

- 파일: `lib/presentation/owner/my_store/store_core_form_page.dart`
- 변경: 폼 필드 최하단 (사업자번호 아래) 에 "브랜드 가맹점" 토글 + 조건부 brandKey 입력 필드 추가.

### 위치

폼 필드 순서:
1. 매장 이름
2. 주소
3. 카테고리
4. 사업자번호
5. **(신규)** 브랜드 가맹점 섹션 ← 여기에 삽입
6. 저장 버튼

이유: 브랜드 가맹점 여부는 다른 필드 입력을 방해하지 않는다. 기존 필드를 모두 입력한 후 마지막에 브랜드 여부를 확인하는 흐름이 자연스럽다.

### 브랜드 가맹점 섹션 레이아웃

```
Column
  ├─ SizedBox(height: 24)
  ├─ Divider(color: AppColors.border, height: 1)
  ├─ SwitchListTile
  │    ├─ title: Text('브랜드 가맹점',
  │    │               fontSize: 15, w600, AppColors.textHeading)
  │    ├─ subtitle: Text('브랜드 키를 입력하면 가맹점으로 등록됩니다',
  │    │                  fontSize: 12, AppColors.textMuted)
  │    ├─ value: _isBrandFranchise
  │    ├─ onChanged: (val) => setState(...)
  │    ├─ activeColor: AppColors.primary
  │    └─ contentPadding: horizontal 0
  └─ (AnimatedSwitcher 또는 if 분기) _BrandKeyField (토글 ON 시만 노출)
```

### `_BrandKeyField`

```
Column(crossAxisAlignment: start)
  ├─ SizedBox(height: 12)
  └─ TextFormField
       ├─ controller: _brandKeyCtrl
       ├─ decoration:
       │    labelText: '브랜드 키'
       │    hintText: 'BR-A1B2C3D4'
       │    prefixIcon: Icon(Icons.vpn_key_rounded, AppColors.textMuted, size: 20)
       │    filled: true
       │    fillColor: AppColors.surfaceElevated
       │    border: OutlineInputBorder(radius: 12, borderSide: AppColors.border 1px)
       │    focusedBorder: OutlineInputBorder(radius: 12, borderSide: AppColors.primary 1.5px)
       │    errorBorder: OutlineInputBorder(radius: 12, borderSide: AppColors.error 1px)
       │    labelStyle: AppColors.textMuted
       ├─ textCapitalization: TextCapitalization.characters  ← 자동 대문자
       ├─ keyboardType: TextInputType.text
       └─ style: fontSize: 15, fontFamily: 'monospace', color: AppColors.textHeading
```

### 인라인 에러 라벨 (제출 시점)

- `_brandKeyCtrl.text.isEmpty` 일 때: `errorText: '브랜드 키를 입력해주세요'`
- `BR-XXXXXXXX` 형식 불일치 (정규식: `^BR-[A-Z2-9]{8}$`) 일 때: `errorText: '올바른 브랜드 키 형식이 아닙니다'`
- 에러 텍스트 색: `AppColors.error`, fontSize: 12

### SnackBar (제출 시 brandKey 미스매치)

- `'정상 브랜드 키가 아닙니다'`
- backgroundColor: `AppColors.error`
- 텍스트 색: `AppColors.onPrimary` (`Colors.white` 대체)
- duration: 3초

---

## 화면 5 — `BrandStoresPage` 갱신

- 파일: `lib/presentation/brand/stores/brand_stores_page.dart`
- 변경: FAB 제거. AppBar 타이틀 `'가맹점'` 으로 변경. 카드 read-only 유지.

### AppBar

```
SliverAppBar (기존 패턴 그대로)
  ├─ title: '가맹점'  ← '매장' → '가맹점' 변경
  ├─ pinned: false, floating: true
  ├─ backgroundColor: AppColors.background
  └─ actions: 없음 (FAB 및 "+" 버튼 제거)
```

### FAB 제거

- 기존 `FloatingActionButton` 위젯 완전 제거.
- `Scaffold.floatingActionButton: null`.

### 카드 구조 (read-only, 기존 sub-phase 3 패턴 유지)

```
Card (AppColors.surfaceElevated, radius 16, border AppColors.border 1px)
  └─ ListTile (contentPadding: horizontal 16, vertical 8)
       ├─ leading: ClipRRect(radius: 8)
       │             Image.network 또는 Placeholder
       │             size: 48×48
       ├─ title: Text(매장명, fontSize: 15, w600, AppColors.textHeading)
       ├─ subtitle: Column
       │              ├─ Text(주소, fontSize: 12, AppColors.textMuted)
       │              └─ SizedBox(height: 4)
       │                   Row
       │                     ├─ ApprovalStatusBadge(status)
       │                     ├─ SizedBox(width: 6)
       │                     └─ StoreScopeBadge.brand(brandName)
       └─ trailing: Icon(Icons.chevron_right_rounded, AppColors.textMuted, size: 18)
```

- `onTap`: `BrandStoreCustomizationPage` 진입 (sub-phase 3 그대로)

### 빈 상태

```
Center
  └─ Column(mainAxisSize: min)
       ├─ Icon(Icons.storefront_outlined, size: 56, color: AppColors.textMuted)
       ├─ SizedBox(height: 16)
       ├─ Text('아직 등록된 가맹점이 없어요',
       │        fontSize: 16, w600, AppColors.textHeading,
       │        textAlign: center)
       ├─ SizedBox(height: 8)
       └─ Text('점주가 브랜드 키를 입력해 매장을 등록하면\n여기에 표시됩니다',
                fontSize: 13, AppColors.textMuted, height: 1.5,
                textAlign: center)
```

### 로딩 상태

shimmer skeleton — 카드 3장. base: `AppColors.surface`, highlight: `AppColors.surfaceElevated`

### 에러 상태

공통 에러 패턴 (sub-phase 1 `common_components.md`):
- 에러 아이콘: `AppColors.error`
- 재시도 버튼: `AppColors.primary` / `AppColors.onPrimary`

---

## 화면 6 — `AdminBrandApprovalDetailPage` 갱신 (SnackBar 카피만)

- 파일: `lib/presentation/admin/approval/admin_brand_approval_detail_page.dart`
- 변경: 승인 성공 SnackBar 메시지 보강 + `BrandKeyCollisionException` 에러 처리 추가.
- UI 구조 변경 없음.

### 승인 성공 SnackBar

```
SnackBar
  ├─ content: Text('브랜드를 승인했어요. 브랜드 키가 발급되었습니다')
  ├─ backgroundColor: AppColors.success
  └─ duration: 3초
```

### brandKey 발급 실패 SnackBar (`BrandKeyCollisionException`)

```
SnackBar
  ├─ content: Text('브랜드 키 발급에 실패했어요. 다시 시도해주세요')
  ├─ backgroundColor: AppColors.error
  └─ duration: 4초
```

---

## 상태별 UI 요약

### UpgradeToBrandSection

| 상태 | 처리 |
|---|---|
| default | 위 스펙 그대로 노출 |
| onTap | InkWell ripple → 다이얼로그 표시 |
| 전환 실패 | SnackBar `'브랜드 전환에 실패했어요: {error}'`, backgroundColor: `AppColors.error` |

### BrandInfoPage — brandKey 영역

| 상태 | 처리 |
|---|---|
| status == approved, brandKey 있음 | brandKey + 복사 버튼 표시 |
| status == pending | 잠금 아이콘 + `'관리자 승인 후 브랜드 키가 발급됩니다'` |
| status == rejected | 미노출 (반려 사유 섹션만) |
| brandKey 복사 성공 | SnackBar `'복사됐어요'` |

### StoreCoreFormPage — 브랜드 가맹점 섹션

| 상태 | 처리 |
|---|---|
| 토글 OFF (default) | brandKey 입력 필드 미노출 |
| 토글 ON | brandKey 입력 필드 AnimatedSize 로 노출 |
| 입력 필드 포커스 | border: `AppColors.primary` 1.5px |
| 빈 입력 후 제출 | 인라인 에러: `'브랜드 키를 입력해주세요'` |
| 형식 불일치 후 제출 | 인라인 에러: `'올바른 브랜드 키 형식이 아닙니다'` |
| brandKey 미스매치 | SnackBar `'정상 브랜드 키가 아닙니다'` (backgroundColor: `AppColors.error`) |
| brandKey 매칭 성공 | 기존 제출 흐름 (SnackBar `'검토 대기 중으로 전환되었습니다'`) |

### BrandStoresPage

| 상태 | 처리 |
|---|---|
| 로딩 중 | shimmer skeleton 3장 |
| 데이터 있음 | 카드 리스트 |
| 빈 상태 | 아이콘 + 안내 2줄 |
| 에러 | 공통 에러 패턴 + 재시도 버튼 |

---

## 인터랙션

| 동작 | 반응 |
|---|---|
| `UpgradeToBrandSection` 탭 | `showUpgradeToBrandDialog(context)` 호출 |
| 다이얼로그 `'취소'` 탭 | `Navigator.pop(false)`, 아무 변화 없음 |
| 다이얼로그 `'전환하기'` 탭 | `Navigator.pop(true)` → `UpgradeToBrandUseCase.call(uid)` → role='brand' → RoleRouter 자동 전환 → BrandScaffold |
| `BrandInfoPage` 복사 버튼 탭 | `Clipboard.setData(ClipboardData(text: brandKey))` + SnackBar `'복사됐어요'` |
| `StoreCoreFormPage` 브랜드 가맹점 Switch ON | `_BrandKeyField` AnimatedSize 로 펼쳐짐 (duration: 200ms, curve: Curves.easeInOut) |
| `StoreCoreFormPage` 브랜드 가맹점 Switch OFF | `_BrandKeyField` AnimatedSize 로 접힘 (동일 curve). `_brandKeyCtrl` 초기화 |
| `BrandStoresPage` 카드 탭 | `BrandStoreCustomizationPage` Navigator.push |

---

## 재사용 컴포넌트

| 컴포넌트 | 파일 | 재사용 위치 |
|---|---|---|
| `ApprovalStatusBadge` | `presentation/common/widgets/approval_status_badge.dart` | BrandStoresPage 카드 |
| `StoreScopeBadge.brand()` | `presentation/admin/widgets/store_scope_badge.dart` | BrandStoresPage 카드 |
| `UpgradeToOwnerSection` 패턴 | 점주 섹션 그대로 차용 | `UpgradeToBrandSection` 위젯 구조 |
| `UpgradeToOwnerDialog` 패턴 | 점주 다이얼로그 그대로 차용 | `UpgradeToBrandDialog` 위젯 구조 |

---

## 개발자 전달 특이사항

### 1. 점주 패턴 차용 — 코드 레벨 지침

`UpgradeToBrandSection` / `UpgradeToBrandDialog` 는 각각 `UpgradeToOwnerSection` / `UpgradeToOwnerDialog` 의 코드를 복사 후 아래만 교체한다:
- 색상 토큰: `AppColors.accent` → `AppColors.primary` / `AppColors.primaryLight`
- 아이콘: `Icons.storefront_rounded` → `Icons.domain_rounded`
- 텍스트 카피: 위 화면별 명세 참조
- UseCase: `upgradeToOwnerUseCaseProvider` → `upgradeToBrandUseCaseProvider`

### 2. brandKey 모노스페이스

`TextStyle(fontFamily: 'monospace')` 를 사용한다. 별도 폰트 패키지 불필요 — Flutter 기본 제공 monospace fallback 사용.

### 3. `_BrandKeyField` AnimatedSize

토글 ON/OFF 시 `AnimatedSize(duration: Duration(milliseconds: 200), curve: Curves.easeInOut)` 로 감싸 입력 필드가 부드럽게 펼쳐지고 접히게 한다.

### 4. brandKey 정규식 검증 (인라인 에러 — 클라이언트 사이드)

```
RegExp(r'^BR-[A-Z2-9]{8}$')
```

대문자 A-Z 와 숫자 2-9 (0, 1 제외) 8자리. 이 형식 검증은 클라이언트 단 빠른 피드백용이고, 실제 존재 여부 검증은 제출 시 `LookupBrandByKeyUseCase` 호출로 서버에서 처리한다.

### 5. 복사 버튼 구현

```dart
await Clipboard.setData(ClipboardData(text: brandKey));
if (context.mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('복사됐어요'),
      backgroundColor: AppColors.primary,
      duration: const Duration(seconds: 2),
    ),
  );
}
```

### 6. `BrandStoresPage` FAB 제거

`Scaffold.floatingActionButton` 파라미터를 완전히 제거한다 (null 할당이 아닌 파라미터 자체 제거). AppBar actions 의 "+" `IconButton` 도 함께 제거.

### 7. MorePage 섹션 배치

`MorePage` 에서 `UpgradeToOwnerSection` 직후에 `UpgradeToBrandSection` 을 배치한다. `role == 'customer'` 조건은 두 섹션 모두 동일하게 적용된다. 두 섹션이 모두 노출될 때 시각적 연속성이 있도록 `UpgradeToBrandSection` 의 `margin top` 을 `0` 으로 설정한다 (점주 섹션 `margin bottom: 24` 가 이미 두 섹션 사이 간격을 담당).

### 8. AppColors 토큰 요약

| 위치 | 토큰 |
|---|---|
| `UpgradeToBrandSection` 보더 | `AppColors.primary.withValues(alpha: 0.3)` |
| `UpgradeToBrandSection` 아이콘 배경 | `AppColors.primary.withValues(alpha: 0.12)` |
| `UpgradeToBrandSection` 아이콘 | `AppColors.primary` |
| `UpgradeToBrandDialog` 아이콘 그라디언트 | `AppColors.primary` → `AppColors.primaryLight` |
| `UpgradeToBrandDialog` 아이콘 | `AppColors.onPrimary` |
| `UpgradeToBrandDialog` 전환 버튼 배경 | `AppColors.primary` |
| `UpgradeToBrandDialog` 전환 버튼 텍스트 | `AppColors.onPrimary` |
| `BrandInfoPage` 복사 버튼 아이콘 | `AppColors.primary` |
| `BrandInfoPage` 복사 SnackBar 배경 | `AppColors.primary` |
| `StoreCoreFormPage` Switch 활성 | `AppColors.primary` |
| `StoreCoreFormPage` 포커스 보더 | `AppColors.primary` |
| `StoreCoreFormPage` 에러 라벨 | `AppColors.error` |
| `StoreCoreFormPage` 미스매치 SnackBar 배경 | `AppColors.error` |
| `AdminBrandApprovalDetailPage` 승인 SnackBar | `AppColors.success` |
| `AdminBrandApprovalDetailPage` 실패 SnackBar | `AppColors.error` |
