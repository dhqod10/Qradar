# order_flow_phase3a 테스트 리포트

## 테스트 일시

- 2026-05-13

---

## 테스트 방법

- 정적 코드 검증 (grep, 파일 트리 확인)
- 문서 교차 검증 (spec.md / design.md / implementation.md 대조)
- `flutter analyze` — No issues found (재확인 완료)
- `flutter test` — 본 phase 단위 테스트 비범위, 생략
- Cloud Functions TypeScript 코드 정적 분석 (빌드 실행 안 함 — 서버 환경 불필요)

---

## 전체 결과

- PASS: 58개 (라이브 검증 +8, F1 / F6 fix 정정 +2, 2026-05-26; F2 / F4 / F5 / F7 / F8 fix 정정 +5, 2026-05-28; F3 / H7 해소 +1, 2026-05-29)
- FAIL: 0개
- 보류: 6개 (H7 해소로 감소)

> **정정 이력 (2026-05-26):** F1 (CartPage 비로그인 가드) 와 F6 (verifyTossPayment 멱등성) 는 본 회차에서 수정 완료. F1: `_CheckoutBar.onPressed` 가드를 `authProvider` 기반으로 교체. F6: 멱등성 가드를 Toss confirm 호출 이전 (step 3-pre) 으로 이동 + Cloud Function 재배포 완료. 상세는 `implementation.md` 섹션 16 참조.

> **정정 이력 (2026-05-28):** F2 / F4 / F5 / F7 / F8 수정 완료. F2: `_ActionBar` 에서 `OrderStatus.completed` 를 `cancelled / refunded` 케이스로 이동 (환불 요청 버튼 차단). F4: `lib/data/repositories/no_op_qoin_accrual_hook.dart` 생성, `qoinAccrualHookProvider` 등록, `checkout_page.dart` 결제 성공 경로에서 `onOrderPaid` 호출. F5: 취소 버튼 `OutlinedButton.styleFrom(side: BorderSide(color: AppColors.error), foregroundColor: AppColors.error)` + `height: 48 / radius: 10` 적용. F7: `orders_page.dart` `_buildShimmer()` 4-카드 shimmer 구현. F8: `order_detail_page.dart` `_OrderDetailShimmer` 전체 화면 shimmer 구현. F3 (ReceiptWebView) 은 `url_launcher` 외부 브라우저 유지 결정 — 보류 항목으로 전환. 상세는 `implementation.md` 섹션 17 참조.

> **정정 이력 (2026-05-29):** F3 / H7 (ReceiptWebView 앱 내 WebView) 구현 완료. `lib/presentation/customer/checkout/widgets/receipt_web_view.dart` 신규 생성 — `WebViewController` 기반 풀스크린 위젯 (진행률 LinearProgressIndicator, 에러 재시도 UI 포함). `order_detail_page.dart` 영수증 버튼 핸들러를 `url_launcher.launchUrl` → `Navigator.push(ReceiptWebView)` 로 교체, `url_launcher` import 제거. 상세는 `implementation.md` 섹션 18 참조.

---

## PASS 항목

### 기능 검증

- [x] 결정 1~12 (사용자 확인 항목) 모두 구현 일치
  - 근거: implementation.md 결정 테이블과 실제 코드(checkout_page.dart, verifyTossPayment.ts) 대조 완료
  - 위치: `lib/presentation/customer/checkout/checkout_page.dart`, `functions/src/verifyTossPayment.ts`

- [x] D1 — 점주 "주문 받기" 확인 다이얼로그 없음 (즉시 acceptOrder)
  - 근거: owner_orders_page.dart `_handleAccept()` 에 showDialog 없이 직접 useCase 호출
  - 위치: `lib/presentation/owner/orders/owner_orders_page.dart`

- [x] D2 — OrderStatusBadge 위치 `presentation/common/`
  - 근거: `lib/presentation/common/order_status_badge.dart` 존재 확인
  - 위치: `lib/presentation/common/order_status_badge.dart`

- [x] D3 — RefundRequestSheet showModalBottomSheet 패턴
  - 근거: `RefundRequestSheet.show()` 가 showModalBottomSheet 사용
  - 위치: `lib/presentation/customer/order/widgets/refund_request_sheet.dart`

