# owner_order_detail_page 기능 명세 (점주 주문 상세 페이지 신규 추가)

> Phase 3b FCM 알림 인프라 도입 이후 발견된 점주 측 UX 누락 보강.  
> 단일 진실원 / 참고:  
> - 큰 그림: [docs/order_flow_summary.md](../../order_flow_summary.md)  
> - 역할 흐름: [docs/processes/role_flows.md](../../processes/role_flows.md) §4.2  
> - 엔티티 lifecycle: [docs/processes/entity_lifecycle.md](../../processes/entity_lifecycle.md) §2 (Order)  
> - 데이터 소유권: [docs/processes/data_ownership.md](../../processes/data_ownership.md) §2.4 (orders.update O1·O3)  
> - 직전 phase: [docs/tasks/order_flow_phase3b/spec.md](../order_flow_phase3b/spec.md), [implementation.md](../order_flow_phase3b/implementation.md)

---

## 개요

- **목적**: Phase 3b 의 FCM deep link 가 현재 `customer/order_detail_page.dart` (고객용) 로 이동하기 때문에 점주가 알림을 탭해도 "주문 받기 / 거절 / 환불 승인·거절" 같은 액션을 수행할 수 없는 문제를 해결한다. 추가로 `OwnerOrdersPage` 카드 영역을 탭해서도 동일 상세 페이지에 진입할 수 있는 경로를 제공한다.
- **작업 유형**: 신규 화면 추가 + 기존 화면 onTap 추가 + 알림 navigator 분기 수정. **Domain / Data / Cloud Functions / Firestore Rules 변경 없음** (기존 UseCase / Repository / Provider 전부 재사용).
- **트리거 진입점**: (a) FCM 알림 탭 (`NotificationType.newOrder` / `NotificationType.refundRequest`) (b) `OwnerOrdersPage` 의 신규 주문 카드 탭 (c) `OwnerOrdersPage` 의 환불 요청 카드 탭.
- **수신 대상 role**: `owner` 만. 고객 / 브랜드 / 관리자는 본 phase 비범위 (고객은 기존 `OrderDetailPage` 유지).

### 영향 범위

| 레이어 | 영향 |
|---|---|
| **Presentation (신규)** | `lib/presentation/owner/orders/owner_order_detail_page.dart` (신규 페이지) / (옵션) `lib/presentation/owner/orders/widgets/` 하위 작은 분할 위젯 (designer 산출에 따라 결정) |
| **Presentation (수정)** | `lib/presentation/owner/orders/owner_orders_page.dart` — 카드 onTap 추가 (받기/거절 / 승인/거절 버튼과 hit 충돌 없게) / `lib/presentation/common/notification/notification_navigator.dart` — `OrderDetailPage` → `OwnerOrderDetailPage` 분기 변경 |
| **Domain / Data** | **변경 없음** — `currentOrderProvider`, `acceptOrderUseCase`, `cancelPaidOrderUseCase`, `processRefundUseCase`, `denyRefundRequestUseCase`, `OrderRepository.watchOrder` 모두 그대로 재사용 |
| **Provider DI** | `order_di_providers.dart` 의 기존 provider 재사용. 신규 provider 불필요. (단, `OwnerOrderDetailPage` 가 `myStoreProvider` / `currentUserProfileProvider` 를 사용해 권한 검증을 보조할 수는 있음 — §"권한 / 안전 가드" 참조) |
| **Cloud Functions** | 변경 없음 |
| **Firestore Rules** | 변경 없음 (점주의 paid→accepted = O1, 환불 거절 = O3 모두 기존 Rules 통과) |
| **공통 컴포넌트** | `OrderStatusBadge`, `OrderItemRow`, `PriceSummary` 재사용 |
| **라우팅** | `Navigator.push(MaterialPageRoute(...))` 패턴 유지 (Phase 3a/3b 와 일관) |
| **테스트** | UI 테스트(액션 분기, refundRequest 분기, 권한 없는 orderId 진입), 알림 deep link 통합 테스트 |

### 비범위

- 고객용 `OrderDetailPage` 동작 / UI 변경 — 그대로 유지.
- FCM 인프라 (`functions/onOrderCreated.ts`, `onOrderRefundRequested.ts`, payload 스키마) 변경 — Phase 3b 에서 확정.
- 고객 측 알림 (주문 접수됨 / 환불 완료 / 환불 거절) — Phase 3c 또는 별 phase.
- 점주의 `making` / `ready` / `completed` 전이 액션 (Phase 3c 예정).
- 부분 환불 / 환불 사유 카테고리화 / 환불 채팅 — 별 phase.
- 알림 본문 / 톤 변경 (Phase 3b 결정 I 유지).
- 점주의 주문 이력(완료/취소/환불 목록) 별도 페이지 — 별 phase. 본 phase 는 **단건 상세** 만.
- `OwnerOrdersPage` 의 탭/필터 구조 변경 — 그대로 유지.

