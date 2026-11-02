# Qoin 사용(spend) 구현 기록

- 작성: developer
- 작성일: 2026-11-02
- 입력: `spec.md` (§0 D-1~D-7 확정), `design.md` (§0 DD-1~DD-5 확정)
- 상태: **구현 완료 · 미배포** (배포는 사용자가 한다). `spendEnabled` 부재 = 꺼짐(fail-closed)이라 배포해도 기능은 꺼진 채 안착한다.

---

## 0. spec 에서 의도적으로 달라진 점 (먼저 읽을 것)

| # | spec | 구현 | 이유 |
|---|---|---|---|
| X-1 | §5.4: 차감은 **confirm 후** 트랜잭션 (사전 검증 + 사후 재검증 2단) | **차감은 Toss confirm 전** 트랜잭션 1회 (`qoinSpendLedger.reserveSpend`). confirm 실패 · 응답 검증 실패 · 주문 쓰기 실패 → 반전 원장으로 롤백 | 사용자 지시. "confirm 후 잔액 부족" 케이스(design DD-6)가 **원천적으로 없다** — 동시 결제 2건이면 두 번째가 confirm 전에 `QOIN_INSUFFICIENT_BALANCE` 로 거절된다 |
| X-2 | §5.1: 음수 `qoinToUse` 는 "0 으로 간주" / §10: "입력검증 거절" (spec 내부 모순) | **미전송·null = 0, 전송됐는데 안전 정수 ≥ 0 이 아니면 `invalid-argument`** | 정상 클라이언트는 음수를 보내지 않는다. 음수/소수/문자열은 금액을 깎으려는 입력이므로 조용히 0 으로 바꾸지 않고 거절 (confirm 전) |
| X-3 | §6.1: 복원 전이 3종 열거 | **`→ cancelled` · `→ refunded` 전부** (출발 status 무관, admin 전권 전이 포함). 멱등이라 과잉 발화해도 안전 | 열거에서 빠진 전이가 돈을 새게 하는 것보다 `spend_{orderId}` 부재 시 no-op 인 편이 안전 |
| X-4 | §6.1: 전역 `enabled=false` → 복원도 멈춤 | spec 대로 멈추되, 멈춘 건을 **`qoinSettlementIssues` 에 `spend_restore_skipped_disabled` 로 기록** | 사용분 복원은 clawback 과 달리 고객에게 불리한 방향(복원 누락 = 고객 돈 증발)이라 로그에만 두지 않는다 (audit_trail §4-6) |
| X-5 | §7.1: `maxSpendPerOrder`/`maxSpendRatio` (D-1 대안) | **구현 안 함** (D-1 = 권고안: 상한 없음). `EXCEEDS_CAP` 사유도 두지 않음 | YAGNI. 필요해지면 `qoinSpend.ts` 의 판정 순서 7번 자리에 추가 |
| X-6 | §8.3: 롤백 설계 없음 | 롤백은 **삭제가 아니라 반전 원장** `spendRefund_{orderId}` (`rollbackReason` 박제). 롤백 자체가 실패하면 `qoinSettlementIssues` 에 `spend_rollback_failed` | 원장 append-only · 불변식 `balance == Σ amount` 유지. 주문 키(idempotencyKey)는 결제 시도마다 새 UUID 라 같은 orderId 가 재사용되지 않아 `spendRefund_{orderId}` 와 충돌하지 않는다 |

---

## 1. 구현 완료 항목

### 1.1 Cloud Functions (`functions/src`)

