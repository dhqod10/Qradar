# temporary_closed_gate 기능 명세

## 개요

- **목적**: 점주 운영폼의 "임시 휴업"(`temporaryClosed`) 스위치가 실제로 판매를 막게 한다. 현재 이 필드는 저장만 되고 **어디서도 읽히지 않는 no-op** 이다(백로그 PSA-N6, payment_server_authority spec §6.8). 사용자 확정안 **C안** = `temporaryClosed` 가 실제로 판매를 막는다.
- **작업 유형**: 기존 기능 수정(no-op 필드를 판매 게이트에 연결) + 소규모 신규(거절 사유코드·점주 가드).
- **영향 범위**:
  - **화면**: 손님 매장 상세(`customer/order/store`), 손님 카트/결제 실패 화면, 점주 운영폼(`owner/my_store/store_operation_form_page.dart`)
  - **Domain**: `checkout_validation.dart`(`StoreSellabilityInput`, `StoreViolation`), `payment_failure.dart`(사유 enum), (선택) 활성 주문 조회 UseCase
  - **Data**: `checkout_validation_remote_data_source.dart`(`RawStoreFields`), 주문 조회(활성 주문)
  - **core/utils**: `store_sellability.dart`(Dart 판정) — **한 사실에 하나** 로 TS 와 동기
  - **functions**: `storeSellability.ts`(TS 판정), `paymentGate.ts`(거절 사유), `migrateStoreApprovalMeta.ts`(signature 영향)
  - **Presentation(copy)**: `payment_failure_copy.dart`(gate 사유 copy)
  - **교차 골든**: `test_fixtures/store_sellability_contract.json` + Dart/TS 두 하네스
  - **라우팅**: 변경 없음
  - **권한 / 환경 설정**: **Firestore Rules 변경 없음**(§영향 범위 상세 참고). 배포 시 `PAYMENT_GATE_MODE=enforce` 전제.
- **비범위**:
  - `businessHours` 기반 영업/마감 자동 판정(`_OpenStatusText` 는 표시 전용) — 손대지 않는다.
  - `temporaryClosed` 변경 이력(설정 변경 이력) 신설 — **남기지 않는다**(사유는 §이력/감사 추적).
  - 손님 홈/목록에서 휴업 매장 **숨김**(노출 필터) — 노출("보여줄까")은 판매("돈 받을까")와 다르다(spec §6.3 / §12 사실 1). 휴업 매장은 계속 보이되 "임시 휴업중" 으로 표시한다.
  - 진행 중 주문의 자동 취소/강제 종료 — 하지 않는다. 가드는 "휴업 전환을 미룬다" 일 뿐이다.
  - 휴업 전환 가드의 **서버 권위 집행**(CF 콜러블/트리거) — 테스트 기간엔 클라 가드로 충분(§가드 결정 참고).

---

## 배경 (검증 완료 — 재조사 불필요)

- `temporaryClosed` 는 `StoreEntity`/`StoreModel` 에 이미 있고, 점주 운영폼(`store_operation_form_page.dart` 의 `_TemporaryClosedToggle`)에서 토글·저장된다. **운영 필드 update 화이트리스트에 이미 포함**(data_ownership §2.5) → Rules 변경 불필요.
- 판매 판정 `canSellNow({rawStatus, hasApprovedAt})` 는 **status+approvedAt 만** 본다.
  - Dart 소비처: `lib/domain/usecases/validate_checkout_use_case.dart:85`(결제 선검증)
  - TS 소비처: `functions/src/paymentGate.ts:191`(G1 매장 게이트), `functions/src/migrateStoreApprovalMeta.ts:74`(M1 ⓓ willBeRejected)
  - 교차 골든: `test_fixtures/store_sellability_contract.json`, 하네스 = `test/core/payment_authority_contract_test.dart` + `functions/test/paymentAuthority.test.mjs`(둘이 같은 json 을 읽는다).
- 현재 `temporaryClosed==true` 매장 **0건**(실측) → 마이그레이션/공지 불필요, 배포 즉시 꺼지는 매장 없음.
- `temporaryClosed` 는 `stores.status`(pending/approved/rejected)와 **직교**한다. status 전이가 아니므로 `entity_lifecycle.md §3` 다이어그램은 변하지 않는다(운영 필드 수정은 status 보존). role_flows §139 "매장 운영 필드 수정" 흐름 안에서 효과만 생긴다.

