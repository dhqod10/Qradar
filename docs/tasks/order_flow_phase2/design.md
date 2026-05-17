# order_flow_phase2 디자인 명세 (홈 추천 섹션 3종 + 원클릭 재주문)

## 참조한 디자인

- Figma: 없음 (Qradar 디자인 시스템 + Phase 1 톤 재사용 기반 신규 설계)
- 기존 화면 톤:
  - `lib/presentation/customer/home/home_page.dart` — 홈 sliver 컴포지션
  - `lib/presentation/customer/home/widgets/nearby_stores_section.dart` — 섹션 헤더 + 가로 스크롤 + loading/error/empty 패턴
  - `lib/presentation/customer/home/widgets/recommended_stores_section.dart` — `SectionTitle.trailing` 패턴
  - `lib/presentation/customer/home/widgets/store_card.dart` — `_cardDecoration()`, `NearbyStoreCard` (가로형), `RecommendedStoreCard` (가로 리스트형), `_StoreImage`
  - `lib/presentation/customer/order/cart_page.dart` (Phase 1b) — `_confirmReplaceCart` 톤
- 참고 컴포넌트:
  - `SectionTitle` (재사용)
  - `_cardDecoration()` 패턴 (재사용)
  - `_StoreImage` placeholder/shimmer 패턴 (메뉴 이미지에 응용)
  - `PriceFormatter.formatKrw` (총액 표기)
  - `Shimmer.fromColors` (loading)

---

## 화면 구성

### A. HomePage (수정)

- 라우트: 기존 (`/`)
- 레이아웃: 기존 `CustomScrollView` 유지. **Phase 2 는 sliver 3개를 `NearbyStoresSection` 위(=상단 spacer 바로 아래)에 추가** 한다.
- 배경: `AppColors.background` (변경 없음)
- SafeArea / Scroll: 변경 없음
- 추가 sliver 순서 (위→아래):
  1. `SliverToBoxAdapter(SizedBox(height: 48))` *(기존, 변경 없음)*
  2. **신규** `SliverToBoxAdapter(QuickReorderSection())` — "다시 주문하기"
  3. **신규** `SliverToBoxAdapter(SizedBox(height: 24))`
  4. **신규** `SliverToBoxAdapter(FrequentStoresSection())` — "자주 찾는 매장"
  5. **신규** `SliverToBoxAdapter(SizedBox(height: 24))`
  6. **신규** `SliverToBoxAdapter(FrequentMenuItemsSection())` — "자주 찾는 메뉴"
  7. **신규** `SliverToBoxAdapter(SizedBox(height: 24))`
  8. `SliverToBoxAdapter(NearbyStoresSection())` *(기존, 위치 변경 없음)*
  9. ... *이하 기존 그대로*

#### 섹션 가시성 분기 (결정 G)

- 각 섹션 위젯은 자체적으로 `Stream<List<...>>` 결과를 본다.
  - data 가 비어 있으면 위젯 build 결과가 `SizedBox.shrink()` (높이 0). 위/아래 24px spacer 도 같이 0 으로 변환되도록 조건부로 작성 (개발자 메모 참조).
- 모든 추천 섹션이 hidden → 홈 상단 첫 화면 요소는 자연스럽게 `NearbyStoresSection` 이 됨.

---

## 컴포넌트 목록

### 1. SectionTitle (재사용)

- 역할: Phase 2 섹션 헤더 3종 (`다시 주문하기` / `자주 찾는 매장` / `자주 찾는 메뉴`) 의 시각 톤 일관성을 보장.
- 위젯 구조: 기존 `SectionTitle(title, trailing?)` 그대로 재사용.
- 재사용 근거: `NearbyStoresSection` / `RecommendedStoresSection` 이 동일 위젯을 사용. 폰트/패딩/높이 톤 통일.
- Phase 2 적용:
  - QuickReorderSection: `SectionTitle(title: '다시 주문하기')` — trailing 없음
  - FrequentStoresSection: `SectionTitle(title: '자주 찾는 매장')` — trailing 없음
  - FrequentMenuItemsSection: `SectionTitle(title: '자주 찾는 메뉴')` — trailing 없음
- "더보기" 액션 미부여 사유: 본 phase 비범위 (검색/필터/전용 페이지 없음). 후속 phase 에서 추가.

---

### 2. QuickReorderSection ("다시 주문하기")

- 역할: 가장 최근 OrderLog 1~3건을 가로 스크롤로 노출. 카드 탭 → 즉시 카트 채움 + CartPage push.
- 데이터: `quickReorderCandidatesProvider` (`StreamProvider<List<QuickReorderCandidateEntity>>`)
- 위젯 구조:
  ```
  Column(crossAxisAlignment: start)
  ├─ SectionTitle(title: '다시 주문하기')
  └─ SizedBox(height: 196,
       child: stores.when(data, loading, error))
  ```
