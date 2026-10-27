# payment_price_authority 구현 기록

- 작성: 2026-10-27
- 작성자: developer
- 기준: `spec.md`(Q1~Q8 확정, §18 배포 순서, §19 가드, §20 분배) · `design.md`(DQ1~DQ6, Q-D1~D3 확정) · 선행 `payment_server_authority/{spec,design,implementation}.md` · `docs/operations.md §6`
- 상태: **코드 완료, 배포 전.** 라이브 검증(⑦ 거절 1건 실측 · ⑧)은 하지 않았다. **커밋하지 않았다**(저장소 규칙: 사용자 요청 시에만) — 아래 §1 은 커밋 경계의 제안이다.

## 0. 검증 결과

| 항목 | 결과 |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **884 전부 통과** (착수 시 HEAD 746 — 요구 746 이상) |
| `functions` `npm test` (= `tsc` 빌드 + 단위/골든) | **310 통과** |
| Rules 하네스 `test_rules` `npm test` | **457/457 통과** (착수 시 420). 신규 37건 중 **구 Rules 에서 12건 FAIL** 로 실제로 구멍을 잡음을 확인(`PPA-1`·`PPA-2` 전건) |
| 교차 골든 | Dart `test/core/payment_price_contract_test.dart`(+ 기존 `payment_authority_contract_test.dart`) 와 TS `functions/test/priceAuthority.test.mjs`(+ `paymentAuthority.test.mjs`)가 **같은 fixture 파일**을 읽는다 |
| 변이 검증 | 아래 §6 — 39개 변이 중 38 검출, 1개 동치 변이(관측 불가) |
| 미실행 | `functions` 에뮬레이터 E2E(`test:emulator`, `test:flow`), 실기기, 라이브(⑦·⑧) |

## 1. 구현 파일

### Rules 커밋 경계 (제안 — 커밋하지 않았다)

| 제안 커밋 | 내용 | 독립 적용 |
|---|---|---|
| **Rules-1** `menuOverrides` | `firestore.rules` 의 `menuOverrides` 블록(+ `ownerOverrideCreateOk()`) · `test_rules/rules.test.mjs` 의 `PPA-1*`·`PPA-2*`·`PPA-3*`(27건) | **단독 적용 가능 — 배포 ③.** 구 앱의 점주 정상 쓰기 둘(W2 upsert · 등록 시 제외 시드)이 통과하므로 앱보다 먼저 둘 수 있다 |
| **Rules-2** `priceHistory` | `firestore.rules` 의 `priceHistory` 블록 1개 · 하네스 `PPA-H*`(10건) | 단독 적용 가능. 이 컬렉션을 쓰는 앱 코드 0건 |
| functions + fixtures | `functions/src/*`, `functions/test/*`, `test_fixtures/*` 4종 | 배포 ①(감사만) / ⑤(전체) |
| Dart 고객 결제 측 | 순수 함수 · 재가격 · 카트/체크아웃/거절 화면 | 앱 ⑥ |
| Dart admin 감사 카드 | `TEMP_PRICE_AUDIT_CARD` 파일들 | 앱 ② (같은 빌드) |
| 문서 + 가드 | `docs/**`, `payment_price_guard_test.dart`, 이 문서 | — |

Rules-1/2 는 `firestore.rules` 의 서로 다른 블록만 만진다. **같은 파일의 다른 hunk 라 `git add -p` 로 나눈다.** 단계별 Rules 파일(`firestore.rules.stage*`)은 **만들지 않았다** — HEAD 를 그대로 배포해도 뒤 단계가 같이 나가 구 앱을 깨는 경로가 없기 때문이다(두 변경 모두 구 앱·구 CF 와 호환; 근거 표는 `deploy_runbook.md §0-3`). 선행처럼 B+C 가 구 앱을 깨는 구조였다면 만들어야 한다.

### functions (TypeScript)

