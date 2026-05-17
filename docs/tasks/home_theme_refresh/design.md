# 홈 화면 테마 리프레시 디자인 명세

## 참조한 Figma 디자인
- [docs/design/screens/home/home.png](docs/design/screens/home/home.png)
- [docs/design/screens/home/home.md](docs/design/screens/home/home.md) — React/Tailwind 스니펫 (레이아웃 참조)

핵심 아이덴티티: **흰색 캔버스** + **미드나잇 네이비 포인트**. 네이비는 헤더 블록·강조 칩·배지·FAB·활성 네비에만 한정적으로 사용되며 나머지 면은 항상 밝게 유지.

---

## 전역 캔버스

- **Scaffold 배경**: `AppColors.background` (흰색)
- **세이프 에어리어**: 헤더가 상단 safe area까지 채우므로 `SafeArea(top: false)` 또는 헤더 내부에서 처리
- **스크롤 물리**: 기존 `AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())` 유지

---

## 화면 구성

### 1. HomeHeader (미드나잇 블록)

- **위젯**: `Container` → `decoration: BoxDecoration`
- **배경**: `AppColors.primary` 단색 (미드나잇 네이비)
  - _옵션_: 수직 그라디언트 `AppColors.primary → AppColors.primaryDeep`로 깊이감
- **라운드**: `BorderRadius.only(bottomLeft: Radius.circular(28))` — 우측은 직각 (home.png와 일치)
- **패딩**: `EdgeInsets.fromLTRB(20, 16, 20, 24)` + `SafeArea(bottom: false)`
- **내부**:
  - **브랜드 Row**
    - `QLogo(size: 40, color: AppColors.onPrimary)` — 로고 색 흰색으로 변경
    - "uality Grader Radar" 타이포:
      - fontSize: 18, bold, letterSpacing: 0.3
      - color: `AppColors.onPrimary` (흰색, 단색)
      - _기존 ShaderMask 그라디언트 제거_ — 네이비 위에 그라디언트 블루는 대비 낮고 자잘함
  - **환영 메시지**:
    - `RichText`, 본문 fontSize 16, color: `AppColors.onPrimary.withValues(alpha: 0.9)` 또는 `#E5E7EB`급
    - 이름 강조 span: fontSize 18, bold, color: `AppColors.onPrimary` (흰색)
    - 텍스트: `[이름]님 어서오세요.`

### 2. SectionTitle (공통)

- **위젯**: `Padding` + `Text`
- **패딩**: `EdgeInsets.symmetric(horizontal: 20)` + 섹션 상단 16
- **타이포**: fontSize 18, fontWeight.w700, color: `AppColors.textHeading`

### 3. NearbyStoresSection (주변매장 가로 스크롤)

- **레이아웃**: `SectionTitle("주변매장")` → `SizedBox(height: 200)` → `ListView.separated(horizontal)`
- **카드 간 간격**: 12
- **좌우 패딩**: 20

#### NearbyStoreCard
| 속성 | 값 |
|------|-----|
| 위젯 | `GestureDetector > Container` |
| 너비 | `(screenWidth * 0.4).clamp(140, 180)` |
| 배경 | `AppColors.surfaceElevated` (흰색) |
| 테두리 | `Border.all(color: AppColors.border, width: 1)` |
| 라운드 | `BorderRadius.circular(16)` |
| 그림자 | `BoxShadow(color: AppColors.primary.withValues(alpha: 0.04), blurRadius: 8, offset: Offset(0, 2))` |
| 이미지 | 높이 112, 상단 라운드 16, `BoxFit.cover` |
| 하단 패딩 | `EdgeInsets.all(12)` |

**카드 내부 텍스트**
- 매장명: fontSize 14, w700, color: `AppColors.textHeading`, maxLines 1, ellipsis
- 거리 Row (SizedBox height 8 아래):
  - `Icon(Icons.place_outlined, size: 12, color: AppColors.textMuted)`
  - `Text(distance, fontSize: 12, w500, color: AppColors.textMuted)`

**등급 배지** (`GradeBadge` 공통) — 이미지 우상단 `Positioned(top: 8, right: 8)`:
- 배경: `AppColors.primary`
- 라운드: `StadiumBorder` 또는 `BorderRadius.circular(999)` (pill)
- 패딩: `EdgeInsets.symmetric(horizontal: 8, vertical: 3)`
- 텍스트: fontSize 11, w700, color: `AppColors.onPrimary`
- 내용: `"${grade}급"` (home.png 스펙 유지)