- 가시성: `data.isEmpty` 시 `SizedBox.shrink()` (Section 자체 미렌더). 비로그인 시 stream `[]` → 동일 처리.
- 가로 스크롤 ListView:
  - `scrollDirection: Axis.horizontal`
  - `padding: EdgeInsets.symmetric(horizontal: 20)`
  - `separator: SizedBox(width: 12)`
  - `itemCount: candidates.length` (max 3, UseCase 가 제한)
- 카드 너비: 고정 240 (메뉴 카드보다 정보량이 많아 넓게). NearbyStoreCard(width clamp 140~180) 와 시각적 차별.
- 카드 높이: 196 (위 SizedBox 높이 = ListView 높이)

#### 2-1. QuickReorderCard

- 역할: OrderLog 1건을 카드 1개로 표현 (매장 + 메뉴 요약 + 총액 + 시간 + CTA).
- 위젯 구조:
  ```
  GestureDetector
  └─ Container (cardDecoration, width 240, height 196)
     └─ Padding(EdgeInsets.fromLTRB(16, 14, 16, 14))
        └─ Column(crossAxisAlignment: start)
           ├─ Row (매장 아이콘 + 매장명)
           ├─ SizedBox(height: 6)
           ├─ Text (paidAt 상대시간)
           ├─ SizedBox(height: 12)
           ├─ Container 구분선 (border 1px, vertical 8 padding)
           ├─ Text (메뉴 요약 "아메리카노 외 1")
           ├─ SizedBox(height: 8)
           ├─ Text (총액)
           ├─ Spacer()
           └─ "다시 주문" CTA pill
  ```
- 카드 데코: `_cardDecoration()` 패턴 재사용 (배경 `surfaceElevated`, border `border` 1px, radius 16, shadow `primary` α0.04 blur 8 offset(0,2))
- 매장명 행:
  - `Icons.storefront_outlined` size 14 color `AppColors.primary`
  - SizedBox(width: 6)
  - `Expanded(Text(storeName, fontSize 14, w700, AppColors.textHeading, maxLines 1, ellipsis))`
- paidAt 상대시간:
  - fontSize 12, w500, `AppColors.textMuted`
  - 포맷 (개발자 helper 권장):
    - `< 24h`: "오늘"
    - `< 48h`: "어제"
    - `< 7d`: "{n}일 전"
    - `< 30d`: "{n}주 전"
    - 그 외: `"yyyy.MM.dd"` (Locale ko)
- 구분선: `Container(height: 1, color: AppColors.border)` (vertical margin 8)
- 메뉴 요약:
  - fontSize 13, w600, `AppColors.textBody`
  - maxLines 2, ellipsis
  - 포맷: 첫 메뉴명 + 추가 항목수 → `"아메리카노 외 1"` / 단일 항목이면 `"아메리카노"`
  - 옵션 라벨은 표기 안 함 (공간 부족, 카트 진입 후 확인)
- 총액:
  - fontSize 16, w800, `AppColors.primary`
  - 포맷: `PriceFormatter.formatKrw(total)`
- "다시 주문" CTA pill (카드 하단):
  - 위젯: 카드 자체 GestureDetector 가 처리. 추가로 시각적 affordance 로 pill 텍스트만 표시 (별도 onTap 없음)
  - 구조: `Align(alignment: centerRight, child: Container)`
  - Container:
    - decoration: `color: AppColors.primary.withValues(alpha: 0.10)`, `borderRadius: 999`
    - padding: `EdgeInsets.symmetric(horizontal: 12, vertical: 6)`
  - Row 자식:
    - `Icon(Icons.refresh_rounded, size: 14, color: AppColors.primary)`
    - SizedBox(width: 4)
    - `Text('다시 주문', fontSize 12, w700, color: AppColors.primary)`
- 상태:
  - default: 위 데코 그대로
  - pressed: GestureDetector 의 splash 미적용 (Container 라). 별도 InkWell wrapping 없이 진행 — 톤 통일 (기존 NearbyStoreCard 와 동일하게 ripple 없음)
  - disabled: 본 phase 에서 노출 시 항상 활성. 매장/메뉴 삭제 검증은 진입 후 처리 (spec).
