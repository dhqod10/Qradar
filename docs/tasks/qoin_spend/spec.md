# Qoin 사용(spend) 기능 명세

- 작성: architect
- 작성일: 2026-11-01
- 상태: **설계 완료, 사용자 결정 대기 (§0)**
- 작업 유형: 신규 기능 (결제 경로 확장 + Qoin 원장에 `spend` / `spendRefund` 타입 추가)
- 선행 사실: `docs/tasks/qoin/spec.md`(Qoin 1차 — 적립/회수/잔액/원장) + `qoin_accrual_rate_hierarchy`(적립률 계층) **이미 prod 배포됨**. 이 task 는 그 위에 "사용(차감)" 을 올린다. 1차 spec 은 §4.2 / §5.4 에서 **이 확장을 전제로** 트랜잭션 기반 잔액 모델을 선택해 두었다 — 그 결정을 재사용한다.

---

## 0. 사용자 확인이 필요한 결정사항 (먼저 읽을 것)

> ✅ **전부 확정 (2026-11-01, 사용자 승인).** D-1~D-7 **모두 권고안대로** 확정. 아래 표는 근거 기록용으로 보존한다. 확정 세부는 표 아래 "확정 요약" 참조. 구현은 이 확정값으로 진행한다.

아래는 결정 근거(권고안/대안) 기록이다.

| # | 결정 | 권고안 | 대안 | 비고 |
|---|---|---|---|---|
| **D-1** | **최대 사용 한도** | **결제 소계(subtotal)에서 `minCashFloor`(D-3) 를 뺀 금액까지.** 비율 상한 없음 (고객 혜택 최대, 로직 단순). | (a) 결제액의 **X%** 까지 (예 50%) — Qoin 부채 소각 속도를 사업이 통제하고 싶을 때. (b) 1회 사용 절대 상한 (예 5,000 Qoin). | 값은 `config/qoin` 에 둬서 재배포 없이 조절. 상한식은 서버가 판정(§5). |
| **D-2** | **최소 사용 단위** | **1 Qoin (1원 단위).** 1 Qoin = 1원이라 반올림 이슈 없음, UX 단순. | **100 Qoin 단위** — 금액이 깔끔하고 "자잘한 잔액" 소진 유도. 이 경우 `Q % 100 == 0` 을 서버가 강제. | — |
| **D-3** | **전액 Qoin 결제 시 PG 처리 (최소 현금)** | **최소 현금 `minCashFloor` 를 남긴다 (전액-Qoin 불가).** 값은 **토스 실결제 최소금액 확인 후 확정**(추정 100원). `Q ≤ subtotal − minCashFloor`. 단일 결제 경로 유지. | **전액-Qoin(0원 결제) 허용** → Toss confirm 을 건너뛰는 **별도 무결제 경로**가 필요(주문 doc 을 PG 없이 CF 가 생성). 범위·위험 큼 → v1 비권장. | ⚠️ **토스페이먼츠 최소 승인금액을 반드시 확인**해야 한다(계약/문서). 서버 코드로는 검증 불가 — 운영 확인 필요. 토스가 0원/소액을 거부하면 D-3(a) 가 강제된다. |
| **D-4** | **적립 ↔ 사용 상호작용 (적립 기준액)** | **실제 현금 결제액(= subtotal − Q) 기준 적립.** 현재 `onOrderQoinSettled` 가 `order.totalPrice` 로 적립하므로, `totalPrice` 를 "현금 결제액" 으로 두면 **코드 변경 없이** 실결제액 적립이 된다. | **소계(subtotal) 기준 적립** — "Qoin 으로 깎아도 적립은 원래 금액대로". 고객 유인은 크나 Qoin 부채가 빨리 늘고 정산 부담 증가. 이 경우 `onOrderQoinSettled` earn 이 `subtotal` 을 읽도록 수정 필요. | 권고안이 보수적(발행자 부담 최소)이고 기존 코드와 정합. |
| **D-5** | **환불/취소 시 사용 Qoin 복원 범위** | **사용분 전액 복원 + (적립됐던 주문이면) 적립분 전액 회수.** `processRefund` 가 **항상 전액 환불**이므로 비례 계산 불필요. | — (부분환불은 현재 코드에 없음) | 부분환불 도입 시 **비례 복원**이 필요 → 명시적 비범위(§비범위). |
| **D-6** | **사용 정책값 운영 수단 (admin UI vs Console)** | **`setQoinSpendPolicy` CF(admin) 신규 + 설정 변경 이력** — `setQoinAccrualRate` 패턴 복제. admin 화면은 기존 Qoin admin 허브에 1페이지 추가. | **v1 Console 직접 편집** + `onQoinConfigWritten` 트리거가 이력 기록(트리거 확장 필요). admin UI 는 후속. | 돈·정책 값이라 **이력은 기본값**(audit_trail §4-1). Console-only 로 가면 트리거 이력 확장이 조건. |
| **D-7** | **사용 kill switch 범위** | **`config/qoin.spendEnabled`(전역 사용 중단) 1개.** `false` → 신규 사용 차단, **복원(spendRefund)은 통과**(막으면 환불된 고객 돈이 증발). 기존 `enabled`(전역 비상정지)는 적립·회수·사용 **전부** 멈추는 상위 스위치로 유지. | 매장/브랜드별 사용 on/off 까지 계층화 — v1 과대, 적립률 계층 재사용 가능하나 범위 큼. 후속. | 적립 스위치(`qoinAccrualEnabled`)와 **다른 필드**다. 혼동 금지. |

