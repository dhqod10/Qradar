# order_flow_phase3a 구현 내역

> 최종 작성: 2026-05-13. 4차 호출에서 전체 완성.

---

## 1. 개요 / 진행 기록

### 목적

카트가 확정된 Qrator(고객)가 **토스페이먼츠 신용/체크카드 또는 카카오페이로 실제 결제를 완료**하고, Cloud Functions 가 결제 검증 후 Firestore `orders` 컬렉션에 주문 doc 을 원자적으로 생성하는 전체 파이프라인을 구축한다. 결제 실패/취소 흐름, 고객 취소(paid 상태), 환불 요청/처리, 점주 최소 접수 UI 도 함께 구현한다.

### spec / design 결정 사항 요약

| # | 결정 | 채택안 |
|---|---|---|
| 결정 1 | 결제 검증 방식 | (C) 클라이언트 콜백 + Cloud Functions 하이브리드 (Toss confirm API) |
| 결정 2 | FCM 푸시 | 본 phase 비범위, in-app 다이얼로그만 |
| 결정 3 | 주문 상태 흐름 | (B) paid / cancelled / refunded 까지 (accepted 이상 enum 만 선언) |
| 결정 4 | 환불 흐름 | 본 phase 포함, 전액 환불만 |
| 결정 5 | 점주 최소 접수 UI | 신규(paid) 탭 + 환불 요청 탭. accepted 이후 placeholder 유지 |
| 결정 6 | OrderEntity vs OrderLogEntity | orders/{orderId} = SOT, users/{uid}/orderLogs/{logId} = 추천 snapshot. Cloud Functions 가 batch write |
| 결정 7 (사용자 확인 7) | Toss SDK | tosspayments_widget_sdk_flutter ^2.2.0 (Widget 기반 통합 UX) |
| 결정 8 | totalPrice 단위 | int (원) |
| 결정 9 | paymentMethod | enum (card / kakaoPay / ...) |
| 결정 10 | LogPage 본구현 | orders 컬렉션 기반 OrdersPage 로 교체 |
| 결정 11 | 결제 실패 후 카트 | 유지 (성공 시에만 clear) |
| 결정 12 | idempotencyKey | uuid v4. orders/{idempotencyKey} = Toss orderId |
| D1 (design) | owner "주문 받기" 확인 다이얼로그 | 없음 — 즉시 acceptOrder |
| D2 (design) | OrderStatusBadge 위치 | presentation/common/ (공용 위젯) |
| D3 (design) | RefundRequestSheet 구현 방식 | showModalBottomSheet 패턴 |

---

## 2. 패키지 선정

### 선정: `tosspayments_widget_sdk_flutter: ^2.2.0`

**근거:**

- Toss 공식 Flutter SDK. Widget 기반 결제창 통합으로 카드 직접 입력과 카카오페이 deeplink 를 **단일 API 호출**로 처리한다.
- `TossPaymentsWebView` 위젯 방식으로 앱 내 결제창 전환이 자연스럽고 외부 브라우저 이탈이 없다.
- 카드 + 카카오페이 결제수단을 동일 인터페이스(PaymentMethod enum)로 분기할 수 있어 Phase 3b(네이버페이 등 추가) 확장 시 동일 패턴을 재사용한다.
- `tosspayments_payment_sdk` (구 SDK) 는 유지보수 업데이트가 느리고 deeplink 처리 코드를 직접 작성해야 하는 부담이 있어 제외했다.

---

## 3. 추가 의존성 (pubspec.yaml)

| 패키지 | 버전 | 용도 |
|---|---|---|
| `tosspayments_widget_sdk_flutter` | ^2.2.0 | Toss 결제창 (카드/카카오페이) SDK |
| `cloud_functions` | ^6.1.0 | Firebase Cloud Functions HTTPS Callable 클라이언트 |
| `uuid` | ^4.5.1 | idempotencyKey (uuid v4) 생성 |
| `intl` | ^0.20.2 | 금액 숫자 포맷 (NumberFormat.currency) |

---

## 4. 디렉토리 구조 / 구현 파일 목록

### 4-1. Domain

