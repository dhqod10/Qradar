# 주문하기 지도 검색 구현 내역 (Phase 2)

## 구현 파일 목록

### 신규
- `assets/map/kakao_map.html` — Kakao Maps JS SDK 로드, 마커(SVG pin) 렌더링, JS Bridge
- `lib/core/config/map_config.dart` — `KAKAO_JS_KEY` 주입 + 등급별 hex 매핑 + baseUrl
- `lib/presentation/customer/order/widgets/kakao_map_view.dart` — `webview_flutter` 래퍼, 브릿지 메시지 라우팅
- `lib/presentation/customer/order/widgets/store_map_marker_sheet.dart` — 마커 탭 시 하단 미니 카드
- `lib/presentation/customer/order/tabs/store_map_tab.dart` — 지도 탭 본체 (검색바/칩/지도/FAB/시트 조립)

### 수정
- `pubspec.yaml` — `webview_flutter: ^4.10.0` 추가, `assets/map/` 등록
- `lib/presentation/customer/order/order_page.dart` — `StoreMapPlaceholderTab` → `StoreMapTab` 교체
- `lib/presentation/customer/order/widgets/order_search_bar.dart` — `onFocusChange` 옵셔널 콜백 추가 (지도 탭의 시트 자동 닫힘 연동용)

### 삭제
- `lib/presentation/customer/order/tabs/store_map_placeholder_tab.dart`

### 변경 없음 (재사용)
- `lib/domain/**` — 전체 그대로
- `lib/data/**` — 전체 그대로
- `lib/presentation/customer/order/providers/order_providers.dart` — Phase 1 그대로
- `lib/presentation/customer/order/widgets/grade_filter_chips.dart` — 그대로
- `lib/presentation/customer/home/widgets/grade_badge.dart` — 시트에서 재사용

---

## 주요 결정사항

- **지도 라이브러리**: `webview_flutter` + `assets/map/kakao_map.html` + Kakao Maps JS SDK. 카카오 공식 Flutter 네이티브 플러그인이 없고, JavaScript SDK 도메인(`http://localhost`)이 이미 등록되어 있어 즉시 사용 가능한 방식을 채택.
- **HTML 로드 방식**: `rootBundle.loadString` 으로 asset 읽기 → 플레이스홀더 3개(`__KAKAO_JS_KEY__`, `__INIT_LAT__`, `__INIT_LNG__`, `__INIT_LEVEL__`) 치환 → `loadHtmlString(html, baseUrl: 'http://localhost')`. baseUrl 을 Kakao 콘솔 등록 도메인과 일치시켜 SDK origin 검증 통과.
- **JS Bridge 페이로드**: 4종 — `ready` / `markerTap(id)` / `mapTap` / `sdkError(reason)`. JSON 문자열로 전달, Dart 측 `jsonDecode` 후 타입별 라우팅.
- **setStores 전달 방식**: Dart 가 `jsonEncode(Map)` 로 직렬화 → JS 함수에 **JS 객체 리터럴** 로 직접 삽입 (`window.flutterMap.setStores(${json})`). JS 측은 `JSON.parse` 없이 바로 사용 (이중 문자열 래핑 회피).
- **마커 구현**: Kakao `CustomOverlay` + 인라인 SVG pin (30x40, 선택 시 36x48). 등급별 fill 색상을 `MapConfig.markerColorHexForGrade` 로부터 주입. 흰 테두리 2px + drop-shadow.
- **선택 마커 강조**: CSS 클래스 토글(`.selected`) — dim 처리 대신 선택 마커만 확대 + glow. S 등급은 Gold 배경 + 검정 라벨(대비 확보), 나머지는 흰 라벨.
- **마커 diff 로직**: JS 쪽 `Map<id, entry>` 유지 → setStores 호출 시 이전 없던 id 만 신규 생성, 제거된 id 만 `setMap(null)`. 중심/줌은 건드리지 않음(필터 재적용 시 지도 뷰 유지).
- **바텀시트 방식**: `showModalBottomSheet` 대신 `Stack + Positioned + AnimatedSlide + AnimatedOpacity`. 시트가 떠 있어도 지도 드래그/줌 유지. 닫힘 시 `IgnorePointer(ignoring: true)` 로 터치 차단.
- **MyLocation FAB 위치 회피**: 시트 열림/닫힘에 따라 `AnimatedPositioned` 로 `bottom` 을 `176 ↔ 20` 사이 전환 (easeInOut 250ms).
- **상단 배너 3변형**: 빈 결과(noMatch) / 주변 없음(noNearby) / 에러(error). error 변형만 "다시 시도" 버튼 포함. 지도는 항상 배경으로 유지 (빈 상태라고 지도 숨기지 않음).
- **등급 색상 진실원**: `MapConfig.markerColorHexForGrade` 에서 `AppColors` Color 객체를 hex 문자열로 변환 후 JSON 전달. HTML/JS 내부에는 AppColors 하드코딩 없음 (단색 배경 `#F3F4F6` 은 surface 토큰의 현재 값과 일치하는 상수로 두되, 팔레트 스왑 시 재확인 필요).
- **검색창 포커스 연동**: `OrderSearchBar` 에 `onFocusChange` 옵셔널 콜백 추가. 지도 탭에서만 사용. 리스트 탭은 기존 호출(`OrderSearchBar()`)을 그대로 유지해도 동작.
- **위치 provider 공유**: `userLocationProvider` / `orderStoresProvider` 를 Phase 1 과 공유. 초기 중심 이동 + 필터 동기화 자동 확보.
- **에러 UI 구분**: WebView 로드 실패 / SDK 로드 실패 / JS Key 누락 → `KakaoMapView` 내부에서 전체 영역 대체 (재시도 버튼 포함). 매장 조회 실패 → 상단 배너(error 변형)만 노출 (지도는 유지).

