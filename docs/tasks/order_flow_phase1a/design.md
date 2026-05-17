# order_flow_phase1a 디자인 명세 (매장 메뉴 + 음료 상세 + 옵션)

## 참조한 디자인

- Figma: 없음 (Qradar 디자인 시스템 + 기존 화면 톤 기반 신규 설계)
- 기존 화면 톤:
  - `lib/presentation/customer/order/widgets/store_map_marker_sheet.dart` — 바텀 카드/라운드/그림자 톤
  - `lib/presentation/customer/home/widgets/store_card.dart` — 카드 데코, 이미지 placeholder, shimmer 패턴
  - `lib/presentation/customer/order/order_page.dart` — AppBar / TabBar 톤
  - `lib/presentation/customer/order/widgets/order_search_bar.dart` — 입력창 톤
- 참고 컴포넌트:
  - `GradeBadge` (재사용)
  - `_StoreImage` 패턴 (매장 메뉴 헤더 이미지 fallback)
  - `_cardDecoration()` 패턴 (메뉴 카드 데코)

---

## 화면 구성

### A. StoreMenuPage

- 라우트: `/order/store/:storeId`
- 레이아웃: Scaffold + CustomScrollView (Sliver 구성)
- 배경: `AppColors.background`
- SafeArea: top/bottom 모두 적용
- Scroll: `CustomScrollView`
  - SliverAppBar (pinned + 매장 헤더가 펼쳐져 있을 때 큰 영역)
  - SliverPersistentHeader (메인 카테고리 탭 + 부 카테고리 chips, pinned)
  - SliverPadding + SliverGrid (메뉴 그리드)
- AppBar:
  - leading: `Icons.arrow_back_ios_new_rounded` (size 20, `textHeading`)
  - title: 매장 이름 (스크롤 collapse 후 노출 — `SliverAppBar.title` + `expandedHeight` 처리)
  - actions: 우상단 카트 아이콘 (개수 뱃지)
  - background: `AppColors.background`, surfaceTint transparent, elevation 0

#### 주요 섹션 (Sliver 순서)
1. **매장 헤더 영역** (SliverAppBar `flexibleSpace`)
2. **카테고리 영역** (SliverPersistentHeader, pinned)
   - 메인 카테고리 탭 3개
   - 부 카테고리 chips (조건부)
3. **메뉴 그리드** (SliverPadding + SliverGrid)
4. **빈 상태** (메뉴 0건 시 SliverFillRemaining 으로 교체)

---

### B. MenuItemDetailPage

- 라우트: `/order/store/:storeId/menu/:menuItemId`
- 레이아웃: Scaffold (body: CustomScrollView, bottomNavigationBar: 하단 고정 액션)
- 배경: `AppColors.background`
- SafeArea: top false (이미지가 status bar 까지 확장), bottom true
- Scroll: SingleChildScrollView 또는 CustomScrollView
- AppBar: 이미지 영역 위 floating (transparent + back 버튼만)
- 하단 고정 영역: `bottomNavigationBar` 또는 `Stack + Positioned` 로 구현

#### 주요 섹션 (위→아래)
1. **메뉴 이미지 영역** (4:3 비율)
2. **메뉴 정보** (이름 / 설명 / 기본가)
3. **옵션 그룹 섹션 리스트**
4. **수량 stepper**
5. **하단 고정**: 합계 + "담기" 버튼 (full-width)

---

## 컴포넌트 목록

### 1. StoreMenuPage AppBar

- 역할: 닫기/뒤로 이동 + 매장 이름(축소 시) + 카트 진입
- 위젯 구조: `SliverAppBar(pinned: true, expandedHeight: 200, ...)`
  - `leading`: `IconButton(Icons.arrow_back_ios_new_rounded)` → `Navigator.pop`
  - `title`: 매장 이름 (collapsed 일 때만 노출 — `LayoutBuilder` 또는 `FlexibleSpaceBar.title`)
  - `actions`: 카트 아이콘 (아래 카트 컴포넌트 참조)
- 크기:
  - expandedHeight: 200
  - collapse 시 표준 toolbar 높이 56