- 인터랙션:
  - 카드 전체 `onTap`:
    1. `cartProvider` 활성 카트의 `storeId` 와 OrderLog `storeId` 비교
    2. 다르면 `showReplaceCartDialog(BuildContext)` 호출 (개발자 메모: Phase 1b `_confirmReplaceCart` 를 cart 영역 공통 헬퍼로 추출 권장)
       - 사용자 "비우고 시작" → 다음 단계 진행
       - 사용자 "취소" → 종료 (busy state 도 false)
    3. `cartRepository.replaceCart(items: log.items)` (또는 `clearCart` + 반복 `addItem`. 개발자 결정)
    4. `Navigator.push(MaterialPageRoute(builder: (_) => CartPage()))`
  - 진행 중 시각 피드백: 카드 자체 spinner 는 노출하지 않음 (조작이 즉시 끝남). `replaceCart` 가 비동기 실패하면 SnackBar `'다시 주문에 실패했어요. 잠시 후 다시 시도해주세요'` (`AppColors.error` 톤 SnackBar 미사용 — 기본 SnackBar 톤)

---

### 3. FrequentStoresSection ("자주 찾는 매장")

- 역할: 빈도 + 즐겨찾기 boost 기반 상위 매장 가로 스크롤 노출.
- 데이터: `frequentStoresProvider` (`StreamProvider<List<FrequentStoreEntity>>`)
- 위젯 구조:
  ```
  Column(crossAxisAlignment: start)
  ├─ SectionTitle(title: '자주 찾는 매장')
  └─ SizedBox(height: 200, child: stores.when(...))
  ```
- 가시성: `data.isEmpty` → `SizedBox.shrink()`
- 노출 max 갯수: **5개** (UseCase 측에서 `take(5)`)
- 가로 스크롤 vs 세로 리스트: **가로 스크롤** 채택
  - 사유: `NearbyStoresSection` 과 시각 톤 통일 (둘 다 카드형 매장). `RecommendedStoresSection` 의 가로 리스트는 등급/거리 등 정보가 풍부한 1차 추천 — Phase 2 의 "자주 찾는 매장" 은 빠른 진입이 목적이므로 가로 카드 형태가 적합.
- 가로 스크롤 ListView 파라미터: NearbyStoresSection 와 동일 패턴
  - padding: `EdgeInsets.symmetric(horizontal: 20)`
  - separator: `SizedBox(width: 12)`

#### 3-1. FrequentStoreCard

- 역할: 매장 1건 표시. **`NearbyStoreCard` 재사용 권장 — 단, visitCount 라벨이 필요해 가벼운 변형 필요**.
- 권장 구현 방식: `NearbyStoreCard` 를 재사용하지 않고 신규 `FrequentStoreCard` 작성. 카드 데코 / 이미지 / 매장명 / 거리 부분은 동일 톤이지만 거리 영역 자리에 visitCount 라벨을 노출.
- 위젯 구조:
  ```
  GestureDetector
  └─ Container (cardDecoration, width clamp 140~180)
     └─ Column(crossAxisAlignment: start)
        ├─ Stack (이미지 + 등급 뱃지 + visitCount 뱃지)
        └─ Padding (이름 + visitCount 라벨)
  ```
- 카드 너비: `MediaQuery.size.width * 0.4` clamp 140~180 (NearbyStoreCard 와 동일)
- 카드 데코: `_cardDecoration()` 재사용
- 이미지 영역: 높이 112, `_StoreImage(store.imageUrl)` 패턴 재사용. radius `BorderRadius.only(topLeft: 16, topRight: 16)`
- 등급 뱃지: `GradeBadge(grade, reviewCount)` — `Positioned(top: 8, right: 8)` (NearbyStoreCard 동일)
- **visitCount 뱃지** (이미지 좌상단):
  - `Positioned(top: 8, left: 8)`
  - Container:
    - decoration: `color: AppColors.textHeading.withValues(alpha: 0.78)`, `borderRadius: 999`
    - padding: `EdgeInsets.symmetric(horizontal: 8, vertical: 4)`
  - Row 자식:
    - `Icon(Icons.repeat_rounded, size: 11, color: AppColors.onPrimary)`
    - SizedBox(width: 4)
    - `Text('${visitCount}회', fontSize 11, w700, color: AppColors.onPrimary)`
  - 노출 조건: `visitCount > 0`. visitCount = 0 (즐겨찾기 boost 단독) 인 경우는 결정 F 임계값 미달이라 노출 자체가 없음.
- Padding `EdgeInsets.all(12)` Column:
  - 매장명: `fontSize 14, w700, AppColors.textHeading, maxLines 1, ellipsis`
  - SizedBox(height: 6)
  - visitCount 라벨 (텍스트 형태):
    - Row:
      - `Icon(Icons.history_rounded, size: 12, color: AppColors.textMuted)`
      - SizedBox(width: 4)
      - `Text('최근 ${visitCount}회 방문', fontSize 12, w500, AppColors.textMuted)`
    - 즐겨찾기인데 visitCount=0 인 경우는 임계값 미달로 노출 안 됨 (결정 F 잠정안). 따라서 본 라벨은 항상 visitCount ≥ 1.