- [x] CheckoutPage 기능 — 결제수단 라디오, 약관 동의, 하단 결제 버튼
  - 근거: checkout_page.dart 구조 확인. PaymentMethod.card / kakaoPay 분기, _tosAgreed / _privacyAgreed 상태 존재
  - 위치: `lib/presentation/customer/checkout/checkout_page.dart`

- [x] idempotencyKey uuid v4 생성 및 동일 키 사용
  - 근거: `const uuid = Uuid(); final idempotencyKey = uuid.v4();` checkout_page.dart line 54-55
  - 위치: `lib/presentation/customer/checkout/checkout_page.dart`

- [x] SDK success callback → Cloud Functions verifyTossPayment 호출 → CartPage clear
  - 근거: checkout_page.dart의 handlePay flow: launchResult.success → verifyAndCreateOrder → clearCartUseCase → pushReplacement PaymentResultPage.success
  - 위치: `lib/presentation/customer/checkout/checkout_page.dart` (lines 108-134)

- [x] SDK fail callback → PaymentResultPage(fail) 전환, 카트 유지
  - 근거: `!launchResult.success` 분기에서 clearCart 없이 PaymentResultPage.fail push
  - 위치: `lib/presentation/customer/checkout/checkout_page.dart`

- [x] SDK cancel callback → PaymentResultPage(cancelled) 전환, 카트 유지
  - 근거: `launchResult.cancelled` 분기에서 clearCart 없이 PaymentResultPage.cancelled push
  - 위치: `lib/presentation/customer/checkout/checkout_page.dart`

- [x] PaymentResultPage 3가지 변형 (success / fail / cancelled)
  - 근거: `enum PaymentResultVariant { success, fail, cancelled }` + switch 분기 구현
  - 위치: `lib/presentation/customer/checkout/payment_result_page.dart`

- [x] PaymentResultPage WillPopScope/PopScope 처리
  - 근거: `PopScope(canPop: false)` 래핑 확인
  - 위치: `lib/presentation/customer/checkout/payment_result_page.dart` line 55-56

- [x] PaymentResultPage 성공 — "주문 상세 보기" → OrderDetailPage push
  - 근거: _SuccessBody 의 버튼 onPressed 에서 OrderDetailPage push 확인
  - 위치: `lib/presentation/customer/checkout/payment_result_page.dart`

- [x] OrderDetailPage 주문 라인 리스트, 합계, 결제 정보 표시
  - 근거: order_detail_page.dart에 OrderItemRow, PriceSummary, 결제 정보 섹션 구현 확인
  - 위치: `lib/presentation/customer/order/orders/order_detail_page.dart`

- [x] OrderDetailPage "취소" 버튼 — status='paid' 일 때만 노출
  - 근거: status switch에서 OrderStatus.paid case 에만 취소 버튼 표시
  - 위치: `lib/presentation/customer/order/orders/order_detail_page.dart` line 444

- [x] OrderDetailPage "환불 요청" 버튼 — status=accepted/making/ready 일 때 노출
  - 근거: status switch에서 accepted/making/ready 케이스에 환불 요청 버튼 표시
  - 위치: `lib/presentation/customer/order/orders/order_detail_page.dart` line 476-508

- [x] OrdersPage — LogPage placeholder 교체, orders 컬렉션 기반
  - 근거: scaffold_with_nav.dart가 OrdersPage를 import하여 Log 탭에 삽입. myOrdersProvider가 orders 컬렉션 기반 stream
  - 위치: `lib/presentation/common/scaffold_with_nav.dart` line 73, `lib/presentation/customer/log/orders_page.dart`

- [x] OrdersPage AppBar title "Log" (Qradar 고유 용어)
  - 근거: orders_page.dart AppBar title: 'Log'
  - 위치: `lib/presentation/customer/log/orders_page.dart` line 21

- [x] OrdersPage 카드 탭 → OrderDetailPage push
  - 근거: OrderCard onTap에서 OrderDetailPage push 확인
  - 위치: `lib/presentation/customer/log/orders_page.dart`