---

## 사용자 결정 사항 (확정)

| # | 항목 | 확정안 |
|---|---|---|
| Q1 | `OwnerOrdersPage` 카드 디자인 | 카드 내 받기/거절(또는 승인/거절) 버튼 **유지** + 카드 영역(버튼 제외) 탭 시 상세 페이지 push (둘 다 가능) |
| Q2 | `OwnerOrderDetailPage` 의 환불 액션 노출 조건 | **`accepted` 상태 + `refundRequest != null` + `refundRequest.deniedAt == null`** 일 때만 "환불 승인 / 환불 거절" 표시 (현재 `OwnerOrdersPage` 탭 2 와 정합) |

---

## architect 잠정 결정 (사용자 확인 후보)

⚠ 아래 결정 A~G 는 architect 잠정안. 사용자 확인 후 designer 호출.

### 결정 A. status badge 위치 / 디자인 — (B) 본문 상단 카드 (architect 추천)

| 옵션 | 장점 | 단점 |
|---|---|---|
| (A) AppBar 우측 영역 | 화면 상단에서 즉시 확인 | AppBar 가 좁아 badge + 주문번호 동시 노출 어려움 |
| **(B) 본문 상단 카드 (현재 customer `OrderDetailPage` 와 동일 패턴 — `_StatusSection`)** (architect 추천) | 기존 customer 페이지와 시각 일관 + 주문번호 / 시각 / 매장명 함께 묶기 자연스러움. `OrderStatusBadge(size: large)` 사용 | 페이지 상단 공간 차지 |
| (C) AppBar title 자체에 badge 임베드 | 컴팩트 | 액션 버튼/뒤로가기와 시각 충돌 |

채택 = **(B)**. AppBar 는 `'주문 상세'` 텍스트만, 본문 첫 섹션이 `_StatusSection` (badge + 주문번호 + createdAt + storeName).

### 결정 B. 메뉴 리스트 `selectedOptions` 표시 — (A) customer 측 `OrderItemRow` 그대로 재사용 (architect 추천)

| 옵션 | 장점 | 단점 |
|---|---|---|
| **(A) `lib/presentation/customer/order/widgets/order_item_row.dart` 그대로 import 재사용** (architect 추천) | 단일 진실원 / 시각 일관 / DRY | customer 폴더의 위젯을 owner 화면이 import — 폴더 경계 위반 우려 |
| (B) 동일 디자인을 `presentation/common/order/order_item_row.dart` 로 승격 후 양쪽이 import | 폴더 경계 명확 | 본 phase 가 리팩터링 범위 확장됨 |
| (C) owner 전용 `OwnerOrderItemRow` 신규 작성 | 점주가 보고 싶은 정보(예: 옵션 강조) 별도 튜닝 가능 | 동일 도메인 모델을 두 위젯이 그림 — 중복 |

채택 = **(A)**. 폴더 경계가 신경 쓰이면 **후속 task** 로 `presentation/common/order/` 승격 — 본 phase 비범위. designer 검토 후 (B) 채택해도 무방.

**표시 정보** (현행 `OrderItemRow` 동작 그대로):  
- 메뉴 이름 / 수량 / 단가  
- selectedOptions (옵션 그룹 → 옵션 이름 / 가격 가산)  
- 라인 합계  

### 결정 C. 환불 요청 정보 표시 위치 — (B) 별도 섹션 카드 (status badge 카드 아래 / 메뉴 리스트 위) (architect 추천)

| 옵션 | 장점 | 단점 |
|---|---|---|
| (A) status badge 카드 안에 인라인 표시 | 컴팩트 | 환불 사유가 길면 badge 카드 비대화 |
| **(B) 별도 섹션 카드** (architect 추천) | 환불 사유 / 요청 시각 / (이미 거절된 경우) 거절 메타 명확히 분리. 점주가 주문 상세를 위에서부터 스캔 시 "환불 요청 있음" 이 시각적으로 강조됨. customer `OrderDetailPage` 의 `_RefundRequestStatusSection` 패턴 재사용 가능 | 페이지 길이 증가 |
| (C) 페이지 하단 별도 expandable | 점주가 주문 메뉴를 먼저 확인 후 환불 정보 확인 | 즉시성 떨어짐 |

채택 = **(B)**. 환불 요청이 있을 때만 노출(없으면 섹션 자체 미렌더). 거절된 환불 요청(`deniedAt != null`)은 별도 시각(error 색상)으로 표시 (customer `_RefundDeniedSection` 패턴 참조).

### 결정 D. 액션 버튼 영역 — (A) sticky bottom (architect 추천)

