# payment_server_authority 구현 기록

- 작성: 2026-10-27
- 작성자: developer
- 기준: `spec.md`(§19 분배·§17 배포 순서), `design.md`
- 상태: **코드 완료, 배포 전.** 라이브 검증(spec §17.2 / T-2)은 하지 않았다.

## 0. 검증 결과

| 항목 | 결과 |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **729 전부 통과** (착수 시 552) |
| `functions` `npm test` (= `tsc` 빌드 + 단위/골든) | 178 통과 |
| Rules 하네스 `test_rules` `npm test` | 404/404 통과 (착수 시 341). Rules-A 신규 12건은 **구 Rules 에서 5건 FAIL** 로 실제로 구멍을 잡음을 확인 |
| 교차 골든 | Dart `test/core/payment_authority_contract_test.dart` 와 TS `functions/test/paymentAuthority.test.mjs` 가 **같은 fixture 3종**을 읽는다 |
| 미실행 | `functions` 에뮬레이터 E2E(`test:emulator`, `test:flow`), 실기기, 라이브(T-2) |

## 1. 구현 파일 (커밋 경계 포함)

### 커밋 경계

| 커밋 | 내용 | 독립 적용 |
|---|---|---|
| `11c90c7` **Rules-A** | `firestore.rules`(stores/brands create 승인 메타 금지) + `test_rules/rules.test.mjs`(PSA-A 12건) | **단독 적용 가능** — 배포 ④. 구 앱 create payload 는 해당 키를 보내지 않는다 |
| `94db822` **Rules-B** | `private/profile` · `brandKeys` · `keyHistory` · 부모 PII whitelist 제거 · brand self-create PII 금지 + PSA-B 케이스 | 앱(⑦) 직후 — 배포 ⑧ |
| `4158572` **Rules-C** | `stores.delete` admin 전용 · `paymentGateRejections` · `storeDeletionHistory` + PSA-C 케이스 + F4 기존 케이스 갱신 | 앱(⑦) 직후 — 배포 ⑧ (B 와 함께 또는 연속) |
| functions + fixtures | `functions/src/*`, `functions/test/*`, `test_fixtures/*` 3종 | 배포 ②/⑥ |
| Dart 고객 결제 측 | checkout/cart/quick_reorder + 판정 함수 + PaymentFailure | 앱 ⑦ |
| Dart 브랜드·점주·admin 측 | brandKey/PII/삭제 | 앱 ⑦ |
| 문서 + 가드 | docs 갱신, `payment_authority_guard_test.dart`, 이 문서 | — |

Rules-A/B/C 는 각각 `firestore.rules` 의 서로 다른 블록만 만진다 (Rules-A: stores/brands create 조건 / B: brands 하위·`brandKeys` / C: stores delete + 신규 컬렉션 2개). 각 커밋은 그 시점의 `rules.test.mjs` 전건 통과 상태다.

### functions (TypeScript)

| 파일 | 역할 |
|---|---|
| `src/storeSellability.ts` | `canSellNow` — Dart 와 교차 골든 |
| `src/menuVisibility.ts` | `applyOverrideForCustomer` TS 포팅 + `classifyCartMenu` (문서 존재로 역추론). **TS 쪽 `soldOut`/override status 비교는 이 파일 1곳** (가드) |
| `src/paymentGate.ts` | `evaluatePaymentGate` (G1+G2, Firestore 비의존) · `buildRejectionMessage`(토큰 §15.1) · 상한 50 |
| `src/paymentGateReader.ts` | Firestore 어댑터(`getAll` 1회) + `recordGateRejection` |
| `src/verifyTossPayment.ts` | 게이트 삽입(멱등 가드 직후, Toss confirm 직전). 본문을 `handleVerifyTossPayment(deps, request)` 로 분리(주입 이음새, 로직 불변). `cart.items` 50 상한 |
| `src/lookupBrandByKey.ts` · `issueBrandKey.ts` · `brandKeyCore.ts` | brandKey 조회(rate limit 분당 10)·발급(`brandKeys` 문서 ID 유일성 + `private/profile` + `keyHistory` 한 트랜잭션, 멱등) |
| `src/deleteStore.ts` | admin 전담 삭제. `dryRun` · 진행 중 주문 가드 · `storeDeletionHistory` phase 재진입(멱등) · Storage 정리 |
| `src/migrateStoreApprovalMeta.ts` · `migrateBrandPrivateProfile.ts` | 임시 마이그레이션 M1 / M2(copy·cleanup). dry-run 기본, 이상치·무효값은 멈추고 보고, `migrationHistory` 1건 |
| `src/index.ts`, `package.json`(test 스크립트) | export / 테스트 목록 |
| `test/paymentAuthority.test.mjs` · `paymentGate.test.mjs` · `authorityCallables.test.mjs` | 골든 · 게이트(매장 6 × 메뉴 5, confirm 미호출, 기록 1건, 토큰 문법) · callable core |

