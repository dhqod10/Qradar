# 주문하기 매장 검색 구현 내역 (Phase 1)

## 구현 파일 목록

### 신규
- `lib/presentation/customer/order/providers/order_providers.dart` — 4개 provider (query / grade filter / base / filtered)
- `lib/presentation/customer/order/widgets/order_search_bar.dart` — debounce 250ms TextField
- `lib/presentation/customer/order/widgets/grade_filter_chips.dart` — S/A/B/C 균등 분배 칩
- `lib/presentation/customer/order/tabs/store_list_tab.dart` — 검색창+필터+리스트 (data/loading/error/empty)
- `lib/presentation/customer/order/tabs/store_map_placeholder_tab.dart` — 지도 탭 placeholder

### 수정
- `lib/presentation/customer/order/order_page.dart` — 전면 재작성 (TabBar 셸)
- `lib/core/constants/grade_thresholds.dart` — `orderRadiusKm = 10.0`, `orderStoresLimit = 50` 추가

### 변경 없음 (재사용)
- `lib/domain/entities/store_entity.dart`, `store_grade.dart`
- `lib/domain/repositories/store_repository.dart`
- `lib/domain/usecases/get_nearby_stores_use_case.dart`
- `lib/data/**` — 그대로
- `lib/presentation/customer/home/widgets/store_card.dart` (`RecommendedStoreCard`)
- `lib/presentation/customer/home/widgets/grade_badge.dart`
- `lib/presentation/customer/home/providers/home_providers.dart` — `getNearbyStoresUseCaseProvider`, `userLocationProvider` 재사용

---

## 주요 결정사항

- **반경·개수 상한**: spec의 `10km / 50개`를 새 상수로 추가. 기존 `nearbyRadiusKm(20km)`은 홈 화면 전용으로 유지.
- **필터 방식**: 서버 쿼리 대신 **클라이언트 필터링**. `orderBaseStoresProvider`(Future)로 원본 로딩 → `orderStoresProvider`(derived)에서 query + grade 필터 + 거리순 정렬. 검색어/등급 변경 시 서버 재조회 없음 → 즉시 반영.
- **`orderStoresProvider` 타입**: `Provider<AsyncValue<List<StoreEntity>>>` — base의 loading/error 상태를 자연스럽게 전파. `AsyncValue.whenData` 사용.
- **debounce 구현 위치**: Provider가 아닌 `OrderSearchBar` 내부 `Timer`로 구현. Riverpod에 debounce 로직을 섞지 않기 위함. dispose에서 cancel.
- **TabBarView physics**: `NeverScrollableScrollPhysics` — 리스트 세로 스크롤과 스와이프 간섭 방지. 탭 전환은 탭 바 클릭으로만.
- **키보드 외부 탭 포커스 해제**: `StoreListTab` 전체를 `GestureDetector(onTap: FocusScope.unfocus)` 로 래핑.
- **빈 상태 분기 데이터 소스**: `_EmptyList`는 `query`와 `baseCount` 두 값을 받아 3가지 메시지로 분기 (base 0 / 검색어 있음 / 등급 필터만).
- **에러/로딩/빈 상태 모두 `ListView` 기반**: `RefreshIndicator`가 Scrollable 자식을 요구하므로 Center 대신 `ListView`로 당김 제스처 가능하게 구성.
- **카드 재사용**: spec 지시대로 `RecommendedStoreCard` 그대로 사용. 공통화/이동 없음 (현 단계 YAGNI).
- **Qradar 용어**: 탭 라벨 "매장 검색" / "지도 검색"은 spec 명칭 준수. 내부 주석에 Qrator 표현 유지.

---

## 테스트 포인트

### 동작 검증
1. **탭 전환**: "매장 검색" ↔ "지도 검색" 탭 탭. 지도 탭은 placeholder 표시.
2. **검색 debounce**: 빠르게 타이핑 시 250ms 동안 provider 미갱신, 멈춘 뒤 1회 갱신.
3. **검색 clear 버튼**: 입력 후 cancel 아이콘 탭 → 텍스트·provider 모두 초기화, 버튼 사라짐.
4. **등급 필터**: S/A/B/C 토글. 마지막 1개 상태에서 그것을 해제 시도 → 반응 없음(최소 1개 유지).
5. **필터 즉시 반영**: 검색어/등급 변경 시 재조회 없이 리스트 즉시 변경, 결과 카운트도 동기화.
6. **거리순 정렬**: 가장 가까운 매장이 최상단. `distanceKm`가 null인 경우 최하단.
7. **pull-to-refresh**: 리스트 당기면 `orderBaseStoresProvider` invalidate → 서버 재조회. 로딩 인디케이터 색상 `primary`.

### 상태 UI
8. **초기 로딩**: 4개 shimmer 카드 표시. 검색창/칩/결과 카운트 위치는 유지.
9. **에러**: Firestore 실패 시 에러 아이콘+메시지+재시도 버튼. 재시도 탭 → 재조회.
10. **빈 상태 A (base 0)**: "주변 10km 이내에 매장이 없어요" + "위치를 이동해서 다시 시도해보세요".
11. **빈 상태 B (검색어로 0)**: "'xxx'에 해당하는 매장이 없어요".
12. **빈 상태 C (등급 필터로만 0)**: "선택한 등급에 해당하는 매장이 없어요".

### UI/스타일
13. **AppColors 외 색상 하드코딩 없음** (grep 확인).
14. **검색창 포커스**: 탭 시 테두리 `primary` 1.5px, blur 시 `border` 1px.
15. **등급 칩 선택 상태**: 선택 = `primary` 배경 + `onPrimary` w700 텍스트. 비선택 = `surfaceElevated` + `border` 1px + `textBody` w600.
16. **결과 카운트 노출 조건**: data 상태에서만 표시. 로딩/에러 시 숨김.
17. **카드 탭**: "준비 중입니다" 스낵바.

### 아키텍처
18. **presentation/domain 에서 Firebase SDK import 없음**.
19. **provider 재사용**: home_providers의 `userLocationProvider`, `getNearbyStoresUseCaseProvider` 그대로 사용 → 홈과 주문 화면이 같은 위치 상태 공유.

---

## 미구현/보류 항목

- **지도 탭 (StoreMapTab)**: 사용자 결정으로 보류. 후속 task `order_store_map`에서 Kakao Map으로 구현 예정. 본 task에서는 `StoreMapPlaceholderTab` 으로 자리만 확보.
- **매장 카드 탭 시 상세 화면 이동**: 현재 "준비 중" 스낵바. 매장 상세 task 진행 시 `onTap` 교체만 필요.

---

## 코드 생성 필요 여부
- [ ] `dart run build_runner build --delete-conflicting-outputs` — **불필요** (freezed 신규 정의 없음).

---

## 검증
- `flutter analyze` (전체) → `No issues found!`