---

## 요구사항

### 기능 요구사항 (사용자 확정)

- [ ] **R1 서버 방어(핵심)**: 손님이 카트를 담은 뒤 매장이 휴업되면, 서버 결제 게이트(`paymentGate` G1)가 `temporaryClosed==true` 인 매장의 결제를 **거절**한다(품절 게이트와 같은 백스톱, Toss confirm 전이라 돈 이동 없음).
- [ ] **R2 새 거절 사유코드**: `STORE_TEMPORARILY_CLOSED` 를 `GateReason` 체계에 신설한다. 기존 `STORE_NOT_SELLABLE` 과 **세분화**(재사용 아님) — 사유 선택 근거는 §레이어 설계 D3.
- [ ] **R3 판정 단일화(한 사실에 하나)**: 판매 판정 로직에 `temporaryClosed` 를 반영하되 **Dart·TS 한 곳씩, 같은 규칙**으로 둔다. 교차 골든을 확장한다.
- [ ] **R4 클라 소비**: 손님 매장 화면에 "임시 휴업중" 상태를 표시하고, 결제 선검증(`validate_checkout`)이 휴업을 위반으로 잡는다. 결제 실패 화면에 `STORE_TEMPORARILY_CLOSED` 전용 copy 를 둔다.
- [ ] **R5 휴업 전환 가드**: 점주가 `temporaryClosed` 를 `false→true` 로 켜려 할 때, 그 매장에 **진행 중 주문**(status ∈ {paid, accepted, making, ready})이 있으면 **저장을 막고 안내**한다. 진행 중 주문이 끝나야 휴업 가능.

### UI 요구사항

- [ ] 손님 매장 상세 헤더: "임시 휴업중" 배지/문구(품절·매장상태 패턴 재사용).
- [ ] 점주 운영폼: 휴업 전환 차단 시 안내 다이얼로그(진행 중 주문 N건, "주문이 끝나면 휴업할 수 있어요").
- [ ] 결제 실패 화면: `STORE_TEMPORARILY_CLOSED` 전용 headline/body(`storeNotSellable` 레이아웃 재사용 + 휴업 맞춤 문구).
- [ ] 카트 결제 차단 스낵바: 기존 store 위반 스낵바 재사용(휴업 전용 문구는 designer 판단).

### 상태 요구사항

- [ ] loading: 가드의 활성 주문 조회 중 저장 버튼 busy.
- [ ] error: 활성 주문 조회 실패 시 — **막지 않고 저장 진행**(가드는 권위가 아니다. 서버 R1 이 백스톱). 단, 사용자가 직접 누른 동작이므로 조회 실패를 조용히 삼키지 않는 처리는 designer/ developer 판단.
- [ ] empty: 진행 중 주문 0건 → 정상 저장.

---

## 데이터 모델

### 필드 (기존 — 변경 없음)

- `stores/{id}.temporaryClosed: bool` (기본 false). 운영 필드. 점주/브랜드가 운영폼에서 토글. Rules 화이트리스트 기포함.

### 판정 입력 확장

- **`StoreSellabilityInput`**(`checkout_validation.dart`): `temporaryClosed: bool` 추가.
- **`RawStoreFields`**(`checkout_validation_remote_data_source.dart`): `temporaryClosed: bool` 추가 — `data['temporaryClosed'] as bool? ?? false` 로 **가공 전 원시 읽기**(기존 `approvedAt != null` 패턴과 동일. `StoreModel`/`EntityApprovalStatus.fromString` 경유 금지).

### 거절 사유

- **TS `GateReason`**: `"STORE_TEMPORARILY_CLOSED"` 추가. `GATE_HTTPS_CODE` 에 `failed-precondition`, `GATE_TEXT` 에 사람용 문장 추가. 메뉴 사유 아님(`MENU_REASONS` 불변, 토큰 `[STORE_TEMPORARILY_CLOSED]`).
- **Dart `PaymentFailureReason`**: `storeTemporarilyClosed('STORE_TEMPORARILY_CLOSED')` 추가. `isMenuReason` = false. 토큰 정규식(`[A-Z][A-Z0-9_]{2,39}`)은 그대로 매치(길이 24).

