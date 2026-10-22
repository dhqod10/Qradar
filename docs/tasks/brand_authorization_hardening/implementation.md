# 브랜드 권한 경계 교정 구현 내역

기준: `spec.md` (D1·D2·D5 확정), `design.md` (§2 매장 승인 · §3 연결 복구 · §4 점검 카드), Qoin `spec.md` §21.6 (배포 순서). 배포는 Qoin 개정 3 과 **같은 창**이다 — 배포하지 않았다. 운영 Firestore 는 읽지도 쓰지도 않았다.

## 1. 구현 완료 항목

| 결정 | 구현 |
|---|---|
| **D2** `isBrandHolder` 공백 매칭 | `brandId is string && brandId != ''` 를 더했다. 호출 12곳에 한 번에 걸리고 `get()` 추가 0. 엄격화 전용 — 정상 흐름 11개 호출 지점이 전부 그대로 참임을 하네스가 고정 (`RM-D2`) |
| **D1** `users.brandId` CF 소유 | self 화이트리스트에서 `brandId` 제거 + "최초 1회" 블록 삭제. 신규 callable `claimSubmittedBrand({brandId})` (`submittedBy == uid` 검증 → `users.brandId` + `users/{uid}/roleHistory` 1건 **같은 트랜잭션**, 멱등, 기존 다른 값은 `failed-precondition`). `users/{uid}/roleHistory` Rules 블록(read 본인·admin, 쓰기 전면 차단) |
| D1-2 | `BrandRepositoryImpl.upsertBrand` 신규 분기: batch 제거 → 브랜드 문서 1건 → `claimSubmittedBrand` (실패해도 던지지 않는다 — 문서가 이미 있어 재등록을 부르지 않게) |
| D1-2 복구 | **`BrandIdMissingView` 신규 작성** (아래 3). `brands where submittedBy == uid` → 0건 폼 / 1건 자동 claim / 2건+ 가장 이른 제출 + SnackBar |
| **D5** | `stores` create: `brandId` 가 있으면 존재하는 `approved` 브랜드. 승인 화면: `BrandScopeBadge` 의 `'브랜드'` 폴백 삭제, `resolveStoreBrandLink` 단일 분류 함수를 배지·상세·승인 버튼이 공유, 실패 3상태 구분 + 승인 버튼 fail-closed, 상속 적립률 문장(블록과 확인 다이얼로그가 글자 그대로 공유), 확인 문장 |
| §4.1 | 임시 callable `auditBrandLinks` (**쓰기 0, 요청 인자 없음, 자동 교정 없음**) + 허브 임시 카드 `AdminBrandLinkAuditCard` |

## 2. 변경 파일

| 영역 | 파일 |
|---|---|
| Rules | `firestore.rules` — `isBrandHolder` · `isSelfProfileUpdate`(brandId 제거) · `roleHistory` · `stores` create(D5) |
| CF | `functions/src/claimSubmittedBrand.ts`(신규) · `auditBrandLinks.ts`(신규, `TRANSITIONAL(brand_authorization_hardening §4)`) · `index.ts` |
| Data | `brand_remote_data_source.dart`(`fetchBySubmitter`, `claimSubmittedBrand` + 실패 분류) · `brand_repository_impl.dart` · `brand_link_audit_*` (임시) |
| Domain | `store_brand_link.dart`(`resolveStoreBrandLink`, `resolveInheritedRate`) · `brand_link_audit_result.dart`(임시) · use case 3종 · `BrandRepository` 2메서드 |
| Presentation | `brand_scaffold.dart` · `brand_id_missing_view.dart`(신규) · `brand_link_gate_provider.dart`(신규) · `brand_info_form_page.dart`(저장 직후 게이트 재평가) · `brand_scope_badge.dart` · `store_scope_badge.dart` · `store_brand_block.dart`(신규) · `store_approve_confirm_dialog.dart`(신규) · `approval_actions_bar.dart` · `admin_store_approval_detail_page.dart` · `admin_brand_link_audit_card.dart`(임시) · 허브 마운트 한 줄 |
| 테스트 | `test_rules/rules.test.mjs`(RM 스위트 · EC) · `test_rules/flow.test.mjs`(신규 통합) · `functions/test/emulator.test.mjs`(CF1~CF8) · Dart 위젯/데이터 테스트 5개 |
| 문서 | `docs/processes/role_flows.md` (brand 전환 흐름의 brandId 발급 주체) · `test_rules/README.md` |

