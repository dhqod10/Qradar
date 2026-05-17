# 주문하기 매장 검색 테스트 리포트 (Phase 1)

## 테스트 일시
- 2026-04-22

## 전체 결과
- **PASS: 34개**
- **FAIL: 0개**
- **보류/개선 제안: 4개** (이 중 3개 후속 반영 완료, 1개는 현상 유지)

`flutter analyze` 전체 통과 (`No issues found!`)

### 개선 제안 반영 내역 (마감 후 수정)
- [x] **(1) suffixIcon**: `Icons.cancel_rounded` → `Icons.close_rounded` — design 일치
- [x] **(2) `_ListContent.stores`**: `List` → `List<StoreEntity>` — 타입 명시화
- [x] **(3) `_ResultCount.asyncStores`**: `AsyncValue<List<dynamic>>` → `AsyncValue<List<StoreEntity>>` — 타입 명시화
- [−] **(4) ResultCount 빈 공간 20px**: 현상 유지 (레이아웃 점프 방지 의도적)

---

## 상세 결과

### PASS — 기능 검증 (spec.md 기준)

#### 공통 (OrderPage 셸)
- [x] **TabBar 2탭 구성** — `order_page.dart:78-81` "매장 검색" / "지도 검색" 라벨 정확
- [x] **지도 탭 placeholder** — `store_map_placeholder_tab.dart` 독립 위젯
- [x] **fullscreenDialog 동작 유지** — `scaffold_with_nav.dart:106` `fullscreenDialog: true` 그대로
- [x] **좌상단 ✕ 닫기 버튼** — `order_page.dart:41-48` `Icons.close_rounded` + `Navigator.pop`
- [x] **위치 권한 폴백 재사용** — `order_providers.dart:51` `userLocationProvider.future` (홈과 공유)

#### 탭 1 — 매장 검색 (리스트)
- [x] **상단 고정 검색창 + placeholder** — `order_search_bar.dart:101` `매장명을 검색하세요`
- [x] **등급 필터 S/A/B/C 다중 선택** — `grade_filter_chips.dart:11-16` 4개 칩 구성
- [x] **기본 전체 선택** — `order_providers.dart:29-34` 초기값 `{S,A,B,C}`
- [x] **최소 1개 유지** — `order_providers.dart:39` `next.length <= 1` 가드
- [x] **거리 오름차순 정렬** — `order_providers.dart:76-80` `distanceKm` 기준 + null은 `double.infinity`
- [x] **카드 재사용 (`RecommendedStoreCard`)** — `store_list_tab.dart:112`
- [x] **카드 탭 → 스낵바** — `store_list_tab.dart:119-123` "준비 중입니다"
- [x] **로딩 shimmer** — `_ListLoading` 4개 카드 (`store_list_tab.dart:126-151`)
- [x] **에러 UI + 재시도** — `_ListError` (`store_list_tab.dart:153-211`)
- [x] **빈 상태 3분기** — `_EmptyList` (`store_list_tab.dart:221-239`)
- [x] **debounce 250ms** — `order_search_bar.dart:17,51-55` Timer + dispose cancel
- [x] **pull-to-refresh** — `store_list_tab.dart:35-41` `ref.invalidate(orderBaseStoresProvider)`

#### 탭 2 — 지도 placeholder
- [x] **지도 아이콘 + 안내 문구** — `store_map_placeholder_tab.dart` 디자인 일치

---

### PASS — 디자인 검증 (design.md 기준)

- [x] **AppBar 스펙 일치** — background/elevation/surfaceTint/leading/title 모두 일치 (`order_page.dart:34-56`)
- [x] **TabBar 스펙 일치** — labelColor/indicatorColor/indicatorSize.tab/indicatorWeight 2.5/divider/labelStyle 15 w700 모두 일치 (`order_page.dart:59-82`)
- [x] **TabBarView NeverScrollableScrollPhysics** — 세로 스크롤 간섭 방지 (`order_page.dart:87`)
- [x] **OrderSearchBar 높이 46 / 라운드 999 / 포커스 전환** — `order_search_bar.dart:67-77`
- [x] **포커스 시 primary 1.5px, 비포커스 border 1px** — 일치
- [x] **등급 칩 선택/비선택 스타일** — `grade_filter_chips.dart:62-75` 정확
- [x] **AnimatedContainer 200ms easeInOut** — `grade_filter_chips.dart:57-58`
- [x] **ResultCount 12 w500 textMuted + data 상태 한정 표시** — `store_list_tab.dart:59-87`
- [x] **RefreshIndicator color primary, bg surfaceElevated** — `store_list_tab.dart:36-37`
- [x] **리스트 padding 20/4/20/24 + separator 12** — `store_list_tab.dart:106,111`
- [x] **에러 상태 문구/버튼 스타일** — "매장 정보를 불러올 수 없어요" / "다시 시도" 일치
- [x] **빈 상태 A/B/C 문구** — design.md 지정 3분기 정확 재현