- 인터랙션:
  - 카드 `onTap` → `Navigator.push(MaterialPageRoute(builder: (_) => StoreMenuPage(store: ...)))`
  - 매장 entity 가 즐겨찾기/카트 등에서 가져온 데이터인지 (StoreEntity 가 필요) → 개발자 메모: `FrequentStoreEntity` 가 `storeId`, `storeName` 만 갖고 있다면 진입 시 `getStoreByIdProvider` 가 필요할 수 있음. 아니면 `StoreMenuPage(storeId: ...)` 형태로 변경하거나, UseCase 가 `StoreEntity` 를 함께 반환하도록 한다.

---

### 4. FrequentMenuItemsSection ("자주 찾는 메뉴")

- 역할: 매장-메뉴 페어 빈도 + 즐겨찾기 boost 기반 상위 메뉴 가로 스크롤.
- 데이터: `frequentMenuItemsProvider` (`StreamProvider<List<FrequentMenuItemEntity>>`)
- 위젯 구조:
  ```
  Column(crossAxisAlignment: start)
  ├─ SectionTitle(title: '자주 찾는 메뉴')
  └─ SizedBox(height: 220, child: items.when(...))
  ```
- 가시성: `data.isEmpty` → `SizedBox.shrink()`
- 노출 max 갯수: **5개** (UseCase 측 `take(5)`)
- 가로 스크롤 ListView:
  - padding: `EdgeInsets.symmetric(horizontal: 20)`
  - separator: `SizedBox(width: 12)`

#### 4-1. FrequentMenuCard

- 역할: 매장-메뉴 페어 1건 표시. 메뉴 카드 톤이지만 매장명 정보가 추가됨.
- 위젯 구조:
  ```
  GestureDetector
  └─ Container (cardDecoration, width clamp 140~180, height ~ 220)
     └─ Column(crossAxisAlignment: start)
        ├─ Stack (이미지 + orderCount 뱃지)
        └─ Padding (메뉴명 + 매장명 + 가격)
  ```
- 카드 너비: `MediaQuery.size.width * 0.4` clamp 140~180
- 카드 데코: `_cardDecoration()` 재사용
- 이미지 영역:
  - 정사각 (카드 너비와 동일)
  - radius: `BorderRadius.only(topLeft: 16, topRight: 16)`
  - `CachedNetworkImage(menuItem.imageUrl)` + fallback `AppColors.surface` + `Icons.local_cafe_outlined` (size 28, `AppColors.textMuted`) — Phase 1a 메뉴 카드 fallback 일관
- **orderCount 뱃지** (이미지 좌상단):
  - `Positioned(top: 8, left: 8)`
  - 동일 톤 (자주 찾는 매장 visitCount 뱃지와 동일 디자인)
  - Row 자식:
    - `Icon(Icons.repeat_rounded, size: 11, color: AppColors.onPrimary)`
    - SizedBox(width: 4)
    - `Text('${orderCount}회', fontSize 11, w700, color: AppColors.onPrimary)`
  - 노출 조건: `orderCount > 0`
- Padding `EdgeInsets.fromLTRB(12, 10, 12, 12)` Column:
  - 메뉴명: `fontSize 14, w700, AppColors.textHeading, maxLines 1, ellipsis`
  - SizedBox(height: 4)
  - 매장명: `fontSize 12, w500, AppColors.textMuted, maxLines 1, ellipsis`
  - SizedBox(height: 8)
  - "최근 N회 주문" 라벨:
    - Row:
      - `Icon(Icons.history_rounded, size: 12, color: AppColors.textMuted)`
      - SizedBox(width: 4)
      - `Text('최근 ${orderCount}회 주문', fontSize 12, w500, AppColors.textMuted)`
  - SizedBox(height: 6)
  - 가격: `fontSize 13, w700, AppColors.primary, PriceFormatter.formatKrw(basePrice)`
  - basePrice 가 entity 에 없다면 UseCase 측에서 채워 넣어야 함 (개발자 메모)