- 색상:
  - background: `AppColors.background`
  - surfaceTintColor: `Colors.transparent`
  - elevation: 0
  - foreground 아이콘/텍스트: `AppColors.textHeading`

---

### 2. 카트 액션 아이콘 (AppBar action)

- 역할: 카트 페이지 진입 (Phase 1a 는 placeholder 토스트)
- 위젯 구조: `Stack` (`IconButton` + `Positioned` 뱃지)
- 크기:
  - tap target: 40×40 (IconButton 기본)
  - 아이콘 크기: 24
  - 뱃지: `Container` 16×16, radius 999
- 색상:
  - 아이콘: `AppColors.textHeading`
  - 뱃지 배경: `AppColors.primary`
  - 뱃지 텍스트: `AppColors.onPrimary` (10sp, w700)
- 상태:
  - default: 뱃지 숨김 (Phase 1a 는 항상 숨김 처리; Phase 1b 가 카운트 연결)
  - placeholder: tap → SnackBar "장바구니는 준비 중입니다 (Phase 1b)"

---

### 3. StoreMenuHeader (SliverAppBar flexibleSpace)

- 역할: 매장 정보 노출 (이미지 + 이름 + 등급 + 거리 + 영업 상태 + 즐겨찾기 토글)
- 위젯 구조:
  ```
  Stack
  ├─ Positioned.fill (배경 이미지 + 어두운 그라디언트 오버레이)
  └─ Padding
     └─ Column (bottom-aligned)
        ├─ Row (이름 + 즐겨찾기)
        ├─ Row (거리 + 영업 상태 + GradeBadge)
  ```
- 크기:
  - 전체 height: 200
  - padding: `EdgeInsets.fromLTRB(20, 56, 20, 16)` (상단 status bar 고려)
- 배경:
  - 이미지: `CachedNetworkImage(fit: BoxFit.cover)`, fallback = `_placeholder` (`AppColors.surface` + `Icons.storefront_outlined`)
  - 오버레이: `LinearGradient(top → bottom, transparent → AppColors.textHeading.withAlpha(0.55))`
- 텍스트:
  - 매장 이름: `fontSize: 22`, `w800`, `AppColors.onPrimary` (이미지 위라 onPrimary 사용 — 흰 텍스트 보장)
  - 거리: `fontSize: 13`, `w500`, `AppColors.onPrimary.withAlpha(0.85)`, prefix `Icons.place_outlined` size 14
  - 영업 상태: `fontSize: 13`, `w600`
    - 영업 중: `AppColors.success`
    - 마감: `AppColors.error`
- 즐겨찾기 토글 위치: 우상단 (Padding 안 Row 의 trailing)
- 즐겨찾기 토글:
  - 위젯 구조: `IconButton`(`Icons.favorite_border_rounded` / `Icons.favorite_rounded`)
  - 크기: 40×40 tap target
  - default: outline icon, color `AppColors.onPrimary`
  - active: filled icon, color `AppColors.error` (붉은 하트 — 음식/즐겨찾기 관습)
  - Phase 1a placeholder: tap → SnackBar "즐겨찾기는 준비 중입니다 (Phase 1c)"
  - 비활성 분기 없음 (항상 시각적으로 outline 유지)
- GradeBadge: 기존 위젯 그대로 재사용 (Row 안)

---

### 4. MainCategoryTabs (SliverPersistentHeader 일부)

- 역할: 커피 / 논커피 / 디저트 메인 카테고리 탭
- 위젯 구조: `Row`로 3개 `_MainCategoryTab` 균등 분할 (`Expanded` 3개)
- 크기:
  - height: 48
  - 텍스트 fontSize: 15
- 색상:
  - 컨테이너 배경: `AppColors.background`
  - 하단 구분선: `AppColors.border` 1px (전체 row 의 bottom)
  - **탭 인디케이터**: 활성 탭 하단에 `AppColors.primary` 2.5px 막대
- 텍스트:
  - 활성: `w700`, `AppColors.primary`
  - 비활성: `w500`, `AppColors.textMuted`
  - 비활성(매장 보유 0): `w500`, `AppColors.textMuted.withAlpha(0.4)` + `IgnorePointer`