| 파일 | 역할 |
|---|---|
| `src/menuVisibility.ts` | `MergedMenu` 에 `optionGroupRefs` 추가(읽기 0). `applyOverrideForCustomer`·`classifyCartMenu`(storeMenu 경로) **양쪽**에서 채운다. `overrideIsApproved` 를 export — **승인 분기의 유일한 구현** |
| `src/optionPricing.ts` **신규** | Dart `option_availability.dart` 의 포팅: `parseOptionGroup` · `resolveSelectableOptions` · `validateSelection` · composite 조립 1곳 |
| `src/cartPricing.ts` **신규** | Dart `cart_pricing.dart` 의 포팅: `computeLinePrice` · `computeLineTotal` · `computeCartAmount`. `priceDelta` 합산이 TS 에서 유일한 곳 |
| `src/priceGate.ts` **신규** | 2-c 판정: `evaluatePriceAuthority`(§4-3 c1~c6 + 옵션 위반) · `resolveMenusForPricing`(게이트가 꺼졌을 때 직접 읽기) · `MAX_OPTION_GROUP_DOCS=200` · `MAX_LINE_QUANTITY=99` · `resolvePriceMode` |
| `src/paymentGate.ts` | `GateReason` 6→8종(`PRICE_MISMATCH` `OPTION_UNAVAILABLE`), 토큰 문법에 두 사유 합류, `GateReader.getOptionGroups` 포트, `isLookupSafeId` export |
| `src/paymentGateReader.ts` | `getOptionGroups` — `getAll` 1회, (scope, id) 중복 제거, 안전하지 않은 id·brandId 없는 brand scope 는 읽지 않고 null |
| `src/verifyTossPayment.ts` | 2-c 삽입 · `defineString("PAYMENT_PRICE_MODE", {default:"off"})` · `VerifyDeps.priceMode` thunk · enforce 에서 `applyServerPricing` 으로 주문 문서 금액 필드를 서버 값으로 |
| `src/orderBuilder.ts` | 거짓 타입 수정(`groupId/groupName/itemId/label`, `imageUrl?`) · `CONSUMED_ITEM_KEYS` / `CONSUMED_OPTION_KEYS` · `applyServerPricing` |
| `src/onMenuPriceWritten.ts` **신규** | 가격 이력 트리거 6개(`onMenuPriceWritten` · `onBrandMenuPriceWritten` · `onMenuOverridePriceWritten` · `onOptionGroupPriceWritten` · `onBrandOptionGroupPriceWritten` · `onMasterOptionGroupPriceWritten`) + 순수 핵심(`diffPriceChange` `recordPriceChange`) |
| `src/auditOrderPriceIntegrity.ts` **신규(임시)** | admin 전용 읽기 전용 감사. 쓰기는 `migrationHistory` 1건 |
| `src/index.ts`, `package.json`(test 스크립트), `.env.example` | export / 테스트 목록 / `PAYMENT_PRICE_MODE` 항목 |
| `test/priceAuthority.test.mjs` **신규** | 교차 골든 40 + 금액 게이트 45건(§4-3 ①~⑥ · 옵션 사유 9종 · 읽기 실패 · 상한 · 모드 · 플래그 조합 · 토큰) = 85 |
| `test/priceAudit.test.mjs` **신규** | 감사 순수 판정 · 이력 핵심 · "감사는 쓰지 않는다" 소스 가드 (17건) |
| `test/qoinRate.test.mjs` | item 레벨 키 집합 골든(T2-b) |

### fixtures (`test_fixtures/`)

| 파일 | 내용 |
|---|---|
| `option_availability_contract.json` **신규** | 26 케이스(resolve 8 · validate 18). active=false · 그룹/항목 비활성(**composite**, 항목 id 단독은 불일치) · ref scope 3종 · 유령 ref · 키 부재 · 항목 부재 · required · single 다중 · **duplicate** · priceDelta 해석(소수 0 쪽 버림) |
| `cart_pricing_contract.json` **신규** | 14 케이스. 옵션 없음/단일/다중/**음수 priceDelta**/quantity/같은 메뉴 2줄/`priceOverride` approved·pending·rejected/매장 직영/0원/소수 `basePrice`. 기준가는 기존 판정(`classifyCheckoutMenu`→`applyOverrideForCustomer`)으로 얻고 그 결과가 산술까지 같은 값으로 이어짐을 고정 |
| `menu_visibility_contract.json` | 기존 14 케이스 전부에 `optionGroupRefs` 추가 + 신규 2(refs 해석 · override 가 refs 를 안 바꾼다) |
| `qoin_cart_contract.json` | `itemKeys` · `selectedOptionKeys` 추가(§1-5 재발 방지) |

### Dart

