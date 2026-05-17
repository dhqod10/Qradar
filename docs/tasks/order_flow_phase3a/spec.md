# order_flow_phase3a 기능 명세 (결제 인프라 + 카드/카카오페이)

> 본 문서는 Qradar 결제 도입의 **첫 번째 phase**. 결제 SDK 의존성, 검증 파이프라인, 주문(`orders`) 도메인을 새로 도입한다.
>
> 큰 그림 단일 진실원: [docs/order_flow_summary.md](../../order_flow_summary.md) §3. Phase 3 예정 범위.
> 데이터 모델 / OrderLog 결정 단일 진실원: [order_flow_phase1/spec.md](../order_flow_phase1/spec.md) 결정 7 + [order_flow_phase2/spec.md](../order_flow_phase2/spec.md) 결정 E.

---

## 개요

- **목적**: 카트가 확정된 사용자가 **실제 결제(토스페이먼츠 카드 / 카카오페이)** 를 완료하고, 결제 결과를 검증한 뒤 Firestore `orders` 컬렉션에 주문 doc 을 생성한다. 결제 실패/취소 흐름, 매장 접수 전 customer 취소 흐름, Qoin 적립 hook 자리도 함께 마련한다.
- **작업 유형**: 신규 기능 (대규모). Phase 1/2 의 `OrderLog` 인프라와는 **별개 컬렉션(`orders`)** 으로 새 도메인을 도입한다. 결제 성공 후 기존 `OrderLog` 도 함께 기록한다 (Phase 2 의 추천 데이터 공급원 유지).
- **결제 PG**: 토스페이먼츠. Flutter SDK = [`tosspayments_widget_sdk_flutter`](https://pub.dev/packages/tosspayments_widget_sdk_flutter) 또는 공식 `tosspayments_payment_sdk` 중 하나 (developer 가 SDK 버전 조사 후 implementation.md 에 픽 사유 기록).
- **첫 결제 수단**: 신용/체크카드 (직접 입력) + 카카오페이.
- **비결제 수단(네이버페이, 토스페이, 삼성/애플페이, 계좌이체 등) 은 Phase 3b**.
- **Qoin 적립 / 사용**: Phase 4. 본 phase 는 **`onPaymentSuccess(order)` hook 자리만** 마련.

### 영향 범위

| 레이어 | 영향 |
|---|---|
| 화면 | (수정) `CartPage` "결제하기" placeholder → 결제 흐름 진입 / (신규) `CheckoutPage` (결제수단 선택 + 약관 동의 + 최종 결제) / (신규) `PaymentResultPage` (성공/실패/취소) / (신규) `OrderDetailPage` (주문 상세 + 영수증 + 취소 버튼) / (신규) `OrdersPage` (내 주문 목록 — placeholder 이상 최소 구현) / (수정) `LogPage` → 결제 완료된 주문을 OrderLog 기반 또는 orders 기반 중 선택 (결정 6 참조) |
| Domain | (신규) `OrderEntity`, `OrderItemEntity`, `PaymentInfoEntity`, `OrderStatus` enum, `PaymentMethod` enum, `PaymentChannel` enum / (신규) `OrderRepository` 인터페이스 / (신규) `PaymentGatewayRepository` 인터페이스 / (신규) UseCase 다수 / (신규) `QoinAccrualHook` 인터페이스 (빈 hook) |
| Data | (신규) Toss SDK 어댑터 (`TossPaymentRemoteDataSource`) / (신규) `OrderRemoteDataSource` (Firestore `orders/{orderId}`) / (신규) `OrderRepositoryImpl`, `PaymentGatewayRepositoryImpl` / (신규) Model (`OrderModel`, `PaymentInfoModel`) / Cloud Functions 코드 1종 (검증 webhook — **결정 1 채택 시**) |
| Presentation | (신규) `presentation/customer/checkout/` 페이지/Provider / (신규) `presentation/customer/order/orders/` 목록·상세 / (수정) `CartPage._CheckoutBar` / (수정/유지) `presentation/owner/placeholders/owner_orders_placeholder.dart` → 최소 접수 UI (결정 5 참조) |
| 공통 컴포넌트 | (신규) `PaymentMethodTile`, `OrderStatusBadge`, `ReceiptWebView` |
| 라우팅 | go_router 미도입 유지. `Navigator.push(MaterialPageRoute(...))` 패턴 그대로 (Phase 1/2 와 일관). 차후 일괄 마이그레이션 task. |
| 권한 / 환경 설정 | iOS Info.plist: 카카오톡 외부 호출 scheme (`kakaopay`, `kakaolink`), URL Type `tosspayments`. Android: deeplink intent filter, `INTERNET`, `ACCESS_NETWORK_STATE`. **`--dart-define` 으로 토스페이먼츠 client key / secret key 주입**. 절대 코드에 하드코딩 금지. |
| 테스트 | 결제는 Toss **테스트 환경** 사용 (`test_ck_xxx` client key). Production key 진입은 운영 배포 시 별도 task. |

### 비범위

본 phase 가 **명시적으로 다루지 않는** 항목 (Phase 3b 또는 별 phase).

- **나머지 결제 수단**: 네이버페이, 토스페이(Toss 자체 간편결제 UI), 삼성페이, 애플페이, 계좌이체, 휴대폰결제, 페이코, SSGPAY 등 — Phase 3b.
- **실제 Qoin 적립 / 사용 / 환불 시 회수**: Phase 4. 본 phase 는 빈 hook (`QoinAccrualHook.onOrderPaid(order)`) 만 등록하고 Provider 에서 `NoOpQoinAccrualHook()` 주입.
- **주문 상태 전체 전이 흐름** (`accepted` → `making` → `ready` → `completed`): Phase 3c 또는 별 phase. 본 phase 는 `paid` / `cancelled` / `refunded` 만 다룬다 (결정 3 참조).
- **점주 주문 접수 본격 UI**: 결정 5 의 **최소 접수 UI** (status 'paid' → 'cancelled by owner' 또는 환불 동의) 만 본 phase 포함. 그 다음 (`making` / `ready` / `completed` 전이) 은 별 phase.
- **매출 조회 (점주/관리자)**: 별 phase. 본 phase 는 `orders` 컬렉션 생성까지.
- **FCM 푸시 인프라 본격 도입** (FCM 토큰 관리 / sending pipeline / 토픽 구독): 결정 2 채택 시에만 본 phase 포함. **잠정 결정 = 본 phase 비범위, in-app 다이얼로그만**. (사용자 확인 항목 2 참조.)
- **결제 실패 retry 자동화** (PG 재시도 정책 / 큐): 본 phase 는 사용자 수동 재시도만.
- **할인 쿠폰 / 프로모션 코드 적용**: 별 phase. `OrderEntity.discount` 필드만 미리 둠 (`int? discount` 기본 null) — 확장성.
- **세금 / 부가세 분리 표시**: 별 phase. `totalPrice` 단일 필드.
- **간편결제 회원 카드 등록 / 빌링키 / 자동결제**: 별 phase.
- **영수증 PDF 발급 / 이메일 전송**: 토스가 제공하는 `receiptUrl` (web) 만 사용. 자체 발급 비범위.
- **장바구니 영속화**: Phase 1b 비범위 유지 — 결제 직전 카트 검증은 본 phase 포함하되 영속화는 별 phase.
- **Firestore 보안 규칙 작성**: 별 task. 본 spec 의 컬렉션 경로 / 필드를 그 task 의 입력으로 메모.
- **다국어 / 외국인 카드 결제 / 해외 결제**: 별 phase.

---

## architect 잠정 결정 (사용자 확인 필요)

⚠ 아래 결정 1~6 은 architect 잠정안이다. **사용자 승인 후 designer / developer 호출**.

### 결정 1. 결제 검증 방식 — **(C) 클라이언트 콜백 + Cloud Functions 검증** (architect 추천)

| 옵션 | 장점 | 단점 |
|---|---|---|
| (A) 클라이언트 검증 only | 구현 단순, 서버 인프라 0 | **결제 위변조 위험**: 클라이언트가 주문 doc 의 `paidAt`/`totalPrice` 를 임의로 set 가능. Firestore 보안 규칙으로도 결제 성공 사실을 검증할 수 없음 |
| (B) Webhook 서버 only | 표준, 변조 차단 | 웹훅 도착 시점이 사용자 결제 완료 후 수 초 지연 가능 → 사용자 UX (결제 결과 화면) 가 "대기 중" 상태로 머뭇거림 |
| **(C) 하이브리드: 클라이언트 콜백 → Cloud Functions `verifyPayment(paymentKey, orderId, amount)` 호출 → Toss Server API 로 confirm + verify → Firestore `orders/{orderId}` write** | **변조 차단 + UX 즉시 반영**. Toss 공식 권장. Cloud Functions 라 별도 서버 운영 부담 X | Cloud Functions 1개 추가 운영 (cold start 1~2s 가능) |

채택 = **(C)**. 아래 흐름:

```
1. CartPage → CheckoutPage → 토스페이먼츠 SDK launch
2. 사용자가 SDK 결제창에서 결제 완료
3. SDK success callback (paymentKey, orderId, amount) 수신
4. Cloud Functions HTTPS Callable `verifyTossPayment` 호출
   - Functions 내부: Toss Server API `POST /v1/payments/confirm` 호출 (secret key 사용)
   - Toss 응답의 amount 와 사용자 입력 amount 일치 검증
   - Toss 응답의 status == 'DONE' 검증
   - Firestore `orders/{orderId}` set (status='paid', paymentInfo with Toss receipt url)
   - 동시에 `users/{uid}/orderLogs/{logId}` append (기존 phase 2 인프라 — Qoin/추천 데이터)
5. Functions 응답 받으면 클라이언트가 PaymentResultPage 로 전환
6. 클라이언트는 `orders/{orderId}` doc 만 ref.watch 해서 표시 (소스 오브 트루스 = Firestore)
```

**Cloud Functions 작성 범위 (Phase 3a 포함)**:
- `functions/src/payments/verifyTossPayment.ts` (또는 .js / Dart Functions)
- Toss secret key 는 Functions 환경 변수 (`firebase functions:config:set toss.secret=...`)
- 입력: `{paymentKey, orderId, amount, cartSnapshot}` — `cartSnapshot` 은 클라이언트가 결제 직전 캡처한 카트 상태 (items, totalPrice). Functions 가 이를 사용해 orders/orderLogs doc 생성.
- 출력: `{success: true, orderId}` 또는 throwable HttpsError

> **Cloud Functions 코드를 본 repo 의 어디에 둘지** — architect 권장 = repo 루트에 `functions/` 디렉토리 신설 (Firebase 표준). 또는 별도 repo. 사용자 확인 필요 (사용자 확인 항목 6).
>
> Toss secret key 가 클라이언트에 절대 노출되면 안 되므로 (B)/(C) 둘 다 서버 코드가 필수. (A) 는 Toss 가 "테스트 모드에서만 허용" 하고 운영 부적합.

### 결정 2. FCM 푸시 알림 — **본 phase 비범위 (in-app 다이얼로그 only)**

| 옵션 | architect 의견 |
|---|---|
| (A) 본 phase 에 FCM 인프라 도입 | FCM 토큰 관리, sending pipeline, 토픽 구독, iOS APNs, Android channel 설정 등 작업량이 결제 본구현 만큼 큼. 결제 흐름과 결합도 낮음 |
| **(B) in-app 다이얼로그 only** (architect 추천) | 결제 실패는 **사용자가 결제 흐름 안에 있을 때만 발생** 가능. 백그라운드 결제 실패는 (현재 시나리오상) 거의 없음. 단, Toss 결제창이 외부 앱(카카오톡 등) 으로 잠시 빠졌다가 돌아오는 경우는 in-app 다이얼로그로 충분 |
| (C) FCM 도입 + in-app 모두 | 본 phase 비범위. 향후 "점주가 주문 거절했을 때 customer 에게 푸시" 등으로 묶어서 별 phase 진행 권장 |

채택 = **(B)**. 결제 실패는 **결제 흐름 화면(`CheckoutPage` / `PaymentResultPage`) 내 다이얼로그** 로만 알린다. FCM 인프라는 별 phase. 단, 본 spec 의 **`PaymentResultPage` 구조는 향후 FCM 푸시 알림 진입점으로도 재사용 가능하도록 deep-link 친화적 URL 시그니처 (예: `orderId`) 를 받는 형태**로 설계.

### 결정 3. 주문 상태 흐름 — Phase 3a 는 **`paid` / `cancelled` / `refunded`** 까지

| 옵션 | 범위 |
|---|---|
| (A) status='paid' 만 | 결제 후 흐름 0. 취소도 안 됨. Phase 1b 결제 placeholder 보다 약간 큰 수준. **부족** |
| **(B) `paid` + `cancelled` + `refunded`** (architect 추천) | 사용자 요청 범위와 정확히 일치. 점주 접수 흐름(`accepted` 등) 은 별 phase |
| (C) 전체 흐름 | 점주 UI 본구현 필요. Phase 3a 비대. 별 phase 권장 |

채택 = **(B)**.

`OrderStatus` enum 정의 (본 phase 사용 + 향후 확장):

```dart
enum OrderStatus {
  /// 결제 완료. 매장 접수 대기. customer 가 취소 가능.
  paid,
  /// (Phase 3a 비범위, enum 만 정의) 매장이 접수. customer 취소 불가. 환불 흐름만 가능.
  accepted,
  /// (Phase 3a 비범위) 제조 중.
  making,
  /// (Phase 3a 비범위) 픽업 대기 (사이렌오더).
  ready,
  /// (Phase 3a 비범위) 픽업 완료. 정상 종료.
  completed,
  /// customer 가 결제 후 매장 접수 전에 직접 취소 → PG 취소 API 호출.
  cancelled,
  /// 매장 접수 후 customer 요청 → 점주 동의 → PG 환불 API 호출.
  refunded,
}
```

**본 phase 작성 범위**:
- 전이: `paid → cancelled` (customer 직접, 매장 접수 전), `paid → refunded` (customer 요청 + 점주 동의)
- `accepted` / `making` / `ready` / `completed` 전이는 본 phase **비범위** (enum 만 선언, 점주 화면은 별 phase)
- 단 점주가 본 phase 의 최소 접수 UI 에서 "주문 받기" 버튼을 누르면 `paid → accepted` 까지는 transit (결정 5 참조). 그 후 단계는 placeholder.

### 결정 4. 환불 흐름 — **Phase 3a 포함** (customer 요청 + owner 동의 흐름까지)

옵션:
- (A) 본 phase 비포함 — 환불 도메인은 별 phase
- **(B) 본 phase 포함** — 사용자가 phase 3a 범위에 명시했고, `refunded` 상태 전이도 phase 3a 범위. 점주 동의 UI 도 결정 5 의 "최소 접수 UI" 안에 같이 포함.

채택 = **(B)**. 단, 환불은 **부분 환불 비범위, 전액 환불만** (단순화). 부분 환불은 별 phase.

흐름:

```
[Customer]
OrderDetailPage (status='accepted' 이상) → "환불 요청" 버튼
  → 사유 입력 다이얼로그 (선택 사유 + free text)
  → orders/{orderId} 에 refundRequest 필드 set ({reason, requestedAt})
  → 점주에게 알림 (Phase 3a 는 in-app 만 — owner 가 OwnerOrdersPlaceholder 화면 진입 시 새 요청 리스트 표시)

[Owner]
OwnerOrdersPlaceholder → 환불 요청 리스트 → "환불 승인" / "거절"
  → 승인: Cloud Functions `processRefund(orderId)` 호출
       → Toss Server API `POST /v1/payments/{paymentKey}/cancel` (cancelReason 포함)
       → orders/{orderId}.status = 'refunded', refundInfo set
       → OrderLog 에 환불 표기 (paymentMethod 등은 그대로, 별도 cancelledAt 필드)
  → 거절: refundRequest.deniedAt / deniedReason set, status 그대로
```

> **부분 환불, 자동 환불 (예: 매장이 N시간 내 접수 안 하면 자동 취소)** 은 본 phase 비범위.
> Customer 가 직접 cancel (status=paid 일 때) 은 점주 동의 없이도 가능 (사용자 정의 = "매장 접수 전") → Toss API 호출 직접.

### 결정 5. 점주 주문 접수 UI — **Phase 3a 에 "최소 접수 UI" 포함**

옵션:
- (A) Phase 3a 비포함 — owner placeholder 유지
- **(B) "최소 접수 UI" 만 포함** — 새 paid 주문 리스트 + "주문 받기 (accepted)" / "취소(점주 측 사유)" 버튼 + 환불 요청 처리. 이후 `making`/`ready`/`completed` 전이는 placeholder

채택 = **(B)** 이유:
- 결정 4 의 환불 점주 동의 흐름이 owner UI 없으면 동작 불가
- "주문 받기" 버튼이 있어야 customer 의 cancel 윈도우가 닫힘 (`paid → accepted` 후 customer cancel 불가)
- 그 이상 (`making`/`ready`/`completed`) 은 Phase 3c (운영 흐름) 로 분리

**Phase 3a 의 owner 측 작업 (최소)**:
- `OwnerOrdersPage` (현 placeholder 자리 대체) — 탭 2개: "신규(paid)" / "환불 요청"
- "신규" 탭: paid 주문 카드 리스트 + "주문 받기" 버튼 (→ `paid → accepted`) + "거절(매장 사유)" 버튼 (→ `paid → cancelled`, Toss cancel API 호출)
- "환불 요청" 탭: refundRequest 있는 주문 카드 리스트 + "승인 / 거절"
- 그 외 status (`accepted`/`making`/`ready`/`completed`) 의 진행 화면은 본 phase **placeholder 유지** (별 phase 에서 본구현)

### 결정 6. `OrderEntity` 와 기존 `OrderLogEntity` 의 관계

Phase 2 의 `OrderLogEntity` (`users/{uid}/orderLogs/{logId}`) 는 **추천 알고리즘용 read-optimized snapshot**. Phase 3a 의 `OrderEntity` (`orders/{orderId}`) 는 **결제/취소/환불의 source of truth**.

| 항목 | OrderEntity (`orders/{orderId}`) | OrderLogEntity (`users/{uid}/orderLogs/{logId}`) |
|---|---|---|
| 목적 | 결제/주문 상태 source of truth | 추천 알고리즘 read snapshot |
| 라이프사이클 | 결제 시 생성. status 전이로 업데이트. 환불/취소도 update | 결제 성공 시 1회 append. 이후 mutate 안 함 |
| 점주 read 가능 | O (점주가 자기 매장 주문 봄) | X (사용자별 서브컬렉션) |
| 환불 표기 | status='refunded', refundInfo | 별도 mutate 안 함. 단 별 phase 에서 `cancelledAt` 등 추가 가능 |

본 phase 작성 결정:
- Cloud Functions `verifyTossPayment` 가 **둘 다 atomic 하게 set** (Firestore batch). 트랜잭션 안에서 `orders/{orderId}` + `users/{uid}/orderLogs/{logId}` 동시 write.
- 환불/취소 시 OrderLog 는 mutate 안 함 (추천 알고리즘이 환불도 "주문 빈도" 로 계산해도 무방. 정밀화는 별 phase).
- `LogPage` 화면은 **`OrderLog` 가 아닌 `OrderEntity` 기반으로 재구성** — status/환불 표시가 필요하므로. → Phase 3a 에서 `LogPage` 본구현. (현재는 placeholder 텍스트만 있음. 본 phase 가 채움.)

---

## 사용자 확인 항목

| # | 항목 | architect 잠정안 | 사용자 확정 필요 |
|---|---|---|---|
| 1 | 결제 검증 방식 | (C) Cloud Functions 하이브리드 (Toss confirm API) | confirm — A/B 도 가능 |
| 2 | FCM 푸시 | 본 phase 비범위, in-app 다이얼로그만 | confirm — FCM 본 phase 도입 원하면 변경 |
| 3 | 주문 상태 흐름 | (B) paid + cancelled + refunded | confirm |
| 4 | 환불 흐름 | 본 phase 포함, 전액만 (부분 환불 비범위) | confirm — 별 phase 로 빼도 됨 |
| 5 | 점주 최소 접수 UI | "신규(paid)" / "환불 요청" 두 탭. accepted 이후 placeholder | confirm — 더 줄이거나 늘려도 됨 |
| 6 | Cloud Functions 코드 위치 | repo 루트에 `functions/` 신설 | confirm — 별 repo 분리도 가능 |
| 7 | Toss SDK 패키지 선택 | `tosspayments_widget_sdk_flutter` vs `tosspayments_payment_sdk` — developer 가 결제창 UX / 지원 결제수단 / 유지보수성 비교 후 선정 | confirm — architect 가 결정 위임 가능 |
| 8 | `OrderEntity.totalPrice` 필드 단위 | 모든 금액은 **int (원)** 으로 통일 (Phase 1 패턴) | confirm — 변경 가능성 낮음 |
| 9 | `paymentMethod` enum 화 | Phase 1a 의 String → enum (`card`, `kakaoPay`, ...). 본 phase 에서 enum 도입 + OrderLogEntity 의 String 필드는 보조 라벨로 둠 (직렬화 시 enum.code) | confirm |
| 10 | `LogPage` 본구현 — 본 phase 범위 | 포함. `orders` 컬렉션 기반 (status / refunded 표시 가능) | confirm — Phase 3b 로 빼도 됨 |
| 11 | 결제 실패 후 카트 유지 정책 | **카트 유지** (사용자가 즉시 재시도 가능). 결제 성공 시에만 카트 clear | confirm |
| 12 | 동일 카트 중복 결제 방지 | 결제 시작 시점에 `idempotencyKey` (uuid v4) 생성. `orders/{idempotencyKey}` 사용 (Firestore doc id = idempotencyKey). Toss `orderId` 도 동일 값 사용. 사용자가 결제창 중복 진입해도 같은 doc 에 merge | confirm |

---

## 요구사항

### 기능 요구사항

#### 결제 시작 (CartPage → CheckoutPage)
- [ ] `CartPage._CheckoutBar` 의 "결제하기" 버튼 placeholder SnackBar 제거
- [ ] 비로그인 / 카트 비어있음 / 매장 영업 중지 / 메뉴 품절 변경 시 → 다이얼로그로 차단 (가격/품절 검증은 결제 직전 단계)
- [ ] "결제하기" 탭 → `CheckoutPage` push (`MaterialPageRoute`)
- [ ] `CheckoutPage` 진입 시 카트 스냅샷 캡처 (immutable), 결제 도중 카트 변경되어도 무관

#### CheckoutPage (결제수단 선택)
- [ ] 주문 요약 (매장명, 라인 N개, 합계)
- [ ] 결제수단 선택 (라디오): "신용/체크카드", "카카오페이"
- [ ] 약관 동의 ("전자결제 이용 약관" / "개인정보 제3자 제공" 동의 — 토스 표준 텍스트)
- [ ] 하단 고정 "X,XXX원 결제하기" 버튼
- [ ] 결제 시작 시 `idempotencyKey` (uuid v4) 생성, 이후 모든 단계에서 동일 키 사용
- [ ] Toss SDK 호출 (선택된 결제수단에 따라 분기)

#### Toss SDK 결제창
- [ ] 카드: 직접 입력 결제창
- [ ] 카카오페이: 카카오톡 외부 호출 (deeplink) → 인증 완료 후 앱 복귀
- [ ] 결제 진행 중 UI: 로딩 인디케이터 (Toss SDK 자체가 webview/native 제공하므로 별도 화면 X, **앱 복귀까지 기다리는 동안 CheckoutPage 는 disabled 상태**)

#### 결제 결과 처리
- [ ] SDK success callback: `(paymentKey, orderId, amount)` 수신 → Cloud Functions `verifyTossPayment` 호출
- [ ] SDK fail callback: `(errorCode, message)` 수신 → 다이얼로그 노출 + 사용자 "재시도" / "결제 수단 변경" / "취소" 선택
- [ ] SDK cancel callback (사용자가 결제창 닫음): "결제가 취소되었습니다" 다이얼로그 → CartPage 로 복귀, 카트 유지

#### Cloud Functions verifyTossPayment
- [ ] 입력 검증 (paymentKey/orderId/amount/cartSnapshot 필수)
- [ ] Toss Server API `POST /v1/payments/confirm` 호출 (secret key, basic auth)
- [ ] Toss 응답 검증: `status == 'DONE'`, `totalAmount == cartSnapshot.totalPrice`
- [ ] Firestore batch: `orders/{orderId}` set + `users/{uid}/orderLogs/{logId}` append
- [ ] 응답: `{success: true}` (실패 시 throwable HttpsError with code)

#### PaymentResultPage
- [ ] 성공/실패/취소 3가지 변형
- [ ] 성공: 큰 체크 아이콘 + "결제가 완료되었어요" + 주문번호 + "주문 상세 보기" 버튼 → `OrderDetailPage` push
- [ ] 실패: 큰 X 아이콘 + 에러 메시지 + "다시 시도" / "결제 수단 변경" / "닫기"
- [ ] 취소: 정보 아이콘 + "결제가 취소되었어요" + "닫기"
- [ ] 카트는 성공 시에만 자동 clear (`clearCartUseCase`)
- [ ] 성공 시 `onPaymentSuccess(OrderEntity)` hook 호출 (Phase 3a 는 NoOp / Phase 4 에서 Qoin 적립 로직 주입)

#### OrderDetailPage (customer)
- [ ] 주문 상태 뱃지 (paid / cancelled / refunded)
- [ ] 주문 라인 리스트 (라인 옵션 포함)
- [ ] 합계
- [ ] 결제 정보 (수단, 카드사/계좌 마스킹된 표시 = Toss 응답 활용)
- [ ] **영수증 보기** 버튼 → `ReceiptWebView` (Toss `receiptUrl` 을 webview 로 호스트)
- [ ] **취소** 버튼 — status='paid' 일 때만 노출. 탭 → 확인 다이얼로그 → Cloud Functions `cancelTossPayment(orderId, reason='customer_request')` 호출 → 성공 시 status='cancelled' 반영
- [ ] **환불 요청** 버튼 — status='accepted'/'making'/'ready' 일 때 노출. 탭 → 사유 입력 다이얼로그 → `orders/{orderId}.refundRequest = {reason, requestedAt}` set. 점주 동의 대기 안내

#### OrdersPage (customer 내 주문 목록 = LogPage 본구현)
- [ ] 현 `LogPage` 의 placeholder 제거
- [ ] `orders` 컬렉션을 `where('userId', '==', uid)` + `orderBy('createdAt', desc)` 로 stream
- [ ] 카드 리스트: 매장명, 라인 요약(첫 메뉴 외 N개), 합계, 상태 뱃지, 시각 (RelativeTimeFormatter)
- [ ] 카드 탭 → `OrderDetailPage` push
- [ ] 빈 상태: "아직 주문이 없어요" + "둘러보기" 버튼

#### OwnerOrdersPage (점주 최소 접수 UI)
- [ ] 현 `OwnerOrdersPlaceholder` 자리 대체
- [ ] 탭 2개: "신규" / "환불 요청"
- [ ] 신규: `where('storeId', '==', myStoreId)` + `where('status', '==', 'paid')` stream
  - 카드: 시각, 라인 요약, 합계
  - "주문 받기" 버튼 → status='paid' → 'accepted' (Firestore set + accepted_at)
  - "거절" 버튼 → 사유 다이얼로그 → Cloud Functions `cancelTossPayment(orderId, reason='store_reject')` → status='cancelled'
- [ ] 환불 요청: `where('storeId', '==', myStoreId)` + `where('refundRequest', '!=', null)` + `where('status', '!=', 'refunded')` stream
  - "승인" → Cloud Functions `processRefund(orderId)` → Toss cancel API → status='refunded'
  - "거절" → `refundRequest.deniedAt`/`deniedReason` set, status 그대로
- [ ] accepted/making/ready 등의 status 표시는 본 phase placeholder (별도 화면)

### 상태 요구사항

| 화면 | loading | error | empty |
|---|---|---|---|
| CheckoutPage | 결제 진행 중 (Toss SDK 호출 후 callback 대기) → disabled | Toss SDK 초기화 실패 시 다이얼로그 + 뒤로가기 | 카트 비어있음 시 진입 자체 차단 |
| PaymentResultPage | (없음 — verifyTossPayment 결과 받고 진입) | 검증 실패 시 fail 변형 | — |
| OrderDetailPage | Firestore stream 로딩 | doc 없음 → "주문을 찾을 수 없어요" | — |
| OrdersPage | stream 로딩 → shimmer | stream error → 에러 카드 + 재시도 | "아직 주문이 없어요" + CTA |
| OwnerOrdersPage | stream 로딩 → shimmer | stream error → 에러 카드 | "신규 주문이 없어요" / "환불 요청이 없어요" |

---

## 데이터 모델

### Enum

#### `OrderStatus`
- 본 phase 사용: `paid`, `cancelled`, `refunded`
- 본 phase 정의(만): `accepted`, `making`, `ready`, `completed` (Phase 3c 활용)
- Firestore 직렬화 = lower snake case String (`'paid'`, `'cancelled'` ...)

#### `PaymentMethod` (사용자 결제수단)
- 본 phase: `card`, `kakaoPay`
- Phase 3b 확장: `naverPay`, `tossPay`, `samsungPay`, `applePay`, `bankTransfer`, `mobile`, `payco`
- Firestore 직렬화 = camelCase String

#### `PaymentChannel` (PG 사) — 본 phase 는 `toss` 만
- `toss`
- 확장성 위해 enum (Phase 3b 에서 다른 PG 도입 시 추가 — 현재는 토스 통합이므로 의미 약함, 그래도 형식 분리)

### Entity

#### `OrderEntity`
| 필드 | 타입 | 설명 |
|---|---|---|
| id | String | doc id, = idempotencyKey = Toss orderId |
| userId | String | customer uid (Phase 1c 의 카카오/네이버 prefix 포함 uid) |
| storeId | String | |
| storeName | String | 시점 스냅샷 |
| brandId | String? | 매장이 속한 브랜드 (없으면 null) |
| items | List<OrderItemEntity> | 라인 |
| subtotal | int | 옵션 포함 라인 합계 (원) |
| discount | int? | 본 phase 미사용. 향후 쿠폰 등 (null) |
| totalPrice | int | subtotal - (discount ?? 0). Toss confirm 검증의 amount 와 일치 |
| status | OrderStatus | |
| paymentInfo | PaymentInfoEntity | |
| refundRequest | RefundRequestEntity? | customer 환불 요청 정보 |
| refundInfo | RefundInfoEntity? | 환불 완료 정보 |
| createdAt | DateTime | 결제 완료 시각 (= Toss `approvedAt`) |
| updatedAt | DateTime | 마지막 mutate 시각 |
| acceptedAt | DateTime? | 점주 접수 시각 (Phase 3c 활용, 본 phase 도 set) |
| cancelledAt | DateTime? | |
| refundedAt | DateTime? | |

#### `OrderItemEntity`
| 필드 | 타입 | 설명 |
|---|---|---|
| menuItemId | String | |
| menuItemName | String | 시점 스냅샷 |
| imageUrl | String | |
| quantity | int | |
| selectedOptions | List<SelectedOption> | Phase 1 의 SelectedOption 재사용 |
| unitPriceWithOptions | int | basePrice + option deltas |
| lineTotal | int | unitPriceWithOptions × quantity |

#### `PaymentInfoEntity`
| 필드 | 타입 | 설명 |
|---|---|---|
| method | PaymentMethod | |
| channel | PaymentChannel | 본 phase 는 항상 `toss` |
| paymentKey | String | Toss `paymentKey` |
| transactionId | String? | Toss `transactionKey` (회계용) |
| receiptUrl | String? | Toss `receipt.url` |
| approvedAt | DateTime | Toss `approvedAt` |
| amount | int | Toss confirm 검증 amount |
| cardCompany | String? | 카드사명 (Toss `card.company`) |
| cardNumberMasked | String? | "1234-****-****-5678" (Toss `card.number` 마스킹 처리) |
| easyPayProvider | String? | 카카오페이 등 (`'KAKAOPAY'`) |

#### `RefundRequestEntity`
| 필드 | 타입 | 설명 |
|---|---|---|
| reason | String | customer 사유 (선택 사유 + free text 합본) |
| requestedAt | DateTime | |
| deniedAt | DateTime? | 점주가 거절했을 때 |
| deniedReason | String? | |

#### `RefundInfoEntity`
| 필드 | 타입 | 설명 |
|---|---|---|
| cancellationKey | String | Toss `cancels[].transactionKey` |
| reason | String | |
| approvedBy | String | 'customer' (paid 단계 직접 취소) / 'owner' (환불 동의) / 'store_reject' (점주 거절) |
| processedAt | DateTime | |
| amount | int | 전액 환불 = totalPrice |

### DTO / Model

Firestore 직렬화 규칙:
- `DateTime` ↔ `Timestamp`
- enum ↔ String code (직렬화 시 항상 `.name`, 역직렬화 시 `OrderStatus.values.firstWhereOrNull`)
- 금액은 모두 int (원)
- `paymentInfo` 등 nested object 는 Firestore `Map<String, dynamic>` 로 평탄화 (서브컬렉션 X)

### Firestore 컬렉션 구조

```
orders/{orderId}                         # top-level 컬렉션 (점주가 자기 매장 주문 read 필요 → top-level 이 유리)
  userId: string
  storeId: string
  storeName: string
  brandId: string?
  items: array<map>
  subtotal: number (int)
  discount: number? (int)
  totalPrice: number (int)
  status: string                          # OrderStatus.name
  paymentInfo: map                        # PaymentInfo 평탄화
  refundRequest: map?                     # null 또는 RefundRequest 평탄화
  refundInfo: map?
  createdAt: Timestamp
  updatedAt: Timestamp
  acceptedAt: Timestamp?
  cancelledAt: Timestamp?
  refundedAt: Timestamp?
```

> **참고**: top-level `orders/{orderId}` 채택 이유 — 점주가 `where('storeId', '==', myStoreId)` 쿼리로 자기 매장 주문을 read 해야 하므로 user 서브컬렉션 구조 (`users/{uid}/orders`) 는 부적합. Phase 2 의 `OrderLog` 는 사용자별 read 만 하면 되어서 서브컬렉션이지만, `OrderEntity` 는 점주 / 관리자 / customer 셋 다 다른 쿼리 패턴이라 top-level 이 표준.

`FirestorePaths` 추가:
```dart
/// 주문 (결제 완료된) top-level 컬렉션. Phase 3a.
static const String orders = 'orders';
```

---

## 레이어 설계

### Domain (`lib/domain/`)

**Entities (신규)**:
- `entities/order_entity.dart`
- `entities/order_item_entity.dart`
- `entities/payment_info_entity.dart`
- `entities/refund_request_entity.dart`
- `entities/refund_info_entity.dart`
- `entities/order_status.dart` (enum)
- `entities/payment_method.dart` (enum)
- `entities/payment_channel.dart` (enum)

**Repository Interface (신규)**:
- `repositories/order_repository.dart`
  - `Stream<OrderEntity?> watchOrder(String orderId)`
  - `Stream<List<OrderEntity>> watchUserOrders(String userId)`
  - `Stream<List<OrderEntity>> watchStoreOrders(String storeId, {Set<OrderStatus>? statusFilter})`
  - `Stream<List<OrderEntity>> watchStoreRefundRequests(String storeId)`
  - `Future<void> setAcceptedByOwner(String orderId)`
  - `Future<void> requestRefund(String orderId, String reason)`
  - `Future<void> denyRefundRequest(String orderId, String deniedReason)`
- `repositories/payment_gateway_repository.dart`
  - `Future<PaymentLaunchResult> launchPayment({required PaymentMethod method, required String idempotencyKey, required int amount, required String orderName, required String customerEmail, required String customerName})`
  - `Future<OrderEntity> verifyAndCreateOrder({required String paymentKey, required String orderId, required int amount, required CartEntity cartSnapshot})`
  - `Future<void> cancelPaidOrder({required String orderId, required String reason, required String approvedBy})` — paid → cancelled (customer 직접 or 점주 거절)
  - `Future<void> processRefund({required String orderId, required String reason})` — accepted+ → refunded
- `repositories/qoin_accrual_hook.dart` (인터페이스, 본 phase Impl 은 NoOp)
  - `Future<void> onOrderPaid(OrderEntity order)`
  - `Future<void> onOrderRefunded(OrderEntity order)` (향후 Qoin 회수 hook)

**UseCases (신규)**:
- `domain/usecases/launch_payment_use_case.dart`
- `domain/usecases/verify_and_create_order_use_case.dart`
- `domain/usecases/cancel_paid_order_use_case.dart`
- `domain/usecases/request_refund_use_case.dart`
- `domain/usecases/deny_refund_request_use_case.dart`
- `domain/usecases/process_refund_use_case.dart`
- `domain/usecases/accept_order_use_case.dart`
- `domain/usecases/watch_order_use_case.dart`
- `domain/usecases/watch_user_orders_use_case.dart`
- `domain/usecases/watch_store_orders_use_case.dart`
- `domain/usecases/watch_store_refund_requests_use_case.dart`

> 기존 `WriteOrderLogUseCase` (Phase 2) 는 본 phase 의 `VerifyAndCreateOrderUseCase` **내부에서 호출 또는 Cloud Functions 가 OrderLog 도 같이 write** 하는 두 가지 옵션 중 **후자 채택** (배치 atomic). 본 phase 의 client UseCase 는 OrderLog 를 직접 건드리지 않음.

### Data (`lib/data/`)

**Models (신규)**:
- `models/order_model.dart` (freezed + manual fromFirestore/toFirestore — 기존 패턴 일관)
- `models/order_item_model.dart`
- `models/payment_info_model.dart`
- `models/refund_request_model.dart`
- `models/refund_info_model.dart`

**DataSources (신규)**:
- `datasources/remote/order_remote_data_source.dart`
  - `Stream<OrderModel?> watchOrder(orderId)`
  - `Stream<List<OrderModel>> watchUserOrders(userId)`
  - `Stream<List<OrderModel>> watchStoreOrders(storeId, statusFilter)`
  - `Stream<List<OrderModel>> watchStoreRefundRequests(storeId)`
  - `Future<void> updateStatus(orderId, OrderStatus next, {accepted_at, cancelled_at, refunded_at})`
  - `Future<void> setRefundRequest(orderId, RefundRequestModel)`
  - `Future<void> setRefundDenied(orderId, deniedAt, deniedReason)`
- `datasources/remote/toss_payment_remote_data_source.dart`
  - `Future<TossPaymentResult> launchPayment(...)` — Toss SDK 호출 wrapper
  - `Future<dynamic> callVerifyTossPayment(payload)` — Cloud Functions HTTPS callable wrapper
  - `Future<dynamic> callCancelTossPayment(orderId, reason)`
  - `Future<dynamic> callProcessRefund(orderId, reason)`
  - **Toss SDK / Firebase Functions 직접 사용은 본 DataSource 내부에서만**.

**Repository Implementation (신규)**:
- `repositories/order_repository_impl.dart`
- `repositories/payment_gateway_repository_impl.dart`
- `repositories/noop_qoin_accrual_hook.dart` — Phase 3a 의 빈 hook 구현 (Phase 4 에서 real impl 로 교체)

**Cloud Functions (신규 — 별 디렉토리 `functions/`)**:
- `functions/src/payments/verifyTossPayment.ts`
- `functions/src/payments/cancelTossPayment.ts`
- `functions/src/payments/processRefund.ts`
- `functions/src/payments/_toss_client.ts` — Toss Server API 래퍼 (axios / fetch + secret key)
- Deploy: `firebase deploy --only functions`

### Presentation

**Pages (신규)**:
- `presentation/customer/checkout/checkout_page.dart`
- `presentation/customer/checkout/payment_result_page.dart`
- `presentation/customer/checkout/widgets/receipt_web_view.dart`
- `presentation/customer/order/orders/orders_page.dart` (기존 `LogPage` 대체 또는 그 자리에 매핑)
- `presentation/customer/order/orders/order_detail_page.dart`
- `presentation/owner/orders/owner_orders_page.dart` (현 placeholder 자리 대체)
- `presentation/owner/orders/widgets/owner_new_order_tile.dart`
- `presentation/owner/orders/widgets/owner_refund_request_tile.dart`

**Widgets (신규)**:
- `presentation/common/order_status_badge.dart`
- `presentation/customer/checkout/widgets/payment_method_tile.dart`
- `presentation/customer/checkout/widgets/checkout_summary_card.dart`

**Providers (신규)**:
- `presentation/customer/checkout/providers/checkout_providers.dart`
  - `paymentMethodProvider` (NotifierProvider — 선택된 결제수단)
  - `idempotencyKeyProvider` (Provider.family<String, void>) — CheckoutPage 진입 시 1회 생성
  - `checkoutSnapshotProvider` — 카트 immutable snapshot
- `presentation/customer/order/orders/providers/orders_providers.dart`
  - `userOrdersProvider` (StreamProvider<List<OrderEntity>>)
  - `orderDetailProvider` (StreamProvider.family<OrderEntity?, String orderId>)
- `presentation/owner/orders/providers/owner_orders_providers.dart`
  - `ownerNewOrdersProvider` (StreamProvider — status='paid')
  - `ownerRefundRequestsProvider` (StreamProvider)
- 공통 DI (`order_repository`, `payment_gateway_repository`, `qoin_accrual_hook` 의 Provider 등록):
  - 신규: `presentation/customer/checkout/providers/payment_di.dart` 또는 기존 phase2 의 `recommendation_providers.dart` 와 함께 묶음 (architect 권장 = 결제 도메인 전용 `payment_di.dart`)

**라우팅**: `Navigator.push(MaterialPageRoute(...))` 패턴 유지.
- `CartPage` "결제하기" → `CheckoutPage`
- `CheckoutPage` 결제 완료 → `PaymentResultPage` (replace)
- `PaymentResultPage` "주문 상세 보기" → `OrderDetailPage` (replace)
- `OrdersPage` 카드 탭 → `OrderDetailPage`
- `OwnerOrdersPage` 카드 탭 → `OrderDetailPage` (owner 시야)

---

## 데이터 흐름

### 결제 시작 → 결제 완료 → 주문 doc 생성

```
CartPage._CheckoutBar "결제하기"
  → CartPage 사전 가드: 비로그인, 카트 비어있음, 매장 영업 정지, 메뉴 품절 변경
  → context.push(MaterialPageRoute(builder: (_) => CheckoutPage(snapshot: cart)))

CheckoutPage build
  → ref.watch(checkoutSnapshotProvider)
  → 결제수단 라디오, 약관 동의

CheckoutPage "결제하기" 탭
  → idempotencyKey = ref.read(idempotencyKeyProvider)
  → launchPaymentUseCase(
       method: selectedMethod,
       idempotencyKey: idempotencyKey,
       amount: cart.totalPrice,
       orderName: '...',
       customerEmail/Name: from authProvider
     )
  → paymentGatewayRepository.launchPayment(...)
  → tossPaymentRemoteDataSource.launchPayment(...) (Toss SDK)
  → SDK 결제창 (카드: in-app, 카카오페이: 외부 앱)

SDK callback (success)
  (paymentKey, orderId=idempotencyKey, amount)
  → verifyAndCreateOrderUseCase(paymentKey, orderId, amount, cartSnapshot)
  → paymentGatewayRepository.verifyAndCreateOrder(...)
  → tossPaymentRemoteDataSource.callVerifyTossPayment(payload) (Cloud Functions HTTPS callable)

[Cloud Functions verifyTossPayment]
  1. payload 검증
  2. Toss Server API POST /v1/payments/confirm (secret key)
  3. 응답 검증 (status='DONE', amount 일치)
  4. Firestore batch:
     - orders/{orderId} set (status='paid', paymentInfo)
     - users/{uid}/orderLogs/{logId} append (Phase 2 OrderLog 패턴)
  5. response: {success: true}

→ Cloud Functions 응답 받으면
  → ref.read(clearCartUseCaseProvider).call()  // 카트 비움
  → ref.read(qoinAccrualHookProvider).onOrderPaid(order)  // NoOp in phase 3a
  → Navigator.pushReplacement(PaymentResultPage.success(orderId))
```

### 결제 실패 / 취소 (사용자가 SDK 결제창 닫음)

```
SDK callback (fail / cancel)
  → CheckoutPage 가 다이얼로그로 사용자에게 표시
  → 카트 유지 (clear 안 함)
  → 사용자 "재시도" → 결제수단 재선택부터
  → 사용자 "닫기" → CartPage 로 pop
```

### Customer 직접 취소 (paid → cancelled)

```
OrderDetailPage (status='paid')
  → "취소" 버튼 → 확인 다이얼로그
  → cancelPaidOrderUseCase(orderId, reason='customer_request', approvedBy='customer')
  → paymentGatewayRepository.cancelPaidOrder(...)
  → tossPaymentRemoteDataSource.callCancelTossPayment(orderId, reason)
  → Cloud Functions cancelTossPayment:
      1. orders/{orderId} read, status='paid' 확인 (atomic guard)
      2. Toss POST /v1/payments/{paymentKey}/cancel (cancelReason)
      3. orders/{orderId} update (status='cancelled', cancelledAt, refundInfo with approvedBy)
  → OrderDetailPage 가 stream 으로 자동 갱신
```

### Owner 환불 동의 (accepted → refunded)

```
OwnerOrdersPage "환불 요청" 탭
  → ownerRefundRequestsProvider stream
  → 카드 "승인" 탭 → 확인 다이얼로그
  → processRefundUseCase(orderId, reason)
  → paymentGatewayRepository.processRefund(...)
  → tossPaymentRemoteDataSource.callProcessRefund(orderId, reason)
  → Cloud Functions processRefund:
      1. orders/{orderId} read, refundRequest 존재 확인
      2. Toss POST /v1/payments/{paymentKey}/cancel (cancelReason)
      3. orders/{orderId} update (status='refunded', refundedAt, refundInfo)
```

### Owner 거절 (paid → cancelled by store)

```
OwnerOrdersPage "신규" 탭 → 카드 "거절" 탭 → 사유 다이얼로그
→ cancelPaidOrderUseCase(orderId, reason='store_reject', approvedBy='store_reject')
→ 위와 동일 흐름, status='cancelled', refundInfo.approvedBy='store_reject'
```

### Owner 접수 (paid → accepted, customer cancel 불가)

```
OwnerOrdersPage "신규" 탭 → 카드 "주문 받기" 탭
→ acceptOrderUseCase(orderId)
→ orderRepository.setAcceptedByOwner(orderId)
→ orderRemoteDataSource.updateStatus(orderId, OrderStatus.accepted, acceptedAt=now)
→ OrderDetailPage (customer 시야) 의 "취소" 버튼 자동 hide, "환불 요청" 자동 노출 (status 분기)
```

---

## 에러 처리

| 케이스 | 처리 |
|---|---|
| Toss SDK 초기화 실패 (테스트 키 미주입, 네트워크 차단) | CheckoutPage 진입 시 다이얼로그 + CartPage 로 pop |
| 카드 결제창 사용자 미입력 시간 초과 | SDK fail callback `'PAY_PROCESS_CANCELED'` → 다이얼로그 |
| 카카오페이 외부 앱 호출 실패 (카카오톡 미설치) | SDK fail callback → 다이얼로그 + "카카오톡 설치" 안내 |
| 카드 결제 한도 초과 / 카드 거절 | SDK fail callback (Toss errorCode) → 다이얼로그 (사용자 친화 메시지로 매핑) |
| Cloud Functions verifyTossPayment 실패 (Toss confirm 응답 mismatch) | PaymentResultPage 'fail' 변형 + "결제 검증에 실패했어요. 결제는 자동 취소됩니다" + Toss 자동 cancel 시도 (Functions 내부) |
| Cloud Functions 네트워크 타임아웃 | PaymentResultPage 'fail' + "결제 결과 확인 중 오류가 발생했어요. 잠시 후 주문내역에서 확인해주세요" — 백그라운드 reconcile (별 phase) |
| 동일 orderId 로 중복 verifyTossPayment 호출 | Cloud Functions 가 `orders/{orderId}` 존재 시 idempotent return (이미 검증 완료 표시) |
| customer 가 status='paid' 인데 owner 가 이미 accepted 로 전환 직후 customer 가 cancel 버튼 탭 (race) | Cloud Functions cancelTossPayment 에서 atomic read 후 status!='paid' 면 throw → 다이얼로그 "이미 매장이 접수했어요. 환불 요청을 이용해주세요" |
| 환불 요청 후 점주가 거절 | OrderDetailPage 에 거절 사유 표시 + 재요청은 별 phase (본 phase 는 1회) |
| Toss cancel API 실패 (이미 환불 완료, network) | Functions throw → owner 화면 SnackBar "환불 처리에 실패했어요" — 수동 콘솔 처리 안내 (별 phase 자동화) |
| 카트 검증 (가격/품절 변경) | CheckoutPage 진입 시 storeMenuItemsProvider 와 비교 → 변경 발견 시 다이얼로그 "메뉴 정보가 변경되었어요. 카트를 다시 확인해주세요" → CartPage 로 pop |
| 비로그인 결제 시도 | CartPage "결제하기" 가드에서 차단 |
| 매장 영업 중지 | 결제 시작 사전 가드 (storeRepository.watchById 로 영업상태 확인) |
| FCM 푸시 (본 phase 비범위) | 알람은 in-app 다이얼로그만 |
| 점주 미로그인 / 점주 매장 없음 | OwnerOrdersPage 진입 시 가드 — 매장 등록 페이지로 안내 (기존 owner 흐름 그대로) |

---

## 보안 / 환경 설정

### `--dart-define` 환경 변수

```bash
flutter run \
  --dart-define=TOSS_CLIENT_KEY_TEST=test_ck_xxxxxxxxxxxxxxxx \
  --dart-define=TOSS_SUCCESS_URL=qradar://payment/success \
  --dart-define=TOSS_FAIL_URL=qradar://payment/fail
```

코드 측:
```dart
const tossClientKey = String.fromEnvironment('TOSS_CLIENT_KEY_TEST', defaultValue: '');
```

운영 키 (prod) 는 별 task 의 CI 환경 변수로 주입. **코드에 하드코딩 금지** (CLAUDE.md 절대 규칙 4).

### Cloud Functions 환경 변수

```bash
firebase functions:config:set toss.secret_test="test_sk_xxxxxxxxxxxxxxxx"
firebase functions:config:set toss.api_base="https://api.tosspayments.com"
```

Secret key 는 **반드시 Functions 환경 변수**. 클라이언트로 절대 노출 금지.

### iOS Info.plist 추가

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>kakaotalk</string>
  <string>kakaolink</string>
  <string>kakaopay</string>
</array>
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>qradar</string>  <!-- Toss redirect (deeplink) -->
    </array>
  </dict>
</array>
```

### Android `AndroidManifest.xml`

```xml
<queries>
  <package android:name="com.kakao.talk" />
  <package android:name="com.kakaopay.app" />
</queries>
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="qradar" />
</intent-filter>
```

### Firestore 보안 규칙 (별 task 의 입력)

본 phase 의 컬렉션 / 필드를 다음 규칙으로 작성할 것을 메모:
- `orders/{orderId}`:
  - read: `userId == request.auth.uid` (customer) **또는** `storeId in userOwnedStores(request.auth.uid)` (점주) **또는** admin role
  - write: **클라이언트 직접 write 금지**. Cloud Functions 만 write (서버 SDK).
  - 단, owner 가 `setAcceptedByOwner` / `setRefundRequest 거절` 등 일부 status 전이는 client write 허용 옵션도 있음 — 보안 규칙 task 에서 결정. 현재 spec 의 client UseCase 는 RepositoryImpl 을 통해 Firestore update 를 직접 하므로, **owner 측 일부 status 전이는 client write 가능 / customer 측 결제·환불은 Functions only** 의 하이브리드를 채택.
- `users/{uid}/orderLogs/{logId}` — Phase 2 의 규칙 그대로

---

## 의존성 (pubspec.yaml 추가)

### Flutter 패키지

```yaml
dependencies:
  # 토스페이먼츠 SDK — developer 가 다음 중 1개 선정 후 implementation.md 기록
  # 후보 1: tosspayments_widget_sdk_flutter (in-app webview 결제창)
  # 후보 2: tosspayments_payment_sdk (네이티브 SDK)
  tosspayments_widget_sdk_flutter: ^x.x.x  # developer 가 최신 버전 확인
  # Firebase Functions HTTPS Callable 호출
  cloud_functions: ^6.x.x  # firebase_core 6.x 와 호환되는 최신
  # URL launcher (영수증 webview / Toss redirect)
  url_launcher: ^6.x.x
  # webview (영수증 표시 — 기존 webview_flutter 재사용 가능)
```

### Cloud Functions (functions/package.json)

```json
{
  "dependencies": {
    "firebase-admin": "^12.x.x",
    "firebase-functions": "^5.x.x",
    "axios": "^1.x.x"
  }
}
```

---

## 결제 도메인 추가 고려사항

### 보안

1. **Toss secret key**: Cloud Functions 환경 변수에만. 클라이언트 절대 노출 금지.
2. **금액 위변조 차단**: Cloud Functions 가 Toss confirm 응답의 `totalAmount` 와 클라이언트가 보낸 `amount` 일치 검증. 불일치 시 즉시 throw + Toss 자동 cancel.
3. **idempotencyKey**: 사용자가 결제 버튼 중복 탭 / 네트워크 retry 등에서 같은 결제 키로 doc 충돌 방지. orderId = idempotencyKey = uuid v4.
4. **Firestore 보안 규칙**: orders write 는 Functions 만 (client write 차단). 별 task.

### Atomicity (트랜잭션)

- Cloud Functions verifyTossPayment 의 Firestore write 는 **batch 트랜잭션**:
  - `orders/{orderId}` set
  - `users/{uid}/orderLogs/{logId}` append
- 둘 중 하나라도 실패하면 전체 롤백 + Toss 자동 cancel.
- 단 Toss confirm 호출은 트랜잭션 외부 (외부 API). Functions 가 confirm 성공 후 Firestore batch 시작, 실패 시 즉시 Toss cancel 호출로 보정.

### Reconciliation (보정)

- 본 phase 비범위. 별 phase 후보: 매일 새벽 Cloud Functions 가 Toss 결제 내역과 Firestore `orders` 비교, 누락분 보정.
- 본 phase 의 fail safe: Cloud Functions verifyTossPayment 실패 시 즉시 Toss cancel.

### Race Conditions

- customer cancel vs owner accept race: Cloud Functions cancelTossPayment 가 트랜잭션 read 로 status='paid' 확인 후 진행. owner accept 가 먼저 commit 됐으면 throw.
- 동일 orderId 중복 결제 시도: idempotencyKey 로 차단 (Firestore doc 충돌).

### UX

- Toss 결제창 외부 앱 진입 (카카오페이) 시 앱 백그라운드 복귀 시점 처리: Toss SDK 가 callback 으로 처리. 본 phase 는 SDK 동작에 의존.
- 결제 진행 중 사용자 강제 종료 (앱 kill): 다음 진입 시 OrdersPage 에서 status 확인. Cloud Functions reconciliation 별 phase.

### 테스트

- Toss **테스트 환경 키** 사용. 테스트 카드번호는 Toss 공식 문서 참조.
- Firestore Emulator + Functions Emulator 로 e2e 테스트 가능 (Phase 3a 비범위 — 별 task).

---

## 작업 분배

### designer

작성 대상: `docs/tasks/order_flow_phase3a/design.md`

작업 필요. 다음 화면의 UI / 컴포넌트 / 상태 변형 정의:

1. **CheckoutPage** — 주문 요약 카드 + 결제수단 라디오 리스트 + 약관 동의 + 하단 고정 결제 버튼. 결제 진행 중 disabled 상태.
2. **PaymentResultPage** — 3가지 변형 (성공 / 실패 / 취소). 큰 아이콘 + 메시지 + 액션 버튼들.
3. **OrderDetailPage** — 상태 뱃지(OrderStatusBadge) + 라인 + 결제 정보 + 영수증 / 취소 / 환불 요청 버튼. status 별 버튼 조합 변형.
4. **OrdersPage (customer)** — 빈 상태 / 카드 리스트.
5. **OwnerOrdersPage** — 2탭 (신규 / 환불요청) + 빈 상태 각각 + 카드 (신규 / 환불요청 톤 분기).
6. **공통 위젯**: `OrderStatusBadge` (paid/cancelled/refunded 색상 분기), `PaymentMethodTile` (라디오), `ReceiptWebView` (Toss receiptUrl webview 외형 — appbar + 로딩).
7. **다이얼로그**:
   - 결제 실패 다이얼로그 (재시도 / 결제수단 변경 / 닫기)
   - 결제 취소 다이얼로그 (닫기)
   - customer 취소 확인 다이얼로그
   - 환불 요청 사유 입력 다이얼로그 (선택 사유 + free text)
   - 점주 거절 사유 입력 다이얼로그
   - 카트 검증 실패 다이얼로그 (메뉴 정보 변경 안내)
   - Phase 1b/1c 다이얼로그 톤 재사용 (배경 surfaceElevated, radius 16, 취소/주액션 색상 분기)
8. **상태 UI** — 각 페이지 loading / error / empty (특히 OrdersPage / OwnerOrdersPage shimmer + 에러 카드 + 빈 상태).

레퍼런스: `docs/agents/designer_guide.md`, Phase 1b 의 카트 충돌 다이얼로그 톤, Phase 1c 의 비로그인 다이얼로그 톤.

### developer

작성 대상: `docs/tasks/order_flow_phase3a/implementation.md`

핵심 작업 순서:

1. **pubspec 의존성 추가** + iOS Info.plist / AndroidManifest 권한·scheme 설정.
2. **`--dart-define` 키 정의** + `lib/core/constants/payment_env.dart` 신규 (키 읽기 헬퍼).
3. **Domain enum / Entity** 8종 신규.
4. **Repository Interface** 3종 (`order_repository`, `payment_gateway_repository`, `qoin_accrual_hook`).
5. **UseCase** 11종 신규.
6. **Data Model** 5종 (freezed + manual fromFirestore/toFirestore — 기존 패턴).
7. **DataSource** 2종 (`order_remote_data_source`, `toss_payment_remote_data_source`).
8. **RepositoryImpl** 3종 (`order_repository_impl`, `payment_gateway_repository_impl`, `noop_qoin_accrual_hook`).
9. **Cloud Functions** (`functions/` 디렉토리 신설):
   - `verifyTossPayment.ts`
   - `cancelTossPayment.ts`
   - `processRefund.ts`
   - `_toss_client.ts` (Toss Server API 래퍼)
   - `package.json` / `tsconfig.json` / `index.ts`
10. **Presentation Pages / Providers / Widgets**:
    - `CheckoutPage`, `PaymentResultPage`, `OrderDetailPage`, `OrdersPage`, `OwnerOrdersPage`
    - `payment_di.dart` (Provider 묶음)
    - `OrderStatusBadge`, `PaymentMethodTile`, `ReceiptWebView`
11. **기존 placeholder 제거 / wiring**:
    - `CartPage._CheckoutBar.onPressed` placeholder SnackBar 제거 → `CheckoutPage` push
    - `LogPage` placeholder → `OrdersPage` 본구현 (또는 LogPage 자체를 OrdersPage 로 대체)
    - `OwnerOrdersPlaceholder` → `OwnerOrdersPage` 본구현
12. **시드 / 테스트 결제** (Phase 1 의 DEV_ONLY 패턴): Toss 테스트 카드번호로 결제 검증. Cloud Functions 도 emulator 로 테스트 가능.
13. `flutter analyze` / `flutter test` / 수동 e2e 검증.

산출물: 코드 + `implementation.md` (Toss SDK 패키지 선정 사유, Cloud Functions 배포 가이드, 테스트 절차 포함)

### tester

작성 대상: `docs/tasks/order_flow_phase3a/test_report.md`

검증 항목:

- **결제 성공 흐름**:
  - 카드 결제 (테스트 카드번호) → `orders/{orderId}` doc 생성 → `users/{uid}/orderLogs/{logId}` 동시 생성 → 카트 자동 비움 → PaymentResultPage 성공 변형 → OrderDetailPage 진입
  - 카카오페이 결제 → 카카오톡 외부 호출 → 인증 → 앱 복귀 → 동일 흐름
- **결제 실패 흐름**:
  - 잘못된 카드 → SDK fail callback → 다이얼로그 → 카트 유지
  - 카카오톡 미설치 → 안내 다이얼로그
- **결제 취소 (사용자가 결제창 닫음)**: 다이얼로그 → CartPage pop, 카트 유지
- **customer 직접 취소 (paid → cancelled)**:
  - OrderDetailPage 취소 버튼 → 확인 → Toss cancel → status='cancelled', cancelledAt
  - status='accepted' 일 때 취소 버튼 hide
- **환불 요청 흐름**:
  - customer: status='accepted'/'making'/'ready' 일 때 "환불 요청" 버튼 → 사유 입력 → refundRequest 필드 set
  - owner: "환불 요청" 탭에서 카드 노출 → 승인 → Toss cancel → status='refunded'
  - owner 거절 → refundRequest.deniedAt / deniedReason set, status 그대로
- **점주 접수**:
  - "주문 받기" → paid → accepted, acceptedAt
  - customer OrderDetailPage 의 취소 버튼 자동 hide, "환불 요청" 자동 노출
- **점주 거절 (paid → cancelled by store)**:
  - 사유 입력 → Toss cancel → status='cancelled', refundInfo.approvedBy='store_reject'
- **OrdersPage**: 사용자의 모든 주문 노출, 시각/상태/매장명. 카드 탭 → OrderDetailPage.
- **카트 검증**: 결제 직전 메뉴 가격/품절 변경 시 다이얼로그 → CartPage pop.
- **idempotencyKey**: 결제 버튼 빠른 중복 탭 시 중복 doc 생성 안 됨.
- **race condition**: customer 가 cancel 누르는 동안 owner 가 accept → 어느 쪽이 먼저 commit 되는지 따라 한쪽이 명확한 메시지 받음.
- **레이어 규칙**:
  - `presentation/` 에서 `tosspayments_*`, `cloud_functions`, `cloud_firestore` 직접 import 없음
  - `domain/` 에서 외부 SDK / Firebase import 없음
  - 색상 하드코딩 0
  - `dart-define` 키가 코드에 하드코딩 안 됨 (grep `test_ck_` / `test_sk_` 0 결과)
- **placeholder 잔존 0**:
  - `CartPage._CheckoutBar` 의 "결제는 준비 중입니다 (Phase 3)" SnackBar 문구 제거
  - `LogPage` placeholder ("준비 중입니다") 제거
  - `OwnerOrdersPlaceholder` import / 사용 제거 또는 클래스 자체 제거
- **status enum 미사용 항목**: `accepted`/`making`/`ready`/`completed` 는 enum 선언만 있고 client UseCase 가 사용 안 함. owner 의 `setAcceptedByOwner` 만 accepted 전이.
- **Qoin hook**: `qoinAccrualHookProvider` 가 NoOp 으로 등록되어 있고 결제 성공 시 호출되는지 (Phase 4 가 hook 만 교체하면 동작).
- `flutter analyze` 0 issue.

---

## 완료 기준

- [ ] 사용자 확인 항목 1~12 모두 확정
- [ ] `design.md` 작성 완료
- [ ] `implementation.md` 작성 완료 — Toss SDK 선정 사유 / Functions 배포 가이드 / 테스트 카드번호 포함
- [ ] `test_report.md` 작성 완료
- [ ] FAIL 항목 0 또는 후속 phase 로 분리
- [ ] `flutter analyze` 0 issue
- [ ] 테스트 카드결제 / 카카오페이 결제 e2e 1회 이상 성공
- [ ] customer 직접 취소 (paid→cancelled) 1회 검증
- [ ] customer 환불 요청 → owner 동의 (accepted→refunded) 1회 검증
- [ ] owner 거절 (paid→cancelled by store) 1회 검증
- [ ] `OrderEntity` 와 `OrderLogEntity` 두 doc 이 동시 생성됨 확인 (Phase 2 추천 알고리즘 호환 유지)
- [ ] Qoin hook (NoOp) 이 결제 성공 시 호출됨 확인 (로그)
- [ ] CartPage / LogPage / OwnerOrdersPlaceholder 의 Phase 3 placeholder 코드 모두 제거
- [ ] Toss client key / secret key 가 코드에 하드코딩 안 됨 (grep 확인)
- [ ] Cloud Functions deploy 가이드가 implementation.md 에 명문화
- [ ] Firestore 보안 규칙 작성 task 의 입력으로 본 spec 의 컬렉션/필드/write 주체 메모

---

## 후속 phase 권고

| phase | 범위 |
|---|---|
| Phase 3b | 네이버페이 / 토스페이 / 삼성페이 / 애플페이 / 계좌이체 / 휴대폰결제 결제수단 추가. `PaymentMethod` enum 확장 + Toss SDK 옵션 추가. 도메인 변경 최소 |
| Phase 3c | 주문 상태 운영 흐름 (`accepted → making → ready → completed`). 점주 본격 접수 화면. customer 픽업 알림 |
| Phase 4 | Qoin 적립 / 사용 / 환불 시 회수. 본 phase 의 `QoinAccrualHook` 인터페이스를 real impl 로 교체 |
| 별 phase | FCM 푸시 인프라 (토큰 관리 / sending pipeline / 토픽 / 점주 → customer 알림 / 결제 실패 백그라운드 알림) |
| 별 phase | 부분 환불 / 자동 환불 (매장 미접수 시간 초과 자동 취소) |
| 별 phase | 매출 조회 (점주 / 관리자) — `orders` 컬렉션 활용 |
| 별 phase | Firestore 보안 규칙 작성 (본 phase 의 컬렉션 입력) |
| 별 phase | Reconciliation (Toss / Firestore 정합 일일 검증) |
| 별 phase | go_router 일괄 마이그레이션 (현재 `Navigator.push` 패턴) |
| 별 phase | 영수증 PDF / 이메일 발급 |
| 별 phase | 쿠폰 / 프로모션 코드 |