### 확정 요약 (2026-11-01)
- **D-1** = 권고. 한도 = `subtotal − minCashFloor` 전액. 비율/절대 상한 없음.
- **D-2** = 권고. 최소 사용 단위 **1 Qoin**.
- **D-3** = 권고. 전액-Qoin 불가, 최소현금 `minCashFloor` 남김. **`minCashFloor` 는 결제수단별로 나누지 않고 "단일 값" 하나**(수단별 최소금액 차이가 1~300원뿐이고, Qoin 사용액 입력 시점에 토스 수단이 미확정이라 분리 시 UX 변경 필요 → 과설계). **기본값 300원**(토스 수단별 최소금액 중 최대치 기준: 카드100·계좌이체200·휴대폰300·가상계좌1·간편결제100 — 2026-11-01 토스/PortOne 문서 기준). 머천트 계약별 상이 가능 → 운영 시 토스 콘솔값으로 조정. 수단별 분리는 필요 시 v2.
- **D-4** = 권고. 실제 현금 결제액(`subtotal − Q`) 기준 적립(기존 코드와 정합, 변경 0).
- **D-5** = 권고. 사용분 전액 복원 + 적립분 전액 회수. 부분환불은 비범위.
- **D-6** = 권고. `setQoinSpendPolicy` CF(admin) + 변경 이력. **`minCashFloor` 를 이 정책값에 포함**(관리자가 재배포 없이 조정 — 토스 정책 변경 대비책). 토스 최소금액 미달 거부는 `paymentGateRejections` 에 기록되어 관리자가 상향 판단 가능.
- **D-7** = 권고. `config/qoin.spendEnabled` 전역 1개(신규 사용만 차단, 복원은 통과).

> **그 외 이미 확정(사용자 지시 반영, 재확인 불필요)**: 모델 A(결제 시 차감, 1 Qoin = 1원) / 서버 권위(차감·검증은 `verifyTossPayment` 안에서 원자적) / 클라이언트는 "사용 요청 Qoin" 만 보내고 서버가 재계산 / 동시성은 Firestore 트랜잭션 + 멱등.

---

## 1. 개요

- **목적**: 현재 Qoin 은 **적립(earn) 전용**이고 쓸 경로가 없다(backlog Q2). 이 task 는 고객이 결제 시 Qoin 으로 결제액을 차감하게 한다. 적립의 효용을 닫는 마지막 고리.
- **핵심 제약 (절대)**: Qoin 차감 금액과 최종 청구액은 **서버가 권위**를 갖는다. 클라이언트는 "사용 요청 Qoin(`qoinToUse`)" 만 보내고, 서버가 (잔액 ≥ 요청, 요청 ≤ 서버재계산 소계 − 최소현금, 정책 단위/상한) 을 검증한 뒤 **최종 청구액을 재계산**해 Toss 에 넘긴다. 이는 기존 `payment_price_authority`(서버 금액 재계산)와 **한 경로로 묶인다**.
- **가장 중요한 기술적 충돌**: 현재 금액 게이트(`priceGate.ts`)의 판정식 **`c2: totalPrice === subtotal`** 과 **`c4: amount === serverSubtotal`** 은 **할인이 0 임을 전제**한다. Qoin 사용은 `totalPrice = subtotal − Q` 를 만들어 이 두 식을 깬다. → 금액 게이트를 **할인 인식형으로 일반화**해야 한다(§5.3). `Q == 0` 이면 현재 동작과 **바이트 단위로 동일**해야 한다(prod 회귀 금지).

---

## 2. 요구사항

### 2.1 기능 요구사항

| # | 요구사항 |
|---|---|
| F1 | 고객이 결제(checkout) 화면에서 **사용할 Qoin 금액을 지정**하면 결제액에서 그만큼 차감된다 (1 Qoin = 1원). |
| F2 | **차감의 권위는 서버**다. `verifyTossPayment` 가 ⓐ 잔액 ≥ 요청 ⓑ 요청이 정책 범위(최소단위/상한/최소현금) ⓒ **서버 재계산 소계** 기준 최종청구액 = Toss 승인액 을 모두 검증한다. 하나라도 어긋나면 **confirm 전에 거절**(돈 안 움직임). |
| F3 | 잔액 차감 + 사용 원장 기록 + 주문/주문로그 생성은 **하나의 Firestore 트랜잭션**에서 원자적으로 일어난다. |
| F4 | 같은 주문의 차감은 **1회만** (CF 재시도/중복 호출에도 이중 차감 없음). 멱등 문서 ID `spend_{orderId}`. |
| F5 | 모든 잔액 변동은 원장 문서로 남는다 — 신규 타입 `spend`(음수) / `spendRefund`(양수, 복원). 기존 불변식 `qoinBalance == Σ amount` 유지. |
| F6 | 주문이 **환불/취소**되면 사용한 Qoin 이 **전액 복원**된다(`spendRefund`). 적립됐던 주문이면 적립분도 회수(`clawback`, 기존)된다. |
| F7 | 사용 정책값(최소단위/상한/최소현금/사용 kill switch)은 **코드에 하드코딩하지 않고** `config/qoin` 1곳에서 CF·클라이언트가 함께 읽는다. |
| F8 | **사용 kill switch**(`spendEnabled=false`) 로 신규 사용을 중단할 수 있다. 복원은 통과한다(D-7). |
| F9 | 사용 거절(잔액부족/정책위반/금액불일치)은 `paymentGateRejections` 에 신규 사유로 기록된다(오탐 탐지). |
| F10 | 구버전 앱(필드 미전송)은 **사용 0 = 기존 결제 흐름** 그대로 동작한다(하위호환). |