### fixtures (`test_fixtures/`)

`menu_visibility_contract.json`(14케이스: spec 8 + 경계 6) · `store_sellability_contract.json`(11) · **`checkout_menu_gate_contract.json`(17, spec 의 2종에 더해 추가)** — 분류 규칙(문서 존재 역추론)도 양쪽이 같아야 하는 "같은 사실에 두 구현"이라 골든으로 묶었다.

### Dart

- 판정(순수): `lib/core/utils/store_sellability.dart`, `checkout_menu_gate.dart` (`store_menu_visibility.dart` 무변경)
- 고객 결제: `domain/entities/{checkout_validation,payment_failure}.dart`, `domain/repositories/checkout_validation_repository.dart`, `domain/usecases/validate_checkout_use_case.dart`, `data/datasources/remote/checkout_validation_remote_data_source.dart`, `data/repositories/checkout_validation_repository_impl.dart`, `core/errors/verify_payment_failure.dart`, `data/datasources/remote/cloud_functions_remote_data_source.dart`(verify 경로만 code+message 보존), `presentation/customer/cart/**`, `presentation/customer/checkout/**`, `presentation/customer/home/widgets/quick_reorder_section.dart`
- 브랜드: `domain/entities/{brand_private_profile_entity,brand_key_lookup}.dart`, `BrandEntity`/`BrandModel`(brandKey·PII 5개 제거, **`brand_entity.freezed.dart` 만 재생성**), `data/models/brand_private_profile_model.dart`, `brand_remote_data_source`, `brand_repository_impl`, `lookup_brand_by_key_use_case`, `brand_info_page`(+`widgets/brand_key_row.dart`), `brand_info_form_page`, `store_core_form_page`, `admin_brand_approval_detail_page`, 시드
- 삭제: `my_store_page`(`_ClosingGuide`), `DeleteStoreUseCase` 및 `deleteStore` 데이터소스/리포지토리 삭제, `domain/repositories/store_deletion_repository.dart` 외 UseCase 2, `presentation/admin/store_management/{admin_store_list_page,admin_store_delete_page}.dart`, `admin_more_page`
- 신규 callable 래퍼: `data/datasources/remote/authority_callables_remote_data_source.dart` (아래 "차이" 참조)
- 테스트 신규 13파일 + 가드 `test/presentation/payment_authority_guard_test.dart` (spec §18.3 의 1, 2(a/b), 3, 4, 5, 6, 6-b, 7 + CartEntity 무변경 + Rules-A 키)

### 문서 갱신 (spec §19-11)

`data_ownership.md`(§2.5 create 제약 1행 + delete 교체 + 쓰기 경로 매트릭스, §2.7/2.7a, §2.13 신규 컬렉션 4개, §3 CF 카탈로그) · `entity_lifecycle.md` §3.3 낡은 "확인 필요"를 확정 사실로 교체 · `audit_trail.md`(이력 3종 + §4 체크리스트 7번) · `tester_guide.md`(상시 항목) · `backlog.md`(⬜ 4건 → ✅, F8 흡수 1행, 후속 **PSA-N1~N6**) · `role_flows.md`(§4.4 admin 1행 + brand 승인 행 + owner 안내).

## 2. 배포 순서 11단계 ↔ 산출물