- 인터랙션:
  - 카드 `onTap` → `Navigator.push(MaterialPageRoute(builder: (_) => StoreMenuPage(storeId: ...)))` 후 추가 자동 navigation 없이 종료.
  - 자동으로 `MenuItemDetailPage` 까지 진입시키지 않는 사유:
    1. 본 phase 비범위 (Phase 1a 의 `MenuItemDetailPage` 진입 인자는 menuItemId + storeId — 직접 push 가능하나, 매장 메뉴 컨텍스트 (장바구니 뱃지/매장 헤더) 가 자연스럽게 빠짐).
    2. 메뉴 상세 직진은 사용자 입장에서 "방금 본 매장 화면을 건너뛰고 바로 옵션 화면" 인데, 옵션을 다시 고를 의도가 분명한 경우 "다시 주문" 카드를 쓰면 됨. "자주 찾는 메뉴" 는 탐색 진입.
  - 결정 정리: **카드 탭 → StoreMenuPage(storeId) push 만**. 메뉴 상세 자동 open 은 안 함.
  - 대안 (만약 사용자가 메뉴 상세 직진을 원한다면): StoreMenuPage 에 `initialMenuItemId` 파라미터를 추가하거나 push 후 `Future.microtask` 로 `MenuItemDetailPage` push. 본 design.md 는 사용자 확인 항목으로 남김.

---

### 5. 매장 충돌 다이얼로그 (재사용)

- 사용처: QuickReorderCard `onTap`
- 위젯: Phase 1b `_confirmReplaceCart` AlertDialog 톤 그대로 재사용. 변경 없음.
- 디자인 (Phase 1b 와 동일):
  - shape: `RoundedRectangleBorder(borderRadius: 16)`
  - backgroundColor: `AppColors.surfaceElevated`
  - title: `'기존 카트를 비울까요?'` (16, w700, `textHeading`)
  - content: `'다른 매장의 카트가 있어요.\n비우고 새 매장으로 시작할까요?'` (13, w500, `textBody`)
  - actions:
    - `'취소'` TextButton — color `AppColors.textMuted`, w600 14
    - `'비우고 시작'` TextButton — color `AppColors.error`, w700 14
- 개발자 메모: Phase 1b `_confirmReplaceCart` 가 `cart_page.dart` 내부 private 함수일 가능성이 높음. **공통 헬퍼 `showReplaceCartDialog(BuildContext) → Future<bool>` 로 추출 권장** (위치: `lib/presentation/customer/order/cart/widgets/replace_cart_dialog.dart` 또는 `lib/presentation/customer/order/cart/cart_dialogs.dart`). 추출 후 Phase 1b 호출부도 헬퍼를 사용하도록 교체.

---

## 인터랙션

| 동작 | 반응 |
|---|---|
| QuickReorderCard 탭 (매장 일치 / 카트 없음) | `cartRepository.replaceCart(items)` → `CartPage` push |
| QuickReorderCard 탭 (매장 충돌) | `showReplaceCartDialog` → 확인 시 replaceCart 후 `CartPage` push, 취소 시 종료 |
| QuickReorderCard 탭 (실패) | SnackBar `'다시 주문에 실패했어요. 잠시 후 다시 시도해주세요'` |
| FrequentStoreCard 탭 | `Navigator.push(StoreMenuPage(...))` |
| FrequentMenuCard 탭 | `Navigator.push(StoreMenuPage(storeId))` (메뉴 상세 직진 X — 결정 사항) |
| 가로 스크롤 (각 섹션) | iOS bouncing / Android overscroll glow (기본 platform) |
| pull-to-refresh (HomePage) | 기존 `_onRefresh` 가 nearbyStores / filteredStores 만 invalidate. 추천 섹션은 stream 이라 자동 갱신. |
| 비로그인 → 로그인 전환 | authProvider 가 emit → 모든 추천 stream 재구성 → 데이터 들어오는 순간 섹션 페이드인 (`AnimatedSwitcher` 권장, 200ms) |
| 로그아웃 | 기존 로직 유지 (LoginPage 로 pushAndRemoveUntil) |

---

## 상태별 UI

### Loading

각 섹션 첫 stream emit 전.

#### QuickReorderSection
- 표시 방식: shimmer 카드 2개 가로 스크롤 자리만 차지
- 컴포넌트 구조:
  ```
  ListView.separated(scrollDirection: Axis.horizontal, padding 20, separator 12, itemCount: 2)
  └─ Shimmer.fromColors(base: AppColors.surface, highlight: AppColors.surfaceElevated)
     └─ Container(width 240, height 196, color AppColors.surface, radius 16)
  ```
- 색상: shimmer base/highlight = `AppColors.surface` / `AppColors.surfaceElevated`

#### FrequentStoresSection
- 동일 패턴, 카드 너비 160 (clamp 중간값), 높이 200

#### FrequentMenuItemsSection
- 동일 패턴, 카드 너비 160, 높이 220

### Error

추천 섹션은 stream 에러 → **섹션 자체 숨김 + 콘솔 로그**. UI 충격 최소화 (spec 결정).