- 상태:
  - default(비선택): `textMuted`
  - selected: `primary` + 인디케이터
  - disabled(보유 0): `textMuted` 40% alpha + 탭 안 됨

---

### 5. SubCategoryChips (SliverPersistentHeader 일부)

- 역할: 현재 메인 카테고리에 매장이 보유한 부 카테고리 노출. 1개뿐이면 위젯 자체 숨김.
- 위젯 구조: `SizedBox(height: 56) + ListView.separated(scrollDirection: Axis.horizontal)`
  - 첫 칩은 항상 "전체" (designer 결정 — UX 권장)
- 크기:
  - row height: 56 (위쪽 여백 12 + 칩 32 + 아래 여백 12)
  - 칩 height: 32
  - 칩 padding: `EdgeInsets.symmetric(horizontal: 14, vertical: 6)`
  - separator: 8
  - 좌우 padding: 20
- 칩 (Chip 자체 디자인):
  - radius: 999 (pill)
  - 텍스트 fontSize: 13, w600
  - **선택**:
    - 배경: `AppColors.primary`
    - 텍스트: `AppColors.onPrimary`
    - border: 없음
  - **비선택**:
    - 배경: `AppColors.surfaceElevated`
    - 텍스트: `AppColors.textBody`
    - border: `AppColors.border` 1px
- 자동 숨김 조건: 매장 보유 부 카테고리 ≤ 1 → 위젯 미렌더 (height = 0)

---

### 6. MenuItemCard (SliverGrid 셀)

- 역할: 메뉴 1건 표시
- 위젯 구조:
  ```
  GestureDetector
  └─ Container (cardDecoration)
     └─ Column
        ├─ Stack (이미지 + 품절 오버레이)
        └─ Padding (이름 + 가격)
  ```
- 그리드:
  - SliverGrid `crossAxisCount: 2`
  - mainAxisSpacing: 12
  - crossAxisSpacing: 12
  - 셀 비율: childAspectRatio: 0.78 (이미지 정사각 + 텍스트 영역 약 64px)
  - 그리드 padding: `EdgeInsets.fromLTRB(20, 16, 20, 32)`
- 카드 데코:
  - background: `AppColors.surfaceElevated`
  - border: `AppColors.border` 1px
  - radius: 16
  - shadow: `AppColors.primary` alpha 0.04, blur 8, offset (0,2)
- 이미지:
  - 정사각 (셀 너비와 동일)
  - `BorderRadius.only(topLeft: 16, topRight: 16)`
  - fallback: `AppColors.surface` + `Icons.local_cafe_outlined` (`AppColors.textMuted`, size 28)
  - shimmer (loading): `AppColors.surface` base / `AppColors.surfaceElevated` highlight
- 텍스트 영역:
  - padding: `EdgeInsets.symmetric(horizontal: 12, vertical: 10)`
  - 이름:
    - fontSize: 14, w700, `AppColors.textHeading`
    - maxLines: 1, ellipsis
  - 가격:
    - fontSize: 13, w700, `AppColors.primary`
    - 포맷: `"4,500원"` (`,` 천단위 구분 + 원)
  - gap: 4
- 품절 오버레이:
  - 조건: `menuItem.soldOut == true`
  - 위젯: `Positioned.fill` `Container(color: AppColors.background.withAlpha(0.7))` + 가운데 `Container` (radius 999, padding 6×12, bg `AppColors.textHeading.withAlpha(0.85)`, text "품절" w700 12sp `AppColors.onPrimary`)
  - 카드 GestureDetector 는 비활성 (`onTap: null`)
  - 이름/가격 텍스트 색은 `textMuted` 로 톤다운

---

### 7. MenuItemDetailPage 헤더 (이미지 + back + 즐겨찾기)

- 역할: 상단 이미지 풀 + back 버튼 + 즐겨찾기 토글
- 위젯 구조:
  ```
  AspectRatio(4/3)
  └─ Stack
     ├─ CachedNetworkImage(fit: BoxFit.cover)
     ├─ 그라디언트 오버레이 (top, status bar 가독성)
     ├─ Positioned(top, left): back 버튼
     └─ Positioned(top, right): 즐겨찾기 토글
  ```