### 2.2 UI 요구사항 (designer 필요 — §9)

| # | 요구사항 |
|---|---|
| U1 | 결제(checkout) 화면에 **보유 Qoin 잔액** 표시 + **사용 금액 입력**(또는 "최대 사용" 토글). |
| U2 | 사용 금액 변경 시 **최종 결제액 실시간 반영**(= subtotal − 사용액). |
| U3 | 상태 UI: ⓐ 잔액 0 / ⓑ 사용 불가(`spendEnabled=false`) / ⓒ 요청이 상한·최소현금 초과(막고 안내) / ⓓ 서버 거절(잔액부족 등) 후 복구 안내. |
| U4 | 최소현금(D-3) 때문에 "전액 사용 불가" 인 경우를 명확히 안내("최소 N원은 결제해야 해요"). |
| U5 | 주문 상세 / Qoin 내역에 **사용/복원 거래**가 부호와 사유와 함께 표시(기존 내역 리스트 확장 — `QoinTransactionType` 에 `spend`/`spendRefund` 추가). |

### 2.3 상태 요구사항

| 상태 | 요구 |
|---|---|
| loading | 잔액은 이미 구독 중인 프로필 스트림에서 옴(즉시). 정책은 `config/qoin` 스트림. |
| error | 정책 로드 실패 → 사용 UI 를 **숨기고** 기존 결제(사용 0) 로 폴백(틀린 정책으로 차감 유도 금지). |
| empty | 잔액 0 → 사용 UI 비활성 + "적립하면 결제에 쓸 수 있어요" 안내. |
| 음수 잔액 | 방어적으로 렌더(§6.4). 사용 입력은 `max(0, balance)` 로 상한. |

---

## 3. 비범위 (이번에 하지 않음)

| # | 항목 | 사유 |
|---|---|---|
| N1 | **부분 환불 비례 복원** | `processRefund` 가 항상 전액 환불(기존). 부분환불 도입 시 별도 설계(기존 qoin spec Q11 과 동일). |
| N2 | **전액-Qoin(0원) 무결제 경로** | D-3 권고안이 최소현금을 남김. 0원 결제는 PG 없는 별도 경로가 필요 → 범위 밖. |
| N3 | **매장/브랜드별 사용 정책 계층화** | v1 은 전역 1단(D-7). |
| N4 | **Qoin 사용 비용 정산**(현금 매출 감소를 누가 부담?) | 적립 비용 정산(audit_trail §5)과 함께 미설계. **단, 원장에 `storeId`/`brandId` 를 남겨 후속 집계 가능하게 둔다.** |
| N5 | **선물하기/사용자 간 이전**(기존 Q8) | 별도 task. |
| N6 | **사용 예정/적립 예정 표시, 유효기간 소멸** | 기존 qoin spec Q3/Q6. |
| N7 | **잔액↔원장 자동 감사 CF** | v1 은 불변식 수동 점검(기존 Q10). 단 신규 타입 포함하도록 식만 갱신. |

---

## 4. 영향 범위

