# 결제 금액의 서버 권위화 (payment_price_authority) 기능 명세

- 선행 task: `docs/tasks/payment_server_authority/` (2026-10-27 운영 배포 완료). **이 task 는 그 spec §21 의 N1 이다.**
- 이 spec 은 선행 task 의 §7.2(읽기 경로) · §8(fail 방향) · §15.1(거절 토큰) · §17.0(게이트 모드) · §6.7(create·update 교차) 을 **잇는다**. 같은 규칙을 다시 정하지 않는다.
- 작성 2026-10-27.

---

## 0. 개요

- **목적**: `verifyTossPayment` 가 결제 금액을 **클라이언트 선언값이 아니라 Firestore 문서에서 다시 계산**하게 한다. 지금은 클라이언트가 보낸 두 값을 서로 비교하므로 금액 검증이 존재하지 않는다.
- **작업 유형**: 기존 기능 수정 (보안 결함 수정) + 신규 판정 함수 2개 + 신규 감사 도구 1개
- **구멍의 크기**: 스크립트로 callable 을 직접 호출해 `amount: 1`, `cart.totalPrice: 1`, `cart.items` 에 17,000원어치를 담으면 **1원이 실제 결제되고 17,000원짜리 주문이 생성**된다. 점주에게는 정상 결제로 보인다.
- **억제력이 없다**: 선행 4건의 억제력은 "자기 돈으로 실제 결제를 해야 한다" 였다. 이번은 **1원이면 된다.** 이것이 N1 을 선행 묶음 직후 최우선으로 둔 이유다.

### 영향 범위

| 영역 | 내용 |
|---|---|
| 화면 | 결제 실패 화면(`payment_result_page.dart`) 사유 2종 추가 · 체크아웃 진입 시 **카트 재가격** 표시 · 카트 합계 |
| Domain | `lib/core/utils/cart_pricing.dart`(신규, 순수) · `lib/core/utils/option_availability.dart`(신규, 기존 구현 **추출**) · `ValidateCheckoutUseCase` 반환 확장 · `CheckoutValidation` 확장 |
| Data | `option_repository_impl.dart` 가 추출된 함수를 호출하게 변경(동작 동일) · `CheckoutValidationRepository` 가 옵션 그룹까지 읽게 확장 · `menu_override_model.dart:52` 비방어 cast 수정 · `payment_gateway_repository_impl.dart` cart 직렬화 |
| Presentation | `checkout_page.dart`(재가격) · `cart_page.dart`(가격 변동 표시) · `menu_item_detail_page.dart`(담기 금액 계산을 공용 함수로) · `PaymentFailure` 사유 2종 |
| Cloud Functions | `verifyTossPayment.ts`(재계산 삽입) · `optionPricing.ts`(신규) · `cartPricing.ts`(신규) · `menuVisibility.ts`(`MergedMenu` 확장) · `paymentGate.ts`(`ResolvedMenu` 소비) · `orderBuilder.ts`(서버 값으로 주문 구성 + 타입 거짓 수정) · `auditOrderPriceIntegrity.ts`(신규, 임시) · `onMenuPriceWritten.ts`(신규, 가격 이력 트리거 — R16) |
| Firebase | **Rules 변경 2건 확정** — ⓐ `menuOverrides` create·update 의 승인 메타 금지(§13-8 🔴) ⓑ `priceHistory` 읽기 전용 1줄(Q7=ⓐ, R16) · 신규 트리거 `onMenuPriceWritten` · 인덱스 변경 없음 · **데이터 마이그레이션 없음** |
| 권한 / 환경 | `PAYMENT_PRICE_MODE` 신규 param (Q3) |
| 테스트 | 교차 골든 2종 신규 · grep 가드 5항목 신규 · functions 단위 · Rules 하네스 회귀 |

### 비범위 (이번 작업에서 제외)

| 제외 | 사유 |
|---|---|
| **Qoin 차감(사용)** | **기능 자체가 존재하지 않는다**(§1-4). 지금 설계할 대상이 없다. 도입 시 건드려야 할 4곳을 §1-4 에 적어 둔다 |
| 쿠폰 / 프로모션 / 비율 할인 | `discount` 에 값이 들어가는 경로가 0개다(§1-3) |
| 가격 승인 정책 자체의 재설계 | §4-4 가 우회로를 지적하고 Q8 로 올린다. 이 task 는 "클라 선언을 문서로 바꾼다" 까지다 |
| `temporaryClosed`(N6) · 매장 status 전이 이력(N3) | 선행 spec 이 등재한 별 과제 |
| 소급 **교정**(과거 주문의 금액을 고치는 것) | 탐지만 한다. 교정은 환불·정산 경로를 건드리므로 별 과제 |
| 옵션 그룹의 `minSelect`/`maxSelect` 도입 | 필드가 없다(§1-2). `required` + `single` 만 검증한다 |

---

## 1. 출발점 사실 (조사 완료 — 재조사하지 말고 여기서 출발한다)

> ⚠️ **선행 spec §21 의 N1 설명("추가 읽기 0 으로 닫을 수 있다")은 절반만 맞다.** 아래 1-2 가 그 가정을 수정한다. 이 수정이 이 task 의 범위를 가르는 사실이다.

### 1-1. 현재 금액 검증의 전부

| 위치 | 비교 | 문제 |
|---|---|---|
| `verifyTossPayment.ts:124` | `data.amount !== data.cart.totalPrice` | **둘 다 클라이언트 값**이다. 자기 자신과 비교한다 |
| `verifyTossPayment.ts:225` | `tossResponse.totalAmount === data.amount` | Toss **승인액 vs 클라 요청액**. "요청한 만큼 승인됐나" 만 본다 |

메뉴 문서 기준 단가 조회는 **0건**이다. `orderBuilder.ts:57,59,84` 는 cart 값을 그대로 복사한다.

**다만 정확히 하자**: `amount == cart.totalPrice` 와 `toss.totalAmount == amount` 가 묶여 있으므로 **`orders.totalPrice` 는 실제 승인액에 고정된다.** 따라서 "결제는 적게 하고 `totalPrice` 만 크게 적어 Qoin 을 많이 받는" 경로는 **이미 막혀 있다**(적립은 `floor(order.totalPrice × rate)`, `onOrderQoinSettled.ts:219,287`). 열려 있는 것은 **`items[]` 의 가치가 지불액과 무관하다**는 것, 즉 ⓐ 점주가 1원 받고 17,000원어치를 내주는 것 ⓑ `items[].lineTotal`·`unitPriceWithOptions` 가 점주 화면·매출 집계(`owner_sales_page`)에 거짓으로 들어가는 것이다.

### 1-2. 옵션 단가는 메뉴 문서에 **없다** (N1 가정 수정)

- 메뉴 문서는 **참조만** 들고 있다: `optionGroupRefs: [{scope, id}]` + `optionGroupRefIds: [id]` (`lib/data/models/menu_item_model.dart:91-97,197-203`).
- 옵션 그룹 문서는 **별도 컬렉션 3곳**에 산다 (`lib/core/constants/firestore_paths.dart:57-87`):
  `optionGroups/{id}`(글로벌·master) · `brands/{b}/optionGroups/{id}` · `stores/{s}/optionGroups/{id}`
- `priceDelta` 는 그 **그룹 문서의 `items` 배열 요소의 필드**다 (`option_item_model.dart:19`: `(map['priceDelta'] as num?)?.toInt() ?? 0`). **음수가 정상 값**이다(텀블러 −300, 시드 `phase1_seed_data.dart:196-234`).

→ **`basePrice` 는 추가 읽기 0 으로 얻는다**(G2 가 이미 읽은 문서에 있다). **옵션 단가는 추가 읽기가 필요하다**(§6 에서 비용 계산). 이것이 Q1 의 내용이다.

### 1-3. 클라이언트 금액 계산의 전부

| 값 | 계산 위치 | 식 |
|---|---|---|
| `unitPriceWithOptions` | `menu_item_detail_page.dart:685-710` | `basePrice + Σ priceDelta(선택 항목)` — `basePrice` 는 **이미 override 적용된 값** |
| `lineTotal` | 같은 곳 `:709` / `cart_local_data_source.dart:57,86` | `unitPriceWithOptions × quantity` |
| `subtotal` | `cart_local_data_source.dart:123-129` | `Σ lineTotal` |
| `discount` | `payment_gateway_repository_impl.dart:184` | **리터럴 `null`.** `CartEntity` 에 필드 자체가 없다 |
| `totalPrice` | 같은 곳 `:185` | **`cart.subtotal` 과 항상 동일** |
| `amount` | `checkout_page.dart:63` | `cart.subtotal`. 같은 값이 Toss 실행(`:91`)과 verify(`:132`) 양쪽에 간다 |

- 금액은 **전부 `int`(원 단위)**. 결제 경로에 double·반올림이 들어가는 지점이 **없다**. 따라서 **허용 오차를 둘 기술적 근거가 없다**(Q2 는 기술이 아니라 시점 문제다).
- 재계산에 필요한 최소 입력은 `storeId` + item 별 `menuItemId`, `quantity`, `selectedOptions[].{groupId, itemId}` 다. 나머지는 서버가 전부 복원할 수 있다.
- **별도 경로 1개**: 홈 "다시 주문" 이 과거 `orderLogs.lineTotal` 에서 단가를 **역산**한다 (`quick_reorder_section.dart:406-411`, `lineTotal ~/ quantity`). 현재 메뉴 가격을 읽지 않는다 → **가격이 바뀐 뒤 재주문하면 재계산과 어긋난다.** 선행 spec N5 가 이것이다. §11 이 처리 방식을 정한다.

### 1-4. Qoin 차감은 **존재하지 않는다**

요구사항 2("Qoin 차감을 재계산식에 넣어라")는 **전제가 성립하지 않는다.** 근거:

- `QoinTransactionType` 은 `earn`, `clawback` 둘뿐 (`lib/domain/entities/qoin_transaction_type.dart`).
- `QoinRepository` 에 **쓰기 메서드가 없다** (`lib/domain/repositories/qoin_repository.dart:4-17` — "원장은 Cloud Function 전용").
- 고객 화면이 **명시적으로 "준비 중"** 이라고 적어 둔다 (`qoin_balance_card.dart:283-301`, 탭 핸들러 없음).
- `lib/presentation/customer/checkout` · `cart` 에 `qoin` 문자열 0건. `verifyTossPayment` payload 에 Qoin 필드 0건.
- `redeem`/`deduct`/`qoinUsed`/`useQoin`/`spendQoin`/`pointsUsed` 전부 0건 (`lib/`, `functions/src/`, `firestore.rules`).

**도입 시 동시에 건드려야 하는 4곳** — 지금 적어 둔다:
`CartEntity`(또는 체크아웃 상태) → `cartToMap` → `CONSUMED_CART_KEYS` → `test_fixtures/qoin_cart_contract.json`.
그리고 **그때 반드시 지킬 것**: 잔액은 `users/{uid}.qoinBalance` 이고 원장은 CF 전용 append-only 다. **클라이언트가 선언한 사용액·잔액을 믿으면 안 되고**, 차감은 `verifyTossPayment` 트랜잭션 안에서 잔액을 읽어 검증해야 한다. 재계산식은 `expected = Σ lineTotal − qoinUsed` 로 확장되며, `qoinUsed ≤ 잔액` 과 `qoinUsed ≤ Σ lineTotal` 을 서버가 검증한다. **이 문장은 설계가 아니라 미래 설계자에게 남기는 제약이다.**

### 1-5. 서버 TS 타입이 런타임과 다르다 (재계산이 바로 걸리는 함정)

클라이언트가 실제로 보내는 옵션 키는 **`groupId / groupName / itemId / label / priceDelta`** 다 (`payment_gateway_repository_impl.dart:199-207`). `orderBuilder.ts:18-24` 의 `OrderItem.selectedOptions` 는 `optionGroupId / optionGroupName / optionId / optionName` 으로 선언돼 있다 — **런타임과 불일치한 거짓 타입**이다. `buildOrderData` 가 `items` 를 그대로 통과시키므로 지금까지 드러나지 않았다(저장·읽기 양쪽 모두 `groupId/itemId`: `order_item_model.dart:68-78,88-95`).

- → **재계산을 `optionGroupId`/`optionId` 로 키잉하면 전부 `undefined` 가 된다.** R7 이 이것을 고정한다.
- 같은 계열: 클라이언트는 `imageUrl` 을 **보내지 않는다**(`_cartItemToMapStatic` 키 6개). `orderBuilder.ts:16` 의 `imageUrl: string` 도 거짓이다.

### 1-6. 옵션 선택 가능 판정의 현재 유일 구현

`option_repository_impl.dart:36-82` — 데이터 레이어 **Repository 구현 안에** 있다.

1. `ref.scope` 로 master / brand(`menuItem.brandId`) / store(`menuItem.storeId`) 중 한 곳에서 그룹을 읽는다
2. `g.active == false` 그룹 제외
3. `disabledGroupIds.contains(group.id)` → 그룹 통째 제외
4. 항목은 **composite 키 `"{groupId}_{itemId}"`** 로 `disabledItemIds` 와 매칭해 제외

`disabledOptionGroupIds`/`disabledOptionItemIds` 는 `applyOverrideForCustomer` 가 **운영 필드로 status 무관 즉시** 복사한 값이다(`store_menu_visibility.dart:35-42`). 제약 필드는 `selectionType ∈ {single, multi}` 와 `required: bool` **뿐**이고 수량 상한은 없다.