- 표시 방식: `error` 분기에서 `SizedBox.shrink()` 반환
- 문구: 없음 (사용자에게 안내 X)
- 재시도 여부: 자동 — provider 가 다시 listen 되면 stream 이 재구성됨. 사용자 트리거 없음.
- 콘솔 로그: `debugPrint('[QuickReorder] stream error: $e')` 등 (개발자 메모 — `assert` 모드만)

> 사유: 추천 섹션은 보조 영역. 에러로 빨간 상태를 보여주면 첫 진입 인상이 나빠짐. 주변 매장 / 카테고리 등 메인 UI 는 정상이므로 사용자 흐름이 끊기지 않음.

### Empty

- 표시 방식: 결정 G — 섹션 자체 숨김 (`SizedBox.shrink()`)
- 문구: 없음
- 다음 행동 안내: 없음 (empty 카드 / placeholder 둘 다 노출 X)
- 비로그인 / 로그인+OrderLog 0 모두 동일 분기

> 사유: empty 카드를 노출하면 빈 곳이 시각적 노이즈가 됨. 데이터가 쌓이면 점차 섹션이 자연스럽게 등장.

---

## Figma 대비 변경사항

| 항목 | spec / 잠정안 | Qradar 적용 |
|---|---|---|
| 색상 | (Figma 없음) | 전부 `AppColors` 토큰 |
| QuickReorderCard 너비 | spec 미정 | 240 고정 (정보량 많아 NearbyStoreCard 보다 넓게) |
| 자주 찾는 매장 가로/세로 | designer 결정 | 가로 스크롤 (NearbyStoresSection 톤 통일) |
| 자주 찾는 메뉴 가로/세로 | designer 결정 | 가로 스크롤 (Phase 1a 메뉴 그리드와 차별, 발견형 카드) |
| visitCount/orderCount 표기 | spec 라벨 형태 미정 | 이미지 좌상단 pill 뱃지 + 카드 본문 "최근 N회 방문" 텍스트 라벨 (이중 강조로 빈도 인지) |
| FrequentStoreCard 재사용 | "기존 StoreCard 재사용 가능성 검토" | **신규 작성 권장** — 데코/이미지/너비 톤은 동일하지만 visitCount 영역이 추가되어 거리 텍스트 자리를 대체. NearbyStoreCard 와 분리해 props 단순화. |
| 자주 찾는 메뉴 탭 후 직진 | "StoreMenuPage 진입 후 자동 메뉴 상세 open 또는 곧장 MenuItemDetailPage" | **StoreMenuPage 진입까지만**. 자동 메뉴 상세 open 은 본 phase 적용 X (사유: 매장 메뉴 컨텍스트 보존, 옵션 재선택 UX 분리) |
| 노출 max 갯수 | spec 권장 3~5 | 자주 찾는 매장/메뉴 = **5개**, 다시 주문 = **3개** (UseCase 단에서 `take`) |
| "다시 주문" CTA | spec "버튼 또는 카드 전체 탭" | 카드 전체 탭 + 시각적 affordance pill (별도 버튼 아님) |
| paidAt 상대시간 | spec 예시 그대로 | 4단계 분기 (오늘 / 어제 / N일 전 / N주 전 / 그 외 yyyy.MM.dd) |
| empty 카드 | spec 결정 G | placeholder 일체 없음 (섹션 숨김) |

---

## 개발자 전달 특이사항

### 구현 시 주의할 점

1. **섹션 자동 숨김 시 위/아래 spacer 동시 제거**:
   - 단순히 `SectionWidget` 이 `SizedBox.shrink()` 를 반환하면 OK.
   - 단, `SliverToBoxAdapter(SizedBox(height: 24))` spacer 들도 hidden 인 섹션 양쪽이면 같이 숨겨야 자연스러움. 권장 패턴: 섹션 위젯 안에 위/아래 spacer 를 함께 포함시켜 한 단위로 처리하거나, HomePage 에서 `Consumer` 로 추천 stream 들을 watch 해 sliver 리스트를 동적으로 구성.
   - 권장 방식: **각 섹션 위젯이 자기 위 24px spacer 를 포함**. 비어 있으면 `SizedBox.shrink()`. HomePage 에는 NearbyStoresSection 위에 별도 spacer 두지 않음.
2. **stream-driven UI**:
   - 모든 섹션은 `ref.watch(StreamProvider)` 결과를 본다. 캐시 X.
   - 비로그인 시 stream 이 `[]` 을 즉시 emit (UseCase 가 보장) → empty 분기 → `SizedBox.shrink()`.