### 클라 위반 enum

- **`StoreViolation`**: `temporarilyClosed` 추가(현재 `{notSellable, notFound}`). 휴업과 "판매 불가(미승인 등)" 를 정직하게 구분하기 위함. 카트 스낵바 문구 분기는 designer 판단(생략 시 기존 generic 유지 가능).

---

## 레이어 설계

### D1. 판정 단일화 — core/utils + functions (R3, 한 사실에 하나)

판매 판정의 **진실은 한 곳**이어야 한다(Dart `store_sellability.dart` ↔ TS `storeSellability.ts`, 교차 골든 고정). `canSellNow` 는 bool 을 돌려주므로 "왜 false 인지"(미승인 vs 휴업)를 구분하지 못한다. R2(세분 사유코드)를 만족시키려면 **사유를 돌려주는 순수 함수 하나**를 둔다.

**신규 순수 함수 `storeGateReason`(Dart+TS, 같은 규칙):**

입력: `{ rawStatus: String?, hasApprovedAt: bool, temporaryClosed: bool }`
반환: `null`(판매 가능) | `STORE_NOT_SELLABLE` | `STORE_TEMPORARILY_CLOSED`

**우선순위(단일 장소에 고정):**
1. 기존 승인 판정(`rawStatus=='approved' || (rawStatus=='pending' && hasApprovedAt)`)이 **거짓** → `STORE_NOT_SELLABLE` (`temporaryClosed` 무시).
2. 아니면 `temporaryClosed==true` → `STORE_TEMPORARILY_CLOSED`.
3. 아니면 `null`.

**이유(이 우선순위의 근거)**: 미승인·미지값 매장은 지금도 `STORE_NOT_SELLABLE` 로 거절되는데, 그 거동과 골든 행의 결과를 **그대로 유지**한다. `STORE_TEMPORARILY_CLOSED` 는 "다른 조건이 모두 OK 인데 점주가 꺼둔" 경우에만 나온다 — 미지값 fail-closed 원칙(spec §8.1)도 그대로다.

**`canSellNow` 는 이 함수에서 파생**: `canSellNow(x) == (storeGateReason(x) == null)`. 기존 `canSellNow` 시그니처는 `temporaryClosed` 를 **추가 인자**로 받는다(필수). 호출처가 전부 바뀌므로 §영향 범위 호출처 참고.

> Dart `store_sellability.dart` 와 TS `storeSellability.ts` 는 **같은 규칙의 복제**다. 한쪽만 고치면 안 된다 — tester 가 두 파일의 동기와 골든 통과를 교차 검증한다.

### D2. 서버 게이트 — functions/src/paymentGate.ts (R1·R2)

`evaluatePaymentGate` G1 분기(현 191줄 `if (!canSellNow(...))`)를 **사유 분기**로 교체:

```
const reason = storeGateReason({ rawStatus, hasApprovedAt, temporaryClosed });
if (reason !== null) {
  return { ok:false, reason, menuItemIds:[], detail: emptyDetail({ rawStatus, hasApprovedAt }) };
}
```

- `temporaryClosed` 는 `store.temporaryClosed === true` 로 읽는다(원시, 비boolean/부재 → false).
- 거절 시 기존 경로대로 `verifyTossPayment` 가 `paymentGateRejections/{autoId}` 에 1건 기록(사유 = `STORE_TEMPORARILY_CLOSED`). **별도 로깅 코드 불필요** — GateReason 체계에 사유를 더하면 거절 이력이 자동으로 따라온다.
- `GateDetail` 에 `temporaryClosed` 를 실을지는 developer 판단(오탐 분석에 유용하면 추가; 필수 아님).

### D3. 거절 사유코드 — 세분화 결정 (R2)

`STORE_TEMPORARILY_CLOSED` 를 **신설(세분화)** 한다. `STORE_NOT_SELLABLE` 재사용 아님.