```
lib/domain/entities/
  order_entity.dart              # OrderEntity (freezed)
  order_entity.freezed.dart
  order_item_entity.dart         # OrderItemEntity (freezed)
  order_item_entity.freezed.dart
  order_log_entity.dart          # OrderLogEntity (기존 Phase 2, freezed)
  order_log_entity.freezed.dart
  payment_info_entity.dart       # PaymentInfoEntity (freezed)
  payment_info_entity.freezed.dart
  order_status.dart              # OrderStatus enum
  payment_method.dart            # PaymentMethod enum
  payment_channel.dart           # PaymentChannel enum
  quick_reorder_candidate_entity.dart   # (Phase 2 기존)
  quick_reorder_candidate_entity.freezed.dart

lib/domain/repositories/
  order_repository.dart
  order_log_repository.dart
  payment_gateway_repository.dart
  cart_repository.dart            # (기존 Phase 1)

lib/domain/usecases/
  launch_payment_use_case.dart           # Toss SDK 결제창 launch
  verify_and_create_order_use_case.dart  # Cloud Functions verifyTossPayment 호출
  watch_order_use_case.dart              # orders/{orderId} stream
  watch_user_orders_use_case.dart        # 내 주문 목록 stream
  watch_store_orders_use_case.dart       # 점주 매장 주문 stream
  cancel_paid_order_use_case.dart        # paid 상태 customer 취소 / owner 거절
  accept_order_use_case.dart             # paid → accepted
  request_refund_use_case.dart           # accepted+ → refundRequest set
  process_refund_use_case.dart           # owner 환불 승인 → Cloud Functions
  deny_refund_request_use_case.dart      # owner 환불 거절
  watch_store_refund_requests_use_case.dart
  write_order_log_use_case.dart          # (Phase 2 기존)
  add_to_cart_use_case.dart              # (Phase 1 기존)
  remove_cart_item_use_case.dart
  update_cart_item_quantity_use_case.dart
  clear_cart_use_case.dart
  watch_cart_use_case.dart
  get_quick_reorder_candidates_use_case.dart
```

### 4-2. Data

```
lib/data/models/
  order_model.dart
  order_item_model.dart
  order_log_model.dart           # (Phase 2 기존)
  payment_info_model.dart

lib/data/datasources/remote/
  toss_payment_remote_data_source.dart      # SDK 실제 호출. _TossPaymentPage push 패턴. BuildContext 받음
  cloud_functions_remote_data_source.dart   # FirebaseFunctions.instanceFor(region:'asia-northeast3') callable
  order_remote_data_source.dart             # Firestore orders/{orderId} CRUD + stream
  order_log_remote_data_source.dart         # (Phase 2 기존)

lib/data/datasources/local/
  cart_local_data_source.dart               # (Phase 1 기존)

lib/data/repositories/
  order_repository_impl.dart
  order_log_repository_impl.dart            # (Phase 2 기존)
  payment_gateway_repository_impl.dart
  cart_repository_impl.dart                 # (Phase 1 기존)
```

### 4-3. Presentation — Customer

```
lib/presentation/customer/checkout/
  checkout_page.dart
  payment_result_page.dart
  widgets/
    checkout_summary_card.dart
    payment_method_tile.dart

lib/presentation/customer/order/orders/
  order_detail_page.dart
  providers/
    order_di_providers.dart      # DI 13개 Provider (usecase / datasource / repository)
    order_view_providers.dart    # currentOrderProvider(family), myOrdersProvider

lib/presentation/customer/order/widgets/  (공용 위젯 — order/ 하위 재사용)
  order_card.dart
  order_item_row.dart
  price_summary.dart
  refund_request_sheet.dart

lib/presentation/customer/log/
  orders_page.dart               # LogPage 를 대체하는 내 주문 목록 (OrdersPage)
  log_page.dart                  # 기존 LogPage (scaffold 진입점 유지, orders_page 를 body 로 위임)

lib/presentation/customer/cart/
  cart_page.dart                 # (수정) placeholder SnackBar → CheckoutPage push

lib/presentation/common/
  order_status_badge.dart        # OrderStatusBadge 공용 위젯
```

### 4-4. Presentation — Owner

```
lib/presentation/owner/orders/
  owner_orders_page.dart
  widgets/
    owner_new_order_tile.dart
    owner_refund_request_tile.dart
```

### 4-5. 라우팅 변경