⚠️ **필터는 표시·담기 시점에만 걸린다.** 카트에 담긴 뒤 옵션이 disabled 로 바뀌어도 그 라인은 결제까지 간다. 선검증은 `menuItemIds` 만 본다(`checkout_page.dart:76-80`).

### 1-7. 금액 파싱의 비대칭 1건

`menu_override_model.dart:52` 가 `priceOverride: data['priceOverride'] as int?` — **`toInt()` 가 아니라 직접 cast** 다. 전 코드베이스에서 유일한 비방어 금액 cast 다. Firestore 에 double 이 들어 있으면 Dart 는 **예외**, TS `asPrice` 는 `Math.trunc` 로 **통과** → 같은 문서를 두 쪽이 다르게 읽는다. R10 이 고친다.

---

## 2. 설계 원칙 (선행 task 에서 실제로 사고가 난 지점)

1. **검사와 실행이 같은 경계에 있어야 한다.** 금액 권위 지점은 Toss confirm **직전** 1곳이다. 선검증·카트 표시는 권위가 아니다.
2. **클라이언트가 선언한 값을 권위로 삼지 않는다.** `CartItemEntity` 에 신뢰 필드를 추가하지 않는다(선행 F1 판단). 서버는 **문서에서 다시 만든다.**
3. **한 사실에는 판정 함수 하나 + 표면 인벤토리 표 + grep 가드.** 표를 만들어도 **행을 빠뜨리면 보호받지 못한다** — 선행 task 에서 FAIL 이 세 번 그렇게 났다. 각 행에 ⓐ 판정 출처 ⓑ **출처 읽기 실패 시 보이는 것** ⓒ 복구 동작을 채운다(§14).
4. **`allow create` 는 `onlyChangedFields` 같은 update 전용 장치의 보호를 받지 않는다.** 같은 패턴으로 네 번 구멍이 났다. 판정 입력 필드는 **주체 × 행위 × 상태 전이** 단위로 교차 확인한다(§13-7).
5. **게이트는 "켜졌는지" 를 양성 대조로 증명한다.** 선행 배포에서 가장 값진 단계는 `shadow` 기록 1건을 일부러 만든 ⑥-b 와 거절 1건을 유도한 ⑥-c 였다. 같은 장치를 이번에도 넣는다(§18, §19-4).
6. **fail 방향은 "그 실패가 누구에게서 무엇을 빼앗는가" 로 정한다.** 가격 불일치로 거절하면 **돈이 멈춘다.** 선행 §8.1 을 잇는다(§7).
7. **새 판정 함수를 만들지 않는다 — 기존 구현을 추출하고 포팅한다.** 가격에도 같은 규칙이 있다: `priceOverride` 는 `status == approved` 일 때만 적용되고(핵심 필드), `disabledOption*` 은 status 무관 즉시 적용된다(운영 필드). 이 분기는 `applyOverrideForCustomer` 하나에만 있어야 한다.

---

## 3. 요구사항

### 기능 요구사항

- [ ] **R1** `verifyTossPayment` 가 Toss confirm **전에** 카트 금액을 Firestore 문서에서 재계산하고, 불일치면 confirm 을 호출하지 않고 거절한다.
- [ ] **R2** 재계산은 `basePrice` 를 **G2 가 이미 읽은 문서에서** 얻는다(추가 읽기 0). `MergedMenu`/`ResolvedMenu` 를 소비하고 메뉴 문서를 다시 읽지 않는다.
- [ ] **R3** 옵션 단가를 서버가 재계산한다 (**Q1=ⓐ 확정 — 전체 재계산**). 옵션 그룹 문서 읽기는 `getAll` **1 round-trip** 으로 묶고 (scope, groupId) 로 중복 제거한다.
- [ ] **R4** 옵션 선택의 유효성을 서버가 검증한다: ⓐ 선택한 그룹이 그 메뉴의 `optionGroupRefs` 에 있다 ⓑ 선택한 `itemId` 가 그 그룹의 `items` 에 있다 ⓒ `active=false` 그룹·`disabled*` 그룹·항목이 선택되지 않았다 ⓓ `required` 그룹에 1개 이상 선택됐다 ⓔ `single` 그룹에 2개 이상 선택되지 않았다.
- [ ] **R5** 금액 판정 함수는 **순수 함수**이고 Firestore 에 의존하지 않는다. 거절 경로에서 **Toss confirm 이 호출되지 않음**을 단위 테스트로 단언한다(선행 R5 패턴).
- [ ] **R6** 옵션 선택 가능 판정을 `option_repository_impl.dart` 에서 **순수 함수로 추출**하고(`lib/core/utils/option_availability.dart`) TS 로 **포팅**한다. 복제가 아니다. **교차 골든**으로 고정한다.
- [ ] **R7** 금액 산술을 Dart·TS 양쪽에서 **같은 식 1개**로 통합한다(`cart_pricing.dart` / `cartPricing.ts`). Dart 소비자: 메뉴 상세 담기, 카트 합계, 선검증 재가격. **교차 골든**으로 고정한다. `orderBuilder.ts` 의 거짓 타입(§1-5)을 실제 키로 고치고 item 레벨 키 집합을 골든에 추가한다.
- [ ] **R8** `enforce` 모드에서 `orders`/`orderLogs` 의 금액 필드(`items[].unitPriceWithOptions`, `items[].lineTotal`, `subtotal`, `totalPrice`)를 **서버 재계산값으로 쓴다.** `shadow` 는 쓰지 않는다(관측만).
- [ ] **R9** 체크아웃 진입 선검증이 **카트 라인을 현재 문서 가격으로 재가격**한다. 선검증이 이미 읽는 문서를 재사용한다. **선검증은 권위가 아니다** — 읽기 실패 시 결제를 막지 않는다(선행 §8.2).
- [ ] **R10** `menu_override_model.dart:52` 비방어 cast 를 `(num?)?.toInt()` 로 고친다(§1-7).
- [ ] **R11** 거절 사유 2종을 선행 §15.1 **토큰 문법 그대로** 추가한다: `PRICE_MISMATCH`, `OPTION_UNAVAILABLE`. 메뉴 사유 계열로 취급해 `menuItemId` 를 토큰에 싣는다.
- [ ] **R12** 거절 1건을 `paymentGateRejections` 에 영구 기록한다. `detail` 에 **클라 선언액 · 서버 계산액 · 부호 있는 차액 · 라인별 차이**를 담는다(오탐 분석의 유일한 수단).
- [ ] **R13** 모드 스위치 **`PAYMENT_PRICE_MODE` 신설**(Q3=ⓑ 확정, 품절 게이트와 독립). `off`(평가·읽기 0) / `shadow`(판정·기록, 거절 없음) / `enforce`(판정·기록·거절). 없거나 모르는 값은 `off`. 의미·운영은 `operations.md §6` 단일 진실원. 모드용 UI·admin 토글은 만들지 않는다(서버 설정).
- [ ] **R14** 기존 주문의 **금액 내부 정합성 감사 도구**를 만든다(읽기 전용, dry-run, admin 전용). §12.
- [ ] **R15** `deploy_runbook.md` 를 작성한다 — 선행 런북 패턴(전체 한 줄 명령 + `--project` + 중단 기준 + 배포 기록). 비상 정지는 `operations.md §6.3` 을 가리킨다.
- [ ] **R16** (Q7=ⓐ) `onMenuPriceWritten` Firestore 트리거가 `basePrice`/`priceOverride`/`optionGroups.items[].priceDelta` 변경을 `priceHistory/{autoId}` 에 남긴다. 쓰기 경로 비간섭. Rules 1줄(`read: isAdmin()`, `write: false`).

### UI 요구사항

- [ ] 결제 실패 화면에 사유 2종(`PRICE_MISMATCH`, `OPTION_UNAVAILABLE`)의 헤드라인·본문·버튼이 있다. **"가격이 안 맞아요" 로 끝나지 않는다 — 고객이 실제로 복구할 수 있는 행동이 주 버튼이어야 한다**(§9-3).
- [ ] 카트/체크아웃이 **재가격으로 금액이 바뀐 사실**을 고객에게 알린다(금액이 조용히 바뀌면 그것도 사고다).
- [ ] 선행 design D4("서버 문자열을 화면에 보간하지 않는다")를 유지한다. 금액 숫자를 보여줄지는 **Q6**.

### 상태 요구사항

- [ ] loading — 재가격 중 체크아웃 결제 버튼 상태(선검증 기존 패턴 재사용, 타임아웃 3초)
- [ ] error — 재가격 실패는 **표시만 하고 결제를 막지 않는다**(선행 §8.2)
- [ ] empty — 재가격 결과 카트가 비는 경우는 없다(가격만 바꾼다. 품절 제거는 기존 G2 UI)

---

## 4. 설계 — 사실과 판정 함수

### 4-1. 사실 목록 (원칙 3)

| # | 사실 | 판정 함수 | 상태 |
|---|---|---|---|
| 2 | "이 메뉴를 지금 팔 수 있는가 **+ 단가는 얼마인가**" | Dart `applyOverrideForCustomer` / TS `menuVisibility.ts` | **기존. 새로 만들지 않는다.** `MergedMenu` 에 `optionGroupRefs` 를 **더한다**(읽기 0) |
| 5 | "이 옵션 항목을 지금 선택할 수 있고 가격 증감은 얼마인가" | Dart `resolveSelectableOptions`(**추출**) / TS `optionPricing.ts`(**포팅**) | **신규 2개 — 같은 규칙 1개** |
| 6 | "이 카트의 결제 금액은 얼마인가" | Dart `computeCartAmount` / TS `computeCartAmount` | **신규 2개 — 순수 산술** |

> **사실 6 은 "승인 규칙" 을 판정하지 않는다.** 가격의 권위(= `priceOverride` 를 적용할지)는 **사실 2 가 이미 결정한 값**이고, 사실 6 은 그 결과에 산술만 한다. 그래서 `applyOverrideForCustomer` 와 갈라질 수 없다 — 갈라질 분기를 갖고 있지 않다. 이것이 요구사항 3("새 판정 함수를 만들지 마라")을 지키는 방식이다.

### 4-2. 재계산식

```
line(i)      = merged(i).basePrice + Σ priceDelta(sel) over sel ∈ selectedOptions(i)
lineTotal(i) = line(i) × quantity(i)
subtotal     = Σ lineTotal(i)
discount     = 0            (§1-3 — 값이 들어가는 경로가 없다)
expected     = subtotal − discount
```

- `merged(i).basePrice` 는 **사실 2 의 출력**이다. 매장 직영 메뉴면 `stores/{s}/menuItems.basePrice`, 브랜드 메뉴면 `applyOverrideForCustomer(master, override).basePrice`(= approved 일 때만 `priceOverride`).
- `priceDelta(sel)` 는 **사실 5 의 출력**이다. 선택 불가(비활성·부재)면 금액이 아니라 **거절**이다(R4).
- `Math.trunc` 를 쓰는 곳은 TS 쪽 `asPrice` 1곳뿐이고 Dart `(num?)?.toInt()` 와 **같은 방향(0 쪽 버림)** 이다. 음수에서도 일치한다.

### 4-3. 판정식

```
enforce 통과 조건 (전부 AND):
  ① data.amount === data.cart.totalPrice            ← 기존. 유지(거의 무료). 권위가 아니다
  ② data.cart.totalPrice === data.cart.subtotal      ← 신규. 클라 내부 정합성
  ③ data.cart.subtotal === Σ data.cart.items[].lineTotal   ← 신규. 클라 내부 정합성
  ④ data.amount === expected                         ← 신규. ★ 이것만이 권위다
  ⑤ 모든 라인에 대해 data.items[i].lineTotal === lineTotal(i)   ← 신규. ⑥ 참조
  ⑥ 모든 라인에 대해 data.items[i].unitPriceWithOptions === line(i)
```

- ①②③ 은 **클라 값끼리의 비교이므로 권위가 아니다.** 그런데도 둔다: 공짜이고, §12 의 소급 감사와 **같은 불변식**이며, 위반이 기록되면 "어느 층에서 틀어졌나" 를 즉시 가른다.
- ④ 가 본체다. ⑤⑥ 은 ④ 가 맞는데 라인 배분이 다른 경우(= `items[]` 가 거짓인데 총액만 맞춘 경우)를 잡는다. **점주 화면·매출 집계가 보는 값은 라인이다**(§1-1). ④ 만으로는 그것을 보호하지 못한다.
- **허용 오차 0원.** 금액이 전부 int 이고 결제 경로에 반올림이 없다(§1-3). 오차를 두면 그만큼이 그대로 공격 여유가 된다. 시점 문제는 오차가 아니라 §7-2 가 받는다.

### 4-4. ⚠️ 설계가 발견한 우회로 — store-scope 옵션 가격은 승인을 받지 않는다 (Q8)

> ⚠️ **먼저 §13-8 을 읽어라.** 그 승인 요건 자체가 Rules 로 집행되지 않는다는 것이 설계 중에 확인됐다. 아래는 **그것을 닫은 뒤에도 남는** 두 번째 우회로다.

브랜드 가맹점이 마스터 메뉴의 **단가**를 바꾸려면 `menuOverrides.priceOverride` 가 `status == approved` 여야 한다(핵심 필드). 그런데 그 메뉴의 `optionGroupRefs` 가 **store scope** 를 가리키면, 그 그룹 문서(`stores/{s}/optionGroups/{id}`)는 **점주가 자유롭게 쓸 수 있고**(`firestore.rules:471-477`, 필드·타입 제약 없음) `priceDelta` 변경이 **즉시** 적용된다.

