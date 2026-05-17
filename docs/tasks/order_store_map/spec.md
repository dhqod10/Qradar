# 주문하기 지도 검색 기능 명세 (Phase 2 — 지도 탭)

## 개요
- **목적**: 주문 화면의 "지도 검색" 탭을 **Kakao Maps JS SDK** 기반 WebView로 구현한다. Phase 1 리스트 탭과 동일한 `orderStoresProvider`(검색어 + 등급 필터 + 거리순)를 지도 마커로 시각화하고, 마커 탭 → 바텀시트 미니 카드를 통해 매장 선택 플로우를 제공한다.
- **영향 범위**:
  - **신규 파일**
    - `lib/presentation/customer/order/tabs/store_map_tab.dart` — 지도 탭 본체
    - `lib/presentation/customer/order/widgets/kakao_map_view.dart` — WebView 래퍼 + JS Bridge
    - `lib/presentation/customer/order/widgets/store_map_marker_sheet.dart` — 마커 탭 시 바텀시트
    - `assets/map/kakao_map.html` — Kakao Maps JS SDK 로드용 정적 HTML
    - `lib/core/config/map_config.dart` — Kakao JS Key 주입 및 마커 색상 상수
  - **수정**
    - `lib/presentation/customer/order/order_page.dart` — `StoreMapPlaceholderTab` → `StoreMapTab` 교체
    - `pubspec.yaml` — `webview_flutter: ^4.x` 추가, `assets/map/` 등록
    - `ios/Runner/Info.plist` — WebView 관련 ATS 예외 (필요 시 확인만)
    - `android/app/src/main/AndroidManifest.xml` — 이미 INTERNET 권한 있음 (변경 없음)
  - **삭제**
    - `lib/presentation/customer/order/tabs/store_map_placeholder_tab.dart`
  - **도메인/데이터 레이어**: **변경 없음** (`StoreEntity.location.latitude/longitude`, `orderStoresProvider` 그대로 사용)

---

## 요구사항

### 핵심 동작
- [ ] "지도 검색" 탭 진입 시 Kakao Maps 지도 렌더링
- [ ] 지도 중심은 `userLocationProvider` 값 (권한 거부 시 폴백 = 서울 시청)
- [ ] 초기 줌 레벨 = Kakao level 5 (약 1km 반경 뷰)
- [ ] `orderStoresProvider` 의 매장 목록을 마커로 표시
- [ ] 마커는 **등급별 색상** (S=Gold, A=PrimaryBright, B=Primary, C=textMuted)
- [ ] 검색어/등급 필터 변경 시 지도 마커 즉시 갱신 (WebView JS Bridge로 `setStores(json)` 호출)
- [ ] 마커 탭 시 하단 바텀시트로 매장 미니 카드 표시
- [ ] 바텀시트 "주문하기" 버튼 → 현재는 "준비 중" 스낵바 (매장 상세 화면은 별도 task)
- [ ] 우하단 floating "내 위치" 버튼 → 지도 중심을 현재 위치로 복귀
- [ ] 지도 상단에 Phase 1과 동일한 `OrderSearchBar` + `GradeFilterChips` 유지 (탭 간 UX 일관성)

### 상태 UI
- [ ] **로딩**: 지도 영역에 shimmer 배경 또는 단색 placeholder + 중앙 CircularProgressIndicator
- [ ] **에러** (WebView 로드 실패 or 매장 조회 실패): 에러 아이콘 + 메시지 + 재시도 버튼
- [ ] **빈 상태** (마커 0개): 지도는 정상 표시하되 상단에 "조건에 맞는 매장이 없어요" 배너 노출

### 인터랙션
- [ ] 지도 드래그/줌 자유 (JS SDK 기본 동작)
- [ ] 검색바 포커스 시 바텀시트가 열려있으면 자동 닫힘
- [ ] 마커 탭 시 바텀시트 열림 (같은 마커 재탭 시에도 sheet 유지)
- [ ] 탭 외부(지도 빈 영역) 탭 시 바텀시트 닫힘
- [ ] "내 위치" 버튼 탭 시 `moveToUser()` JS 호출 → 현재 위치로 지도 중심 이동 (애니메이션 500ms)

---

## 데이터 모델

### Entity
변경 없음. 기존 `StoreEntity` 재사용.
- `StoreEntity.location.latitude` / `longitude` — 마커 좌표
- `StoreEntity.grade` — 마커 색상 분기
- `StoreEntity.id` — 마커 ↔ 매장 매핑 키
- `StoreEntity.name`, `imageUrl`, `distanceKm`, `grade`, `reviewCount` — 바텀시트 표시

### DTO (WebView 전달용)
마커 렌더링용 JSON 구조 (Dart → JS).