---

### PASS — 아키텍처 검증

- [x] **presentation 레이어에 Firebase SDK import 없음** — `grep firebase|cloud_firestore` 결과 0건 (`lib/presentation/customer/order/`)
- [x] **레이어 의존 방향** — order → home_providers (UseCase/Provider) → domain/data. 정상.
- [x] **파일 위치 규칙 준수** — `lib/presentation/customer/order/{providers,widgets,tabs}/` 구조 정확
- [x] **Provider 명명** — 모두 `xxxProvider` 접미사 준수
- [x] **Notifier 최소 1개 유지 패턴** — `selectedCategoriesProvider` 패턴과 일관

---

### PASS — 코드 품질

- [x] **AppColors 외 하드코딩 색상 없음** — `grep Color\(0x` 결과 0건. `Colors.transparent`는 프로젝트 전역 관례(2개 파일에서도 동일 사용).
- [x] **flutter analyze 에러/경고 없음** — 전체 `No issues found!`
- [x] **Qradar 용어** — 탭 라벨은 기능 명칭 그대로 유지(주문/지도/매장). 내부 주석 "Qrator" 표현 유지 (`order_providers.dart:7`). 준수 수준 적절.
- [x] **dispose 규약** — `_OrderPageState.dispose` TabController 해제, `_OrderSearchBarState.dispose` Timer/FocusNode/Controller 모두 해제

---

## 보류 / 개선 제안 (FAIL 아님)

### 1. suffixIcon 아이콘 종류 불일치
- **위치**: `order_search_bar.dart:117`
- **관찰**: design.md는 `Icons.close_rounded` 지정, 구현은 `Icons.cancel_rounded` 사용 (채움원 내 X).
- **영향**: 미미. `cancel_rounded` 가 검색창 clear 아이콘으로 사실상 더 관용적.
- **제안**: 디자이너가 명시적으로 의도한 아이콘이었다면 `Icons.close_rounded` 로 교체. 아니면 현 구현 유지.

### 2. `_ListContent.stores` 타입이 `List<dynamic>`
- **위치**: `store_list_tab.dart:90`
- **관찰**: `List` 로만 선언되어 런타임 타입 체크만 수행. 컴파일 타임 타입 안정성 저하.
- **영향**: 현재 `flutter analyze` 통과. 실제 런타임 동작에 문제 없음.
- **제안**: `List<StoreEntity>` 로 명시. `import 'package:qradar/domain/entities/store_entity.dart'` 필요.

### 3. `_ResultCount.asyncStores` 타입이 `AsyncValue<List<dynamic>>`
- **위치**: `store_list_tab.dart:60`
- **관찰**: 위 항목과 동일 패턴. 동작엔 영향 없지만 타입 안정성 관점에서 개선 권장.
- **제안**: `AsyncValue<List<StoreEntity>>` 로 변경.

### 4. 결과 카운트 자리 `SizedBox(height: 20)` 플레이스홀더
- **위치**: `store_list_tab.dart:69-70`
- **관찰**: design.md에 미명시. 로딩/에러 상태에서 검색창/칩과 리스트 사이 레이아웃 점프 방지 목적으로 보임.
- **영향**: 합리적. 20px는 임의 값(텍스트 라인 높이 ≈ 20).
- **제안**: 현 구현 유지. 필요 시 design.md 에 "로딩/에러 시 20px 공간 유지" 주석 추가.

---

## 설계자 전달 메시지

### 완료 확인 요청
- 전체 기능/디자인/아키텍처 항목이 PASS. `flutter analyze` 통과. Phase 1 마감 가능 상태로 판단.
- 보류/개선 제안 4건은 모두 **FAIL이 아님** — 기능 및 스펙 준수 측면에서 결격 없음. 타입 명시화(항목 2·3)는 다음 정리 커밋에서 반영 권장.

### 후속 작업 상기
- Phase 2 (`order_store_map`): Kakao Map 플러그인 도입 필요. 본 task에서 확보한 provider 구조(`orderStoresProvider`)를 그대로 지도 탭에서 구독만 하면 필터 동기화 자동 확보됨.
- 매장 카드 탭 → 상세 화면 이동: `_showComingSoon` 교체만 하면 되도록 설계됨.

### 우선순위 제안
| 우선순위 | 항목 | 액션 |
|---|---|---|
| 1 | Phase 1 마감 확정 | 사용자 확인 후 종료 |
| 2 | 타입 명시화 (보류 2, 3) | 10분 작업. Phase 2 시작 전 정리 권장 |
| 3 | suffixIcon 아이콘 확인 (보류 1) | 디자이너 최종 확인 후 처리 |
| 4 | Phase 2 지도 탭 task 개시 | Kakao Map API 키 활성화 후 |
