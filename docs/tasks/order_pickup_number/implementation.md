# order_pickup_number — 구현 기록

기준: `spec.md`, `design.md`. 배포(firebase deploy) 하지 않음.

## 구현 항목

### 서버 (functions/src)
- `pickupCounter.ts` (신규): `kstDateKey(Date)` (UTC+9 변환, `yyyyMMdd`), `nextPickupNumber(current)` (순수), `allocatePickupNumber(tx, counterRef, updatedAt)` (트랜잭션 안에서 read -> +1 -> set).
- `orderBuilder.ts`: `buildOrderData(..., pickupNumber?)`, `buildOrderLogData({..., pickupNumber?})` — 값이 있을 때만 키 생성.
- `verifyTossPayment.ts`: 최종 `db.batch()` -> `db.runTransaction`. Toss confirm / Qoin 예약 / Layer2 신호 위치는 기존 그대로.
  - 트랜잭션 순서: (1) `orders/{id}` 재-존재 확인 (있으면 `{duplicate}` 반환, 재발급·덮어쓰기 없음, 기존 status 반환) (2) 카운터 read+증가 (3) orders / orderLogs / counter set. 읽기는 모두 쓰기 전.
  - 날짜 기준: Toss `approvedAt` (주문 `createdAt` 과 동일 순간) 의 KST 날짜. 서버 UTC 시계와 무관.
  - 커밋 전 실패 시 abort -> 카운터 불변. 기존 catch 의 Qoin 롤백 경로 유지 (`reservation = null` 은 커밋 성공/동시 중복 감지 후).
- 카운터 문서: `stores/{storeId}/pickupCounters/{yyyyMMdd}` `{current, updatedAt}`.

### Rules / 문서
- `firestore.rules`: `stores/{storeId}/pickupCounters/{dateKey}` `allow read, write: if false` (admin 포함). orders 는 변경 없음 (create `if false`, update O1~O7 화이트리스트에 pickupNumber 없음 — 하네스로 고정).
- `docs/processes/data_ownership.md` §2.2 / §2.4 / 신규 §2.5a / §3 CF 표, `audit_trail.md`, `entity_lifecycle.md` 갱신.

### Dart
- `OrderEntity.pickupNumber`, `OrderLogEntity.pickupNumber` (`int?`), `OrderModel` / `OrderLogModel` 읽기 매핑 (`toFirestore` 에는 쓰지 않음). freezed 재생성.
- 신규 공통 위젯 `lib/presentation/common/widgets/pickup_number_display.dart` (`PickupNumberDisplay`, variant hero/badge/inline, `muted`, `caption`, `badgeSize`, `inlineSuffix`). null 이면 `SizedBox.shrink` (inline 은 suffix 만).
- 표시:
  - `customer/checkout/payment_result_page.dart`: `_SuccessBody` ConsumerWidget 화, 기존 `currentOrderProvider(orderId)` 재사용. 로딩 스켈레톤(108, surface), 에러/null 생략. 체크 80->64, 상단 60->40, 문구 "매장에서 이 번호를 보여주세요", "주문번호" -> "주문 ID" 12px textMuted.
  - `customer/order/orders/order_detail_page.dart` `_StatusSection`: 최상단 hero (cancelled/refunded 는 muted), "주문 ID".
  - `owner/orders/widgets/owner_new_order_tile`, `owner_in_progress_order_tile`, `owner_refund_request_tile`: 좌측 52x52 badge (+12 간격, null 이면 둘 다 생략).
  - `owner/orders/owner_order_detail_page.dart` `_StatusSection`: 좌측 64x64 badge, "주문 ID".
  - `customer/order/widgets/order_card.dart`: `#3 · 3분 전` inline (OrderCard 는 OrderEntity 사용 — OrderLogEntity 는 필드만 추가, 화면 소비처 없음).

## 테스트
- `functions/test/pickupNumber.test.mjs` (신규, `npm test` 등록): KST 경계(UTC 15:00, 연말/월말), nextPickupNumber, 순증·로그 동일 번호, 매장 독립, 자정 리셋, **12건 동시 경합(낙관적 동시성 fake, 재시도 발생 확인) 중복 없음**, 멱등(3-pre 및 트랜잭션 내부 재확인), 오펀 방지(커밋 실패 시 카운터 불변), 기존 카운터 이어 발급.
- 기존 fake db 4개 파일(`selfDealing`/`paymentGate`/`priceAuthority`/`qoinSpend`)의 `batch()` -> `runTransaction` 대응 수정 (qoinSpend memDb 는 orders 읽는 트랜잭션을 `txCount` 에서 제외).
- `test_rules/rules.test.mjs` PK-1~13: pickupNumber 클라 create/update 거부, 정상 전이 회귀, pickupCounters read/write/delete 전면 거부(admin 포함).
- `test/presentation/common/pickup_number_display_test.dart`: null 생략, hero, 4자리 오버플로 없음, inline.

## 결과
- `functions: npm test` 557 pass / 0 fail (tsc 포함).
- rules 하네스 508/508 PASS (에뮬레이터).
- `flutter analyze` 0 issues, `flutter test` 전체 통과.

## 테스터 포인트
- 에뮬레이터(`npm run test:emulator`)는 이번 변경 후 미실행 — 실 트랜잭션 경합/emulator.test.mjs 가 batch 가정을 하는지 확인 필요.
- 결제 실제 흐름에서 결제완료 화면 hero 노출 지연(스트림 로딩 스켈레톤), 과거 주문 UI 무변화, 취소/환불 상세 muted.
- 자정 직전/직후 결제의 번호 리셋.

## 참고 / 보류
- 기존 동작 유지: Qoin 미사용 결제에서 confirm 후 커밋 실패 시 Toss 자동 취소는 이전에도 없었음 (undoQoinReservation 은 Qoin 예약이 있을 때만). 이번 범위 밖.
- `OrderLogModel` 은 `total`/`paidAt` 을 읽는데 서버는 `totalPrice`/`createdAt` 으로 쓴다 (기존 drift, 소비처 없음). 이번 범위 밖으로 건드리지 않음.
- 과거 주문 backfill 없음 (spec).