```json
{
  "userLat": 37.5666791,
  "userLng": 126.9782914,
  "stores": [
    {
      "id": "store-abc",
      "name": "스테이브 망원",
      "lat": 37.5555,
      "lng": 126.9077,
      "grade": "S"
    }
  ]
}
```

- grade 는 enum 의 label 대신 코드(S/A/B/C)로 직렬화 (JS 에서 색상 매핑용)
- 이미지/거리/리뷰 등 상세 정보는 JS 쪽에 넘기지 않음 (마커 탭 시 Dart가 id로 `orderStoresProvider` 에서 조회)

---

## 레이어 설계

### Domain
**변경 없음.** 기존 엔티티/유스케이스 그대로 사용.

### Data
**변경 없음.**

### Presentation

**Tab**
- `lib/presentation/customer/order/tabs/store_map_tab.dart`
  - Column: `OrderSearchBar` + `GradeFilterChips` + Expanded(Stack[KakaoMapView, 플로팅 버튼, 바텀시트])
  - `orderStoresProvider` 구독 → `KakaoMapView` 에 stores 전달
  - `userLocationProvider` 구독 → 초기 중심, "내 위치" 버튼 동작
  - 마커 탭 콜백 → 로컬 state `_selectedStoreId` 설정 → `StoreMapMarkerSheet` 노출

**Widgets**
- `lib/presentation/customer/order/widgets/kakao_map_view.dart`
  - `StatefulWidget`, `WebViewController` 관리
  - `assets/map/kakao_map.html` 을 `loadFlutterAsset` 으로 로드
  - Dart → JS:
    - `setStores(List<StoreEntity>, UserLocation)` — 마커 전체 재렌더
    - `moveTo(double lat, double lng)` — 중심 이동 (애니메이션)
  - JS → Dart:
    - `JavaScriptChannel('KakaoMapBridge')` — 페이로드 예: `{"type":"markerTap","id":"store-abc"}`
  - WebView 생명주기:
    - `onPageFinished` 이후에만 `setStores` 호출 (ready flag)
    - dispose 시 별도 정리 불필요 (`WebViewController` 는 GC)

- `lib/presentation/customer/order/widgets/store_map_marker_sheet.dart`
  - `StatelessWidget`, 입력: `StoreEntity` + `VoidCallback onOrderPressed` + `VoidCallback onClose`
  - 구성: 닫기 버튼 + 이미지(`_StoreImage` 재사용 고려) + 이름 + `GradeBadge` + 거리 + "주문하기" 버튼
  - 하단 고정 (`Positioned(bottom: 0)`), 높이 고정 (약 160), 라운드 상단 20

**Core**
- `lib/core/config/map_config.dart`
  - `kakaoJsKey` — `const String.fromEnvironment('KAKAO_JS_KEY')`
  - `markerColorForGrade(StoreGrade)` — 등급 → hex 색상 매핑 (JS 측 JSON 전달용)
  - 초기 줌 `defaultZoomLevel = 5`, 마커 탭 애니메이션 duration 등 상수

**Assets**
- `assets/map/kakao_map.html` — Kakao Maps JS SDK 로드, `window.flutterMap` 객체에 아래 API 제공
  - `window.flutterMap.setStores(payloadJson)` — payload 파싱 후 마커 전체 재생성
  - `window.flutterMap.moveTo(lat, lng)` — `map.panTo(new kakao.maps.LatLng(lat, lng))`
  - 마커 탭 시 `window.KakaoMapBridge.postMessage(JSON.stringify({type:'markerTap', id:'...'}))`
  - 등급별 마커 SVG: 색상 채운 원 + 흰 테두리 + 그림자. 선택 상태 마커는 크기 키움(1.2x) 예정

---

## 데이터 흐름

```
[탭 진입]
StoreMapTab.build
  → orderStoresProvider.watch ─┐
  → userLocationProvider.watch ─┤
                                └─► KakaoMapView(stores, userLocation)
                                     └─ onPageFinished 후 runJs('setStores', payload)

[필터/검색 변경]
orderSearchQueryProvider / orderGradeFilterProvider 갱신
  → orderStoresProvider 파생 재계산
  → StoreMapTab 리빌드 → KakaoMapView 갱신 → runJs('setStores', newPayload)
  (지도 중심/줌은 유지; 마커만 재렌더)

[마커 탭]
JS: marker.click
  → window.KakaoMapBridge.postMessage({type:'markerTap', id:'abc'})
Dart: JavaScriptChannel.onMessageReceived
  → setState(_selectedStoreId = 'abc')
  → 바텀시트 노출

[내 위치 버튼]
버튼 탭 → userLocationProvider.value.latitude/longitude 획득
  → runJs('moveTo', lat, lng)

[바텀시트 닫기 / 지도 빈 영역 탭]
JS: map.click (non-marker)
  → Bridge: {type:'mapTap'}
Dart: setState(_selectedStoreId = null)
```