| 옵션 | 장점 | 단점 |
|---|---|---|
| **(A) `bottomNavigationBar` 또는 `Scaffold.bottomSheet` 로 sticky bottom 고정** (architect 추천) | 긴 주문(메뉴 다수)에서도 액션 버튼 항상 접근 가능. 모바일 UX 베스트 프랙티스. `OwnerOrdersPage` 카드 버튼과 다른 위계 — 상세 페이지 = 액션 페이지 의미 강조 | sticky 영역이 본문 일부 가림 → `SingleChildScrollView` padding 하단 보강 필요 |
| (B) 본문 하단 (스크롤 내) | 구현 단순 (현재 customer `_ActionSection` 패턴 동일) | 메뉴 5개 이상 주문에서 액션 도달까지 스크롤 필요 — 점주는 빠른 응답이 핵심이라 불리 |

채택 = **(A)**. 액션이 없는 status (`making`, `ready`, `completed`, `cancelled`, `refunded`, 또는 환불 요청 없는 `accepted`) 에서는 bottom 영역 자체 미렌더 (Scaffold 본문이 전체 차지).

### 결정 E. `OwnerOrdersPage` 카드 onTap hit 영역 — (A) 카드 전체를 `InkWell` 로 감싸고 버튼 영역에 `GestureDetector` 흡수 (architect 추천)

| 옵션 | 장점 | 단점 |
|---|---|---|
| **(A) 카드 외곽 `InkWell.onTap = pushDetail` + 버튼은 그대로 (Flutter `ElevatedButton` 의 tap 이 우선됨)** (architect 추천) | Flutter 의 hit test 가 자식 위젯의 tap handler 를 먼저 처리 → 자동으로 버튼이 우선. 코드 단순. ripple 효과까지 제공 | 버튼 사이 갭(8px) 영역은 카드 tap 으로 인식 — 사용자가 "거의 버튼을 눌렀다" 라고 느낄 수 있음 (수용 가능 수준) |
| (B) `GestureDetector` 카드 외곽 + 버튼 wrapper 에 `behavior: HitTestBehavior.opaque` 명시 | 명시적 hit 제외 | 코드 더 복잡 |
| (C) "상세 보기" 별도 버튼/링크 추가 | 명확 | 카드 안에 버튼 3개 → 시각 노이즈 |

채택 = **(A)**. `OwnerNewOrderTile` / `OwnerRefundRequestTile` 의 root `Container` 를 `Material` + `InkWell` 로 감싸고 `onTap: () => Navigator.push(OwnerOrderDetailPage(orderId))` 추가. 기존 버튼은 그대로.

### 결정 F. T6/T7 (FCM 알림 탭) 진입 시 동일 페이지 사용 — (A) Yes (architect 추천)

`NotificationType.newOrder` 와 `NotificationType.refundRequest` 모두 `OwnerOrderDetailPage(orderId: ...)` 로 push.  
환불 액션 노출 여부는 페이지 내부의 status / refundRequest 검사 로직이 자동 분기 → 알림 종류 별도 인자 불필요.

### 결정 G. 권한 / 안전 가드 — (B) 페이지 내부에서 storeId 매칭 검사 + fallback UI (architect 추천)

배경: Firestore Rules 에 의해 `orders.read` 는 `userId == uid OR storeOwner(storeId) OR admin` 이 통과. 즉 점주가 본인 매장 주문이 아닌 다른 매장의 orderId 로 강제 진입을 시도해도 Rules 단에서 stream error 가 날 가능성. 또한 FCM 메시지가 stale 한 orderId 를 가져왔을 가능성.

| 옵션 | 처리 |
|---|---|
| (A) 페이지 내부 검증 없음, Rules / stream error 만 신뢰 | 구현 단순. error UI 가 모든 케이스 흡수 |
| **(B) 페이지 진입 직후 `currentOrderProvider` data 도착 시 점주의 `myStoreProvider.id != order.storeId` 면 안내 + pop** (architect 추천) | 의도 명확. 잘못된 알림 deep link / 오랜 시간 후 알림 탭 케이스에서 사용자가 혼란 안 겪음 | 코드 약간 증가 |
| (C) Cloud Function trigger 단에서 orderId-ownerUid 매칭 사전 검증 | 본 phase 비범위 (Phase 3b 트리거는 이미 그렇게 함) | — |

채택 = **(B)**. `OwnerOrderDetailPage` 가 `myStoreProvider` 와 `currentOrderProvider(orderId)` 를 동시 watch → mismatch 면 friendly empty state + "주문 목록으로 가기" 버튼 노출.

---

## 요구사항

### 기능 요구사항

#### 신규 페이지 (`OwnerOrderDetailPage`)