| 파일 | 역할 |
|---|---|
| `lib/core/utils/option_availability.dart` **신규(추출)** | `resolveSelectableOptions` · `validateSelection` · `OptionIssueKind`(7종) · `optionRefKey` · composite 판정 1곳. `OptionRepositoryImpl` 의 규칙을 **그대로** 옮겼다 |
| `lib/core/utils/cart_pricing.dart` **신규** | `computeLinePrice` · `computeLineTotal` · `sumLineTotals` · `computeCartAmount`. 순수, Firebase·Flutter 비의존 |
| `lib/data/repositories/option_repository_impl.dart` | 판정을 자체 보유하지 않고 `resolveSelectableOptions` 호출(동작 동일) |
| `lib/data/models/{menu_override,menu_item,option_group}_model.dart` | R10 `(num?)?.toInt()` · `MenuItemModel.fromData` · `OptionGroupModel.fromData` 추출(교차 골든 테스트가 **실제 모델 경로**를 타게) |
| `lib/domain/entities/checkout_validation.dart` | `CartRepricing{priceChanges, optionIssues}` · `RepricedLine` · `LineOptionIssue`. 가격 변동은 위반이 아니다(`hasViolations` 미포함), 옵션 위반은 위반이다 |
| `lib/domain/usecases/validate_checkout_use_case.dart` | `cartItems` 를 주면 재가격. 메뉴 문서 재사용 + 옵션 그룹만 추가 읽기. 옵션 읽기 실패는 재가격만 생략(메뉴 위반 유지), `reportFailure` 면 던진다. 타임아웃 자동 3초 / 사용자 5초 |
| `lib/domain/usecases/apply_repriced_cart_use_case.dart` **신규** | 단가만 넘기고 합계는 저장소가 같은 식으로 다시 만든다. 이미 새 단가인 라인은 "바뀐 라인" 으로 세지 않는다 |
| `lib/domain/repositories/{checkout_validation,cart}_repository.dart` + 구현 + 데이터소스 | `fetchOptionGroupsFresh` · `getActiveCart` · `applyUnitPrices` |
| `lib/data/datasources/local/cart_local_data_source.dart` | 라인/소계 산식을 `cart_pricing.dart` 로 교체 |
| `lib/domain/entities/payment_failure.dart` | 사유 6→8. `isMenuReason` 에 두 사유 포함(토큰이 `menuItemId` 를 싣는 계열) |
| `lib/presentation/customer/checkout/payment_failure_copy.dart` | 두 사유의 문구 · 변형 N · 재가격 문구 상수 · `repriceAndReturn` 액션 |
| `lib/presentation/customer/checkout/payment_result_page.dart` | `_PriceMismatchBody`(재가격 중/실패/반복 차단) · OPTION_UNAVAILABLE 목록 아이콘·옵션 id 기록 |
| `lib/presentation/customer/checkout/checkout_page.dart` | 결제 탭 재가격: 품절·매장 > 옵션 > 가격. 가격 변동은 **카트 적용 후** 시트, 결제창을 열지 않는다 |
| `lib/presentation/customer/checkout/widgets/checkout_price_changed_sheet.dart` **신규** | 가격 변동 시트 · 옵션 위반 시트 |
| `lib/presentation/customer/cart/**` | `cart_line_availability.dart`(`optionUnavailable`) · `cart_line_tile.dart`(취소선 이전 금액·방향 캡션·옵션 라벨 `Text.rich`·`다시 고르기`) · **`cart_price_change_banner.dart` 신규**(배너·합계 행·`summarizePriceChanges`) · `cart_page.dart`(자동 적용·새 변동이면 멈춤) · `providers/checkout_validation_providers.dart`(`cartPriceChangesProvider` · `priceRepricedCartSignatureProvider` · `paymentOptionRejectedMenuIdsProvider` · `refreshAndReprice`) |
| `lib/presentation/customer/order/menu/**` | 담기 금액·실시간 합계를 `computeLinePrice`/`computeLineTotal` 로 (식 하나) |
| `lib/presentation/customer/home/widgets/quick_reorder_section.dart` | 가드 허용 목록의 **사유 주석만** 추가(동작 변경 0) |
| **임시** `lib/domain/entities/price_audit_report.dart` · `data/datasources/remote/price_audit_remote_data_source.dart` · `data/repositories/price_audit_repository_impl.dart` · `domain/repositories/price_audit_repository.dart` · `domain/usecases/run_price_audit_use_case.dart` · `presentation/admin/widgets/admin_price_audit_card.dart` | `TEMP_PRICE_AUDIT_CARD` 로 grep 된다. 배포 ⑩ 에서 삭제. `admin_migration_page.dart` 에 카드 1줄 |

### 테스트 (신규)

`test/core/payment_price_contract_test.dart`(골든 41) · `test/domain/reprice_checkout_use_case_test.dart`(재가격 14 + 적용 4 = 18) · `test/presentation/payment_price_screens_test.dart`(거절 화면·카트 행·배너·시트 27) · `payment_price_cart_page_test.dart`(6) · `payment_price_checkout_page_test.dart`(7) · `payment_price_guard_test.dart`(22) · `price_audit_card_test.dart`(14). 수정: `payment_failure_test` · `payment_authority_guard_test`(허용 목록) · `payment_authority_contract_test`(`optionGroupRefs`) · `qoin_f1_contract_test`(item 키) · `validate_checkout_use_case_test`(fake 에 포트).

### 문서 갱신 (spec §22)

`operations.md §6`(행 실측 반영 — §3) · `data_ownership.md`(§2.6 menuOverrides Rules-1 + Q8 우회로, §2.13 `priceHistory`·거절 reason/detail, §3 CF 카탈로그 3행, 미해결 표) · `audit_trail.md`(`priceHistory` ✅, A3 해소) · `role_flows.md`(결제 행 + admin 감사 행) · `entity_lifecycle.md`(§5.5 Rules 갱신 + `→ paid` 진입 조건 + Q8) · `backlog.md`(PSA-N1 완료, PSA-N5 사유 갱신, PPA-P1~P7 등재) · `deploy_runbook.md` 신규.

## 2. 배포 단계별 산출물 매핑 (spec §18)

| 단계 | 산출물 | 비고 |
|---|---|---|
| ① 감사 CF 만 (함수 단위) | `auditOrderPriceIntegrity` | `npx firebase deploy --only functions:auditOrderPriceIntegrity`. 전 함수 배포 금지. 신규 callable 이라 Cloud Run 호출자 권한이 필요할 수 있다(런북 ①) |
| ② 실태 측정 | admin 앱 → `배포 마이그레이션 (임시)` → `② ⑨ 가격 감사` 카드 | 앱 빌드 필요(같은 빌드 — 재가격은 서버 모드와 무관하게 안전). ⓐ 주문 위반 · ⓑ self-approved · ⓒ store-scope 참조 |
| ③ Rules | `firestore.rules` HEAD 그대로 (Rules-1 + Rules-2) | **CF 보다 먼저.** 단계 파일 없음(§1) |
| ④ ⓑ 실태 처리 | 사람 판단 | ⓑ=0 이면 no-op |
| ⑤ 본 CF (`PAYMENT_PRICE_MODE=shadow`) | `verifyTossPayment` 개정 + 신규 모듈 + 이력 트리거 6개 | `.env` 에 `PAYMENT_GATE_MODE=enforce` 가 있는지 먼저 확인(없으면 선행 게이트가 조용히 off) |
| ⑤-b shadow 관측 | `paymentGateRejections` `detail.shadow:true` | 양성 대조: 구버전 앱으로 담은 뒤 가격 변경 → 결제 |
| ⑥ 앱 | R9 재가격 + 거절 문구 + 임시 감사 카드 | **enforce 보다 먼저**(선행과 반대) |
| ⑦ enforce | `.env` 한 줄 교체 + `functions:verifyTossPayment` | 결제창이 떠 있는 동안 `basePrice` 를 바꿔 거절 1건 실측 |
| ⑧ 라이브 검증 | — | 불변식: 옵션 포함 정상 결제 성공 |
| ⑨ 재측정 | 감사 카드 | ② 대비 증가 0 |
| ⑩ 정리 | 감사 CF · 카드 삭제 | 이력 트리거·`priceHistory` Rules 는 상시 자산이라 유지 |