---

## 테스트 포인트

### 동작 검증
1. **초기 진입**: 지도 탭 진입 → 사용자 위치(또는 서울 시청 폴백) 중심으로 Kakao 지도 렌더.
2. **마커 표시**: 반경 10km/50개 제한의 매장들이 등급별 색상 pin 으로 표시.
3. **마커 색상**: S=Gold / A=SkyBlue / B=Midnight / C=Gray. S 라벨만 검정, 나머지는 흰색.
4. **필터 동기화**: 등급 칩 토글 / 검색어 입력(250ms debounce) → 마커 즉시 재렌더, 지도 중심/줌 유지.
5. **마커 탭**: 바텀시트 열림 + 해당 마커 1.2x 확대 + 흰 테두리 3px + glow. 다른 마커 재탭 시 시트가 새 매장으로 갱신.
6. **지도 빈 영역 탭**: 바텀시트 닫힘 + 선택 마커 원복.
7. **시트 X 탭**: 동일하게 닫힘 + 마커 원복.
8. **검색창 포커스**: 시트 열린 상태에서 검색창 탭 → 시트 자동 닫힘.
9. **필터로 선택 매장이 사라지는 경우**: 시트 자동 닫힘.
10. **내 위치 버튼**: 우하단 FAB 탭 → 현재 위치로 panTo (카카오 애니메이션).
11. **내 위치 FAB 위치 이동**: 시트 열리면 bottom 이 20 → 176 으로 부드럽게 상승.
12. **주문하기 버튼**: "준비 중입니다" 스낵바.

### 상태 UI
13. **로딩**: WebView ready 전까지 surface 단색 배경 + Kakao 내부 로딩.
14. **에러 — WebView 로드 실패 / SDK 키 누락**: KakaoMapView 전체가 에러 상태로 교체 (지도 아이콘 + "지도를 표시할 수 없어요" + 재시도 버튼).
15. **에러 — 매장 조회 실패**: 지도는 유지, 상단 얇은 배너에 "매장 정보를 불러올 수 없어요" + "다시 시도" 버튼.
16. **빈 상태 A (필터 결과 0, base 결과 있음)**: 상단 배너 "조건에 맞는 매장이 없어요".
17. **빈 상태 B (base 결과 0)**: 상단 배너 "주변 10km 이내에 매장이 없어요".

