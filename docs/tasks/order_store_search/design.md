# 주문하기 매장 검색 디자인 명세 (Phase 1)

## 참조한 Figma 디자인
- Figma 레퍼런스 없음. spec.md + Qradar 디자인 시스템 + 기존 홈 패턴(카테고리 칩, RecommendedStoreCard, GradeBadge) 재사용.

---

## 화면 구성

### OrderPage (셸)
- **레이아웃**: `Scaffold(fullscreenDialog)` + `AppBar` + `Column[TabBar, Expanded(TabBarView)]`
- **배경**: `AppColors.background`
- **SafeArea**: AppBar가 상단 safeArea 처리, body는 기본
- **표시 방식**: `Navigator.push(MaterialPageRoute(fullscreenDialog: true))` — 기존 scaffold_with_nav의 `_openOrder` 유지

#### 컴포넌트 목록

1. **AppBar**
   - 위젯: `AppBar`
   - 배경: `AppColors.background`
   - `elevation: 0`, `surfaceTintColor: Colors.transparent`
   - `centerTitle: false`
   - `leading`: `IconButton(Icons.close_rounded, size: 24, color: AppColors.textHeading)` — 탭 시 `Navigator.pop`
   - `title`: `Text('주문', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textHeading))`
   - `bottom`: TabBar (아래 참조)

2. **TabBar**
   - 위젯: `TabBar(controller: _tabController, tabs: [...])`
   - 배경: `AppColors.background`
   - `labelColor`: `AppColors.primary`
   - `unselectedLabelColor`: `AppColors.textMuted`
   - `indicatorColor`: `AppColors.primary`
   - `indicatorWeight: 2.5`
   - `indicatorSize: TabBarIndicatorSize.tab`
   - `dividerColor: AppColors.border`
   - `dividerHeight: 1`
   - `labelStyle`: `TextStyle(fontSize: 15, fontWeight: FontWeight.w700)`
   - `unselectedLabelStyle`: `TextStyle(fontSize: 15, fontWeight: FontWeight.w500)`
   - `splashFactory: NoSplash.splashFactory`, `overlayColor: WidgetStateProperty.all(Colors.transparent)` — 다크 프리미엄 감성
   - 탭 2개: `Tab(text: '매장 검색')`, `Tab(text: '지도 검색')`

3. **TabBarView** (body)
   - `children: [StoreListTab(), StoreMapPlaceholderTab()]`
   - `physics: NeverScrollableScrollPhysics()` — 스와이프 전환 비활성 (리스트 세로 스크롤과 충돌 방지)

---

### StoreListTab

- **레이아웃**: `Column`
- **배경**: `AppColors.background`

#### 컴포넌트 목록

1. **OrderSearchBar** (고정 상단)
   - 위젯: `Padding(EdgeInsets.fromLTRB(20, 16, 20, 0))` → `Container(TextField)`
   - 높이: 46
   - 배경: `AppColors.surfaceElevated`
   - 테두리: 기본 `AppColors.border` 1px, 포커스 `AppColors.primary` 1.5px
   - 라운드: 999 (pill)
   - `prefixIcon`: `Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted)`
   - `suffixIcon`: 입력 있을 때 `IconButton(Icons.close_rounded, size: 18, color: AppColors.textMuted)` — 탭 시 clear
   - hint: `'매장명을 검색하세요'`, `color: AppColors.textMuted`, `fontSize: 14`
   - 입력 텍스트: `color: AppColors.textBody`, `fontSize: 14`, `fontWeight: w500`
   - `contentPadding`: `EdgeInsets.symmetric(horizontal: 0, vertical: 12)`
   - `cursorColor: AppColors.primary`
   - debounce 250ms 이후 `orderSearchQueryProvider` 갱신