- [ ] orderId 파라미터로 진입. `currentOrderProvider(orderId)` stream watch.
- [ ] status / 주문번호(앞 12자) / createdAt(yyyy.MM.dd HH:mm) / 매장명 표시.
- [ ] `refundRequest != null` 이면 환불 요청 정보 섹션 노출 (사유 / 요청 시각 / 거절된 경우 거절 메타).
- [ ] 메뉴 리스트 (selectedOptions 포함) — `OrderItemRow` 재사용 (결정 B).
- [ ] 가격 요약 — `PriceSummary` 재사용.
- [ ] 결제 정보 (방법 / paymentKey 마스킹 / 영수증 링크 / 카드 정보 / 결제 금액) — customer 페이지의 `_PaymentInfoSection` 디자인 그대로 (재사용 또는 owner 측 동일 위젯 인라인).
- [ ] 액션 분기 (결정 D — sticky bottom):
  - `status == OrderStatus.paid` → "주문 받기" (primary, ElevatedButton) + "거절" (outlined error)
  - `status == OrderStatus.accepted && refundRequest != null && refundRequest.deniedAt == null` → "환불 승인" (primary) + "환불 거절" (outlined)
  - 그 외 (`accepted` 인데 환불 요청 없음, `making`/`ready`/`completed`/`cancelled`/`refunded`) → bottom 영역 미렌더 (또는 "추가 액션 없음" status 안내 inline 카드 — 결정 D 의 (B) 패턴, **확인 필요**)
- [ ] 액션 다이얼로그는 `OwnerOrdersPage` 의 기존 다이얼로그(`_showRejectOrderDialog`, `_showApproveRefundDialog`, `_showDenyRefundDialog`) 와 **동일한 디자인 / 동일한 텍스트** 유지 — 공통 위젯으로 추출 권장 (designer / developer 합의):
  - `presentation/owner/orders/widgets/owner_order_action_dialogs.dart` (신규) 로 추출
- [ ] 액션 성공 시 SnackBar 표시 (`OwnerOrdersPage` 동일 카피).
- [ ] 액션 진행 중 버튼 disable + spinner.
- [ ] 액션 후 페이지 pop **하지 않음** — stream 이 status 갱신을 받아 자동으로 액션 영역 재구성. (예: paid → accepted 전이 후 환불 액션은 refundRequest 가 없으므로 미노출.)
- [ ] 권한 / 안전 가드 (결정 G):
  - 점주의 `myStoreProvider` data 와 `order.storeId` 비교 → 불일치 시 fallback empty state ("이 주문은 다른 매장의 주문이에요" + 뒤로가기 안내).
  - `currentOrderProvider` 가 null (주문 없음) → "주문을 찾을 수 없어요" 안내.
  - stream error → 기존 customer `_ErrorBody` 패턴 (retry).
- [ ] 로딩 상태 — shimmer (customer `_OrderDetailShimmer` 패턴 참조).

#### `OwnerOrdersPage` 수정 (카드 onTap)

- [ ] 신규 주문 카드 (`OwnerNewOrderTile`) root 를 `InkWell` (또는 `Material + InkWell`) 로 감싸 `onTap` → `Navigator.push(OwnerOrderDetailPage(orderId: order.id))`.
- [ ] 환불 요청 카드 (`OwnerRefundRequestTile`) 동일 처리.
- [ ] 카드 내 받기 / 거절 / 승인 / 거절 버튼은 그대로 유지. Flutter hit test 가 자식 우선이므로 자동 분기 (결정 E).
- [ ] 시각 변화 (ripple) 가 너무 도드라지지 않게 `InkWell.splashColor` 톤다운 — designer 결정.

#### `NotificationNavigator` 수정

- [ ] `lib/presentation/common/notification/notification_navigator.dart` 의 import 를 `OrderDetailPage` → `OwnerOrderDetailPage` 로 교체.
- [ ] switch case (`newOrder` / `refundRequest`) 의 `MaterialPageRoute` builder 를 `OwnerOrderDetailPage(orderId: orderId)` 로 변경.
- [ ] `NotificationType.unknown` 는 기존대로 no-op.
- [ ] (참고) 현재 알림은 점주만 받음 (Phase 3b). 향후 고객 알림이 추가되면 navigator 가 role 별 분기 필요 — 본 phase 비범위.

### UI 요구사항 (designer 위임)

- [ ] AppBar: `'주문 상세'` 타이틀 + 뒤로가기.
- [ ] 본문 섹션 순서: `_StatusSection` → (조건부) `_RefundRequestSection` → `_StoreSection` (또는 status 카드에 매장명 통합) → `_ItemsSection` → `_PriceSection` → `_PaymentInfoSection`.
- [ ] sticky bottom 액션 영역: 가로 full width, 좌 = primary (받기/승인), 우 = outlined error (거절). 비율은 designer 가 결정 (현재 `OwnerNewOrderTile` 의 `Expanded + width:80` 비대칭은 카드에선 자연스럽지만 상세 페이지의 sticky bar 에선 `Expanded(2) : Expanded(1)` 또는 `1:1` 검토 필요).
- [ ] 환불 거절 상태 (`deniedAt != null`) 노출 시 — 사유 표시 + "이미 거절된 요청" 회색 톤 + 액션 버튼 미노출.
- [ ] 상태별 status badge 색상은 기존 `OrderStatusBadge` 사용.
- [ ] 색상은 `AppColors` 만 사용 (절대 규칙).

