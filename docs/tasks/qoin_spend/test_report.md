# Qoin 사용(spend) 테스트 리포트

- 검증: tester (독립 재실행 + 코드 직접 확인)
- 검증일: 2026-11-02
- 대상 커밋: `0c96b3a` (main). 기준: `spec.md`(§0, §5~§8), `design.md`(DD-1~5), `implementation.md`, `CLAUDE.md`, `docs/architecture.md`
- 코드 수정·배포 없음. git 조작은 에뮬레이터 비교용 detached checkout 1회뿐이며 `main`(0c96b3a) 로 복귀했다. working tree 는 검증 전과 동일하다 (`?? .firebase/ .firebaserc docs/tasks/rebrand/` 만 — 본 작업 이전부터 존재).

## 0. 결과 요약

| 구분 | 개수 |
|---|---|
| PASS | 핵심 불변식 9/9, 규칙 준수 3/3, 에뮬레이터 "기존 실패" 주장 검증 1/1 |
| **FAIL** | **0** |
| 보류 | 6 (아래 §5) |

**차단 사유(FAIL) 없음. 머지·배포 진행 가능.** `spendEnabled` 부재 = OFF 라 배포해도 기능은 꺼진 채 안착한다 (코드로 확인: `resolveSpendPolicy` fail-closed).

## 1. 독립 재실행 수치

| 항목 | 결과 | implementation.md 주장 |
|---|---|---|
| `flutter analyze` | No issues found | 일치 |
| `flutter test` | **1001 passed / 0 failed** | 일치 |
| `functions` `npm test` (tsc + 9 파일) | **465 pass / 0 fail** | 일치 |
| `test_rules` `npm test` | **479/479 PASS** | 일치 |
| `functions` `npm run test:emulator` (HEAD) | **113 PASS / 3 FAIL** (총 116) | 일치 |
| 동 스위트, 변경 전 `c9a577b`(= `0c96b3a~1`) | **93 PASS / 3 FAIL** | 일치 (93/96) |

### 에뮬레이터 3건 "기존 실패" 검증 : PASS
- 변경 전 코드에서 같은 3건이 동일 메시지로 실패한다: `CH16 earn(브랜드 소속)` (read 5 기대 / 6 실측) · `Q1 일괄 덮어쓰기 … 켜진 매장은 새 브랜드 값` · `CF7 auditBrandLinks … 쓰기 0 지문`.
- 케이스를 직접 읽었다. 세 건 모두 브랜드 적립률 / 브랜드 링크 감사 영역으로 spend 코드 경로(verifyTossPayment 의 Q>0 분기, spend 원장, 복원)와 무관하다. 변경 전 20 PASS 가 늘어난 차이(93→113)가 신규 SP1~SP17(+SP5 변형)이다.
- 같은 CH16 의 **clawback** 케이스는 spend 확인 read +1 로 기대값을 4→5 로 올렸다. 이는 spec 변경에 따른 의도된 갱신으로 타당하다 (왕복 ≤ 4 유지를 `getAll` 1회로 지킴).
- 3건은 본 기능과 무관한 기존 부채다. 별도 task 로 분리를 권한다 (§6).

## 2. 핵심 불변식 검증 (돈 이동)