- 즉 **옵션 가격은 가격 승인 정책의 우회로**다. 이 task 가 그 값을 "서버가 문서에서 읽은 권위 있는 값" 으로 쓰기 시작하면 **우회가 서버 공인된다.**
- 이것은 이 task 가 만드는 결함이 아니라 **드러내는** 결함이다. 선행 M1·M2 가 기존 데이터 결함을 드러낸 것과 같은 성질이다.
- 처리 방향은 **Q8**. 이번 범위에서는 **현행 동작 유지 + 명시 + 후속 등재**를 추천한다.

---

## 5. CF 삽입 지점

```
verifyTossPayment.ts
  1   인증
  2   입력 검증 (+ cart.items.length <= MAX_CART_ITEMS = 50, 기존)
  3-pre 멱등 가드
  2-b G1 매장 + G2 메뉴 게이트            ← 기존. evaluatePaymentGate → GateResult.resolved
  2-c ★ 신규: 금액 재계산 게이트            ← 여기. confirm 전
        ⓐ resolved(= MergedMenu + optionGroupRefs) 를 받는다           [추가 읽기 0]
        ⓑ 필요한 (scope, groupId) 를 모아 getAll 1회로 옵션 그룹을 읽는다  [+m reads]
        ⓒ resolveSelectableOptions → computeCartAmount → §4-3 판정
        ⓓ 위반 → 기록 + (enforce 면) HttpsError. confirm 호출 없음
  3   Toss confirm
  4   응답 검증 (status DONE / totalAmount / orderId)
  6   Firestore batch  ← enforce 면 서버 재계산값으로 orders·orderLogs 를 쓴다 (R8)
```

- **2-b 와 2-c 는 한 번의 평가 흐름으로 묶는다.** 분리하면 `resolved` 를 다시 만들어야 하고, 그러면 사실 2 를 두 번 판정하게 된다(원칙 3 위반).
- **confirm 이후를 재검사하지 않는다.** 선행 §7.3 Q5 = ⓐ 확정을 그대로 잇는다. confirm 과 게이트 사이의 창(수백 ms~수초)에 점주가 가격을 바꾸면 그 1건이 통과한다 — **보상 경로가 이미 있다**(점주 주문 거절 / `processRefund`). ⓑ(confirm 후 취소)는 "돈만 빠지고 주문이 없는" 더 나쁜 상태를 새로 만든다.

---

## 6. 읽기 비용과 상한

### 6-1. 비용

| 구간 | 읽기 | round-trip |
|---|---|---|
| 기존 G1 | `stores/{s}` 1 | 1 |
| 기존 G2 | 3n (n = 메뉴 **종류** 수, 가맹점) | 1 (`getAll`) |
| **신규 (옵션)** | **m** (m = 중복 제거한 (scope, groupId) 쌍 수) | **+1 (`getAll`)** |
| 신규 (basePrice) | **0** | 0 |

현실값: 카트 3품목·메뉴당 옵션 그룹 2~3개·그룹 공유 있음 → **m ≈ 3~6**. 기존 10 reads 에서 **13~16 reads** 가 된다.
일 1,000건 결제 기준 추가 약 6,000 reads/일 ≈ **$0.004/일**(Firestore $0.06/100k). **결제 1건당 비용이고 결제는 희소하다 — 수용한다.**

### 6-2. 상한 (선행 `MAX_CART_ITEMS` 와 같은 성질의 뚜껑)

```
MAX_OPTION_GROUP_DOCS = 200     // 중복 제거 후 (scope, groupId) 쌍 수 상한
```

- `MAX_CART_ITEMS = 50` 이 메뉴 종류 수를 막지만 **메뉴당 옵션 그룹 수는 점주·브랜드가 정한다.** 상한이 없으면 메뉴 1개가 그룹 40개를 가리키면 결제 1건이 2,000 reads 다.
- 초과 시: **거절 + 기록**(사유 `READ_FAILED`, 고객 문구는 "일시적인 오류"). ⚠️ **정직하게 적는다 — 재시도로 풀리지 않는다.** 현재 데이터 모양에서 **도달 불가**한 값이라 오탐 0 으로 보지만, 그 가정이 틀렸으면 shadow 에서 드러나야 한다.
- → **런북 중단 기준**: shadow 관측에서 이 기록이 **1건이라도 나오면 멈추고 원인부터 찾는다.**

---

## 7. 오탐 — "잘못 막히면 무슨 일이 일어나는가" (선행 §8 을 잇는다)

### 7-1. fail 방향 표

| 데이터 상태 | 판정 | 결과 | 오탐 시 |
|---|---|---|---|
| 재계산액 ≠ 클라 선언액 (클라가 **적다**) | **거절** | 결제 불가 | 조작이거나 **카트가 오래된 것**이다. **서버는 둘을 구분할 수 없다**(§7-2). 고객 문구는 **선량한 쪽을 가정해야 한다** |
| 재계산액 ≠ 클라 선언액 (클라가 **많다**) | **거절** | 결제 불가 | 가격이 내려갔는데 카트가 옛값이다. 통과시키면 **정상 고객을 과다 청구**한다. 거절이 고객에게 유리하다 |
| 선택한 옵션 항목이 그룹에 **없다** | 거절 | 결제 불가 | 점주가 옵션 항목을 삭제했다. 의도된 동작. 지목이 필요하다 |
| 선택한 옵션이 **disabled / active=false** | 거절 | 결제 불가 | **가장 현실적인 오탐.** 점주가 옵션을 끈 뒤 담아 둔 카트가 막힌다 |
| `required` 그룹에 선택이 **없다** | 거절 | 결제 불가 | ⚠️ **점주가 required 그룹의 항목을 전부 비활성화하면 그 메뉴는 영구히 결제 불가**가 된다. 담기 단계에서도 막히므로(선택할 항목이 없다) 현행과 일관되지만, **담아 둔 카트는 막힌다.** 기록으로 탐지한다 |
| 옵션 그룹 문서 **부재**(ref 가 유령을 가리킨다) | 거절 | 결제 불가 | 데이터 결함. 자동 통과시키면 **그 그룹의 가격이 0 으로 계산되어 구멍이 된다** |
| 옵션 그룹 **읽기 실패**(장애) | **거절** + `READ_FAILED` + 기록 | 결제 불가 | 대안("읽기 실패 시 통과")은 게이트를 무력화한다. 선행 §8.1 과 같은 방향 |
| 그룹 수 상한 초과 | 거절 + 기록 | 결제 불가 | §6-2. 도달 불가 가정이 틀렸음을 알리는 신호 |
| `PAYMENT_PRICE_MODE` 없음 / 모르는 값 | **`off`** | 결제 성립(현재와 동일) | **구멍이 열린 채 유지된다. 의도된 선택이다** — 설정 오타로 매출이 멈추는 것보다 낫다(선행 §17.0 과 같은 근거). 대가는 "enforce 인 줄 알았는데 off" 이고, **런북의 거절 1건 실측**이 그것을 받는다 |
| `shadow` | 판정·기록만 | 결제 성립 | 오탐이 **기록으로만** 나타난다. 돈이 멈추기 전에 보는 창 |

### 7-2. 서버는 조작과 시점 차이를 **구분할 수 없다** (이 task 의 핵심 제약)

클라 선언액과 재계산액이 다를 때, 서버가 보는 것은 "다르다" 뿐이다. 원인은 둘이다.

| 원인 | 빈도 |
|---|---|
| 조작 (스크립트 직접 호출) | 드물다. 그러나 이 task 의 존재 이유다 |
| **카트가 담긴 시점의 가격이 지금과 다르다** | 점주가 가격을 바꿀 때마다, 그 순간 카트를 들고 있는 모든 고객 |

- **카트는 in-memory·비영속**이다(`cart_local_data_source.dart:6-10`). 담기 시점의 `unitPriceWithOptions` 를 들고 있고 **스스로 갱신하지 않는다.**
- → ⚠️ **거절만 하면 고객은 무한 거절 루프에 빠진다.** 다시 눌러도 카트의 금액은 그대로이므로 또 거절된다. **이것이 이 설계에서 가장 위험한 오탐이다** — 돈이 멈추는 데다 고객이 빠져나갈 길이 없다.
- → 그래서 **R9(체크아웃 진입 재가격)는 선택이 아니라 필수 선행**이다. 재가격이 창을 "담기~결제" 에서 "체크아웃 진입~confirm"(수십 초)으로 줄인다.
- → 그리고 **거절 화면의 주 버튼은 실제로 복구되는 동작이어야 한다**(= 카트를 현재 가격으로 다시 맞춘 뒤 카트로 보낸다). "다시 시도" 를 달면 같은 거절을 반복시킨다(선행 design §3.1 과 같은 판단).
- 처리 방식의 갈림길은 **Q2**.

### 7-3. 오탐 탐지 수단

`paymentGateRejections` 가 유일한 수단이다(선행 §9-7 재사용). 이번에 `detail` 을 확장한다:

```
detail = {
  clientAmount        클라 선언 amount
  serverExpected      서버 재계산액
  delta               clientAmount − serverExpected  (부호 있는 값 — 방향이 원인을 가른다)
  checks              { c1..c6 : bool }       §4-3 어느 조건이 깨졌는가
  lines               [{ menuItemId, clientLineTotal, serverLineTotal, quantity }]  (상한 50)
  optionIssues        [{ menuItemId, groupId, itemId, kind }]  kind: missing|disabled|inactive|notInRefs|requiredEmpty|multiInSingle
  shadow              true (shadow 모드일 때만)
}
```

- **`delta` 의 부호 분포가 조작과 시점 차이를 사후에 가른다**: 시점 차이는 양·음 양방향으로 흩어지고 금액이 작다. 조작은 음수로 크게 치우친다(공격자는 적게 낸다).
- 기록 실패는 거절 결과를 바꾸지 않는다(기존 `recordGateRejection` 규약 유지).

---

## 8. 모드 스위치 — **`PAYMENT_PRICE_MODE` 신설** (Q3 = ⓑ 확정)

> **모드 값(off/shadow/enforce)의 의미 · 바꾸는 명령 · 비상 정지 · 현재값 확인(양성 대조) · 일일 점검은 `docs/operations.md §6` 이 단일 진실원이다.** `PAYMENT_PRICE_MODE` 는 그 §6.1 표에 이미 등재돼 있다. 이 절은 **왜 이렇게 설계했는가**만 둔다 — 운영 방법을 중복 기술하지 않는다.
>
> **모드 스위치는 서버 설정(개발자만, `functions/.env.*` + 재배포)이다. admin 앱에서 바꿀 수 없고, 바꿀 수 있게 두지 않는다** — `off` 는 검증을 제거하는(되돌릴 수 없는 방향) 배포 안전장치라, 손이 더 가는 경로에 두는 것 자체가 안전장치로 기능한다. 이 task 는 모드용 UI·admin 토글을 만들지 않는다.

- **품절 게이트(`PAYMENT_GATE_MODE`)와 독립이다.** 두 게이트의 오탐 양상이 다르다 — 품절 오탐은 고객이 그 메뉴를 빼면 복구되지만, 금액 오탐은 카트 전체가 막히고 §7-2 의 루프 위험이 있다. 금액 쪽 오탐으로 `PAYMENT_PRICE_MODE` 를 내려도 **검증 끝난 품절 게이트를 함께 끄지 않는다.** 이것이 플래그를 나눈 이유다.
- `off` 면 **옵션 그룹을 읽지 않는다**(비용 0). 선행 `off` 와 같은 성질.
- ⚠️ **의존 관계 — 이 분리가 만드는 유일한 함정**: 금액 재계산은 `GateResult.resolved`(= G2 의 산출물)를 필요로 한다. 따라서 **`PAYMENT_GATE_MODE=off` + 가격 모드 `enforce` 조합**은 입력이 없어 **조용히 아무 일도 하지 않을** 수 있다 — 선행 task 에서 가장 비쌌던 실패("켜졌다고 믿었는데 off")의 재현이다.
  → **처리 = ⓐ 확정**: 가격 모드가 `off` 가 아닌데 게이트 모드가 `off` 면 **가격 모드가 메뉴 읽기를 직접 수행**한다(게이트 판정은 하지 않는다). 기능이 플래그 조합에 의존하지 않게 된다. **조용히 통과시키는 선택지는 없다** — 19-3 이 이 조합을 테스트로 고정한다.
- enforce 전환의 **양성 대조는 필수**다(원리: operations §6.4). 전환 직후 금액을 일부러 틀린 호출로 거절 1건을 유도해 확인한다. **확인 없이는 전환이 끝난 것으로 보지 않는다.**

---

## 9. 거절 사유 / 문구

### 9-1. 신규 사유 2종 (선행 §15.1 문법 그대로)

| reason | HttpsError code | 토큰 | id |
|---|---|---|---|
| `PRICE_MISMATCH` | `failed-precondition` | `[PRICE_MISMATCH:id1,id2]` | **차이가 난 라인의 `menuItemId`**. 차이가 총액에만 있으면 id 없이 `[PRICE_MISMATCH]` |
| `OPTION_UNAVAILABLE` | `failed-precondition` | `[OPTION_UNAVAILABLE:id1]` | **해당 라인의 `menuItemId`** |