| 파일 | 변경 내용 |
|---|---|
| `lib/presentation/customer/cart/cart_page.dart` | "결제하기" placeholder SnackBar → `Navigator.push(CheckoutPage)` |
| `lib/presentation/customer/log/log_page.dart` 또는 scaffold_with_nav | Log 탭 body 를 `OrdersPage` 로 교체 |
| `lib/presentation/owner/owner_scaffold.dart` | `OwnerOrdersPlaceholder` → `OwnerOrdersPage` 교체 |
| `lib/presentation/customer/checkout/payment_result_page.dart` 내부 | success → `OrderDetailPage` push wire |

### 4-6. Cloud Functions (TypeScript, `functions/src/`)

```
functions/
  package.json
  tsconfig.json
  .env.example
  .gitignore
  README.md
  src/
    index.ts                  # 함수 export 진입점
    verifyTossPayment.ts      # HTTPS Callable: 결제 검증 + Firestore batch write
    cancelTossPayment.ts      # HTTPS Callable: 결제 취소 (customer paid 취소 / owner 거절)
    processRefund.ts          # HTTPS Callable: 환불 승인 (owner)
    tossClient.ts             # Toss Server API HTTP 클라이언트 공통 모듈
```

### 4-7. 네이티브 설정

| 파일 | 추가 항목 |
|---|---|
| `ios/Runner/Info.plist` | `LSApplicationQueriesSchemes`: kakaopay, kakaolink, kakaotalk. `CFBundleURLSchemes`: qradar (deeplink 복귀) |
| `android/app/src/main/AndroidManifest.xml` | `<queries>` 패키지 (com.kakao.talk). `intent-filter` scheme=qradar (deeplink 복귀) |
| `firebase.json` | `functions` 섹션 (source: "functions", runtime: nodejs20, region: asia-northeast3) |

---

## 5. 결제 흐름 (시퀀스)

### 골든 패스 (성공)

```
CartPage
  └─ "결제하기" 탭
       └─ [비인증 체크] → 로그인 요청 다이얼로그 (차단)
       └─ [카트 비어있음] → 다이얼로그 (차단)
       └─ CheckoutPage push (MaterialPageRoute)
            ├─ 카트 스냅샷 캡처 (immutable)
            ├─ 결제수단 선택 (카드 / 카카오페이)
            ├─ 약관 동의
            └─ "X,XXX원 결제하기" 탭
                 ├─ idempotencyKey = uuid v4() 생성
                 ├─ LaunchPaymentUseCase(context, idempotencyKey, amount, method)
                 │    └─ TossPaymentRemoteDataSource.launch(...)
                 │         └─ _TossPaymentPage push (Toss SDK WebView 화면)
                 │              └─ 사용자: 카드 입력 또는 카카오페이 인증
                 ├─ [SDK success callback]
                 │    paymentKey, orderId(=idempotencyKey), amount
                 │    └─ VerifyAndCreateOrderUseCase(paymentKey, orderId, amount, cartSnapshot)
                 │         └─ CloudFunctionsRemoteDataSource.call('verifyTossPayment', {...})
                 │              [Cloud Functions 내부]
                 │              ├─ auth.uid 인증 검증
                 │              ├─ Toss Server API POST /v1/payments/confirm 호출
                 │              ├─ response.amount === 요청 amount 검증
                 │              ├─ response.status === 'DONE' 검증
                 │              ├─ Firestore batch:
                 │              │    orders/{orderId} set (status='paid', paymentInfo, items, ...)
                 │              │    users/{uid}/orderLogs/{logId} append (Phase 2 schema)
                 │              └─ return {success: true, orderId}
                 └─ PaymentResultPage push (result=success, orderId)
                      └─ "주문 상세 보기" 탭 → OrderDetailPage push
```

### 결제 실패 / 취소

```
[SDK fail callback]
  errorCode, message
  └─ PaymentResultPage push (result=fail)
       └─ 카트 유지
       └─ "다시 시도" → CheckoutPage 재진입
       └─ "닫기" → CartPage 복귀

[SDK cancel callback] (사용자가 결제창 X)
  └─ PaymentResultPage push (result=cancelled)
       └─ 카트 유지
       └─ "카트로 돌아가기" → CartPage 복귀
```

---

## 6. 환불 / 취소 흐름

### Customer 직접 취소 (paid 상태)

```
OrderDetailPage (status=paid)
  └─ "주문 취소" 버튼 표시
       └─ 확인 다이얼로그 ("결제가 취소됩니다. 계속하시겠어요?")
            └─ CancelPaidOrderUseCase(orderId)
                 └─ CloudFunctionsRemoteDataSource.call('cancelTossPayment', {orderId})
                      [Cloud Functions]
                      ├─ auth.uid === orders/{orderId}.uid 검증
                      ├─ status === 'paid' 검증
                      ├─ Toss Server API POST /v1/payments/{paymentKey}/cancel
                      └─ orders/{orderId}.status = 'cancelled'
```