| # | 불변식 | 결과 | 근거 |
|---|---|---|---|
| 1 | 잔액 무결성 `qoinBalance == Σ(amount)` | PASS | 모든 잔액 변경이 원장 문서 쓰기와 **같은 트랜잭션**: `reserveSpend`(`qoinSpendLedger.ts` t.set spend + t.update 절대값), `rollbackSpend`(반전 원장 `spendRefund_`), 복원은 기존 `applyTransaction`. 삭제 경로 없음(append-only). 에뮬레이터 `sumLedger==0` 단언: SP4(롤백), SP5(복원 4전이), SP6(4타입), SP7 멱등. 단위: `qoinSpend.test.mjs:455` |
| 2 | 회귀 0 (Q=0) | PASS | `priceGate.ts` 디프 확인: D 기본 0 → `serverExpected`/`c2`/`pricing.expected` 가 D=0 분기에서 **현행 식 그대로**, 거절 `detail.discount` 는 D≠0 일 때만 키 생성(`...(discount !== 0 ? {discount} : {})`). `verifyTossPayment`: `qoinToUse>0` 분기 밖에서는 정책 read·트랜잭션·인자 모양 변화 없음(`discount` 키를 아예 안 넘김). 테스트: "회귀 Q=0" 가격모드 4종(`qoinSpend.test.mjs:268`), Q=0 명시/null(286), off 모드에서 클라 금액 신뢰 유지(297), 기존 `priceAuthority.test.mjs` 무수정 통과, 앱 `qoin_spend_checkout_test` "숨김=이전과 동일" + 기존 `payment_price_checkout_page_test` 무수정 통과 |
| 3 | 서버 권위 | PASS | `qoinToUse>0` ⇒ `priceMode="enforce"` 강제(verifyTossPayment 312행). 한도 = 서버 재계산 소계 − `minCashFloor`(`validateQoinSpend`), 소계는 `serverPricing.subtotal`. `data.amount !== serverFinal` 재확인(벨트+멜빵). 소계 뻥튀기(서버 4000/클라 40000/Q=39700)가 off 모드에서도 거절(테스트 420, 에뮬 SP12). 음수·소수·문자열 `qoinToUse` → invalid-argument(`parseQoinToUse`, confirm 0) |
| 4 | 멱등·동시성 | PASS | `reserveSpend` 가 `spend_{orderId}` 선존재 가드 + 잔액 read + 판정 + 쓰기를 한 트랜잭션에서. 같은 키 성공 후 재호출 → 기존 주문 반환(이중 차감 0, 테스트 505). 예약만 남은 상태 + 같은 키 → `aborted`, 롤백 안 함(518). 동시 2건 → 두 번째는 confirm 호출 0 으로 `QOIN_INSUFFICIENT_BALANCE`(531), **실 Firestore 트랜잭션 경합 SP2**: 정확히 1건 성공, 음수 없음 |
| 5 | 차감 시점 | PASS | 코드 순서 확인: 정책 → 금액게이트 → `reserveSpend` → Toss confirm → 응답검증 → 주문 batch → `reservation=null`. 전체가 바깥 `try/catch`, `undoQoinReservation` 이 롤백(+ confirm 후면 Toss cancel 선시도). 롤백 실패는 `recordSpendIssue(spend_rollback_failed)`. 테스트: confirm throw(459), status≠DONE(469), batch 실패+cancel(477), 롤백 실패 기록 + 원본 에러 유지(487), Q=0 은 롤백 코드 미진입(497). 취소 금액은 `paymentInfo.amount`(현금)라 `cancelTossPayment` 도 정합 |
| 6 | 복원 커버리지 | PASS | `onOrderQoinSettled`: `isRestore = after ∈ {cancelled, refunded}` (출발 무관). `completed→refunded` 는 `getAll` 1회로 config·earn·spend 읽고 `clawbackEarn` + `restoreSpend` 둘 다. 멱등 ID `spendRefund_{orderId}`(롤백과 동일 ID — 키가 시도마다 새 UUID 라 충돌 없음). 복원은 `config.enabled` 만 확인, `spendEnabled=false` 통과(SP9). 전역 `enabled=false` → 멈춤 + `spend_restore_skipped_disabled` 기록(SP10). SP5 4전이, SP6 4타입 동시, SP7 재전달 멱등, SP8 미사용 no-op |
| 7 | 정책·Rules | PASS | `qoinSpendPolicyFields()` 1곳을 `config/{docId}` **create(`keys().hasAny`) 와 update(`affectedKeys().hasAny`) 양쪽**에 적용. 하네스 QS-R1~R1f(update·삭제·setDoc 교체), R2~R2c(create 3필드), R3(고객·점주), **R4 정상 payload 허용 회귀**, R5 고객 read 허용, R6/R7(원장·issues 직접 쓰기 차단). tester_guide 의 "create 거부 1 + 정상 허용 회귀 1" 충족. `setQoinSpendPolicy`: admin 전용, 같은 트랜잭션에 값+이력, `minCashFloor` 없이 `spendEnabled:true` 거부, noop 은 이력 없음(SP13~SP16), Console 편집은 `source:'direct'`(SP17) |
| 8 | 거절사유 5종 기록 | PASS | `rejectSpend` 가 `recordGateRejection` 후 throw (DISABLED/BELOW_MIN_UNIT/NOT_UNIT_MULTIPLE/INSUFFICIENT_BALANCE/BELOW_CASH_FLOOR 전부 `SPEND_REJECT_TOKEN` 경유). 테스트 361행 `rejections.at(-1).reason` 사유별 단언 |
| 9 | 골든 계약 | PASS | `qoin_cart_contract.json`(`inputKeys`/`requiredInputKeys`)은 TS `qoinRate.test.mjs:157` ↔ Dart `qoin_f1_contract_test.dart`, `qoin_spend_contract.json` 은 TS `qoinSpend.test.mjs:17` ↔ Dart `qoin_spend_calculator_test.dart:11` 가 **같은 파일**을 읽는다. 한쪽만 바뀌면 깨지는 구조임을 코드로 확인 (변조 실험은 수정 금지 지침상 하지 않음) |