- 읽기 실패·상한 초과는 **기존 `READ_FAILED`** 를 쓴다(새 사유를 만들지 않는다).
- **옵션 id 를 토큰에 싣지 않는다.** `menuItemId` 만 싣고 화면은 카트의 메뉴 이름으로 지목한다 — 선행 §15.1 의 해석 경로를 그대로 재사용한다. 옵션 라벨까지 지목하면 해석 경로가 둘이 된다.
- 사유 우선순위(토큰은 1개): `OPTION_UNAVAILABLE` > `PRICE_MISMATCH`. **옵션이 고객이 고칠 수 있는 쪽**이고, 옵션이 깨지면 금액도 자동으로 깨지므로 금액 사유로 덮으면 고객이 할 일을 모른다.
- 기존 6종과 합쳐 **8종**. 선행 grep 가드 6-c ⓑ("알려진 사유가 각각 헤드라인·버튼을 가진다")가 **자동으로 실패**하므로 표를 빠뜨릴 수 없다. **그 가드가 이번에 값을 낸다.**

### 9-2. 토큰 상한

메뉴 사유와 같다. `MAX_CART_ITEMS = 50` 이 메뉴 종류 수를 막으므로 id 최대 50개 ≈ 1,050자 < 2,048. **절단이 구조적으로 발생하지 않는다.**

### 9-3. ⚠️ designer 에게 넘기는 질문 — "가격이 안 맞아요" 는 고객이 할 수 있는 게 없다

이 사유의 어려움은 문구가 아니라 **고객의 복구 행동이 무엇인가** 다.

| 질문 | 내용 |
|---|---|
| **DQ1** | 주 버튼이 무엇인가. 추천 방향: **`최신 가격으로 다시 담기`** — 누르면 카트를 현재 문서 가격으로 재계산한 뒤 카트로 보낸다. 단순 `pop()` 은 **같은 거절을 반복시킨다**(§7-2) |
| **DQ2** | 금액 차이를 **숫자로** 보여줄 것인가. "17,000원 → 16,500원" 은 고객이 납득할 수 있게 하지만, 선행 D4("서버 바이트를 화면에 보간하지 않는다")에 **정수 검증 후 포맷**이라는 예외를 만든다. 숫자를 쓰려면 **Q6 가 토큰에 금액을 실어야 한다** |
| **DQ3** | 재가격으로 카트 금액이 **바뀐 순간**을 어떻게 알리는가(R9). 조용히 바꾸면 "결제 금액이 내가 본 것과 다르다" 가 된다. 배너 / 라인 뱃지 / 다이얼로그 중 어느 것인가 |
| **DQ4** | 가격이 **올랐을 때**와 **내렸을 때** 문구가 같아도 되는가 |
| **DQ5** | `OPTION_UNAVAILABLE` 의 지목 단위. 메뉴 이름만 지목하면 "이 메뉴의 옵션" 까지만 말할 수 있다. 고객 카트에는 옵션 라벨이 있으므로 **카트 쪽에서** 옵션 행을 표시하는 것이 가능하다(선행 D6 패턴) |
| **DQ6** | 조작자와 선량한 고객이 **같은 화면**을 본다. 그래도 선량한 쪽을 가정한 문구로 쓰는 것이 맞는가(설계자 판단: 그렇다. 조작자에게 숨길 정보가 없다) |

**문구에 절대 쓰지 않을 것**: "조작", "비정상", "위조". 오탐 시 선량한 고객을 범죄자로 만든다.

---

## 10. 주문 문서를 서버 값으로 쓴다 (R8)

- **무엇을**: `orders/{id}.items[].unitPriceWithOptions`, `.lineTotal`, `.subtotal`, `.totalPrice` 와 `orderLogs` 의 같은 필드.
- **왜**: 선행 spec §9 체크리스트 3번이 이미 적어 둔 것이다 — "주문은 가격을 박제한다. **단 박제하는 값이 클라이언트 값이다.**" 이 task 가 그것을 닫는다.
- **enforce 에서는 서버 값 = 클라 값이다**(§4-3 ⑤⑥ 이 같음을 요구하므로). 그래서 **바이트는 바뀌지 않는다.** 그래도 서버 값으로 쓴다: 클라 값이 주문 문서에 도달하는 **경로 자체를 없애는 것**이 목적이다. 나중에 누가 판정식을 느슨하게 하면(예: 오차 허용) 경로가 남아 있으면 즉시 거짓이 박제된다.
- **shadow 에서는 쓰지 않는다.** shadow 가 주문 문서를 바꾸면 "관측만" 이 깨진다. ⚠️ **shadow 와 enforce 가 쓰는 문서가 다르다 — 테스터가 이 차이를 확인한다.**
- **이름·옵션 라벨까지 서버가 다시 만들 것인가는 Q4.** 가격만 바꾸는 것을 추천한다(이름은 돈에 영향이 없고, 문서의 현재 이름이 고객이 담을 때 본 이름과 다를 수 있다).
- `discount` 는 `null` 유지(§1-3).

---

## 11. 체크아웃 진입 재가격 (R9) — 필수 선행

- 선검증(`ValidateCheckoutUseCase`)이 **이미 매장 + 메뉴 문서를 fresh 로 읽는다**(`validate_checkout_use_case.dart`). 거기에 **옵션 그룹 읽기만 더하면** 카트를 현재 가격으로 재계산할 수 있다.
- 반환을 확장한다: `CheckoutValidation` 에 **재가격 결과**(라인별 새 `unitPriceWithOptions`/`lineTotal`, 새 `subtotal`, 변동 여부)를 더한다.
- **선검증은 권위가 아니다**(선행 §8.2). 읽기 실패·타임아웃이면 **재가격하지 않고 결제를 진행**한다. `CheckoutValidation` 에 `failed` 값을 만들지 않는다는 선행 design N1 판단을 유지한다.
- 판정은 **§4-1 의 같은 함수들**을 호출한다. 자체 계산을 만들지 않는다 — 이것이 "클라와 서버가 갈라지지 않는" 이유다.
- **quick reorder(선행 N5)는 이 재가격이 자동으로 덮는다.** `orderLogs.lineTotal` 역산으로 담긴 stale 라인도 체크아웃 진입 시 현재 가격으로 교정된다. → **N5 를 이 task 범위에 넣지 않는다.** 남는 문제는 홈 화면이 옛 가격을 **표시**하는 것뿐이고 그것은 돈 경로가 아니다. N5 는 backlog 에 유지하고 **사유를 갱신**한다.

---

## 12. 소급 탐지 (R14) — 할 수 있는가

### 12-1. 할 수 있다. 단 1계층까지만.

| 계층 | 방법 | 추가 읽기 | 결론 |
|---|---|---|---|
| **Tier 1 — 내부 정합성** | 주문 문서만으로 `lineTotal == unitPriceWithOptions × quantity`, `subtotal == Σ lineTotal`, `totalPrice == subtotal`, `paymentInfo.amount == totalPrice` 를 검사 | **0** (주문 문서 1건당 1 read) | **포함한다.** §0 의 공격(`amount:1` + 17,000원어치 items)은 `subtotal(1) ≠ Σ lineTotal(17,000)` 으로 **반드시 걸린다.** 현행 클라이언트는 항상 정합하므로 **오탐 0** |
| **Tier 2 — 문서 대조** | 과거 주문의 금액을 **현재** 메뉴·옵션 문서와 비교 | 주문당 3n+m | **제외한다.** 가격 변경 이력이 없어(§13-1) "그때 얼마였나" 를 알 수 없다. 정상 가격 변경이 전부 오탐이 된다. **결론을 낼 수 없는 도구는 만들지 않는다** |

- Tier 1 의 한계도 명시한다: **공격자가 `lineTotal`·`unitPriceWithOptions`·`subtotal` 을 전부 정합하게 위조하면 Tier 1 은 통과한다.** 그 경우 `totalPrice == amount` 이므로 주문 문서는 "값싼 메뉴를 산" 것으로 보이고, 거짓은 **단가 자체**에 있다 → Tier 2 영역이고 가격 이력 없이는 판정 불가. **Q7 이 ⓐ 로 결정되면 그 시점 이후부터는 Tier 2 가 가능해진다.**
- 따라서 Tier 2 는 "지금 못 한다" 가 아니라 **"가격 이력이 없어서 못 한다"** 다. Q7 의 대가 비교에 이 사실을 넣는다.

### 12-2. 도구의 모양

- `auditOrderPriceIntegrity` — **임시 CF**(onCall, admin 전용, **읽기 전용**). 선행 `migrateStoreApprovalMeta` 패턴과 admin 카드 진입 경로(`implementation.md §11`)를 **그대로 재사용**한다.
- 입력: 기간(`from`/`to`), `limit`. 출력 3부:
  - ⓐ **주문 Tier 1**: `{ scanned, violations: [{orderId, userId, storeId, createdAt, checks, clientSubtotal, sumOfLineTotals, amount}], byCheck: {...} }`
  - ⓑ **self-approved override** (§13-8): `menuOverrides` 전수에서 `status == 'approved'` 인데 `approvedBy` 가 **없거나 그 매장 점주 uid** 인 건 → `[{storeId, masterMenuItemId, priceOverride, approvedBy, updatedAt}]`
  - ⓒ **store-scope ref** (§4-4 / Q8): 브랜드 매장의 메뉴가 `scope == 'store'` 옵션 그룹을 참조하는 건수 → `{count, samples:[{storeId, menuItemId, groupId}]}`
- ⓑⓒ 는 "다음 판단을 싸게 하는 측정" 이다. **수를 모르면 Q8 과 §13-8 의 처리를 정할 수 없다.**
- **고치지 않는다. 멈추고 보고한다**(선행 M1 과 같은 규약).
- **배포 순서상 자리**: 배포 ② 에서 1회 실행해 **기준선(baseline)** 을 기록한다. 기준선이 0 이 아니면 그것이 이미 일어난 사고다. 기준선 없이 enforce 하면 "원래부터 있던 것" 과 "새로 생긴 것" 을 영구히 구분할 수 없다.
- 실행 1건당 기록 1건을 남긴다(§13-5).
- **⑩ 정리 커밋에서 삭제**한다(임시 자산 — 선행 ⑪ 패턴).

---

## 13. 이력 / 감사 추적 (`audit_trail.md` §4 체크리스트 7항목)

| # | 항목 | 판정 |
|---|---|---|
| **1** | 돈·권한·정책 값을 바꾸는가 → **설정 변경 이력이 기본값** | **⚠️ 그렇다 — 그리고 이 task 가 그 문제를 처음으로 뼈아프게 만든다.** 아래 13-1 |
| **2** | 덮어쓰기로 사라지는 값 | **가격이 그렇다.** `basePrice`/`priceOverride`/`priceDelta` 는 덮어쓰면 이전 값이 사라진다. → 13-1. 또 거절 시에는 "클라가 뭐라고 주장했는가" 가 사라진다 → `paymentGateRejections.detail`(§7-3)이 받는다 |
| **3** | 거래/기록 문서가 정책 값을 참조만 하는가 | **개선된다.** 주문은 가격을 박제하는데 지금은 **박제하는 값이 클라이언트 값**이다(선행 §9 가 지적). R8 이 서버 값으로 바꾼다 |
| **4** | "누가" 가 기록되는가 | `paymentGateRejections.uid`(고객) + `storeId`. 감사 도구 실행은 admin uid |
| **5** | 일괄 처리가 있는가 | 감사 도구 1건. 실행 1건을 묶어 기록하고 **영향 범위(scanned / violations 수 / 기간)** 를 함께 남긴다 |
| **6** | CF 로그에 의존하지 않는가 | **거절 기록은 Firestore 다**(`paymentGateRejections` 재사용). Cloud Logging 보존 기간 뒤에도 **오탐 분포와 `delta` 부호 분포**를 볼 수 있어야 한다 — 그것이 이 게이트의 유일한 오탐 탐지 수단이다 |
| **7** | 판정 입력 필드의 `create`·`update` 교차 확인 | 13-7 |

### 13-1. ⚠️ 가격 변경 이력이 없다 (Q7)

**거래 이력이 있다고 설정 변경 이력이 있는 것이 아니다.** 주문이 가격을 박제하는 것은 **거래 이력**이다. **가격 자체가 언제 누구에 의해 얼마에서 얼마로 바뀌었는지는 어디에도 없다.**

이 task 는 가격을 **권위**로 쓰기 시작한다. 그래서 이력의 부재가 세 곳에서 아프다.

| 아픈 곳 | 내용 |
|---|---|
| 오탐 분석 | 거절 1건을 보고 "그 시점에 가격이 바뀌었나" 를 확인할 수 없다. `delta` 분포로 **추정**만 한다 |
| 소급 감사 | Tier 2 가 불가능하다(§12-1) |
| 분쟁 | 고객이 "그 가격이 아니었다" 고 하면 답할 자료가 없다 |

`audit_trail.md` §4-1 의 기본값은 **"남긴다"** 이고, 안 남기려면 **사유를 spec 에 쓴다.** → **Q7**. 추천안은 **Firestore 트리거 1개**(`onMenuPriceWritten`)로 `basePrice` / `priceOverride` / `optionGroups.items[].priceDelta` 변경을 `priceHistory` 에 남기는 것이다. 트리거는 **클라이언트 직접 쓰기도 포착**하므로 **쓰기 경로를 하나도 건드리지 않는다**(Rules 로는 이력을 강제할 수 없다 — 이것이 트리거여야 하는 이유다).

### 13-2. 남기지 않기로 한 것과 사유

- **모드 전환 이력**(`PAYMENT_PRICE_MODE` 를 누가 언제 올렸나) — **Firestore 에 남기지 않는다.** 사유: 값이 `functions/.env.*` + git + Cloud Functions 리비전에 남고, 전환은 배포 행위이며 운영자는 1인이다. 선행 task 와 같은 판단이다. **단 런북에 전환 시각과 실행자를 손으로 적는다**(선행 배포 기록 패턴).
- **거절되지 않은 결제의 재계산 결과** — 통과한 결제의 계산 과정을 기록하지 않는다. 사유: 볼륨이 결제 건수와 같고, 통과는 "서버 값 = 박제 값"(R8)이므로 주문 문서 자체가 기록이다.