### 상태 요구사항

| 상태 | UI |
|---|---|
| loading | shimmer (customer `_OrderDetailShimmer` 패턴) |
| error (stream error) | "다시 시도" 버튼 포함 (customer `_ErrorBody` 패턴) |
| empty (주문 없음 / 다른 매장 주문) | 안내 텍스트 + "주문 목록" 으로 돌아가기 (back) |
| 액션 진행 중 | bottom 영역 버튼 disabled + spinner |
| 액션 완료 직후 | SnackBar + stream 자동 갱신 → bottom 영역 자동 재계산 |

---

## 데이터 모델

본 phase 는 **데이터 모델 변경 없음**. 기존 `OrderEntity`, `RefundRequestEntity`, `PaymentInfoEntity`, `OrderItemEntity` 그대로 사용.

참고 — 결정 분기에 사용하는 필드:
- `order.status` (`OrderStatus`) — 액션 분기 핵심
- `order.refundRequest` (`RefundRequestEntity?`) — 환불 요청 존재 여부
- `order.refundRequest.deniedAt` (`DateTime?`) — 환불 거절 여부
- `order.storeId` — 권한 가드 (결정 G)

---

## 레이어 설계

### Domain (변경 없음)

기존 그대로 사용:
- `OrderEntity` / `OrderStatus` / `RefundRequestEntity`
- `OrderRepository.watchOrder(orderId)`
- `AcceptOrderUseCase`
- `CancelPaidOrderUseCase` (점주 거절 시 `approvedBy: 'owner'`)
- `ProcessRefundUseCase` (환불 승인)
- `DenyRefundRequestUseCase` (환불 거절)
- `WatchOrderUseCase`

### Data (변경 없음)

기존 그대로 사용:
- `OrderRepositoryImpl` / `OrderRemoteDataSource`
- `PaymentGatewayRepositoryImpl` (cancel / refund CF 호출)
- `CloudFunctionsRemoteDataSource`

### Presentation

#### 신규 파일

```
lib/presentation/owner/orders/
├── owner_order_detail_page.dart            # 신규 — 본 phase 핵심 산출물
└── widgets/
    └── owner_order_action_dialogs.dart     # (권장) OwnerOrdersPage 와 공유할 다이얼로그 추출
```

`OwnerOrderDetailPage` 내부 분할 위젯은 동일 파일 내 private 클래스로 두거나 (`_StatusSection`, `_RefundRequestSection`, `_ItemsSection`, `_PaymentInfoSection`, `_ActionBar`) designer 산출에 따라 별도 파일 분리. **architect 권장**: customer `OrderDetailPage` 와 동일하게 동일 파일 내 private 클래스 — 단일 파일 1개로 응집.

#### 수정 파일

- `lib/presentation/owner/orders/owner_orders_page.dart`
  - import `owner_order_detail_page.dart`
  - 두 탭 카드 onTap 핸들러 추가
- `lib/presentation/owner/orders/widgets/owner_new_order_tile.dart`
  - root `Container` 를 `InkWell` 로 감싸기 + `onTap` 콜백 prop 추가
- `lib/presentation/owner/orders/widgets/owner_refund_request_tile.dart`
  - 동일
- `lib/presentation/common/notification/notification_navigator.dart`
  - import 교체 + switch builder 교체

#### Provider DI

- 기존 `order_di_providers.dart` 의 provider 그대로 재사용:
  - `currentOrderProvider(orderId)` (`order_view_providers.dart`)
  - `acceptOrderUseCaseProvider`
  - `cancelPaidOrderUseCaseProvider`
  - `processRefundUseCaseProvider`
  - `denyRefundRequestUseCaseProvider`
- 점주 권한 가드용:
  - `myStoreProvider` (`owner_providers.dart`)
- 신규 provider 없음.

---

## 데이터 흐름

### A. 알림 탭 → 점주 주문 상세 진입 (신규 주문)

```
[Owner 디바이스: 알림 탭 (백그라운드/종료)]
FirebaseMessaging.onMessageOpenedApp 또는 getInitialMessage
  → RemoteNotificationMessage(type=newOrder, orderId=X)
  → NotificationNavigator.navigate(message)
  → switch(type):
      case newOrder|refundRequest:
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => OwnerOrderDetailPage(orderId: X))
        )
```

### B. `OwnerOrdersPage` 카드 탭 → 점주 주문 상세 진입

```
[Owner: 신규 주문 카드 탭 (받기/거절 버튼 영역 아님)]
OwnerNewOrderTile.InkWell.onTap
  → Navigator.push(MaterialPageRoute(builder: (_) => OwnerOrderDetailPage(orderId: order.id)))

[탭 2 환불 요청 카드 탭]
OwnerRefundRequestTile.InkWell.onTap
  → 동일
```

### C. 페이지 진입 후 stream watch + 권한 가드

