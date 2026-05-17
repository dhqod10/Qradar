# 주문하기 매장 검색 기능 명세 (Phase 1 — 리스트 탭)

## 개요
- **목적**: 주문 FAB로 열리는 주문 화면을 2탭 구성으로 재작성. 본 task(Phase 1)에서는 **리스트 탭(매장 검색)**을 완성한다. 지도 탭은 TabBar 자리만 확보하고 placeholder로 유지하며, 후속 task(`order_store_map`)에서 Kakao Map으로 구현한다.
- **영향 범위**:
  - 전면 재작성: `lib/presentation/customer/order/order_page.dart` (기존 placeholder)
  - 신규 폴더: `lib/presentation/customer/order/{providers,tabs,widgets}/`
  - 도메인/데이터 레이어: **변경 없음** (기존 `StoreEntity`, `StoreRepository.getNearbyStores` 재사용)
  - 지도용 네이티브/패키지 설정: **없음** (후속 task로 이관)

---

## 요구사항

### 공통 (OrderPage 셸)
- [ ] 상단 TabBar — "매장 검색" / "지도 검색" 2개 탭
- [ ] 지도 탭은 placeholder 위젯 ("지도 준비 중입니다" + 아이콘)
- [ ] FAB로 열리는 fullscreenDialog 동작 유지
- [ ] 좌상단 닫기 버튼(✕)
- [ ] 위치 권한 미확정 상태에서도 폴백 위치(서울 시청) 기반 동작 (기존 `userLocationProvider` 재사용)

### 탭 1 — 매장 검색 (리스트)
- [ ] 상단 고정: 매장명 검색창 (placeholder "매장명을 검색하세요")
- [ ] 검색창 아래: 등급 필터 칩 (S / A / B / C 다중 선택, 기본 **전체 선택**, 최소 1개 유지)
- [ ] 하단: 세로 매장 카드 리스트 (거리 오름차순)
- [ ] 카드: 기존 `RecommendedStoreCard` 재사용
- [ ] 카드 탭 → 임시로 "준비 중" 스낵바 (매장 상세 화면은 별도 task)
- [ ] 로딩(shimmer) / 에러(재시도) / 빈 상태 UI
- [ ] 검색어 입력 시 debounce 250ms 후 반영
- [ ] pull-to-refresh 재조회

### 탭 2 — 지도 검색 (placeholder)
- [ ] placeholder 화면: 중앙 아이콘 + "지도 검색 준비 중입니다" 문구
- [ ] 후속 task 에서 Kakao Map으로 대체

---

## 데이터 모델

### Entity
변경 없음. 기존 `StoreEntity` 그대로.

### DTO
변경 없음.

---

## 레이어 설계

### Domain
**변경 없음.** 재사용:
- `StoreEntity`, `StoreGrade`, `UserLocation`
- `StoreRepository.getNearbyStores(location, radiusKm, limit)`
- `GetNearbyStoresUseCase`

### Data
**변경 없음.**

### Presentation

**Page / Tab**
- `lib/presentation/customer/order/order_page.dart` — TabBar 셸 (전면 재작성)
- `lib/presentation/customer/order/tabs/store_list_tab.dart`
- `lib/presentation/customer/order/tabs/store_map_placeholder_tab.dart`

**Widgets**
- `lib/presentation/customer/order/widgets/order_search_bar.dart` — 이름 검색 입력창
- `lib/presentation/customer/order/widgets/grade_filter_chips.dart` — S/A/B/C 토글 칩
- 카드 재사용: `presentation/customer/home/widgets/store_card.dart` 의 `RecommendedStoreCard`

**Providers (Riverpod) — 신규**
- `lib/presentation/customer/order/providers/order_providers.dart`
  - `orderSearchQueryProvider` — `NotifierProvider<String>`, 입력창과 바인딩 (debounce는 UI 레벨 처리)
  - `orderGradeFilterProvider` — `NotifierProvider<Set<StoreGrade>>`, 기본 `{S,A,B,C}`, 최소 1개 유지
  - `orderBaseStoresProvider` — `FutureProvider<List<StoreEntity>>` — `getNearbyStores(radius: 10km, limit: 50)` 호출
  - `orderStoresProvider` — `Provider<AsyncValue<List<StoreEntity>>>` — base 결과에 query + grade 클라이언트 필터 적용, 거리 오름차순 정렬

**Core**
- `lib/core/constants/grade_thresholds.dart` 에 `orderRadiusKm = 10.0`, `orderStoresLimit = 50` 추가

---

## 데이터 흐름

```
OrderPage 진입
  ↓
orderBaseStoresProvider
  → getNearbyStoresUseCase(userLocationProvider, 10km, 50)
  → StoreRepository → Firestore
  ↓
orderStoresProvider (파생)
  → orderBaseStoresProvider + orderSearchQueryProvider + orderGradeFilterProvider
  → 메모리 필터링 (name contains, grade in set) + 거리 정렬
  ↓
store_list_tab: ListView.builder

검색어 입력 → debounce 250ms → orderSearchQueryProvider 갱신 → 재필터
등급 칩 토글 → orderGradeFilterProvider 갱신 → 재필터
pull-to-refresh → orderBaseStoresProvider invalidate
```

---

## 에러 처리

| 케이스 | 처리 |
|--------|------|
| 위치 권한 거부/미확정 | `userLocationProvider` 폴백(서울 시청) — 기존 동작 |
| Firestore 실패 | 에러 UI + 재시도 버튼 |
| 필터 결과 0개 | 빈 상태 ("조건에 맞는 매장이 없어요") |
| 전체 등급 해제 시도 | 최소 1개 유지 (카테고리 필터와 동일 패턴) |

---

## 후속 task

### `order_store_map` (Phase 2)
- Kakao Map 플러그인 도입 (`kakao_map_plugin` 또는 WebView 방식 검토)
- Kakao 개발자센터에서 지도 API 키 활성화
- `store_map_tab.dart` 구현 — 같은 `orderStoresProvider` 구독하여 마커 렌더링
- 마커 탭 → 하단 미니 카드 → "주문하기" 버튼
- 탭 간 필터 동기화는 이미 Phase 1 provider 구조로 확보됨

---

## 작업 분배 (Phase 1)

### designer (우선)
- OrderPage TabBar 디자인 (색상·인디케이터·탭 라벨, AppColors 기반)
- 검색 입력창 디자인 (홈 헤더 `_HomeSearchBox`와 톤 일치)
- 등급 필터 칩 디자인 (기존 `category_filter_section` 참고, 등급별 색상 반영)
- 리스트 상태 UI (shimmer 로딩·에러·빈 상태)
- 지도 탭 placeholder 디자인
- 산출물: `docs/tasks/order_store_search/design.md`

### developer (디자인 확정 후)
- `order_providers.dart` 작성 (4개 provider)
- `order_page.dart` 전면 재작성 (TabBar + fullscreenDialog 셸)
- `store_list_tab.dart`, `store_map_placeholder_tab.dart` 구현
- `order_search_bar.dart`, `grade_filter_chips.dart` 구현
- `grade_thresholds.dart` 상수 확장
- 산출물: 코드 + `docs/tasks/order_store_search/implementation.md`

### tester (구현 후)
- spec 기준 기능 검증
- design 기준 UI 검증
- 검색/필터 동작, 최소 1개 유지 규칙, 빈/에러/로딩 상태 검증
- 산출물: `docs/tasks/order_store_search/test_report.md`