### Customer 환불 요청 (accepted 이상)

```
OrderDetailPage (status=accepted 이상)
  └─ "환불 요청" 버튼 표시
       └─ RefundRequestSheet (showModalBottomSheet)
            사유 선택(라디오) + 자유 입력 (optional)
            └─ RequestRefundUseCase(orderId, reason, reasonDetail)
                 └─ OrderRemoteDataSource.setRefundRequest(orderId, {reason, requestedAt})
                      orders/{orderId}.refundRequest 필드 set
```

### Owner 주문 받기 (paid → accepted)

```
OwnerOrdersPage / 신규 탭
  └─ OwnerNewOrderTile: paid 주문 카드
       └─ "주문 받기" 버튼 탭 (확인 다이얼로그 없음 — D1 결정)
            └─ AcceptOrderUseCase(orderId)
                 └─ OrderRemoteDataSource.updateStatus(orderId, OrderStatus.accepted)
```

### Owner 거절 (매장 사유, paid → cancelled)

```
OwnerOrdersPage / 신규 탭
  └─ OwnerNewOrderTile
       └─ "거절" 버튼 탭 → 다이얼로그 (사유 입력)
            └─ CancelPaidOrderUseCase(orderId, ownerReason)
                 └─ CloudFunctionsRemoteDataSource.call('cancelTossPayment', {orderId, ownerReason})
                      [Cloud Functions]
                      ├─ orders/{orderId}.store.ownerId === auth.uid 검증
                      ├─ Toss Server API cancel 호출
                      └─ orders/{orderId}.status = 'cancelled'
```

### Owner 환불 승인

```
OwnerOrdersPage / 환불 요청 탭
  └─ OwnerRefundRequestTile
       └─ "승인" 버튼 탭 → 확인 다이얼로그
            └─ ProcessRefundUseCase(orderId)
                 └─ CloudFunctionsRemoteDataSource.call('processRefund', {orderId})
                      [Cloud Functions]
                      ├─ orders/{orderId}.store.ownerId === auth.uid 검증
                      ├─ refundRequest 존재 검증
                      ├─ Toss Server API POST /v1/payments/{paymentKey}/cancel (cancelReason 포함)
                      ├─ orders/{orderId}.status = 'refunded', refundInfo set
                      └─ (OrderLog 는 mutate 안 함 — 결정 6)
```

### Owner 환불 거절

```
OwnerOrdersPage / 환불 요청 탭
  └─ OwnerRefundRequestTile
       └─ "거절" 버튼 탭 → 다이얼로그 (거절 사유 입력)
            └─ DenyRefundRequestUseCase(orderId, deniedReason)
                 └─ OrderRemoteDataSource.denyRefundRequest(orderId, {deniedAt, deniedReason})
                      orders/{orderId}.refundRequest.deniedAt / deniedReason set (status 그대로)
```

---

## 7. Cloud Functions

### 배포 region

`asia-northeast3` (서울)

### 함수 시그니처

```typescript
// verifyTossPayment: 결제 검증 + Firestore batch write
export const verifyTossPayment = onCall(
  { region: 'asia-northeast3', secrets: ['TOSS_SECRET_KEY'] },
  async (request: CallableRequest<{
    paymentKey: string;
    orderId: string;
    amount: number;
    cartSnapshot: CartSnapshotPayload;
  }>) => Promise<{ success: true; orderId: string }>
);

// cancelTossPayment: 결제 취소 (customer paid 취소 또는 owner 거절)
export const cancelTossPayment = onCall(
  { region: 'asia-northeast3', secrets: ['TOSS_SECRET_KEY'] },
  async (request: CallableRequest<{
    orderId: string;
    cancelReason?: string;
  }>) => Promise<{ success: true }>
);

// processRefund: 환불 승인 (owner)
export const processRefund = onCall(
  { region: 'asia-northeast3', secrets: ['TOSS_SECRET_KEY'] },
  async (request: CallableRequest<{
    orderId: string;
  }>) => Promise<{ success: true }>
);
```

### Toss Server API 매핑