### 13-7. create·update 교차 확인 (원칙 4 — 같은 패턴으로 네 번 구멍이 났다)

금액 판정에 **입력으로 들어가는 필드 전수**와 쓰기 경로:

| 판정 입력 필드 | 문서 | 쓰기 주체 | create | update | 교차 확인 |
|---|---|---|---|---|---|
| `basePrice` | `stores/{s}/menuItems`, `brands/{b}/menuItems` | 점주 / brandHolder / admin | 허용 | 허용 | 자기 자원의 가격 설정은 **권한 내**다. 위조가 아니다 |
| `priceOverride` | `stores/{s}/menuOverrides` | 점주(제출) / brandHolder·admin(승인) | 🔴 **구멍 확인됨** | 🔴 **구멍 확인됨** | §13-8 |
| `override.status` | 같음 | 같음 | 🔴 **구멍 확인됨** | 🔴 **구멍 확인됨** | §13-8. **하네스에 create·update 거부 케이스 각 1건 + 정상 제출 허용 회귀 1건** |
| `optionGroups.items[].priceDelta` | 3 scope | scope 별 상이 | 허용 | 허용 | **store scope 는 점주가 즉시 변경 가능** → §4-4 우회로(Q8) |
| `active` (그룹) | 같음 | 같음 | 허용 | 허용 | 비활성 = 거절 방향이므로 구멍이 아니라 오탐 방향 |
| `disabledOptionGroupIds` / `disabledOptionItemIds` | `menuItems`, `menuOverrides` | 점주 | 허용 | 허용 | 운영 필드(status 무관). 거절 방향 |
| `visible` / `soldOut` | 기존 | 기존 | — | — | 선행 task 가 다뤘다 |

- Rules 에 **필드·타입 제약이 전무**하다(`firestore.rules:453-477, 574-592, 638-640`). 점주 권한 토큰으로 SDK 를 직접 치면 `priceDelta: 0.5` 나 음수 `basePrice` 를 심을 수 있다. **그 자체는 권한 내**(자기 가격)이지만, `0.5` 는 Dart 와 TS 의 파싱이 갈리는 입력이다(§1-7) → R10 이 받는다. 타입·범위 제약은 후속 P5.

### 13-8. 🔴 설계 중 확인된 구멍 — `priceOverride` 의 승인 요건이 집행 불가능하다

`firestore.rules:462-468`:

```
match /menuOverrides/{masterMenuItemId} {
  allow read: if isSignedIn();
  allow create, update, delete:
    if isAdmin() || isStoreOwner(storeId) || isBrandHolder(...);
}
```

**필드 제약이 하나도 없다.** 즉 가맹점주가 `menuOverrides/{id}` 에 `{ status: 'approved', priceOverride: 1, approvedAt: ..., approvedBy: ... }` 를 **직접 쓸 수 있다.** create 도 update 도 막혀 있지 않다.

- → **`applyOverrideForCustomer` 의 "`status == approved` 일 때만 적용" 분기가 의미를 갖지 못한다.** 쓰는 사람이 `status` 를 정한다. 브랜드의 가격 승인은 **UI 상의 약속**이고 **집행되지 않는다.**
- **같은 패턴의 다섯 번째**다 (`users.qoinBalance` create / `qoinAccrualRate` create / `isBrandHolder` 빈 문자열 / `stores.approvedAt` create / **여기**). 원칙 4 가 가리키는 바로 그 지점이다.
- **이 task 가 만드는 결함이 아니다** — 고객 화면의 가격 표시는 이미 이 값을 쓴다. 그러나 **이 task 는 그 값을 "서버가 문서에서 읽은 권위 있는 금액" 으로 승격시킨다.** 승격 전에 닫는 것이 맞다.
- **영향 방향**: 점주가 가격을 **낮추는** 것은 자기 손해이고, **높이는** 것은 고객이 보고 선택한다. 그래서 금전 피해가 즉시 발생하는 구멍은 아니다. 피해는 **브랜드의 가격 통제권**이다 — `brand_authorization_hardening` 이 다룬 계열과 같은 종류다.
- **조치**: 배포 순서 ① 의 Rules 변경을 **확정 항목으로 올린다**. `menuOverrides` 의 `create`·`update` 에서 **점주는 승인 메타(`status: 'approved'` / `approvedAt` / `approvedBy`)를 쓸 수 없다**(선행 §6.5 Rules-A 와 같은 형태). brandHolder·admin 의 승인 쓰기는 **유지**한다.
- ⚠️ **선행 조사 필수**: 운영 데이터에 **이미 self-approved 된 override 가 있는지** 세어야 한다. 있으면 Rules 를 조이는 것만으로는 **과거 값이 그대로 권위로 남는다.** → 감사 도구(§12-2)에 **1줄로 함께 측정**한다: `menuOverrides where status == 'approved' && approvedBy == null`(또는 `approvedBy` 가 그 매장 점주 uid). **자동으로 고치지 않고 멈추고 보고한다**(선행 M1 ⓒ 규약).
- 실태 건수가 0 이 아니면 **그 처리를 Q8 과 함께 결정**해야 한다. 그래서 이 측정은 ② 실태 측정 단계에서 함께 돈다.

---

## 14. 표면 인벤토리 (원칙 3 — ⓑ 가 빈 칸이면 미설계)

> 선행 design §2 가 사실 1~4 를 들고 있다. **designer 는 거기에 사실 5·6 을 행으로 추가한다**(이 표를 옮기는 것이 아니라 §2 에 더한다). 행을 빠뜨리면 보호받지 못한다 — 선행 task 에서 FAIL 이 세 번 그렇게 났다.

### 사실 5 — "이 옵션 항목을 지금 선택할 수 있고 가격 증감은 얼마인가"

| 표면 | ⓐ 판정 출처 | ⓑ 출처 읽기 실패 시 보이는 것 | ⓒ 복구 동작 |
|---|---|---|---|
| `verifyTossPayment` 금액 게이트 (**권위**) | TS `optionPricing.ts` (Dart 와 교차 골든) | **거절** + `READ_FAILED` + 기록 1건 | 없음(거절). "잠시 후 다시 시도" |
| 메뉴 상세 옵션 목록 | `option_availability.dart`(추출 후) 경유 `OptionRepositoryImpl` | 기존 에러 UI | 재시도 |
| 체크아웃 재가격 (R9) | 같은 Dart 함수 | **재가격하지 않고 결제를 진행한다**(권위가 아니다) | — |
| 결제 실패 화면 `OPTION_UNAVAILABLE` | CF 토큰 → `PaymentFailure` | 토큰 파싱 실패 → **갈래 C** | DQ1/DQ5 |
| 점주 옵션 비활성 토글 | 기존 쓰기 | 기존 | 재시도 |

### 사실 6 — "이 카트의 결제 금액은 얼마인가"

| 표면 | ⓐ 판정 출처 | ⓑ 출처 읽기 실패 시 보이는 것 | ⓒ 복구 동작 |
|---|---|---|---|
| `verifyTossPayment` (**권위**) | TS `computeCartAmount` | 입력 문서를 못 읽으면 **거절**(§7-1) | 없음(거절) |
| **`orders`/`orderLogs` 금액 필드** | **enforce: 서버 재계산값 / shadow: 클라 값**(R8) | — | — |
| 점주 주문 상세 · 매출 집계 | 주문 문서를 **그대로 읽는다**(판정 없음) | 기존 에러 UI | 재시도 |
| Qoin 적립 기준 | `order.totalPrice`(`onOrderQoinSettled.ts:219,287`) — **이미 Toss 승인액에 고정**(§1-1) | 기존 skip + 기록 | 기존 |
| 메뉴 상세 담기 금액 | Dart `computeCartAmount`(R7 통합) | 메뉴를 못 읽으면 기존 `_DeletedView` | `매장 메뉴 보기` |
| 카트 합계 | 같은 함수 (`cart_local_data_source`) | 카트는 로컬이라 항상 그려진다 | 라인 삭제(기존) |
| 체크아웃 재가격 표시 | 같은 함수 + 선검증 읽기 | **표시하지 않고 진행**(권위가 아니다) | DQ3 |
| 빠른 재주문 단가 | **역산(`lineTotal ~/ quantity`) — 판정 출처가 없다** | 확인을 안 하므로 실패 표면이 없다 | **없음 → 체크아웃 재가격이 교정한다**(§11) |
| 결제 실패 화면 `PRICE_MISMATCH` | CF 토큰 | 토큰 파싱 실패 → 갈래 C | DQ1 |

---

## 15. 레이어 설계

### Domain (순수 Dart)

- `lib/core/utils/cart_pricing.dart` **신규** — `computeCartAmount`, `computeLinePrice`. 순수 산술. Firebase·Flutter 비의존.
- `lib/core/utils/option_availability.dart` **신규(추출)** — `resolveSelectableOptions({groups, disabledGroupIds, disabledItemIds})` + `validateSelection(...)`. `option_repository_impl.dart:56-81` 의 규칙을 **그대로** 옮긴다(동작 변경 없음).
- `lib/domain/entities/checkout_validation.dart` **확장** — 재가격 결과 필드 추가. `failed` 값은 만들지 않는다(선행 design N1).
- `lib/domain/usecases/validate_checkout_use_case.dart` **확장** — 옵션 그룹까지 읽어 재가격 결과를 포함. 판정은 §4-1 함수만 호출.
- `lib/domain/repositories/checkout_validation_repository.dart` **확장** — 옵션 그룹 fresh 읽기 메서드 추가.

### Data

- `lib/data/repositories/option_repository_impl.dart` — 추출한 함수를 호출하게 변경. **판정을 자체 보유하지 않는다.**
- `lib/data/repositories/checkout_validation_repository_impl.dart` — 옵션 그룹 fresh 읽기 구현.
- `lib/data/models/menu_override_model.dart:52` — 비방어 cast 수정(R10).
- `lib/data/repositories/payment_gateway_repository_impl.dart` — cart 직렬화. **키 집합을 바꾸지 않는다**(골든이 고정). item 레벨 키를 골든에 **추가**한다.

### Presentation

- `checkout_page.dart` — 선검증 결과의 재가격을 카트에 반영. **금액 변동을 고객에게 알린다**(DQ3).
- `cart_page.dart` — 가격 변동 표시(designer 명세 따름).
- `menu_item_detail_page.dart:685-710` — 담기 금액 계산을 `computeCartAmount` 로 교체(식이 같아야 한다).
- `payment_result_page.dart` / `PaymentFailure` — 사유 2종 추가.

### Cloud Functions

- `menuVisibility.ts` — `MergedMenu` 에 `optionGroupRefs: {scope, id}[]` 추가(읽기 0). `applyOverrideForCustomer`·`classifyCartMenu` **양쪽 경로**에서 채운다.
- `optionPricing.ts` **신규** — Dart `option_availability.dart` 의 포팅. Firestore 비의존.
- `cartPricing.ts` **신규** — Dart `cart_pricing.dart` 의 포팅. 순수 산술.
- `paymentGate.ts` / `paymentGateReader.ts` — 옵션 그룹 `getAll` 1회 추가(`GateReader` 에 포트 1개 추가). 판정은 여기서 하지 않는다.
- `orderBuilder.ts` — 거짓 타입 수정(§1-5) + 서버 재계산값으로 금액 필드 구성(R8).
- `verifyTossPayment.ts` — 2-c 삽입.
- `auditOrderPriceIntegrity.ts` **신규(임시)**.
- `onMenuPriceWritten.ts` **신규** — 가격 변경 이력 트리거(R16). `menuItems`/`menuOverrides`/`optionGroups` write 를 받아 `priceHistory` 에 `before`/`after` 를 남긴다. 쓰기 경로 비간섭.

### 레이어 규칙 주의 (developer 에게)

- `lib/core/utils/` 는 **순수 Dart**다. Firebase·Flutter import 금지.
- 옵션 판정을 `option_repository_impl` 에 **남겨 두고 TS 만 만드는 것은 금지**다. 그러면 교차 골든이 "Repository 구현 vs TS" 를 비교하게 되고, Dart 쪽을 테스트하려면 Firestore 가 필요해진다 — 선행 task 가 `menuVisibility` 를 순수 함수로 둔 이유와 같다.
- `presentation` 이 재가격을 **직접 계산하지 않는다.** UseCase 가 계산한 결과만 그린다.

---

## 16. 데이터 흐름

### 결제 (금액 게이트 적용 후)

```
checkout_page  → ValidateCheckoutUseCase (진입 시)
                   → CheckoutValidationRepository (store / menu / optionGroups fresh)
                   → canSellNow · classifyCheckoutMenu · resolveSelectableOptions · computeCartAmount
                   → 위반 + 재가격 결과
                 (읽기 실패 → CheckoutValidation.none, 재가격 없음, 결제 진행)
               → 카트 반영 + 금액 변동 표시 (DQ3)
               → Toss SDK 결제창
               → verifyTossPayment(amount, cart, ...)
                    ├ 멱등 가드
                    ├ 2-b G1·G2        → GateResult.resolved (MergedMenu + optionGroupRefs)
                    ├ 2-c 금액 재계산   → getAll(옵션 그룹) → resolveSelectableOptions
                    │                    → computeCartAmount → §4-3
                    │                    위반 → paymentGateRejections 기록
                    │                           + (enforce) HttpsError [PRICE_MISMATCH:...]
                    │                           ★ confirm 호출 없음
                    ├ Toss confirm
                    └ batch: orders + orderLogs  (enforce → 서버 재계산 금액)
```