- 근거: 두 상황은 손님에게 **다른 사실**이다. 미승인/부재는 "이 매장에서 (당분간/영영) 주문 불가", 휴업은 "지금만 닫힘, 곧 다시 열림". 결제 실패 화면 copy 와 행동 유도(다른 매장 둘러보기 vs 잠시 후 재시도)가 달라야 한다.
- `GATE_TEXT`(사람용, 구앱/디버깅): 예 "지금은 매장이 잠시 휴업 중이에요. 잠시 후 다시 시도해주세요". 신앱 화면은 이 문자열을 그리지 않고 코드 상수(`payment_failure_copy.dart`)만 그린다(spec §15.1).
- HTTPS code = `failed-precondition`(`STORE_NOT_SELLABLE` 과 동일 계열).

### D4. 클라 선검증 — Domain/Data (R4)

- `checkout_validation_remote_data_source.fetchStore` 가 `temporaryClosed` 를 원시 읽어 `RawStoreFields` 에 싣고, `checkout_validation_repository_impl.fetchStoreFresh` 가 `StoreSellabilityInput.temporaryClosed` 로 전달.
- `validate_checkout_use_case._evaluate`: 현재 `if (!canSellNow(...)) return notSellable;` 를 `storeGateReason(...)` 분기로 바꿔 `STORE_NOT_SELLABLE→StoreViolation.notSellable`, `STORE_TEMPORARILY_CLOSED→StoreViolation.temporarilyClosed`. 선검증은 권위가 아니다(읽기 실패는 `CheckoutValidation.none`) — 기존 불변식 유지.

### D5. 결제 실패 화면 copy — Presentation (R4)

- `payment_failure_copy.dart` 의 `gateFailureCopy` switch 에 `storeTemporarilyClosed` case 추가(enum 추가 시 switch 가 컴파일 오류로 누락을 알린다 — 기존 주석대로). `storeNotSellable` 레이아웃(주 버튼 "카트로 돌아가기", 보조 "다른 매장 둘러보기") 재사용 + 휴업 맞춤 headline/body.
- `PaymentFailure.from` 은 토큰만 파싱하므로 추가 변경 없음(enum·정규식만).

### D6. 손님 매장 표시 — Presentation (R4)

- 매장 상세 헤더(`customer/order/store/widgets/store_menu_header.dart`, `_OpenStatusText` 근처)에 "임시 휴업중" 배지/문구. 데이터는 이미 `StoreEntity.temporaryClosed`.
- 범위: **표시 + 결제 차단(서버 R1 + 선검증 D4)** 이 in-scope. "담기 버튼 비활성화" 등 더 깊은 차단은 designer 권고(선택). 노출 필터(목록 숨김)는 비범위.

### D7. 휴업 전환 가드 — Presentation + Domain (R5) — §가드 결정 참고

- `store_operation_form_page.dart._submit`: `_temporaryClosed==true` **그리고** `widget.existing.temporaryClosed==false`(전환)일 때만, 저장 직전 **활성 주문 1회 조회**. 있으면 저장 중단 + 안내 다이얼로그(`_confirmAllOff` 패턴 재사용). 없으면 진행.
- 조회: 활성 주문 = `where('storeId') + where('status', whereIn:[paid,accepted,making,ready])` 1회 `get`. 쿼리·복합 인덱스(storeId+status+createdAt)·Rules(`isStoreOwner`) 모두 기존 `streamPaidByStore` 로 존재. **stream 아닌 one-shot** 용 메서드(`fetchActiveOrders`/`hasActiveOrders(storeId)`)를 `OrderRemoteDataSource`/repository/UseCase 에 추가(developer).
- 브랜드 가맹점 운영폼(`owner/brand_store/**`)에서 동일 토글이 가능하면 같은 가드 적용 여부 확인(현재 운영폼은 `store_operation_form_page` 단일 — developer 가 브랜드 분기 존재 시 동일 처리).

---

## 가드(R5) 집행 위치 결정 — 클라 사전확인 (설계 결정)

사용자 요구 4의 "어디서 집행하나" 에 대한 architect 결정과 근거.