| 함수 | Toss Server API |
|---|---|
| verifyTossPayment | `POST https://api.tosspayments.com/v1/payments/confirm` |
| cancelTossPayment | `POST https://api.tosspayments.com/v1/payments/{paymentKey}/cancel` |
| processRefund | `POST https://api.tosspayments.com/v1/payments/{paymentKey}/cancel` |

### 보안 / 인증 / 권한

- `TOSS_SECRET_KEY`: Firebase Functions v2 secrets (`firebase functions:secrets:set TOSS_SECRET_KEY`) 사용. 코드 하드코딩 절대 금지.
- 모든 함수 내부에서 `request.auth?.uid` 존재 여부 검증. 미인증 시 `HttpsError('unauthenticated')` throw.
- `cancelTossPayment` / `processRefund`: `orders/{orderId}.uid === auth.uid` (customer 취소) 또는 `orders/{orderId}.store.ownerId === auth.uid` (owner 처리) 검증. 불일치 시 `HttpsError('permission-denied')`.
- Firestore 에서 store 문서의 owner 필드명은 `ownerId` (내부 코드 확인 결과 `ownerUid` 아님 — 주의).

### 에러 매핑 (CloudFunctionsRemoteDataSource)

`FirebaseFunctionsException` 를 한국어 메시지로 변환하여 상위 레이어에 전달.

| HttpsError code | 한국어 메시지 |
|---|---|
| unauthenticated | 로그인이 필요합니다 |
| permission-denied | 권한이 없습니다 |
| not-found | 주문 정보를 찾을 수 없습니다 |
| already-exists | 이미 처리된 결제입니다 |
| invalid-argument | 요청 정보가 올바르지 않습니다 |
| internal | 서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요 |

---

## 8. 네이티브 설정

### iOS — `ios/Runner/Info.plist`

추가 항목:

```xml
<!-- 카카오페이 외부 앱 호출 허용 -->
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>kakaopay</string>
  <string>kakaolink</string>
  <string>kakaotalk</string>
</array>

<!-- Toss / 카카오 인증 완료 후 앱 복귀 deeplink -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>qradar</string>
    </array>
  </dict>
</array>
```

### Android — `android/app/src/main/AndroidManifest.xml`

추가 항목:

```xml
<!-- 카카오톡 설치 여부 쿼리 -->
<queries>
  <package android:name="com.kakao.talk" />
</queries>

<!-- deeplink 복귀 intent-filter (MainActivity 내부) -->
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="qradar" />
</intent-filter>
```

### firebase.json — functions 섹션

```json
{
  "functions": {
    "source": "functions",
    "runtime": "nodejs20"
  }
}
```

---

## 9. 환경 변수 / 보안

### Flutter 클라이언트 (Dart)

- `TOSS_CLIENT_KEY`: `--dart-define=TOSS_CLIENT_KEY=test_ck_xxx` 또는 IDE Run Configuration 에 등록.
- 코드 참조: `const String.fromEnvironment('TOSS_CLIENT_KEY')`.
- 코드에 직접 하드코딩 금지 (절대 규칙).

### Cloud Functions (서버)

- `TOSS_SECRET_KEY`: Firebase secrets 에 등록 (`firebase functions:secrets:set TOSS_SECRET_KEY`).
- 함수 정의에서 `secrets: ['TOSS_SECRET_KEY']` 선언 후 `process.env.TOSS_SECRET_KEY` 로 참조.

### .gitignore / .env

- `functions/.env.example` 만 commit (실제 값 없음).
- `functions/.env` 는 `.gitignore` 에 포함.

### 클라이언트 amount 위·변조 대응

- 클라이언트가 전달하는 `amount` 는 서버(Cloud Functions)에서 **Toss 결제 응답의 `amount` 와 재검증**. 불일치 시 `HttpsError('invalid-argument')` throw 후 Firestore write 금지.

---

## 10. 데이터 모델 / Firestore 컬렉션

### `orders/{orderId}` 스키마

`orderId` = `idempotencyKey` = Toss `orderId` (uuid v4).