- 비율: **4:3** (designer 판단 — 16:9 보다 음료 이미지 보존성 좋음)
- 이미지 fallback: `AppColors.surface` + `Icons.local_cafe_outlined` (size 64, `AppColors.textMuted`)
- 그라디언트 오버레이 (상단 96px):
  - `LinearGradient(top → bottom, AppColors.textHeading.withAlpha(0.45) → transparent)`
- back 버튼:
  - 크기: 40×40 tap target, 아이콘 24
  - 배경: `AppColors.surfaceElevated.withAlpha(0.85)` 원형 (radius 999)
  - 아이콘: `Icons.arrow_back_ios_new_rounded`, color `AppColors.textHeading`
  - 위치: `Positioned(top: 12 + status bar, left: 16)` (SafeArea wrapping)
- 즐겨찾기 토글:
  - 동일 원형 배경
  - 아이콘: outline → `Icons.favorite_border_rounded` (`AppColors.textHeading`), active → `Icons.favorite_rounded` (`AppColors.error`)
  - 위치: `Positioned(top: 12 + status bar, right: 16)`
  - Phase 1a placeholder: tap → SnackBar "즐겨찾기는 준비 중입니다 (Phase 1c)"

---

### 8. MenuItemDetail Info 섹션

- 역할: 이름 / 설명 / 기본가
- 위젯 구조: `Padding(EdgeInsets.fromLTRB(20, 24, 20, 0)) → Column`
- 텍스트 stack (위→아래):
  - 이름: `fontSize: 22`, w800, `AppColors.textHeading`, maxLines 2
  - gap: 8
  - 설명: `fontSize: 14`, w400, `AppColors.textBody`, lineHeight 1.5, 설명 없으면 위젯 미렌더
  - gap: 12
  - 기본가: `fontSize: 18`, w700, `AppColors.primary`, 포맷 `"4,500원"`
- 하단 구분선: 24px 위 여백 + `Container(height: 1, color: AppColors.border)` + 24px 아래 여백 (다음 옵션 섹션 시작 전)

---

### 9. OptionGroupSelector

- 역할: 옵션 그룹 1건 표시 (헤더 + 항목 리스트)
- 위젯 구조:
  ```
  Padding(horizontal: 20, vertical: 8)
  └─ Column
     ├─ Row (헤더): 그룹명 + (필수면) 필수 뱃지
     ├─ gap 12
     └─ Column (항목 리스트): _OptionItemRow × N
  ```
- 헤더:
  - 그룹명: `fontSize: 16`, w700, `AppColors.textHeading`
  - 필수 뱃지:
    - 조건: `group.required == true`
    - 위젯: `Container(padding: 6×3, decoration: radius 6 + bg AppColors.primary.withAlpha(0.1) + border AppColors.primary 1px)`
    - 텍스트: "필수", `fontSize: 11`, w700, `AppColors.primary`
- 그룹 간 구분: 그룹 사이 `Container(height: 1, color: AppColors.border)` + vertical 16

#### 9-1. _OptionItemRow (단일 선택 = 라디오)

- 위젯 구조: `InkWell + Row(라디오 + 라벨 + Spacer + priceDelta)`
- 크기:
  - 전체 height: 52 (tap target 보장)
  - radio 크기: 22
  - padding: `EdgeInsets.symmetric(vertical: 14)`
- 라디오:
  - 선택: 채움 원 (radius 11) `AppColors.primary` + 안쪽 흰 점
  - 비선택: 외곽선 1.5px `AppColors.border` (radius 11)
- 라벨: `fontSize: 15`, w500, `AppColors.textBody`
- priceDelta:
  - 양수: `"+1,000원"` color `AppColors.textBody`, w600
  - 음수: `"-300원"` color `AppColors.success`, w600
  - 0: 미렌더
- 선택 시 라벨/딜타 색은 `AppColors.textHeading` + w700 로 강조 (단, priceDelta 음수면 success 유지)
- 단일/선택 그룹: 첫 번째 항목으로 `_OptionItemRow(label: "선택 안함", value: null, priceDelta: 0)` 자동 prepend

#### 9-2. _OptionItemRow (다중 선택 = 체크박스)

