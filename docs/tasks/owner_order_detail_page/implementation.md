# owner_order_detail_page 구현 보고

## 신규 / 수정 파일 목록

### 신규

| 파일 | 역할 |
|---|---|
| `lib/presentation/owner/orders/owner_order_detail_page.dart` | 점주용 주문 상세 페이지 (본 phase 핵심 산출물) |
| `lib/presentation/owner/orders/widgets/owner_order_action_dialogs.dart` | 점주 액션 다이얼로그 공통 추출 (`OwnerOrdersPage` / `OwnerOrderDetailPage` 공유) |

### 수정

| 파일 | 변경 내용 |
|---|---|
| `lib/presentation/owner/orders/widgets/owner_new_order_tile.dart` | `onTapDetail` prop 추가, `Material + InkWell` 로 root 감싸기 |
| `lib/presentation/owner/orders/widgets/owner_refund_request_tile.dart` | 동일 |
| `lib/presentation/owner/orders/owner_orders_page.dart` | 다이얼로그 3개 → `OwnerOrderActionDialogs` 위임, 카드에 `onTapDetail` 연결, `intl` import 제거 |
| `lib/presentation/common/notification/notification_navigator.dart` | `OrderDetailPage` → `OwnerOrderDetailPage` 교체 |

---

## 재사용 vs 신규 정리

| 항목 | 재사용 / 신규 | 비고 |
|---|---|---|
| `currentOrderProvider(orderId)` | 재사용 | `order_view_providers.dart` |
| `myStoreProvider` | 재사용 | `owner_providers.dart` |
| `acceptOrderUseCaseProvider` | 재사용 | `order_di_providers.dart` |
| `cancelPaidOrderUseCaseProvider` | 재사용 | |
| `processRefundUseCaseProvider` | 재사용 | |
| `denyRefundRequestUseCaseProvider` | 재사용 | |
| `OrderStatusBadge` | 재사용 | `presentation/common/order_status_badge.dart` |
| `OrderItemRow` | 재사용 | `customer/order/widgets/` (결정 B-A, 임시 허용) |
| `PriceSummary` | 재사용 | `customer/order/widgets/` |
| `ReceiptWebView` | 재사용 | `customer/checkout/widgets/` |
| `_OwnerOrderDetailShimmer` | 신규 (private) | customer `_OrderDetailShimmer` 패턴 복제 |
| `_ErrorBody` | 신규 (private) | customer `_ErrorBody` 패턴 복제 |
| `_FallbackBody` | 신규 (private) | 권한 가드 / 안전 가드 fallback UI |
| `OwnerOrderActionDialogs` | 신규 추출 | 기존 `OwnerOrdersPage` 다이얼로그 3개 분리 |
| Domain / Data 레이어 | 변경 없음 | spec 결정 준수 |

---

## 구현 결정 사항 일치 여부

| spec 결정 | 구현 |
|---|---|
| 결정 A: `_StatusSection` 본문 상단 카드 | `_StatusSection` — OrderStatusBadge + 주문번호 + createdAt + storeName |
| 결정 B-A: `OrderItemRow` customer 폴더 import | 임시 허용 import 적용, 후속 task 주석 없음 (spec 인지) |
| 결정 C: `_OwnerRefundSection` 별도 카드 | `refundRequest != null` 조건부 렌더 |
| 결정 D: sticky bottom `_ActionBar` | `Scaffold.bottomNavigationBar` 에 배치 |
| 결정 E: `InkWell` 카드 전체 감싸기 | `Material + InkWell`, Flutter hit test 자동 분기 |
| 결정 F: `newOrder` / `refundRequest` 동일 페이지 | `NotificationNavigator` 두 case 모두 `OwnerOrderDetailPage` |
| 결정 G: storeId 불일치 fallback | `order.storeId != store.id` 검사 → `_FallbackBody` |
| Q1: 카드 버튼 유지 + 카드 탭 상세 진입 | 버튼 그대로, `onTapDetail` prop 추가 |
| Q2: `accepted` + `refundRequest != null` + `deniedAt == null` | `_hasActionBar` / `_buildBottomBar` 분기 로직 |
| 환불 요청 섹션 color: error 톤 | `AppColors.error` border 1.5px (활성) / `AppColors.border` (거절 완료) |
| status 카드 storeName 포함 | `_StatusSection` 하단에 storeName 표시 |
| paid 버튼 비율 2:1 | `Expanded(flex:2)` / `Expanded(flex:1)` |
| 액션 라벨 "주문 받기" | `_PrimaryButton(label: '주문 받기')` |

