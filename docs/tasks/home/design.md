# 홈 화면 디자인 명세

## 참조한 Figma 디자인
- `docs/design/screens/home/home.png` — 홈 화면 레이아웃
- `docs/design/screens/home/home.md` — React 코드 참조 (레이아웃/컴포넌트 구조)
- `docs/design/components/bottom_nav.md` — 하단 네비게이션 코드 참조

## 디자인 방침 (사용자 부재 시 자율 결정 사항)
- Figma 원본이 라이트 테마 기반이므로 **Qradar 다크 프리미엄 테마**로 전면 전환
- 원본의 레이아웃 구조는 유지하되, 색상·재질·강조는 Qradar 아이덴티티로 재해석
- 모든 색상은 `AppColors`에서만 사용 (하드코딩 금지)

---

## 전역 디자인 토큰

### Border Radius
| 요소 | 값 |
|------|---|
| 카드 (매장) | 16 |
| 버튼 | 12 |
| 칩 (카테고리) | 20 (pill) |
| 등급 배지 | 8 |
| 헤더 하단 모서리 | 28 (bottom-left only) |

### Spacing
- 화면 좌우 패딩: 20
- 섹션 간 세로 간격: 24
- 카드 간 간격: 12
- 텍스트-아이콘 간격: 6

### Typography (fontSize / fontWeight)
| 용도 | 크기 | 굵기 | 색상 |
|------|------|------|------|
| 브랜드 타이틀 | 22 | bold | AppColors.textDark |
| 섹션 제목 | 18 | w700 | AppColors.textDark |
| 환영 메시지 | 16 | w400 | AppColors.textDefault |
| 카드 제목 | 14 | w700 | AppColors.textDark |
| 본문 | 13 | w500 | AppColors.textDefault |
| 보조/레이블 | 12 | w500 | AppColors.textMuted |
| 전체보기 링크 | 13 | w600 | AppColors.primaryBright |

### 등급별 색상 (핵심 브랜드 컬러 시스템)
등급별로 배지/악센트 색상을 차등 적용하여 Qradar의 "품질 선별" 아이덴티티 강화:

| 등급 | 주색상 | Flutter |
|------|--------|---------|
| **S** | Gold | `AppColors.accent` (#FFD700) |
| **A** | Electric Blue | `AppColors.primaryBright` (#38BDF8) |
| **B** | Sky | `AppColors.primaryLight` (#7DD3FC) |
| **C** | Slate | `AppColors.textMuted` (#64748B) |

---

## 화면 구성: HomePage

### 최상위 구조
```
Scaffold (backgroundColor: AppColors.background)
└─ Stack
   ├─ CustomScrollView  // body 본체
   │  ├─ SliverToBoxAdapter: HomeHeader
   │  ├─ SliverPadding + SliverToBoxAdapter: NearbyStoresSection
   │  ├─ SliverPadding + SliverToBoxAdapter: CategoryFilterSection
   │  └─ SliverPadding + SliverList: RecommendedStoresSection
   └─ (bottom nav은 ScaffoldWithNav에서 관리)
```

- SafeArea: true (상단만 적용, 하단은 BottomNav가 담당)
- 스크롤 물리: BouncingScrollPhysics (iOS 감성)

---

### 1. HomeHeader (헤더)

**레이아웃:**
```
Container
  - width: 전체 화면 폭
  - padding: EdgeInsets.fromLTRB(20, 16, 20, 24)
  - decoration:
      gradient: LinearGradient(
        begin: topLeft, end: bottomRight,
        colors: [AppColors.surface, AppColors.background]  // #0F172A → #060D1A
      )
      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28))
  - child: Column(crossAxisAlignment: start)
      ├─ Row (QLogo + 브랜드 텍스트)
      │    ├─ QLogo(size: 40, color: AppColors.textDark)
      │    └─ Transform.translate(Offset(-4, 4)) +
      │       Text("uality Grader Radar",
      │         style: fontSize 22, bold, textDark)
      ├─ SizedBox(height: 12)
      └─ RichText("[사용자명]님 어서오세요.",
           사용자명: fontSize 18, bold, textDark
           나머지: fontSize 16, textDefault)
```

**사용자명 출력 로직:**
- authProvider에서 user.displayName → 없으면 user.email의 @ 앞부분 → 없으면 "Qrator"

---

### 2. NearbyStoresSection (주변매장)

**섹션 헤더:**
- `Text("주변매장", style: sectionTitle)` — 섹션 제목 스타일
- 상단 간격 24, 하단 간격 12

**리스트:**
```
SizedBox(
  height: 200,
  child: ListView.separated(
    scrollDirection: horizontal,
    padding: EdgeInsets.symmetric(horizontal: 20),
    separatorBuilder: (_) => SizedBox(width: 12),
    itemCount: stores.length,
    itemBuilder: NearbyStoreCard,
  ),
)
```

**NearbyStoreCard:**
```
Container
  - width: screenWidth * 0.4  (약 150~160)
  - height: 200
  - decoration: AppColors.surface 배경, borderRadius 16,
                 border: Border.all(AppColors.surfaceElevated)
  - child: Column
      ├─ Stack (이미지 영역)
      │    - height: 112
      │    ├─ ClipRRect(top: 16)
      │    │    └─ CachedNetworkImage (fit: cover, 플레이스홀더: shimmer)
      │    └─ Positioned(top: 8, right: 8): GradeBadge
      └─ Padding(all: 12)
          └─ Column
              ├─ Text(store.name, maxLines: 1, ellipsis,
              │        style: 카드 제목)
              ├─ SizedBox(height: 8)
              └─ Row
                  ├─ Icon(Icons.star, 12, AppColors.accent)
                  ├─ SizedBox(width: 4)
                  ├─ Text("4.8급 평균" 대신 Qradar는 등급제라 생략 가능)
                  │   (실제로는 등급/리뷰수만 표시)
                  ├─ Spacer()
                  ├─ Icon(Icons.place_outlined, 12, AppColors.textMuted)
                  └─ Text(distance, 본문)
```

**디자인 결정:**
- Figma 원본은 별점(4.8)을 썼지만, Qradar는 **등급제(S/A/B/C) + 평가 개수** 시스템
- 카드 하단에는 `Icon(place) + 1.2km`만 표시 (거리 중심)
- 등급과 평가 개수는 **GradeBadge** 안에 통합 표시

---

### 3. CategoryFilterSection (카테고리 필터)

**섹션 헤더:**
- `Text("카테고리", style: sectionTitle)`

**칩 그리드:**
```
Padding(horizontal: 20)
  Wrap(
    spacing: 8, runSpacing: 8,
    children: [CategoryChip, ...]  // 12개
  )
```

**CategoryChip:**
```
GestureDetector(onTap: toggle)
  AnimatedContainer(duration: 200ms, curve: easeInOut)
    - padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8)
    - decoration:
        if selected:
          color: AppColors.primaryBright
          border: none
          boxShadow: [Shadow(AppColors.primaryBright.alpha(0.3), blur 8)]
        else:
          color: AppColors.surfaceElevated
          border: Border.all(AppColors.surfaceElevated.alpha(...) or darker)
        borderRadius: 20
    - child: Text(category,
        fontSize 13, w600,
        color: selected ? Colors.white : AppColors.textDefault)
```

**카테고리 목록 (12개):**
```
추천메뉴, 커피, 우리의 디카페인, 논커피/파일라떼,
티, 스무디/프라페, 에이드/쥬스, 밀크쉐이크,
아이스크림, 푸드/디저트, MD상품, 콜라보 메뉴
```

**상호작용:**
- 탭: 선택/해제 토글
- 최소 1개는 선택된 상태 유지 (초기값: "추천메뉴")
- 마지막 하나를 해제하려 하면 해제 방지 (UX 유지)

---

### 4. RecommendedStoresSection (맞춤 추천)

**섹션 헤더:**
```
Row
  ├─ Text("맞춤 추천 (${filtered.length})", style: sectionTitle)
  ├─ Spacer()
  └─ TextButton("전체보기",
       textStyle: 전체보기 링크 스타일,
       onPressed: 전체 매장 리스트 화면으로 이동(향후))
```

**리스트:**
```
Padding(horizontal: 20)
  Column(
    children: stores.map(RecommendedStoreCard).intersperse(SizedBox(height: 12))
  )
```

**RecommendedStoreCard:**
```
Container
  - decoration: AppColors.surface 배경, borderRadius 16,
                border Border.all(AppColors.surfaceElevated)
  - height: 96
  - child: Row
      ├─ Stack (왼쪽 이미지 96x96)
      │    ├─ ClipRRect(left: 16)
      │    │    └─ CachedNetworkImage
      │    └─ Positioned(top: 8, left: 8): GradeBadge
      ├─ Expanded
      │    └─ Padding(EdgeInsets.symmetric(horizontal: 12, vertical: 10))
      │        └─ Column(crossAxisAlignment: start,
      │                   mainAxisAlignment: spaceBetween)
      │            ├─ Text(name, 카드 제목, maxLines 1, ellipsis)
      │            └─ Row
      │                ├─ Icon(place_outlined, 12, textMuted)
      │                └─ Text(distance, 본문)
      └─ Padding(right: 12)
          └─ Icon(chevron_right, 20, textMuted)
```

---

## 공통 컴포넌트

### GradeBadge

**역할:** 매장 등급 + 평가 개수를 한 배지에 통합 표시

**시각 디자인:**
```
Container
  - padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)
  - decoration:
      color: [등급별 주색상].withValues(alpha: 0.15)
      border: Border.all([등급별 주색상], width: 1)
      borderRadius: 8
  - child: Row(mainAxisSize: min)
      ├─ Text("S급", fontSize 11, bold, color: [등급별 주색상])
      └─ Text(" (124)", fontSize 10, w500, color: textMuted)  // 평가 개수
```

**동작:**
- `reviewCount == 0` → `" (-)"` 표시
- 등급별 색상은 위의 "등급별 색상" 테이블 참조

---

### Section Title Widget (공통)

```
Padding(horizontal: 20, bottom: 12)
  Text(title, style: 섹션 제목 스타일)
```

---

## 상태 UI

### 로딩 상태
- **전체 로딩 (첫 진입)**: `CircularProgressIndicator(AppColors.primaryBright)` 중앙
- **주변매장 로딩**: 카드 3개 shimmer 자리표시자
- **맞춤추천 로딩**: 가로 카드 3개 shimmer 자리표시자

### 에러 상태
- **전체 에러 (위치/네트워크)**:
  - 중앙 정렬
  - `Icon(Icons.error_outline, 48, textMuted)`
  - 제목: "매장 정보를 불러올 수 없어요" (w700)
  - 설명: 에러 메시지 (textDefault)
  - 버튼: "다시 시도" (primaryBright 배경)

### 빈 상태
- **주변매장 없음**: 
  - `Icon(Icons.place_outlined, 40, textMuted)` + "주변에 매장이 없습니다"
- **맞춤추천 없음 (필터 결과 0)**:
  - `Icon(Icons.filter_alt_off, 40, textMuted)` + "선택한 카테고리에 해당하는 매장이 없습니다"
- **위치 권한 거부**:
  - 기본 위치(서울 시청)로 폴백하고 상단에 SnackBar로 "위치 권한 없이 기본 위치로 표시 중입니다" 안내

---

## 하단 네비게이션: BottomNav

### 구조
```
Container
  - height: 80 + bottomSafeArea
  - decoration:
      color: AppColors.surface (#0F172A)
      border(top): BorderSide(AppColors.surfaceElevated, 1)
  - child: SafeArea(top: false)
      └─ Row(mainAxisAlignment: spaceAround)
          ├─ NavItem(index 0, icon: home, label: "홈")
          ├─ NavItem(index 1, QLogoIcon, label: "Qoin")
          ├─ OrderFAB (중앙 특수 버튼)
          ├─ NavItem(index 2, receipt_long, label: "Log")
          └─ NavItem(index 3, more_horiz, label: "더보기")
```

**각 NavItem 폭:** `(screenWidth - FAB영역) / 4` 균등 분배

### NavItem 스타일
```
Column(mainAxisAlignment: center)
  ├─ Icon(icon, 24,
       color: active ? AppColors.primaryBright : AppColors.textMuted)
  ├─ SizedBox(height: 4)
  └─ Text(label,
       fontSize 11, w500,
       color: active ? AppColors.textDark : AppColors.textMuted)
```

- "Qoin" 탭의 아이콘은 `QLogo(size: 22, color: 활성색)` 사용 (로고 자체가 아이콘 역할)

---

### OrderFAB (중앙 주문 버튼)

**스펙:**
```
Transform.translate(offset: Offset(0, -12))  // 네비바 위로 돌출
  AnimatedContainer (pulse 애니메이션)
    - size: 64 x 64
    - decoration:
        shape: circle
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryBright],  // Electric Blue 그라디언트
          begin: topLeft, end: bottomRight
        )
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBright.withAlpha(0.5),
            blurRadius: 애니메이션(8→16→8)
          )
        ]
    - child: CoffeeCupIcon (커스텀 또는 Icons.coffee_outlined, white, 28)
```

**애니메이션:**
- Scale: 1.0 ↔ 1.04 (2초 주기, easeInOut)
- Glow (boxShadow blur): 8 ↔ 16 (2초 주기)
- 탭 시 `scale 0.95` 피드백 + 햅틱(HapticFeedback.lightImpact)

**디자인 결정:**
- Figma 원본은 Midnight Navy 그라디언트였으나, 다크 테마 배경 위에서 충돌
- **Electric Blue 그라디언트**로 변경하여 다크 바탕에서 확실한 포커스 포인트 확보
- Qradar의 "레이더" 감성 강화

---

### CoffeeCupIcon (커스텀 아이콘, 선택사항)
Figma 원본의 김(steam) 애니메이션은 MVP에서는 생략하고, 기본 `Icons.coffee_rounded`로 시작.
향후 CustomPainter로 상세 구현 가능.

---

## ScaffoldWithNav (공통 컨테이너)

로그인 후 모든 메인 탭 화면(홈/Qoin/주문/Log/더보기)의 공통 껍데기.

```
Scaffold
  - backgroundColor: AppColors.background
  - body: [선택된 탭의 페이지]
  - bottomNavigationBar: BottomNav(
      selectedIndex: ...,
      onTap: (index) => ...
    )
```

**네비게이션 상태 관리:**
- `selectedTabIndexProvider` (StateProvider<int>, 초기값 0)
- 탭 전환 시 페이지 교체 (IndexedStack으로 상태 유지)

**라우팅 영향:**
- `main.dart`에서 로그인 성공 시 `HomePage` → `ScaffoldWithNav` 로 변경
- HomePage는 ScaffoldWithNav의 child body로 이동

---

## Placeholder 화면 (Qoin / 주문 / Log / 더보기)

모두 같은 공통 템플릿:

```
Center
  Column(mainAxisAlignment: center)
    ├─ Icon([화면별 아이콘], 64, textMuted)
    ├─ SizedBox(height: 16)
    ├─ Text("[화면명]", 섹션 제목 스타일)
    └─ Text("준비 중입니다", 본문, textMuted)
```

| 화면 | 아이콘 | 화면명 |
|------|--------|--------|
| Qoin | QLogo | Qoin |
| 주문 | coffee_outlined | 주문 |
| Log | receipt_long | Log |
| 더보기 | more_horiz | 더보기 |

---

## 인터랙션 요약

| 제스처 | 동작 |
|--------|------|
| 주변매장 카드 탭 | (향후) 매장 상세 페이지 이동 — MVP에서는 SnackBar "상세 화면 준비 중" |
| 카테고리 칩 탭 | 선택 토글 (최소 1개 유지) |
| 맞춤 추천 카드 탭 | (향후) 매장 상세 — MVP에서는 SnackBar |
| 전체보기 탭 | (향후) 매장 리스트 전체 — MVP에서는 SnackBar |
| 하단 네비 탭 | 탭 전환 (IndexedStack) |
| OrderFAB 탭 | (향후) 주문 플로우 — MVP에서는 SnackBar "주문 기능 준비 중" |
| Pull-to-Refresh | HomePage 전체 새로고침 (CustomScrollView + RefreshIndicator) |

---

## Figma 대비 주요 변경사항

| 요소 | 원본 (라이트) | Qradar 적용 |
|------|--------------|-------------|
| 전체 배경 | Gray → White 그라디언트 | Midnight Navy (`#060D1A`) 단색 |
| 헤더 배경 | Slate-900 그라디언트 | Midnight Navy 그라디언트 + 하단 좌측 라운드 |
| 카드 배경 | White | `AppColors.surface` (#0F172A) |
| 카드 테두리 | Gray-100 | `AppColors.surfaceElevated` |
| 별점 시스템 | 4.8 (숫자) | 등급 배지 (S/A/B/C + 리뷰수) |
| 등급 배지 | 단일 Slate-900 | 등급별 색상 차등 (S=Gold, A=Blue, B=Sky, C=Slate) |
| 선택된 카테고리 | Slate-900 배경 | `AppColors.primaryBright` 배경 + 글로우 |
| 하단 네비 배경 | White | `AppColors.surface` |
| 중앙 FAB | Navy 그라디언트 | Electric Blue 그라디언트 (Qradar 포커스 강화) |
| 탭 라벨 "주문내역" | 그대로 | **"Log"** (Qradar 용어) |

---

## 자율 결정 사항 요약 (사용자 확인 요망)

사용자 부재 중 내린 결정들. 돌아와서 수정 의견 있으면 반영:

1. **별점 → 등급 배지 통합**: 매장 카드에서 별점(4.8) 제거, GradeBadge가 등급+리뷰수 통합 표시
2. **등급별 색상 차등**: S=Gold, A=Electric Blue, B=Sky, C=Slate — 품질 레이더 아이덴티티 강화
3. **중앙 FAB 색상**: Midnight Navy → Electric Blue 그라디언트 (다크 바탕에서 포커스)
4. **헤더 하단 라운드**: bottomLeft만 28px — Figma 원본의 독특한 비대칭 감성 유지
5. **카테고리 최소 1개 유지**: UX 일관성 (빈 필터 상태 방지)
6. **CoffeeCup 김 애니메이션 생략**: MVP 단순화, 기본 아이콘 사용
7. **카드 탭 액션**: 매장 상세 페이지는 이번 작업 범위 외이므로 SnackBar 안내