| 방식 | 판정 |
|---|---|
| **클라 사전확인(채택)** | 운영폼 저장 직전 활성 주문 조회 후 차단 + 안내. |
| Rules 집행 | **불가** — Rules 는 다른 컬렉션(`orders`)을 쿼리할 수 없다(단건 `get` 만, 집합 판정 불가). |
| CF 콜러블로 토글 이전 | 과설계. `temporaryClosed` 는 운영 필드 묶음(phone/hours/notice/closedDates…)과 **한 update** 로 저장된다. 이 하나만 CF 로 떼면 저장 경로가 쪼개지고 이력 요구도 없다. |
| 트리거 보정 | 사후 교정(이미 휴업된 뒤 되돌리기)은 UX 가 더 나쁘다. |

**핵심 근거**: R5 가드를 우회했을 때의 피해는 **돈·보안이 아니라 "진행 중 주문이 있는데 매장이 닫힌 것처럼 보임"** 이라는 운영 불편뿐이다. **진짜 백스톱은 서버 R1**(`temporaryClosed` 면 신규 결제 거절)이고 그건 권위로 집행된다. 가드는 점주 편의를 위한 사전 안내다.

**수용되는 틈(spec 에 명시)**:
- 조회와 토글 사이에 새 주문이 들어올 수 있다(TOCTOU). 수용 — 토글은 **기존 진행 중 주문을 취소하지 않고**, 서버는 그 시점 이후 신규 결제만 막는다. 되돌리기는 점주가 다시 끄면 된다.
- 조회 실패 시 **막지 않고 저장**(가드는 권위 아님). 서버 R1 이 백스톱.

---

## 데이터 흐름

```text
[손님 결제]
Cart/Checkout → ValidateCheckoutUseCase → CheckoutValidationRepository → RemoteDataSource(원시 temporaryClosed 읽기)
  → storeGateReason(rawStatus,hasApprovedAt,temporaryClosed)  // 선검증(권위 아님)
그리고 서버:
verifyTossPayment → evaluatePaymentGate(G1) → storeGateReason  // 권위, confirm 전 거절 → paymentGateRejections 1건

[점주 휴업 전환]
StoreOperationFormPage._submit(temporaryClosed false→true)
  → (활성 주문 1회 조회) → 있으면 다이얼로그 차단 / 없으면
  → UpdateStoreOperationFieldsUseCase → stores.update(운영 필드 묶음)
```

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| 서버 게이트 `temporaryClosed==true` | confirm 전 거절 + `STORE_TEMPORARILY_CLOSED` + `paymentGateRejections` 1건 |
| 선검증 매장 읽기 실패/타임아웃 | `CheckoutValidation.none`(막지 않음) — 서버가 백스톱 |
| 가드 활성 주문 조회 실패 | 막지 않고 저장 진행(권위 아님). 서버 R1 백스톱 |
| 가드: 진행 중 주문 존재 | 저장 중단 + 안내 다이얼로그(건수·"주문이 끝나면 휴업 가능") |
| 모르는 사유 토큰 | 기존대로 `PaymentFailureReason.unknown`→갈래 C(변경 없음) |

---

## 이력 / 감사 추적 (audit_trail §4 체크리스트)

1. **돈·권한·정책 값을 바꾸는가?** → `temporaryClosed` 는 "지금 판매하는가" 라는 **운영 상태**다. 점주가 수시로 켜고 끄는 가역 토글로, Qoin 적립률 같은 **정책 값(돈의 계수)** 도, `users.brandId` 같은 **권한 값(자원 트리 쓰기 권한)** 도 아니다. 성격상 `soldOut`·`businessHours`·`isOpen`(변경 이력 없음)과 **동급의 운영 필드**이며, audit_trail A2("매장 운영 정보 변경 이력 — 미설계")에 속한다. → **설정 변경 이력을 남기지 않는다.** (단, 판매를 막는 효과가 생기므로 이 판단을 여기 명시한다.)
2. **덮어쓰기로 사라지는 값?** → 이전 토글값의 보존 필요성 낮음(운영 상태). 수용.
3. **거래/기록이 정책 값을 참조만?** → 해당 없음. `temporaryClosed` 는 금액·적립 계산에 들어가지 않는다.
4. **"누가"?** → 거절 발생은 `paymentGateRejections` 에 남는다(거절 이력). 토글 행위자 기록은 위 1 사유로 생략.
5. **batch?** → 없음(단건 운영 update).
6. **CF 로그 의존?** → 아니다. 거절은 Firestore `paymentGateRejections` 에 영구 기록(기존 경로).
7. **권한 판정 필드의 create/update 교차?** → `temporaryClosed` 는 권한 판정 입력이 아니다(판매 게이트 입력일 뿐 Rules 권한과 무관). create 경로에서도 임의 bool 은 피해가 없다(0건 실측, fail 방향은 false). Rules 가드 추가 불필요.