- [x] OrdersPage empty 상태 — "아직 주문이 없어요" + "둘러보기" 버튼
  - 근거: _EmptyBody 위젯 구현 확인
  - 위치: `lib/presentation/customer/log/orders_page.dart`

- [x] OwnerOrdersPage — OwnerOrdersPlaceholder 대체
  - 근거: owner_scaffold.dart가 OwnerOrdersPage import
  - 위치: `lib/presentation/owner/owner_scaffold.dart` line 37

- [x] OwnerOrdersPage 2탭 구조 — "신규" / "환불 요청"
  - 근거: TabController(length: 2), tabs: ['신규', '환불 요청'] 확인
  - 위치: `lib/presentation/owner/orders/owner_orders_page.dart` lines 350-353

- [x] 점주 "주문 받기" → paid→accepted 전환
  - 근거: AcceptOrderUseCase 호출 확인
  - 위치: `lib/presentation/owner/orders/owner_orders_page.dart`

- [x] 점주 "거절" → cancelTossPayment Cloud Functions 호출
  - 근거: _handleReject에서 CancelPaidOrderUseCase 호출
  - 위치: `lib/presentation/owner/orders/owner_orders_page.dart`

- [x] 환불 승인 확인 다이얼로그 (D6) → processRefund 호출
  - 근거: _showRefundApproveDialog → ProcessRefundUseCase 호출
  - 위치: `lib/presentation/owner/orders/owner_orders_page.dart`

- [x] 환불 거절 사유 다이얼로그 (D7) → DenyRefundRequestUseCase 호출
  - 근거: _showRefundDenyDialog 구현 확인
  - 위치: `lib/presentation/owner/orders/owner_orders_page.dart`

### UI 검증

- [x] AppColors만 사용 — 하드코딩 Color 없음
  - 근거: `grep -rn "Color(0x" lib/presentation/customer/checkout/ lib/presentation/customer/order/ lib/presentation/owner/orders/ lib/presentation/common/` → 출력 없음
  - 위치: 검증 대상 파일 전체

- [x] OrderStatusBadge 7가지 상태 색상 모두 정의
  - 근거: paid/accepted/making/ready/completed/cancelled/refunded 모두 AppColors 토큰으로 정의
  - 위치: `lib/presentation/common/order_status_badge.dart`

- [x] OrderStatusBadge small/large 크기 변형
  - 근거: OrderStatusBadgeSize enum과 switch 분기 확인
  - 위치: `lib/presentation/common/order_status_badge.dart`

- [x] CheckoutPage 결제 진행 중 UI — 버튼 spinner + AppBar LinearProgressIndicator
  - 근거: `_processing` 상태에서 PreferredSize(LinearProgressIndicator) + CircularProgressIndicator on button + IgnorePointer 래핑
  - 위치: `lib/presentation/customer/checkout/checkout_page.dart` lines 164-303

- [x] OwnerOrdersPage shimmer 로딩 구현
  - 근거: `_buildShimmer()` 메서드 존재 확인 (lines 460, 565)
  - 위치: `lib/presentation/owner/orders/owner_orders_page.dart`

- [x] OrdersPage error 상태 — "다시 시도" 버튼
  - 근거: _ErrorBody 위젯 구현 확인
  - 위치: `lib/presentation/customer/log/orders_page.dart`

- [x] OwnerOrdersPage empty 상태 — "신규 주문이 없어요" / "환불 요청이 없어요"
  - 근거: 각 탭의 empty 텍스트 확인
  - 위치: `lib/presentation/owner/orders/owner_orders_page.dart` line 503

### 아키텍처 검증

- [x] presentation / domain 레이어에 Firebase / Toss SDK 직접 import 없음
  - 근거: `grep -rn "import 'package:cloud_firestore"`, `import 'package:firebase_"`, `import 'package:cloud_functions"`, `import 'package:tosspayments"` → lib/presentation, lib/domain 에서 결과 없음 (기존 auth_provider.dart의 firebase_auth는 Phase 1c 기존 코드, 본 phase 신규 파일 아님)
  - 위치: 전체 검증 완료