| 영역 | 영향 |
|---|---|
| 화면/Widget | **결제(checkout) 화면 수정** — Qoin 사용 UI 추가. Qoin 내역 타일에 `spend`/`spendRefund` 표시(기존 `qoin_transaction_tile.dart` 확장). |
| Provider | 결제 화면 상태에 "사용할 Qoin" 입력 상태 추가. 사용 가능액 계산 provider(잔액 + 정책 조합). |
| Domain Entity | `QoinTransactionType` 에 **`spend` / `spendRefund` 추가**. `QoinConfigEntity` 에 사용 정책 필드 추가. `CartEntity`/주문 금액 모델의 `discount` 를 실제로 사용(현재 null 고정). |
| UseCase | 사용 가능액/최종 결제액 계산(순수 로직, `core/utils`). 결제 요청에 `qoinToUse` 전달. |
| Repository/DataSource | `PaymentGatewayRepositoryImpl.cartToMap` 수정(`discount`/`totalPrice`), `verifyAndCreateOrder` 에 `qoinToUse` 파라미터 추가. `QoinRemoteDataSource`/`QoinConfigModel` 에 정책 필드 파싱. |
| **Cloud Functions** | ⓐ `verifyTossPayment` **수정**(사용 검증+차감, batch→조건부 transaction) ⓑ 신규 순수 모듈 `qoinSpend.ts`(정책 해석·검증) ⓒ `onOrderQoinSettled` **확장**(→cancelled/→refunded 에서 `spendRefund`) ⓓ (D-6 권고 시) 신규 `setQoinSpendPolicy` CF ⓔ (D-6 권고 시) `onQoinConfigWritten` 확장. |
| **priceGate.ts** | **할인 인식형으로 일반화**(§5.3). 가장 위험한 변경 — 회귀 테스트 필수. |
| orderBuilder.ts | `applyServerPricing` 가 `discount`/`totalPrice` 를 서버값으로 쓰도록 확장. |
| Firestore 구조 | `config/qoin` 신규 필드. `qoinTransactions` 신규 타입 2종. `orders.discount` 활성. Rules: config 사용정책 필드 쓰기 차단(D-6 CF안 시). |
| 골든 계약 | `test_fixtures/qoin_cart_contract.json` + `CONSUMED_CART_KEYS` — `qoinToUse` 반영(§8.1). |
| 테스트 | priceGate 할인 회귀(PPA-*), qoinSpend 단위, verifyTossPayment E2E(사용/전액근접/잔액부족/멱등/동시), 트리거 복원 E2E, Rules, Dart 단위. |
| 권한/환경 | `firestore.rules` 배포, CF 재배포. **`PAYMENT_PRICE_MODE` 와의 결합**(§5.3 핵심). |

---

## 5. 서버 권위 설계 (핵심)

### 5.1 입력 — 클라이언트가 보내는 것

- 신규 입력 **`qoinToUse: int`** (`VerifyPaymentInput` 최상위, `amount`/`paymentMethod` 형제). 사용 요청액. 미전송/음수 → **0 으로 간주**(하위호환, F10).
- `cart.discount` = `qoinToUse`, `cart.totalPrice` = `cart.subtotal − qoinToUse` 로 클라이언트가 **표시·기록용** 으로 채운다. **단 이 값들은 권위가 아니다** — 서버가 `qoinToUse` 를 검증하고 금액을 재계산한다.
- 기존 입력 검증 유지: `amount === cart.totalPrice`(클라 자기정합). Q=0 이면 `totalPrice === subtotal` 이라 기존과 동일.

### 5.2 신규 순수 모듈 `functions/src/qoinSpend.ts`

Firebase 비의존 순수 함수(단위 테스트 용이, priceGate/qoinRate 와 동일 패턴):

```
resolveSpendPolicy(configData) → { spendEnabled, minUnit, maxPerOrder|maxRatio, minCashFloor }
  // 부재/비정상 값은 fail-closed 또는 안전 기본(아래 표)

validateQoinSpend({ requested, balance, serverSubtotal, policy }) →
  | { ok: true, validatedQ }
  | { ok: false, reason: 'DISABLED'|'INSUFFICIENT_BALANCE'|'BELOW_MIN_UNIT'|'NOT_UNIT_MULTIPLE'|'EXCEEDS_CAP'|'BELOW_CASH_FLOOR' }
```

판정 규칙(권고안 기준, D-1/2/3 확정 시 고정):
1. `requested == 0` → `{ok:true, validatedQ:0}` (사용 안 함, 항상 통과).
2. `spendEnabled !== true` → `DISABLED`.
3. `requested` 가 정수·양수 아님 → 거절(`BELOW_MIN_UNIT`).
4. `requested % minUnit != 0` → `NOT_UNIT_MULTIPLE` (D-2 가 100단위일 때만 유효).
5. `requested > balance` → `INSUFFICIENT_BALANCE`.
6. `requested > (serverSubtotal − minCashFloor)` → `BELOW_CASH_FLOOR` (최소현금 보장, D-3).
7. (D-1 대안 선택 시) 비율/절대 상한 초과 → `EXCEEDS_CAP`.
8. 통과 → `validatedQ = requested`.

> **serverSubtotal 은 반드시 서버 재계산값**이다. 클라 `subtotal` 을 쓰면 "subtotal 뻥튀기 → Q 로 거의 전액 차감" 공짜 돈 공격이 가능하다. 그래서 §5.3 이 선행이다.

### 5.3 금액 게이트 일반화 (가장 위험한 변경)

현재 `evaluatePriceAuthority`(priceGate.ts)의 판정식:
- `c2: totalPrice === subtotal`, `c4: clientAmount === serverExpected(=serverSubtotal)`.

**일반화**: 할인 `D`(= 검증된 Qoin 사용액)를 1급 입력으로 받아
- `c2'`: `cart.totalPrice === cart.subtotal − D`
- `c4'`: `clientAmount === serverSubtotal − D` ← **권위 판정**
- `c1`(amount===totalPrice), `c3`(subtotal===clientLineSum), `c5`/`c6`(라인 단가·합계)은 **그대로**.
- **`D == 0` 이면 c2'/c4' 는 현행 c2/c4 와 완전히 동일** → 비-Qoin 주문 회귀 0. 하네스 `PPA-3*`(정상흐름)이 바뀌지 않아야 한다.