2. **GradeFilterChips** (고정, 검색창 아래)
   - 위젯: `Padding(EdgeInsets.fromLTRB(20, 12, 20, 4))` → `Row` (S/A/B/C 4개 균등)
   - 칩 개별 스펙 (카테고리 칩과 같은 패턴):
     - `AnimatedContainer(duration: 200ms, curve: easeInOut)`
     - padding: `EdgeInsets.symmetric(horizontal: 0, vertical: 8)` — `Expanded`로 폭 균등 분배
     - 선택: 배경 `AppColors.primary`, 테두리 없음, 텍스트 `AppColors.onPrimary` w700
     - 비선택: 배경 `AppColors.surfaceElevated`, 테두리 `AppColors.border` 1px, 텍스트 `AppColors.textBody` w600
     - 라운드: 999
     - 폰트: 13
     - 라벨: `grade.label` ('S급' / 'A급' / 'B급' / 'C급')
     - 칩 사이 간격: 8 (`SizedBox(width: 8)`)
   - 탭 동작: 토글. 최소 1개 유지 (마지막 1개 해제 시도 시 무시, 햅틱 피드백 없음).

3. **ResultCount** (보조 정보)
   - 위젯: `Padding(EdgeInsets.fromLTRB(20, 12, 20, 8))` → `Text`
   - 내용: `'검색 결과 ${count}곳'` (data 상태일 때만 표시, 로딩/에러 시 숨김)
   - 스타일: `fontSize: 12, fontWeight: w500, color: AppColors.textMuted`

4. **StoreListView** (Expanded)
   - 위젯: `RefreshIndicator` → `ListView.separated`
   - `color: AppColors.primary`, `backgroundColor: AppColors.surfaceElevated`
   - padding: `EdgeInsets.fromLTRB(20, 4, 20, 24)`
   - separator: `SizedBox(height: 12)`
   - 각 아이템: `RecommendedStoreCard(store, onTap: () => _showComingSoon)` (기존 공통 위젯 그대로)
   - `physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())` — 결과 없어도 당겨서 refresh 가능

---

### StoreMapPlaceholderTab

- **레이아웃**: `Center` + `Column`
- **배경**: `AppColors.background`

#### 컴포넌트 목록
1. **Icon**
   - `Icons.map_outlined`, size 72, color `AppColors.textMuted`
2. **Title**
   - `'지도 검색 준비 중입니다'`, `fontSize: 16`, `fontWeight: w700`, `color: AppColors.textHeading`
   - 아이콘 아래 `SizedBox(height: 20)` 간격
3. **Subtitle**
   - `'곧 만나볼 수 있어요'`, `fontSize: 13`, `fontWeight: w500`, `color: AppColors.textMuted`
   - 타이틀 아래 `SizedBox(height: 6)` 간격

---

## 인터랙션

| 동작 | 반응 |
|------|------|
| ✕ 버튼 탭 | `Navigator.pop(context)` |
| 탭 전환 | `TabBarView` 애니메이션 기본값 (약 300ms slide) |
| 검색어 입력 | 250ms debounce → `orderSearchQueryProvider` 갱신 → 즉시 리스트 재필터 |
| 검색어 clear 버튼 | 입력창 비우고 provider 갱신 |
| 등급 칩 토글 | `AnimatedContainer` 200ms 배경/텍스트 색 전환 + `orderGradeFilterProvider` 갱신 |
| 카드 탭 | "준비 중입니다" 스낵바 (기존 home 패턴과 동일) |
| Pull-to-refresh | `ref.invalidate(orderBaseStoresProvider)` → 재조회 |

---

## 상태별 UI

### 로딩 (초기 로딩 + 새로고침 초기 상태)
- `ListView` 자리에 `_ListLoading` (`presentation/customer/order/widgets/` 내에 정의)
- 내용: 4개의 shimmer 카드
- 개별 shimmer:
  - `Shimmer.fromColors(baseColor: AppColors.surface, highlightColor: AppColors.surfaceElevated)`
  - `Container(height: 96, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)))`
  - 간격 12
- 패딩: `EdgeInsets.fromLTRB(20, 4, 20, 24)`
- ResultCount는 숨김