```
OwnerOrderDetailPage build:
  myStore = ref.watch(myStoreProvider)
  order   = ref.watch(currentOrderProvider(orderId))

  switch ((myStore, order)):
    (loading, _) | (_, loading) → shimmer
    (error, _) | (_, error)     → _ErrorBody (retry)
    (data(null), _)             → "등록된 매장이 없어요"
    (data(store), data(null))   → "주문을 찾을 수 없어요"
    (data(store), data(o)) where o.storeId != store.id
                                 → "이 주문은 다른 매장의 주문이에요" (결정 G fallback)
    (data(store), data(o)) where o.storeId == store.id
                                 → 정상 본문 렌더
```

### D. 액션 (점주 접수 / 거절 / 환불 승인 / 환불 거절)

```
[paid → accepted]
"주문 받기" 탭 → ref.read(acceptOrderUseCaseProvider).call(orderId)
  → AcceptOrderUseCase
  → OrderRepository.setAcceptedByOwner(orderId)  # 직접 Firestore update (O1)
  → stream 으로 status='accepted' 수신 → 액션 영역 자동 재계산 (refundRequest 없으면 사라짐)

[paid → cancelled (점주 거절)]
"거절" 탭 → reject dialog → ref.read(cancelPaidOrderUseCaseProvider).call(orderId, reason, approvedBy:'owner')
  → CancelPaidOrderUseCase → CF cancelTossPayment
  → status='cancelled' 수신 → "취소된 주문입니다" inline 카드 노출

[accepted+refundRequest → refunded]
"환불 승인" 탭 → confirm dialog → ref.read(processRefundUseCaseProvider).call(orderId, reason)
  → ProcessRefundUseCase → CF processRefund
  → status='refunded' 수신

[refundRequest → denied]
"환불 거절" 탭 → reason dialog → ref.read(denyRefundRequestUseCaseProvider).call(orderId, deniedReason)
  → DenyRefundRequestUseCase → OrderRepository.denyRefundRequest (O3)
  → refundRequest.deniedAt 수신 → 액션 영역 사라지고 거절 표시 섹션 노출
```

### E. 상태별 액션 영역 분기 (요약 표)

| status | refundRequest | 액션 영역 |
|---|---|---|
| `paid` | (무관) | "주문 받기" + "거절" |
| `accepted` | null | 액션 없음 (또는 inline 안내) |
| `accepted` | not null & `deniedAt==null` | "환불 승인" + "환불 거절" |
| `accepted` | `deniedAt!=null` | 액션 없음 + 거절 표시 섹션 |
| `making` / `ready` / `completed` | (무관) | 액션 없음 (Phase 3c) |
| `cancelled` | — | "취소된 주문입니다" |
| `refunded` | — | "환불 처리된 주문입니다" |

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| orderId 가 잘못된 값 (존재하지 않음) | `currentOrderProvider` 가 `null` 반환 → "주문을 찾을 수 없어요" 안내 (back) |
| orderId 가 다른 매장의 주문 (FCM stale / 권한 없음) | `myStore.id != order.storeId` 체크 → 안내 + back. Rules 단에서 stream error 가 나면 `_ErrorBody` |
| `myStoreProvider` 에러 (매장 정보 로드 실패) | "매장 정보를 불러오지 못했어요" (기존 `OwnerOrdersPage` 와 동일 카피) |
| 네트워크 에러 (stream error) | `_ErrorBody` + "다시 시도" 버튼 (invalidate currentOrderProvider) |
| 액션 호출 중 네트워크 에러 (예: CF 5xx) | `OwnerOrdersPage` 와 동일하게 SnackBar 로 에러 메시지 표시. 버튼은 disable 해제. stream 은 이전 status 유지 |
| 권한 없는 액션 시도 (Rules 차단) | Repository 에서 throw → catch → SnackBar (`"오류가 발생했습니다: $e"`) |
| 액션 중복 탭 | `_isActionLoading` 가드. 진행 중 버튼 disabled |
| stream 으로 status 가 액션 결과보다 먼저/늦게 도착 race | UI 는 stream 을 단일 진실원으로 사용. 액션 성공/실패에 따라 SnackBar 만 표시. UI 갱신은 stream 이 담당 |
| 알림 탭 직후 페이지 진입했지만 owner 가 로그아웃 상태 | `NotificationNavigator` 가 호출되는 시점에 `RoleRouter` 가 LoginPage 로 보냄. push 자체는 시도되나 LoginPage 위에 OwnerOrderDetailPage 가 쌓임 — 본 phase 비범위 (Phase 3b 의 `PendingNotificationHolder` 가 향후 다룸) |
| 점주가 아닌 role (customer / brand / admin) 이 어떤 이유로 `OwnerOrderDetailPage` 에 도달 | `myStoreProvider` 가 null/error → "등록된 매장이 없어요" 안내. Rules 단에서도 `orders.read` 분기 `userId==uid` 또는 `storeOwner` 미충족 시 차단 |