---

## 에러 처리

| 케이스 | 처리 |
|--------|------|
| `KAKAO_JS_KEY` 미전달 (`--dart-define` 누락) | WebView에 에러 페이지 로드 + Dart 측 debugPrint 경고 |
| WebView 로드 실패 (네트워크 오류) | `NavigationDelegate.onWebResourceError` → 에러 UI 노출 + 재시도 버튼 (`WebViewController.reload`) |
| Kakao SDK 로드 실패 | HTML 내부에서 `window.onerror` catch → `KakaoMapBridge.postMessage({type:'sdkError'})` → Dart 에러 UI |
| `orderStoresProvider` error | 지도는 표시하되 상단 에러 배너 + 재시도 (`ref.invalidate(orderBaseStoresProvider)`) |
| 마커 0개 | 지도 정상 표시 + 상단 얇은 배너 ("조건에 맞는 매장이 없어요") |
| 위치 권한 거부 | 폴백(서울 시청) 좌표로 동작, 내 위치 버튼도 동일 좌표로 이동 (기존 `userLocationProvider` 동작) |

---

## 보안 / 환경 설정

- **Kakao JS Key 노출 특성**: JS SDK 특성상 클라이언트에 노출 불가피. 카카오 콘솔의 "JavaScript SDK 도메인" 제한으로 남용 방지.
- **키 주입 방식**: `--dart-define=KAKAO_JS_KEY=xxx` + `String.fromEnvironment`. 하드코딩/저장소 커밋 절대 금지.
- **WebView 로컬 HTML 로드 스킴**: `flutter_assets://` 또는 `file:///android_asset/...` — JS SDK 도메인 설정에 `http://localhost` 외에 해당 스킴/origin 등록 필요할 수 있음 → developer가 실제 동작 확인 후 가이드 업데이트.
- **이번 task 환경**: 로컬 개발용. 프로덕션 배포 준비 task에서 별도 JS Key(프로덕션용) + 배포 도메인 등록 + 키 분기 로직 추가 예정.

---

## 작업 분배

### designer (우선)
- 지도 탭 전체 레이아웃 (상단 필터 + 지도 영역 + 플로팅 + 바텀시트)
- 마커 디자인 (등급별 색상 4종 SVG 스펙, 선택/비선택 크기 및 테두리)
- 바텀시트 미니 카드 구성 (이미지/이름/등급 뱃지/거리/주문 버튼) — `RecommendedStoreCard` 간소화 버전
- "내 위치" 플로팅 버튼 (AppColors.surfaceElevated 배경, primary 아이콘, 그림자)
- 에러/빈 상태 배너 (지도 위 오버레이)
- 산출물: `docs/tasks/order_store_map/design.md`

### developer (디자인 확정 후)
- `webview_flutter` 의존성 추가 + `pubspec.yaml` assets 등록
- `assets/map/kakao_map.html` 작성 (Kakao JS SDK 로드 + 마커 관리 + Bridge)
- `lib/core/config/map_config.dart` (키 주입, 색상 매핑)
- `kakao_map_view.dart` (WebView 래퍼, JS Bridge)
- `store_map_marker_sheet.dart` (바텀시트)
- `store_map_tab.dart` (탭 본체)
- `order_page.dart` placeholder 교체 + `store_map_placeholder_tab.dart` 삭제
- 실기기/에뮬레이터에서 JS Key 주입 후 지도 렌더링 확인
- 산출물: 코드 + `docs/tasks/order_store_map/implementation.md`

### tester (구현 후)
- spec 기준 동작 검증 (마커 렌더, 필터 동기화, 내 위치 이동, 바텀시트 열고 닫기)
- design 기준 UI 검증 (마커 색상 매핑, 바텀시트 레이아웃, 플로팅 버튼)
- 에러/빈 상태 UI 확인
- JS Key 누락 시 에러 처리 확인
- 산출물: `docs/tasks/order_store_map/test_report.md`

---

## 후속 task (본 task 범위 외)

- **매장 상세 화면**: 바텀시트의 "주문하기" 버튼 → 매장 상세 이동. `onTap` 교체만 필요.
- **프로덕션 키 분기**: 환경별 JS Key 자동 선택 + 배포 도메인 등록 (Phase 3 배포 준비).
- **마커 클러스터링**: 매장 수 급증 시 근접 마커 클러스터 표시 (현재는 최대 50개 제한이라 불필요).
- **네이티브 SDK 전환**: 성능 이슈 발생 시 WebView → iOS/Android 네이티브 Kakao Maps SDK 로 교체. (현 아키텍처에서 `KakaoMapView` 위젯만 교체하면 되도록 설계.)