3. **AnimatedSwitcher 적용 권장**:
   - 비로그인 → 로그인 전환 / 데이터 0 → 데이터 들어옴 시 섹션이 갑자기 튀어나오면 시각 충격이 있음. 각 섹션의 root 를 `AnimatedSwitcher(duration: 200ms, child: data.isEmpty ? SizedBox.shrink() : ContentColumn)` 로 감싸 페이드인.
   - 단, sliver 안에서 AnimatedSwitcher 사용 시 layout 재계산 비용 주의. SliverToBoxAdapter wrapping 자체는 OK.
4. **QuickReorderCard 의 카드 전체 탭과 pill affordance 분리**:
   - pill 은 시각 표현만. `IgnorePointer` 로 감싸 별도 탭 영역으로 잡히지 않게 해 주세요 (사용자가 pill 만 탭하면 GestureDetector 가 안 잡히는 영역이 생기지 않도록).
5. **paidAt 상대시간 helper 권장 위치**:
   - `lib/core/utils/relative_time_formatter.dart` (`RelativeTimeFormatter.formatKo(DateTime now, DateTime target)`).
   - 4월 28일 기준 paidAt = 4월 27일 → "어제", 4월 25일 → "3일 전", 4월 1일 → "4주 전".
6. **FrequentStoreCard 가 StoreEntity 가 아닌 FrequentStoreEntity 만 받음**:
   - `StoreMenuPage(store: ...)` 가 StoreEntity 를 요구하면 (Phase 1a 코드 확인 결과 `StoreMenuPage({required StoreEntity store})` ) 어댑터가 필요.
   - 옵션 A: UseCase 가 `FrequentStoreEntity` 안에 `StoreEntity` 를 함께 보유.
   - 옵션 B: 별도 `getStoreByIdProvider` 를 카드 onTap 안에서 호출. async 라 sync push 가 어려움 → 추천 X.
   - **권장: 옵션 A**. UseCase 측에서 매장 stream 과 합성해 `StoreEntity` 도 같이 넘긴다.
7. **FrequentMenuCard 의 imageUrl/basePrice 보강**:
   - `FrequentMenuItemEntity` 가 imageUrl / basePrice 를 갖지 않으면 UseCase 측에서 메뉴 stream 과 합성해 채워 넣어야 함.
   - 누락 시 imageUrl 은 빈 문자열 → fallback 아이콘으로 처리 (Phase 1a 패턴 동일).
8. **카드 너비 / 높이 고정값**:
   - QuickReorderCard width 240 / height 196 — 매장명 길이가 길어도 ellipsis. paidAt 라벨 폭은 가변.
   - FrequentStoreCard width clamp 140~180 / height 200 (이미지 112 + Padding 88).
   - FrequentMenuCard width clamp 140~180 / height 220 (이미지 = width / 정사각 + Padding 영역).
9. **`replaceCart` 다이얼로그 헬퍼화**:
   - `lib/presentation/customer/order/cart/widgets/replace_cart_dialog.dart` 로 추출.
   - 시그니처: `Future<bool> showReplaceCartDialog(BuildContext context)` (true = "비우고 시작", false/null = 취소).
   - Phase 1b 의 `_confirmReplaceCart` 도 동일 헬퍼를 사용하도록 교체 (중복 제거).
10. **QuickReorder 실패 SnackBar**:
    - 톤은 기존 placeholder SnackBar 와 동일 (Material 기본). Color override 없음. 기존 Phase 1b 의 `'담기에 실패했어요...'` 와 같은 메시지 톤.

### 재사용할 컴포넌트

- `SectionTitle` (그대로)
- `_cardDecoration()` (그대로 — 단, 현재 store_card.dart 안 private 이라면 위젯 파일 안에서 자체 복제 OK. 또는 `presentation/common/card_decoration.dart` 로 추출 권장)
- `_StoreImage` 패턴 (private — FrequentStoreCard 안에서 동일 패턴으로 작성. 위젯 추출은 선택)
- `GradeBadge` (FrequentStoreCard 에서 재사용)
- `Shimmer.fromColors` 패턴
- `PriceFormatter.formatKrw`
- Phase 1b `_confirmReplaceCart` AlertDialog (헬퍼화 후 재사용)

### 새로 만들어야 하는 컴포넌트

- `lib/presentation/customer/home/widgets/quick_reorder_section.dart`
  - `QuickReorderSection` (ConsumerWidget)
  - `QuickReorderCard` (private 또는 동일 파일 export)
  - loading / error / empty 분기 (loading 만 shimmer, error/empty = `SizedBox.shrink()`)
- `lib/presentation/customer/home/widgets/frequent_stores_section.dart`
  - `FrequentStoresSection`
  - `FrequentStoreCard`
