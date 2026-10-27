# payment_price_authority 테스트 리포트 (T-1: 구현 직후 · 코드/에뮬레이터)

## 테스트 일시

- 2026-10-27
- 대상 커밋: `e9b7546` (단일 커밋)
- 범위: T-1 (코드·로컬 에뮬레이터). **T-2 (라이브 ⑦ 거절 실측 · ⑧)는 배포 전이라 미실행** — 아래 "배포 후 수동 확인 목록".

---

## 테스트 방법

착수 전 요청자가 재실행해 확인한 것은 반복하지 않았다 (`flutter analyze` 0 / `flutter test` 884 / `functions` 310 / `test_rules` 457/457 / 구 Rules 대조 PPA-1·PPA-2 12건 FAIL / 교차 골든 변이 39 중 38). 그 위에서 아래를 직접 수행했다. 모든 변이는 **scratchpad 복사본**에서만 했고 저장소는 무변경이다 (`git status` clean).

| # | 방법 | 결과 |
|---|---|---|
| M-1 | spec·design·implementation·선행 task 통독, 가격 경로(Dart·TS) 정적 대조 | 아래 항목별 |
| M-2 | **TS 변이 실험** (`functions` 복사본, `npm test`) 22종 — 모드 off, 수량 경계 4, 승인 분기 2, 옵션 판정 9, 어댑터 경로·brandId 3, c4, enforce 서버값, refs·scope | 17 검출 / 생존 5 (**4 = F-03**, 1 = 동치 변이: enforce 가 서버값을 안 써도 정상 경로에선 클라 값과 같아 관측 불가 — developer 보고와 동일) |
| M-3 | **실 Firestore(에뮬레이터)로 `handleVerifyTossPayment` 전체 호출** — 실제 `makeFirestoreGateReader` + 3 scope(master/brand/store) 옵션 그룹 + 승인 override + pending override + W2 문서 + 개인 매장. 모드 조합 4(`enforce/enforce`, `off/enforce`, `shadow/enforce`, `enforce/shadow`). **정상 경로 호출에 입력 금액만 다르게 준다**(공격 스크립트 아님) | 12/12 OK |
| M-4 | **Rules 변이** (`test_rules` 복사본, 하네스 457건) 10종 — owner create 의 각 절, owner update 허용 목록 | 9 검출 / **생존 1** (F-05) |
| M-5 | **Dart 가드 변이** (프로젝트 복사본, `payment_price_guard_test`) 10종 — 금지어·백틱·원 단위·success·hex | 8 검출 / **생존 2** (F-05) |
| M-6 | **Dart UI 실험** (임시 위젯 테스트, 실험 후 제거) — 루프 차단 서명 리셋, 수량 병합 | 2건 재현 (F-01, F-02) |
| M-7 | 표면 인벤토리 역방향 grep (`unitPriceWithOptions\|lineTotal\|priceDelta\|basePrice\|priceOverride\|subtotal\|totalPrice` 앱·서버 전수) | 표에 없는 행 (F-04) |
| M-8 | git status 로 저장소 무변경 확인 | clean |

재현 산출물: `/private/tmp/claude-503/-Users-Byeonguk-Developer-OrderApp/06fb23cb-93d5-476b-84e8-c85485beb04a/scratchpad/` 의 `price_emu.mjs`(M-3), `mut/mut.sh`(M-2), `rmut/rm.sh`(M-4), `dmut/dm.sh`(M-5), `dmut/test/zz_t1_test.dart`·`zz_t2_test.dart`(M-6).

---

## 전체 결과