- 동일 구조, radio 자리에 체크박스 (`Icons.check_box_rounded` / `Icons.check_box_outline_blank_rounded`)
- 크기: 동일 22
- 색상:
  - 선택: `AppColors.primary`
  - 비선택: `AppColors.border` (outline 아이콘)
- 라벨/priceDelta 규칙 동일

---

### 10. QuantityStepper (`presentation/common/quantity_stepper.dart`)

- 역할: 수량 1~99 입력
- 위젯 구조: `Container(decoration) → Row[(-) , value, (+)]`
- 크기:
  - 전체 height: 44
  - 좌/우 버튼: 44×44
  - 중앙 텍스트 영역 width: 64
- 데코:
  - 배경: `AppColors.surfaceElevated`
  - border: `AppColors.border` 1px
  - radius: 12
- 버튼:
  - 아이콘: `Icons.remove_rounded`, `Icons.add_rounded` (size 20)
  - 활성 색: `AppColors.textHeading`
  - 비활성 색: `AppColors.textMuted.withAlpha(0.4)` (- 가 1, + 가 99 일 때)
  - splash: `AppColors.primary.withAlpha(0.08)`
- 중앙 값:
  - fontSize: 16, w700, `AppColors.textHeading`
- 페이지 내 위치:
  - MenuItemDetailPage 옵션 섹션 다음, 하단 액션 위
  - 좌측 라벨 "수량" (`fontSize: 16`, w700, `textHeading`) + 우측에 stepper

---

### 11. MenuItemDetailPage 하단 액션

- 역할: 합계 + "담기" 버튼 (full-width)
- 위젯 구조 (`bottomNavigationBar` 자리):
  ```
  Container(
    decoration: top border + shadow,
    padding: 20×16(top) + 20×16(bottom + safeArea),
    child: Column(
      children: [
        Row (라벨 "합계" + 합계 텍스트),
        gap 12,
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton),
      ],
    ),
  )
  ```
- 데코:
  - background: `AppColors.surfaceElevated`
  - top border: `AppColors.border` 1px
  - shadow: `AppColors.primary.withAlpha(0.06)`, blur 16, offset (0, -4)
- 합계 row:
  - 좌측 "합계": fontSize 14, w500, `AppColors.textMuted`
  - 우측 합계 금액: fontSize 20, w800, `AppColors.primary`, 포맷 `"6,000원"`
- 버튼:
  - 활성:
    - 배경: `AppColors.primary`
    - 텍스트: `AppColors.onPrimary`, fontSize 16, w700
    - radius: 14
    - elevation: 0
  - 비활성 (필수 옵션 미충족):
    - 배경: `AppColors.surface`
    - 텍스트: `AppColors.textMuted`, fontSize 16, w700
    - 누르면 토스트로 미충족 그룹 안내 ("'온도' 를 선택해주세요" 등)
  - Phase 1a placeholder: 활성 상태에서 누르면 → SnackBar "장바구니 기능은 준비 중입니다 (Phase 1b)"
  - 라벨: "담기" (Phase 1b 에서 텍스트 그대로 유지)

---

### 12. 시드 다이얼로그 (개발자 전용)

- 트리거: MorePage 앱 버전 텍스트 long-press (1초). `kDebugMode` 분기.
- 다이얼로그: `AlertDialog`
- 데코:
  - background: `AppColors.surfaceElevated`
  - radius: 16
- 텍스트:
  - 제목: "Phase 1 시드 데이터", fontSize 17, w700, `AppColors.textHeading`
  - 본문: "subCategories / optionGroups / 임시 매장 1개 + 메뉴 6~8개를 Firestore 에 기록합니다. 이미 존재 시 덮어씁니다.", fontSize 14, w400, `AppColors.textBody`, lineHeight 1.5
- 액션 버튼 (Row, mainAxisAlignment.end):
  - "취소": TextButton, color `AppColors.textMuted`, fontSize 14, w600
  - "실행": TextButton, color `AppColors.primary`, fontSize 14, w700