| 파일 | 변경 |
|---|---|
| `qoinSpend.ts` (신규, 순수) | `resolveSpendPolicy`(fail-closed: 전역 `enabled`·`spendEnabled`·`minCashFloor`(1~100000)·`minSpendUnit`(1~10000, 부재=1)) · `validateQoinSpend`(spec §5.2 판정 순서) · `maxSpendable` · `parseQoinToUse` · `SPEND_REJECT_TOKEN` |
| `qoinSpendLedger.ts` (신규) | `reserveSpend`(선존재 가드 → 잔액 read → 판정 → `spend_{orderId}` 원장 + `qoinBalance` 절대값, **한 트랜잭션**) · `rollbackSpend`(반전 원장, 멱등) · `spendRefundFields`(spend 원장 상속) · `recordSpendIssue` |
| `priceGate.ts` | `evaluatePriceAuthority` 에 선택 인자 `discount`(D). **D=0/생략이면 현행 판정과 동일** (c2 는 D=0 분기에서 현행 식 `totalPrice === subtotal` 그대로 — 타입 강제 변환 차이까지 보존). D>0: `c2' = isInt(subtotal) && totalPrice === subtotal − D`, `c4' = amount === serverSubtotal − D`, `pricing.expected = serverSubtotal − D`. 거절 기록 `detail.discount` 는 D>0 일 때만 |
| `orderBuilder.ts` | `applyServerPricing(cart, pricing, discount = 0)` (D>0 일 때만 `discount` 주입) · `buildOrderLogData` 의 선택 인자 `discount`(명시로 넘길 때만 키 생성 — 클라 `cart.discount` 는 로그에 새기지 않음) · `CONSUMED_INPUT_KEYS`(최상위 입력 키 골든) |
| `paymentGate.ts` | `GateReason` 에 `QOIN_SPEND_DISABLED` · `QOIN_INSUFFICIENT_BALANCE` · `QOIN_BELOW_CASH_FLOOR` · `QOIN_BELOW_MIN_UNIT` · `QOIN_NOT_UNIT_MULTIPLE` (모두 `failed-precondition`, 토큰은 메뉴 id 를 싣지 않음) |
| `verifyTossPayment.ts` | `qoinToUse` 파싱 → (Q>0 만) 정책 read → 꺼져 있으면 즉시 거절 → **가격 모드 강제 enforce** + `discount: Q` 로 금액 게이트 → `data.amount === serverFinal` 재확인 → `reserveSpend`(confirm 전) → confirm → 응답 검증 → 주문+로그 batch(`discount`/`totalPrice` 서버값) → 커밋 후 예약 확정. 실패는 바깥 `catch` 가 `undoQoinReservation`(Toss 승인 후였으면 cancel 시도 + 반전 원장 롤백). **Q=0 이면 위 전부가 없다** (정책 read 0, 트랜잭션 0, 인자 모양 동일) |
| `onOrderQoinSettled.ts` | `* → cancelled|refunded` 에서 `restoreSpend`(spend 원장 반전 → `spendRefund_{orderId}`, 멱등). `completed → refunded` 는 `clawbackEarn`(기존 코드를 함수로만 분리) + `restoreSpend`. 복원은 `config.enabled` 만 본다 (`spendEnabled=false` 는 복원을 막지 않음, D-7) |
| `setQoinSpendPolicy.ts` (신규) + `index.ts` | admin callable. 보낸 필드만 변경, 값 쓰기와 필드별 이력을 **같은 트랜잭션**에. `config/qoin` 없으면 거부, `minCashFloor` 없이 `spendEnabled:true` 거부, 같은 값은 noop |
| `onQoinConfigWritten.ts` | 감시 필드에 `spendEnabled`/`minSpendUnit`/`minCashFloor` 추가 (Console 직접 편집 → `source:'direct'` 이력, callable 이력과 중복 기록 안 함) |

### 1.2 Firestore Rules (`firestore.rules`)

- `qoinSpendPolicyFields()` 1곳(`spendEnabled` · `minSpendUnit` · `minCashFloor`)을 `config/{docId}` 의 **create 와 update 양쪽**에서 admin 포함 차단 (`accrualRate` 와 같은 CF 전담, audit_trail §4-7). `enabled` 직접 쓰기 경로와 F3 강제는 그대로.
- `qoinTransactions` / `qoinSettlementIssues` / `paymentGateRejections` 는 이미 `if false`(CF 전담) — 신규 타입·사유도 추가 규칙 불필요 (하네스로 확인).

### 1.3 Dart