## 3. 작업표와 현실이 다른 곳

1. **`_BrandIdMissingView` 는 수정이 아니라 신규 작성이다** — sub-phase 6(V8)에서 폐기되어 `BrandScaffold` 가 `brandId` 가 비면 곧바로 `BrandInfoFormPage` 로 보냈다. 폼이 조회보다 먼저 그려지면 claim 실패 → 재등록 → 고아 브랜드가 쌓인다. 게이트를 되살려 **조회 전·조회 실패·연결 실패에서 폼을 그리지 않는다.** 이름은 private 이 아니라 `BrandIdMissingView`(위젯 테스트 접근용).
2. **등록 폼이 저장한 뒤 게이트를 다시 평가시켜야 한다.** 폼이 `BrandScaffold` 안에 계속 남아 있으면 claim 이 실패했을 때 사용자가 다시 저장해 중복 등록한다 → 신규 모드 저장 성공 직후 `ref.invalidate(brandLinkGateProvider)` (폼이 내려가고 방금 만든 브랜드를 조회해 연결). 작업표에 없던 연결.
3. **`orphan_brand` 정의**: spec 은 "`submittedBy == null OR status == 'approved'` 중 아무 users 도 가리키지 않는 문서" 인데 §4.2 조치표는 "`pending` 이고 아무도 가리키지 않으면 삭제" 다. 두 문장이 어긋나 **전수 스캔 후 `users.brandId` 로 가리켜지지 않는 모든 브랜드**로 보고하고 status 를 항목에 실었다 (보고만 하므로 과보고가 안전 측).
4. `duplicate` 인 계정은 `ok` 집계에서 뺐다 (한 계정이 두 분류에 이중으로 세어지지 않게). `dangling`/`mismatch` 와의 겹침은 허용 — 각각 별도 조치가 필요한 사실이다.
5. 매장 승인 목록의 `'브랜드'` 폴백만 지웠다. 메뉴 승인 큐(`admin_approval_queue_page.dart` 의 브랜드 묶음 타일)에도 같은 문자열 폴백이 있으나 다른 표면(브랜드별 대기 메뉴 수)이라 건드리지 않았다.

## 4. 점주→브랜드 전환이 깨지지 않는다는 근거

세 겹으로 확인했다 (추론 아님).

1. **Rules + CF 를 한 세션에서 이어서 돈 통합 테스트** — `test_rules/flow.test.mjs` (`npm run test:flow`, 27/27 PASS). 점주 출신·고객 출신 각각: ① `role` 전이 ② 전환 직후 권한 0 ③ **구 방식 batch(브랜드 + users.brandId)는 신 Rules 에서 전체 거부되고 고아 브랜드 문서도 생기지 않음**(③→④ 순서가 필수인 이유) ④ 신 방식 브랜드 문서 1건 create 통과 ⑤ `brands where submittedBy == uid` 조회 가능(게이트의 조회) ⑥ `claimSubmittedBrand` → `users.brandId` + `roleHistory` 1건, 재호출 멱등 ⑦ 연결 후 내 브랜드 권한 정상·남의 브랜드는 여전히 거부 ⑧ admin 승인 ⑨ 점주가 그 brandId 로 매장 등록(D5 통과) ⑩ 핵심 필드 수정 → pending 회귀 ⑪ 반려 후 재제출 ⑫ 자기 `brandId` 임의 변경 거부.
2. **게이트 위젯 테스트** (`brand_link_gate_test`): 0건 폼 / 조회 중·실패에서 폼 금지 / 1건 자동 claim 정확히 1회 / 2건+ 가장 이른 + SnackBar / 연결 실패에서 새로 등록 버튼 없음·자동 재호출 없음 / 폼 저장 직후 게이트 재평가로 폼이 내려감.
3. **쓰기 맵 골든** (`brand_repository_link_test`): 신규 분기는 `set` + `claim` 만 부르고 `users` 를 쓰는 경로가 데이터소스에 없다. claim 이 실패해도 `upsertBrand` 는 던지지 않고, 브랜드 문서 쓰기가 실패하면 claim 을 부르지 않는다.

