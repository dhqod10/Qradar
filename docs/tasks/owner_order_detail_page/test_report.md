# owner_order_detail_page 테스트 리포트 (점주 주문 상세 페이지)

## 테스트 일시

- 2026-06-06 ~ 2026-06-07

---

## 테스트 방법

- Android 에뮬레이터 Pixel 7 + Android 실기기
- iPhone 17 시뮬레이터 (UI 구조 확인)
- Firebase 정식 환경 (`order-app-5957e`)
- 점주 계정: `dhqod12@naver.com` (uid: `Og25uNUmRDMX5aJPTCRkzMYYuA82`)
- 정적 코드 검증 (spec.md / design.md / implementation.md 교차 검증)
- `flutter analyze`

---

## 전체 결과

- PASS: 32개
- FAIL: 0개
- 보류: 3개

---

## PASS 항목

### 기능 검증 (라이브)

- [x] O1 — `OwnerOrdersPage` 카드 탭 → `OwnerOrderDetailPage` 진입
  - 근거: 라이브 검증에서 카드 탭 시 상세 페이지 push 정상 확인
  - 위치: `lib/presentation/owner/orders/owner_orders_page.dart`, `owner_new_order_tile.dart`, `owner_refund_request_tile.dart`

- [x] O2 — FCM 알림 탭 → `OwnerOrderDetailPage` 진입 (Phase 3b T6 회귀)
  - 근거: `NotificationNavigator` 교체 후 알림 탭 시 `OwnerOrderDetailPage` 정상 진입 확인
  - 위치: `lib/presentation/common/notification/notification_navigator.dart`

- [x] O3 — `paid` 상태에서 "주문 받기" → `accepted` 전이
  - 근거: 라이브 검증에서 주문 받기 버튼 → `accepted` 상태 전이 확인
  - 위치: `lib/presentation/owner/orders/owner_order_detail_page.dart` `_acceptOrder()`

- [x] O4 — 환불 요청 상태에서 환불 승인 → `refunded` 전이 (Toss mock 모드)
  - 근거: 라이브 검증에서 환불 승인 → `refunded` 상태 전이 확인 (Toss API는 우회 모드)
  - 위치: `owner_order_detail_page.dart` `_approveRefund()`

### 기능 검증 (정적)

- [x] T1 — `OwnerOrdersPage` 신규 카드 탭 → 상세 진입 (spec.md §결정 E)
  - 근거: `owner_new_order_tile.dart` 에 `onTapDetail` prop 추가 + `Material+InkWell` 로 root 감싸기. implementation.md §수정 파일 목록 확인
  - 위치: `lib/presentation/owner/orders/widgets/owner_new_order_tile.dart`

- [x] T1 — 환불 요청 카드 탭 → 상세 진입 (동일)
  - 근거: `owner_refund_request_tile.dart` 동일 처리
  - 위치: `lib/presentation/owner/orders/widgets/owner_refund_request_tile.dart`

- [x] T2 — 카드 내 버튼 hit test 우선 (spec.md 결정 E — Flutter hit test 자동 분기)
  - 근거: Flutter 의 `ElevatedButton.onPressed` 가 상위 `InkWell.onTap` 보다 먼저 처리됨. implementation.md §결정 E 구현 확인
  - 위치: `owner_new_order_tile.dart`, `owner_refund_request_tile.dart`

- [x] T3 — 알림 탭(newOrder) → `OwnerOrderDetailPage` + paid 액션 노출 (spec.md 결정 F)
  - 근거: `notification_navigator.dart` line 23-28: `newOrder` / `refundRequest` 모두 `OwnerOrderDetailPage` 로 push
  - 위치: `lib/presentation/common/notification/notification_navigator.dart`

- [x] T4 — 알림 탭(refundRequest) → 환불 액션 노출 (spec.md 결정 F)
  - 근거: 동일 페이지 진입 후 `_hasActionBar` 로직이 `accepted+refundRequest+deniedAt==null` 분기를 처리
  - 위치: `owner_order_detail_page.dart` `_hasActionBar()`