**모드 결합 (중대 보안 규칙)**: `qoinToUse > 0` 인 주문은 **`PAYMENT_PRICE_MODE` 값과 무관하게 서버가 소계를 재계산하고 최종청구액을 enforce** 한다. 할인의 정당성은 **권위 있는 소계**에 의존하므로, 가격 모드가 `off`/`shadow` 라고 Qoin 차감을 클라 소계로 믿으면 공짜 돈이 샌다(backlog: "차감은 PPA 와 한 경로로 묶기"). 즉:
- 비-Qoin 주문: 기존대로 `PAYMENT_PRICE_MODE` 가 지배.
- Qoin 주문(`Q>0`): **항상 재계산·enforce**(모드가 off 여도 `resolveMenusForPricing` + `evaluatePriceAuthority` 를 강제 실행). 재계산 실패(READ_FAILED)·불일치면 **거절**.

### 5.4 `verifyTossPayment` 수정 흐름 (Q>0 경로)

```
1 auth / 입력검증(qoinToUse 정수≥0, amount===cart.totalPrice)
2 멱등 가드 (orders/{idempotencyKey} 존재 → 동일결과 반환)  ← 기존
3 자기거래 가드 (stores 읽음 → ownerId/brandId 확보)        ← 기존 (brandId 재사용)
4 결제 게이트 G1/G2                                          ← 기존
5 금액 재계산: serverSubtotal 산출
     - Q>0 이면 PAYMENT_PRICE_MODE 무관 강제 실행 (§5.3)
6 Qoin 사용 검증 (confirm 전):
     - users/{uid} 잔액 read + config/qoin 정책 read
     - validateQoinSpend(...)  →  실패 시 recordGateRejection(QOIN_SPEND_*) + throw (돈 안 움직임)
     - serverFinal = serverSubtotal − validatedQ
     - assert amount === serverFinal  (틀리면 PRICE_MISMATCH 류 거절)
7 Toss confirm                                               ← 기존
8 응답검증 (DONE/amount/orderId)                              ← 기존
9 최종 쓰기:
   if validatedQ > 0:  db.runTransaction:
       t.get(spendRef = qoinTransactions/spend_{orderId})  → 있으면 already → 주문만 set(멱등)
       t.get(users/{uid})  → balanceBefore
       재검증: balanceBefore ≥ validatedQ  (아니면 abort)   ← §5.5 동시성
       balanceAfter = balanceBefore − validatedQ
       t.set(orders/{orderId}, orderData(discount=validatedQ, subtotal, totalPrice=serverFinal))
       t.set(orderLogs/{logId}, logData)
       t.set(spendRef, {type:'spend', amount:-validatedQ, balanceAfter, orderId, storeId, storeName, brandId, orderSubtotal, orderTotalPrice:serverFinal, createdAt})
       t.update(users/{uid}, { qoinBalance: balanceAfter })   // 절대값, 1필드만
     ※ 트랜잭션 abort(잔액부족)면 → Toss cancel 시도 + throw (기존 '검증실패→cancel' 패턴 재사용)
   else:  기존 batch 경로 그대로 (order + orderLog)             ← 비-Qoin 회귀 0
10 orderSignals (best-effort)                                 ← 기존
```

- **왜 batch→transaction(조건부)**: 잔액 "read→검증→차감" 과 원장·주문 생성이 쪼개지면 이중 차감/잔액 유실이 난다. Admin SDK 트랜잭션은 다중 컬렉션 쓰기를 지원한다. **Q==0 은 기존 batch 유지**(prod 동작 불변).
- **Toss confirm 은 트랜잭션 밖**(외부 HTTP, 롤백 불가). 그래서 "confirm 전 검증(6)" + "confirm 후 트랜잭션 재검증(9)" 2단.

### 5.5 멱등 · 동시성

- **멱등**: ⓐ 기존 orders/{id} 선존재 가드 ⓑ 트랜잭션 내 `spend_{orderId}` 선존재 가드. onCall 은 자동 재시도가 없고, 클라 중복 호출은 ⓐ 가 흡수. 차감 중복은 ⓑ 가 흡수.
- **동시 결제(같은 유저 2건)**: 6번 사전검증은 둘 다 통과할 수 있으나, 9번 트랜잭션에서 **두 번째는 잔액 부족으로 abort** → 이미 confirm 된 Toss 결제는 **cancel + 에러**로 되돌린다. 윈도가 극히 좁고 자기-동시결제라는 병리적 케이스만 해당. 이 트레이드오프를 숨기지 않는다(기존 qoin spec §4.2 의 "레이스 방지" 가 트랜잭션 잔액의 존재 이유).

---

## 6. 환불/취소 시 복원 + 적립 상호작용

### 6.1 트리거 커버리지 — `onOrderQoinSettled` 확장

사용(spend)은 **결제 시점(paid)** 에 일어난다. 따라서 복원은 **paid 이후의 모든 종료 전이**를 덮어야 한다. 현재 트리거는 `*→completed`(earn), `completed→refunded`(clawback) 만 처리 → **복원 전이를 놓친다.**

| 전이 | 주체 CF | 신규 동작 |
|---|---|---|
| `* → completed` | (status update) | 적립 earn (**기존, 불변**) |
| `completed → refunded` | processRefund | 회수 clawback (기존) **+ 사용복원 spendRefund (신규)** |
| `accepted/making/ready → refunded` | processRefund | **사용복원 spendRefund (신규)** — earn 없으니 clawback 은 no-op |
| `paid → cancelled` | cancelTossPayment | **사용복원 spendRefund (신규)** — 고객취소/점주거절 모두 |