- [x] Repository Interface — domain, Repository Implementation — data 분리
  - 근거: order_repository.dart (domain), order_repository_impl.dart (data) 각각 위치 확인
  - 위치: `lib/domain/repositories/`, `lib/data/repositories/`

- [x] Cloud Functions Toss SDK 직접 사용은 data layer DataSource에서만
  - 근거: toss_payment_remote_data_source.dart가 `tosspayments_widget_sdk_flutter` import. presentation/domain 에서 미사용
  - 위치: `lib/data/datasources/remote/toss_payment_remote_data_source.dart`

- [x] Cloud Functions region 일관성 (asia-northeast3)
  - 근거: verifyTossPayment.ts, cancelTossPayment.ts, processRefund.ts 모두 `region: "asia-northeast3"`, Flutter client `FirebaseFunctions.instanceFor(region: 'asia-northeast3')` 일치
  - 위치: `functions/src/*.ts`, `lib/data/datasources/remote/cloud_functions_remote_data_source.dart`

- [x] store.ownerId 필드명 일치 (StoreEntity ↔ Cloud Functions)
  - 근거: StoreEntity에 `@Default('') String ownerId`, cancelTossPayment.ts `storeData["ownerId"]`, processRefund.ts `storeData["ownerId"]` 모두 일치
  - 위치: `lib/domain/entities/store_entity.dart`, `functions/src/cancelTossPayment.ts`, `functions/src/processRefund.ts`

- [x] TOSS_SECRET_KEY 환경변수 사용 (하드코딩 금지)
  - 근거: `defineSecret("TOSS_SECRET_KEY")` + `secrets: [tossSecretKey]` 선언 확인. 코드 내 literal key 없음
  - 위치: `functions/src/verifyTossPayment.ts`, `cancelTossPayment.ts`, `processRefund.ts`

- [x] TOSS_CLIENT_KEY dart-define 주입 패턴
  - 근거: `String.fromEnvironment('TOSS_CLIENT_KEY', defaultValue: 'test_ck_placeholder')` 사용 확인
  - 위치: `lib/data/datasources/remote/toss_payment_remote_data_source.dart` lines 63-65

- [x] HttpsError 코드 분류 — unauthenticated / permission-denied / invalid-argument / failed-precondition / not-found
  - 근거: 세 함수 모두 사용 확인. `already-exists`는 미구현 (별도 FAIL 항목 F6)
  - 위치: `functions/src/verifyTossPayment.ts`, `cancelTossPayment.ts`, `processRefund.ts`

### 코드 품질 검증

- [x] flutter analyze — No issues found
  - 근거: `flutter analyze --no-pub` 실행 결과
  - 위치: 전체 lib/

- [x] async 후 mounted 체크
  - 근거: checkout_page.dart의 _handlePay에서 await 이후 `if (!mounted) return;` 다수 확인
  - 위치: `lib/presentation/customer/checkout/checkout_page.dart` lines 77, 118, 122, 133, 144, 154

- [x] Provider DI 13개 wiring
  - 근거: order_di_providers.dart에 DataSource 3개 + Repository 2개 + UseCase 10개 = 총 15개 provider 정의 (spec 요구 13개 포함 + 일부 추가)
  - 위치: `lib/presentation/customer/order/orders/providers/order_di_providers.dart`

- [x] freezed generated files 존재 (build_runner 통과)
  - 근거: order_entity.freezed.dart, order_item_entity.freezed.dart, payment_info_entity.freezed.dart 존재 확인. implementation.md에 "dart run build_runner build 통과 (27 freezed outputs)" 기록
  - 위치: `lib/domain/entities/`

- [x] Cloud Functions 10개 파일 존재 (spec 기준 충족)
  - 근거: `functions/src/` 에 index.ts, verifyTossPayment.ts, cancelTossPayment.ts, processRefund.ts, tossClient.ts + package.json, tsconfig.json, .env.example, README.md, .gitignore 확인
  - 위치: `functions/`