### 소급 감사

```
admin → 더보기 > 배포 마이그레이션(임시) → auditOrderPriceIntegrity(from, to, limit)
          → orders 읽기 전용 스캔 → Tier 1 불변식 4개 → 리포트 + 실행 기록 1건
          (고치지 않는다)
```

---

## 17. 마이그레이션

**데이터 마이그레이션 없음.** 근거:

- 재계산의 입력(`basePrice`, `priceOverride`, `priceDelta`, `optionGroupRefs`)은 **모두 기존 필드**이고 기존 읽기 경로가 이미 폴백을 갖고 있다(부재 → 0 / false / 빈 배열).
- 선행 M1 이 필요했던 이유는 `status` **부재**가 fail-closed 판정의 입력이었기 때문이다. 금액에는 그런 "부재 → 거절" 입력이 없다 — **단 하나 예외**: `optionGroupRefs` 가 가리키는 그룹 문서의 **부재**는 거절이다(§7-1).
  → 따라서 **마이그레이션 대신 shadow 관측이 그 역할을 한다.** 유령 ref 가 운영 데이터에 있으면 shadow 기록으로 드러난다. **이것이 §18 에서 shadow 구간을 생략할 수 없는 이유다.**
- `priceHistory`(Q7 ⓐ)는 마이그레이션이 아니라 **그 시점 이후를 기록**한다. 과거 가격은 복원할 수 없다 — **그래서 늦어질수록 영구히 못 보는 구간이 늘어난다.** Q7 의 시급성 근거다.

---

## 18. 배포 순서 — **런북 필요** (R15)

> **필요하다.** 선행 런북이 받은 위험(되돌릴 수 없는 방향의 실패 = 정상 손님의 결제 거부)이 **그대로**이고, 이번에는 오탐 경로가 하나 더 있다(§7-2 카트 stale → **무한 거절 루프**). `docs/tasks/payment_price_authority/deploy_runbook.md` 를 선행 패턴(전체 한 줄 명령 + 모든 명령에 `--project order-app-5957e` + 중단 기준 + 배포 기록 표)으로 작성한다.
>
> **런북의 비상 정지 절은 `operations.md §6.3` 을 가리킨다**(운영 방법은 거기가 단일 진실원). 다만 **이번 배포 고유의 중단 기준**(무한 거절 루프 관측 시 `PRICE` 만 `off` 등 §18-2)은 런북 본문에 둔다 — 배포 중에만 쓰는 지식이기 때문이다.

| 단계 | 내용 | 왜 이 자리인가 |
|---|---|---|
| **①** 감사 CF 만 배포 (**함수 단위**) | `auditOrderPriceIntegrity` | ⚠️ **`npm run deploy` 금지** — 전 함수 배포이므로 금액 게이트가 기준선 측정 전에 켜진다(선행 §0-1 과 같은 함정. 같은 `index.ts` 다) |
| **②** **실태 측정 — Rules 보다 먼저** | 감사 dry-run: ⓐ 주문 금액 Tier 1 **기준선** ⓑ **self-approved override 건수**(§13-8) ⓒ 브랜드 메뉴의 store-scope ref 건수(§4-4) | ⚠️ **Rules 를 조이기 전에 측정한다.** ⓑ 가 0 이 아니면 Rules 만으로는 과거 값이 권위로 남고, **Rules 를 먼저 조이면 정상 경로와 self-approved 를 구분할 단서가 줄어든다.** 기준선 없이는 "원래 있던 것" 과 "새로 생긴 것" 을 영구히 구분할 수 없다 |
| **③** **Rules 변경 — 확정 항목** | `menuOverrides` create·update 의 승인 메타 금지 (§13-8) | 선행 Rules-A 와 같은 근거이자 같은 자리. **CF 보다 먼저.** 뒤집으면 위조가 데이터로 굳는다. 구버전 앱의 정상 제출(`status: 'pending'`)은 깨지지 않으므로 **앱보다 먼저 둘 수 있다**(선행 Rules-A 와 동일 성질) |
| **④** ⓑ 실태 처리 | ②-ⓑ 가 0 이 아니면 **사람이 판단**해 처리하고 결과를 기록 | 처리 없이 ⑦ 로 가면 **self-approved 가격이 서버 공인 금액이 된다** |
| **⑤** 본 CF 배포 — **가격 모드 `shadow`** | `verifyTossPayment` 개정 + 신규 모듈 | 코드가 올라가지만 거절하지 않는다. 유령 ref·상한 초과·오탐 분포를 **돈이 멈추기 전에** 본다(§17) |
| **⑤-b** shadow 관측 | `paymentGateRejections` 에서 `shadow:true` + `PRICE_*`/`OPTION_*` 을 본다 | **정상 결제가 잡히면 멈추고 원인부터 찾는다.** `delta` 부호 분포를 본다 |
| **⑥** **앱 배포 (재가격 포함)** | R9 + 거절 문구 | ⚠️ **선행과 순서가 반대다.** 선행은 "선검증이 서버 안전망 없이 막으면 안 된다" 는 이유로 앱을 enforce 뒤에 뒀다. 이번 앱 변경은 **막는 장치가 아니라 카트를 고치는 장치**이고, **그것이 없으면 enforce 가 무한 거절 루프를 만든다**(§7-2). 따라서 **앱이 enforce 보다 먼저**다. **이 역전의 근거를 런북 머리말에 적는다** |
| **⑦** 가격 모드 `enforce` 전환 | param 변경 + 재배포 | 전제: ⑤-b 가 깨끗함 + ⑥ 이 라이브. **전환 직후 금액을 일부러 틀린 호출로 거절 1건을 유도해 확인**(원칙 5). 확인 없이는 전환이 끝난 것으로 보지 않는다 |
| **⑧** 라이브 검증 | 정상 결제 1건 성공(옵션 포함) · 가격 변경 직후 결제 1건 · 재가격 동작 1건 | 불변식: **옵션이 붙은 정상 결제가 성공한다.** 이 항목이 FAIL 이면 배포 중단 |
| **⑨** 재측정 | 감사 재실행 | ② 대비 증가 0 을 확인 |
| **⑩** 정리 커밋 (며칠 뒤) | 감사 CF 삭제 | 선행 ⑪ 패턴 |

### 18-1. 비상 정지

**방법은 `operations.md §6.3` 이 단일 진실원이다** — 해당 모드를 `off` 로 재배포(명령은 §6.2). 이번 task 에서는 `PAYMENT_PRICE_MODE=off` 다.
- `PAYMENT_PRICE_MODE` 를 내릴 때 품절 게이트(`PAYMENT_GATE_MODE`)는 **건드리지 않는다** — 두 플래그를 나눈 이유가 이것이다(§8).
- ⚠️ `off` 는 **1원 결제가 가능한 상태**다. 내린 뒤 잊지 않는다(§6.3 과 동일 경고).
- **이번 배포 고유의 발동 신호**: §7-2 의 **무한 거절 루프**가 라이브에서 관측되면(같은 고객·같은 카트의 `PRICE_MISMATCH` 거절이 반복) → 데이터·앱 원인을 찾기 전에 **`PAYMENT_PRICE_MODE=off`** 로 먼저 내린다. 품절 게이트는 유지된다.

### 18-2. 중단 기준

- ② 기준선 ⓐ 에 위반이 **1건이라도** 있으면 멈추고 보고한다(이미 일어난 사고다).
- ② ⓑ(self-approved override)가 **0 이 아니면** ④ 의 사람 판단 없이 ⑦ 로 가지 않는다.
- **③ Rules 가 없으면 ⑦(enforce)로 넘어가지 않는다** (승인 요건이 집행되지 않는 값을 권위로 쓰게 된다).
- ⑤-b 에서 **정상 결제가 잡히면** `enforce` 로 넘어가지 않는다.
- ⑤-b 에서 **그룹 수 상한 초과 기록이 1건이라도** 나오면 멈춘다(§6-2 의 도달 불가 가정이 틀렸다).
- ⑤-b 에서 **유령 ref(`optionGroups` 문서 부재)** 가 나오면 데이터를 먼저 고친다.
- **⑥(앱)가 라이브가 아니면 ⑦ 로 넘어가지 않는다**(무한 거절 루프).
- ⑦ 의 **거절 1건 실측을 못 했으면** 전환이 끝난 것으로 보지 않는다.
- ⑧ 의 정상 결제(옵션 포함)가 실패하면 **즉시 비상 정지** 후 보고.

---

## 19. 테스트 / 가드

### 19-1. 교차 골든 (이 task 의 핵심 가드 — 선행 R4 패턴)

Dart 테스트와 `functions npm test` 가 **같은 파일**을 읽는다. 한쪽만 바뀌면 깨져 **대조가 강제된다.**

- `test_fixtures/option_availability_contract.json` **신규** — active=false / 그룹 disabled / 항목 disabled(**composite `{groupId}_{itemId}`**) / ref scope 3종 / brandId 부재 / 그룹 문서 부재 / 항목 부재 / required 미충족 / single 다중 선택 — **최소 12 케이스**
- `test_fixtures/cart_pricing_contract.json` **신규** — 옵션 없음 / 단일 옵션 / 다중 옵션 / **음수 `priceDelta`** / quantity>1 / 같은 메뉴 다른 옵션 2줄 / `priceOverride` approved / `priceOverride` pending(= 마스터 가격) / 매장 직영 메뉴 / 0원 메뉴 — **최소 10 케이스**
- `test_fixtures/menu_visibility_contract.json` **확장** — `optionGroupRefs` 를 기대값에 추가(기존 8 케이스 전부)
- `test_fixtures/qoin_cart_contract.json` **확장** — **item 레벨 키 집합**(`selectedOptions` 의 `groupId/groupName/itemId/label/priceDelta` 포함)을 고정. §1-5 의 거짓 타입이 다시 생기지 않게 한다

### 19-2. grep 가드 (`test/.../payment_price_guard_test.dart` 신규)

1. `priceDelta` 를 **합산**하는 코드가 Dart 쪽 `cart_pricing.dart` **1곳**에만 있다 (`menu_item_detail_page.dart` 의 중복 계산이 제거됐다)
2. `priceDelta` 합산이 TS 쪽 `cartPricing.ts` **1곳**에만 있다
3. `"{groupId}_{itemId}"` composite 조립이 Dart `option_availability.dart` · TS `optionPricing.ts` **각 1곳**에만 있다
4. `optionGroupId` / `optionId` 문자열이 `functions/src/` 에 **0건**이다 (§1-5 재발 방지)
5. `priceOverride` 를 읽는 TS 코드가 `menuVisibility.ts` **1곳**에만 있다 (승인 분기의 복제 금지)
6. `as int?` 형태의 금액 cast 가 `lib/data/models/` 에 **0건**이다 (§1-7 재발 방지)
7. `lineTotal ~/ quantity` 류 단가 역산이 **`quick_reorder_section.dart` 밖에 0건**이다(허용 목록 1건, 사유 주석 필수)
8. **허용 목록**: 점주 매출 집계(`owner_sales_page`)는 주문 문서를 읽을 뿐 판정이 아니다 — 1·2번의 예외로 **명시**한다

### 19-3. functions 단위

- 금액 게이트: 통과 1 / §4-3 ①~⑥ 각 위반 1 / 옵션 사유 6종(missing·disabled·inactive·notInRefs·requiredEmpty·multiInSingle) / 읽기 실패 / 상한 초과 = **최소 16 케이스**
- **거절 경로에서 `confirm` 이 호출되지 않음**을 주입 mock 으로 단언 (R5)
- `shadow` 에서 **주문 문서가 클라 값으로 쓰인다** / `enforce` 에서 **서버 값으로 쓰인다** (R8 — shadow·enforce 가 쓰는 문서가 다르다)
- 모드 `off`/없음/모르는 값 → **옵션 그룹을 읽지 않는다**(reader mock 호출 0회로 단언)
- §8 의 플래그 조합(게이트 `off` + 가격 `enforce`) 처리가 **조용히 통과하지 않는다**

### 19-4. 양성 대조 (원칙 5)

- 에뮬레이터 E2E: **금액을 일부러 틀린 호출**이 ⓐ `shadow` 에서 기록 1건을 남기고 결제가 성립 ⓑ `enforce` 에서 거절되고 confirm 이 호출되지 않음
- 라이브: ⑥ 전환 직후 거절 1건 유도 — **런북 단계**이며 확인 전까지 전환 미완료

### 19-5. Rules 하네스

- 13-7 🔴 2행: `menuOverrides` **create** 에서 `status: 'approved'` / `approvedAt` / `approvedBy` 거부 **각 1건**
- **회귀**: 점주의 정상 override 제출(`status: 'pending'`)이 여전히 허용된다 / brandHolder·admin 의 승인 update 가 여전히 허용된다 — **막다가 정상 제출까지 막으면 안 된다**

### 19-6. 회귀

- 옵션이 붙은 정상 결제가 성공한다(**불변식**)
- `option_repository_impl` 추출 전후로 메뉴 상세 옵션 목록이 **동일**하다
- 선검증 읽기 실패 시 결제가 **진행**된다
- `cart_pricing.dart` 통합 후 카트 합계·담기 금액이 **기존과 동일**하다

---

## 20. 작업 분배

### designer — **필요하다. developer 보다 먼저.**