## 3. 규칙 준수 (CLAUDE.md)

| 항목 | 결과 | 근거 |
|---|---|---|
| Clean Architecture | PASS | 변경된 `lib/` 파일 중 `cloud_firestore`/`cloud_functions`/`firebase_*` import 는 `data/`(`cloud_functions_remote_data_source.dart`, `qoin_config_model.dart`)뿐. domain·presentation·core 0건. 계산기는 `core/utils` 순수 Dart, 레포지토리 인터페이스는 domain, 구현은 data |
| AppColors 만 | PASS | 변경 파일 전체에서 `Color(0x` 0건. `qoin_spend_section.dart` 전부 `AppColors.*`. 유일한 `Colors.transparent`(checkout_page, 타일)는 비색상(투명) 용도이며 기존 패턴 |
| 시크릿 하드코딩 | PASS | 신규 시크릿 없음 (`TOSS_SECRET_KEY` 기존, 배포 순서에도 신규 시크릿 없음 명시). Mock 분기 `test_gsk_docs_` 접두 검사는 기존 코드 |
| 파일 위치·네이밍 | PASS | `qoin_spend_*.dart` snake_case, `qoinSpendViewProvider` 등 Provider 접미, UseCase 단일 책임 유지 |
| generated 파일 | PASS | `qoin_config_entity.freezed.dart` 는 build_runner 재생성분 |
| 비범위 임의 구현 | PASS | `maxSpendPerOrder`(X-5), 부분환불·0원결제·선물·소멸 미구현, 구현자가 스스로 기록 |

## 4. spec 이탈(X-1~X-6) 타당성

모두 타당하며 implementation.md §0 에 근거가 기록돼 있다.
- X-1(차감을 confirm **전**으로): "confirm 후 잔액 부족"을 원천 제거하는 쪽이 안전. 대신 롤백 복잡도가 늘었으나 위 불변식 5 로 테스트 커버.
- X-2(음수 입력 거절): spec 내부 모순 해소, 조용히 0 으로 바꾸지 않아 보수적.
- X-3(복원 전이 전부), X-4(비상정지 중 복원 누락을 issues 로 기록), X-6(삭제 아닌 반전 원장): 돈이 새거나 증발하는 방향을 막는 쪽이라 타당.

## 5. 보류 항목

