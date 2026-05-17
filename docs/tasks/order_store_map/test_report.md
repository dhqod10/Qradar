# order_store_map 테스트 리포트 (Phase 2)

## 테스트 일시
- 2026-04-22

## 테스트 방식
- 코드 정적 분석 (spec.md + design.md 기준 수동 매핑)
- `flutter analyze` 실행
- 하드코딩 색상 / Firebase import / WebView 레이어 침범 grep 검증
- 실기기 동적 검증은 KAKAO_JS_KEY 주입 환경이 필요하므로 테스터 외 실기기 담당자 몫(별도 메모)

## 전체 결과
- PASS: 31개
- FAIL: 0개
- 보류: 3개

---

## 상세 결과

### PASS — 기능 (spec.md 요구사항)

- [x] "지도 검색" 탭 진입 시 Kakao Maps 렌더 — [store_map_tab.dart:62-74](lib/presentation/customer/order/tabs/store_map_tab.dart#L62-L74), [kakao_map_view.dart:160-172](lib/presentation/customer/order/widgets/kakao_map_view.dart#L160-L172)
- [x] 초기 중심 = `userLocationProvider`, 없으면 `GradeThresholds.defaultLatitude/Longitude` 폴백 — [kakao_map_view.dart:76-79](lib/presentation/customer/order/widgets/kakao_map_view.dart#L76-L79)
- [x] 초기 줌 레벨 = Kakao level 5 (`MapConfig.defaultZoomLevel = 5`) — [map_config.dart:18](lib/core/config/map_config.dart#L18)
- [x] `orderStoresProvider` 매장 목록을 마커로 표시 — [store_map_tab.dart:188-203](lib/presentation/customer/order/tabs/store_map_tab.dart#L188-L203)
- [x] 등급별 색상 (S=accent / A=primaryBright / B=primary / C=textMuted) — [map_config.dart:25-36](lib/core/config/map_config.dart#L25-L36)
- [x] 검색어/등급 필터 변경 시 마커 즉시 갱신 — [store_map_tab.dart:31-41](lib/presentation/customer/order/tabs/store_map_tab.dart#L31-L41) (ref.listen → `_syncToMap`), JS 측 diff 로직 [kakao_map.html:92-151](assets/map/kakao_map.html#L92-L151)
- [x] 마커 탭 → 바텀시트 노출 — [store_map_tab.dart:138-142](lib/presentation/customer/order/tabs/store_map_tab.dart#L138-L142), [kakao_map.html:75-78](assets/map/kakao_map.html#L75-L78)
- [x] "주문하기" 버튼 → "준비 중입니다" 스낵바 — [store_map_tab.dart:169-173](lib/presentation/customer/order/tabs/store_map_tab.dart#L169-L173)
- [x] 우하단 "내 위치" FAB → 현재 위치 복귀 — [store_map_tab.dart:159-162](lib/presentation/customer/order/tabs/store_map_tab.dart#L159-L162), [kakao_map.html:153-156](assets/map/kakao_map.html#L153-L156)
- [x] 상단 `OrderSearchBar` + `GradeFilterChips` 유지 — [store_map_tab.dart:54-61](lib/presentation/customer/order/tabs/store_map_tab.dart#L54-L61)
- [x] 지도 빈 영역 탭 → 시트 닫힘 — [kakao_map.html:180-182](assets/map/kakao_map.html#L180-L182), [store_map_tab.dart:144-150](lib/presentation/customer/order/tabs/store_map_tab.dart#L144-L150)
- [x] 검색바 포커스 시 시트 자동 닫힘 — [order_search_bar.dart:44-49](lib/presentation/customer/order/widgets/order_search_bar.dart#L44-L49), [store_map_tab.dart:152-157](lib/presentation/customer/order/tabs/store_map_tab.dart#L152-L157)
- [x] 필터로 선택 매장 사라지면 시트 자동 닫힘 — [store_map_tab.dart:34-40](lib/presentation/customer/order/tabs/store_map_tab.dart#L34-L40)

### PASS — 상태 UI

- [x] 로딩: WebView ready 전까지 `AppColors.surface` 단색 배경 — [kakao_map_view.dart:164-171](lib/presentation/customer/order/widgets/kakao_map_view.dart#L164-L171)
- [x] 에러 (WebView/SDK 로드 실패 / JS Key 누락) → 전체 영역 에러 UI + 재시도 — [kakao_map_view.dart:49-52, 122-127, 175-226](lib/presentation/customer/order/widgets/kakao_map_view.dart#L175-L226)
- [x] 에러 (매장 조회 실패) → 상단 배너 + "다시 시도" (`ref.invalidate(orderBaseStoresProvider)`) — [store_map_tab.dart:211-213, 289-290](lib/presentation/customer/order/tabs/store_map_tab.dart#L211-L213)
- [x] 빈 상태 A (필터 결과 0 / base 있음) — [store_map_tab.dart:216-217, 287](lib/presentation/customer/order/tabs/store_map_tab.dart#L216-L217)
- [x] 빈 상태 B (base 0) — [store_map_tab.dart:216, 288](lib/presentation/customer/order/tabs/store_map_tab.dart#L216)

### PASS — 디자인 (design.md)

- [x] StoreMapTab 레이아웃 (Column[SearchBar, Chips, Expanded(Stack[Map, Banner, FAB, Sheet])]) — [store_map_tab.dart:52-119](lib/presentation/customer/order/tabs/store_map_tab.dart#L52-L119)
- [x] 마커 SVG pin 30x40, 선택 시 36x48, 흰 테두리 2px, drop-shadow — [kakao_map.html:10-39, 63-66](assets/map/kakao_map.html#L10-L39)
- [x] S 등급 라벨 `#0F172A`, 나머지 흰색 — [kakao_map.html:32-38](assets/map/kakao_map.html#L32-L38)
- [x] _MyLocationFab 48x48, surfaceElevated, border 1px, primary alpha 0.08 그림자 — [store_map_tab.dart:232-277](lib/presentation/customer/order/tabs/store_map_tab.dart#L232-L277)
- [x] FAB 위치 회피 `bottom: 176 ↔ 20` AnimatedPositioned 250ms easeInOut — [store_map_tab.dart:81-90](lib/presentation/customer/order/tabs/store_map_tab.dart#L81-L90)
- [x] _MapStatusBanner 3변형 (noMatch / noNearby / error) — [store_map_tab.dart:281-367](lib/presentation/customer/order/tabs/store_map_tab.dart#L281-L367)
- [x] 바텀시트 스펙 (높이 160 / 상단 라운드 20 / 80x80 thumb(14) / 이름 16 w700 / 거리 13 + place 아이콘 13 / GradeBadge / 주문 버튼 48) — [store_map_marker_sheet.dart](lib/presentation/customer/order/widgets/store_map_marker_sheet.dart)
- [x] 시트 애니메이션 `AnimatedSlide(Offset(0,1.2)→0) + AnimatedOpacity` 250ms easeOutCubic — [store_map_tab.dart:96-112](lib/presentation/customer/order/tabs/store_map_tab.dart#L96-L112)
- [x] 시트 열려도 지도 드래그/줌 유지 (`Positioned` + `IgnorePointer` 기반, `showModalBottomSheet` 미사용) — [store_map_tab.dart:91-114](lib/presentation/customer/order/tabs/store_map_tab.dart#L91-L114)
- [x] 선택 마커 확대 + glow (dim 없음) — [kakao_map.html:18-22](assets/map/kakao_map.html#L18-L22)

### PASS — 아키텍처 / 품질

- [x] `presentation/customer/order/**` 및 `lib/core/config/map_config.dart` 에 `Color(0x...)` 하드코딩 0건 (grep 결과 없음)
- [x] `presentation/customer/order/**` 에 firebase import 0건 (grep 결과 없음)
- [x] `lib/domain/**` 에 webview import 0건 (grep 결과 없음)
- [x] JS Key 하드코딩 0건 — `KAKAO_JS_KEY` 참조는 `map_config.dart` (String.fromEnvironment) 와 `kakao_map_view.dart` 의 placeholder replace 2곳뿐
- [x] AppColors 단일 진실원 유지 — 마커 색상 hex 변환도 `map_config.dart` 에서만 수행 ([map_config.dart:38-41](lib/core/config/map_config.dart#L38-L41))
- [x] `flutter analyze` → **No issues found!** (ran in 5.1s)
- [x] Placeholder 파일 삭제 확인 — `lib/presentation/customer/order/tabs/` 에 `store_list_tab.dart`, `store_map_tab.dart` 둘만 존재

---

### 보류 항목

- [ ] **실기기 동적 동작 검증**
  - 이유: Kakao JS Key 주입(`--dart-define=KAKAO_JS_KEY=xxx`) + 실기기/에뮬레이터 필요. implementation.md 28개 포인트 중 지도 렌더 / 마커 탭 / panTo / SDK origin 통과 등은 테스터 정적 분석 범위 외. 사용자(테스터 측 실기기 담당)가 별도 검증 예정.

- [ ] **`AutomaticKeepAliveClientMixin` 미적용**
  - 이유: spec/design 에 명시되지 않음. implementation.md 에서 "실기기 체감 후 필요 시 적용. 이번 task 범위 외"로 명기. 현재 2탭 + `NeverScrollableScrollPhysics` 로 동작 가능하므로 정적 검증에서는 보류 처리.

- [ ] **HTML 내 `#F3F4F6` (surface) 고정값**
  - 이유: AppColors hex 변환 주입 대신 HTML 내 상수로 고정. 현재 팔레트(`LightMidnightAccentPalette`)의 surface 값과 일치하므로 문제 없으나, 팔레트 스왑 시 수동 동기 필요. implementation.md 에서 "필요 시 `__SURFACE_HEX__` 플레이스홀더로 승격 가능"으로 명기된 의도적 결정 — spec/design 위반은 아님.

---

## 설계자 전달 메시지

- **전체 PASS (FAIL 0건)**. spec.md 17개 요구사항 + design.md 컴포넌트 스펙 10개 + 아키텍처/품질 7개 항목 모두 코드 레벨 검증 완료.
- `flutter analyze` 클린 통과. AppColors 하드코딩 / Firebase 혼입 / JS Key 노출 / WebView 레이어 침범 모두 0건.
- **보류 3건**은 모두 task 범위 외(실기기 검증 위임 / KeepAlive 최적화 / HTML surface 토큰 승격) — 추가 개발 재작업은 불필요하다고 판단.
- **실기기 검증 후속 조치**: 테스터 측 담당자가 `--dart-define=KAKAO_JS_KEY=xxx` 주입 후 아래 항목을 최종 확인하면 task 클로즈 가능.
  1. 지도 렌더 및 Kakao SDK origin 검증 통과 (`http://localhost` baseUrl)
  2. 마커 등급별 색상 4종 + 선택 상태 확대/glow 시각 확인
  3. 필터/검색 변경 시 마커 재렌더 + 지도 중심/줌 유지
  4. 시트 열림 중 지도 드래그/줌 유지, FAB 위치 이동
  5. KAKAO_JS_KEY 누락 시 에러 UI 표시
- **권고**: 정적 검증 기준 완료 처리 가능. 실기기 결과에서 이상 발견 시에만 re-open.