- [x] Firestore batch write (orders + orderLogs) atomic 처리
  - 근거: `const batch = db.batch(); batch.set(orderDoc, orderData); batch.set(logDoc, logData); await batch.commit();`
  - 위치: `functions/src/verifyTossPayment.ts` lines 202-205

- [x] iOS Info.plist LSApplicationQueriesSchemes + CFBundleURLSchemes(qradar)
  - 근거: kakaopay, kakaolink, kakaotalk, supertoss, tossapp 존재 확인. CFBundleURLSchemes에 "qradar" 존재
  - 위치: `ios/Runner/Info.plist`

- [x] Android Manifest queries(com.kakao.talk) + intent-filter scheme=qradar
  - 근거: `<package android:name="com.kakao.talk" />`, `<data android:scheme="qradar" />` 존재 확인
  - 위치: `android/app/src/main/AndroidManifest.xml`

- [x] Cart placeholder SnackBar 제거 후 CheckoutPage push 연결
  - 근거: cart_page.dart `_CheckoutBar.onPressed`에서 `Navigator.push(MaterialPageRoute(builder: (_) => const CheckoutPage()))`
  - 위치: `lib/presentation/customer/cart/cart_page.dart` line 292-295

- [x] OrdersPage (LogPage 대체) — scaffold_with_nav.dart Log 탭에 OrdersPage 삽입
  - 근거: scaffold_with_nav.dart line 73 `OrdersPage()` 확인. log_page.dart는 파일만 남고 미사용
  - 위치: `lib/presentation/common/scaffold_with_nav.dart` line 73

- [x] Phase 2 OrderLog 스키마 보존 — verifyTossPayment batch에서 유지
  - 근거: logData 객체에 logId, orderId, storeId, storeName, items, totalPrice, status, paymentMethod, paymentChannel, createdAt, updatedAt 포함
  - 위치: `functions/src/verifyTossPayment.ts` lines 187-200

---

## FAIL 항목

_(F1 항목 없음 — 2026-05-26 fix 완료. `_CheckoutBar.onPressed` 에 `authProvider.asData?.value` 기반 가드 추가. null 시 SnackBar + LoginPage redirect. `currentUserProfileProvider` (Firestore 스트림) 대신 `authProvider` (Firebase Auth 직접) 사용으로 세션 만료 즉시 반영 보장. 상세는 `implementation.md` 섹션 16 참조.)_

---

_(F2 항목 없음 — 2026-05-28 fix 완료. `_ActionBar.build` 의 `case OrderStatus.completed:` 를 `cancelled / refunded` 케이스 그룹으로 이동. completed 상태에서 환불 요청 버튼 미노출, 완료 안내 컨테이너만 표시. 상세는 `implementation.md` 섹션 17 참조.)_

---

_(F3 항목 PASS — 2026-05-29 구현 완료. `lib/presentation/customer/checkout/widgets/receipt_web_view.dart` 신규 생성. `WebViewController` 기반 풀스크린 위젯 — 진행률 LinearProgressIndicator / 에러 재시도 UI 포함. `order_detail_page.dart` 영수증 버튼을 `Navigator.push(ReceiptWebView)` 로 교체, `url_launcher` import 제거. spec(line 27, 268) ReceiptWebView 명세 충족. 상세는 `implementation.md` 섹션 18 참조.)_

---

_(F4 항목 없음 — 2026-05-28 fix 완료. `lib/data/repositories/no_op_qoin_accrual_hook.dart` 생성 (`class NoOpQoinAccrualHook implements QoinAccrualHook`, `const NoOpQoinAccrualHook()`, `onOrderPaid` / `onOrderRefunded` NoOp 구현). `order_di_providers.dart` 에 `qoinAccrualHookProvider` 등록. `checkout_page.dart` clearCart 이후 `ref.read(qoinAccrualHookProvider).onOrderPaid(order)` 호출 추가. 상세는 `implementation.md` 섹션 17 참조.)_

---

_(F5 항목 없음 — 2026-05-28 fix 완료. 취소 버튼을 `OutlinedButton.styleFrom(side: BorderSide(color: AppColors.error), foregroundColor: AppColors.error)` + `height: 48` + `borderRadius: 10` 으로 수정. design.md(line 129) 스펙과 일치. 상세는 `implementation.md` 섹션 17 참조.)_