| 레이어 | 파일 | 변경 |
|---|---|---|
| core | `core/utils/qoin_spend_calculator.dart` (신규) | `QoinSpendPolicy.fromConfig`(서버 `resolveSpendPolicy` 사본) · `QoinSpendCalculator.maxSpendable/clamp/isAllowed/limitedBy/finalAmount` — **표시용**, 골든 `qoin_spend_contract.json` 이 서버와 고정 |
| domain | `QoinTransactionType` | `spend` · `spendRefund` 추가 (`fromCode` 미지값 → null 유지) |
| domain | `QoinConfigEntity` (+ freezed 재생성) | `spendPolicy`(기본 `disabled`, fail-closed) |
| domain | `PaymentFailureReason` | `qoinInsufficientBalance` · `qoinSpendDisabled` · `qoinBelowCashFloor` · `qoinInvalidAmount`(그 외 모든 `QOIN_*`). 알려진 3종 밖의 `QOIN_*` 도 갈래 B 로 처리 |
| domain | `PaymentGatewayRepository.verifyAndCreateOrder` · `VerifyAndCreateOrderUseCase` | `int qoinToUse = 0` 추가 |
| data | `QoinConfigModel.fromMap` | `spendPolicy` 파싱 |
| data | `PaymentGatewayRepositoryImpl` | `cartToMap(cart, {qoinToUse})`: Q>0 이면 `discount=Q`, `totalPrice=subtotal−Q` (표시·기록용). **Q=0 이면 이전과 바이트 동일**. `qoinToUse` 는 cart 밖 최상위 입력 |
| data | `CloudFunctionsRemoteDataSource` | `verifyPayload`(정적, 테스트용) 로 최상위 입력 조립 + `qoinToUse` |
| presentation | `checkout/providers/qoin_spend_providers.dart` (신규) | `qoinToUseProvider`(autoDispose, 체크아웃 이탈 시 폐기) · `qoinSpendViewProvider`(잔액+정책+카트 소계 → 섹션 phase / 사용가능액 / **적용액**) |
| presentation | `checkout/widgets/qoin_spend_section.dart` (신규) | design §1~§3, §5: 숨김(S4/S5) · skeleton · 비활성 S1~S3 · 활성(입력 · 최대 사용/사용 취소 토글 · 클램프 + 3초 경고 · 결제 예정 금액 · 적립 안내). 스트림 갱신으로 한도가 줄면 경고와 함께 클램프 |
| presentation | `checkout_page.dart` | `QoinSpendSection` 배치, `qoinToUse = 적용액`(섹션 숨김/비활성이면 0), 결제 금액·CTA·`PriceSummary` 가 같은 값을 봄 |
| presentation | `customer/order/widgets/price_summary.dart` | `discountLabel`(기본 `할인`, 하위호환). 체크아웃·고객 주문상세는 `Qoin 사용` |
| presentation | `qoin_transaction_tile.dart` | spend/spendRefund 아이콘·사유 문구, **`qoinSpokenText` 의 `… 후 잔액` 접두사를 타입별(적립/회수/사용/복원)로 수정** (spend 가 "회수 후" 로 읽히던 버그) |
| presentation | `payment_failure_copy.dart` | 4종 문구 + 공통 보조 문구 `kQoinUnchangedLine` |

### 1.4 골든 계약 (양쪽 모두 갱신)

- `test_fixtures/qoin_cart_contract.json`: `inputKeys` / `requiredInputKeys` 추가(최상위 입력, `qoinToUse` 포함) + `_doc` 에 `cart.discount` 가 non-null 일 수 있음 명시. cart `keys` 는 그대로(`discount` 이미 포함).
  - TS: `CONSUMED_INPUT_KEYS` ↔ `functions/test/qoinRate.test.mjs` / Dart: `CloudFunctionsRemoteDataSource.verifyPayload` ↔ `test/data/qoin_f1_contract_test.dart`
- `test_fixtures/qoin_spend_contract.json` (신규): 정책 해석 16 · 사용가능액 12 · 판정 14 · 요청 파싱 8 케이스. TS `functions/test/qoinSpend.test.mjs` ↔ Dart `test/core/qoin_spend_calculator_test.dart`

### 1.5 문서

`docs/processes/data_ownership.md`(config 정책 필드 · 원장 4타입 · issues 사유 · CF 표), `entity_lifecycle.md`(취소/환불 → 복원 후속 액션), `operations.md §6.7`(Qoin 사용 운영).