- **복원 로직**: `spend_{orderId}` 원장을 읽어 **금액 반전**(재계산 금지, clawback 과 동일 패턴). 없으면 no-op(Qoin 안 쓴 주문). 멱등 ID `spendRefund_{orderId}`.
- **kill switch 상호작용**: 전역 `enabled=false` → 복원도 멈춤(상위 비상정지). 사용 `spendEnabled=false` 는 **복원을 막지 않는다**(D-7) — 막으면 환불된 고객 돈이 증발.
- **복원은 적립률/스위치를 읽지 않는다**(원장 반전뿐) → clawback 과 같은 read 비용 구조.

### 6.2 적립 ↔ 사용 상호작용 (D-4)

- `order.totalPrice = serverFinal = subtotal − Q`(현금 결제액)로 저장 → `onOrderQoinSettled` earn 이 `totalPrice` 를 읽으므로 **자동으로 "실결제액 기준 적립"**(권고안). earn 코드 변경 불필요.
- 한 주문이 completed→refunded 면 **같은 전이에서 clawback(적립 반전) + spendRefund(사용 복원)** 둘 다 발생. 서로 독립 원장, 각자 멱등. 순 효과: 잔액이 주문 전으로 원복.

### 6.3 불변식 (갱신)

```
qoinBalance == Σ qoinTransactions[*].amount
  types: earn(+) · clawback(−) · spend(−) · spendRefund(+)   (전부 부호 포함)
```
- append-only, clamp 금지(기존 §5.4 그대로). **음수 잔액 가능**(이번 주문 적립분을 다른 주문에 쓴 뒤 이 주문이 환불되어 clawback 되면 음수가 사실이 됨) — 사용시점 가드(`Q ≤ 현재잔액`)는 "지금보다 더" 는 막지만 미래 clawback 은 못 막는다. **의도된 동작**, clamp 하면 감사가 무력화된다.

### 6.4 음수 방어

- 사용 입력 상한 = `max(0, balance)` 클라이언트 + 서버 재검증. 잔액 음수면 사용 UI 비활성.

---

## 7. 데이터 모델

### 7.1 `config/qoin` 신규 필드 (사용 정책)

| 필드 | 타입 | 기본/부재 시 | 비고 |
|---|---|---|---|
| `spendEnabled` | bool | **부재 → false (사용 차단, fail-closed)** | 사용 kill switch(D-7). 돈 쓰는 기능은 명시 켜야 켜짐. |
| `minSpendUnit` | int | 부재 → 1 (D-2) | 최소 사용 단위. |
| `minCashFloor` | int | 부재 → fail-closed(사용 차단). **초기 세팅값 300** (D-3 확정) | 최소 현금 결제액(D-3) — **결제수단 무관 단일 값**. 기본 300원(토스 수단별 최소금액 중 최대치). 관리자가 `setQoinSpendPolicy`로 조정. |
| `maxSpendPerOrder` / `maxSpendRatio` | int / number | 부재 → 한도 = subtotal−minCashFloor (D-1 권고) | D-1 대안 선택 시만 사용. |

> 위 필드는 **돈·정책 값** → **설정 변경 이력이 기본값**(audit §4-1). §8.2 참조.

### 7.2 `users/{uid}/qoinTransactions/{txId}` 신규 타입

| 필드 | spend | spendRefund |
|---|---|---|
| `txId` | `spend_{orderId}` | `spendRefund_{orderId}` |
| `type` | `'spend'` | `'spendRefund'` |
| `amount` | **−Q (음수)** | **+Q (양수, spend 에서 반전)** |
| `balanceAfter` | 트랜잭션 내 계산 | 동일 |
| `orderId`/`storeId`/`storeName` | 주문값 | spend 원장에서 상속 |
| `brandId` | `stores/{id}.brandId`(자기거래 가드가 읽은 값) | spend 에서 상속 |
| `orderSubtotal` | subtotal(서버) | spend 에서 상속 |
| `orderTotalPrice` | serverFinal(현금) | spend 에서 상속 |
| `createdAt` | serverTimestamp | serverTimestamp |

- `QoinTransactionType`(Dart enum) 에 `spend`, `spendRefund` 추가. `fromCode` 미지값 → null → UI 중립 문구(전방호환 기존 설계 유지).

### 7.3 `orders/{orderId}` — 기존 필드 활성

- `discount`: 지금까지 **항상 null**(orderBuilder.ts:99). → `validatedQ`(서버값) 저장.
- `subtotal`: 서버 소계. `totalPrice`: `serverFinal`. (Q=0 이면 discount=null, totalPrice=subtotal — 기존과 동일.)
- `orderLog` 에도 `discount` 추가 권장(내역 일관성, 선택).

---

## 8. 기존 계약 / 보안 / 감사

### 8.1 골든 계약 (`qoin_cart_contract.json` ↔ `CONSUMED_*`)