---

_(F6 항목 없음 — 2026-05-26 fix 완료. 멱등성 가드를 Toss confirm 호출 이전 (step 3-pre) 으로 이동. terminal status 존재 시 기존 결과 반환 (Toss API 미호출), 비정상 상태 시 internal 에러. Cloud Function 재배포 완료. 상세는 `implementation.md` 섹션 16 참조.)_

---

_(F7 항목 없음 — 2026-05-28 fix 완료. `orders_page.dart` `_buildShimmer()` 메서드 구현. `ListView.builder(itemCount: 4)` 로 shimmer 카드 4개 (storeName row + menuSummary row + price/date row) 표시. AppColors.surface + AppColors.border 만 사용. 상세는 `implementation.md` 섹션 17 참조.)_

---

_(F8 항목 없음 — 2026-05-28 fix 완료. `order_detail_page.dart` `_OrderDetailShimmer` 위젯 구현. 상태 뱃지 영역 + 매장명 row + 아이템 행 3개 + 가격 요약 블록 + 결제 정보 블록 shimmer 표시. AppColors.border 박스만 사용. 상세는 `implementation.md` 섹션 17 참조.)_

---

## 보류 항목

### H1 — domain 레이어 BuildContext 의존 (아키텍처 검토 필요)

- 이유: `payment_gateway_repository.dart`와 `launch_payment_use_case.dart`가 `package:flutter/widgets.dart`의 `BuildContext`를 import. domain 레이어의 framework independence 원칙 위반 소지
- 필요한 확인: Toss SDK가 BuildContext를 필수로 요구하는지 여부. SDK 내부에서만 사용되면 navigatorKey 패턴(GlobalKey<NavigatorState>)으로 대안 가능
- 후속 작업 제안: Phase 3b에서 SDK 의존 제거 또는 `navigatorKey.currentContext` 패턴으로 domain 레이어에서 Flutter 의존 제거. implementation.md에 인식된 tradeoff로 이미 기록됨
- 현재 판단: 구현에서 인지된 상태. 동작에는 문제 없으나 아키텍처 경계 측면에서 향후 개선 권장

### H2 — firebase.json runtime 필드 없음 (배포 환경 확인 필요)

- 이유: implementation.md(8절)에서 `"runtime": "nodejs20"` 기재. 실제 firebase.json의 functions 섹션에 runtime 필드 없음. functions/package.json의 engines.node = "22". Firebase 배포 시 runtime 버전 결정 방식 명확화 필요
- 필요한 확인: Firebase Functions v2는 package.json engines.node를 우선 사용하는지 firebase.json runtime 필드가 필요한지 확인
- 후속 작업 제안: functions 배포 전 firebase.json에 `"runtime": "nodejs22"` 추가 또는 engines.node와 일관성 확보

### H3 — common/refund_request_dialog.dart 미사용 파일

- 이유: design.md 파일 경로 매핑(line 740)에 `lib/presentation/common/refund_request_dialog.dart`로 명시되어 있으나, 실제 코드에서는 `lib/presentation/customer/order/widgets/refund_request_sheet.dart`가 사용됨. common 파일은 어디서도 import되지 않는 dead code
- 필요한 확인: 향후 다른 화면(owner 측)에서 동일 시트를 재사용할 계획인지 여부
- 후속 작업 제안: 미사용 파일 삭제 또는 design.md 경로 매핑 업데이트

### H4 — OrdersPage AppBar title fontSize 불일치 (P3)

- 이유: design.md(line 159)에서 `fontSize: 20` 명시. 코드는 `fontSize: 18`. 기능 영향 없음
- 필요한 확인: 사용자/디자이너 승인 필요
- 후속 작업 제안: 의도적 변경이면 design.md 업데이트, 아니면 18→20으로 수정

### H5 — 실기기 딥링크 복귀 검증 (실기기 필요)