---

## 2. 회귀 0 (Q=0) 확인 근거

| 항목 | 근거 |
|---|---|
| 서버 경로 | `qoinToUse` 미전송/null/0 → `qoinToUse > 0` 분기 전부 건너뜀. 정책·잔액 read 0, 트랜잭션 0, `priceMode` 해석 동일, `evaluatePriceAuthority` 인자 모양 동일(키 자체를 안 넘김), 주문 문서 `discount: null`/`totalPrice`=소계, 로그에 `discount` 키 없음, batch 경로 그대로. 테스트: `qoinSpend.test.mjs` "회귀 Q=0" (가격 모드 4종 × 트랜잭션 0 / config 미접근 / discount null / confirm 금액) |
| `priceGate` | D 생략 ≡ D=0 ≡ 현행 (`deepEqual`, pricing 키 집합 `expected/lines/subtotal` 불변, 거절 detail 에 `discount` 키 없음). 기존 `priceAuthority.test.mjs` PPA 전부 무수정 통과 |
| 가격 모드 | Q=0 에서 `off` 는 여전히 클라 금액을 믿는다 (현행) — 테스트로 고정. 강제 enforce 는 Q>0 에만 |
| 앱 화면 | 섹션 숨김/Q=0 이면 `PriceSummary` 에 Qoin 행 없음, CTA = 소계, Toss 금액 = 소계, `qoinToUse` = 0. `qoin_spend_checkout_test.dart` "숨김 = 이전 화면과 동일" 3건 + 기존 `payment_price_checkout_page_test.dart` 무수정 통과 |
| 구버전 앱 | `qoinToUse` 키 없음 = 0. 서버 테스트 "qoinToUse 미전송" |
| 신 앱 + 구 서버 | 신 앱은 `qoinToUse: 0` 키를 항상 싣는다 — 구 서버는 모르는 키를 무시. (Q>0 은 `spendEnabled` 가 켜져야 UI 가 나오므로 **functions 를 먼저 배포**하면 구 서버에 Q>0 이 가는 경로가 없다) |

---

## 3. 테스트 결과

| 항목 | 결과 |
|---|---|
| `flutter analyze` | **No issues found** |
| `flutter test` | **1001 passed / 0 failed** (신규: `qoin_spend_calculator_test` 58, `qoin_spend_checkout_test` 14, 계약/모델/실패문구/타일 보강) |
| `functions` `npm test` (tsc + 9 파일) | **465 pass / 0 fail** (신규 `qoinSpend.test.mjs` 96건 포함; 기존 테스트 무수정 통과(계약 테스트 1건만 추가) — PPA/게이트/자기거래/적립률 전부) |
| `test_rules` (`npm test`) | **479/479 PASS** (신규 QS-R1~R7 20건) |
| `functions` `npm run test:emulator` | **113/116 PASS** — 신규 SP1~SP17(+SP5 4전이 변형) 전부 PASS, 실패 3건은 **본 변경과 무관한 기존 실패**(§6) |

---

## 4. 테스트 포인트 (tester 전달)