- `qoinToUse` 는 **cart 밖 최상위 입력**으로 두는 것을 권고(장바구니는 메뉴 선택을 표현; 차감은 결제시점 선택). → `qoin_cart_contract.json` 의 `keys`(cart 키)는 **그대로**(`discount` 이미 포함), 대신 **최상위 입력 계약**을 fixture 주석/별도 키로 고정하고 Dart `verifyAndCreateOrder`/`cartToMap` 양쪽 테스트가 읽게 한다.
- `cart.discount` 가 이제 non-null 일 수 있음을 계약 주석에 명시. `CONSUMED_CART_KEYS` 는 `discount` 를 이미 포함하므로 cart 키 변화 없음.
- **한쪽만 바꾸면 골든이 깨지도록** Dart·TS 양쪽 테스트가 같은 fixture 를 읽는 기존 규율 유지.

### 8.2 감사 추적 — audit_trail.md §4 체크리스트 6항목

1. **돈·권한·정책 값 변경?** → **그렇다.** 사용 정책(`spendEnabled`/`minCashFloor`/상한/단위)은 정책값. **설정 변경 이력을 남긴다**(기본값). → `config/qoin/qoinRateHistory` 재사용, `field` 에 `'spendEnabled'`/`'minCashFloor'`/`'minSpendUnit'`/`'maxSpend*'` 추가. 쓰기 주체는 **CF(`setQoinSpendPolicy`) 전담**(D-6 권고) → "이력 없는 변경이 구조적으로 불가". D-6 를 Console 안으로 정하면 `onQoinConfigWritten` 트리거가 이 필드들을 기록하도록 확장(그 경우에도 이력은 남긴다).
2. **덮어쓰기로 사라지는 값?** 정책값은 히스토리로 보존. 잔액은 덮어쓰지만 **원장이 진실**(append-only). OK.
3. **거래 기록이 정책값 참조만?** → 아니오. spend 원장에 `orderSubtotal`/`orderTotalPrice`/`amount` 를 **당시 값으로 박제**. 정책이 바뀌어도 과거 사용 기록 불변.
4. **"누가"?** 사용 행위자 = 고객 `uid`(원장 하위컬렉션 경로 + 주문 `userId`). 복원 = CF(system). 정책 변경 = `changedBy` admin uid(`setQoinSpendPolicy`).
5. **batch?** 사용은 주문 단위. 정책 변경은 단건. 해당 없음.
6. **CF 로그 의존?** 아니오 — 사용 거절은 `paymentGateRejections`(Firestore, 영구), 복원 누락 가능성은 (spend 원장이 있으면) 트리거 멱등 재시도. 정책 이력은 Firestore.

> 추가(상시 §4-7): **권한/판정 입력 필드의 create·update 교차 확인.** `config/qoin` 의 사용정책 필드를 CF 전담으로 할 경우 Rules 에서 **create·update 양쪽** 차단(기존 `accrualRate` 와 동일 하네스에 케이스 추가). 정상 payload 회귀 케이스도 함께.

### 8.3 기존 가드와의 정합

- **자기거래 가드**: 변경 없음. 이미 읽은 store 의 `ownerId`/`brandId` 를 spend 원장 `brandId` 와 재사용(추가 read 0).
- **orderSignals**: 변경 없음(주문 커밋 후 best-effort). 신호에 사용액을 추가할지는 선택(기본 미포함).
- **data_ownership**: `users.qoinBalance`/`qoinTransactions` 는 **CF 전담 쓰기**(기존). spend/spendRefund 도 동일 경로라 Rules 변경 불필요(원장 create/update/delete = `if false` 유지). `config/qoin` 사용정책 필드만 Rules 추가(D-6).

---

## 9. 레이어 설계

### Domain
- Entity: `QoinTransactionType` +`spend`/`spendRefund`. `QoinConfigEntity` + 사용정책 필드.
- UseCase/순수로직: `core/utils` 에 최종결제액·사용가능액 계산(클라 표시용; **권위는 서버**). 
- Repository: `QoinRepository` 는 조회 전용(기존). 쓰기는 CF. `PaymentGatewayRepository.verifyAndCreateOrder` 시그니처에 `qoinToUse` 추가.

### Data
- `QoinConfigModel.fromFirestore` 사용정책 파싱(방어적). 
- `PaymentGatewayRepositoryImpl.cartToMap`: `discount`/`totalPrice` 반영. `verifyAndCreateOrder`: `qoinToUse` 전달.
- **Functions(data 레이어와 동급의 서버)**: `qoinSpend.ts`(순수), `verifyTossPayment.ts`(수정), `priceGate.ts`/`orderBuilder.ts`(일반화), `onOrderQoinSettled.ts`(복원 확장), (`setQoinSpendPolicy.ts` + `index.ts` 등록).

### Presentation
- 결제 화면: Qoin 사용 입력 위젯 + 최종액 반영 + 상태 UI. provider 로 "사용할 Qoin" 상태 보관.
- Qoin 내역 타일: spend/spendRefund 렌더(부호·사유·중립 폴백).