- 이유: iOS/Android 딥링크(qradar scheme) 복귀 동작, 카카오페이 외부 앱 전환/복귀는 시뮬레이터에서 검증 불가
- 필요한 확인: 실기기 빌드 후 T02(카카오페이) 시나리오 테스트
- 후속 작업 제안: Phase 3b 진입 전 실기기 테스트 수행

### H6 — Toss SDK callback 처리 (실 결제 환경 필요)

- 이유: `TossPaymentRemoteDataSource.launch()`의 실제 SDK 동작(success/fail/cancel callback 수신 타이밍, 앱 복귀 흐름)은 테스트 키 없이 검증 불가
- 필요한 확인: TOSS_CLIENT_KEY dart-define 등록 후 테스트 환경 결제 시도
- 후속 작업 제안: implementation.md 13번 섹션 "사전 점검" 항목 수행 후 T01~T04 시나리오 검증

### H7 — ReceiptWebView 앱 내 WebView ~~미구현~~ → **해소 (2026-05-29)**

- ~~이유: spec(line 27, 268)에서 `ReceiptWebView` 공통 컴포넌트 신규 생성 요구. 2026-05-28 기준 `url_launcher.launchUrl(LaunchMode.externalApplication)` 방식 유지 — Toss 영수증 URL 이 외부 도메인이므로 현행 외부 브라우저 UX도 허용 가능. webview_flutter 의존 추가 여부는 사용자·디자이너 UX 결정 후 별도 task 분리 예정~~
- **해소 내용 (2026-05-29):** `lib/presentation/customer/checkout/widgets/receipt_web_view.dart` 구현 완료. `WebViewController` 기반 풀스크린 위젯 — 진행률 표시 / 에러 재시도 포함. `order_detail_page.dart` 연결 완료, `url_launcher` 의존 제거. F3 → PASS 전환.
- 현재 판단: **PASS**

---

## 설계자 전달 메시지

### 요약

- 전체 판단: **FAIL 0 — Phase 3a 종결 완료**
- 58개 PASS / 0개 FAIL / 6개 보류
- Clean Architecture 레이어 경계는 대체로 준수됨 (domain BuildContext 예외는 인지된 tradeoff)
- 결제 핵심 파이프라인(verifyTossPayment batch, cancel, refund 흐름) 구현 완료
- flutter analyze No issues 확인 (2026-05-28 재확인)

### 재작업 우선순위

_(잔여 FAIL 없음. 모든 FAIL 항목 수정 완료.)_

### 후속 task 후보

- **Firestore 색인 생성** (implementation.md 13-5 항목): 내 주문 목록 / 점주 주문 리스트 복합 색인 — 실 서비스 전 필수
- **Firestore 보안 규칙 작성**: orders collection client write 차단 (spec 비범위 명시)
- **Cloud Functions 배포 및 TOSS 키 등록** (implementation.md 13-1~3): 실 결제 환경 진입 전
- **실기기 딥링크 검증** (H5): T02 카카오페이 시나리오
- **domain BuildContext 제거** (H1): Phase 3b에서 navigatorKey 패턴으로 개선 권장
- ~~**ReceiptWebView 앱 내 WebView 구현** (H7): UX 방향 결정 후 별도 task~~ → **2026-05-29 해소**

---

## 사용자 후속 작업 항목 (implementation.md §13 참조)

| # | 항목 | 현재 상태 | 우선순위 |
|---|---|---|---|
| 1 | TOSS_SECRET_KEY Firebase secrets 등록 | 미완료 — 실 결제 불가 | 배포 전 필수 |
| 2 | Cloud Functions 배포 (`firebase deploy --only functions`) | 미완료 | 배포 전 필수 |
| 3 | TOSS_CLIENT_KEY dart-define 등록 (IDE/CI) | 미완료 — 테스트 결제 불가 | 테스트 전 필수 |
| 4 | iOS/Android 실기기 빌드 테스트 (딥링크 검증) | 미완료 | Phase 3b 진입 전 |
| 5 | Firestore 복합 색인 생성 | 미완료 — 쿼리 실패 가능 | 배포 전 필수 |
| 6 | functions/ npm install + tsc build 확인 | 미완료 | 배포 전 필수 |
| 7 | store 문서 ownerId 필드명 Firestore 확인 | 확인 필요 | 배포 전 필수 |