| 단계 | 요구하는 산출물 | 비고 |
|---|---|---|
| ① 인덱스 | `firestore.indexes.json` **변경 없음** | 아래 §3 — 복합 인덱스 불필요 확인 |
| ② 임시 마이그레이션 CF 배포 | `migrateStoreApprovalMeta`, `migrateBrandPrivateProfile` (functions 코드) | 본 CF 와 같은 코드베이스라 **functions 를 한 번에 올리면 게이트(⑥)도 같이 켜진다.** ② 와 ⑥ 을 나누려면 `index.ts` 에서 `verifyTossPayment` 만 이전 버전을 유지한 채 먼저 배포하거나, `firebase deploy --only functions:migrateStoreApprovalMeta,functions:migrateBrandPrivateProfile` 로 함수 단위 배포한다 |
| ③ M1 실행 | `migrateStoreApprovalMeta` (dry-run → 실행) | 이상치/무효 status 가 있으면 CF 가 `failed-precondition` 으로 멈추고 목록을 돌려준다 |
| ④ **Rules-A** | 커밋 `11c90c7` 의 `firestore.rules` | **⑥ 보다 먼저.** 실패하면 ⑥ 진행 금지 (§17.1) |
| ⑤ M2 1단계 | `migrateBrandPrivateProfile {stage:'copy'}` | 부모 필드는 지우지 않는다 |
| ⑥ 본 CF 배포 | `verifyTossPayment`(G1·G2) · `lookupBrandByKey` · `issueBrandKey` · `deleteStore` | 게이트가 켜진다. ③④ 선행 필수 |
| ⑦ 앱 빌드·설치 | Dart 전부 | `build_runner`: 이번 변경은 `brand_entity.freezed.dart` 재생성만 필요(저장소에 이미 커밋됨) |
| ⑧ **Rules-B + Rules-C** | 두 커밋의 `firestore.rules` | ⑦ 직후. B 는 `private/profile` 을 요구하므로 ⑤ 가 먼저 |
| ⑨ M2 2단계 | `migrateBrandPrivateProfile {stage:'cleanup'}` | R9 이행 조건. 구 앱 부재 확인 후 |
| ⑩ 라이브 검증 | spec §17.2 (T-2) | `rules.test.mjs` 의 PSA-A/B/C 가 3-b·3-c·7·9 의 에뮬레이터 대응 |
| ⑪ 정리 커밋 | 임시 CF 2개 삭제 (`migrateStoreApprovalMeta`, `migrateBrandPrivateProfile`, `index.ts` export, `authorityCallables.test.mjs` 의 해당 테스트) | |

**Rules-B/C 가 앞서 나가면 안 되는 이유**: B 는 부모 whitelist 에서 PII 를 빼고 brand create 의 PII 키를 막으므로 구 앱의 브랜드 정보 저장이 거부된다. 반대로 Rules-A 는 구 앱과 호환된다.

## 3. 복합 인덱스 확인 (spec 순서 6-b)

- `orders where storeId == X and status in ['paid','accepted','making','ready']` (`count()`): **복합 인덱스 불필요.** 등식 1개 + `in` 1개, `orderBy` 없음 → 단일 필드 인덱스 병합(zigzag merge)으로 처리된다.
- `storeDeletionHistory where storeId == X`: 단일 필드 등식 (정렬은 클라이언트에서).
- `brandKeys/{key}` 는 문서 ID 조회라 인덱스 없음.
- 따라서 `firestore.indexes.json` 은 수정하지 않았다. 배포 ① 단계는 "변경 없음". (실제 Firestore 에서의 인덱스 요구 여부는 에뮬레이터가 검사하지 않는다 — 배포 후 `deleteStore {dryRun:true}` 를 한 번 호출하면 확정된다. 에러가 나면 콘솔이 만들 인덱스 링크를 준다.)

## 4. 테스트 포인트 (tester)

1. **정보 수정 직후 결제(최우선, R2)**: 승인 매장 전화번호 수정 → `status:'pending'`, `approvedAt` 유지 → 결제 성공. (`paymentGate.test.mjs` "pending + approvedAt" 가 코드 수준 대응)
2. 거절 경로에서 Toss confirm 미호출 (`paymentGate.test.mjs` — spy), 거절마다 `paymentGateRejections` 1건, 기록 쓰기 실패해도 거절 결과 유지.
3. override `pending`+`soldOut` → 거절 / `pending`+`excluded` → 통과 / `approved`+`excluded` → `MENU_EXCLUDED`.
4. 품절 거절 화면에 **카트의 메뉴명**이 전부 열거되고 옵션 2줄이어도 1회, 미해석 id 비출력. 토큰 없는 실패(네트워크 끊김)와 `READ_FAILED`(unavailable) 의 갈래 구분 — `READ_FAILED` 는 갈래 B 여야 한다 (verify 경로가 code+message 를 보존하도록 바꾼 부분).
5. 선검증 네트워크 차단 → Toss 창까지 진행, 통과를 암시하는 요소 없음. 빠른 재주문 전부 위반 시 기존 카트 유지.
6. brandKey 행 S3(읽기 실패)에 "관리자 승인 후" 문구가 없음, 재시도 시 스켈레톤.
7. 점주 `my_store_page` 개인/가맹 모두 삭제 버튼 없음, "임시 휴업" 문구 없음.
8. admin 삭제: 진행 중 주문 n≥1 비활성, 중간 실패 후 재실행 시 이력 1건(`deleteStore` core 테스트가 코드 수준 대응), 같은 ID 재생성 후 재삭제 시 이력 2건.
9. 권한 판정 필드 create·update 교차: `PSA-A1~A3` 거부, `A4/A5/A5b` 허용(회귀), `B4d`(private create 에 brandKey) 거부.
10. **PII 선택 필드(본사 주소·대표자)를 비워 저장 시 실제 삭제되는가** — 클라이언트가 `FieldValue.delete()` 를 쓴다. 에뮬레이터에서 `PSA-B5b` 로 Rules 는 통과함을 확인했으나 앱 경로 E2E 는 미실행.
11. 라이브(T-2): 설계 Q1 `요금도 청구되지 않았어요` 사실 확인, 카드·카카오페이 각각.