### 4. CategoryFilterSection

- **레이아웃**: `SectionTitle("카테고리")` → `Wrap(spacing: 8, runSpacing: 8)`
- **좌우 패딩**: 20

#### CategoryChip
**선택됨 (Selected)**
| 속성 | 값 |
|------|-----|
| 배경 | `AppColors.primary` |
| 텍스트 색 | `AppColors.onPrimary` |
| 테두리 | 없음 |
| 라운드 | `999` (pill) |
| 패딩 | `EdgeInsets.symmetric(horizontal: 16, vertical: 8)` |
| 타이포 | fontSize 13, w500 |

**선택 안됨 (Unselected)**
| 속성 | 값 |
|------|-----|
| 배경 | `AppColors.surfaceElevated` |
| 텍스트 색 | `AppColors.textBody` |
| 테두리 | `Border.all(color: AppColors.border, width: 1)` |
| 라운드 | `999` |
| 패딩 | 동일 |
| 타이포 | 동일 |

**터치 인터랙션**
- `InkWell` 또는 `GestureDetector` 로 탭 영역 확보, splash color 제거(`Colors.transparent`)

### 5. RecommendedStoresSection (맞춤 추천 세로 리스트)

- **제목 Row**: `SectionTitle("맞춤 추천 (N)")` 좌측, 우측 "전체보기" 텍스트 버튼
  - 전체보기: fontSize 13, w500, color: `AppColors.info` (스카이 블루)
  - `TextButton(overlayColor: transparent)` 또는 `GestureDetector` + `Text`
- **리스트**: `ListView.separated(vertical, separator: SizedBox(height: 12))`
- **좌우 패딩**: 20

#### RecommendedStoreCard
| 속성 | 값 |
|------|-----|
| 높이 | 96 |
| 배경 | `AppColors.surfaceElevated` |
| 테두리 | `Border.all(color: AppColors.border, width: 1)` |
| 라운드 | `BorderRadius.circular(16)` |
| 그림자 | NearbyStoreCard와 동일 |

**좌측 이미지 (96×96)**
- 라운드: 좌측만 16
- `Positioned(top: 8, left: 8)` → `GradeBadge` (동일 스타일)

**우측 정보 영역**
- 패딩: `EdgeInsets.symmetric(horizontal: 12, vertical: 10)`
- `Column(mainAxisAlignment: spaceBetween)`
  - 매장명: fontSize 14, w700, color: `AppColors.textHeading`
  - 하단 Row:
    - `Icon(Icons.place_outlined, size: 12, color: AppColors.textMuted)`
    - `Text(distance, fontSize: 13, w500, color: AppColors.textBody)`

**우단**
- `Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted)` + `padding: EdgeInsets.only(right: 12)`

### 6. BottomNav (하단 네비게이션)

- **컨테이너**: 전체 너비, height 자동
- **배경**: `AppColors.surfaceElevated` (흰색)
- **상단 보더**: `Border(top: BorderSide(color: AppColors.border, width: 1))`
- **그림자**: `BoxShadow(color: AppColors.primary.withValues(alpha: 0.06), blurRadius: 12, offset: Offset(0, -2))`
- **세이프 에어리어**: `SafeArea(top: false)` 적용

#### 탭 아이템 (5개)
| 탭 | 아이콘 | 라벨 |
|----|--------|------|
| 홈 | `Icons.home_rounded` | 홈 |
| Qoin | `QLogo(size: 24)` 또는 로고 아이콘 | Qoin |
| 주문 (중앙 FAB) | 커피컵 아이콘 | 주문 |
| Log | `Icons.receipt_long_rounded` | Log |
| 더보기 | `Icons.menu_rounded` | 더보기 |

**탭 상태 색상**
| 상태 | 아이콘/라벨 색 |
|------|---------------|
| 활성 | `AppColors.primary` |
| 비활성 | `AppColors.textMuted` |

- 아이콘 크기: 24
- 라벨: fontSize 11, w500
- 수직 패딩: 8~12

### 7. OrderFab (중앙 주문 FAB)