- 실행 후 SnackBar (성공/실패):
  - 성공: bg `AppColors.success`, text `AppColors.onPrimary` "시드 완료 (총 N건)"
  - 실패: bg `AppColors.error`, text `AppColors.onPrimary` "시드 실패: {message}"

---

## 인터랙션

| 동작 | 반응 |
|---|---|
| 매장 헤더 즐겨찾기 탭 | placeholder 토스트 ("즐겨찾기는 준비 중입니다 (Phase 1c)") |
| 메인 카테고리 탭 | 인디케이터 이동 (200ms ease-out), `selectedSubCategoryIdProvider` null reset, 부 카테고리 chips 갱신, 그리드 갱신 |
| 메인 카테고리 비활성 탭 (보유 0) | 무반응 (`IgnorePointer`) + 시각적으로 회색 |
| 부 카테고리 칩 탭 | `selectedSubCategoryIdProvider` 갱신, 그리드 필터 적용. "전체" 칩이면 null 로 reset |
| 메뉴 카드 탭 | `/order/store/:storeId/menu/:menuItemId` push (transition: 기본 platform) |
| 품절 메뉴 카드 탭 | 무반응 (GestureDetector onTap null) |
| AppBar 카트 아이콘 탭 | placeholder 토스트 ("장바구니는 준비 중입니다 (Phase 1b)") |
| MenuItemDetail 옵션 라디오 | 그룹 내 1개 선택, 합계 즉시 갱신 |
| MenuItemDetail 옵션 체크박스 | 그룹 내 다중 선택 토글, 합계 즉시 갱신 |
| 수량 stepper +/- | 1~99 범위, 합계 즉시 갱신, 경계값에서 버튼 비활성 |
| MenuItemDetail "담기" 활성 탭 | Phase 1a: placeholder 토스트. Phase 1b 에서 addToCart 호출로 교체. |
| MenuItemDetail "담기" 비활성 탭 | 토스트로 미충족 그룹 안내 (예: "'온도' 를 선택해주세요") |
| MenuItemDetail 즐겨찾기 탭 | placeholder 토스트 (Phase 1c) |
| 스와이프 (좌→우 시스템 백) | 페이지 pop |
| 스크롤 (StoreMenuPage) | SliverAppBar collapse → AppBar title 노출 |
| MorePage 앱 버전 long-press (debug 빌드만) | 시드 다이얼로그 표시 |

---

## 상태별 UI

### Loading

#### StoreMenuPage
- 표시 방식:
  - 매장 헤더: shimmer 박스 (높이 200, base `AppColors.surface`, highlight `AppColors.surfaceElevated`)
  - 카테고리 영역: 정상 렌더 (탭만 회색 인디케이터 없이 표시)
  - 그리드: 6개 shimmer 카드 (이미지 정사각 + 2줄 텍스트 라인)
- 색상: shimmer base/highlight 위 토큰
- progress: 사용 안 함 (shimmer로 충분)

#### MenuItemDetailPage
- 표시 방식:
  - 상단 이미지: shimmer 박스 (4:3)
  - 본문: 텍스트 라인 shimmer 3줄 (이름 / 설명 / 기본가)
  - 옵션 영역: 그룹 헤더 + 항목 3개 shimmer
  - 하단 액션: 버튼 비활성 상태 (`AppColors.surface` + `textMuted` 텍스트 "로딩 중...")

### Error

#### StoreMenuPage
- 표시 방식: `SliverFillRemaining` 으로 헤더/카테고리 자리만 유지하고 그리드 자리에 에러 카드
- 위젯 구조:
  ```
  Center(
    Column(
      Icon(Icons.error_outline_rounded, size 48, AppColors.error),
      gap 12,
      Text("매장 메뉴를 불러올 수 없어요", w700 16 textHeading),
      gap 6,
      Text("잠시 후 다시 시도해주세요", w400 13 textMuted),
      gap 16,
      OutlinedButton("재시도"),
    ),
  )
  ```
- 재시도 버튼:
  - border: `AppColors.primary` 1.5px
  - 텍스트: `AppColors.primary` w700
  - radius: 12, height 44, padding 28×0
  - onPressed: `ref.invalidate(storeMenuItemsProvider(storeId))`

