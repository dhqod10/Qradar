# 주문하기 지도 검색 디자인 명세 (Phase 2)

## 참조한 Figma 디자인
- Figma 레퍼런스 없음. spec.md + Qradar 디자인 시스템(LightMidnightAccentPalette) + Phase 1 리스트 탭 디자인 일관성 기준.

---

## 화면 구성

### StoreMapTab (지도 검색 탭)

- **레이아웃**:
  ```
  Column
    ├─ Padding(20,16,20,0) → OrderSearchBar (Phase 1 재사용)
    ├─ Padding(20,12,20,4) → GradeFilterChips (Phase 1 재사용)
    └─ Expanded
         └─ Stack
              ├─ KakaoMapView (전체 채움)
              ├─ Positioned(top:12, left:20, right:20) → _MapStatusBanner (조건부)
              ├─ Positioned(bottom:_hasSheet ? 176 : 20, right:20) → _MyLocationFab
              └─ Positioned(bottom:0, left:0, right:0) → StoreMapMarkerSheet (조건부)
  ```
- **배경**: `AppColors.background`
- **SafeArea**: AppBar 가 상단 처리, body 는 기본 (Stack 하단은 bottom SafeArea 영향 없도록 자체 padding)

---

## 컴포넌트 상세

### 1. OrderSearchBar (Phase 1 재사용)
- **위치**: 상단 고정, `Padding(EdgeInsets.fromLTRB(20, 16, 20, 0))`
- **변경 없음**: Phase 1 `order_search_bar.dart` 그대로. debounce 250ms, clear 버튼, 포커스 border primary 1.5px.
- **특이 동작**: 포커스 획득 시 현재 열려있는 `StoreMapMarkerSheet` 자동 닫힘 (Dart 측 로직).

### 2. GradeFilterChips (Phase 1 재사용)
- **위치**: 검색창 바로 아래, `Padding(EdgeInsets.fromLTRB(20, 12, 20, 4))`
- **변경 없음**: Phase 1 `grade_filter_chips.dart` 그대로. 4개 균등 분배, AnimatedContainer 200ms, 최소 1개 유지.

### 3. KakaoMapView (WebView 래퍼)
- **위젯**: `SizedBox.expand(child: WebViewWidget(controller: _webViewController))`
- **배경**: WebView 로딩 전 영역 — `AppColors.surface` (단색 placeholder)
- **원형 클리핑 없음**: 지도는 전체 Stack 바닥을 채움. 상단/하단 오버레이가 띄워진 형태.
- **WebView HTML 배경**: `#F3F4F6` (surface 와 동일, Kakao 지도 타일 로드 전 틈 최소화)
- **JS SDK 로드 표시**: HTML 내부에서 처리 (Dart는 별도 로딩 인디케이터 필요시 표시)

### 4. Marker (SVG, Kakao Maps CustomOverlay 또는 MarkerImage 방식)

**핵심 원칙**: 등급별로 식별 가능한 색상 구분. 흰 외곽 테두리 + 연한 그림자.

| 등급 | 색상 토큰 | HEX (참고) | 의미 |
|------|----------|-----------|------|
| S | `AppColors.accent` | `#FFD700` | Gold — 최상급 프리미엄 |
| A | `AppColors.primaryBright` | `#38BDF8` | Sky — 상위 하이라이트 |
| B | `AppColors.primary` | `#0F172A` | Midnight — 기본 브랜드 |
| C | `AppColors.textMuted` | `#6B7280` | Gray — 표준 |