1. **회귀 0**: Q=0/미전송의 결제 흐름·주문 문서·화면이 현행과 동일 (가격 모드 off/shadow/enforce 각각). 특히 `PAYMENT_PRICE_MODE=off` 에서 Q=0 은 클라 금액을 그대로 믿고 Q>0 만 강제 enforce 되는 비대칭.
2. **서버 권위**: 소계 뻥튀기(서버 4000, 클라 40000, Q=39700) · `amount` 에 Q 미반영 · `cart.totalPrice` 불일치 · 음수/소수/문자열 `qoinToUse` → 모두 confirm 전 거절, 잔액·원장·주문 불변.
3. **경계**: `Q = 소계−minCashFloor` 통과 / `+1` 거절(`QOIN_BELOW_CASH_FLOOR`) · 전액(Q=소계) 거절 · `Q = 잔액` 통과(잔액 0) / `잔액+1` 거절 · 음수 잔액 · `minSpendUnit=100` 의 250 거절.
4. **정책 fail-closed**: `spendEnabled` 부재/false/비-bool · 전역 `enabled=false` · `minCashFloor` 부재/0/소수/상한 초과 · `config/qoin` 문서 없음 → `QOIN_SPEND_DISABLED`.
5. **롤백**: confirm throw · 응답 status≠DONE(Toss cancel 포함) · 주문 batch 실패(Toss cancel + 롤백) → 잔액 원복 + `spendRefund_{orderId}`(`rollbackReason`), 원장 합 0. 롤백 자체 실패 → `qoinSettlementIssues.spend_rollback_failed`.
6. **멱등·동시성**: 같은 키 재호출(주문 있음 → 기존 결과, 이중 차감 0) · `spend_` 만 남은 예약 + 같은 키(→ `aborted`, 롤백 안 함) · 동시 2건(잔액 초과) → 정확히 1건 성공 · 두 번째는 **confirm 호출 0**.
7. **복원 커버리지**: `paid→cancelled` · `accepted/making/ready→refunded` · `completed→refunded`(clawback+spendRefund 동시, 잔액이 주문 전으로 원복) · 재전달 멱등 · Qoin 미사용 주문은 no-op · `spendEnabled=false` 여도 복원 통과 · 전역 `enabled=false` 면 복원 멈춤 + issues 기록.
8. **적립 정합(D-4)**: Q 사용 주문의 earn 기준 = 현금 결제액(`orders.totalPrice`).
9. **정책 callable/이력**: 비로그인/비관리자 거절 · 인자 검증 · 최소현금 없이 켜기 거절 · 필드별 이력(`before/after/beforeState/changedBy/reason`) · noop 은 이력 없음 · Console 편집은 `source:'direct'` · 트리거가 callable 이력과 중복 기록하지 않음.
10. **Rules**: 사용 정책 3필드 create·update·delete 차단(admin 포함) + `enabled` 직접 쓰기 회귀 + 고객 `config/qoin` read 가능.
11. **골든**: `qoin_cart_contract.json`(`inputKeys`) · `qoin_spend_contract.json` — 한쪽만 바꾸면 Dart/TS 중 하나가 깨지는지.
12. **UI**: design §2~§5 상태 전부(숨김 · skeleton · S1~S3 · 활성 · 클램프 경고 3초 · 최대 사용 토글 · 스트림 갱신 클램프) + 스크린리더(`qoinSpokenText` 타입별 접두사, 입력/버튼 Semantics) + 서버 거절 4종 문구(갈래 B, 금액 숫자·서버 문자열 없음) + 문의 코드 캡션(`QOIN_*` 가 `^[A-Z][A-Z0-9_]{2,39}$` 통과).
13. **실기기**(자동화 불가): 숫자 키보드 · 키보드가 섹션을 가리지 않는지(`ensureVisible`) · 실제 Toss 최소 승인금액 대 `minCashFloor` 300원.

---

## 5. 미구현 / 보류