#### MenuItemDetailPage
- 동일 패턴, 메시지: "메뉴를 불러올 수 없어요" + "재시도"
- 메뉴 deleted (provider null):
  - 메시지: "메뉴를 찾을 수 없어요"
  - 버튼 텍스트: "뒤로가기" → `Navigator.pop`

### Empty

#### StoreMenuPage (메뉴 0건)
- 표시 방식: SliverFillRemaining
- 위젯 구조:
  ```
  Center(
    Column(
      Icon(Icons.local_cafe_outlined, size 56, textMuted),
      gap 16,
      Text("등록된 메뉴가 없어요", w700 16 textHeading),
      gap 6,
      Text("매장에 다시 방문해주세요", w400 13 textMuted),
      gap 16,
      TextButton("뒤로가기", primary 14 w600),
    ),
  )
  ```

#### StoreMenuPage (특정 메인 카테고리만 보유 0)
- 메뉴 그리드 자리에:
  - Icon `Icons.category_outlined` size 48 textMuted
  - Text "이 카테고리에는 메뉴가 없어요" w500 14 textMuted
  - 50px 위/아래 패딩

---

## Figma 대비 변경사항

| 항목 | Figma / 기존안 | Qradar 적용 |
|---|---|---|
| 색상 | (Figma 없음) | 전부 `AppColors` 토큰 |
| 매장 헤더 | spec 텍스트만 | SliverAppBar 4:3 비율 + 그라디언트 오버레이 + 매장 이름 큰 타이포 |
| 메인 카테고리 탭 | spec 텍스트만 | TabBar 형태가 아닌 균등 Row + 하단 인디케이터 (TabBar 보다 가벼움) |
| 부 카테고리 chips | "1개뿐이면 자동 숨김" 만 | "전체" 칩 prepend 하여 필터 해제 명확화 |
| 음료 상세 이미지 | spec 비율 미정 | 4:3 채택 (음료 이미지 보존성) |
| 즐겨찾기 색상 | (미정) | active = `AppColors.error` (붉은 하트). 음식 도메인 관습 + accent(골드)는 Qoin/등급 전용으로 보존 |
| 옵션 priceDelta 음수 색상 | spec "할인 표기" | `AppColors.success` (녹색). 사용자 이득 강조 |

---

## 개발자 전달 특이사항

### 구현 시 주의할 점

1. **SliverAppBar collapse 시 매장 이름 표시**:
   - `FlexibleSpaceBar.title` 은 자동 collapse 와 잘 맞지 않을 수 있음. `LayoutBuilder` 로 `constraints.biggest.height` 를 추적해 collapsed 상태일 때만 AppBar `title` 위젯에 매장 이름 표시 권장.
2. **부 카테고리 chips 자동 숨김**:
   - 매장 보유 부 카테고리(`storeAvailableSubCategoriesProvider`) 결과에 "전체" 를 포함하지 말고, UI 렌더 단에서 prepend. 보유 ≤ 1 판정은 "전체" 빼고 카운트.
3. **메인 카테고리 탭 비활성**:
   - `IgnorePointer` 로 탭 차단 + opacity 0.4 처리. `Tab.enabled` 가 아닌 wrapper 로 처리.
4. **품절 카드 onTap null**:
   - GestureDetector 가 아닌 부모에서 분기. 카드 자체는 항상 그려도 OK.
5. **placeholder 토스트는 모두 SnackBar 로 통일** (`ScaffoldMessenger.of(context).showSnackBar`):
   - duration 2초
   - bg: `AppColors.textHeading.withAlpha(0.9)`, text `AppColors.onPrimary`, radius 8, margin 16
6. **수량 stepper 의 분리 가능성**:
   - 본 phase 의 stepper 는 `presentation/common/` 에 둠. 재사용 의도 (카트 라인에서도 사용 예정).
7. **이미지 fallback 통일**:
   - 매장: `Icons.storefront_outlined`
   - 메뉴: `Icons.local_cafe_outlined`
8. **OptionGroupSelector 단일/선택 그룹의 "선택 안함" prepend**:
   - 그룹의 selectionType=single + required=false 인 경우만 자동 prepend.
   - 단일/필수 그룹은 "선택 안함" 없음. 첫 항목 자동 선택.
