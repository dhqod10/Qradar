# payment_server_authority 테스트 리포트 (T-1: 구현 직후 · 코드/에뮬레이터)

## 테스트 일시

- 2026-10-27
- 대상 커밋: `11c90c7`(Rules-A) `94db822`(Rules-B) `4158572`(Rules-C) `85de349`(functions+fixtures) `4a01ca1`(고객 결제 Dart) `3feb96d`(브랜드·점주·admin Dart) `ac7de30`·`8d0bca6`(문서)
- 범위: T-1 (spec §19 tester 표). **T-2(라이브, 배포 후)는 미실행** — 배포 후 확인 목록은 §"배포 후 수동 확인 목록".

---

## 테스트 방법

착수 전에 이미 확인된 것은 반복하지 않았다 (`flutter analyze` 0 / `flutter test` 729 / `functions` 178 / `test_rules` 404/404 / 구 Rules 대조 실험). 그 위에서 아래를 직접 수행했다.

| # | 방법 | 결과 |
|---|---|---|
| M-1 | spec(1,366줄)·design·implementation 통독, 코드 정적 대조 (functions / Rules / Dart 전 변경 파일) | 아래 항목별 |
| M-2 | **변이 실험 (TS 골든)** — `menuVisibility.ts`/`storeSellability.ts` 에 7종 변이 후 `npm test` | 7/7 검출 |
| M-3 | **변이 실험 (Dart 골든)** — `store_menu_visibility.dart`/`store_sellability.dart`/`checkout_menu_gate.dart` 에 5종 변이 후 계약 테스트 | 5/5 검출 |
| M-4 | **변이 실험 (가드 테스트)** — 가드 위반을 8종 주입 후 `payment_authority_guard_test.dart` | 6종 검출, **2종 미검출** (H-09) |
| M-5 | **실 Firestore(에뮬레이터) 어댑터 검증** — `makeFirestoreGateReader`·`evaluatePaymentGate`·`makeFirestoreDeletePorts`·`runDeleteStore` 를 실제 Firestore 에뮬레이터에 연결 (35개 단언) | 35/35 OK. 단위 테스트가 fake reader 만 써서 **어댑터 getAll 인덱스 계산·`in` 쿼리·recursiveDelete 가 어디서도 실행된 적 없었다** |
| M-6 | **Rules 에뮬레이터 실험** — (a) 커밋별 Rules 파일 × 커밋별/구 테스트 스위트 교차 (b) `status` create 경로 (c) 앱 실제 payload 로 R2 (d) **반려 매장 self-regress (F-02)** (e) 미등재 컬렉션 default-deny · admin 의 부모 `brandKey` 쓰기 가능 여부 | (a) P-04 (b)(c)(e) OK (d) **재현됨 → F-02** |
| M-7 | **`npm run test:emulator`** (functions+firestore 에뮬레이터) · **`test_rules` `npm run test:flow`** | 둘 다 로컬 에뮬레이터로 **실행 가능했다** (`npx firebase-tools@14`, JDK17). 96 PASS / 27/27 PASS. 단 두 스위트 모두 **게이트·deleteStore 를 호출하지 않는다** (M-5 가 그 공백을 메웠다) |
| M-8 | **빠른 재주문 위젯 실험 (임시 테스트, 실험 후 제거)** — 전부 위반/매장 불가/일부 위반(취소·나머지 담기)/확인 실패 4시나리오 | 4/4 OK. 이 경로에는 **자동 테스트가 한 건도 없었다** |
| M-9 | `git status` 로 저장소 무변경 확인 (실험 파일은 scratchpad) | clean |

실험 산출물(재현용): `/private/tmp/claude-503/-Users-Byeonguk-Developer-OrderApp/06fb23cb-93d5-476b-84e8-c85485beb04a/scratchpad/` 의 `adapter_exp.mjs`, `rules_exp/exp*.mjs`, `mut_ts.sh`, `mut_dart.sh`, `tmp_tests/zz_tmp_quick_reorder_exp_test.dart`.

---

## 전체 결과