- **산출물**: `docs/tasks/payment_price_authority/design.md`
- 전달 사항:
  1. **§9-3 의 DQ1~DQ6 에 답한다.** 특히 DQ1(주 버튼이 실제로 복구되는 동작인가)은 **돈이 멈추는 오탐의 유일한 탈출구**다.
  2. 선행 design **§2 표면 인벤토리에 사실 5·6 행을 추가**한다(§14 를 옮기는 것이 아니라 더한다). ⓐⓑⓒ 를 전부 채운다.
  3. 선행 design §3.1 표에 사유 **2행을 추가**한다(헤드라인·본문·보조본문·메뉴목록·주버튼·보조버튼). 돈 줄(§3.4) 적용 여부도 정한다 — **가격 거절은 confirm 전이므로 청구가 없다**.
  4. **재가격 알림 UI**(DQ3) — 카트·체크아웃 어디에서 어떻게 알리는가. 금액이 조용히 바뀌는 것은 그 자체가 사고다.
  5. 선행 design D2("지목 + 돈 + 다음 행동") · D4(서버 문자열 비보간) · D5(전부 열거) 를 잇는다.
  6. ⚠️ **"조작/비정상/위조" 를 문구에 쓰지 않는다.**

### developer

- **§13-8 의 Rules 변경은 확정 항목이다** (설계가 실태를 확인했다 — 다시 조사하지 않는다). 선행 `firestore.rules.stage4` 패턴처럼 **단계별 Rules 파일을 저장소에 둔다**(HEAD 를 그대로 배포하면 뒤 단계가 같이 나간다 — 선행 런북 §0-2 의 사고 경로).
- 구현 순서 추천:
  1. `MergedMenu` 에 `optionGroupRefs` 추가 + 기존 골든 확장 (가장 싸고 뒤를 전부 가능하게 한다)
  2. Dart `option_availability.dart` **추출** + `cart_pricing.dart` 신규 + 교차 골든 fixture 작성 (**TS 보다 먼저** — 포팅의 기준이 Dart 다)
  3. TS 포팅 2개 + functions 단위
  4. `GateReader` 에 옵션 그룹 포트 추가 + 2-c 삽입 + 모드
  5. `orderBuilder.ts` 거짓 타입 수정 + R8
  6. 선검증 확장(R9) + 앱 UI
  7. 감사 CF + admin 카드
  8. `onMenuPriceWritten` 트리거 + `priceHistory` Rules 1줄(R16)
  9. grep 가드 + Rules 하네스
- **구현 후 확인 1건 (`operations.md §6`)**: `PAYMENT_PRICE_MODE` 는 `operations.md §6.1` 표에 이미 등재돼 있다. 구현이 끝나면 **그 행이 실제와 맞는지** 확인한다 — 값이 **어느 파일/코드에서 읽히는지**(`defineString("PAYMENT_PRICE_MODE", {default:"off"})` 가 `verifyTossPayment.ts` 에 있고 `resolveGateMode` 와 같은 폴백을 타는지), §6.2 의 바꾸는 명령이 실제 키 이름과 맞는지. 어긋나면 `operations.md §6` 을 고친다(단일 진실원이므로 spec 이 아니라 그쪽을 맞춘다).
- 재사용할 기존 구조: `GateReader`/`makeFirestoreGateReader`(getAll 패턴) · `recordGateRejection` · `resolveGateMode` · `buildRejectionMessage`/`TOKEN_ID_RE` · `PaymentFailure` · 임시 CF + admin 카드 진입 경로(선행 `implementation.md §11`) · dry-run 리포트 규약
- 주의할 레이어 규칙: §15 "레이어 규칙 주의" 3항목
- **금지**: `CartItemEntity`/`CartEntity` 에 신뢰 필드 추가 · 판정 함수 신설 · `option_repository_impl` 에 판정을 남긴 채 TS 만 작성 · `presentation` 에서 직접 재계산

### tester

- 주요 검증 기준: §19 전항목 + §22 완료 기준
- 반드시 확인할 예외 케이스:
  - **옵션이 붙은 정상 결제가 성공한다** (FAIL 이면 배포 중단)
  - 음수 `priceDelta` 가 정확히 반영된다
  - 같은 메뉴를 옵션만 달리해 2줄 담은 카트 (메뉴 읽기는 1회, 금액은 2줄 별도)
  - **`shadow` 가 주문 문서를 바꾸지 않는다** / `enforce` 는 서버 값을 쓴다
  - 거절 경로에서 **confirm 미호출**
  - 가격을 바꾼 직후 담아 둔 카트로 결제 → 거절 → **주 버튼으로 실제 복구되는가**(무한 루프 없음)
  - 모드 `off`/없음/모르는 값에서 **옵션 그룹 읽기 0회**
  - 게이트 `off` + 가격 `enforce` 조합이 조용히 통과하지 않는다
  - 추출 전후 메뉴 상세 옵션 목록 동일(회귀)
  - 감사 도구가 **고치지 않는다**
- **2회 호출**: 구현 완료 후 1회 + 배포(⑥ enforce) 후 1회

---

## 21. 사용자 결정 (Q) — **전건 확정** (2026-10-27)

> **Q1~Q8 전부 확정됐다(전건 설계자 추천안).** 아래 요약표가 확정값이고, 각 Q 의 상세 표는 **근거 보존용**으로 남긴다. 확정이 무엇을 바꾸는지는 요약표의 "반영" 열을 본다.

| Q | 확정 | 반영 |
|---|---|---|
| **Q1** | **ⓐ 전체 재계산** (옵션 단가 포함) | §4·§6·R3. 옵션 그룹 `getAll` +1 round-trip |
| **Q2** | **ⓐ 거절 + 재가격 복구 경로**, 오차 0원 | §7-2·R9. 서버 견적(quote)은 P1 후속 |
| **Q3** | **ⓑ `PAYMENT_PRICE_MODE` 신설** (품절 게이트와 독립) + 조합 처리 ⓐ | §8·R13. 운영은 `operations.md §6` |
| **Q4** | **ⓐ 금액 필드만** 서버가 다시 만든다 | §10·R8. 이름·라벨은 클라 값. ⓑ 는 P3 |
| **Q5** | **ⓐ Tier 1 감사만** | §12·R14. Tier 2 는 P4(가격 이력 선행) |
| **Q6** | **ⓒ 토큰은 id 만, 숫자는 카트 재가격** | §9·§4-3 토큰 문법 불변. designer DQ2/DQ3 |
| **Q7** | **ⓐ 트리거 `onMenuPriceWritten` 로 가격 변경 이력** | §13-1. 쓰기 경로 비간섭(아래 R16) |
| **Q8** | **ⓑ 현행 유지 + 명시 + 후속 등재** | §4-4·§13-8. 건수는 감사 ②-ⓒ 가 측정 → P2 |

> Q7 확정으로 **R16** 이 추가된다: `onMenuPriceWritten` Firestore 트리거가 `basePrice`/`priceOverride`/`optionGroups.items[].priceDelta` 변경을 `priceHistory/{autoId}`(`changedBy`/`before`/`after`/`targetId`/`scope`/`changedAt`)에 남긴다. 트리거여야 하는 이유는 §13-1(클라이언트 직접 쓰기도 포착 — Rules 로는 이력을 강제할 수 없다). Rules 1줄(`read: isAdmin()`, `write: false`) 추가. 쓰기 경로는 건드리지 않는다.

### Q1. 옵션 단가를 서버가 재계산하는가 — **이 task 의 범위를 가르는 결정**

| 안 | 내용 | 대가 |
|---|---|---|
| **ⓐ 전체 재계산 (추천)** | `basePrice` + 옵션 `priceDelta` 전부 서버 계산. `expected == amount` 정확 일치 | 옵션 그룹 **추가 읽기 m ≈ 3~6 / 결제 1건**(1 round-trip, 일 1,000건에 약 $0.004/일). 옵션 판정 함수 추출·포팅·교차 골든이 필요(이 task 분량의 절반). **구멍이 완전히 닫힌다** |
| ⓑ basePrice 만 + 하한 검증 | `amount >= Σ basePrice × quantity` 만 본다 | 1원 공격은 막힌다. **그러나 옵션 금액 전체가 열려 있다** — 옵션이 붙은 주문에서 공격자는 옵션값을 내지 않는다. 샷 추가·사이즈업이 많은 메뉴일수록 구멍이 크다. **"안 하면 구멍이 옵션으로 옮겨갈 뿐" 이 그대로 현실이 된다.** 읽기 추가 0 |
| ⓒ basePrice 만 + 정확 일치 | `amount == Σ basePrice × quantity` | **옵션이 붙은 정상 결제가 전부 거절된다.** 성립하지 않는다. 기록용으로만 적는다 |

**추천 ⓐ.** 근거: ⓑ 는 구멍을 옮기는 것이고, 옵션까지 닫는 비용이 **읽기 m 과 함수 1개 추출**이며 그 둘이 모두 싸다. ⓑ 를 택하면 N1 의 후속으로 "옵션 금액 권위화" 가 또 필요해지고, 그때 이 task 의 모든 구조(추출·포팅·골든·런북)를 다시 만들어야 한다.

### Q2. 결제 도중 / 담은 뒤 가격이 바뀐 경우를 어느 쪽으로 처리하는가

> 허용 오차 자체는 **0원**이 맞다(§4-3 — 금액이 전부 int 이고 반올림이 없다. 오차는 그만큼의 공격 여유다). 결정이 필요한 것은 **시점 차이**다.

| 안 | 내용 | 대가 |
|---|---|---|
| **ⓐ 거절 + 재가격 복구 경로 (추천)** | 0원 오차로 거절. **R9(체크아웃 진입 재가격)와 거절 화면의 복구 버튼이 필수 쌍** | 창이 "체크아웃 진입 ~ confirm"(수십 초)으로 줄고, 그 안에 걸린 고객은 **한 번 더 눌러 복구**한다. 가격을 바꾼 점주가 그 순간 결제 중인 고객 1~2명을 되돌리게 한다. **구현 분량이 R9 만큼 늘어난다** |
| ⓑ 서버 견적(quote) 발급 | 결제창 **전**에 `quotePrice` CF 가 금액을 계산해 짧은 유효기간의 견적을 발급(Firestore 저장 또는 서명). verify 는 견적과 비교 | 시점 차이가 **구조적으로 사라진다**(고객이 본 금액이 서버가 보증한 금액이다). 대가: **새 CF + 새 상태 + 만료 처리 + 멱등**. 견적을 클라이언트가 들고 오므로 **저장 또는 서명이 없으면 "클라이언트 선언값" 문제가 재발**한다. 분량이 이 task 를 1.5배로 만든다 |
| ⓒ `amount >= expected` 허용 | 가격이 **내렸을** 때만 통과(고객이 더 냄) | 구현이 가장 싸다. 대가: **정상 고객을 과다 청구하고 서버가 그것을 공인한다.** 가격이 **오른** 경우는 여전히 거절이므로 루프 문제도 남는다. 추천하지 않는다 |

**추천 ⓐ.** ⓑ 는 올바른 방향이지만 지금 지불할 분량이 아니다. ⓐ 로 창을 줄이고 `delta` 분포(§7-3)로 실제 빈도를 **측정한 뒤** ⓑ 의 필요를 판단하는 것이 순서다. ⓑ 를 후속으로 등재한다.

### Q3. `PAYMENT_GATE_MODE` 를 공유하는가, 새 플래그를 두는가

| 안 | 내용 | 대가 |
|---|---|---|
| ⓐ 공유 | 같은 플래그가 품절 게이트와 금액 게이트를 함께 켠다 | 플래그 1개, 런북 짧다. 대가: **"품절은 켜고 가격은 끈다" 가 불가능하다.** 금액 게이트가 오탐을 내면 비상 정지가 **선행 배포의 성과(품절 게이트)까지 끈다.** shadow 관측 창도 공유할 수 없어, 이미 enforce 인 품절 게이트를 shadow 로 **내렸다 올려야** 한다 |
| **ⓑ `PAYMENT_PRICE_MODE` 신설 (추천)** | 독립 3상태. 없거나 모르는 값은 `off` | 독립 롤아웃 + **독립 비상 정지**. 대가: 플래그 2개, 관측 창 2개, 런북이 길어진다. 그리고 **조합 처리를 명시해야 한다**(§8 — 게이트 `off` + 가격 `enforce` 가 조용히 무효가 되는 것을 막는 장치가 필수) |

**추천 ⓑ.** 근거: 두 게이트의 **오탐 양상이 다르다.** 품절 오탐은 고객이 그 메뉴를 빼면 복구되지만, 금액 오탐은 카트 전체가 막히고 §7-2 의 루프 위험이 있다. 비상 정지 단위가 같아야 할 이유가 없다. 다만 ⓑ 는 §8 의 조합 처리(추천 ⓐ: 가격 모드가 메뉴 읽기를 직접 수행)를 **반드시** 함께 구현해야 한다.

### Q4. 주문 문서를 서버가 어디까지 다시 만드는가

| 안 | 내용 | 대가 |
|---|---|---|
| **ⓐ 금액 필드만 (추천)** | `unitPriceWithOptions`/`lineTotal`/`subtotal`/`totalPrice` | 돈에 영향 있는 전부를 덮는다. 이름·라벨은 클라 값(표시 전용) |
| ⓑ 이름·옵션 라벨까지 | 메뉴명·옵션 라벨도 문서에서 다시 만든다 | 추가 읽기 0(이미 읽은 문서에 있다). 대가: **고객이 담을 때 본 이름과 다른 이름이 영수증·Log 에 박제될 수 있다**(그 사이 점주가 이름을 바꾸면). 또 메뉴명 조작으로 점주를 혼란시키는 경로가 닫힌다 |