- **크기**: 56×56
- **모양**: 원형 (`shape: BoxShape.circle`)
- **배경 그라디언트**: `LinearGradient(colors: [AppColors.primary, AppColors.primaryLight], begin: topLeft, end: bottomRight)`
- **위치**: 네비 영역 중앙, `Transform.translate(offset: Offset(0, -18))` 또는 `Stack`으로 위로 떠오르게
- **글로우 애니메이션**:
  - `AnimatedBuilder`로 2초 주기 펄스
  - `BoxShadow` 2개 스택:
    - 정적: `BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 16, offset: Offset(0, 4))`
    - 펄스: `BoxShadow(color: AppColors.primary.withValues(alpha: 0.0 → 0.5 → 0.0), spreadRadius: 0 → 6 → 0, blurRadius: 12)`
- **아이콘**: 커스텀 `CoffeeCupIcon` (home.md의 SVG 이식) 또는 `Icons.coffee_rounded`, color: `AppColors.onPrimary` (흰색)
- **라벨**: 아이콘 아래 "주문", fontSize 11, w500, color: 탭 상태에 따라 `primary` / `textMuted`

### 8. QLogo 색상 수정

- 미드나잇 배경 위(헤더) 노출 시: `color: AppColors.onPrimary`
- 흰 배경 위(네비 Qoin 탭) 노출 시:
  - 활성: `AppColors.primary`
  - 비활성: `AppColors.textMuted`
- 기존 `primaryBright` 단색 고정 → **컨텍스트별 주입**으로 변경

---

## 인터랙션

| 요소 | 인터랙션 |
|------|---------|
| 카드 (주변매장·추천) | Tap → 매장 상세 이동 (현재는 SnackBar placeholder) |
| 카테고리 칩 | Tap → `selectedCategoriesProvider.toggle(category)` |
| 전체보기 | Tap → 매장 전체 목록 화면 (현재는 placeholder) |
| 하단 네비 | Tap → 해당 탭 전환 |
| OrderFab | Tap → 주문 화면 / 장시간 누르면 크게 반응 (현재 버전에선 기본 onTap만) |
| Pull-to-refresh | `RefreshIndicator(color: AppColors.primary)` — 현재 `primaryBright` → `primary`로 변경 |

**애니메이션 타이밍**
- FAB 펄스: 2000ms 주기, `Curves.easeInOut`
- 카드 탭 피드백: 기본 `Material` ripple 대신 `InkWell` + `splashColor: AppColors.primary.withValues(alpha: 0.06)`

---

## 상태별 UI

### 로딩 (shimmer)
- **base color**: `AppColors.surface` (gray-100)
- **highlight color**: `AppColors.surfaceElevated` (흰색)
- _주의_: 다크 팔레트에선 두 값이 역전돼도 자연스럽게 보이므로 토큰 사용 유지
- 카드 placeholder: 실제 카드와 동일한 크기/라운드, 내부 이미지 영역만 shimmer

### 에러
- 화면: 중앙 정렬 Column
  - `Icon(Icons.error_outline, size: 32, color: AppColors.error)`
  - Text "주변매장을 불러올 수 없어요", fontSize 13, w500, color: `AppColors.textBody`
  - `SizedBox(height: 12)`
  - `ElevatedButton`:
    - bg: `AppColors.primary`, fg: `AppColors.onPrimary`
    - shape: `RoundedRectangleBorder(borderRadius: 12)`
    - padding: `EdgeInsets.symmetric(horizontal: 20, vertical: 10)`
    - 라벨: "다시 시도"

### 빈 상태
- `Icon(Icons.place_outlined, size: 40, color: AppColors.textMuted)`
- Text "주변에 매장이 없습니다", fontSize 13, w500, color: `AppColors.textBody`
- (옵션) 보조 문구: "위치 권한을 허용하거나 다시 검색해보세요" — fontSize 12, color: `AppColors.textMuted`

### 위치 폴백 안내
- SnackBar (하단 플로팅) — "위치 권한 없이 기본 위치로 표시 중입니다"
- bg: `AppColors.primary`, textColor: `AppColors.onPrimary`
- duration: 3초

---

## Figma(home.png) 대비 변경사항 / Qradar 아이덴티티 적용