- **PASS: 30개**
- **FAIL: 4개** (높음 2 · 중간 1 · 낮음 1)
- **보류: 14개** (라이브 필요 / 정책 판단 / 후속)
- implementation §6 의 15건: **수용 15 / FAIL 0** (단 #2·#3·#8·#12 는 문서 정정 또는 runbook 반영 부기)

### 배포해도 되는가

> **현재 상태 그대로 11단계 배포: NO-GO (조건부).** 코드 로직 자체는 반복 검증에서 견고했다 (오탐 방향 — 영업 중 매장 / 품절 아닌 메뉴 / 정상 재주문 — 은 어떤 실험에서도 막히지 않았다). 그러나 이 변경은 "되돌릴 수 없는 방향의 실패"를 만들고, 그 안전은 **순서(③ M1 → ④ Rules-A → ⑥ CF)에 전적으로 달려 있는데 코드·저장소 어디에도 그 순서를 강제하거나 감지하는 장치가 없다 (F-01)**. 또 G1 이 막으려던 "미승인 매장이 결제를 받는 길"이 **반려 매장 경로로 아직 열려 있다 (F-02)**. 이 둘이 해소되면 GO. F-03·F-04 와 모든 보류 항목은 배포를 막지 않는다.

---

## FAIL 항목

### F-01 [높음 · 배포 순서] ③→④→⑥ 순서 전제를 코드가 강제하지도 감지하지도 않는다 — 순서를 어기면 조용히 매출이 멈춘다

- 문제 (3겹):
  1. **② 와 ⑥ 이 같은 코드베이스·같은 배포 명령이다.** `functions/package.json` 의 `deploy` = `firebase deploy --only functions` (전 함수). 임시 마이그레이션 CF(`migrateStoreApprovalMeta`)는 `verifyTossPayment`(게이트)와 한 `index.ts` 에서 export 된다. spec §17 ② 에서 "백필 수단만 먼저" 올리려고 평범하게 `npm run deploy` 를 치면 **게이트가 ③ M1 과 ④ Rules-A 이전에 켜진다.** implementation §2 가 함수 단위 배포(`--only functions:migrate...`)를 적어 두었지만 문서 한 줄일 뿐, 게이트 on/off 스위치(환경 파라미터·섀도 모드)가 없다.
  2. **④ Rules-A 는 HEAD 의 `firestore.rules` 로는 단독 배포할 수 없다.** HEAD 파일에는 Rules-B+C 가 이미 들어 있다. `firebase deploy --only firestore:rules` 를 HEAD 에서 치면 ⑦(앱) 이전에 B+C 가 나가 **구 앱의 브랜드 정보 저장·`brands.create` 가 거부**된다(implementation §2 말미가 스스로 경고하는 사고). Rules-A 만 나가려면 `git show 11c90c7:firestore.rules` 를 써야 한다. 이 task 디렉토리에는 **`deploy_runbook.md` 가 없다** (`qoin_accrual_rate_hierarchy` 는 있었다).
  3. **M1 이 빠졌을 때의 탐지 수단이 사후 기록뿐이다.** 실험(M-5)·단위 테스트가 확인한 동작: `status` 필드 없는 legacy 매장은 `STORE_NOT_SELLABLE` 로 **전면 거절**된다. 그런데 고객 목록은 `fromString` 폴백으로 그 매장을 **계속 보여 주고**, 신 앱 선검증(같은 `canSellNow`)이 카트 단계에서 막으므로 Toss 창에도 도달하지 못한다 — 매출이 멈춘 것을 알려 주는 것은 `paymentGateRejections` 에 쌓이는 기록(Console 에서 admin 만)뿐이고 **알람도, 운영자용 화면도 없다.** 게다가 M1 dry-run 리포트(`setStatusApproved/backfillApprovedAt/anomalies/invalid`)는 **"M1 이후에도 게이트가 거절할 매장"** 을 보여 주지 않는다 (예: `pending` + `approvedAt` 없음, `rejected`). 운영자는 어느 매장이 막힐지 미리 알 수 없다.
  - (같은 계열) M2 도 순서 전제가 있다: ⑤ copy 가 ⑥ 보다 먼저여야 `issueBrandKey` 가 기존 키를 "이미 발급" 으로 인식한다. 어기면 **재승인 때 새 키가 발급되어 기존 키가 무효가 된다.** 이쪽은 cleanup 단계가 불일치를 `invalid` 로 멈추는 안전장치가 있어 상대적으로 낫다.
- 위치: `functions/package.json:deploy` · `functions/src/index.ts`(임시 CF + 게이트 동거) · `firestore.rules`(HEAD = A+B+C) · `functions/src/migrateStoreApprovalMeta.ts`(dry-run 리포트) · `docs/tasks/payment_server_authority/`(runbook 부재)
- 확인 방법: `cat functions/package.json` / `git show 11c90c7:firestore.rules | diff - firestore.rules` / M1 dry-run 코드에서 거절 예정 매장 목록 부재 확인. 순서 위반 결과는 `functions/test/paymentGate.test.mjs` "status 부재 (legacy — M1 전)" 가 **그 거절 동작을 정답으로 고정**하고 있다.
- 제안 (택1 이상, 권장 순):
  1. **게이트 모드 스위치** — `PAYMENT_GATE_MODE = off | shadow | enforce` (functions param). 기본 `shadow`: 판정·`paymentGateRejections` 기록은 하되 **거절하지 않는다**(`detail.shadow:true`). ② 에서 어떤 방식으로 올려도 안전하고, M1 후 shadow 기록이 비어 있음을 확인한 뒤 `enforce` 로 전환한다. "되돌릴 수 없는 방향의 실패" 에 대한 가장 싼 보험이다. (선검증 Dart 는 서버 모드와 무관하게 유지 — 선검증이 이미 거절하면 서버 모드가 무의미하므로 **앱 ⑦ 은 `enforce` 전환 이후**로 정해야 한다. runbook 에 명시.)
  2. **M1 dry-run 에 `willBeRejected`(= 백필 가정 후에도 `canSellNow` 가 false 인 매장 id·status·approvedAt 유무) 추가** — 운영자가 ⑥ 전에 "이 매장들은 막힌다" 를 눈으로 확인.
  3. **`deploy_runbook.md` 작성** — ② 는 `--only functions:migrateStoreApprovalMeta,functions:migrateBrandPrivateProfile` (+ `verifyTossPayment` 리비전 불변 확인), ④ 는 `git show 11c90c7:firestore.rules`(또는 F-02 보강 후의 Rules-A 파일), ⑥ 직전 체크리스트(M1 dry-run 빈 목록, `willBeRejected` 검토, Rules-A 라이브 확인 3-b/3-c).
- 우선순위: **높음** (배포 차단 조건)

### F-02 [높음 · G1 우회] 반려된 매장의 점주가 `status` 를 `pending` 으로 되돌리면 `canSellNow` 가 참이 된다

- 문제: admin 반려(`StoreModel.rejectFields`)는 `status:'rejected'` 와 함께 **`approvedBy`·`approvedAt` 도 쓴다** (`store_model.dart:332-340`). Rules(`isStoreOwnerFieldUpdate`/`isStoreOwnerBrandUpdate`)는 점주의 `status → 'pending'` 만 요구하고 **`approvedAt` 을 그대로 두는 것을 허용**한다. 정상 앱 경로는 `isResubmit`(= 로컬 entity 가 `rejected`)일 때 `approvedAt` 을 null 로 지우지만, 이는 **클라이언트 코드의 선택**이지 Rules 가 강제하지 않는다. 결과: `rejected + approvedAt` → (점주 SDK 직접 `updateDoc({status:'pending'})`) → `pending + approvedAt` → `canSellNow` **true**. 한 번도 승인되지 않은 채 반려된 매장도, 승인 후 수정이 반려된 매장도 결제를 받는다. spec §6.2 가 "rejected 재제출은 `isResubmit` 가 approvedAt 를 클리어한다" 에 기댄 부분이고, spec 의 §6.6 쓰기 경로 매트릭스는 이 전이를 열거하지 않았다. 앱 정상 경로에서도 admin 이 반려한 직후 점주 폼이 stale entity 로 제출되면 같은 상태가 우연히 생긴다.
- 재현 (M-6d, 에뮬레이터): seed `stores/s_rej = {status:'rejected', approvedBy:ADMIN, approvedAt:<ts>, rejectedReason:'x'}` → 점주 계정 `updateDoc(..., {status:'pending'})` **ALLOWED** → 문서는 `status:'pending'`, `approvedAt` 존재 → `canSellNow({rawStatus:'pending', hasApprovedAt:true}) === true`. 스크립트: `scratchpad/rules_exp/exp2.mjs`. 반대로 앱 정상 payload(`isResubmit:true`, 승인 메타 null 클리어)는 `canSellNow=false` 로 정확히 막힌다 (`exp4.mjs`).
- 위치: `firestore.rules:347` `isStoreOwnerFieldUpdate` · `:379` `isStoreOwnerBrandUpdate` (stores update) · `lib/data/models/store_model.dart:332`(`rejectFields` 가 approvedAt 을 씀) · `functions/src/storeSellability.ts`(입력이 "approvedAt 존재 여부" 하나)
- 제안: **Rules-A 에 포함해 ④ 에서 한 번에 배포**한다 (Rules-A 는 앱과 독립이고 ⑥ 보다 먼저 나가므로 가장 싼 자리): 점주/브랜드 update 에서 `resource.status == 'rejected'` 이고 결과 `status != 'rejected'` 이면 **`approvedAt == null && approvedBy == null` 을 강제**. 정상 재제출 payload 는 이미 null 로 지우므로 호환된다 (PSA-A7 과 같은 모양). 하네스에 "rejected → pending 이면서 approvedAt 유지" deny 1건 + "rejected → pending + 승인 메타 null 클리어" allow 1건(브랜드 보유자 분기 포함) 추가. 보강: M1 이상치 감사에 `status=='pending' && rejectedReason != null && approvedAt != null`(self-regress 흔적) 추가 — 기존 감사(`approvedBy == null` 기준)는 이 경우를 못 잡는다 (`approvedBy` 가 admin 값으로 남아 있다).
- 우선순위: **높음** (G1 의 존재 이유 훼손. 현상 대비 악화는 아니므로 배포를 *악화*시키진 않지만, Rules 를 두 번 배포하지 않으려면 ④ 이전에 넣어야 한다)

### F-03 [중간 · tester_guide 상시 항목] 게이트 입력 `status` 의 create 거부 케이스가 하네스에 없다

- 문제: `tester_guide.md` 상시 항목 — "판정 입력 필드마다 Rules 하네스에 create 거부 1건 + 정상 payload 허용 1건. 하나라도 빠지면 FAIL". G1 의 입력은 `status` 와 `approvedAt` 둘이다. `approvedAt` 은 A1·A5·A6·A7 로 완비됐으나 **`status` 를 `approved`/`rejected` 로 심은 점주 create 거부 케이스가 없다** (`grep "setDoc(doc(asOwner, 'stores'"` 전수 확인). Rules 자체는 올바르다 — 에뮬레이터 실험 M-6b 에서 `status:'approved'`·`'rejected'` create 는 DENY, 부재는 ALLOW 로 확인 — 즉 **규칙의 결함이 아니라 회귀 방지 장치의 공백**이다. F-02 의 케이스도 같은 표에 들어가야 한다.
- 위치: `test_rules/rules.test.mjs` (PSA-A 블록)
- 확인 방법: `exp.mjs` (M-6b)
- 제안: `PSA-A9 owner create status:'approved' deny`, `PSA-A9b status:'rejected' deny`, `PSA-A9c status 부재 allow`(앱은 항상 pending 을 쓰지만 Rules 는 부재를 허용) 추가. F-02 케이스와 함께.
- 우선순위: 중간

### F-04 [낮음 · UI 문구] 카트 배너 본문에 마크다운 백틱이 그대로 화면에 나온다

- 문제: `'... 방금 다시 판매를 시작했을 수도 있으니 `다시 확인`을 눌러 보세요.'` — design 문서의 마크다운 코드 서식(백틱)을 문자열에 그대로 복사했다. 3개 변형 모두 화면에 `` ` `` 문자가 출력된다.
- 위치: `lib/presentation/customer/cart/widgets/cart_availability_banner.dart:28,30,32`
- 확인 방법: `grep -n '\`다시 확인\`' lib/presentation/customer/cart/widgets/cart_availability_banner.dart` — 이 문자열을 단언하는 테스트는 없다.
- 제안: 「다시 확인」 또는 따옴표(`'다시 확인'`)로 교체. 디자이너가 design §4.2 표의 표기도 함께 정리.
- 우선순위: 낮음

---

## PASS 항목

### 기능 검증 — G1 (매장 판매 가능)

- [x] **P-01 R2 불변식: 승인 이력 있는 `pending` 은 통과, 신규·재생성(approvedAt 없음)은 거절**
  - 근거: ① 단위 `paymentGate.test.mjs` "pending + approvedAt (R2)" ② **실 Firestore 어댑터**(M-5): `{status:'pending', approvedAt:Timestamp}` 통과 / `{status:'pending', approvedAt:null}` 거절 ③ **앱 실제 payload(`toFirestoreForCoreUpdate`) 를 실 Rules 에 통과시킨 뒤**(M-6c) 승인 매장 → 핵심 수정 → `canSellNow=true`; 반려 → 재제출(승인 메타 null 클리어) → `false`.
  - 위치: `functions/src/storeSellability.ts`, `paymentGate.ts:evaluatePaymentGate`, `lib/core/utils/store_sellability.dart`
- [x] **P-02 fail 방향 표 §8.1 전 행 일치** — status 부재·미지 문자열·대소문자 다름·빈 문자열·문서 부재·경로 주입 storeId(`a/b`)·읽기 실패 모두 거절 + 기록. 정상 매장을 막는 방향의 오탐은 실험에서 발견되지 않음.
  - 근거: `paymentGate.ts:131-160`, 골든 11케이스, M-5 `E1 G1 *`
- [x] **P-03 Rules-A: create 승인 메타 자가 설정 금지** — spec §18.5 의 8케이스(A1~A8) 전부 존재, 추가로 A5b·A8b·A8c·A8d. 
  - 근거: `test_rules/rules.test.mjs:915-945`. 구 Rules 대조는 선행 확인됨.
- [x] **P-04 Rules-A 단독 배포 가능 + 구 앱 호환 (직접 검증)** — `11c90c7` 의 `firestore.rules` 는 stores/brands create 두 블록만 바꾼 14줄 diff. 이 파일 × **착수 전 341케이스 스위트 = 341/341 PASS** (구 앱이 하던 모든 쓰기가 그대로 허용됨). 커밋별 자기 스위트: `11c90c7` 353/353 · `94db822` 388/388 · `4158572` 404/404.
  - 근거: M-6a. (HEAD Rules × 구 스위트는 336/341 — 실패 5건은 전부 F4a~c 의 "점주 삭제 허용" 으로, 의도된 변경이다.)
  - 주의: 이 PASS 는 "파일을 그 커밋 시점으로 골라 배포할 때" 성립한다 → F-01-②.

### 기능 검증 — G2 (품절·판매중단) 와 교차 골든

- [x] **P-05 fixture 3종을 Dart·TS 가 같은 파일로 읽는다** — Dart `File('test_fixtures/$name')`, TS `path.join(here,'../../test_fixtures',n)`. 복제본 없음.
- [x] **P-06 `applyOverrideForCustomer` 비자명 분기를 양방향으로 덮는다 (변이 실험으로 확인)** — fixture 14케이스가 "핵심 필드는 approved 일 때만(3,5,9,10,11 미적용 / 2,4,12 적용)" 과 "운영 필드는 status 무관(6,8,10)" 을 모두 포함. **TS 변이 7종**(excluded 무조건 적용 / soldOut 을 approved 에만 / 가격 무조건 적용 / 미지 status→pending / canSellNow 의 pending+approvedAt 삭제 / canSellNow fail-open / 점포 메뉴 visible 무시) **전부 TS 테스트가 실패**했고, **Dart 변이 5종**(excluded 무조건 / soldOut 을 approved 에만 / canSellNow 두 변이 / 분류 우선순위 뒤집기) **전부 Dart 계약 테스트가 실패**했다. 즉 어느 한쪽만 바뀌어도 반대쪽 골든이 깨진다.
- [x] **P-07 실 Firestore 에서 G2 분류 정확** — 개인/점포한정/가맹 마스터 + override(pending·soldOut 거절, pending·excluded 허용, approved·excluded 거절), 개인 매장에서 마스터 id → NOT_FOUND, 사유 혼합 시 SOLD_OUT 우선·기록에는 전부.
  - 근거: M-5 `E1 *` (`getAll` 인덱스 계산 `data(n+k)`/`data(2n+k)` 포함)
- [x] **P-08 R5 · R7 · 토큰** — 거절 경로에서 confirm 미호출(spy), 거절마다 `paymentGateRejections` 1건, 기록 쓰기 실패 시 거절 유지, 토큰 문법 §15.1, `cart.items > 50` → 토큰 없는 `invalid-argument`.
  - 근거: `paymentGate.test.mjs`, `verifyTossPayment.ts:83-110,127-143`

### 기능 검증 — 서버 문자열 / 결제 실패 화면

- [x] **P-09 서버 문자열이 화면에 도달하는 경로 없음** — ① 신규·변경 presentation 파일 전수 grep: `$e`/`.toString()`/`.message`/`$error` 노출 0건 (남은 것은 날짜 포맷·위젯 파라미터명·`debugPrint`·사전 존재 `ArgumentError.message`) ② `PaymentFailure` 가 문자열을 담지 않음(`menuItemIds` 는 조회 키, `rawCode` 는 `^[A-Z][A-Z0-9_]{2,39}$` 통과분) ③ `VerifyPaymentFailure.toString` 이 message 미포함 ④ `StoreDeletionException`/`BrandKeyLookupException` 도 미포함.
  - **가드가 실제로 깨지는지(변이)**: `paymentGate.ts` 에 `soldOut` 주입 → 가드1 실패, `verifyTossPayment.ts` 에 `"approved"` 주입 → 가드2-a 실패, `cart_page.dart` 에 `.status ==` 주입 → 가드2-b 실패, `payment_result_page.dart` 에 `.toString()` 주입 → 가드6 실패, `validate_checkout_use_case.dart` 에 `fromString` 주입 → 가드3 실패. 보호하는 가드다. (약점은 H-09)
- [x] **P-10 갈래 A/B/C 화면 = design §3** — 6개 사유 헤드라인·본문·버튼·목록 헤더 문구 일치, 돈 줄은 갈래 B 에만, 갈래 C 는 `요금`/`청구` 0건 + `Log 에서 확인하기` 주 버튼(설계자 판단 `8d0bca6` 반영), 이름은 고객 카트의 `menuItemName`, 중복 1회, 미해석 id 비출력, 전부 실패 시 카드 없는 문구.
  - 위치: `payment_failure_copy.dart`, `payment_result_page.dart`, `payment_menu_list_card.dart`
- [x] **P-11 `READ_FAILED` 와 토큰 없는 네트워크 실패의 갈래 구분** — verify 경로만 code+message 를 보존(`VerifyPaymentFailure`)해 `unavailable`+`[READ_FAILED]` 는 갈래 B, 토큰 없는 `unavailable` 은 갈래 C. (실기기 확인은 H-05)

### 기능 검증 — 선검증 · 카트 · 빠른 재주문

- [x] **P-12 선검증 fail-open (§8.2) 과 N1~N6** — 읽기 실패·타임아웃(3초)·권한 오류 → `none`, `reportFailure:true`(사용자가 누른 `다시 확인`)만 예외. `CartLineAvailability` 에 `verified/ok` 없음(가드 ⓓ). 통과 시 어떤 긍정 표시도 없음. 결제 버튼은 항상 활성. 위반 시 시트는 취소 가능, "그래도 결제" 없음.
- [x] **P-13 spec §19-10: 빠른 재주문 전부 위반이면 기존 카트 유지** — 코드 순서(선검증 → 비우기)와 **M-8 위젯 실험 4/4**: 전부 위반/매장 불가는 알림만 + 카트 불변, 일부 위반은 `취소` 시 카트 불변·`나머지 담기` 시 위반 제외 품목만, 확인 실패는 막지 않고 기존 동작. (자동 테스트는 없었음 → H-12)
- [x] **P-14 카트 행/배너/하단 바 = design §4.1~4.3** — 4상태, `빼기` 버튼, `AnimatedSize`, 서버 지목(`rejectedByServer`) 메모리 플래그와 소거 시점(카트 변경 가지치기·새 결제 시도·`다시 확인` 성공), 위반 행으로 스크롤, `포함된 금액이에요` 줄. (문구 백틱은 F-04)

### 기능 검증 — B1 (brandKey / PII)

- [x] **P-15 `issueBrandKey` / `lookupBrandByKey`** — 문서 ID 유일성(`t.create`), 한 트랜잭션(키 인덱스 + private + keyHistory), 멱등(`already`), 충돌 재시도 5회, 동시 2회 → 1키, 미존재/미승인/형식 불일치 동일 응답, rate limit 분당 10(성공 호출도 계수), 반환 `{brandId,name,logoUrl}` 만.
  - 근거: `authorityCallables.test.mjs` 11건, 코드 정독.
- [x] **P-16 brandKey 행 S0~S4 · 매장 등록 폼 3경우** — S3 읽기 실패는 `관리자 승인 후` 문구가 없고(`brand_key_row_test`), 재시도는 스켈레톤으로 복귀, 폼은 미매칭/네트워크/rate limit 문구 3종 분리·인라인 에러·제출 재탭이 복구.
- [x] **P-17 PII 읽기 실패가 빈 값으로 폴백되지 않는다 (§6-2 의 두 화면)** — `brand_info_form_page`: 읽기 실패 시 폼을 열지 않고 `다시 시도`만 제공(빈 폼 → 저장 → PII 덮어쓰기 방지). `admin_brand_approval_detail_page`: 사업자 정보 섹션만 오류 표시, 승인/반려 액션 정상.
- [x] **P-18 Rules-B 케이스 전건** — 제3자(고객·점주·타 브랜드) private 읽기 거부, 부모 읽기 허용, 보유자/제출자/admin 허용, `brandKey` write 를 create·update·admin 모두 거부, 부모에 PII 거부(update·self-create), `brandKeys` 전면 거부, `keyHistory` admin 읽기만, **고객 서브컬렉션(menuItems/subCategories/optionGroups) 읽기 계속 허용(회귀)**.

### 기능 검증 — D1 (매장 삭제)

- [x] **P-19 점주 삭제 경로 0건** — Rules `delete: isAdmin()` (PSA-C1/C1b/C1c deny), UI `_ClosingGuide` 2곳(개인/가맹) 버튼 없음·임시 휴업 미안내(`my_store_closing_guide_test`), 클라이언트 `stores.delete` 0건(가드4), `DeleteStoreUseCase` 삭제.
- [x] **P-20 spec §19-12/§11.4 진행 중 주문 가드** — `paid/accepted/making/ready` 4종을 **실 Firestore `in` 쿼리**로 계수(M-5), 종결 상태 2종은 미계수, 차단 시 `failed-precondition` + `[STORE_HAS_INFLIGHT_ORDERS]`, **차단은 쓰기 0건·이력 0건·매장 문서 그대로**(M-5). `cancelTossPayment.ts:85`·`processRefund.ts:80` 이 읽는 `stores/{id}` 가 그대로 있으므로 차단 뒤 점주 취소·환불 경로는 영향받지 않는다(코드 정독; 라이브는 H-02). 환불 요청 중 주문은 UI 상 `accepted` 에 머물므로(`owner_order_detail_page.dart:964-967`) 별도 절 불필요 — spec 가정이 앱 경로에서 성립.
- [x] **P-21 spec §19-13 / §11.5 멱등** — 실 Firestore: ③에서 중단 → 매장 문서는 이미 없음·이력 `phase:'docDeleted'` → 재실행 → `done`, **이력 1건**, 하위 컬렉션 0, `affected` 는 실행 시점 값, 완료 후 재실행은 `alreadyDeleted` 쓰기 없음. 같은 ID 재생성(`createdAt` 다름) 후 재삭제 → **이력 2건**(첫 이력 불변). `createdAt` 부재 legacy(`_0`) 를 두 번 삭제해도 **이력 2건**. 단계별 중단 5종은 단위 테스트로도 고정.
- [x] **P-22 spec §19-14 admin 신규 2화면 상태** — 목록 loading(스켈레톤 6)/error(+다시 시도)/empty 0건/empty 검색 0건, 삭제 화면 loading/error/진행 중 n≥1 비활성/0 표시/삭제 중/성공/실패/경쟁 변형/이미 삭제됨. dryRun 파싱 실패는 fail-closed (`affected` 가 Map 이 아니면 실패).

### 아키텍처 · 코드 품질 · 문서

- [x] **P-23 레이어** — presentation/domain/core 에서 `cloud_firestore`·`cloud_functions`·`firebase_*` import 0건. 판정 함수 2종은 순수 Dart. `CartEntity`/`CartItemEntity` 무변경(가드).
- [x] **P-24 색상·하드코딩** — 이번 변경에서 추가된 줄에 `Color(0x`/`Colors.*` 없음(사전 존재 `Colors.transparent/white` 만). API key·secret 하드코딩 없음.
- [x] **P-25 임시 마이그레이션 CF 설계** — dry-run 기본, 이상치·무효값에서 멈추고 목록 반환, `migrationHistory` 1건, M2 cleanup 은 private 값과 일치할 때만 부모 필드 제거(불일치·부재는 `invalid` 로 정지), copy 는 private 기존 값을 덮지 않음. (M1 리포트의 공백은 F-01-③)
- [x] **P-26 신규 컬렉션 default-deny** — `brandKeyLookupLimits`·`migrationHistory` 를 admin 포함 클라이언트가 읽기/쓰기 모두 거부(M-6e). `data_ownership.md` §2.13 에 등재.
- [x] **P-27 문서 갱신 (spec §19-11)** — `data_ownership.md`·`entity_lifecycle.md` §3.3·`audit_trail.md`·`tester_guide.md`·`backlog.md`(✅ 전환·F8 흡수·`PSA-N1~N6`)·`role_flows.md`.
- [x] **P-28 에뮬레이터 스위트** — `test:emulator` 96 PASS · `test:flow` 27/27 PASS (M-7). (게이트·삭제 CF 미포함 — 그 공백은 M-5 로 보완.)

### 표면 인벤토리 (design §2) — 정·역방향

- [x] **P-29 정방향: design §2 의 모든 행을 코드에서 찾았다 (1-1~4-6, 33행)** — 신규 표면(1-3~1-6, 2-3~2-7, 3-1~3-5, 4-1~4-5)은 모두 구현 확인, 테스트도 존재(예외: 3-3 admin 승인 실패의 *화면 표시*는 위젯 테스트 없음), `기존`/`서버` 행은 무변경 확인. 판정 출처가 둘 이상인 표면은 없다 (결제 경로는 `canSellNow`·`classifyCheckoutMenu` 호출만, 가드 2-b·3).
- [x] **P-30 역방향: 코드에서 사실을 말하는 표면을 grep 으로 전수 열거 — 표에 없어서 FAIL 인 행은 없다** (네 번째 누락 없음). 방법과 결과:
  - **품절/판매중단** — `soldOut|isSoldOut|SoldOutOverlay|품절` 을 lib 전체에서 열거(41파일). 고객 표면 = `menu_item_detail_page`(2-8)·`menu_item_card`(2-9)·`menu_search_result_tile`(2-10)·`frequent_menu_items_section`(2-11)·`cart_line_tile`/`cart_page`(2-3~2-5)·`quick_reorder_section`(2-7)·`QuantityStepper`(2-8 하위 컴포넌트, 사실을 말하지 않음). 점주 표면 = 2-13. 나머지는 도메인/데이터/시드/폼 초기값/설명 주석이며, `my_store_page.dart:1242` 의 "메뉴 옵션·품절 관리" 는 진입 라벨이지 사실 진술이 아니다. **카트에 메뉴를 넣는 경로는 정확히 2곳**(`menu_item_detail_page:713`, `quick_reorder_section:267`)이고 둘 다 표에 있다.
  - **매장 판매 가능** — 승인 상태로 매장을 거르는 곳은 `store_repository_impl._filterApproved` 한 곳(1-7), `주문할 수 없어요` 문구를 쓰는 곳은 결제 실패/시트/배너/빠른 재주문(1-2~1-6)뿐.
  - **brandKey/PII** — `brandKey`·PII 5개 필드명을 lib/functions/test_rules/tools 전수 grep: 읽는 화면 = `brand_key_row`(3-1)·`store_core_form_page`(3-2)·`admin_brand_approval_detail_page`·`brand_info_form_page`(implementation §6-2 가 발견한 두 곳), 나머지는 주석·모델·시드.
  - **매장 삭제** — `deleteStore`/`.delete()` 전수: 4-1~4-5 외 없음.
  - 표에 없는 *비-사실* 접점 3개는 FAIL 이 아닌 H-10·H-11 로 기록.

---

## implementation §6 의 15건 판정

> 번호는 `implementation.md` §6 본문 번호(1~15)를 그대로 쓴다. 요청서가 따로 지목한 네 건은 본문 번호로 **2번(§10.4 누락) · 8번(정하지 않은 판정 지점) · 3번(`LookupBrandByKeyUseCase` 시그니처) · 1번(신규 callable 파일)** 이다.

| # | 내용 | 판정 | 근거 |
|---|---|---|---|
| 1 | spec §13 의 `functions_remote_data_source` 는 실제로 `cloud_functions_remote_data_source.dart` — 새 callable 3종을 신규 `authority_callables_remote_data_source.dart` 에 둠 | **수용** | spec 이 지목한 파일명이 존재하지 않는다. `qoin_callable.dart`·`brand_link_audit_remote_data_source.dart` 등 callable 래퍼를 별도 파일로 두는 선례가 있고 레이어(data)가 맞다. SDK 예외가 파일 밖으로 나가지 않는다(도메인 예외로 변환, 서버 message 미탑재). 합치는 비용은 이동뿐. 리전 상수(`asia-northeast3`)가 두 파일에 중복 → 후속 정리 후보 |
| 2 | spec §10.4 표에서 `admin_brand_approval_detail_page`·`brand_info_form_page` 누락 | **수용 (표 누락 확인 · 추가 누락 재검 완료)** | 두 곳 모두 `private/profile` 로 옮겼고 **읽기 실패를 빈 값으로 폴백하지 않는다**(P-17). §10.4 를 역방향 전수 재검했다(brandKey·PII 필드명을 lib/functions/test_rules/tools 전수 grep + 부모 brand 문서를 읽거나 쓰는 Dart·CF·Rules·테스트·시드 열거): **앱 코드의 추가 누락은 없다.** 앱 밖 잔여 3건은 FAIL 이 아니라 보류로 기록 — H-10(`flow.test.mjs` 6단계가 구 방식을 여전히 모델링, 낡은 주석 3곳) · H-11(시드 매장에 approvedAt 없음) · H-15(admin 은 부모 `brandKey` 를 여전히 쓸 수 있음). 추가로 admin 승인 실패(`BrandKeyIssueException`)의 **화면 표시는 위젯 테스트가 없다**(리포지토리 단위 테스트만). architect 가 spec §10.4 를 보강하길 권고 |
| 3 | `LookupBrandByKeyUseCase` 시그니처 변경 (`BrandEntity?` → `BrandKeyLookup` + `BrandKeyLookupException`) — spec §13 은 "유지" | **수용** | spec §13 "유지" 는 design §5.4(미매칭/네트워크/rate limit 세 문구) 및 spec §3 U4("읽기 실패를 미발급·미매칭으로 오해시키지 않는다")와 **spec 내부에서 충돌**한다. `BrandEntity?` 한 값은 null 이 "없다" 와 "확인 못 했다" 를 구분하지 못한다. 변경은 domain 안에서 끝나고(UseCase·Repository 인터페이스·엔티티·예외) 유일한 소비자(`store_core_form_page`)가 3경우를 분리해 그린다(위젯 테스트 5건). `BrandKeyCollisionException` 은 서버 이동으로 소멸. spec §13 정정 권고 |
| 4 | `migrateQoinZeroRates` 패턴이 코드에 없어 새로 작성 | **수용** | 같은 계약(dry-run 기본, 이상치에서 멈추고 보고, 이력 1건)을 구현했고 P-25 에서 확인. 런북 ⑧ 정리로 이미 삭제된 자산이라 참조할 수 없었던 것이 사실 |
| 5 | backlog 의 기존 N1 과 겹쳐 `PSA-N1~N6` 로 등재 | **수용** | `backlog.md:711-720` 에 등재 확인. 충돌 회피로 타당 |
| 6 | design §3.3 vs spec §18.3 6-c ⓒ 충돌 (갈래 C 에 `요금`/`청구` 금지) | **수용 (해결됨)** | 설계자가 `8d0bca6` 로 design 문구를 가드에 맞췄다. 코드·design·가드 일치 확인(P-10) |
| 7 | `checkout_page` 바깥 catch 를 갈래 C 가 아닌 `PaymentFailure.launch()` 로 | **수용** | 바깥 catch 는 선검증·결제창 단계 예외뿐이고 Toss confirm 은 서버(verify)에서만 일어난다 → 돈 안 움직임. 서버 호출 예외는 안쪽 catch 가 `PaymentFailure.from` 으로 처리. 주의: 이 구분은 "verify 호출이 안쪽 try 안에 있다" 는 구조에 의존 — 코드 주석이 그 사실을 적고 있어 충분 |
| 8 | spec 이 정하지 않은 판정 지점을 "막지 않는 쪽" 으로 구현 (마스터 visible/status 미검사 · 점포 한정 status 미검사 · 사유 혼합 시 1사유 토큰 · override 미지 status→approved · 경로 오염 id) | **수용 (단 override 항목은 라벨 정정)** | ⓐ 마스터 `visible=false`/`status≠approved` 미검사: spec §7.2 ③ 이 `applyOverrideForCustomer` 결과만 본다고 정의 → 일치, 막지 않는 방향(정책 판단은 H-14). ⓑ 점포 한정 `status` 미검사: 같은 근거. ⓒ 혼합 사유 토큰 1개: 기록에는 전부 남고(M-5) 선검증은 위반 전부를 한 번에 보여 준다. ⓓ **override 미지 status→approved 는 "막지 않는 쪽" 이 아니다** — approved 로 읽으면 `excluded:true` 가 적용되어 **오히려 거절 쪽으로 기운다.** 그러나 이 선택의 진짜 근거(= Dart `fromString` 과 같아야 "고객이 본 화면 = 결제 결과", spec §8.1 G2 row)는 옳고 골든 #12 가 고정한다. 비대칭의 의도: 매장 `status` 는 **돈을 받는 문(권한 값)** 이라 미지값을 거절(fail-closed), override `status` 는 **어느 필드를 적용할지 고르는 값**이라 화면과 일치시키는 쪽(= Dart 폴백). 둘은 다른 질문이므로 비대칭이 의도에 맞다. 실무 영향은 Console 오타 + `excluded:true` 동시 발생뿐이고 그 메뉴는 고객 목록에서도 숨겨진다. implementation 의 "막지 않는 쪽" 문구를 "화면과 같은 쪽" 으로 정정 권고. ⓔ 경로 오염 id → 읽지 않고 NOT_FOUND, 토큰 미탑재: 안전 |
| 9 | Rules 하네스 F4a/b/c 갱신 (점주 삭제 → deny, 이후 단계는 Admin SDK 삭제로 준비) | **수용** | 구 스위트 × HEAD Rules 실행에서 실패는 정확히 그 5건뿐(M-6a) — 의도된 변경 외 회귀 없음. 재생성 이후의 create 제약 검증은 유지됨 |
| 10 | spec 에 없는 신규 컬렉션 `brandKeyLookupLimits`·`migrationHistory` | **수용** | Rules 없음 = default-deny 를 실험으로 확인(P-26), 문서 등재. `migrationHistory` 는 spec §9-5 가 요구한 일괄 처리 기록 |
| 11 | 시드: `private/profile` 은 클라이언트로, `brandKeys`/키는 별도 단계(실패 시 로그) | **수용** | dev 도구. 실서버는 `issueBrandKey`. 단 시드 매장에 `approvedAt` 이 없다 → H-11 (T-2 오경보 주의) |
| 12 | M2 과도기 한계: ⑥~⑨ 사이 `issueBrandKey` 로 승인된 브랜드는 부모에 키 복사본 없음 | **수용 (runbook 반영 필요)** | R8 때문에 의도. 구 앱 점주의 조회 실패 구간. 추가로 확인한 인접 위험: ⑦~⑧ 사이(신 앱 × 구 Rules)에는 brandKey 행뿐 아니라 **브랜드 정보 저장·admin 승인 상세의 PII 섹션도 `permission-denied`** 가 된다(spec §17.1 은 brandKey 행만 적음). 창이 수 분이면 수용 가능. ⑨ 전에 copy 재실행 + dry-run 0 을 runbook 에 (M2 cleanup 이 불일치를 멈춰 주므로 안전망은 있음) |
| 13 | 타임아웃: 클라 120초 vs CF 300초 | **수용** | 클라가 먼저 포기해도 CF 는 계속, 재실행 멱등(P-21). 실패 문구가 이 상황을 그대로 말한다. 동시 2회 호출은 H-13 |
| 14 | 새 읽기 provider 4개 Riverpod 자동 재시도 해제 | **수용** | 기존 `readNoAutoRetry` 패턴. "읽기 실패"를 즉시 보이는 것이 S3/오류 UI 의 전제 |
| 15 | `payment_method_tile.dart:140` 사전 존재 `Colors.black87` | **수용** | 범위 밖, 이번 diff 가 도입한 것이 아님 |

---

## 보류 항목

- [ ] **H-01 라이브(T-2) 전체** — 이유: 배포 전. 필요한 확인: 아래 "배포 후 수동 확인 목록".
- [ ] **H-02 진행 중 주문 차단 뒤 점주 취소·환불의 라이브 동작 (spec §19-12)** — 이유: 코드상 차단 시 매장 문서·이력·하위 문서가 전혀 변하지 않아 `cancelTossPayment`/`processRefund` 의 `stores` 조회가 그대로 성공하지만, 실제 Toss 취소·환불 호출까지의 라이브 확인은 배포 후.
- [ ] **H-03 설계 Q1: "요금도 청구되지 않았어요" 사실 확인** — 이유: 카드/카카오페이가 confirm 전에 카드사 알림·승인 보류를 만들 수 있는지는 실결제로만 확인. 틀리면 `kGateMoneyLine` 을 `아직 결제가 완료되지 않았어요` 로 즉시 교체.
- [ ] **H-04 `deleteStore` 진행 중 주문 쿼리의 복합 인덱스 필요 여부** — 이유: 에뮬레이터는 인덱스를 검사하지 않는다(M-5 는 쿼리 동작만 증명). `storeId ==` + `status in` + `count()` 는 인덱스 병합으로 처리될 가능성이 높으나 미확정. 필요한 확인: 배포 후 `deleteStore {dryRun:true}` 1회 — 에러가 나면 콘솔 링크로 인덱스 생성.
- [ ] **H-05 실기기에서 `unavailable` + `[READ_FAILED]` 토큰이 iOS/Android SDK 를 통과하는지** — 이유: 기존 `_convertFunctionsException` 이 `unavailable` 에서 message 를 버렸던 사실이 이 설계의 전제(`backlog.md:566-569` 의 details 문제와 같은 계열). 단위 테스트는 파서만 증명. 필요한 확인: 로컬 functions 에뮬레이터 + 앱, 또는 라이브에서 Firestore 읽기를 실패시켜 갈래 B `READ_FAILED` 화면 확인.
- [ ] **H-06 `deleteStore` 진행 중 주문 가드의 TOCTOU** — 이유: 계수(가드)와 매장 문서 삭제(②) 사이에 새 주문이 `paid` 로 생성될 수 있다(고객이 그 순간 결제 → 게이트가 아직 매장을 본다). 창은 ms~수초, 삭제는 admin 이 드물게 하는 동작. 발생 시 그 주문의 취소·환불이 묶인다. 필요한 확인: 정책 판단 — ②직후 재계수 후 >0 이면 경고 로그/admin 알림(복원은 이력 snapshot 으로 가능) 정도의 완화.
- [ ] **H-07 `deleteStore` 의 메뉴 이미지(`menu_images/...`) Storage 정리 안 함** — 이유: implementation §5 에 기록된 알려진 한계(spec 이 images 를 매장 이미지로만 정의). 삭제된 매장의 메뉴 이미지가 고아로 남는다. 후속 task 후보.
- [ ] **H-08 정책: 영업 중 매장의 *수정이 반려*되면 결제가 멈춘다** — 이유: `rejected` 는 `approvedAt` 이 있어도 `canSellNow=false`(골든 "rejected + approvedAt"). 반려 직전까지 팔던 매장이 반려 즉시 막힌다(이전에는 장바구니로 계속 결제 가능했음). 의도된 정책인지 사용자 판단 필요 — 의도라면 N2(핵심 수정 분리) 가 풀어야 하고, F-02 보강과 같은 전이 규칙으로 정리.
- [ ] **H-09 가드 테스트의 약점 (변이 실험에서 확인)** — (a) `switch (x.status)` 형태는 가드 2-b 가 잡지 못함 (`.status ==` 만 검사) (b) `rules.contains("get('approvedAt', null) == null")` 은 **brands 규칙에도 같은 문자열이 있어** stores 쪽을 지워도 통과 (`approvedBy` 도 동일; `rejectedReason` 만 stores 전용) — 하네스 PSA-A1~A3 가 실제 보호 (c) 가드6 은 `payment_result_page.dart`·`checkout_page.dart` 두 파일만 본다 (d) 가드 ⓐ 는 `PaymentFailure` 객체의 필드를 합쳐 검사하지 렌더된 위젯 트리를 보지 않는다(화면 테스트가 일부 보완). 모두 현재 코드는 위반하지 않음. 가드 강화는 후속.
- [ ] **H-10 낡은 테스트·주석** — `test_rules/flow.test.mjs` 6단계("admin 승인: ... brandKey 발급 (admin 전권)")는 구 방식(admin 이 부모에 brandKey 기록)을 그대로 모델링하고 있고 27/27 은 통과하지만 새 승인 경로(`issueBrandKey` → 상태 승인)를 검증하지 않는다. `store_brand_block.dart:12`·`store_brand_link.dart:8`·`rules.test.mjs` RM18 라벨의 "`brandKey` 가 공개" 는 이제 사실이 아님(비공개). implementation §5 가 `flow.test.mjs` 재확인을 요청했고 본 리포트가 실행 결과를 기록(M-7).
- [ ] **H-11 시드 매장에 `approvedAt` 없음 (T-2 오경보 위험)** — `lib/dev/seed/phase1_seed_data.dart` 의 `storeDoc`·`brandStoreDoc` 은 `status:'approved'` 만 쓴다. M1 이 전체 매장을 백필하므로 기존 시드는 안전하지만, **M1 이후에 새로 시드한 매장으로 T-2 ⑩-2("핵심 수정 후 결제")를 하면 승인 이력이 없어 거절되고, spec §17.3 의 "즉시 ⑥ 롤백" 조건이 오경보로 발동한다.** T-2 ⑩-2 는 반드시 admin 승인 흐름을 거친 매장으로. 시드에 `approvedAt` 추가는 후속(낮음).
- [ ] **H-12 빠른 재주문 자동 테스트 부재** — 이번에 임시 위젯 테스트로 4시나리오를 검증했으나(M-8) 저장소에는 `QuickReorder` 를 다루는 테스트가 0건. 고객 카트를 통째로 날릴 수 있는 경로이므로 임시 테스트(`scratchpad/tmp_tests/zz_tmp_quick_reorder_exp_test.dart`)를 정식 테스트로 승격 권장.
- [ ] **H-13 게이트·`deleteStore` 운영 가시성** — (a) `paymentGateRejections` 는 오탐 탐지 장치(spec §8.3)이지만 admin 이 볼 UI 가 없다 — Console 로만. (b) 인증된 사용자가 무효 카트로 `verifyTossPayment` 를 반복 호출하면 거절 기록이 제한 없이 쌓인다(rate limit 없음, 비용). (c) `deleteStore` 동시 2회 호출(클라 120초 포기 후 재시도)은 멱등 설계상 무해해 보이나 테스트하지 않았다. 필요한 확인: 배포 후 일정 기간 `paymentGateRejections` 일일 점검 루틴.
- [ ] **H-14 정책: 마스터 메뉴가 숨김/재심사(`visible=false`, `status≠approved`)가 된 뒤 이미 카트에 담긴 것은 결제된다** — spec §7.2 ③ 에 따른 의도(막지 않는 쪽)이며 오탐 0 방향. 브랜드가 메뉴를 내려도 카트에 있던 건은 팔린다는 점을 사용자가 인지하면 충분.
- (참고, 보류 아님·정보) H-15 admin 은 Rules 상 부모 `brands.brandKey` 를 여전히 쓸 수 있다(M-6e) — ⑨ 이후 구 admin 앱이 승인하면 키가 다시 공개 영역에 남는다. 앱 ⑦ 배포 후엔 발생하지 않으나, 완전히 닫으려면 ⑨ 이후 Rules 에서 부모 `brandKey` 키를 전원 거부. H-16 `getById`/`watchById` 경로(즐겨찾기·직접 진입)는 status 를 거르지 않아 미승인 매장 페이지가 열릴 수 있다 — 사실을 *주장*하지는 않아(표 비해당) FAIL 이 아니며 서버 게이트·카트 선검증이 막는다. `store_menu_header` 의 영업 중/마감은 영업시간 표시일 뿐 `canSellNow` 와 무관(N6 때 함께). 
- (참고) 코드 품질: `checkout_page.dart`·`cloud_functions_remote_data_source.dart` 등에 이번 기능과 무관한 `dart format` 재배치가 섞여 diff 가 커졌다 (요청 범위 밖 변경은 아니나 리뷰 비용).

---

## spec §19 tester 예외 케이스 1~14 수행 결과

| # | 케이스 | 결과 |
|---|---|---|
| 1 | 승인 매장이 핵심 필드 수정 직후 결제 | **PASS** — 앱 payload × 실 Rules × 실 Firestore 게이트 (P-01). 라이브는 T-2 ⑩-2 |
| 2 | `status` 없는 legacy 매장 M1 전/후 | **M1 전 = 전면 거절(고정된 동작), M1 후 = approved 로 통과** — 그러나 **M1 전 상태를 막거나 알려 주는 장치가 없다 → F-01** |
| 3 | override `pending`+`soldOut` 거절 / `pending`+`excluded` 통과 | **PASS** (골든 6·3 · 실 Firestore) |
| 4 | 품절 메뉴명이 거절 문구에 보이는가 | **PASS** (토큰 id → 카트 이름, 위젯 테스트) |
| 5 | 선검증 네트워크 실패 시 결제가 막히지 않는가 | **PASS** (UseCase 단위 + 위젯 실험; 실기기는 T-2) |
| 6 | brand_info_page 읽기 실패가 "미발급" 으로 보이지 않는가 | **PASS** (S3 테스트) |
| 7 | 점주 삭제 버튼 잔존 | **PASS** (개인·가맹 모두 없음) |
| 8 | admin 매장 승인의 `BrandScopeBadge` 회귀 | **PASS(코드·Rules)** — 부모 read 유지(PSA-B2), 위젯 무변경. 라이브 ⑩-7 |
| 9/9-b | 표면 전수 열거 / create·update 교차 | 9 **PASS**(P-29/30) · 9-b **`approvedAt` PASS, `status` 및 반려→pending 전이는 FAIL(F-02·F-03)** |
| 10 | 빠른 재주문 전부 위반 시 기존 카트 유지 | **PASS** (M-8) |
| 11 | 토큰 id → 이름, 2개 이상 전부 열거, 옵션 2줄 1회, 미해석 id 비출력 | **PASS** (`payment_authority_screens_test`) |
| 12 | 진행 중 주문 삭제 차단 + 차단 뒤 취소·환불 | **차단 PASS(실 Firestore)** / 차단 뒤 취소·환불 라이브 = H-02 |
| 13 | `deleteStore` 중단 후 재실행 이력 1건, 재생성 후 재삭제 이력 2건 | **PASS** (실 Firestore) |
| 14 | admin 신규 2화면 loading/error/empty/검색 empty | **PASS** (P-22) |

---

## spec §21 완료 기준 대조

| 기준 | 상태 |
|---|---|
| Q1~Q6 결정 반영 | 완료 |
| §6.7 create·update 교차 (판정 입력 필드별) | **미완 — F-03(`status`), F-02(반려→pending)** |
| Rules-A 가 ⑥ 보다 먼저 | **배포 시점 항목 — 강제 장치 없음 (F-01)** |
| design / implementation / test_report | 완료 / 완료 / 본 문서 (T-2 미완) |
| R1~R14 | 구현됨. R9 는 ⑨ 까지 가야 이행 (배포 단계) |
| 승인 매장 핵심 수정 직후 결제 성공 | 코드·Rules·Firestore 어댑터 PASS / **라이브 확인 필요** |
| confirm 미호출 · 메뉴명 노출 · 서버 원문 미노출 | PASS |
| 진행 중 주문 매장 삭제 차단 · `deleteStore` 멱등 | PASS |
| admin 화면 + `role_flows.md` | PASS |
| 교차 골든 2종(실제 3종) · 가드 7항목 | PASS (가드 약점 H-09) |
| Rules: 제3자 private 거부 · 점주 delete 거부 · 고객 서브컬렉션 허용 | PASS |
| M1·M2 dry-run 0건 수렴 · ⑨ 완료 · 이상치 0건 | **배포 단계 항목** |
| 이력 3종이 실제로 쓰인다 | `paymentGateRejections`·`storeDeletionHistory` 실 Firestore 에서 쓰임 확인 / `keyHistory` 는 단위 테스트(실 Firestore 미확인) |
| `flutter analyze` / `flutter test` / `functions npm test` | 선행 확인됨 (0 / 729 / 178) |
| FAIL 없음 또는 후속 분리 | **F-01·F-02 는 배포 전 해결 권고** |

---

## 설계자 전달 메시지

### 요약

- 전체 판단: **로직은 견고하고 오탐 방향 실험에서 결제를 잘못 막은 사례가 없다.** 문제는 코드 밖(순서)과 Rules 의 한 전이(반려→pending)에 있다. 두 가지 모두 이 task 의 핵심 위험 — "되돌릴 수 없는 방향의 실패" 와 "게이트가 장식이 되는 것" — 에 정확히 해당한다.
- 이번 검증에서 새로 드러난 것 (착수 전 검증이 보지 못한 영역): ① 게이트 어댑터·`deleteStore` 포트가 실 Firestore 에서 한 번도 실행된 적 없었다 → 직접 실행해 이상 없음 ② Rules-A 의 독립성·구 앱 호환을 파일 단위로 증명 ③ 변이 실험으로 골든이 양방향임을 증명, 가드는 대체로 보호하나 약점 4건 ④ **F-02**.

### 재작업 우선순위

1. **F-02 — Rules-A 에 "rejected → 다른 상태 전이 시 승인 메타 null 강제" 추가** (+ 하네스 2건, F-03 의 `status` 케이스 포함). Rules-A 는 ④ 에서 가장 먼저 나가므로 이 시점이 가장 싸다. 이유: G1 이 막으려던 경로가 열려 있고, Rules 를 두 번 배포하지 않으려면 ④ 이전이어야 한다.
2. **F-01 — 게이트 모드 스위치(shadow→enforce) 또는 최소한 `deploy_runbook.md` + M1 dry-run 의 `willBeRejected`.** 이유: ②를 평범한 `npm run deploy` 로 치는 순간 ③④ 없이 게이트가 켜지고, M1 누락은 알람 없이 매출만 멈춘다.
3. **F-03** — `status` create deny 3건 하네스 보강 (1번과 같은 커밋).
4. **F-04** — 백틱 3곳 (언제든).
5. 보류 중 먼저: H-11(T-2 전 시드 확인), H-04(배포 직후 dryRun), H-05(실기기 READ_FAILED), H-12(빠른 재주문 테스트 승격).

### 후속 task 후보

- 게이트 가시성: admin `paymentGateRejections` 보기 화면 + 임계치 알림 (H-13) — 오탐 탐지가 Console 수작업에 머무는 한 "오탐 시 매출 정지" 가 사후 발견이다.
- `deleteStore` 메뉴 이미지 Storage 정리 (H-07) · TOCTOU 완화 (H-06).
- 가드 강화 (H-09) · `flow.test.mjs` 신 승인 경로로 갱신 (H-10) · 시드 `approvedAt` (H-11).
- N2(핵심 수정과 pending 회귀 분리) 우선순위 재검토 — F-02·H-08 이 같은 뿌리("승인 이력" 을 `approvedAt` 한 필드에 기대는 구조)에서 나온다. `approvedAt` 이 승인과 반려 양쪽에서 쓰이는 의미 중복이 장기적으로 `rejectedAt` 분리를 요구한다.
- spec §10.4(표 2행 누락) · §13(`LookupBrandByKeyUseCase` 시그니처, 파일명 `functions_remote_data_source`) 정정.

---

## 배포 후 수동 확인 목록

> 순서가 곧 안전이다. **굵은 항목은 중단 기준(spec §17.3)에 걸린다.**

### 배포 전 사전 점검 (② ~ ⑥ 사이)

1. ② 임시 CF 만 배포: `firebase deploy --only functions:migrateStoreApprovalMeta,functions:migrateBrandPrivateProfile`. 배포 후 `verifyTossPayment` 의 리비전이 **바뀌지 않았음**을 콘솔에서 확인 (F-01 미해결 시 필수). 게이트 모드 스위치를 도입했다면 `shadow` 확인.
2. ③ `migrateStoreApprovalMeta {dryRun:true}` — `anomalies`·`invalid` 모두 빈 목록이어야 실행. **dry-run 결과의 모든 매장에 대해 "M1 후에도 `status != approved` 이고 `approvedAt` 없음" 인 매장을 사람이 목록으로 확인** (현재 리포트가 보여 주지 않음 → `stores` 콘솔 직접 확인 또는 F-01 제안 2). 실행 후 재 dry-run = 전부 0.
3. ④ Rules-A: **HEAD 가 아니라 Rules-A 파일(`git show 11c90c7:firestore.rules`, F-02 보강 시 그 파일)** 을 배포. 배포 직후 점주 계정 SDK 로: `approvedAt`/`approvedBy`/`rejectedReason` 을 담은 매장 create → 각각 거부 (spec ⑩-3b/3c), **반려 매장에서 `status:'pending'` 만 바꾸는 update → 거부 (F-02 보강 시)**, 정상 매장 등록 → 성공.
4. ⑤ `migrateBrandPrivateProfile {stage:'copy', dryRun:true}` → 무효 목록 비어 있음 → 실행. `brandKeys` 문서 수 = 키 보유 브랜드 수.
5. ⑥ 직전: 승인 대기 브랜드가 없는지 확인 (implementation §6-12). 필요 시 `shadow`→`enforce` 전환은 M1 후 `paymentGateRejections` 에 예상 밖 기록이 없음을 본 뒤.

### 라이브 검증 (⑩ = spec §17.2 전 11개 + 아래 추가)

- **⑩-1/⑩-2** 승인 매장 정상 결제 → 핵심 필드(전화번호 아님 — 이름/주소) 수정 → `status:'pending'` 회귀 확인 → **같은 매장 결제 성공.** *매장은 admin 승인 흐름을 거친 것(approvedAt 존재)을 쓴다 — 신규 시드 매장 금지 (H-11).*
- ⑩-3 미승인 신규 매장에 CF 직접 호출 → 거절 + `paymentGateRejections` 1건. **반려된 매장도 같은 호출 → 거절** (F-02).
- ⑩-4~6 품절 / override `pending`+`soldOut` 거절 / `pending`+`excluded` 성공. 거절 화면에 **메뉴명 전부**, 옵션 2줄이어도 1회.
- ⑩-7/8 brandKey: 점주 조회 정상, 타 브랜드 `private/profile` 직접 읽기 거부, brandKey 로 매장 등록, **admin 매장 승인 화면 `BrandScopeBadge` 정상(경고면 ⑧ 롤백)**.
- ⑩-9/10 점주 `stores/{id}` delete 거부 · admin 더보기 → 매장 관리 → 목록 → 삭제: dryRun 숫자 표시 → 테스트 매장 삭제 → `storeDeletionHistory` 1건(`done`) + 하위 컬렉션 0 + Storage 매장 이미지 0 (메뉴 이미지는 남음 — H-07).
- ⑩-10-b 진행 중 주문이 있는 매장 삭제 화면 → 비활성 + 사유 + 다시 불러오기. **그 주문의 점주 취소/환불 승인이 정상 동작** (H-02).
- **⑩-10-c (Q1)** 실제 카드 / 카카오페이 각각으로 게이트 거절 유발 → 카드사 알림·결제 내역에 **아무것도 남지 않는지.** 남으면 `kGateMoneyLine` 즉시 교체.
- ⑩-11 품절 해제 후 같은 카트로 결제 성공 (오탐 복구).

### 추가 확인 (design §9.3 · 본 리포트)

- 선검증 **네트워크 차단(비행기 모드) 상태**에서 카트 → 체크아웃 → Toss 창까지 진행되는지, 그 화면에 통과를 암시하는 요소가 없는지 (N1·N3). `다시 확인` 은 실패 시 SnackBar.
- 서버가 지목했으나 선검증은 정상인 경우 카트 행의 `rejectedByServer` 캡션.
- 빠른 재주문: 전부 위반 시 기존 카트 유지 (실기기).
- brandKey 행 S0~S4 유도 (읽기 차단 → S3, 승인 후 키 삭제 → S4). **S3 에서 `관리자 승인 후` 문구가 보이면 FAIL.**
- 점주 `my_store_page` 개인/가맹 두 화면에 삭제 버튼 없음.
- `READ_FAILED` 토큰이 iOS/Android 에서 갈래 B 화면으로 이어지는지 (H-05).
- 첫 `deleteStore {dryRun:true}` 호출에서 인덱스 오류가 나는지 (H-04).
- 카트 배너 문구에 백틱이 남아 있는지 (F-04).
- ⑦→⑧ 창 동안 신 앱 × 구 Rules 에서 깨지는 화면(brandKey 행 · 브랜드 정보 저장 · admin 승인 상세 PII)을 인지하고 창을 수 분으로.
- ⑨ M2 cleanup 직전: copy 재실행 + dry-run 0, **구 앱 부재 확인**, 실행 후 부모 `brands/*` 에 `brandKey`/PII 가 없는지, `lookupBrandByKey` 가 여전히 동작하는지 (R8·R9 최종).
- 가동 후 일정 기간 `paymentGateRejections` 일일 점검: `reason` 분포, `STORE_NOT_SELLABLE` 의 `detail.rawStatus`(null·미지값이면 M1 누락 신호), `MENU_SOLD_OUT` 의 건수 급증.
- ⑪ 임시 CF 2개 + `authorityCallables.test.mjs` 해당 테스트 정리.

---

## 완료 판단

- [ ] 전체 PASS
- [ ] FAIL 있으나 후속 task로 분리 가능
- [x] **재작업 필요** — F-01 · F-02 는 배포 전 조치 권고(F-02 는 Rules-A 에 포함), F-03 은 같은 커밋, F-04 는 후속 가능. 조치 후 이 문서의 해당 항목만 재검증하면 된다 (T-1 재실행 범위: Rules 하네스 + 게이트 모드/런북 확인).