> 자주 놓치는 혼동 방지: 여기엔 **거절 이력**(`paymentGateRejections`)만 있고 **설정 변경 이력**은 의도적으로 없다. 둘은 다르며, 위 1 에서 없음 사유를 명시했다.

---

## 교차 골든 갱신 범위 (R3 — 반드시)

`test_fixtures/store_sellability_contract.json` 과 **두 하네스**(Dart `payment_authority_contract_test.dart`, TS `paymentAuthority.test.mjs`)를 함께 바꾼다. 둘이 같은 json 을 읽어야 "한 사실에 하나" 가 유지된다.

- **스키마 확장**: 각 케이스에 `temporaryClosed`(bool) 입력과 `expectReason`(`null`|`STORE_NOT_SELLABLE`|`STORE_TEMPORARILY_CLOSED`) 를 추가. 기존 `expect`(bool)는 `expectReason==null` 과 동치로 유지(또는 `expect` 제거하고 reason 으로 통일 — developer/tester 합의).
- **기존 11행**: `temporaryClosed:false` 를 더하고 `expectReason` 부여(true→null, false→STORE_NOT_SELLABLE). 결과 불변.
- **신규 행(최소)**:
  - approved + temporaryClosed:true → reason `STORE_TEMPORARILY_CLOSED`, canSell=false
  - approved(approvedAt 없음 legacy) + temporaryClosed:true → `STORE_TEMPORARILY_CLOSED`
  - pending + approvedAt + temporaryClosed:true → `STORE_TEMPORARILY_CLOSED`
  - pending 단독 + temporaryClosed:true → `STORE_NOT_SELLABLE`(승인 문제가 우선)
  - null(status 부재) + temporaryClosed:true → `STORE_NOT_SELLABLE`
- **하네스 변경**: 두 하네스가 `storeGateReason`(와 파생 `canSellNow`)을 `temporaryClosed` 입력과 함께 호출하고 `expectReason`/`expect` 둘 다 단언.

---

## 영향 범위 — canSellNow 호출처 전수 (signature 변경)

`canSellNow` 에 `temporaryClosed` 필수 인자가 추가되므로 아래가 전부 수정 대상이다.

| 위치 | 처리 |
|---|---|
| `functions/src/paymentGate.ts:191` | `storeGateReason` 로 교체(§D2) — `temporaryClosed` 전달 |
| `functions/src/migrateStoreApprovalMeta.ts:74` (M1 ⓓ willBeRejected) | **`temporaryClosed:false` 로 호출**(승인 전용 판정). 의도적 휴업 매장을 "마이그레이션 이상치" 로 오분류하지 않기 위함. 현재 0건이라 무영향이나 명시한다 |
| `lib/domain/usecases/validate_checkout_use_case.dart:85` | `storeGateReason` 분기(§D4) — `StoreSellabilityInput.temporaryClosed` 전달 |
| Dart/TS 테스트(`payment_authority_contract_test.dart`, `paymentAuthority.test.mjs`, `authorityCallables.test.mjs`) | 골든/호출 인자 갱신 |

Rules: **변경 없음**(`temporaryClosed` 운영 필드 화이트리스트 기포함; owner 의 `orders` where(storeId) 읽기 기허용).

---

## 작업 분배

### designer (필요 — 최소)