### UI/스타일
18. **AppColors 외 하드코딩 색상 없음** (Dart 파일 기준). HTML 내부 배경 `#F3F4F6` 은 surface 와 일치하는 고정 값.
19. **바텀시트 레이아웃**: 이미지 80x80 라운드 14, 이름 16/w700, 거리 13/w500 + 아이콘 13px, 등급 뱃지 재사용, 주문 버튼 48 높이.
20. **바텀시트 애니메이션**: `AnimatedSlide(offset y:1.2→0) + AnimatedOpacity` 250ms easeOutCubic.
21. **MyLocation FAB**: 48x48 원형 + surfaceElevated 배경 + border 1px + primary alpha 0.08 그림자 + primary 아이콘.
22. **상단 배너**: 라운드 12 + border 1px + primary alpha 0.08 그림자.

### 환경/보안
23. **JS Key 누락 (`--dart-define=KAKAO_JS_KEY` 없음)**: `MapConfig.kakaoJsKey` 빈 문자열 → `_init` 에서 `_flagError()` 호출 → 에러 UI 노출.
24. **JS Key 하드코딩 금지**: `lib/**` 전체 grep 에 JS Key 리터럴 없음(확인 필요).
25. **AppColors 단일 진실원**: `MapConfig.markerColorHexForGrade` 에서 AppColors → hex 변환. 팔레트 스왑 시 마커 색상도 자동 따라감.

### 아키텍처
26. **presentation/domain 에 Firebase / WebView SDK 혼입 없음**: WebView 는 presentation 레이어 위젯에만 등장. domain/data 변경 0.
27. **provider 재사용**: Phase 1 의 `orderStoresProvider`, `userLocationProvider` 그대로 구독.
28. **탭 간 상태 공유**: 리스트 탭에서 건 필터가 지도 탭에서 그대로 반영됨 (provider 공유 효과).

---

## 미구현 / 보류 항목

- **`AutomaticKeepAliveClientMixin` 미적용**: 현재 `TabBarView(physics: NeverScrollableScrollPhysics)` + 2탭만 존재. 탭 전환 시 리빌드되지만 지도 WebView 가 짧은 시간 재로딩 될 수 있음. 실기기 체감 후 필요 시 적용. (이번 task 범위 외.)
- **매장 상세 화면 이동**: "주문하기" 버튼은 여전히 스낵바. 매장 상세 task 진행 시 `onOrderPressed` 교체만 필요.
- **프로덕션 JS Key 분리**: 배포 도메인 등록 + 환경별 키 주입 로직은 Phase 3 배포 준비에서 처리.
- **마커 클러스터링**: 현재 상한 50개라 불필요. 상한 확대 시 재검토.
- **HTML 내 surface 색(#F3F4F6)**: 현재 팔레트(`LightMidnightAccentPalette`) 와 동기. 팔레트 스왑 시 HTML 값도 수동 갱신 필요. → 필요 시 HTML 플레이스홀더(`__SURFACE_HEX__`) 로 승격 가능.

---

## 실행 방법

```bash
# 의존성
flutter pub get

# 실행 (Kakao JS Key 주입 필수)
flutter run -d <device> --dart-define=KAKAO_JS_KEY=<your-js-key>

# 릴리즈 빌드
flutter build ios --release --dart-define=KAKAO_JS_KEY=<your-js-key>
flutter build appbundle --release --dart-define=KAKAO_JS_KEY=<your-js-key>
```

Kakao 콘솔에서 "JavaScript SDK 도메인" 에 `http://localhost` 가 등록되어 있어야 SDK 가 origin 검증을 통과한다. (이미 사용자 확인 완료.)

---

## 코드 생성 필요 여부
- [ ] `dart run build_runner build --delete-conflicting-outputs` — **불필요** (freezed 신규 정의 없음).

---

## 검증
- `flutter pub get` 성공
- `flutter analyze` → `No issues found!`
- 실기기 검증: 테스터가 `--dart-define=KAKAO_JS_KEY=xxx` 주입 후 확인 예정.