- **PASS: 14개**
- **FAIL: 5개** (중 2 · 낮음 3)
- **보류: 8개**
- implementation §8 판정 4건: **수용 3 / 일부 FAIL 1** (#2 의 수량 규칙 — 서버 규칙은 수용, 앱 쪽 병합 상한 부재가 새 오탐을 만든다)

### 배포해도 되는가

> **② 감사 ~ ⑥ 앱: GO (단 ⑥ 앱 빌드에 F-01 수정 포함 권장). ⑦ enforce: 조건부 NO-GO.**
>
> 가격 계산 자체는 견고했다 — 실 Firestore 로 3 scope 옵션·승인 override·W2·모드 조합 12건이 모두 정상 통과/기대 거절했고, Dart·TS 교차 골든은 양방향 변이를 잡는다. 다섯 번째 구멍의 Rules 는 owner create·update 각 절을 변이로 뒤집어도 하네스가 잡는다. **문제는 "정상 결제를 막는" 쪽의 좁은 틈 두 개**다: (1) 카트 라인 병합이 99 를 넘길 수 있는데(`60+60=120`) 서버는 100 이상을 `PRICE_MISMATCH` 로 거절하고 앱 재가격은 이를 알아보지 못한다(F-01) (2) 루프 차단 서명이 카트가 비워져도 안 지워진다(F-02). 둘 다 **탈출구(카트 비우기)는 있어 영구 정지는 아니지만**, 앱 변경이므로 **⑥ 빌드에 넣어야** enforce 이전에 닫힌다.
>
> **⑦ 의 조건**: ① F-01 수정이 담긴 앱이 배포돼 있을 것 ② **구버전 앱 비율 확인**(H-01 — 구버전은 `PRICE_MISMATCH` 를 몰라 갈래 C "주문 완료 여부 확인 필요" 를 보이고 재가격이 없다. 최소 버전 게이트가 코드 어디에도 없다) ③ ⑤-b shadow 에서 **brand-scope·store-scope 옵션이 든 정상 결제**가 한 건도 안 잡혔을 것 (F-03: 이 경로는 자동 테스트가 없다 — 내 M-3 가 일회성으로 확인했다).
>
> **"앱이 enforce 보다 먼저" 전제**: 복구 경로는 **코드에 있다** — 체크아웃 결제 탭 재가격(`checkout_page.dart` `_showPriceChanged`, 모드 무관), 카트 자동 적용(`refreshAndReprice`), 거절 화면 `최신 가격으로 다시 담기`(`_PriceMismatchBody._reprice`, 읽기 실패 시 pop 하지 않고 머문다). 그러나 이 전제를 **강제하거나 감지하는 장치는 없다**(런북의 순서 문장 + 사람) — 구버전 앱이 남아 있으면 H-01.

---

## FAIL 항목

### F-01 [중 · 새 오탐] 카트 라인 병합이 수량 99 를 넘긴다 — 서버는 거절하고 앱은 원인을 모른다

- 문제: 서버는 `quantity` 가 1~99 정수가 아니면 `PRICE_MISMATCH`(`unusable:'badQuantity'`)로 거절한다(`priceGate.ts` `MAX_LINE_QUANTITY`). 그런데 `CartLocalDataSource.addItem` 은 같은 (메뉴, 옵션) 라인을 만나면 `line.quantity + item.quantity` 로 **상한 없이 합친다**. `QuantityStepper`(1~99) 는 카트 화면의 +/- 만 막고, 병합 결과는 막지 않는다.
  - 재현 (M-6, 임시 테스트): 같은 메뉴를 60개 + 60개 담으면 카트 라인 `qty=120`. 서버 쪽 100 거절은 M-3(실 Firestore)에서 확인(`수량 100 거절`, 99 는 통과).
  - 결과: 결제 → `PRICE_MISMATCH` → 거절 화면 `최신 가격으로 다시 담기` → 앱 재가격은 **수량을 검사하지 않으므로** "달라진 게 없어요"(변형 N) → 카트로 돌아가 다시 결제 → **같은 거절**. 탈출구는 `카트 비우고 메뉴 보러가기` 뿐이고, 화면은 "가격이 바뀌었어요" 라고 **틀린 원인**을 말한다. `+` 버튼은 `value<max` 라 비활성이고 `-` 만 남아 21번을 눌러야 99 가 된다는 힌트는 어디에도 없다.
  - 현실성: 카페 앱에서 한 라인 100개 이상은 드물지만(단체 주문), 이 task 의 핵심 우려 "정상 결제를 막는 오탐" 의 전형이고 서버 규칙(§8-4)이 spec 에 없던 것을 구현자가 추가해서 생긴 불일치다.
- 위치: `lib/data/datasources/local/cart_local_data_source.dart` `addItem`(병합) · `lib/domain/usecases/validate_checkout_use_case.dart` `_reprice`(수량 미검사) · `functions/src/priceGate.ts` `parseLine`
- 제안 (택1 이상): ① `addItem` 병합 결과를 99 로 clamp (가장 싸다, 서버 규칙과 한 자리에서 맞는다) ② 재가격이 수량 위반을 `LineOptionIssue` 와 같은 방식으로 지목 ③ 서버 `badQuantity` 를 `PRICE_MISMATCH` 가 아닌 전용 사유로 (→ 사유 9종, design 변경). 어느 쪽이든 **수량 경계 교차 골든**(1·99·100·병합)을 추가 — 현재 Dart 쪽에 수량 규칙이 한 줄도 없다.
- 우선순위: **중** (앱 변경 → ⑥ 빌드 전)

### F-02 [낮음 · 루프 차단기] 재가격 서명이 카트 비움/결제 성공에서 지워지지 않는다

- 문제: `priceRepricedCartSignatureProvider` 는 `mark()` 만 있고 리셋이 없다(`grep` 전수: 쓰는 곳은 `payment_result_page.dart` 두 곳뿐). 카트 **구성이 바뀌면**(메뉴·수량·옵션) 서명 비교가 어긋나 자동 리셋되는 것은 맞다. 그러나 **한 번 재가격한 구성과 같은 구성을 나중에 다시 담으면**(결제 성공 후 "아메리카노 1" 재주문 — 가장 흔한 케이스) 서명이 남아 있어서 **첫 거절부터 변형 N**(재가격 버튼 없음)이 뜬다.
  - 재현 (M-6): 거절 → 재가격(서명 기록) → 카트 비움 → 같은 구성 새 라인 → 가격이 또 바뀐 상태로 거절 화면 → `reprice=false variantN=true`.
  - 영향: 영구 정지는 아니다 — 변형 N 의 `카트로 돌아가기`는 카트의 `결제하기` 탭 재가격으로 이어지고, `카트 비우고 메뉴 보러가기`도 있다. 같은 앱 세션 안에서 두 번째 가격 변경 + 같은 구성일 때만. 다만 설계(design P2)의 "재가격을 이미 한 번 적용했는데 같은 카트가 또 거절" 이 **다른 주문**에 새는 것이다.
- 위치: `lib/presentation/customer/cart/providers/checkout_validation_providers.dart` `PriceRepricedCartSignatureNotifier`
- 제안: 카트 stream 이 null(비워짐)이 되면 서명을 null 로 (`CartPriceChangesNotifier` 가 이미 같은 `ref.listen(cartProvider)` 패턴을 쓴다). 위젯 테스트에 "결제 성공 후 같은 구성 재주문의 첫 거절은 기본형" 추가.
- 우선순위: 낮음

### F-03 [중 · tester_guide 상시 항목] 금액 게이트의 실 어댑터 경로를 지키는 자동 테스트가 없다

- 문제: 단위 테스트는 `fakeReader` 만 쓴다. 아래 변이가 **전부 생존**했다(310건 전부 통과):
  | 변이 | 의미 | 결과 |
  |---|---|---|
  | `getOptionGroups` 의 store scope 경로를 `optionGroups/{id}` 로 | store-scope 옵션 그룹을 못 읽음 → 유령 ref → 선택 시 `missing` 거절 | 생존 |
  | brand scope 경로를 `optionGroups/{id}` 로 | 〃 | 생존 |
  | `verifyTossPayment` 가 `storeBrandId: null` 을 넘김 | **brand-scope 옵션 그룹을 전부 못 읽음 → brand 옵션이 든 모든 정상 결제 거절** | 생존 |
  | `MAX_LINE_QUANTITY` 99 → 98 | 수량 99 정상 결제 거절 | 생존 (경계 유효값 99 의 통과 단언이 없다) |
  선행 test_report 가 M-5 로 "어댑터가 어디서도 실행된 적 없다" 를 지적했던 것과 같은 공백이다. 코드는 맞다 — **M-3 에서 실 Firestore 로 3 scope·99·100 을 확인했다** — 하지만 회귀 방지 장치가 아니다.
- 위치: `functions/test/priceAuthority.test.mjs`(fake reader) · `functions/src/paymentGateReader.ts` `getOptionGroups` · `functions/src/verifyTossPayment.ts` brandId 전달
- 제안: ① `test:emulator` 스위트에 `price_emu.mjs` 와 같은 시나리오(3 scope 옵션·승인 override·수량 99 정상) 추가 ② 단위에 "brand-scope 옵션 정상 결제는 `getOptionGroups` 가 `brandId` 를 받는다" 단언(`fakeReader` 가 인자를 기록) + 수량 99 통과 케이스.
- 우선순위: 중 (⑦ 전 조건은 아님 — ⑤-b 정상 결제 양성 대조가 같은 역할을 한다. 단 그 대조에 brand-scope·store-scope 옵션이 들어가야 한다)

### F-04 [낮음 · 표면 인벤토리] design §3 표에 없는 "가격을 말하는 표면" 이 있다

- 문제: 역방향 grep 으로 금액·옵션 가격을 그리는 표면을 열거했다. design §3 의 사실 5·6 행(5-1~5-8, 6-1~6-13)과 대조해 **표에 행이 없는 것**:
  | 표면 | 가격의 출처 | 판정 |
  |---|---|---|
  | 메뉴 목록 카드 `customer/order/store/widgets/menu_item_card.dart` | `watchMenuItemsByStore` (병합된 단가) | 행 없음 |
  | 검색 결과 `customer/search/widgets/menu_search_result_tile.dart` | `search_menu_items_use_case` (override 적용) | 행 없음 |
  | 홈 자주 찾는 메뉴 `home/widgets/frequent_menu_items_section.dart` | `storeMenuItemsProvider` 병합 단가 | 행 없음 (6-12 는 빠른 재주문만) |
  | 고객 주문 상세·Log `order/orders/order_detail_page.dart` · `order_card` · `order_item_row` · `price_summary` | 주문 문서 그대로 | 6-13 은 "점주 주문 상세·매출·Qoin" 만 적었다 |
  | 환불 요청 금액 (`processRefund.ts` 가 주문 합계를 읽음) | 주문 문서 | 행 없음 |
  | 점주 브랜드 매장 메뉴 카드 `owner/brand_store/owner_brand_store_menus_page.dart` | 병합 단가 | 행 없음 |
  | 브랜드·점주 가격 입력 화면 (`price_override_input` · 마스터/점포 메뉴 폼 · 옵션 항목 편집기) | 쓰기 (승인 흐름) | 행 없음 — Q8 의 "승인 없이 쓸 수 있는 경로" 와 직결 |
- 판정: **동작 결함은 찾지 못했다** — 읽기 전용 표시이며 가격은 같은 병합 함수(`applyOverrideForCustomer`)를 거친다(검색은 코드 주석으로 확인, 나머지는 provider 경로 확인). 문제는 선행에서 다섯 번 반복된 패턴, 즉 **표에 없는 표면은 설계되지 않았다**는 것이다. 특히 마지막 행(가격 입력 화면)은 H-02 와 연결된다.
- 위치: `docs/tasks/payment_price_authority/design.md` §3
- 제안: 위 7행을 §3 에 "기존 · UI 무변경 · 판정 출처 = 병합 함수 / 주문 문서" 로 추가 (코드 변경 없음). 가드 후보: `formatKrw`/`₩` 를 쓰는 customer 파일 목록을 인벤토리와 대조하는 테스트.
- 우선순위: 낮음

### F-05 [낮음 · 가드/하네스 약점] 통과하는 가드와 보호하는 가드의 차이 3건

| 변이 | 결과 | 의미 |
|---|---|---|
| 금지어(`위조`)를 `_copyFiles` 목록 **밖** 파일(`payment_menu_list_card.dart`)의 문자열에 넣음 | 생존 | 문구 가드가 **닫힌 파일 목록**(9개)만 스캔한다. 새 문구 파일이 생기면 무방비. 디렉터리(`customer/cart`·`customer/checkout`) 단위 스캔이 안전하다 |
| 거절 화면 문구에 `17000 원이 …` (쉼표 없음 + 공백) | 생존 | 원 단위 가드 정규식 `\d{1,3}(,\d{3})*원` 이 `17000원`(붙여 쓴 경우)은 잡지만 공백 변형은 놓친다 |
| Rules: 점주 create 의 `approvedAt == null` 절 삭제 | 생존 (457/457) | `PPA-1b` 는 approvedBy+approvedAt 을 **함께** 보내서 approvedAt 단독 deny 케이스가 없다. override 의 효력 판정 입력은 아니므로 영향은 작지만 "필드마다 deny 1건" 기준 위반 |
- 대조 (검출된 것): 금지어를 `payment_failure_copy`·`cart_line_tile`·`checkout_price_changed_sheet` 에 → 검출 / 백틱 → 검출 / `17,000원` → 검출 / `AppColors.success` 를 배너·라인에 → 검출 / hex 색 → 검출.
- 우선순위: 낮음

---

## PASS 항목

### 가격 계산 — Dart·TS 일치 (요청 1)

- [x] **P-01 교차 골든은 같은 fixture 를 읽고 양방향 변이를 잡는다.** TS 변이(`Math.trunc`→`round`, 중복 선택 검출 제거, 필수 검사 제거, single 다중 검사 제거, 끈 그룹 required 면제 제거, active 필터 제거, ref 첫 우선→마지막 우선, 승인 분기 `rejected`도 적용 / `pending`도 적용, override 가 refs 제거, scope 폴백)가 각각 골든을 깬다. 요청 항목별 덮는 범위: 음수 `priceDelta` (P4·V2·V16 의 이유) · `multi` 중복 (V16 + `OPTION_UNAVAILABLE — duplicate`) · scope 혼합 (V2·V17) · override `pending`/`rejected`/부재 가격 (P8·P9·P10, M7a/M7b 가 검출) · 소수 0 쪽 버림 (R7·V18·P14).
  - **덮지 못하는 분기**: 수량 경계(1·99·0·100)는 교차 골든에 **없다** — Dart 쪽에 수량 규칙이 없어 한쪽만 있다 (F-01·F-03).
- [x] **P-02 실 Firestore 정상 경로.** M-3: 가맹 마스터 메뉴 + 승인 override(3000) + master/brand/store 3 scope 옵션(`ice +300`, `shot +500`, `syr +400.9→400`, `tumbler −300`) × 수량 2 = 정상 통과. 4개 모드 조합 모두 통과. 개인 매장 store-scope 정상. **pending override(100)를 믿고 100원 결제는 거절**, W2 문서(`approved`+`priceOverride:null`)는 마스터 가격으로 정상.
- [x] **P-03 서버 수량 경계.** 0·음수·소수·100 거절은 단위 테스트가 변이로 잡고(M3a/b/d), 99 정상·100 거절은 실 Firestore 로 확인(단 98 변이 생존 → F-03).
- [x] **P-04 재가격과 서버가 같은 함수를 호출한다.** `ValidateCheckoutUseCase._reprice` 는 `applyOverrideForCustomer`·`validateSelection`·`computeLinePrice` 만 호출하고 자체 산술이 없다. 메뉴 상세 담기 금액·카트 소계·재가격 모두 `cart_pricing.dart` 한 곳.

### `off` 비용 0 · 모드 조합 (요청 4)

- [x] **P-05 `off` 는 읽기 0회.** `if (priceMode !== "off")` 를 `if (true)` 로 바꾸면 **20건 FAIL** (off 계열 단언 + 기록 유무). 단위 테스트가 `reader` 호출 카운터와 `paymentGateRejections` 0건을 함께 본다. `priceMode` thunk 부재도 off.
- [x] **P-06 조합.** `GATE=off`+`PRICE=off` = 변경 전과 같다. `GATE=off`+`PRICE=enforce` = 가격 모드가 직접 읽어 판정하고 품절은 판정하지 않으며 매장 읽기 실패는 `READ_FAILED`, 해석 불가 메뉴는 거절(M-3 정상 통과 포함). `GATE=enforce`+`PRICE=enforce` = 메뉴 문서 1회 재사용. `GATE=shadow`(위반)+`PRICE=enforce` = 가격 모드가 직접 읽는다. 폴백은 `resolveGateMode` 와 같은 함수.

### 다섯 번째 구멍의 경계 (요청 3)

- [x] **P-07 Rules owner create·update 전수 변이.** 10종 중 9 검출: update 허용 목록에 `priceOverride`/`status`/`excluded`/`approvedBy,approvedAt` 추가 → 각각 PPA-2c/2·2e·2f/2d/2b 가 깨짐, update 절의 `onlyChangedFields` 제거 → 6건 이상 깨짐, create 의 `approvedBy`/`status` 허용목록/`excluded` 절/`approved`+`priceOverride` 절 제거 → PPA-1c/1d/1e/1 이 깨짐. (생존 1 = F-05)
- [x] **P-08 W2 정상 흐름 회귀 없음.** 앱 코드 경로 대조: `updateOverrideOperationFields` 는 override 가 없으면 `set`(approved + 승인 메타 null + `priceOverride:null` + `excluded:false`) — create 절 통과; 있으면 5개 운영 필드만 `update` — 허용 목록과 정확히 같다. PPA-3 회귀 + M-3 의 W2 문서 결제 통과.
- [x] **P-09 (분석) 점주가 운영 필드·삭제만으로 `priceOverride` 를 만들 수는 없다.** create 는 `approved` 면 `priceOverride`/`excluded` 가 비어 있어야 하고 승인 메타는 항상 null 이어야 하며 `status` 는 enum 이어야 한다. update 는 5개 운영 필드뿐. 점주가 삭제 후 재생성해도 같은 create 제약. `pending`+`priceOverride` create 는 허용되지만 서버·앱 모두 `pending` 가격을 적용하지 않는다(M-3 로 확인). **단 좁은 우회 하나 → H-02.**

### 무한 거절 루프 (요청 2)

- [x] **P-10 재가격 읽기 실패 시 pop 하지 않는다.** `_reprice` 의 `catch` 는 `_busy=false; _failures++` 만 하고 화면에 머문다. `ValidateCheckoutUseCase.call` 은 `reportFailure` 일 때 store·menu·option 읽기 실패 모두 재던진다(선검증은 권위가 아니므로 자동 호출은 무음). 카트 불변.
- [x] **P-11 카트 구성이 바뀌면 루프 차단기가 풀린다.** 서명이 menuItemId + 수량 + 옵션 id 정렬이라 구성 변경 시 `signature == cartSignature(cart)` 가 거짓 — 변형 N 이 기본형으로 돌아온다. (같은 구성 재주문은 F-02.)
- [x] **P-12 탈출 경로 존재.** 기본형 주 버튼은 pop 단독이 아니다(신선 읽기 → 카트 적용 → pop). 변형 N 에 `카트 비우고 메뉴 보러가기`. 체크아웃 결제 탭이 변동을 먼저 적용한 뒤 시트를 띄우고 결제창을 열지 않는다.

### 문서·기타

- [x] **P-13 가드의 기능 가드는 보호한다.** 변이 검출: 금지어(`payment_failure_copy`·`cart_line_tile`·`checkout_price_changed_sheet`), 백틱, `17,000원`, `AppColors.success`(배너·라인), hex 색. (약점은 F-05)
- [x] **P-14 이력 트리거·감사 CF.** 트리거 6개의 문서 경로·리전(`asia-northeast3`)이 기존 Firestore 트리거와 같고, 문서 ID = 이벤트 ID 라 재전달 멱등. 감사 CF 는 `requireAdmin` 이후 읽기 + `migrationHistory` 1건만 쓴다. `priceHistory` Rules 는 admin 읽기 전용.

---

## implementation §8 판정 (요청 7)

| # | 내용 | 판정 | 근거 |
|---|---|---|---|
| 1 | §13-8 을 W2 안 깨지게 좁힘 | **수용** | P-07·P-08. spec 문구("점주는 status approved 불가")를 그대로 구현하면 첫 품절 토글이 깨진다는 근거가 앱 코드로 확인됨. 위협 본질(`priceOverride`·`excluded` 효력)을 닫았고 변이로 증명. 좁은 잔여는 H-02 |
| 2 | `duplicate` + 수량(1~99) 위반 추가 | **duplicate 수용 / 수량은 서버 규칙 수용 + 앱 쪽 FAIL (F-01)** | duplicate: `multi` 에서 음수 `priceDelta` 반복으로 가격을 깎는 진짜 구멍이고 UI(Set 선택)는 중복을 못 만들어 새 오탐 없음(병적 데이터 H-07 만). 수량: 서버 규칙 자체는 필요하나 앱의 병합이 99 를 넘길 수 있어 새 오탐 |
| 3 | 유령 ref 는 선택·required 일 때만 거절 | **수용** | 미선택 유령까지 막으면 그 메뉴가 영구 결제 불가가 되는 오탐이 더 크다. Dart 화면은 유령 그룹을 `whereType` 으로 조용히 숨기므로 일치. M19 변이(미선택 유령도 거절)는 V5/V6 이 잡는다 |
| 4 | 가격 이력 ID = 이벤트 ID | **수용** | 멱등. `authId` 가 실이벤트에서 채워지는지는 미확인 (H-03) |

---

## 보류 항목

| # | 내용 | 메모 |
|---|---|---|
| **H-01** | **구버전 앱 잔존.** 구버전은 `PRICE_MISMATCH`/`OPTION_UNAVAILABLE` 토큰을 모르는 reason 으로 보고 갈래 C(`주문이 완료됐는지 확인이 필요해요`)를 띄운다(`git show HEAD~1:lib/domain/entities/payment_failure.dart` — 알려진 6개 밖은 `unknown`). 재가격 코드도 없다. 최소 버전 게이트는 코드·런북에 없다 | ⑦ 전 구버전 앱 비율 확인 또는 강제 업데이트 필요. 구버전은 가격이 한 번 바뀌면 카트 비움 외에 탈출구가 없고 화면은 "돈이 나갔을 수 있다" 를 암시한다 |
| **H-02** | **점주 운영 필드(`disabledOptionItemIds`/`disabledOptionGroupIds`)로 승인 없이 단가를 바꿀 수 있다.** 확인(`validateSelection` 직접 호출): 필수 `single` 그룹 S(0)/M(+500)/L(+1000)에서 점주가 S·M 을 끄면 선택 가능한 것은 L 뿐(+1000). 필수 그룹 자체를 끄면 필수 가산이 면제(감소 방향). 서버·UI 가 일치하고 고객은 선택지를 본다 | 결제 정합 결함이 아니라 **가격 승인 정책**(PPA-P2 확장 후보). spec §463 이 `disabled*` 를 운영 필드로 허용했으므로 설계자 판단 |
| **H-03** | `onDocumentWrittenWithAuthContext` 의 `authId` 가 실 이벤트에서 채워지는지 | 배포 ⑤ 직후 `priceHistory` 1건 확인 (런북에 있음) |
| **H-04** | 에뮬레이터 E2E(`test:emulator`, `test:flow`)·실기기·라이브 미실행. 이번 M-3 는 `handleVerifyTossPayment` 를 실 Firestore 에 연결한 일회성 확인이다 | 아래 배포 후 목록 |
| **H-05** | `checkout_page._showPriceChanged`: `hasPriceChanges` 인데 `applied.hasChanges` 가 거짓이면(단가는 같고 `lineTotal` 만 stale) 결제 탭이 **무반응**이다. 현 카트 저장소는 항상 `lineTotal=단가×수량` 이라 도달 불가 | 방어 코드 부재 — 후속 |
| **H-06** | 문서 값 해석 차이: Dart 모델은 `(num?)` 캐스트라 문자열 가격이면 `TypeError`, 서버는 0 으로 읽는다 | PPA-P5(타입 Rules)와 같은 계열. 오너가 `priceOverride:"100"`(pending)을 쓸 수 있어 고객 앱 파싱 크래시 가능 — 기존 문제이나 서버가 권위가 된 지금 재평가 후보 |
| **H-07** | 한 메뉴가 같은 `id` 의 ref 를 두 scope 로 가지면(병적 데이터) 화면이 같은 (그룹, 항목)을 두 번 `selectedOptions` 에 넣어 `duplicate` 로 거절된다 | 데이터 정합성 영역 |
| **H-08** | `kMaxOptionGroupDocs`(200) 초과 시 앱 재가격이 생략되고 서버는 거절 → 변형 N | 병적 규모 |

---

## 배포 후 수동 확인 목록 (T-2, 미실행)

1. **⑤-b shadow 양성 대조**: 구버전 앱으로 담고 가격 변경 후 결제 → `paymentGateRejections` 에 `detail.shadow:true` 1건. **그 전에 모드가 `shadow` 인지**(F-05 선행: 기록이 비면 모드 오류).
2. **정상 결제가 잡히지 않는지** — 반드시 포함: **brand-scope 옵션**이 든 가맹 메뉴, **store-scope 옵션**, 음수 `priceDelta`, 같은 메뉴 옵션만 다른 2줄, **수량 99** (F-03 의 자동 테스트 공백을 이 대조가 메운다). `detail.optionIssues` 에 `missing` 이 정상 선택에서 나오면 ⑦ 금지.
3. ⑦ 직후 **거절 1건 실측**: 결제창이 떠 있는 동안 `basePrice` 를 바꿔 거절 → 거절 화면 → `최신 가격으로 다시 담기` → 카트 배너·취소선 → 재결제 성공.
4. `priceHistory` 1건: 점주가 `basePrice`/옵션 `priceDelta` 변경 → `changedBy` 가 uid 인지 (H-03).
5. 네트워크 차단 상태에서 재가격 → 거절 화면에 머무는지, `다시 불러오기`.
6. 가격 변동이 없는 카트에서 어떤 가격 표시도 안 뜨는지(통과 표시 금지), 내림이 초록이 아닌지(info).
7. 감사 카드 ② 기준선 숫자를 기록하고 ⑨ 에서 증가 0 확인.
8. **구버전 앱 비율**(H-01) 확인 후 ⑦.

---

## 설계자 전달 메시지

### 요약

- 계산·Rules·모드 비용은 견고하다. **FAIL 은 전부 "정상 고객을 막는" 방향의 좁은 틈**이고 영구 정지는 없다.
- 가장 먼저: **F-01 (카트 병합 99 clamp)** — 앱 변경이라 ⑥ 빌드에 포함해야 한다.

### 재작업 우선순위

| 순서 | 항목 | 담당 |
|---|---|---|
| 1 | F-01 병합 clamp(+ 수량 경계 골든) | developer |
| 2 | F-02 서명 리셋 | developer |
| 3 | F-03 어댑터·99 경계 회귀 테스트 | developer |
| 4 | F-04 design §3 7행 추가 | designer |
| 5 | F-05 가드 디렉터리 스캔·정규식·approvedAt deny 1건 | developer |

### 설계자 판단 요청

- **H-02**: 점주 `disabled*` 로 필수 그룹 선택지를 고가 하나로 몰 수 있다 — 승인 필요 여부(PPA-P2 확장)
- **H-01**: 구버전 앱 처리(강제 업데이트/비율 임계값) — ⑦ 의 GO 조건
- F-01 해법 선택: 앱 clamp(권장) vs 전용 거절 사유(사유 9종 → design 변경)

### 후속 task 후보

PPA-P2 확장(H-02), 최소 앱 버전 게이트, 금액 Rules 타입 제약(PPA-P5·H-06), 병합 상한을 포함한 카트 규칙 문서화.

---

## 완료 판단

- 구현은 spec Q1~Q8 의 의도를 충족한다. F-01~F-05 닫힘 + H-01 조건 충족 시 ⑦ GO.