---

## 권한 / 보안

### Firestore Rules

- `orders.read` — `userId == uid OR storeOwner(storeId) OR admin` (변경 없음, [data_ownership.md §2.4](../../processes/data_ownership.md) 참조).
- `orders.update`:
  - 점주 접수 (paid → accepted): O1 분기 — `storeOwner(storeId)` + `resource.status=='paid'` + 화이트리스트(`status, acceptedAt, updatedAt`). **변경 없음**.
  - 점주 환불 거절: O3 분기 — `storeOwner(storeId)` + `refundRequest != null` + `deniedAt == null` + 내부 4필드 화이트리스트. **변경 없음**.
- 점주 거절 (paid → cancelled) 및 환불 승인 (accepted+ → refunded) 은 Cloud Function (`cancelTossPayment`, `processRefund`) 전담 — **변경 없음**.

### 클라이언트 권한 가드

결정 G — 페이지 내부 `myStore.id == order.storeId` 검사로 잘못된 진입 차단 (UX 가드). Rules 가 최종 진실원.

---

## 작업 분배

### designer

- UI 변경 필요 여부: **예** (신규 페이지 UI 명세 + `OwnerOrdersPage` 카드의 InkWell 시각 톤 결정 필요).
- 디자인 산출물 (`docs/tasks/owner_order_detail_page/design.md`):
  - 페이지 전체 와이어프레임 (section 순서 / 간격 / 색상)
  - `_StatusSection` / `_RefundRequestSection` / `_RefundDeniedSection` 카드 디자인
  - sticky bottom 액션 영역 레이아웃 (paid 분기 / refund 분기)
  - 액션 다이얼로그 (재사용 / 추출 결정)
  - empty / loading / error 상태 UI
  - `OwnerOrdersPage` 카드 ripple / 톤 (결정 E)
- 전달할 사항:
  - `AppColors` 만 사용 (절대 규칙)
  - customer `OrderDetailPage` 와의 시각 일관성 검토 (point of view 가 점주 vs 고객)
  - 본 phase 의 액션 우선순위 = 빠른 응답 → 액션 버튼 명도 / 크기 강조

### developer

- 구현 항목:
  - 신규 `lib/presentation/owner/orders/owner_order_detail_page.dart` 작성 (private 분할 위젯 포함)
  - 기존 `OwnerOrdersPage` 의 두 다이얼로그(`_showRejectOrderDialog`, `_showApproveRefundDialog`, `_showDenyRefundDialog`) 를 `widgets/owner_order_action_dialogs.dart` 로 추출 (양쪽이 import 재사용)
  - `OwnerNewOrderTile` / `OwnerRefundRequestTile` 의 root 를 `InkWell` 로 감싸고 `onTap` prop 추가
  - `OwnerOrdersPage` 에서 카드 onTap 핸들러 연결
  - `NotificationNavigator` 의 builder 교체
- 재사용할 기존 구조:
  - `currentOrderProvider`, `myStoreProvider`
  - `acceptOrderUseCaseProvider`, `cancelPaidOrderUseCaseProvider`, `processRefundUseCaseProvider`, `denyRefundRequestUseCaseProvider`
  - `OrderStatusBadge`, `OrderItemRow`, `PriceSummary`
- 주의할 레이어 규칙:
  - Domain / Data 레이어 코드 변경 금지 (본 phase 는 presentation only)
  - `OrderItemRow` 를 customer 폴더에서 import 하는 것은 임시 허용 (결정 B-A). 후속 task 로 common 승격 검토
  - Firebase / 외부 SDK 직접 import 금지 (`Navigator`, Riverpod, `OrderEntity` 만 사용)
  - `AppColors` 강제, `Color(0x...)` 금지
- 구현 후 산출물 (`docs/tasks/owner_order_detail_page/implementation.md`):
  - 생성/수정 파일 목록
  - InkWell hit 우선순위 동작 검증 결과 (수동 테스트 노트)
  - 사용된 provider / useCase 목록
  - 결정 사항과의 일치 여부

### tester