```
orders/{orderId}
  uid: String                     # 주문한 Qrator uid
  storeId: String
  storeName: String
  store: { ownerId: String, ... } # ownerId 필드 (ownerUid 아님)
  items: [{ menuId, name, quantity, unitPrice, options }]
  totalPrice: int                 # 원 단위
  discount: int?                  # null (Phase 4 확장 예약)
  paymentMethod: String           # enum.code ('card' / 'kakaoPay')
  paymentChannel: String          # 'toss'
  status: String                  # OrderStatus enum.code
  paymentInfo: {
    paymentKey: String
    receiptUrl: String?
    paidAt: Timestamp
  }
  refundRequest: {                # 필드 없음 → 환불 요청 없음
    reason: String
    reasonDetail: String?
    requestedAt: Timestamp
    deniedAt: Timestamp?
    deniedReason: String?
  }?
  refundInfo: {                   # 환불 완료 시 set
    refundedAt: Timestamp
    cancelReason: String?
  }?
  idempotencyKey: String          # orderId 와 동일
  createdAt: Timestamp
  updatedAt: Timestamp
```

### `users/{uid}/orderLogs/{logId}` (Phase 2 스키마 유지)

결제 성공 시 `verifyTossPayment` Cloud Functions 에서 batch write. 이후 mutate 없음.

### Firestore 색인

본 phase 에서 `firestore.indexes.json` 별도 추가 없음. 다음 쿼리에 복합 색인이 필요할 수 있으므로 Console 에서 생성 또는 `firestore.indexes.json` 에 추가 필요:

- `orders` 컬렉션: `uid` ASC + `createdAt` DESC (내 주문 목록)
- `orders` 컬렉션: `storeId` ASC + `status` ASC + `createdAt` DESC (점주 주문 리스트)
- `orders` 컬렉션: `storeId` ASC + `refundRequest` (환불 요청 필터)

---

## 11. 테스트 포인트 (실기기 / 시뮬레이터 시나리오)

| # | 시나리오 | 확인 항목 |
|---|---|---|
| T01 | 결제 골든 패스 — 카드 | SDK 결제창 → success callback → verifyTossPayment 호출 → orders doc 생성 → OrderDetailPage 이동. 카트 clear 확인. |
| T02 | 결제 골든 패스 — 카카오페이 | 카카오톡 딥링크 전환 → 인증 → 앱 복귀 → success callback → 동일 플로우. |
| T03 | 결제 실패 (카드 잔액 부족 등) | fail callback → PaymentResultPage(fail) 노출. 카트 유지. "다시 시도" 탭 → CheckoutPage 재진입 가능. |
| T04 | 결제 사용자 취소 (결제창 X) | cancel callback → PaymentResultPage(cancelled) 노출. 카트 유지. "카트로 돌아가기" 동작. |
| T05 | 결제 후 customer 직접 취소 (paid) | OrderDetailPage "주문 취소" → 확인 다이얼로그 → cancelTossPayment 호출 → status=cancelled 갱신 확인. |
| T06 | 결제 후 owner 거절 | OwnerOrdersPage 신규 탭 → "거절" → 사유 입력 → cancelTossPayment 호출 → status=cancelled. customer OrderDetailPage 실시간 갱신 확인. |
| T07 | accepted 이후 customer 환불 요청 | OrderDetailPage(accepted) "환불 요청" → RefundRequestSheet → requestRefund → orders/{orderId}.refundRequest set. "주문 취소" 버튼 미노출 확인. |
| T08 | owner 환불 승인 | OwnerOrdersPage 환불 요청 탭 → "승인" → processRefund → status=refunded. customer OrderDetailPage 실시간 갱신. |
| T09 | owner 환불 거절 | OwnerOrdersPage 환불 요청 탭 → "거절" → 사유 입력 → denyRefundRequest → refundRequest.deniedAt set. status 변경 없음 확인. |
| T10 | 동일 idempotencyKey 중복 결제 방지 | 같은 orderId 로 두 번 verifyTossPayment 호출 시 두 번째 호출이 `already-exists` 에러 반환 확인. |
| T11 | 영수증 link 동작 | OrderDetailPage 영수증 버튼 탭 → paymentInfo.receiptUrl WebView 또는 외부 브라우저 열림 확인. |
| T12 | 미인증 사용자 결제 차단 | 로그인 없이 CartPage "결제하기" 탭 → 로그인 요청 다이얼로그. CheckoutPage 진입 불가. |
| T13 | 다른 매장 점주의 환불 시도 차단 | 다른 storeId 의 점주 uid 로 processRefund 호출 시 Cloud Functions `permission-denied` 반환 확인. |
| T14 | OrdersPage / OrderDetailPage 실시간 status 갱신 | 점주가 status 변경 시 customer 화면 자동 갱신 (Firestore stream). |
| T15 | OwnerOrdersPage 실시간 신규/환불 요청 갱신 | customer 가 주문하거나 환불 요청 시 owner 화면 자동 갱신. |