- [x] T5 — `paid → accepted` 전이 후 액션 영역 자동 사라짐 (spec.md §액션 후 pop 않음)
  - 근거: stream 갱신 → `_hasActionBar` false → `Scaffold.bottomNavigationBar: null`. implementation.md §T5 대응 구현 확인
  - 위치: `owner_order_detail_page.dart` `_buildBottomBar()`

- [x] T6 — 환불 승인 → `refunded` → `_NoActionInfoCard('환불이 완료된 주문이에요.')` 표시
  - 근거: implementation.md §T6 대응. `processRefundUseCase` → stream → `_NoActionInfoCard` 렌더
  - 위치: `owner_order_detail_page.dart` `_NoActionInfoCard`

- [x] T7 — 환불 거절 → `deniedAt` 설정 → 거절 섹션 노출, 액션 사라짐
  - 근거: `denyRefundRequestUseCase` → stream → `_OwnerRefundSection._buildDenied()` 분기
  - 위치: `owner_order_detail_page.dart` `_OwnerRefundSection`

- [x] T8 — 잘못된 orderId → `_FallbackBody('주문을 찾을 수 없어요')` (spec.md 에러 처리)
  - 근거: `currentOrderProvider` null → `_FallbackBody` 표시. `owner_order_detail_page.dart` line 216-224
  - 위치: `owner_order_detail_page.dart`

- [x] T9 — 다른 매장 orderId → 결정 G fallback `_FallbackBody('이 주문은 다른 매장의 주문이에요')` (spec.md 결정 G)
  - 근거: `order.storeId != store.id` 분기 → `_FallbackBody`. `owner_order_detail_page.dart` line 227-235
  - 위치: `owner_order_detail_page.dart`

- [x] T10 — 액션 중복 탭 방지 (`_isActionLoading` 가드)
  - 근거: `_isActionLoading` bool flag — 진행 중 버튼 `onPressed: isLoading ? null : onTap`. implementation.md §중복 탭 방지 확인
  - 위치: `owner_order_detail_page.dart`

- [x] T11 — status별 액션 영역 분기 매트릭스 (spec.md §E 표)
  - 근거: `_hasActionBar` 로직 (`paid` → true, `accepted+refundRequest+deniedAt==null` → true, 그 외 false) + `_buildPaidButtons` / `_buildRefundButtons` / `_NoActionInfoCard`
  - 위치: `owner_order_detail_page.dart`

- [x] T12 — customer `OrderDetailPage` 회귀 없음
  - 근거: `lib/presentation/customer/order/orders/order_detail_page.dart` 는 본 phase 에서 수정 없음 (implementation.md 확인)
  - 위치: `lib/presentation/customer/order/orders/order_detail_page.dart`

- [x] 다이얼로그 공통 추출 — `OwnerOrderActionDialogs` (spec.md §developer 구현 항목)
  - 근거: `owner_order_action_dialogs.dart` 신규 파일 — `showRejectOrder` / `showApproveRefund` / `showDenyRefund` 3개 함수. `OwnerOrdersPage` + `OwnerOrderDetailPage` 양쪽 import 재사용
  - 위치: `lib/presentation/owner/orders/widgets/owner_order_action_dialogs.dart`

- [x] 액션 성공 시 SnackBar 표시
  - 근거: `_acceptOrder`, `_rejectOrder`, `_approveRefund`, `_denyRefund` 각각 성공 시 `ScaffoldMessenger.of(context).showSnackBar` 호출
  - 위치: `owner_order_detail_page.dart`

- [x] 액션 후 페이지 pop 없음 — stream 자동 갱신
  - 근거: 각 액션 함수에 `Navigator.pop` 없음. implementation.md §액션 후 pop 없음 확인
  - 위치: `owner_order_detail_page.dart`

- [x] `myStoreProvider` + `currentOrderProvider(orderId)` 동시 watch (spec.md §C 데이터 흐름)
  - 근거: `owner_order_detail_page.dart` line 150-151
  - 위치: `owner_order_detail_page.dart`