- 주요 검증 기준 (T 시리즈 — [§"테스트 시나리오"](#테스트-시나리오)):
  - T1: `OwnerOrdersPage` 카드 탭 → 상세 페이지 진입
  - T2: 받기/거절 버튼 탭 시 상세 페이지 진입되지 않음 (버튼 액션만 발화)
  - T3: 알림 탭 (newOrder) → `OwnerOrderDetailPage` 진입 + paid 액션 노출
  - T4: 알림 탭 (refundRequest) → 환불 액션 노출
  - T5: paid 상태에서 "주문 받기" → accepted 전이 → 액션 영역 사라짐 (refundRequest 없음)
  - T6: accepted + refundRequest 활성 → "환불 승인" → status=refunded → "환불 처리된 주문입니다"
  - T7: accepted + refundRequest 활성 → "환불 거절" → `deniedAt` set → 거절 섹션 노출 + 액션 사라짐
  - T8: 잘못된 orderId 진입 → "주문을 찾을 수 없어요" fallback
  - T9: 다른 매장의 orderId 진입 (storeId mismatch) → 결정 G fallback UI
  - T10: 액션 진행 중 버튼 중복 탭 방지
  - T11: status별 액션 영역 분기 (paid / accepted-no-refund / accepted-with-refund / accepted-with-denied-refund / cancelled / refunded)
  - T12: customer `OrderDetailPage` 동작 / UI 변경 없음 (regression)
- 반드시 확인할 예외 케이스:
  - 점주가 카드 버튼 사이 갭(8px) 영역을 정확히 탭했을 때 카드 onTap 발화 (사용자 수용 가능 수준)
  - 알림 종료 상태 deep link → splash 후 진입 정상 동작 (Phase 3b 의 `PendingNotificationHolder` 가 호환)
  - 동일 주문에 대해 알림 탭으로 진입 → 액션 → 뒤로가기 → 카드 탭으로 재진입 시 정상 동작
- 산출물 (`docs/tasks/owner_order_detail_page/test_report.md`): PASS/FAIL 표 + 재현 절차 + 발견 이슈.

---

## 테스트 시나리오 (T1~T12)

| # | 시나리오 | 사전 조건 | 검증 |
|---|---|---|---|
| T1 | OwnerOrdersPage 신규 카드 탭 진입 | paid 주문 1건 존재 | 상세 페이지 push, status=paid, 주문 받기/거절 버튼 노출 |
| T2 | 카드의 "받기"/"거절" 버튼 우선 동작 | 동일 | 카드 onTap 발화 안 됨, 액션 다이얼로그 노출 |
| T3 | 알림 탭(newOrder) → 상세 | FCM 메시지 type=new_order | OwnerOrderDetailPage 진입, paid 액션 노출 |
| T4 | 알림 탭(refundRequest) → 상세 | FCM 메시지 type=refund_request | OwnerOrderDetailPage 진입, refundRequest 섹션 + 환불 승인/거절 노출 |
| T5 | paid → accepted 전이 후 액션 영역 자동 사라짐 | T3 후 "주문 받기" | status=accepted 수신, 액션 영역 미렌더 (refundRequest 없음) |
| T6 | accepted + refundRequest → "환불 승인" | accepted 주문 + refundRequest 활성 | confirm dialog → CF processRefund → status=refunded → "환불 처리된 주문입니다" |
| T7 | accepted + refundRequest → "환불 거절" | 동일 | reason dialog → O3 update → `deniedAt` set, 거절 섹션 노출, 액션 사라짐 |
| T8 | 잘못된 orderId 진입 | orderId 존재 X | "주문을 찾을 수 없어요" 안내 |
| T9 | 다른 매장 orderId 진입 | order.storeId != myStore.id | 결정 G fallback ("다른 매장 주문" 안내) |
| T10 | 액션 중복 탭 방지 | 액션 진행 중 | 버튼 disabled + spinner 노출, 중복 호출 없음 |
| T11 | status별 액션 영역 분기 | 매트릭스 6개 케이스 | 각 status 에서 정확한 액션 영역 (또는 inline 안내) 표시 |
| T12 | customer OrderDetailPage 회귀 | 고객 계정으로 진입 | UI / 동작 변경 없음 |

---

## 완료 기준

- [ ] 모든 요구사항 (기능 / UI / 상태) 구현 또는 보류 사유 명시
- [ ] `design.md` 작성 완료 (신규 페이지 UI + InkWell 톤)
- [ ] `implementation.md` 작성 완료
- [ ] `test_report.md` 작성 완료 + T1~T12 모두 PASS 또는 FAIL 후속 task 분리
- [ ] customer `OrderDetailPage` regression 없음
- [ ] `flutter analyze` warning 0
- [ ] designer / developer / tester 모두 본 spec 의 결정 항목 (A~G, Q1, Q2) 에 따라 작업했음을 산출물에서 명시

---

## 참고 자료

- Phase 3b spec / implementation: `docs/tasks/order_flow_phase3b/`
- customer `OrderDetailPage`: `lib/presentation/customer/order/orders/order_detail_page.dart`
- 기존 owner orders 페이지: `lib/presentation/owner/orders/owner_orders_page.dart`
- 알림 navigator: `lib/presentation/common/notification/notification_navigator.dart`
- order 도메인 / status: `lib/domain/entities/order_entity.dart`, `lib/domain/entities/order_status.dart`
- order DI providers: `lib/presentation/customer/order/orders/providers/order_di_providers.dart`
- owner providers (`myStoreProvider`): `lib/presentation/owner/providers/owner_providers.dart`
- 단일 진실원: `docs/processes/role_flows.md` §4.2, `docs/processes/entity_lifecycle.md` §2, `docs/processes/data_ownership.md` §2.4