| # | 항목 | 사유·메모 |
|---|---|---|
| H-1 | **점주 정산(N4)** | 범위 밖(디자이너 지시). `orders.discount` 활성화로 **점주 주문 상세(`common/price_summary.dart`)에 `할인` 행이 새로 나타난다**(라벨 미변경). 점주 매출(`owner_sales`)은 `totalPrice`(현금)를 집계하므로 Qoin 사용분만큼 점주 집계가 줄어든다 — **정산 정책(누가 Qoin 비용을 부담하나) 확정 전에는 점주 표시/집계를 바꾸지 않았다.** 원장에 `storeId`/`brandId`/`orderSubtotal`/`orderTotalPrice` 를 박제해 후속 집계는 가능 |
| H-2 | **admin 화면(정책 편집 + 이력 표시)** | CF `setQoinSpendPolicy` 와 이력 기록까지만. admin 앱 UI 는 없다 → 당장은 Console 편집(Rules 우회, `onQoinConfigWritten` 이 `direct` 이력 기록) 또는 callable 직접 호출로 운영. 이력 `field` 신규 3종은 앱 모델(`QoinRateField.fromCode`)이 모르는 값으로 걸러 **admin 이력 화면에는 아직 나타나지 않는다**(Firestore 에는 남음) |
| H-3 | 고아 예약 청소 | 차감 트랜잭션 커밋 직후 서버가 죽으면(타임아웃·인스턴스 종료) `spend_*` 원장만 남고 주문·롤백이 없다 — 고객 Qoin 이 묶인다. 자동 스위퍼 없음. 점검 쿼리: `spend_*` 중 `orders/{orderId}` 부재 + `spendRefund_{orderId}` 부재. 사용 시작 후 빈도를 보고 스케줄 CF 여부 결정 |
| H-4 | 롤백 결과 불명(트랜잭션 커밋 응답 유실) | `reserveSpend` 가 "커밋됐는지 모르는" 오류로 끝나면 예약이 남았지만 롤백 대상으로 추적되지 않는다(H-3 와 동일 증상·동일 점검). 확률 극히 낮음 |
| H-5 | confirm 이후 취소 실패 | 주문 쓰기 실패 → Toss cancel 도 실패하면 Qoin 만 롤백되고 결제 승인은 남는다. 이는 기존에도 있던 위험(주문 쓰기 실패 시 cancel 시도 자체가 없었다)을 Q>0 에서만 개선한 것이다. Q=0 은 현행 유지 |
| H-6 | 천 단위 콤마 입력 표시 | design §2.1 이 구현자 재량으로 허용 — 입력 중/후 모두 콤마 없이 표시. 예정 금액·잔액·한도는 콤마 표기 |
| H-7 | `QoinPolicyPlate` 사용 정책 한 줄 | design §8.2 가 "제안만 — 필수 아님" 으로 명시. 미구현 |
| H-8 | 부분 환불 비례 복원(N1) · 0원 무결제 경로(N2) · 매장/브랜드별 사용 정책(N3) · 선물/이전(N5) · 소멸(N6) · 자동 정합 감사 CF(N7) | spec §3 비범위 그대로 |
| H-9 | 기존에 실패하던 에뮬레이터 케이스 | 아래 §6 (본 변경과 무관, 베이스라인 동일) |

---

## 6. 에뮬레이터 스위트 메모

`npm run test:emulator` (tsc + firestore/functions 에뮬레이터, 실결제 0). 신규 `SP` 섹션(실제 Firestore 트랜잭션): 차감 · **실제 경합 동시 예약 2건 → 정확히 1건 성공** · 재예약 충돌 · 롤백 멱등 · 복원 5전이(`paid→cancelled`, `accepted/making/ready→refunded`, `completed→refunded` 동시 clawback+spendRefund) · 이벤트 재전달 멱등 · 미사용 주문 no-op · `spendEnabled=false` 복원 통과 · 전역 `enabled=false` 복원 중단+issues · `verifyTossPayment` E2E(차감→취소→복원, 소계 뻥튀기 거절) · `setQoinSpendPolicy`(권한/검증/켜기 안전장치/이력/noop/문서 부재) · Console 편집 이력.

**기존 실패 3건 — 변경 전(HEAD) 코드로 같은 스위트를 돌려도 동일하게 실패한다 (베이스라인 93/96, 같은 3건)**:
- `CH16 earn(브랜드 소속)` : read 5 기대, 6 실측 (earn 경로는 이번에 건드리지 않았다)
- `Q1 일괄 덮어쓰기 후에도 적립 사용 안 함 매장…` : "켜진 매장은 새 브랜드 값"
- `CF7 auditBrandLinks` : 쓰기 0 지문 비교 (트리거 비동기 쓰기와의 타이밍 경합으로 보인다)

**CH16 clawback**: `completed → refunded` 는 사용 복원 확인이 붙어 문서 read 가 4 → **5** 가 된다. 왕복은 늘리지 않도록 config · earn · spend 를 한 번의 `getAll` 로 읽는다 (왕복 ≤ 4 유지). 기대값을 5 로 갱신했다. Qoin 을 쓰지 않은 `paid→cancelled`/`accepted+→refunded` 는 spend 원장 1 read 로 끝난다(이전엔 read 0).

---

## 7. 배포 순서 (사용자 수행 — 배포는 하지 않았다)

시크릿 신규 없음 (`TOSS_SECRET_KEY`/`SIGNAL_HASH_SALT` 기존). `PAYMENT_GATE_MODE`/`PAYMENT_PRICE_MODE` 값 변경 불필요.