| 항목 | Figma | Qradar 적용 |
|------|-------|-------------|
| 배경 그라디언트 | `gray-50 → white` | 단색 `background`(흰색) — 단순함 우선, 옵션으로 `backgroundGradient` |
| 헤더 그라디언트 | `slate-900 → slate-800` | `AppColors.primary` 단색 (팔레트 전환 대응). 그라디언트 필요 시 `primary → primaryDeep` |
| 카드 shadow | `shadow-sm / hover:shadow-lg` | 정적 아주 연한 shadow 하나 (Flutter 호버 없음) |
| 브랜드 텍스트 색 | 흰색 단색 | 흰색 단색 (기존 ShaderMask 블루 그라디언트 제거 — 네이비 위에서 대비 약함) |
| 카테고리 칩 비선택 | `bg-white + border-gray-200 + text-gray-700` | `surfaceElevated + border + textBody` |
| 전체보기 | `text-sky-500` | `AppColors.info` (`#0EA5E9`) |
| 별점 | `text-amber-500` | `AppColors.accent` (`#FFD700`) — 현재 화면에는 별점 미노출이지만 추후 메뉴에서 사용 |
| 하단 네비 활성 | `text-slate-900` | `AppColors.primary` (동일 의미) |
| 하단 네비 비활성 | `text-gray-400 / text-gray-600` | `AppColors.textMuted` 단일화 |

---

## 토큰 치환 체크리스트 (developer 참조)

기존 위젯의 다크 전제 하드코딩/잘못된 토큰 사용 지점:

### `home_header.dart`
- ❌ `gradient: LinearGradient(colors: [AppColors.surface, AppColors.background])` (라이트에서 gray-100 → 흰색)
- ✅ `color: AppColors.primary` 또는 `gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDeep])`
- ❌ QLogo 기본색이 `primaryBright`여서 네이비 위에서 대비 애매 → `color: AppColors.onPrimary` 주입
- ❌ 'uality Grader Radar' ShaderMask 제거, 단색 `onPrimary`
- ❌ `AppColors.textDefault / textDark` → 네이비 헤더 위에선 `onPrimary` / `onPrimary.withValues(alpha:.9)`

### `store_card.dart` (Nearby & Recommended)
- ❌ `color: AppColors.surface` (gray-100) → ✅ `AppColors.surfaceElevated` (흰색)
- ❌ `Border.all(color: AppColors.surfaceElevated)` (흰) → ✅ `AppColors.border` (gray-200)
- ❌ `color: AppColors.textDark` (OK, alias로 textHeading) — alias 유지돼 동작하지만 새 토큰 `textHeading` 권장
- `_StoreImage._placeholder`의 `color: AppColors.surfaceElevated` → `AppColors.surface` 로 (플레이스홀더가 너무 희다)

### `grade_badge.dart`
- ❌ 등급별 색 `store_grade.dart`의 badgeColor 사용 중 — S=accent, A=primaryBright, B=primaryLight, C=textMuted
- home.png는 **등급 무관 미드나잇 단일**이라서 더 단순함
- ✅ 배지 배경 `AppColors.primary` 고정 + 텍스트 `AppColors.onPrimary`
- 등급 구분은 텍스트("S급", "A급")로만 표현. 색을 등급별로 다르게 유지하고 싶으면 별도 옵션 필요 — 이번 리프레시는 **단일 미드나잇** 기준

### `nearby_stores_section.dart` / `recommended_stores_section.dart`
- shimmer color 쌍 유지 (`surface` / `surfaceElevated`) — 토큰 기반이라 팔레트 스왑 자동 대응
- 에러/빈 상태 아이콘 색: `textMuted` 유지, 에러 아이콘만 `AppColors.error`로 변경

### `category_filter_section.dart`
- 선택/비선택 상태별 배경·테두리·텍스트 토큰 위의 규칙대로 치환
- 기존에 `primaryBright` 사용 중이면 → `primary`

### `section_title.dart`
- 텍스트 색: `textDark` (alias) → `textHeading`로 표기 통일 권장 (동작 동일)

### `bottom_nav.dart`, `order_fab.dart`, `scaffold_with_nav.dart`
- 위 6·7번 항목 수치/색 적용

---

## 완료 기준 (design.md 관점)

- 개발자가 본 문서만 보고 위젯 단위로 구현 가능한 구체성 확보 ✓
- 모든 상태(로딩/에러/빈/폴백) 정의 ✓
- 색상은 `AppColors.*` 토큰으로만 지정, 헥스 값 직접 사용 없음 ✓
- 팔레트 스왑(`LightMidnightAccentPalette` ↔ `DarkMidnightPalette`) 시 깨지지 않도록 의미 기반 토큰만 사용 ✓