데이터 흐름:
```
Checkout UI → (사용액 입력) provider → verifyAndCreateOrder(qoinToUse) 
  → PaymentGatewayRepositoryImpl → FunctionsDataSource.verifyTossPayment
  → [서버] 게이트 → qoinSpend 검증 → Toss confirm → 트랜잭션(차감+원장+주문)
→ onOrderQoinSettled(상태전이) → earn/clawback/spendRefund
```

---

## 10. 에러 처리

| 케이스 | 처리 |
|---|---|
| `qoinToUse` 음수/비정수 | 입력검증 거절(invalid-argument). |
| `spendEnabled=false` 인데 Q>0 | `QOIN_SPEND_DISABLED` 거절 + 기록. confirm 전. |
| 잔액 < Q (사전) | `QOIN_INSUFFICIENT_BALANCE` 거절 + 기록. confirm 전. |
| 최소현금/상한/단위 위반 | `QOIN_SPEND_*` 거절 + 기록. confirm 전. |
| 서버 소계 재계산 실패(Q>0) | READ_FAILED 거절(통과 금지 — 할인 정당성 근거 없음). |
| `amount !== serverFinal` | PRICE_MISMATCH 거절 + 기록. |
| 잔액 부족(트랜잭션 재검증, confirm 후) | Toss cancel + 에러(기존 검증실패 패턴). |
| 정책 read 실패(일시) | throw(일시장애). confirm 전이라 돈 안 움직임. |
| 클라 정책 로드 실패 | 사용 UI 숨기고 기존 결제(Q=0) 폴백. |
| 복원 시 spend 원장 없음 | no-op(info 로그). |

---

## 11. 작업 분배

### designer (필요 — 먼저 호출)
- 결제 화면 Qoin 사용 UI: 잔액 표시, 사용액 입력/"최대 사용" 토글, 최종결제액 반영, 상태 UI(U1~U4). 내역 타일 spend/spendRefund 표현(U5).
- 산출물: `docs/tasks/qoin_spend/design.md`.
- 전달: AppColors 재사용, 최소현금·상한으로 "전액 불가" 안내 카피, 음수 잔액 방어 렌더.

### developer (design 후)
- **순서 권고**: ① `qoinSpend.ts`(순수) + 단위테스트 ② `priceGate`/`orderBuilder` 할인 일반화 + PPA 회귀 ③ `verifyTossPayment` 사용검증·트랜잭션 ④ `onOrderQoinSettled` 복원 확장 ⑤ (D-6) `setQoinSpendPolicy` + Rules ⑥ Dart(enum/config/cartToMap/verifyAndCreateOrder/결제화면).
- 재사용: `resolveMenusForPricing`/`evaluatePriceAuthority`(소계), 자기거래 store read(brandId), 1차 트랜잭션 의사구조, `orderLogs`/`qoinTransactions` 원장 패턴.
- 레이어 규칙: Firebase 직접 사용은 data·functions 만. 색상 AppColors. 정책값 하드코딩 금지(config/qoin). 원장 append-only(clamp 금지). floor 외 단수처리 금지(해당 시).
- 산출물: `docs/tasks/qoin_spend/implementation.md`.

### tester (구현 후)
- 핵심 검증: ⓐ **Q=0 비-Qoin 주문 회귀 0**(바이트 동일) ⓑ 정상 사용(차감·원장·잔액·주문 discount) ⓒ 잔액부족 사전/사후(Toss cancel) ⓓ 최소현금·단위·상한 경계 ⓔ **멱등**(중복호출·재시도) ⓕ **동시 결제** 두 번째 abort ⓖ 환불/취소 전 전이에서 **복원**(paid→cancelled, accepted/making/ready→refunded, completed→refunded 동시 clawback+spendRefund) ⓗ `spendEnabled=false` 복원 통과 ⓘ 골든 계약(한쪽 변경 시 실패) ⓙ Rules(config 정책 필드 create·update 차단 + 정상 회귀) ⓚ 불변식 `balance==Σamount`(4타입).
- 산출물: `docs/tasks/qoin_spend/test_report.md`.

---

## 12. 완료 기준

- [ ] §0 결정 7건 확정·반영
- [ ] design.md 완료
- [ ] implementation.md 완료 (CF·priceGate·트리거·Dart·Rules·fixture)
- [ ] test_report.md 완료, FAIL 없음 또는 후속 분리
- [ ] 비-Qoin 주문 회귀 0 확인(가장 중요)
- [ ] 골든 계약 양방향 고정
- [ ] 사용 정책 설정 변경 이력 동작 확인(audit §4)
- [ ] `config/qoin` 사용정책 값 세팅(특히 `minCashFloor` — 토스 최소금액 확인) 후에만 `spendEnabled=true`

## 13. 배포 체크리스트 (요약)
1. 토스페이먼츠 **실결제 최소 승인금액 확인**(D-3) → `minCashFloor` 확정.
2. `config/qoin` 사용정책 필드 세팅(`spendEnabled=false` 로 배포 → 코드/게이트 먼저 안착).
3. CF 재배포(`verifyTossPayment` 등). `PAYMENT_PRICE_MODE` 상태 확인(Qoin 주문은 강제 enforce 지만 비-Qoin 영향 점검).
4. Rules 배포(config 정책 필드).
5. shadow 관측 후 `spendEnabled=true` 전환.
</content>
</invoke>