**마커 스펙 (기본 / 비선택 상태)**:
- 형태: 원형 pin (하단 꼬리 포함), 머리 지름 30, 꼬리 끝까지 전체 높이 40
- 채움: 위 등급별 색상
- 외곽 테두리: `AppColors.onPrimary` (#FFFFFF) 2px
- 그림자: `rgba(15, 23, 42, 0.18)` (primary alpha 0.18), blur 6, offset (0, 2)
- 중앙 아이콘/문자: 등급 알파벳 대문자 (S/A/B/C), 11px w700, 색상:
  - S (Gold 배경): `AppColors.primary` (#0F172A) — 대비 확보
  - A/B (밝은~짙은 색 배경): `AppColors.onPrimary` (#FFFFFF)
  - C (Gray 배경): `AppColors.onPrimary` (#FFFFFF)

**선택 상태 (해당 매장 바텀시트 열린 경우)**:
- 크기 1.2x 확대 (머리 지름 36, 전체 높이 48)
- 외곽 테두리 3px (흰색 유지)
- 글로우: 해당 등급 색 alpha 0.35, blur 12 외곽 링
- 나머지 마커는 기본 상태 유지 (dim 처리 없음 — 가독성 우선)

**구현 방식 (JS측)**:
- `CustomOverlay` + 인라인 SVG 문자열 — 상태/색상 동적 변경 용이
- 각 매장 id 를 data attribute 로 보관 → 탭 핸들러가 id 추출

### 5. _MyLocationFab (우하단 플로팅 버튼)
- **위젯**: `Material(type: MaterialType.canvas, elevation: 0)` + `InkResponse`
- **크기**: 48x48
- **배경**: `AppColors.surfaceElevated`
- **테두리**: `AppColors.border` 1px
- **라운드**: 999 (원형)
- **그림자**: `BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 12, offset: Offset(0, 4))`
- **아이콘**: `Icons.my_location_rounded`, size 22, color `AppColors.primary`
- **위치**:
  - `Positioned(right: 20, bottom: _sheetOpen ? 176 : 20)` — 바텀시트 열릴 때 위로 밀림
  - `AnimatedPositioned(duration: 250ms, curve: Curves.easeInOut)` 로 부드럽게 이동
- **탭 동작**: `runJs('moveTo', userLat, userLng)` — 지도 panTo 애니메이션 (카카오 기본 약 400ms)
- **비활성 조건**: `userLocationProvider` 가 loading 또는 error 일 때 불투명도 0.4 + `IgnorePointer`

### 6. _MapStatusBanner (지도 상단 얇은 배너)
지도 위 상태 알림용 얇은 오버레이. 3가지 변형.

**공통 스펙**:
- **위치**: `Positioned(top: 12, left: 20, right: 20)`
- **컨테이너**: `AnimatedSlide` + `AnimatedOpacity` (duration 200ms)
- **padding**: `EdgeInsets.symmetric(horizontal: 14, vertical: 10)`
- **라운드**: 12
- **그림자**: primary alpha 0.08, blur 10, offset (0, 2)

**변형 A — 빈 결과 (마커 0, base 결과는 있음)**:
- 배경: `AppColors.surfaceElevated`
- 테두리: `AppColors.border` 1px
- 아이콘: `Icons.search_off_rounded`, size 16, color `AppColors.textMuted`
- 텍스트: `'조건에 맞는 매장이 없어요'`, 12, w600, `AppColors.textBody`

**변형 B — 주변 매장 없음 (base 결과 0)**:
- 배경: `AppColors.surfaceElevated`
- 테두리: `AppColors.border` 1px
- 아이콘: `Icons.storefront_outlined`, size 16, color `AppColors.textMuted`
- 텍스트: `'주변 10km 이내에 매장이 없어요'`, 12, w600, `AppColors.textBody`

**변형 C — 로드 에러**:
- 배경: `AppColors.surfaceElevated`
- 테두리: `AppColors.error.withValues(alpha: 0.4)` 1px
- 아이콘: `Icons.error_outline`, size 16, color `AppColors.error`
- 텍스트: `'매장 정보를 불러올 수 없어요'`, 12, w600, `AppColors.textBody`
- 우측: `TextButton('다시 시도')` — foreground `AppColors.primary`, 12, w700, padding 최소

### 7. StoreMapMarkerSheet (하단 미니 카드)

마커 탭 시 지도 위로 올라오는 고정형 시트 (modal 아님, `Positioned(bottom: 0)` 방식으로 제어).

**컨테이너**:
- **위젯**: `AnimatedSlide` + `AnimatedOpacity` (`duration: 250ms, curve: Curves.easeOutCubic`)
- **높이**: 고정 160 (이미지 120 높이 + 컨텐츠 분리 레이아웃은 아래 참고)
- **배경**: `AppColors.surfaceElevated`
- **라운드**: 상단만 `BorderRadius.vertical(top: Radius.circular(20))`
- **그림자**: `BoxShadow(color: AppColors.primary.withValues(alpha: 0.12), blurRadius: 20, offset: Offset(0, -6))`
- **전체 padding**: 좌우 16, 상하 16

**내부 레이아웃** (`Row`):
```
Row
  ├─ _StoreThumb  (이미지 80x80, 좌측)
  ├─ SizedBox(width:14)
  ├─ Expanded(Column[name, 거리, 등급 뱃지])
  └─ _OrderButton (우측 세로 전체, 주문하기)
```

**구성 요소 상세**:

1. **_StoreThumb**
   - 크기: 80x80
   - 라운드: 14
   - 이미지: `CachedNetworkImage(fit: BoxFit.cover)`
   - 에러/빈 URL: `AppColors.surface` 배경 + `Icons.storefront_outlined` size 24 color `AppColors.textMuted`

2. **매장 이름**
   - `Text`, fontSize 16, fontWeight w700, color `AppColors.textHeading`
   - maxLines 1, ellipsis

3. **거리 + 등급 뱃지 Row**
   - 상단 name 아래 `SizedBox(height: 8)`
   - Row:
     - `Icon(Icons.place_outlined, size: 13, color: AppColors.textMuted)`
     - `SizedBox(width: 4)`
     - `Text(DistanceCalculator.formatKm(store.distanceKm ?? 0) 또는 '-')` — 13, w500, `AppColors.textBody`
     - `SizedBox(width: 10)`
     - `GradeBadge(grade, reviewCount)` — 기존 재사용
   - 아래 여백 자유 (Column spaceBetween 대신 crossAxisAlignment start)

4. **닫기 버튼** (우측 상단)
   - `Positioned(top: 6, right: 6)` — 시트 내부 기준
   - `IconButton` 대체: `GestureDetector(behavior: opaque, child: Padding(6) + Icon)`
   - 아이콘: `Icons.close_rounded`, size 18, color `AppColors.textMuted`
   - hit 영역: 최소 32x32

5. **_OrderButton**
   - `ElevatedButton`, 높이 48, 폭 hug (padding 수평 20)
   - 배경: `AppColors.primary`
   - foreground: `AppColors.onPrimary`
   - 라운드: 12
   - elevation 0 (커스텀 그림자도 없음)
   - 텍스트: `'주문하기'`, 14, w700
   - 탭: 현재는 "준비 중입니다" 스낵바 (Phase 1 동일 패턴)

**열림/닫힘 조건**:
- 열림: 마커 탭 시 (`_selectedStoreId != null`)
- 닫힘 조건:
  - 시트 내부 X 버튼 탭
  - 지도 빈 영역 탭 (JS → Dart Bridge `mapTap`)
  - OrderSearchBar 포커스 획득
  - 등급 필터 변경으로 선택 매장이 리스트에서 사라질 때

**애니메이션**:
- 초기 offset `Offset(0, 1.2)` → `Offset(0, 0)`
- `AnimatedSlide + AnimatedOpacity` 조합 / duration 250ms / curve easeOutCubic
- 닫힐 때 반대로

---

## 인터랙션

| 동작 | 반응 |
|------|------|
| 탭 최초 진입 | WebView 로드 → Kakao SDK init → `setStores(payload)` 호출 → 마커 렌더 |
| 검색어/등급 변경 | `orderStoresProvider` 재계산 → `setStores(newPayload)` 재호출, 지도 중심/줌 유지 |
| 마커 탭 | SVG pin 1.2x 확대 + glow + 바텀시트 열림 + 내위치 FAB 위로 밀림 |
| 지도 드래그/줌 | 기본 Kakao JS SDK 동작 (바텀시트 열려있어도 유지) |
| 지도 빈 영역 탭 | 바텀시트 닫힘 + 선택 마커 기본 상태 복귀 |
| 내 위치 버튼 탭 | `moveTo(userLat, userLng)` panTo 애니메이션 + 햅틱 없음 |
| OrderSearchBar 포커스 | 바텀시트 자동 닫힘 |
| 주문하기 버튼 탭 | "준비 중입니다" 스낵바 |
| 바텀시트 X 탭 | 시트 닫힘 + 선택 마커 기본 상태 |

---

## 상태별 UI

### 로딩 (WebView 또는 매장 데이터 로딩)
- KakaoMapView 영역: `AppColors.surface` 단색 배경 유지 (WebView 바닥색과 동일)
- 중앙: `CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5)` — 크기 32
- CircularProgressIndicator 아래 `SizedBox(height: 12)`
- `Text('지도 불러오는 중...')` — 12, w500, `AppColors.textMuted`
- 상단 검색바/칩은 정상 표시 (상호작용 가능하지만 지도 갱신은 WebView ready 후)

### 에러
- `_MapStatusBanner` 변형 C 노출 (지도 자체는 배경으로 유지)
- 추가: WebView 자체가 로드 실패한 경우 → KakaoMapView 영역 전체를 다음으로 교체:
  - `Center` + `Column`:
    - `Icon(Icons.map_outlined, size: 40, color: AppColors.error)`
    - `SizedBox(height: 12)`
    - `'지도를 표시할 수 없어요'` — 14, w700, `AppColors.textHeading`
    - `SizedBox(height: 6)`
    - `'네트워크 연결을 확인해주세요'` — 12, `AppColors.textMuted`
    - `SizedBox(height: 16)`
    - `ElevatedButton('다시 시도')` — 배경 primary, 라운드 12, padding h20 v10
  - 재시도: `WebViewController.reload()`

### 빈 상태
- 마커 0 + base 결과 있음: `_MapStatusBanner` 변형 A
- 마커 0 + base 결과도 0: `_MapStatusBanner` 변형 B
- 지도 자체는 정상 렌더 (사용자 위치 중심 뷰 유지) — 빈 상태라고 지도 숨기지 않음

---

## 주요 디자인 결정

### Phase 1 과의 일관성
- 상단 검색바/등급 칩은 **완전히 동일한 위젯 재사용** — 탭 간 시각적 점프 없음
- `RecommendedStoreCard` 는 **바텀시트에 적용하지 않음** (높이/비율 불일치) → `StoreMapMarkerSheet` 신규 구성
- 빈 상태 문구는 Phase 1 과 동일 문구 사용 (일관성)

### 마커 색상 체계
- 기존 `GradeBadge` 는 **단일 미드나잇 pill + 텍스트 등급** 철학. 지도 마커도 일관성을 위해 단색 고정 원한다면 고려 가능.
- 그러나 지도 특성상 "여러 마커를 한눈에 식별"이 핵심 UX → **등급별 색상 차별화** 를 채택.
- `AppColors.accent(Gold)`를 S 등급에 사용해 Qradar 프리미엄 정체성 반영.

### 바텀시트 방식 — modal 이 아닌 Positioned
- `showModalBottomSheet` 사용 시 지도 드래그/줌 불가 (뒤 영역 차단)
- 지도 조작성 유지 + 시트 노출을 동시에 만족하기 위해 **Stack + Positioned + AnimatedSlide** 조합
- 상호작용 영역: 시트 내부 이외는 그대로 지도 조작 가능

### 플로팅 FAB 위치 회피
- 바텀시트 열리면 FAB가 가려짐 → `AnimatedPositioned` 로 `bottom: 176` (시트 높이 160 + 간격 16)로 위로 이동
- 시각적 튀는 현상 최소화, 사용자 조작성 유지

### 선택 마커 강조
- dim 처리 대신 **선택 마커 확대 + glow** 방식 — 주변 맥락 가독성 유지

---

## Figma 대비 변경사항
- Figma 없음. 전반적 Qradar 라이트 미드나잇 아이덴티티 적용.
- 카카오 기본 마커 대신 커스텀 SVG — 브랜드 일관성 + 등급 시각화.
- 지도 상단에 Phase 1 검색창/칩 유지 — 단일 fullscreenDialog 컨텍스트의 탭 전환 일관성.

---

## 공통 컴포넌트 재사용 정리

| 재사용 컴포넌트 | 사용처 |
|---|---|
| `OrderSearchBar` | 지도 탭 상단 |
| `GradeFilterChips` | 지도 탭 상단 |
| `GradeBadge` | StoreMapMarkerSheet 내 거리 옆 |
| `DistanceCalculator.formatKm` | StoreMapMarkerSheet 거리 |
| `CachedNetworkImage` | _StoreThumb 이미지 |

---

## 개발자 전달 특이사항

### WebView 관련
- **Kakao JS Key**: `String.fromEnvironment('KAKAO_JS_KEY')` 로 읽고 HTML 에 주입. 키 누락 시 `_MapStatusBanner` 변형 C 노출.
- **HTML 로드 방식**: `WebViewController.loadFlutterAsset('assets/map/kakao_map.html')` 권장. 또는 `loadHtmlString(await rootBundle.loadString(...))` 대안.
- **JS Bridge 이름**: `KakaoMapBridge` (일관성을 위해 소문자 카멜 지양, 원문 유지).
- **JS → Dart 페이로드**: `{"type":"markerTap","id":"..."}` / `{"type":"mapTap"}` / `{"type":"sdkError"}` / `{"type":"ready"}` JSON 문자열.
- **`ready` 페이로드**: HTML 내 Kakao SDK init 완료 시 전송 → Dart는 그 이후 `setStores` 호출 시작. ready 전 호출 방지용 flag 필수.
- **JS 전역 객체**: `window.flutterMap.setStores(json)`, `window.flutterMap.moveTo(lat, lng)` — 둘 다 Dart `runJavaScript` 로 실행.

### 좌표/위치
- **초기 중심**: `userLocationProvider.value` (AsyncValue.data 일 때), 아니면 서울 시청 폴백.
- **초기 줌**: Kakao level 5 (약 1km 반경).
- **내 위치 이동**: `map.panTo(LatLng)` — 카카오 기본 애니메이션 사용.

### 마커 관리 (JS 측)
- 매장 id 를 key 로 하는 Map 유지 (`const markers = new Map()`).
- `setStores(payload)` 호출 시:
  1. 기존 마커 중 새 payload 에 없는 id → `setMap(null)` 후 Map 제거
  2. 새 payload 에 있는 id 중 기존 없음 → 신규 CustomOverlay 생성
  3. 둘 다 있음 → 위치/등급 변경 체크 후 필요 시 업데이트 (현 단계는 위치 불변 가정, grade 만 체크)
- `setStores` 호출 간 **지도 중심/줌은 유지** (setCenter/setLevel 호출 금지).

### 상태 관리 (Dart 측)
- `StoreMapTab` 은 `ConsumerStatefulWidget` 권장:
  - `_selectedStoreId: String?` — 선택 매장 (바텀시트 연동)
  - `_webViewReady: bool` — ready 이벤트 받았는지
- `ref.listen(orderStoresProvider, ...)` 로 변경 감지 → `_pushStoresToWebView()` 호출.
- 탭 벗어나더라도 상태 유지 (TabBarView 기본은 keepAlive false — 필요시 `AutomaticKeepAliveClientMixin`).

### 접근성
- _MyLocationFab: `Semantics(label: '내 위치로 이동', button: true)`
- 바텀시트 닫기 버튼: `Semantics(label: '닫기', button: true)`
- 주문하기 버튼: `Semantics(label: '주문하기', button: true)`

### 하드코딩 색상 금지
- 단, **마커 SVG 문자열 내부** 는 HTML/JS 컨텍스트라 AppColors 직접 참조 불가.
- → `map_config.dart` 의 `markerColorForGrade(StoreGrade)` 함수에서 `AppColors.xxx.toHex()` (또는 수동 hex) 로 변환 후 JSON 전달.
- JS는 받은 hex 문자열만 사용 → 색상 진실원은 여전히 AppColors.

### 애니메이션 타이밍 정리
| 대상 | duration | curve |
|------|----------|-------|
| 바텀시트 열림/닫힘 | 250ms | easeOutCubic |
| 내 위치 FAB 이동 | 250ms | easeInOut |
| 지도 panTo | ~400ms (Kakao 기본) | - |
| 상단 배너 노출/숨김 | 200ms | easeInOut |
| 마커 선택 확대 | 즉시 (다음 setStores 에서 반영) | - |