## 3. `PAYMENT_PRICE_MODE` — 어디서 읽고, `operations.md §6` 행이 맞는가

- **읽는 곳**: `functions/src/verifyTossPayment.ts` — `defineString("PAYMENT_PRICE_MODE", { default: "off" })`. 요청마다 `deps.priceMode?.()` 로 값을 읽어 `resolvePriceMode`(`priceGate.ts`)로 정규화한다. **`resolvePriceMode` 는 `resolveGateMode` 를 그대로 호출**하므로 폴백이 같다(정확 일치만 인정, 미지값·오타·대소문자·공백은 `off`). Secret Manager 가 아니다(스위치는 비밀이 아니다).
- **값이 놓이는 곳**: 배포 머신의 `functions/.env.order-app-5957e` — 키마다 한 줄. `PAYMENT_GATE_MODE` 와 **같은 파일**이다. 배포 시점에 박힌다.
- **`off` 의 비용 0**: 단위 테스트로 단언 — `off`/없음/`''`/`Enforce`/`'enforce '`/`weird`/thunk 없음 모두 **매장·메뉴·옵션 그룹 읽기 0회**(`reader` 호출 카운터 전부 0, `paymentGateRejections` 0건, 금액이 틀려도 결제 성립).
- **`operations.md §6` 확인 결과 — 어긋난 곳이 있어 고쳤다**: ⓐ §6.1 표의 행과 "두 스위치는 독립" 문장은 **실제와 맞았다.** ⓑ §6.2 의 명령은 `PAYMENT_GATE_MODE` 예시뿐이고 "키 이름만 바꿔" 라고 했는데, 실제 키는 `PAYMENT_PRICE_MODE` 로 맞다 — 다만 **`.env` 파일 하나에 두 키가 같이 있어** 한 키를 바꾸는 명령이 다른 키를 지우지 않는지가 중요하므로 `grep -v` 형식의 가격 명령을 명시했다. ⓒ 빠져 있던 것을 추가했다: 읽는 곳 · **파일이 없으면 두 스위치가 함께 `off`** 경고 · 게이트 off + 가격 on 조합의 실제 동작 · 금액 게이트 `off` 가 1원 결제 가능 상태라는 경고 · 무한 거절 루프 신호 · 금액 거절 `detail` 읽는 법(`delta` 부호·`checks`·`failure`) · 금액 스위치의 양성 대조 방법. (spec 은 건드리지 않았다.)

## 4. 복합 인덱스 — **불필요**

- 앱 쪽 신규 쿼리 없음(재가격은 문서 단건 `get`, 옵션 그룹도 문서 단건).
- 서버: `getAll`(문서 ID 조회) · 감사 CF 의 `orders where createdAt >= && < orderBy createdAt` 는 **단일 필드 범위** 라 자동 인덱스 · `collectionGroup('menuOverrides').get()` 은 필터·정렬이 없어 collection-group 인덱스 불필요 · `brands/{b}/menuItems.get()` · `stores.get()`.
- `firestore.indexes.json` 은 수정하지 않았다. `priceHistory` 는 쓰기 전용(트리거) + admin 콘솔 읽기라 쿼리 인덱스가 없다.

## 5. 테스트 포인트 (tester)