9. **하단 액션 영역 SafeArea**:
   - `bottomNavigationBar` 자리는 자동 SafeArea. `Container` 사용 시 `SafeArea(top: false)` wrapping 권장.

### 재사용할 컴포넌트

- `GradeBadge` (그대로 재사용)
- `_StoreImage` 패턴 (메뉴 헤더에 동일 패턴 사용 — 별도 위젯 추출하지 않고 inline OK)
- `_cardDecoration()` 패턴 (메뉴 카드)
- `Shimmer.fromColors` 패턴 (이미지/텍스트 라인 placeholder)

### 새로 만들어야 하는 컴포넌트

- `presentation/customer/order/store/widgets/store_menu_header.dart` — SliverAppBar flexibleSpace 안에 들어갈 매장 헤더
- `presentation/customer/order/store/widgets/main_category_tabs.dart`
- `presentation/customer/order/store/widgets/sub_category_chips.dart`
- `presentation/customer/order/store/widgets/menu_item_card.dart`
- `presentation/customer/order/menu/widgets/option_group_selector.dart`
- `presentation/customer/order/menu/widgets/menu_item_detail_image.dart` (이미지 + back + 즐겨찾기)
- `presentation/customer/order/menu/widgets/menu_item_bottom_action.dart` (합계 + 담기 버튼)
- `presentation/common/quantity_stepper.dart`

### AppColors 토큰 정리

| 위치 | 토큰 |
|---|---|
| Scaffold 배경 | `AppColors.background` |
| AppBar 배경 | `AppColors.background` |
| 카드/입력창/다이얼로그 | `AppColors.surfaceElevated` |
| placeholder/shimmer base/이미지 fallback | `AppColors.surface` |
| shimmer highlight | `AppColors.surfaceElevated` |
| 카드 border / 구분선 | `AppColors.border` |
| 메인 텍스트(타이틀) | `AppColors.textHeading` |
| 본문 텍스트 | `AppColors.textBody` |
| 보조/캡션/비활성 | `AppColors.textMuted` |
| 활성 탭/칩/버튼/가격 | `AppColors.primary` |
| primary 위 텍스트/아이콘 | `AppColors.onPrimary` |
| 즐겨찾기 active | `AppColors.error` |
| priceDelta 음수(할인) | `AppColors.success` |
| 영업 중 | `AppColors.success` |
| 마감 | `AppColors.error` |
| 시드 SnackBar 성공 | `AppColors.success` |
| 시드 SnackBar 실패 | `AppColors.error` |

### 애니메이션 수치

| 대상 | duration | curve |
|---|---|---|
| 메인 카테고리 인디케이터 이동 | 200ms | Curves.easeOutCubic |
| 부 카테고리 칩 색상 전환 | 150ms | Curves.easeOut |
| SliverAppBar collapse | (Sliver 기본) | (Sliver 기본) |
| 페이지 push/pop | (platform 기본) | (platform 기본) |
| SnackBar 노출 | 250ms (Material 기본) | (Material 기본) |

### 후속 작업 (Phase 1a 완료 후)

- Phase 1b: 카트 액션 아이콘의 뱃지 카운트 연결, 담기 버튼 onTap 교체, 카트 페이지 신규 디자인
- Phase 1c: 즐겨찾기 토글 active 상태 연결, 비로그인 다이얼로그 디자인 추가
- Figma 가 나올 경우: 본 design.md 의 비율/패딩 수치를 우선 검토 대상으로 잡을 것

### 명세에 없는 임의 추가 사항

- "전체" 칩 prepend (designer 결정, spec 권장 사항 채택)
- 즐겨찾기 active 색상 = `AppColors.error` (designer 결정, 위 변경사항 표 참조)
- priceDelta 음수 색상 = `AppColors.success` (designer 결정)
- 4:3 이미지 비율 (designer 판단)
- 메뉴 카드 fallback 아이콘 = `Icons.local_cafe_outlined` (음료/디저트 모두 무난)

이상 항목은 spec 의 "설계자 판단" 또는 "designer 판단" 영역으로 명시된 부분을 본 design.md 에서 확정한 결과.