spec D1-2 의 9단계 중 1·2·5~9 단계는 코드 변경이 없고, 3(batch 제거)·4(claim) 만 바뀐다 — 위 통합 테스트가 1~9 를 전부 지난다.

## 5. 테스트 결과 (전부 직접 실행)

| 스위트 | 결과 |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 447 / 447 PASS |
| `functions` tsc + `npm test` + `npm run test:emulator` | 오류 0 / 86 / 97 PASS |
| Rules 하네스 | **332 / 332 PASS** (개정 2 의 261 + 신규 71: RM01~RM20 및 변형 42, `RM-D2` 11, FLOW 3, RHIST 8, EC 7) |
| 통합 `test:flow` | 27 / 27 PASS |

### 회귀 핀이 실제로 핀 역할을 하는가

- **RM07 을 D2 없이 돌렸다** (`RULES_FILE=<D2 를 뺀 rules>`): `RM07`(brandId 필드 없는 매장 menuOverrides)이 **ALLOW 가 나와 FAIL** — 함께 `RM07b` 4종(menuItems·subCategories·optionGroups·qoinRateHistory)·`RM09`·`RM09c`·`RM10`·`RM10b` 도 FAIL (9건, 323/332). D2 를 넣으면 332/332.
- **직전 Rules(`fa41917`)에 신 하네스를 돌렸다**: 26건 FAIL (RM02·RM02b·RM02c·RM03·RM07·RM09·RM10·RM16·RM17·FLOW-3·RHIST·EC1/3/4 …) — 하네스가 구멍을 잡는다.
- **RM18 은 ALLOW 로 고정**했다 (approved 남의 브랜드 지정). "Rules 가 막지 않는다" 를 명시.
- RM02/RM03 은 DENY 를 확인한 뒤 **Admin SDK 로 변조 상태를 강제 주입하고 하위 권한을 다시 때린다** (`RM02-inj`: users.brandId 가 주입됐다면 그 브랜드 쓰기가 열린다 — 쓰기 차단이 유일한 방어선임을 문서화하는 ALLOW 케이스, `RM03-inj`: `role:brand` 만 주입된 상태는 DENY). 모든 RM 케이스는 `users/{uid}` 를 케이스 안에서 쓴다 (고정 시드 재사용 0).

## 6. 읽기·라운드트립 비용

- 적립 1건당 read·라운드트립 증가 **0** — 적립/결제 경로 파일 무변경, CH16 실측 동일 (earn 브랜드 5 read / 왕복 4).
- Rules: `isBrandHolder` 의 `get()` 추가 0. `stores` create 에만 브랜드 `get()` 1회 추가(브랜드 지정 시). `users` update 의 `get()` 추가 0.

## 7. 정리 커밋 (보안 task §8-A2)

삭제 대상은 모두 `TRANSITIONAL(brand_authorization_hardening §4)` 로 grep 가능하다: `functions/src/auditBrandLinks.ts` · `index.ts` export 한 줄 · `admin_brand_link_audit_card.dart` · 허브 마운트 한 줄 · `audit_brand_links_use_case` / `brand_link_audit_*` (domain·data) · `brand_link_audit_card_test.dart` · 이 파일의 `emulator.test.mjs` CF7/CF8. 가드 테스트의 허용 목록에서도 해당 파일을 지운다.

## 8. 미구현 · 보류 · 설계 보고

- 미구현: **없음** (spec/design 의 developer 항목 전부). 문서 쪽 보류는 Qoin `implementation.md` C9 참조.
- 설계 문제로 보이는 것: Qoin `implementation.md` C9 의 4건 + 아래.
  1. 게이트 실패 화면(`연결 실패`)에서 사용자가 할 수 있는 일은 `다시 연결` 과 `로그아웃` 뿐이다. `alreadyLinked`/`notSubmitter` 는 재시도도 없다 — D4 가 의도한 거동이지만 사용자는 문의 외 탈출구가 없다.
  2. 2건 이상일 때 자동 선택이 의도와 다를 수 있고 사용자가 되돌릴 수 없다 (design T2 와 동일, 정책 변경 없음).
  3. `firestore.rules` 의 `brands` read 가 `isSignedIn()` 전체 공개라 `brandKey` 가 열쇠로 기능하지 않는다 — 이미 backlog B4. D5 의 Rules 검증이 "존재하는 approved 브랜드" 까지인 이유다.