## 5. 미구현 / 보류

- 에뮬레이터 E2E (`npm run test:emulator`, `test_rules` `test:flow`)와 실기기/라이브 검증은 하지 않았다. `flow.test.mjs` 가 부모에 PII/brandKey 를 쓰는 admin 승인 단계를 포함하는지는 재확인이 필요하다(admin 전권 분기는 막지 않으므로 통과할 것으로 보나 미실행).
- `issueBrandKey` 의 **재발급(reissue)** 은 만들지 않았다 (UI 없음). 이력 구조(`previousKey`)만 열어 두었다.
- `deleteStore` 의 Storage 정리는 **매장 문서의 `imageUrl`/`imageUrls` 만** 대상이다. 하위 메뉴 문서의 이미지(`menu_images/...`)는 지우지 않는다(하위 문서를 지우기 전에 URL 을 수집해 이력에 넣는 단계가 필요 — spec 은 "images" 를 매장 이미지로만 정의).
- 서버 거절 `details`({reason, menuItemIds}) 폴백은 쓰지 않는다 — 지시대로 message 토큰만 1차 근거. `VerifyPaymentFailure` 에 details 를 추가하면 확장 가능.
- 설계 Q1 문구 사실 확인(T-2), 후속 PSA-N1~N6.

## 6. 작업표와 현실의 차이 (문서는 고치지 않았다 — 판단 요청)

1. **spec §13 "functions_remote_data_source" 는 실제로 `cloud_functions_remote_data_source.dart` 다.** 두 에이전트가 동시에 같은 파일을 고치지 않도록 새 callable 3종(`lookupBrandByKey`/`issueBrandKey`/`deleteStore`)은 신규 `authority_callables_remote_data_source.dart` 에 두었다. 합치려면 이동만 하면 된다.
2. **spec §10.4 표에 빠진 표면 2곳**: `admin_brand_approval_detail_page`(PII 를 부모에서 읽음)와 `brand_info_form_page`(수정 시 초기값을 부모에서 읽음). 둘 다 `private/profile` 로 옮겼다. 부모 PII 제거(⑨) 후 이 두 곳이 안 옮겨져 있으면 admin 승인 화면이 빈다.
3. **`LookupBrandByKeyUseCase` 시그니처**: spec §13 은 "유지" 라 했으나 `BrandEntity?` 한 값으로는 미매칭/실패/rate limit 을 구분할 수 없어(design §5.4 가 세 문구를 요구) `BrandKeyLookup` + `BrandKeyLookupException(kind)` 로 바꿨다. `BrandKeyCollisionException` 은 서버로 이동해 삭제, 승인 실패는 `BrandKeyIssueException`.
4. **`migrateQoinZeroRates` 패턴은 코드에 없다** (런북 ⑧ 정리로 이미 삭제됨). 같은 계약(dry-run 기본, 멈추고 보고)으로 새로 작성했다.
5. **ID 충돌**: spec 후속 과제 N1~N6 는 `backlog.md` 에 이미 존재하는 N1(알림 flow 테스트)과 겹쳐 **`PSA-N1~N6`** 으로 등재했다.
6. **design §3.3 vs spec §18.3 6-c ⓒ 충돌**: design 은 갈래 C 보조 본문에 "요금이 청구됐는데 주문이 없으면…" 을 쓰지만 가드는 갈래 C 에 `요금`/`청구` 단어 0건을 요구한다. 가드를 따라 "결제는 됐는데 주문이 없으면 관리자에게 문의해 주세요" 로 바꿨다 (코드 주석에 근거). **설계자 판단 필요.**
7. **`checkout_page` 바깥 catch(`launchPayment` 예외)** 는 갈래 C 가 아니라 `PaymentFailure.launch()`(갈래 A 기본 문구)로 보낸다 — Toss confirm 은 서버(verify)에서만 일어나므로 이 지점에서는 돈이 움직이지 않았다. 안쪽 verify catch 는 `PaymentFailure.from(e)`. 원치 않으면 한 줄 변경.
8. **게이트 판정에서 spec 이 정하지 않은 지점 (spec §8 fail 방향을 따라 "막지 않는" 쪽 선택)**:
   - 마스터 메뉴 자체의 `visible=false`/`status!=approved` 는 **검사하지 않는다** (spec §7.2 ③ 는 `applyOverrideForCustomer` 결과만 본다. 고객 목록은 그 마스터를 숨기지만, 이미 카트에 담긴 것을 막는 근거는 spec 에 없다).
   - 점포 한정 메뉴의 `status`(pending 등)도 검사하지 않고 `visible`/`soldOut` 만 본다.
   - 한 카트에 사유가 섞이면 토큰은 한 사유만 싣는다(우선순위 SOLD_OUT > EXCLUDED > NOT_FOUND). 기록(`paymentGateRejections.detail`)에는 위반 전부가 남는다. 고객은 빼고 다시 결제하면 다음 사유를 만난다.
   - override 의 `status` 가 알 수 없는 문자열이면 Dart `EntityApprovalStatus.fromString` 과 같이 `approved` 로 해석한다(골든 12번). 서버가 혼자 엄격해지면 고객이 본 화면과 갈라지기 때문. 단 **매장 status 는 반대로 fail-closed**(spec §8.1).
   - 경로를 오염시킬 수 있는 `menuItemId`(`/` 포함 등)는 읽지 않고 `MENU_NOT_FOUND`, 토큰에는 싣지 않는다.