### 에러
- 중앙 정렬 `Column`:
  - `Icon(Icons.error_outline, size: 40, color: AppColors.error)`
  - `SizedBox(height: 12)`
  - `'매장 정보를 불러올 수 없어요'` — w700, 14, `textHeading`
  - `SizedBox(height: 6)`
  - 에러 상세 메시지 — 12, `textMuted`, 중앙 정렬
  - `SizedBox(height: 16)`
  - `ElevatedButton('다시 시도')` — 배경 `primary`, 텍스트 `onPrimary`, 라운드 12, padding `h20 v10`
- 탭 시 `ref.invalidate(orderBaseStoresProvider)`

### 빈 상태

**빈 상태 A — 검색/필터 결과 없음** (base 결과는 있으나 필터 통과 0)
- 중앙 정렬 `Column`:
  - `Icon(Icons.search_off_rounded, size: 40, color: AppColors.textMuted)`
  - `SizedBox(height: 12)`
  - 조건에 따라 텍스트:
    - 검색어 있음: `"'${query}'에 해당하는 매장이 없어요"` — 13, `textBody`, w500
    - 검색어 없음 (등급 필터만): `'선택한 등급에 해당하는 매장이 없어요'` — 13, `textBody`, w500

**빈 상태 B — 주변 매장 없음** (base 결과 0)
- 중앙 정렬 `Column`:
  - `Icon(Icons.storefront_outlined, size: 40, color: AppColors.textMuted)`
  - `SizedBox(height: 12)`
  - `'주변 10km 이내에 매장이 없어요'` — 13, `textBody`, w500
  - `SizedBox(height: 6)`
  - `'위치를 이동해서 다시 시도해보세요'` — 12, `textMuted`

---

## Figma 대비 변경사항
- Figma 참조 없음. 전반적으로 Qradar 라이트 미드나잇 아이덴티티 적용:
  - 다크 그라디언트 대신 흰 캔버스 유지 (홈 헤더 블록과 구분된 fullscreenDialog 컨텍스트)
  - 모든 색상 `AppColors` 토큰 사용
  - 검색창은 홈 헤더의 `_HomeSearchBox`와 시각 톤 일치시키되 실제 입력 가능
  - 등급 필터는 카테고리 필터 칩 UX 재사용 → 일관된 토글 경험

---

## 공통 컴포넌트 재사용 정리
| 기존 컴포넌트 | 사용처 |
|---|---|
| `RecommendedStoreCard` (`home/widgets/store_card.dart`) | 리스트 탭 카드 |
| `GradeBadge` (`home/widgets/grade_badge.dart`) | RecommendedStoreCard 내부 — 자동 반영 |
| `DistanceCalculator.formatKm` | 카드 거리 표시 — 자동 반영 |

---

## 개발자 전달 특이사항
- **debounce 구현**: `order_search_bar.dart` 내부에서 `Timer(Duration(milliseconds: 250))` 사용, `dispose`에서 cancel. Provider 갱신은 debounce 이후 한 번만.
- **TextField controller**: 로컬 controller 사용. clear 버튼 탭 시 controller.clear() + provider 갱신.
- **TabBar 탭 인덱스 유지**: `TabController(length: 2, vsync: this)` — StatefulWidget 필수.
- **리스트 카드 탭 동작**: 현재 "준비 중" 스낵바. 차후 매장 상세 화면으로 이동하도록 `onTap` 인자만 교체 예정.
- **검색 결과 카운트**: `orderStoresProvider`의 data 결과 length. 로딩/에러 중엔 숨김.
- **빈 상태 구분**: base 결과 length==0 vs 필터 후 length==0 판단 필요 — provider에서 flag 노출하거나 tab에서 base/filtered 둘 다 watch.
- **AppColors 외 하드코딩 색상 없음** (필수).
- **키보드 외부 탭 시 포커스 해제**: `GestureDetector(onTap: () => FocusScope.of(context).unfocus(), behavior: HitTestBehavior.opaque)`로 TabBarView 래핑 권장.