1. **옵션이 붙은 정상 결제가 성공한다**(불변식) — 음수 `priceDelta` 포함, 같은 메뉴 옵션만 달리 2줄. `priceAuthority.test.mjs` "통과(불변식)" 가 코드 수준 대응.
2. `amount:1` + 17,000원어치 `cart.items` → 거절 + confirm 미호출 + `delta` 음수 기록(같은 파일 ③).
3. **무한 루프 없음** — 가격 변경 후 담아 둔 카트로 결제 → 거절 화면 → `최신 가격으로 다시 담기` → 카트에 배너·라인 표시 → 결제 성공. 같은 구성에서 또 거절되면 **변형 N**(재가격 버튼 없음, `카트 비우고 메뉴 보러가기`가 탈출구).
4. 재가격 실패(네트워크 차단): 거절 화면에 **머문다**, `다시 불러오기`, 카트 불변. 연속 2회에 힌트 한 줄.
5. 카트 `결제하기` 탭에서 **새 변동이 있으면 멈춘다**(오름·내림·섞임 같은 규칙), 두 번째 탭이 체크아웃. 변동이 없으면 어떤 가격 표시도 없다.
6. 체크아웃 결제 탭: 가격 변동 시트(밀어 닫아도 합계가 새 금액), 옵션 위반 시트(가격보다 우선). 결제창은 어느 쪽에서도 열리지 않는다.
7. 내림은 **초록이 아니다**(info). 거절 화면에 **금액 숫자 0건**, 금지어 0건, 백틱 0건.
8. 모드: `off`/없음/모르는 값 → **옵션 그룹 읽기 0회**. 게이트 `off` + 가격 `enforce` → 조용히 통과하지 않고 직접 읽어 거절. 게이트 `enforce` + 가격 `enforce` → 메뉴 문서 읽기 1회(재사용).
9. `shadow`: 기록 1건(`detail.shadow:true`), 결제 성립, 주문 문서는 클라 값. `enforce`: 서버 값(`applyServerPricing` 단위 테스트 + 주문·로그 양쪽 확인).
10. Rules: 점주 `status:'approved'`+`priceOverride` create/update 거부 + **정상 흐름 회귀**(품절 토글 W2 upsert · 등록 시 제외 시드 · 브랜드 제출 · admin 승인/반려). `priceHistory` admin 읽기만.
11. 가격 이력: 점주가 `basePrice`/옵션 `priceDelta`/override 를 바꾸면 `priceHistory` 1건(변경 전후·`changedBy`). 가격 밖 필드만 바꾸면 기록 없음.
12. 감사 카드: 세 분류를 0건이어도 그린다 / 응답에 없으면 `응답에 없음` / **쓰기 버튼 없음** / 위반이면 중단 배너.
13. 추출 회귀: 메뉴 상세 옵션 목록이 추출 전과 같다(`OptionRepositoryImpl` → `resolveSelectableOptions`), 담기 금액 = 카트 합계.
14. 라이브(⑦·⑧): 런북의 거절 1건 실측 · 정상 옵션 결제 · 재가격 복구 · 옵션 비활성 · 네트워크 차단.

## 6. 변이 검증 — 가드·골든이 실제로 깨지는가

변이 → 테스트 실행 → 실패를 확인하고 원복했다(`*.mutbak` 잔존 0). **양방향** = Dart 만 바꿔도 / TS 만 바꿔도 같은 fixture 로 각각 깨진다.

| 분류 | 변이 | 검출 |
|---|---|---|
| 산술 | `computeLinePrice` 음수 증감을 절댓값으로 — **Dart / TS 각각** | 각 쪽 골든 실패 |
| 옵션 판정 | active=false 미필터 · composite 순서 뒤집기 · 중복 선택 검출 제거 — **Dart / TS 각각**, required 검사 제거(Dart) | 각 쪽 골든 실패 |
| 승인 분기 | pending `priceOverride` 도 적용 — **Dart / TS 각각** | 기존 `menu_visibility` 골든 + 신규 `cart_pricing` 골든 |
| 게이트 | c4(총액 대조) 무력화 · 수량 검증 제거 · off 에서도 평가 · enforce 가 서버 값을 안 씀 · 거절해도 진행 · override 경로 refs 누락 | `priceAuthority.test.mjs` |
| 가드 | 메뉴 상세에 priceDelta 합산 재도입 · 금지어 `조작` · 백틱 · `AppColors.success` · 거절 문구에 `17,000원` · TS `optionGroupId` · 앱에 `PAYMENT_PRICE_MODE` · 새 composite 조립 · `CartItemEntity` 신뢰 필드 · 모델 `as int?` · TS 새 파일의 `priceOverride` | `payment_price_guard_test` / `payment_authority_guard_test` |
| UI | 주 버튼이 pop 단독 · 재가격 실패해도 pop · 루프 차단기 제거 · 변경 없음인데 카트로 보냄 · 카트 탭이 멈추지 않음 · 체크아웃이 가격 변동에도 결제창을 염 · 읽기 실패 시 결제를 막음 · 재가격이 카트에 적용 안 됨 · 내림에 success 톤 | `payment_price_screens/cart_page/checkout_page_test` |
| Rules | 구 Rules(HEAD)로 하네스 실행 | `PPA-1*`·`PPA-2*` **12건 FAIL** (435/447) |
| **생존 1** | `else if (!shadow) { serverPricing = … }` → `else` | **동치 변이.** shadow 가 정상 통과(`result.ok`)일 때 서버 값은 클라 값과 **같다**(판정식 ④⑤⑥ 의 의미) — 관측 가능한 차이가 없다. 불일치일 때는 `result.ok` 가 아니라 `serverPricing` 이 만들어질 수 없다. 의도적 약점이 아니다 |

## 7. 미구현 / 보류

- **에뮬레이터 E2E**(`functions` `test:emulator` · `test_rules` `test:flow`), 실기기, 라이브(⑦ 거절 1건 실측 · ⑧) — 하지 않았다. 이력 트리거는 **단위 테스트(순수 핵심 + fake db)까지만** 검증했고 실제 Firestore 이벤트로 `onDocumentWrittenWithAuthContext` 가 `authId` 를 채우는지는 미확인이다(⑤ 직후 `priceHistory` 1건 확인이 런북에 있다).
- `gcloud run services add-iam-policy-binding` 의 정확한 서비스명(`auditorderpriceintegrity`)은 선행 배포의 방식에서 추정했다 — ① 실행 시 확인.
- 선행 spec 의 "`details` 가 실기기에서 Map 으로 안 오는 문제" 는 그대로다. 두 신규 사유도 message 끝 토큰만 1차 근거로 쓴다.
- 비활성 키 composite 를 **쓰는** 화면 3곳은 손대지 않았다(PPA-P6).
- 홈의 빠른 재주문 표시 가격(PSA-N5) — 돈 경로는 재가격이 덮는다.
- 서버 견적(P1) · 옵션 가격 승인(P2) · 이름·라벨 서버 구성(P3) · Tier 2(P4) · 타입·범위 Rules(P5).