1. **사전 확인**: 토스 콘솔에서 이 머천트 계약의 결제수단별 **최소 승인금액** 확인 → `minCashFloor`(초기 300) 확정 (spec D-3).
2. **Rules 배포**: `firebase deploy --only firestore:rules` (사용 정책 3필드 CF 전담 차단). 이 단계에서 `config/qoin` 에는 아직 정책 필드가 없으므로 동작 변화 없음.
3. **Functions 배포**: `firebase deploy --only functions` (`verifyTossPayment` · `onOrderQoinSettled` · `onQoinConfigWritten` · 신규 `setQoinSpendPolicy` — 최초 배포 시 callable 신규 생성). **앱보다 먼저.** 이 시점부터 서버는 `qoinToUse` 를 이해하지만 `spendEnabled` 부재라 Q>0 은 `QOIN_SPEND_DISABLED` 로 거절된다. Q=0 결제는 현행과 동일.
4. **정책값 세팅** (`spendEnabled` 는 아직 켜지 않는다 — 부재 또는 `false`): callable `setQoinSpendPolicy({ minCashFloor: 300, reason: '토스 최소금액 확인' })` (필요 시 `minSpendUnit`). callable 이 값과 이력을 같은 트랜잭션에 쓴다. (Console 직접 입력도 가능하지만 functions 배포 후여야 `onQoinConfigWritten` 이 이력을 남긴다.)
5. **앱 빌드 배포**: 신 앱은 `config/qoin.spendEnabled` 가 켜지기 전까지 Qoin 섹션을 그리지 않는다(DD-1). 구버전 앱은 영향 없음(`qoinToUse` 미전송 = 0).
6. **관측**: 배포 후 하루 정도 `paymentGateRejections` 에 `QOIN_*` 가 없는지, 일반 결제 거절률이 변하지 않았는지 확인 (Q=0 회귀 0 검증).
7. **`spendEnabled` 를 켜는 시점**: 위 1~6 이 끝나고 `minCashFloor` 가 토스 최소금액 이상으로 확인된 뒤, `setQoinSpendPolicy({ spendEnabled: true, reason })`. (`minCashFloor` 없이 켜기는 서버가 거부한다.) 켠 직후 **고객 계정으로**(자기거래 가드 때문에 본인 매장 불가) 확인:
   - Q>0 결제 1건: 주문 `discount`/`totalPrice`, `spend_{orderId}` 원장, 잔액, 토스 승인 금액이 `소계 − Q` 인지
   - 그 주문 취소(`paid → cancelled`) 후 `spendRefund_{orderId}` 와 잔액 원복
   - 이상 시 즉시 `spendEnabled:false` (신규 사용만 차단, 복원은 계속 동작)
8. `PAYMENT_PRICE_MODE` 상태와 무관하게 Q>0 은 서버가 강제 enforce 한다. 다만 가격 모드가 `off` 인 환경에서는 **Q>0 주문에 한해** 메뉴·옵션 그룹 읽기가 추가로 일어난다(비용 소폭 증가).

---

## 8. 알려진 한계 / 운영 메모

- **전액 Qoin 결제 불가**: 최소 현금 `minCashFloor` 를 항상 남긴다 (spec D-3, N2).
- **음수 잔액은 의도된 동작**: 이번 주문 적립분을 다른 주문에 쓴 뒤 이 주문이 환불되어 clawback 되면 잔액이 음수가 될 수 있다. clamp 하지 않는다 (감사 수단). 음수 잔액 고객에게는 Qoin 섹션이 "쓸 수 없어요" 로 표시된다.
- **전역 `enabled=false` 는 사용·복원을 모두 멈춘다** — 그 사이 환불된 사용분은 `qoinSettlementIssues(spend_restore_skipped_disabled)` 로 남으므로 **재개 후 수동 복구**가 필요하다 (소급 복원 도구는 없음).
- 입력 필드는 `LengthLimitingTextInputFormatter(9)` 로 9자리까지만 받는다 (정수 오버플로 방지 — 서버는 안전 정수만 허용).