**추천 ⓐ.** 이름은 돈에 영향이 없고, ⓑ 는 "고객이 본 것과 기록이 다르다" 를 새로 만든다. 이름 조작은 **점주가 실물을 만들 때 드러나므로** 금액 조작과 위험이 다르다. ⓑ 를 원하면 후속으로 분리한다.

### Q5. 소급 감사의 범위

| 안 | 내용 | 대가 |
|---|---|---|
| **ⓐ Tier 1 만 (추천)** | 주문 문서 내부 정합성 4개 불변식. 읽기 전용 dry-run | §0 의 공격을 **반드시** 잡는다. 오탐 0. 비용 = 주문 1건당 1 read. **기준선 측정이 enforce 의 전제**다(§12-2) |
| ⓑ 범위에 넣지 않는다 | 감사 도구를 만들지 않는다 | 분량이 줄고 임시 자산이 없다. 대가: **"이미 일어났는가" 를 영구히 모른다.** enforce 이후에 발견되면 "원래 있던 것" 과 구분할 수 없다 |
| ⓒ Tier 2 까지 | 현재 메뉴·옵션 문서와 대조 | **결론이 나오지 않는다** — 가격 변경 이력이 없어 정상 가격 변경이 전부 위반으로 보인다(§12-1). Q7 ⓐ 이후에만 의미가 있다 |

**추천 ⓐ.** Tier 1 은 싸고 오탐이 0 이며, 기준선이 없으면 ⑥ 전환의 성과를 증명할 수 없다.

### Q6. 거절 토큰에 **금액**을 실을 것인가 (고객 문구와 직결)

| 안 | 내용 | 대가 |
|---|---|---|
| **ⓐ 싣지 않는다 (추천)** | 토큰은 `[PRICE_MISMATCH:menuItemId...]` 만 | 선행 §15.1·D4 를 **문법 변경 없이** 잇는다. 화면은 "가격이 바뀌었어요" + 카트의 메뉴 이름. 대가: **고객이 얼마가 달라졌는지 모른다** |
| ⓑ 서버 계산액을 싣는다 | 토큰 문법에 숫자 필드를 더하고 화면이 "17,000원 → 16,500원" 을 그린다 | 고객이 납득한다. 대가: **선행 §15.1 문법을 확장**해야 하고(id 전용 문법이다), D4 에 "정수 검증 후 포맷" 예외가 생긴다. `details` 가 실기기에서 Map 으로 안 오는 기존 문제(backlog)도 그대로 적용된다 |
| ⓒ 숫자를 카트 재가격으로 보여준다 | 토큰은 ⓐ. 화면은 **카트로 돌아간 뒤** 재가격 결과로 변동을 보여준다 | 문법 변경이 없고 숫자도 보여준다. 대가: 숫자가 **거절 화면이 아니라 카트에서** 보인다(한 화면 늦다) |

**추천 ⓒ.** 토큰 문법을 건드리지 않으면서 DQ2 의 요구를 만족시킨다. designer 가 DQ1~DQ3 과 함께 판단한다.

### Q7. 가격 변경 이력을 이번에 남기는가 (`audit_trail.md` §4-1 — **기본값은 "남긴다"**)

| 안 | 내용 | 대가 |
|---|---|---|
| **ⓐ 트리거 1개로 남긴다 (추천)** | `onMenuPriceWritten` Firestore 트리거가 `basePrice`/`priceOverride`/`optionGroups.items[].priceDelta` 변경을 `priceHistory` 에 남긴다 | **쓰기 경로를 하나도 건드리지 않는다**(트리거는 클라이언트 직접 쓰기도 포착한다 — Rules 로는 이력을 강제할 수 없다). 오탐 분석·분쟁 대응·Tier 2 감사가 가능해진다. 대가: 메뉴·옵션 쓰기당 트리거 1회 + 신규 컬렉션 + Rules 1줄(`read: isAdmin()`, `write: false`). 이 task 분량이 늘어난다 |
| ⓑ 남기지 않고 사유를 적는다 | 후속(N3 계열)으로 등재 | 분량이 줄어든다. 대가: **과거는 복원할 수 없다** — 미루는 동안의 구간은 영구히 못 본다(§17 마지막). 그리고 이 task 가 가격을 권위로 쓰기 시작하는 **바로 그 시점**에 "그때 얼마였나" 를 답할 수 없다 |

**추천 ⓐ.** 근거: 이 task 는 가격을 **돈의 권위**로 승격시킨다. `audit_trail.md` §4-1 은 돈·정책 값을 바꾸는 기능에서 **설정 변경 이력을 기본값**으로 두고, "거래 이력이 있다고 설정 변경 이력이 있는 것이 아니다" 를 못박았다. 주문의 금액 박제는 **거래 이력**이고 가격 변경 이력이 아니다. 트리거 방식이면 쓰기 경로를 안 건드리므로 **지금이 가장 싸다.**

### Q8. store-scope 옵션 가격이 가격 승인을 우회하는 문제 (§4-4)

> 전제: **§13-8(승인 요건이 Rules 로 집행되지 않는다)은 Q 가 아니라 이 task 의 확정 항목**이다 — 배포 ② 에서 닫는다. Q8 은 **그것을 닫은 뒤에도 남는** 우회로다. 실태 건수는 ①-ⓒ 가 측정한다.

| 안 | 내용 | 대가 |
|---|---|---|
| **ⓑ 현행 유지 + 명시 + 후속 등재 (추천)** | 서버는 문서값을 그대로 권위로 쓴다. spec 과 `data_ownership.md` 에 우회로를 명시 | 이 task 의 범위를 지킨다. 대가: **가맹점이 승인 없이 옵션 가격을 바꾸는 것을 서버가 공인한다**(현행 동작과 같지만, 이제 "권위" 라는 이름이 붙는다) |
| ⓐ 옵션 가격도 승인 대상으로 | store-scope 옵션 그룹의 `priceDelta` 변경에 승인을 요구 | 가격 승인 정책이 일관된다. 대가: **가격 승인 흐름 전반**(제출·심사 UI·브랜드 승인 큐)을 건드린다. 이 task 의 2배 분량이고 designer 범위가 크게 늘어난다 |
| ⓒ 브랜드 메뉴가 store-scope 그룹을 참조하는 것을 금지 | ref scope 제약(현재 클라이언트에만 있다: `menu_item_repository_impl.dart:384-393`)을 서버로 올린다 | 우회로가 닫힌다. 대가: **기존 데이터에 그런 참조가 있으면 그 메뉴들이 전부 결제 불가**가 된다 → 마이그레이션·실태 조사가 선행돼야 하고, 지금은 **그 수를 모른다** |

**추천 ⓑ.** 단 ⓒ 의 실태(브랜드 메뉴가 store-scope 그룹을 참조하는 건수)는 **감사 도구에 1줄로 함께 넣어 측정**할 수 있다. 수를 알면 다음 판단이 싸진다 → developer 에게 그 집계를 요청한다.

---

## 22. 완료 기준

- [ ] Q1~Q8 이 모두 결정되고 spec 에 반영됐다
- [ ] **옵션이 붙은 정상 결제가 성공한다** (불변식 — 이 항목이 FAIL 이면 배포 중단)
- [ ] `amount: 1` + 17,000원어치 `cart.items` 호출이 **거절되고 confirm 이 호출되지 않는다** (이 task 의 존재 이유)
- [ ] 금액 판정이 **문서에서 다시 만든 값**으로 이뤄진다 — 클라 선언값을 권위로 쓰는 비교가 판정식의 **④⑤⑥ 에 없다**
- [ ] `CartItemEntity`/`CartEntity` 에 신뢰 필드가 **추가되지 않았다** (F1 판단)
- [ ] 사실 5·6 의 판정 함수가 **Dart·TS 각 1개**이고 **교차 골든 2종**이 양쪽 테스트에서 통과한다
- [ ] 옵션 판정이 `option_repository_impl` 에서 **추출**됐고, 추출 전후 메뉴 상세 옵션 목록이 **동일**하다(회귀)
- [ ] **§13-7 상시 항목** — 금액 판정 입력 필드마다 `create`·`update` 양쪽을 교차 확인했고, Rules 하네스에 **create 거부 케이스 + 정상 제출 허용 회귀**가 있다
- [ ] **모드가 없거나 모르는 값일 때 `off` 로 떨어지고, 옵션 그룹 읽기가 0회다**
- [ ] **게이트 모드 `off` + 가격 모드 `enforce` 조합이 조용히 통과하지 않는다** (§8)
- [ ] **enforce 전환 직후 거절 1건을 실제로 유도해 확인했다** — 확인 없이는 전환 완료가 아니다 (원칙 5)
- [ ] **shadow 가 주문 문서를 바꾸지 않고, enforce 는 서버 재계산값을 쓴다** (R8)
- [ ] **감사 기준선 3종(ⓐ 주문 Tier 1 · ⓑ self-approved override · ⓒ store-scope ref)이 enforce 전에 측정되고 기록됐다.** 각각 0 이거나, 0 이 아닌 경우 사람이 판단한 처리 결과가 기록됐다
- [ ] **🔴 §13-8 — 점주가 `menuOverrides` 에 `status: 'approved'`·`approvedAt`·`approvedBy` 를 쓸 수 없다** (create·update 양쪽, 하네스 각 1건). 그리고 **정상 제출(`pending`)과 brandHolder·admin 승인은 여전히 허용된다**
- [ ] **거절 화면의 주 버튼이 실제로 복구된다** — 같은 거절이 반복되지 않는다 (§7-2 무한 루프 없음)
- [ ] **체크아웃 진입 재가격이 동작하고, 읽기 실패 시 결제를 막지 않는다** (R9 + 선행 §8.2)
- [ ] 결제 실패 화면에 **원시 예외·서버 원문·미해석 id 가 0건** (선행 D4 가드 유지)
- [ ] 거절 기록에 **`delta` 부호와 라인별 차이**가 남는다 (§7-3 — 오탐 탐지의 유일한 수단)
- [ ] **가격 변경 이력(`priceHistory`)이 실제로 쓰인다** (R16 — `onMenuPriceWritten` 트리거, 쓰기 경로 비간섭)
- [ ] **모드 스위치용 UI·admin 토글이 없다** (서버 설정 전용) · `operations.md §6` 의 `PAYMENT_PRICE_MODE` 행이 구현과 일치한다
- [ ] 표면 인벤토리: **design §2 에 사실 5·6 행이 추가**되고 ⓐⓑⓒ 가 전부 채워졌다
- [ ] grep 가드 8항목 통과 (허용 목록 1건에 사유 주석)
- [ ] `deploy_runbook.md` 가 있고 **⑥(앱)가 ⑦(enforce)보다 먼저인 이유**가 머리말에 적혀 있다 (선행과 순서가 반대다)
- [ ] 화면 문구에 **"조작/비정상/위조" 가 0건**이고 마크다운 백틱이 0건
- [ ] 문서 갱신: `audit_trail.md`(가격 이력 = Q7 ⓐ 확정, `priceHistory` 등재) · `data_ownership.md`(§4-4 우회로 + 신규 컬렉션 `priceHistory`) · `role_flows.md` · `operations.md §6`(`PAYMENT_PRICE_MODE` 행 실측 반영) · `backlog.md`(N1 완료, N5 사유 갱신, P1~P5 등재)
- [ ] `design.md` / `implementation.md` / `test_report.md` 작성 완료
- [ ] `flutter analyze` 무경고 / `flutter test` / `functions npm test` 전건 통과
- [ ] FAIL 없음 또는 후속으로 분리

---

## 23. `role_flows.md` / `entity_lifecycle.md` 영향

- **`role_flows.md`**: 고객 "결제 / 주문 생성"(`:118`) 행에 **거절 1갈래 추가**(금액·옵션 사유). `:208` 의 "결제는 반드시 CF 경유" 원칙은 변하지 않는다 — **강화된다**. admin 에 감사 도구 1행(임시, ⑨ 에서 제거).
- **`entity_lifecycle.md`**: **order status 전이는 변하지 않는다.** 새 status 가 없고, 거절은 **주문이 생성되기 전**에 일어난다(전이가 아니라 **진입 차단**이다). §2.2 에 한 줄만 보강한다 — "`→ paid` 진입 조건에 서버 금액 일치가 추가된다". MenuItem·MenuOverride lifecycle 의 `priceOverride` 승인 규칙은 변하지 않는다(§4-4 의 우회로는 **기존 사실**이고, Q8 ⓑ 면 §5.5 에 1줄로 명시한다).

---

## 24. 이 spec 이 등재하는 후속 과제 (`backlog.md`)

| # | 과제 | 근거 |
|---|---|---|
| P1 | **서버 견적(quote) 발급** — 시점 차이를 구조적으로 제거 | Q2 ⓑ. `delta` 분포 측정 후 필요를 판단 |
| P2 | **가격 승인 정책의 일관화** — store-scope 옵션 가격 | Q8 ⓐ/ⓒ. 감사 도구가 측정한 참조 건수가 착수 근거 |
| P3 | 주문 문서의 **이름·라벨도 서버가 구성** | Q4 ⓑ |
| P4 | **Tier 2 소급 감사** (가격 이력 대조) | §12-1. Q7 ⓐ 이후에만 가능 |
| P5 | Rules 에 금액 필드 **타입·범위 제약** (`basePrice >= 0`, `priceDelta` 정수) | §13-7 마지막. 현재 Rules 에 타입 제약이 전무하다 |
| N5(갱신) | `quick_reorder_section` 단가 역산 제거 | §11 — **돈 경로는 체크아웃 재가격이 덮었다.** 남은 것은 홈 화면의 **표시** 정확성뿐이므로 **우선도를 낮춘다** |