- UI 변경: (a) 손님 매장 상세 "임시 휴업중" 배지/문구(품절·매장상태 패턴 재사용), (b) 점주 휴업 전환 차단 다이얼로그 copy/레이아웃(`_confirmAllOff` 패턴 재사용), (c) 결제 실패 화면 `STORE_TEMPORARILY_CLOSED` copy(`storeNotSellable` 레이아웃 재사용 + 휴업 문구), (d) 카트 store 위반 스낵바 휴업 문구 분기 여부.
- 산출물: `docs/tasks/temporary_closed_gate/design.md`.
- 전달: AppColors 만, 신규 컴포넌트 지양. "담기 버튼 비활성화" 깊이는 designer 권고로 판단(기본은 표시 + 결제 차단).

### developer

- 구현: §D1~D7 전부. 순서 권장 — D1(판정 단일화·Dart/TS) → 골든 확장 → D2(서버 게이트) → D4/D5/D6(클라) → D7(가드).
- 재사용: `storeNotSellable` copy 레이아웃, `_confirmAllOff` 다이얼로그, `streamPaidByStore` 쿼리/인덱스(one-shot 변형 추가), 원시 읽기 패턴(`approvedAt != null`).
- 레이어 규칙: Firebase 는 data 레이어에서만. `store_sellability.dart` 는 순수 Dart(외부 SDK import 금지). **Dart·TS 판정 동기 필수.** 색상 `AppColors` 만.
- 산출물: `docs/tasks/temporary_closed_gate/implementation.md`.
- 빌드: `dart run build_runner build --delete-conflicting-outputs`(entity 필드 추가 시 freezed 재생성), `flutter analyze`, `flutter test`, functions `npm test`/`tsc`.

### tester

- 검증:
  - `storeGateReason` Dart·TS **동일 규칙**(두 파일 교차) + 교차 골든 두 하네스 통과(신규 행 포함).
  - 서버 게이트: `temporaryClosed==true` 면 `STORE_TEMPORARILY_CLOSED` 거절 + `paymentGateRejections` 1건, Toss confirm 미호출(단위 테스트).
  - 우선순위: pending-only + temporaryClosed → `STORE_NOT_SELLABLE`(승인 문제 우선), approved + temporaryClosed → `STORE_TEMPORARILY_CLOSED`.
  - 선검증: 읽기 실패 시 막지 않음(권위 아님) 불변식 유지.
  - 가드: 진행 중 주문(paid/accepted/making/ready) 있으면 토글 차단, completed/cancelled/refunded 만 있으면 허용, 조회 실패 시 저장 진행.
  - 결제 실패 화면: `STORE_TEMPORARILY_CLOSED` 전용 copy 렌더, switch 누락 없음.
  - Rules 무변경 회귀(`temporaryClosed` 운영 update 여전히 통과, 승인 메타·Qoin 보호 불변).
- 예외 케이스: 비boolean/부재 `temporaryClosed`→false, 대문자/공백 status + temporaryClosed 조합(fail-closed 유지), 토큰 길이.
- 산출물: `docs/tasks/temporary_closed_gate/test_report.md`.

---

## 배포 영향 (사용자 조치)

- **functions 재배포**: `storeSellability.ts`(판정), `paymentGate.ts`(사유), `migrateStoreApprovalMeta.ts`(signature).
- **앱 재빌드**: 클라 선검증·copy·가드·enum.
- **게이트 모드**: 서버 거절이 실제로 걸리려면 `PAYMENT_GATE_MODE=enforce`(operations.md §6). `shadow` 면 기록만, `off` 면 평가 안 함.
- **Rules 배포 불필요**(변경 없음). 마이그레이션 불필요(0건).

---

## 완료 기준

- [ ] R1~R5 모두 구현 또는 보류 사유 명시.
- [ ] `store_sellability.dart` ↔ `storeSellability.ts` 판정 규칙 동기 확인.
- [ ] 교차 골든(json + Dart/TS 하네스) 확장·통과.
- [ ] `STORE_TEMPORARILY_CLOSED` 서버 거절 + 클라 copy 동작.
- [ ] 휴업 전환 가드(진행 중 주문) 동작, 수용 틈 명시.
- [ ] `design.md` 작성 완료.
- [ ] `implementation.md` 작성 완료.
- [ ] `test_report.md` 작성 완료, FAIL 없음(또는 후속 분리).
- [ ] 이력/감사 §4 6항목 통과(설정 변경 이력 미기록 사유 명시 포함).