---

## `_hasActionBar` 분기 로직 요약

```dart
bool _hasActionBar(OrderEntity order) {
  if (order.status == OrderStatus.paid) return true;
  if (order.status == OrderStatus.accepted) {
    final req = order.refundRequest;
    return req != null && req.deniedAt == null;
  }
  return false;
}
```

- sticky bar 있음: `bottom padding = 96`
- sticky bar 없음: `bottom padding = 32`, `_NoActionInfoCard` 본문 하단 표시

---

## 액션 흐름

| 버튼 | 흐름 |
|---|---|
| 주문 받기 | 즉시 `acceptOrderUseCase` 호출 → stream 갱신 → 액션 바 자동 사라짐 |
| 거절 | `OwnerOrderActionDialogs.showRejectOrder` → `cancelPaidOrderUseCase(approvedBy:'owner')` |
| 환불 승인 | `OwnerOrderActionDialogs.showApproveRefund` → `processRefundUseCase` |
| 환불 거절 | `OwnerOrderActionDialogs.showDenyRefund` → `denyRefundRequestUseCase` |

중복 탭 방지: `bool _isActionLoading` 플래그 — 진행 중 버튼 disabled.  
액션 후 pop 없음 — stream 자동 갱신으로 UI 재계산.

---

## T1~T12 검증 시나리오 대응

| # | 시나리오 | 대응 구현 |
|---|---|---|
| T1 | OwnerOrdersPage 카드 탭 → 상세 진입 | `onTapDetail` → `Navigator.push(OwnerOrderDetailPage)` |
| T2 | 카드 버튼 우선 동작 | Flutter hit test 자동 분기 (InkWell onTap vs Button onPressed) |
| T3 | 알림 탭(newOrder) → OwnerOrderDetailPage | `NotificationNavigator` case newOrder → `OwnerOrderDetailPage` |
| T4 | 알림 탭(refundRequest) → 환불 액션 노출 | 동일, 페이지 내부 `_hasActionBar` 가 `accepted+refundRequest` 검사 |
| T5 | paid → accepted 전이 후 액션 영역 사라짐 | stream 갱신 → `_hasActionBar` false → `bottomNavigationBar: null` |
| T6 | 환불 승인 → refunded → inline 안내 | `processRefundUseCase` → stream → `_NoActionInfoCard('환불이 완료된 주문이에요.')` |
| T7 | 환불 거절 → `deniedAt` set → 거절 섹션 + 액션 사라짐 | `denyRefundRequestUseCase` → stream → `_OwnerRefundSection` 3-B 분기 |
| T8 | 잘못된 orderId → "주문을 찾을 수 없어요" | `currentOrderProvider` null → `_FallbackBody` |
| T9 | 다른 매장 orderId → 결정 G fallback | `order.storeId != store.id` → `_FallbackBody('이 주문은 다른 매장의 주문이에요')` |
| T10 | 액션 중복 탭 방지 | `_isActionLoading` guard + 버튼 disabled |
| T11 | status별 액션 영역 분기 | `_hasActionBar` + `_buildPaidButtons` / `_buildRefundButtons` / `_NoActionInfoCard` |
| T12 | customer OrderDetailPage 회귀 없음 | 해당 파일 수정 없음 |

---

## 미구현 / 보류 항목

| 항목 | 사유 |
|---|---|
| `OrderItemRow` / `PriceSummary` `presentation/common/` 승격 | 결정 B-A 임시 허용 — 후속 task |
| `_OrderDetailShimmer` / `_ErrorBody` 공통화 | 후속 task |
| customer 알림 도착 시 role 별 분기 (`NotificationNavigator`) | Phase 3c 예정 |
| 점주 `making` / `ready` / `completed` 전이 액션 | Phase 3c 예정 |

---

## `flutter analyze` 결과

```
Analyzing OrderApp...
No issues found! (ran in 6.1s)
```