## 8. 작업표와 현실의 차이 (설계자 판단 요청 포함)

1. **🔴 spec §13-8 의 Rules 문구를 그대로 쓰면 정상 흐름이 깨진다 — 더 좁게 구현했다.** spec: "점주는 `status:'approved'`/`approvedAt`/`approvedBy` 를 쓸 수 없다". 그러나 점주의 **품절 토글**(`updateOverrideOperationFields` 첫 케이스, W2)은 override 가 없을 때 `status:'approved'`, `approvedBy:null`, `priceOverride:null`, `excluded:false` 로 **문서를 만든다**(entity_lifecycle §5.5). 문구대로면 브랜드 매장 점주가 처음 품절 처리를 못 한다. 위협의 본질은 `status` 가 아니라 **`approved` 가 효력을 주는 핵심 필드(`priceOverride`·`excluded`)** 이므로: ⓐ 점주 create — 효력 있는 핵심 필드(`status` 가 `approved` 인데 `priceOverride != null` 또는 `excluded == true`)·승인 메타(null 이 아닌 `approvedBy`/`approvedAt`)·`{pending, approved, rejected}` 밖의 `status`(앱은 모르는 문자열을 approved 로 읽는다) 금지 ⓑ 점주 update — **운영 필드 5개만**. 하네스 `PPA-3`(앱 payload 그대로)이 이 회귀를 고정한다. **설계자 확인: 이 해석이 §13-8 의 의도와 맞는가.**
2. **감사 ⓑ 의 정의도 같은 이유로 좁혔다.** spec: "`status=='approved'` 인데 `approvedBy` 가 없거나 점주". W2 문서가 전부 걸린다 → **핵심 필드가 있는 건만** `selfApproved`, 없는 건은 `opsOnlyApproved` 로 따로 센다(카드가 둘 다 보인다). 승인 판정은 `menuVisibility.ts overrideIsApproved` 를 가져다 쓴다(복제 금지).
3. **`duplicate` — spec 의 6종 밖에서 7번째 위반을 추가했다.** `multi` 그룹에서 같은 (그룹, 항목)을 반복 선택하면 음수 `priceDelta`(텀블러 −300)로 가격이 깎인다 — 서버가 클라 선택을 그대로 더하면 진짜 구멍이다. `detail.optionIssues[].kind` 가 7종이 된다. 골든 V16. **설계자 확인 필요(PPA-P7).**
4. **수량 검증**: spec 에 없다. `quantity` 가 음수·0·소수·100 이상이면 라인 합계가 음수가 되어 총액을 깎을 수 있어 `MAX_LINE_QUANTITY=99`(앱 `QuantityStepper` 와 같다)로 거절한다(`PRICE_MISMATCH`, `lines[].unusable:'badQuantity'`).
5. **유령 ref 정책을 좁혔다.** spec §7-1 "ref 가 유령을 가리키면 거절" — 구현은 **선택한 그룹이 유령일 때**(`missing`)와 **필수 제약에 걸릴 때**만 거절한다. 고객이 고를 수도 없었던 미선택 유령 ref 까지 거절하면 그 메뉴 전체가 영구 결제 불가가 되는 오탐이 더 크다. 클라이언트 화면은 유령 그룹을 조용히 숨기므로(`whereType`) 일관된다. 런북 ⑤-b 가 "정상 선택에서 `missing`" 만 본다.
6. **brand-scope 옵션 그룹의 brandId**: 서버와 새 재가격은 `store.brandId`(신뢰원)를 쓴다. 기존 메뉴 상세 옵션 목록은 `menuItem.brandId`(문서 자신의 필드)를 쓴다. 마스터 메뉴는 두 값이 같고, 점포 한정 메뉴가 brand-scope 그룹을 가리키는 비정상 데이터에서만 갈릴 수 있다(그때 화면은 그룹을 못 보여 주므로 그 선택을 만들 수 없다).
7. **가격 이력 트리거는 "1개" 가 아니라 문서 종류별 6개 export**(Firestore 트리거는 경로 하나) — 핵심(`recordPriceChange`)은 하나다. 문서 ID 는 `autoId` 가 아니라 **트리거 이벤트 ID**(at-least-once 재전달이 와도 같은 문서에 덮어써 중복이 없다). `changedBy` 는 `onDocumentWrittenWithAuthContext` 의 `authId`(클라이언트 쓰기면 uid, Admin SDK/CF 면 null + `authType`). `before`/`after` 는 가격 필드만, 원시 값 그대로.
8. **게이트 off + 가격 on 조합의 해석 불가 케이스**: 메뉴 문서가 없거나 `excluded` 라 단가를 못 얻으면 → `PRICE_MISMATCH`(`unusable:'menuUnresolved'`), 매장 읽기 실패·부재면 → `READ_FAILED`(`failure:'storeUnreadable'`). 게이트 shadow 가 위반으로 끝난 경우도 가격 모드가 메뉴를 한 번 더 읽는다(정상 경로는 읽기 0 추가).
9. **`CheckoutValidation.hasViolations` 의 의미를 확장**(옵션 위반 포함)했고 호출부 2곳을 갈랐다: 체크아웃은 `store/menus`(품절 시트) → `optionIssues`(옵션 시트) → `hasPriceChanges`(가격 시트) 순.
10. **`isMenuReason` 에 두 사유를 포함**해서 거절 화면의 `카트로 돌아가기`(pop)가 기존 사유처럼 지목 id 를 `paymentRejectedMenuIdsProvider` 에 기록한다(카트 행 `rejectedByServer` 캡션). `OPTION_UNAVAILABLE` 은 별도 provider 에도 기록해 폴백 캡션이 옵션 사유를 말한다.
11. **가드 허용 목록 변경**: `payment_authority_guard_test` 1번에 `onMenuPriceWritten.ts`·`auditOrderPriceIntegrity.ts`(가격 필드를 **기록·보고**만 한다 — status 비교 0, 승인 분기는 import) · 신규 가드 3번에 composite 쓰기 화면 3곳(PPA-P6).
12. **선행 `payment_authority_guard_test` 2-b 와의 충돌 없음** — 새 카트/체크아웃 코드에 `'approved'`/`.status ==` 리터럴 0건.
13. **앱 DI**: `ValidateCheckoutUseCase` 의 `userTimeout` 은 생성자 기본값이 `timeout` 과 같고, 앱 provider 가 5초를 넣는다(기존 테스트가 짧은 `timeout` 으로 실패를 재현하는 방식을 깨지 않기 위해).
14. **admin 카드 위치**: 새 화면을 만들지 않고 기존 `배포 마이그레이션 (임시)` 화면에 카드로 합류했다.
15. **교차 골든에서 Dart 쪽 모델 해석을 실제 경로로** 타게 하려고 `MenuItemModel.fromData` · `OptionGroupModel.fromData` 를 `fromFirestore` 에서 추출했다(동작 동일, 요청 범위 안의 최소 변경).