- `lib/presentation/customer/home/widgets/frequent_menu_items_section.dart`
  - `FrequentMenuItemsSection`
  - `FrequentMenuCard`
- `lib/core/utils/relative_time_formatter.dart` (`RelativeTimeFormatter.formatKo`)
- `lib/presentation/customer/order/cart/widgets/replace_cart_dialog.dart` (Phase 1b 헬퍼화 + 본 phase 재사용)

### AppColors 토큰 정리

| 위치 | 토큰 |
|---|---|
| 카드 배경 | `AppColors.surfaceElevated` |
| 카드 border / 카드 내 구분선 | `AppColors.border` |
| 카드 shadow | `AppColors.primary` α0.04 |
| 매장명 / 메뉴명 (heading) | `AppColors.textHeading` |
| 본문 텍스트 (메뉴 요약 등) | `AppColors.textBody` |
| 보조 텍스트 (paidAt, 매장명 보조, 라벨) | `AppColors.textMuted` |
| 총액 / 가격 / "다시 주문" pill 텍스트 | `AppColors.primary` |
| "다시 주문" pill 배경 | `AppColors.primary` α0.10 |
| visitCount / orderCount 뱃지 배경 | `AppColors.textHeading` α0.78 |
| visitCount / orderCount 뱃지 텍스트/아이콘 | `AppColors.onPrimary` |
| 매장 아이콘 (storefront) | `AppColors.primary` |
| history 아이콘 | `AppColors.textMuted` |
| 메뉴 이미지 fallback bg | `AppColors.surface` |
| 메뉴 이미지 fallback 아이콘 | `AppColors.textMuted` |
| 매장 충돌 다이얼로그 actions | 취소 = `AppColors.textMuted`, 확정 = `AppColors.error` |
| shimmer base / highlight | `AppColors.surface` / `AppColors.surfaceElevated` |

### 애니메이션 수치

| 대상 | duration | curve |
|---|---|---|
| 섹션 페이드인 / 페이드아웃 (AnimatedSwitcher, 비로그인↔로그인) | 200ms | Curves.easeOut |
| 가로 스크롤 | (platform 기본) | (platform 기본) |
| 페이지 push (CartPage / StoreMenuPage) | (platform 기본) | (platform 기본) |
| 매장 충돌 다이얼로그 | (Material 기본) | (Material 기본) |
| SnackBar | (Material 기본) | (Material 기본) |

### 후속 작업 (Phase 2 완료 후)

- Figma 작업물이 나오면 본 design.md 의 카드 너비/높이/패딩 수치를 우선 검토.
- "더보기" / 전체 보기 페이지: 후속 phase 에서 `SectionTitle.trailing` 자리에 `TextButton('전체보기')` 추가.
- 추천 카드 dismiss / 관심 없음 UX: spec 비범위 (Phase 3 이후).
- 시간대별 추천 (출근 시간 ☕): 추후 phase.

### 명세에 없는 임의 추가 사항 (designer 결정)

- QuickReorderCard 카드 너비 240 (정보량 기준 designer 판단)
- 자주 찾는 매장/메뉴 가로 스크롤 + 5개 max (spec 권장 3~5 중 최대값 채택)
- visitCount / orderCount 시각화 = 이미지 좌상단 pill 뱃지 + 본문 "최근 N회" 라벨 이중 표기
- "다시 주문" pill = 시각 affordance 만 (별도 버튼 아님), 카드 전체 탭으로 처리
- paidAt 상대시간 4단계 분기 (오늘 / 어제 / N일 전 / N주 전 / 그 외 yyyy.MM.dd)
- "자주 찾는 메뉴" 카드 탭 후 메뉴 상세 자동 open 안 함 (StoreMenuPage 까지만) — **사용자 확인 필요 항목**
- error 시 섹션 숨김 (spec 의 "섹션 숨김 + 콘솔 로그" 적용)

---

## 사용자 확인 필요 항목

본 design.md 진행에서 사용자 의견이 필요한 1건:

1. **자주 찾는 메뉴 카드 탭 후 메뉴 상세 자동 open 여부**
   - 현재 design.md 결정: StoreMenuPage 까지만 진입.
   - 대안: StoreMenuPage push + 자동으로 MenuItemDetailPage push.
   - designer 판단 사유: 매장 메뉴 컨텍스트 (장바구니 뱃지 / 헤더) 보존이 자연스럽고, 옵션을 똑같이 다시 쓰고 싶다면 "다시 주문" 카드를 쓰면 됨.
   - 사용자가 메뉴 상세 직진을 원하면 spec 결정 H 영역으로 추가 합의 필요.