---

## 12. 미구현 / 보류 (다음 phase 후보)

| 항목 | 예정 phase |
|---|---|
| FCM 푸시 알림 (점주 신규 주문 알림, customer 거절/환불 알림) | Phase 3b 또는 별도 |
| 부분 환불 (전액 환불만 구현됨) | 별 phase |
| 주문 상태 전체 전이 (accepted → making → ready → completed) | Phase 3c |
| 추가 결제 수단 (네이버페이, 토스페이, 삼성페이, 애플페이, 계좌이체 등) | Phase 3b |
| Qoin 적립 / 사용 / 환불 시 회수 (`QoinAccrualHook` 빈 hook 자리만 있음) | Phase 4 |
| 점주 매출 조회 | 별 phase |
| Firestore 보안 규칙 작성 (본 phase 컬렉션 경로 입력 필요) | 별 task |
| 카트 영속화 | Phase 1b 비범위 유지 |
| 결제 실패 자동 retry / 큐 | 별 phase |
| 세금 / 부가세 분리 표시 | 별 phase |
| 간편결제 빌링키 / 자동결제 | 별 phase |
| Firestore 색인 (`firestore.indexes.json`) 정식 추가 | 다음 task 또는 Console 에서 수동 생성 |

---

## 13. 다음 phase (3b/3c/4) 진입 전 점검

아래 항목이 완료되지 않으면 실제 결제가 동작하지 않는다.

1. **TOSS_SECRET_KEY Firebase secrets 등록**: `firebase functions:secrets:set TOSS_SECRET_KEY`
2. **Cloud Functions 배포**: `firebase deploy --only functions` (functions/ 디렉토리에서 `npm install` 선행 필요)
3. **TOSS_CLIENT_KEY dart-define 등록**: IDE Run Configuration 또는 `flutter run --dart-define=TOSS_CLIENT_KEY=test_ck_xxx`
4. **iOS / Android 실기기 빌드 테스트**: Toss SDK deeplink 복귀 동작 확인 필요 (시뮬레이터에서는 카카오페이 외부 앱 전환 불가)
5. **Firestore 색인 생성**: 내 주문 목록 / 점주 주문 리스트 쿼리에 복합 색인 필요 — Console 또는 `firestore.indexes.json`
6. **functions/tsconfig.json 빌드 확인**: `cd functions && npm install && npm run build`
7. **store 문서 ownerId 필드 확인**: Firestore 의 store 문서 owner 필드명이 `ownerId` 임을 확인 (`ownerUid` 아님 — Cloud Functions 권한 검증 로직과 일치해야 함)

---

## 14. 사용자 후속 결정 필요 항목

| # | 항목 | 현재 상태 |
|---|---|---|
| 1 | Toss 실 결제 키 발급 시점 | 테스트 키(`test_ck_xxx`)로 구현. 운영 배포 전 별도 task |
| 2 | 결제 수수료 분담 정책 | 미결정 (Toss 기본 수수료는 결제 금액의 일정 %). 정산 주기 / 분담 정책 확정 필요 |
| 3 | 환불 처리 SLA | 점주가 환불 요청을 몇 시간 내 응답해야 하는지 정책 미결정. 자동 환불(N시간 무응답 시) 도입 여부 |
| 4 | 점주 알림 채널 | FCM 도입 시점 결정 필요 (현재 in-app 다이얼로그만). 신규 주문 / 환불 요청 즉각 알림이 필요하면 Phase 3b 에서 FCM 병행 필요 |

---

## 15. 구현 준수 사항

- **Clean Architecture 레이어 경계 준수**: Firebase / Toss SDK 직접 사용은 `data` 레이어(`datasources/`)에서만. `domain` 및 `presentation` 에서 직접 import 없음.
- **색상 하드코딩 없음**: 모든 색상은 `AppColors` 토큰 사용. `Color(0x...)` 직접 사용 없음.
- **API key 하드코딩 없음**: `TOSS_CLIENT_KEY` 는 `String.fromEnvironment`, `TOSS_SECRET_KEY` 는 Firebase secrets.
- **flutter pub get**: 통과.
- **dart run build_runner build --delete-conflicting-outputs**: 통과 (27 freezed outputs).
- **flutter analyze**: No issues found.