## 9. 코드 생성

필요 없음 — 신규 freezed 클래스 없음.

---

## 10. T-1 재작업 (C1~C4) — test_report F-01~F-05, H-01, H-02

### 10.1 커밋 경계 (제안 — 커밋하지 않았다)

| 제안 커밋 | 내용 | 배포 |
|---|---|---|
| **C1** F-01 수량 경계 | `cart_pricing.dart`(`kMaxLineQuantity=99` · `isValidLineQuantity` · `mergeLineQuantity`) · `cartPricing.ts`(`MAX_LINE_QUANTITY` · `isValidLineQuantity` · `mergeLineQuantity`, `priceGate.ts` 는 여기서 import) · `cart_local_data_source.dart`(병합 clamp, **잘렸으면 true 반환**) → `CartRepository.addItem`/`AddToCartUseCase` 가 `Future<bool>` · 메뉴 상세 SnackBar 안내 · `cart_pricing_contract.json` 의 `quantityCases`(7)·`mergeCases`(4) · Dart/TS 골든 · `cart_quantity_clamp_test.dart` | **앱 ⑥ 빌드에 포함 필수.** 서버 변경 없음(상수 이동) |
| **C2** H-01 최소 버전 게이트 | 아래 §10.2 | 앱 ⑥ + 서버(기록 한 줄) ⑤ |
| **C3** F-02 서명 리셋 | `PriceRepricedCartSignatureNotifier` 가 카트가 null 이 되면 서명 null | 앱 ⑥ |
| **C4** F-05 가드 보강 | `payment_price_guard_test` 금지어·백틱 가드를 결제·카트 디렉터리 전체로, 원 단위 정규식 `\d[\d,]*\s*원`, Rules `PPA-1h`(approvedAt 단독 deny) · `PPA-C*` | — |
| 문서 | `deploy_runbook.md`(⑥-c · 중단 기준 10 · 기록 표 · ⑧ 확인) · `design.md` §3.0(F-04 7행) · `backlog.md`(PPA-P2 에 H-02 묶음, PPA-P8) | — |

### 10.2 C2 — 최소 버전 게이트: 어디서 버전을 읽는가

기존에 **버전 체크·강제 업데이트 패턴은 없었다**(`package_info`·`minVersion` 류 0건 — grep). 앱 문자열 버전 대신 **정수 "결제 클라이언트 수준"** 을 신설했다 (패키지 추가 없이, 빌드가 가진 *능력*을 센다).