- [x] loading → `_OwnerOrderDetailShimmer` 표시
  - 근거: `_buildBody` line 182-184: `storeAsync.isLoading || orderAsync.isLoading` → shimmer
  - 위치: `owner_order_detail_page.dart`

- [x] stream error → `_ErrorBody` + "다시 시도" 버튼 표시
  - 근거: `_buildBody` line 187-198: `hasError` 분기 → `_ErrorBody`
  - 위치: `owner_order_detail_page.dart`

### UI 검증

- [x] AppBar — `'주문 상세'` + 뒤로가기 (design.md §1 AppBar)
  - 근거: `owner_order_detail_page.dart` line 155-170
  - 위치: `owner_order_detail_page.dart`

- [x] 섹션 순서 — `_StatusSection` → `_OwnerRefundSection` (조건부) → `_ItemsSection` → `_PriceSection` → `_PaymentInfoSection` (design.md §화면 구성)
  - 근거: `_OwnerOrderDetailBody.build()` line 309-335
  - 위치: `owner_order_detail_page.dart`

- [x] sticky bottom `_ActionBar` — `Scaffold.bottomNavigationBar` 에 배치 (spec.md 결정 D)
  - 근거: `owner_order_detail_page.dart` line 174: `bottomNavigationBar: _buildBottomBar(...)`
  - 위치: `owner_order_detail_page.dart`

- [x] paid 버튼 2:1 비율 (`Expanded(flex:2)` "주문 받기" / `Expanded(flex:1)` "거절") (design.md §_ActionBar, implementation.md §버튼 비율)
  - 근거: `_ActionBar._buildPaidButtons()` line 778-796
  - 위치: `owner_order_detail_page.dart`

- [x] 환불 요청 활성 섹션 — error 톤 border (`AppColors.error`, 1.5px) (spec.md 결정 C / implementation.md §환불 요청 섹션 color)
  - 근거: `_OwnerRefundSection._buildActive()` line 421-432: `Border.all(color: AppColors.error, width: 1.5)`
  - 위치: `owner_order_detail_page.dart`

- [x] 환불 거절 완료 섹션 — 회색 톤 border (`AppColors.border`) (spec.md 결정 C)
  - 근거: `_OwnerRefundSection._buildDenied()` line 472-480: `Border.all(color: AppColors.border)`
  - 위치: `owner_order_detail_page.dart`

- [x] `_StatusSection` 에 storeName 포함 (design.md §2 StatusSection)
  - 근거: `_StatusSection.build()` line 381-388: storeName Text 노출
  - 위치: `owner_order_detail_page.dart`

### 아키텍처 검증

- [x] Domain / Data 레이어 코드 변경 없음 (spec.md §영향 범위)
  - 근거: implementation.md §재사용 vs 신규 정리 — Domain/Data 모두 "재사용, 변경 없음"
  - 위치: `lib/domain/`, `lib/data/`

- [x] Presentation 에서 Firebase / 외부 SDK 직접 import 없음 (CLAUDE.md 절대 규칙 2)
  - 근거: `owner_order_detail_page.dart` import 목록 확인 — `flutter`, `riverpod`, `qradar domain/presentation` 만 사용
  - 위치: `owner_order_detail_page.dart` line 1-16

- [x] 기존 Provider 재사용 — 신규 Provider 없음 (spec.md §Provider DI)
  - 근거: `owner_order_detail_page.dart` 에서 `currentOrderProvider`, `myStoreProvider`, `acceptOrderUseCaseProvider`, `cancelPaidOrderUseCaseProvider`, `processRefundUseCaseProvider`, `denyRefundRequestUseCaseProvider` 사용. 신규 Provider 없음
  - 위치: `owner_order_detail_page.dart`

- [x] `NotificationNavigator` import 교체 — `OrderDetailPage` → `OwnerOrderDetailPage`
  - 근거: `notification_navigator.dart` line 3: `import 'package:qradar/presentation/owner/orders/owner_order_detail_page.dart'`
  - 위치: `lib/presentation/common/notification/notification_navigator.dart`