| # | 항목 | 판정 | 비고 |
|---|---|---|---|
| H-A | **N4 점주 정산** | 보류(후속 task), 깨짐 아님 | `orders.discount` 가 활성화되며 점주 주문상세(`common/price_summary.dart`, `owner_order_detail_page.dart:772`)에 `할인` 행이 신규 노출되고 `owner_sales` 가 현금액(`totalPrice`) 기준이라 Qoin 사용분만큼 점주 집계가 줄어든다. 크래시·불일치가 아니라 "누가 Qoin 비용을 부담하나" 정책 미결정에서 오는 **미설계**다. 후속 집계에 필요한 키는 spend 원장에 이미 박제돼 있다 (`storeId`/`brandId`/`orderSubtotal`/`orderTotalPrice`, `reserveSpend` 및 `spendRefundFields` 상속 확인). 단 점주에게 '할인' 라벨이 Qoin 이라는 설명 없이 보이므로 **`spendEnabled` 를 켜기 전**에 점주 표시 정책(라벨/매출 정의)을 확정하길 권한다 |
| H-B | **고아 예약**(차감 직후 서버 다운) | 범위 판단 타당, 보류 | 발생 조건이 "트랜잭션 커밋~다음 await 사이 인스턴스 종료"로 좁고, `spendEnabled` 기본 OFF 라 노출 전에 점검 쿼리(`operations §6.7`: `spend_*` 중 `orders/{id}` 부재 + `spendRefund_` 부재)를 갖춘 상태다. 다만 해당 시 **고객 Qoin 이 묶이고 시스템이 알아채지 못한다**(issues 미기록, `recordSpendIssue` 는 롤백 시도가 있었을 때만). 사용 시작 후 점검 쿼리 주기 실행으로 빈도를 보고, 발생하면 스케줄 스위퍼를 후속으로 둔다는 판단에 동의 |
| H-C | **confirm 응답 유실 후 실제 승인된 경우** | 보류, 영향 낮음 | confirm 이 타임아웃으로 throw 했는데 Toss 쪽은 승인된 경우, `tossConfirmed=false` 라 Toss cancel 없이 Qoin 만 롤백된다. Q=0 에서도 (주문 없이 승인 잔존) 같은 위험이 기존에 있으며 Q>0 에서만 새로 생기는 위험은 아니다. 다만 Q>0 이면 "Qoin 은 복구 + 카드는 승인 잔존" 이라 고객 영향이 같은 방향. 기존 결제 결과 불명 처리 전반의 후속으로 분리 권장 |
| H-D | **admin 정책 편집/이력 화면** 없음 | 보류(후속) | 운영은 callable 직접 호출 또는 Console. 신규 `field` 3종이 `QoinRateField.fromCode` 에 걸러져 admin 이력 화면에 안 나타남 (Firestore 에는 남음). 이력 누락이 아닌 표시 누락 |
| H-E | **실기기 확인 불가 항목** | 보류 | 숫자 키보드, 키보드가 섹션을 가리지 않는지(`ensureVisible`), **실제 Toss 최소 승인금액 대 `minCashFloor` 300원** 은 자동화 불가. 후자는 `spendEnabled` 를 켜기 전 필수 사전 확인 (배포 순서 1단계) |
| H-F | **전역 `enabled=false` 중 환불된 사용분** | 보류(운영 규칙) | 재개 후 수동 복구 필요, 소급 복원 도구 없음. 이슈 문서로 목록은 남는다. 비상정지 절차(`operations`)에 "복구 쿼리" 한 줄을 추가하면 좋다 |

## 6. 우선순위 제안

FAIL 이 없으므로 수정 필수 항목은 없다. 권고 순서:
1. (켜기 전) 토스 최소 승인금액 확인 후 `minCashFloor` 확정 — H-E.
2. (켜기 전) 점주 화면의 '할인' 행 표기/매출 정의 결정 — H-A.
3. (운영 시작 후) 고아 예약 점검 쿼리 정기 실행 — H-B.
4. (별도 task) 에뮬레이터 기존 실패 3건(CH16 earn(브랜드), Q1, CF7) 수정 — spend 와 무관한 기존 부채.
5. (후속) admin 정책/이력 화면 — H-D.

## 7. 검증하지 못한 것

- UI 의 픽셀·간격 비교(design §2~§5)는 위젯 테스트(`qoin_spend_checkout_test` 14건 통과)와 코드 확인까지만 했다. 실기기 렌더링·접근성 읽기 순서는 H-E 와 함께 실기기 확인 필요.
- 골든 계약의 "한쪽만 바꾸면 깨진다"는 구조 확인이며 실제 변조 실험은 하지 않았다 (수정 금지).