---

## 완료 판단

- [x] 핵심 결제·환불 흐름 라이브 검증 PASS (T5 회귀 8건 모두 통과)
- [x] **F1 (P0) / F6 (P1) 재작업 완료** (2026-05-26)
- [x] **F2 / F4 / F5 / F7 / F8 수정 완료** (2026-05-28)
- [x] **F3 보류 전환 — H7로 편입** (2026-05-28)
- [x] **F3 / H7 (ReceiptWebView) 구현 완료 — 보류 해소** (2026-05-29)
- [x] **잔여 FAIL 0 — Phase 3a 최종 종결**

---

## 라이브 검증 (2026-05-13 이후)

### 검증 일시

- 2026-05-25 ~ 2026-05-26

### 검증 방법

- 운영 Firestore 환경 (정식 Rules 배포 후) 라이브 흐름 수동 테스트
- Cloud Functions (verifyTossPayment / cancelTossPayment / processRefund) 실제 호출
- flutter analyze — No issues found (재확인 완료)

---

### T5 회귀 — 결제/환불 흐름 (신규 Rules + drift fix 후)

| 항목 | 결과 |
|---|---|
| 고객: paid 주문 취소 (`cancelTossPayment` CF 호출) → status=cancelled, cancelInfo 필드 정상 노출 | PASS |
| 고객: accepted 주문 환불 요청 → `refundRequest` 필드 정상 노출 (orders 문서 update, O2 룰 통과) | PASS |
| 점주: 환불 요청 거절 → `refundRequest.deniedAt` dot-path update → O3 룰 통과 | PASS |
| 점주: 환불 승인 → `processRefund` CF 호출 → status=refunded, refundInfo 필드 정상 노출 | PASS |
| 점주: paid 주문 accept → `acceptedAt` 필드 정상, O1 룰 통과 | PASS |
| owner orders 로딩 — `storeId / status` 복합 쿼리 Firestore 인덱스 영구화 후 정상 | PASS |
| cancelInfo 표시 — OrderDetailPage cancelled 상태에서 정상 노출 | PASS |
| refundRequest 표시 — OrderDetailPage refundRequest!=null 상태에서 정상 노출 | PASS |

**추가 PASS: 8건**

---

### 라이브 검증 전체 결과 (누적)

- 정적 검증 (2026-05-13): PASS 42 / FAIL 8 / 보류 6
- 라이브 검증 추가 (2026-05-26): PASS +8
- F1 / F6 재작업 완료 (2026-05-26): PASS +2 / FAIL −2
- F2 / F4 / F5 / F7 / F8 수정 완료 (2026-05-28): PASS +5 / FAIL −5
- F3 보류 전환 (2026-05-28): FAIL −1 / 보류 +1
- F3 / H7 해소 (2026-05-29): PASS +1 / 보류 −1
- **누적: PASS 58 / FAIL 0 / 보류 6**

---

## Phase 3a 종결 선언 (2026-05-26, 갱신 2026-05-29)

**범위:** Toss Payments 결제 흐름 + 취소 + 환불 요청·거절·완료 + Owner 주문 접수 + 신규 Rules 환경 정합성

**최종 결과:**
- PASS 58 / FAIL 0 / 보류 6
- P0 결제·환불 핵심 흐름 라이브 검증 PASS
- 본 phase 산출물 4종 (spec / design / implementation / test_report) 작성 완료
- 부수 산출물: Cloud Functions (verifyTossPayment / cancelTossPayment / processRefund) 배포 / Firestore 정식 Rules 배포 / Firestore Composite Index 영구화
- 후속 수정 (2026-05-28): F2 / F4 / F5 / F7 / F8 수정 완료, F3 → H7 보류 전환, flutter analyze No issues 재확인
- 후속 수정 (2026-05-29): F3 / H7 (ReceiptWebView 앱 내 WebView) 구현 완료 — spec 원래 명세 충족, 보류 6개로 감소, flutter analyze No issues 재확인

**Phase 3a 종결.** 다음 phase 후보는 별도 architect 호출로 결정.