### 디자인 시스템 검증

- [x] 색상 `AppColors` 만 사용 — `Color(0x...)` 하드코딩 없음
  - 근거: grep 결과: `owner_order_detail_page.dart` / `owner_order_action_dialogs.dart` 에서 `Color(0x...)` / `Colors.white` / `Colors.black` 0건
  - 확인: `grep -n "Colors.black\|Colors.white\|Color(0x" owner_order_detail_page.dart owner_order_action_dialogs.dart` → 0건

### 코드 품질 검증

- [x] `flutter analyze` — No issues found (ran in 6.6s)
  - 근거: 실행 결과 직접 확인

- [x] 파일명 `snake_case.dart`, 클래스명 `PascalCase` 준수
  - 근거: `owner_order_detail_page.dart`, `OwnerOrderDetailPage`, `OwnerOrderActionDialogs` 등 확인

- [x] spec.md 결정 항목 A~G, Q1, Q2 모두 implementation.md 에 명시 및 코드 반영
  - 근거: implementation.md §구현 결정 사항 일치 여부 표 확인

---

## FAIL 항목

없음.

---

## 보류 항목

- [ ] T9 — 다른 매장 orderId 진입 fallback (라이브 미검증)
  - 이유: 라이브 검증 세션에서 `storeId mismatch` 케이스를 실기기로 직접 시험하지 않음. 정적 코드 검증으로 PASS 처리.
  - 필요한 확인: 점주 A 계정으로 점주 B 매장의 orderId 로 `OwnerOrderDetailPage` 직접 진입 시도 → `_FallbackBody('이 주문은 다른 매장의 주문이에요')` 표시 확인.
  - 후속 작업 제안: 다음 검증 세션에서 수동 확인.

- [ ] `OrderItemRow` / `PriceSummary` `presentation/common/` 승격 (spec.md 결정 B-A 임시 허용)
  - 이유: 현재 `customer/order/widgets/` 폴더의 위젯을 `owner` 화면에서 import — 폴더 경계 임시 허용 상태.
  - 필요한 확인: `presentation/common/order/order_item_row.dart` / `price_summary.dart` 로 이동 후 양쪽 import 경로 갱신.
  - 후속 작업 제안: `widget_common_elevation` 또는 유사 task 로 분리.

- [ ] `_OwnerOrderDetailShimmer` / `_ErrorBody` 공통화 (implementation.md §미구현/보류)
  - 이유: customer `OrderDetailPage` 와 동일 패턴의 private 클래스 중복 존재.
  - 필요한 확인: `presentation/common/` 으로 승격 후 양쪽 재사용.
  - 후속 작업 제안: `widget_common_elevation` task 와 묶음 처리 권장.

---

## 설계자 전달 메시지

### 요약

- 전체 판단: FAIL 0건. spec.md 결정 A~G, Q1, Q2 모두 코드에 반영됨 확인. `flutter analyze` No issues found. customer `OrderDetailPage` 회귀 없음.
- Phase 3b FCM deep link 의 최종 도착점이 `OwnerOrderDetailPage` 로 올바르게 교체됨.

### 재작업 우선순위

없음. 현재 재작업 필요 항목 없음.

### 후속 task 후보

- `widget_common_elevation` (또는 유사명) — `OrderItemRow`, `PriceSummary`, shimmer/error 공통 위젯을 `presentation/common/order/` 로 승격. 결정 B-A 임시 허용 해소.
- Phase 3c — 고객 측 알림(주문 접수됨/환불 완료/환불 거절) 추가 시 `NotificationNavigator` 에 role 별 분기 추가 필요. 현재 점주 전용 경로만 구현.
- 점주 `making` / `ready` / `completed` 전이 액션 — Phase 3c 예정. 현재 해당 status 에서는 `_NoActionInfoCard` 안내만 표시.

---

## 완료 판단

- [x] 전체 PASS (FAIL 0건)