9. **Rules 하네스 기존 케이스 갱신**: F4a/F4b/F4c 는 "점주 삭제 → 같은 ID 재생성(수용된 경로 #13)"을 고정하던 테스트라 점주 삭제 단계를 `deny` 로 바꾸고 이후 단계는 Admin SDK 삭제로 준비하게 했다(재생성 이후의 create 제약 검증은 유지).
10. **spec 에 없는 신규 컬렉션**: `brandKeyLookupLimits/{uid}`(rate limit), `migrationHistory/{autoId}`. Rules 가 없어 클라이언트 접근은 기본 거부이며 `data_ownership.md` §2.13 에 등재했다.
11. **시드(dev)**: Rules-B 하에서 클라이언트는 `private/profile.brandKey` 와 `brandKeys/*` 를 쓸 수 없다. 시드는 부모 + PII(`private/profile`)를 심고, 키 쪽은 별도 단계(Rules 우회 환경에서만 성공, 실패 시 로그)로 분리했다. 실서버 개발 데이터는 `issueBrandKey` 로 발급해야 한다.
12. **M2 과도기 한계**: ⑥~⑨ 사이에 `issueBrandKey` 로 새로 승인된 브랜드는 부모에 `brandKey` 복사본이 없다(R8 때문에 의도). 이 구간에 아직 구 앱을 쓰는 점주는 그 브랜드의 키 조회에 실패한다. 구간을 짧게 가져가거나 ⑥ 직전에 승인 대기 브랜드가 없음을 확인한다.
13. **타임아웃**: 클라이언트 `deleteStore` 호출은 120초, CF 는 300초다. 클라이언트가 먼저 포기해도 CF 는 계속 진행하고 재실행이 멱등이다(design §7.2 실패 문구와 일치).
14. **Riverpod 자동 재시도 해제**: 새 읽기 provider 4개(private profile ×2, 삭제 preview, admin 매장 목록)는 기본 자동 재시도(약 38초)를 꺼서 "읽기 실패" 를 바로 보인다(기존 `readNoAutoRetry` 패턴).
15. **`payment_method_tile.dart:140` 의 기존 `Colors.black87`** 은 범위 밖이라 건드리지 않았다.

## 7. 코드 생성

필요함 — `dart run build_runner build --delete-conflicting-outputs`. 변경된 생성 파일은 `brand_entity.freezed.dart` 하나(이미 반영됨). 새 코드는 freezed 를 쓰지 않았다.