- **앱의 수준**: `lib/core/constants/app_client_level.dart` `kPaymentClientLevel = 1` (재가격 R9 + 새 거절 화면이 들어간 빌드).
- **서버 설정**: Firestore `config/app` 문서의 `minClientLevel`(정수). 기존 `config/{docId}` Rules 로 충분하다 — 로그인 사용자 read, 쓰기는 admin(Console 포함). 하네스 `PPA-C1~C3`. 읽기는 `Source.server`(캐시 금지, `AppConfigRemoteDataSource`).
- **비교·fail 방향**: `CheckClientUpdateRequiredUseCase` — `min > clientLevel` **확인됐을 때만** `true`. 문서·필드 없음 / 예외 / 3초 시간 초과는 전부 `false`(막지 않음). 순수 판정 `core/utils/client_update.dart`. 단위 테스트가 네 방향을 고정, 위젯 테스트가 "확인 실패 → 결제 진행" 을 카트·체크아웃 양쪽에서 고정.
- **호출 지점**: 카트 `결제하기` 탭 직전(`cart_page.dart` `_onCheckout`)과 체크아웃 결제 탭 직전(`checkout_page.dart` `_handlePay`) 두 곳 → `UpdateRequiredPage`(`앱을 업데이트해 주세요` · 돈 줄 · `확인`). 서버 문자열 보간 없음, 금지어·백틱 가드가 이 디렉터리를 이미 스캔한다.
- **서버 쪽 한 줄**: 앱은 `verifyTossPayment` 호출에 `clientLevel: 1` 을 싣고, 서버는 **금액 거절 기록**의 `detail.clientLevel` 에 남긴다(숫자 아니면 `null`; 판정에는 쓰지 않는다). 구버전 비율을 재는 수단이다. 테스트: `priceAuthority.test.mjs` H-01.
- ⚠️ **한계(솔직히)**: 이 게이트는 **게이트 코드가 든 빌드만** 막을 수 있다. 이 수정 이전에 이미 설치된 앱(= 문제의 구버전)에는 게이트가 없어 스스로 업데이트 화면을 띄울 수 없다. 그래서 런북 ⑥-c 는 게이트 배포와 함께 **스토어 버전 분포 + `clientLevel==null` 기록**으로 구버전 비율을 *숫자로* 확인하고 임계값을 넘으면 ⑦ 로 가지 않게 했다(중단 기준 10). 구버전을 서버에서 강제로 막으려면 서버가 `clientLevel` 부재 요청을 거절해야 하는데, 구버전은 그 거절 사유도 몰라 갈래 C 를 띄우고 **가격이 안 바뀐 정상 결제까지 막으므로** 이번에 만들지 않았다 — 필요하면 별도 결정(`PAYMENT_MIN_CLIENT_LEVEL` 서버 스위치 + 스토어 강제 업데이트).
- 신규 파일: `app_client_level.dart` · `client_update.dart` · `app_config_repository.dart`(+Impl, `AppConfigRemoteDataSource`) · `check_client_update_required_use_case.dart` · `checkout/providers/client_update_providers.dart` · `checkout/update_required_page.dart`. `firestore_paths.dart` 에 `appConfigDocId`.

### 10.3 C1 — 조용한 데이터 손실을 피한 방법

병합이 99 로 잘리면 `addItem` 이 `true` 를 돌려주고(`CartLocalDataSource` → `CartRepository` → `AddToCartUseCase`) 메뉴 상세가 SnackBar 를 `한 메뉴는 최대 99개까지 담을 수 있어요. 99개로 맞췄어요` 로 바꿔 3초 보인다(평소 `카트에 담겼어요`). 새 화면·설계 변경 없음. 수량은 서버 `MAX_LINE_QUANTITY` 와 **같은 값을 별개로 정의**하되 같은 fixture(`quantityCases` 0/1/99/100/-1/1.5/1000000, `mergeCases` 60+60=99 등)로 양쪽을 고정한다 — 한쪽을 100 으로 바꾸면 그 쪽 골든이 깨진다(아래 변이).

### 10.4 F-03 / F-04 / H-02 처리 (코드 변경 없음)

- **F-03**: 코드는 맞다(tester 가 실 Firestore 로 12건 일회성 확인). 에뮬레이터 하네스는 **후속 `PPA-P8`** 로 backlog 등재만 했다. 이번에 실 에뮬레이터 테스트를 새로 작성하지 않았다.
- **F-04**: 동작 결함 없음(읽기 전용 표시, 판정 출처 = 병합 함수 / 주문 문서). `design.md` §3.0 에 **7행(6-14~6-20)** 을 추가해 표를 완성했다. 새 코드 경로 없음.
- **H-02**: 코드 불변. `backlog.md` **PPA-P2** 에 "옵션 `priceDelta` 조작" 과 "옵션 비활성으로 저가 선택지 제거" 를 한 항목으로 묶었다 (착수 근거 = 감사 도구 `storePairs` + 옵션 비활성 건수 — 후자는 도구가 아직 세지 않는다).

### 10.5 검증 (재작업 후)

| 항목 | 결과 |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **914 통과** (재작업 전 884) |
| `functions` `npm test` | **323 통과** (재작업 전 310) |
| `test_rules` | **463/463 통과** (재작업 전 457; 신규 `PPA-1h` · `PPA-C1~C3`) |
| 변이 (이번 batch 신규 15종) | **전건 검출**: Dart 병합 clamp 제거 · Dart 상한 100 · Dart 정수 검사 제거 · TS 상한 100 · TS clamp 제거 · TS 정수 검사 제거 · 서명 리셋 제거 · 금지어를 이전 9파일 밖(`payment_menu_list_card.dart`)에 · `17000 원` · Rules `approvedAt` 절 제거(`PPA-1h` FAIL 확인) · 게이트 fail-closed(catch → true) · 카트 게이트 호출 제거 · 체크아웃 게이트 호출 제거 · 판정 부등호 뒤집기 · 서버 `clientLevel` 미기록 |

`dart format` 은 이번 batch 에서 새로 만든 파일에만 돌렸다.
