# Qoin 적립률 계층화 구현 내역

기준: `spec.md` (§17 전건 확정), `design.md` (+ **맨 끝 "잔여 결정 확정 (2026-10-22)" 우선**), `docs/tasks/qoin/{implementation,test_report}.md` (1차 F1~F3), `docs/processes/audit_trail.md` §4.

실결제 0회. 배포는 하지 않았다 (사용자 배포 명령은 아래 §배포).

---

## 1. 구현 완료 항목

| 영역 | 내용 |
|---|---|
| 해석 | 매장 → 브랜드 → 전역. **무효 값은 상위로 폴백하지 않고 멈춘다.** 필드 부재 = 상속 / `0` = 명시적 적립 중단. CF(TS)·클라이언트(Dart) 각 1곳 |
| CF | `onOrderQoinSettled` 교체 (계층 읽기는 earn 분기 안 `getAll` 1 라운드트립), `setQoinAccrualRate`, `applyBrandQoinRate`, `onQoinConfigWritten` 신규 |
| 원장 | `accrualRateSource` (`'store'｜'brand'｜'global'`) 추가 — **배포 전이라 과거 원장 소급 문제 없음.** clawback 은 earn 문서에서 상속 |
| Rules | 적립률 쓰기 경로 12개 전수 차단 (admin 전권 분기 · create 포함), 이력 서브컬렉션 3종 + collection-group 블록 |
| Dart | 4값(`QoinRateSetting`) · 해석(`resolveEffectiveQoinRate`) · 엔티티/모델/Repository/UseCase/DataSource · provider 공용 위치로 이동 |
| 화면 | 관리자 7화면(허브·전역·브랜드 목록/편집·매장 목록/편집·이력), 점주·브랜드 읽기 행 3곳 + 이력 화면, 고객 plate 숫자 제거 |
| 이력(H7) | 값과 이력을 **같은 트랜잭션**에 기록. 일괄 적용은 1건 + 서버가 센 영향 수·덮어쓰기 여부 |
| 테스트 | Rules 하네스 163건, CF 에뮬레이터 42건(저장소에 커밋 가능한 스크립트), TS 단위 50건, Dart 260건 |

---

## 2. 변경 파일

### 인프라 (배포 필요)

| 파일 | 변경 |
|---|---|
| `firestore.rules` | **수정**: `touchesQoinRate()` / `hasQoinRateOnCreate()` 헬퍼 추가. `stores` update(`!touchesQoinRate()` 를 **최상위 조건**으로 — admin 전권 포함 3분기 모두) · create, `brands` update · create(admin 포함), `config/{docId}` (create: `accrualRate` 금지 / update: `accrualRate` 변경 금지, `enabled` 허용 / **delete 금지**). **신규**: `config/qoin/qoinRateHistory`, `brands/{id}/qoinRateHistory`, `stores/{id}/qoinRateHistory`, `{path=**}/qoinRateHistory`(collection group, admin read 만). 이력 쓰기는 전부 `if false` (admin 도 불가) |
| `firestore.indexes.json` | `qoinRateHistory.changedAt` fieldOverride (COLLECTION + **COLLECTION_GROUP** ASC/DESC) 추가 — §6 인덱스 실측 참조 |
| `firebase.json` | `emulators.functions` (포트 5137) 추가 |
| `functions/src/qoinRate.ts` | **신규.** TS 경계 상수의 유일한 출처 (`MIN_RATE`/`MAX_RATE`/`BULK_STALE_MS`), `classifyRate`, `resolveEffectiveRate`, `isValidCallableRate`, `computeEarnAmount` — 순수 함수 |
| `functions/src/qoinAdmin.ts` | **신규.** admin 서버 재검증(`users/{uid}.role === 'admin'`), `parseReason`, 이력 컬렉션 헬퍼 |
| `functions/src/onOrderQoinSettled.ts` | `loadConfig` → kill switch 판정만 (적립률 검증 분리), earn 분기에서 계층 해석, `accrualRateSource` 기록, `skipped_rate_zero` / `skipped_invalid_store` / `skipped_invalid_rate: invalid_{store｜brand｜global}` 로그. `MIN_RATE`/`MAX_RATE` 로컬 선언 삭제 |
| `functions/src/setQoinAccrualRate.ts` | **신규** onCall |
| `functions/src/applyBrandQoinRate.ts` | **신규** onCall (timeout 540s) |
| `functions/src/onQoinConfigWritten.ts` | **신규** onDocumentWritten `config/{docId}` (docId=`qoin` 만 처리) |
| `functions/src/index.ts` | export 3줄 |
| `functions/package.json` | `test`, `test:emulator` 스크립트 |
| `functions/test/qoinRate.test.mjs` | **신규** TS 단위 (50건) |
| `functions/test/emulator.test.mjs` | **신규** CF 에뮬레이터 (42건) — 저장소에 둔다 (1차 test_report ⑧ 해소) |
| `test_fixtures/qoin_rate_truth_table.json` | **신규** Dart·TS 가 같이 읽는 진리표 (resolve 20행 / classify 14 / callable 13) |
| `test_rules/rules.test.mjs` | 기존 73건 유지(2건 의미 변경, §5) + RH 90건 신규 |

### Core / Domain / Data

| 레이어 | 파일 |
|---|---|
| core | `utils/qoin_policy.dart` (확장: `isValidRate`, `isValidCallableRate`, `explicitOffRate`, `bulkStaleAfter`, `historyPageSize`, `reasonMaxLength`), **신규** `utils/qoin_rate_resolver.dart` (`QoinRateSetting` 4값, `QoinRateSource`, `EffectiveQoinRate`, `resolveEffectiveQoinRate`), **신규** `errors/qoin_rate_exception.dart`, `constants/firestore_paths.dart` (이력 경로/필드 키) |
| domain | **신규** `qoin_rate_scope.dart`, `qoin_rate_change_entity.dart`(+freezed), `qoin_rate_results.dart`, `repositories/qoin_rate_repository.dart`, UseCase 4 (`set_qoin_accrual_rate`, `apply_brand_qoin_rate`, `watch_qoin_rate_history`, `watch_all_qoin_rate_history`). **수정** `StoreEntity`/`BrandEntity` (`qoinAccrualRate`), `QoinConfigEntity` (`accrualRateSetting`), `QoinConfigAdminRepository` (`saveAccrualRate` 제거). **삭제** `save_qoin_accrual_rate_use_case.dart` |
| data | **신규** `qoin_rate_remote_data_source.dart` (callable 2 + 이력 쿼리 — 적립률 관련 Firebase 직접 사용의 전부), `qoin_rate_change_model.dart`, `qoin_rate_repository_impl.dart`. **수정** `StoreModel`/`BrandModel` (읽기 추가, **쓰기 맵에는 넣지 않음**), `QoinConfigModel` (경계를 `QoinPolicy` 로 — 아래 ② 참조), `qoin_remote_data_source.dart`/`qoin_repository_impl.dart` (`saveAccrualRate` 삭제) |

### Presentation

| 위치 | 파일 |
|---|---|
| `common/providers/` | `qoin_di_providers.dart` (customer 에서 **이동**, 적립률 DI 추가), `qoin_config_providers.dart` (`qoinConfigProvider` 이동), `qoin_rate_providers.dart` (이력 · 유효 적립률 · 변경자 이름) |
| `common/widgets/qoin/` | `qoin_rate_labels.dart` (`QoinRateLabels`/`QoinRateBadgeKind`/`QoinRateValueLabel`/`QoinScopeLabel`/`QoinScopeIcons`), `qoin_rate_source_badge.dart` (+`QoinRateValueText`), `qoin_rate_info_row.dart` (block/summary/tile + 래퍼 2), `qoin_rate_history_tile.dart`, `qoin_rate_history_list.dart`, `qoin_rate_history_page.dart` (+`QoinHistoryFooter`), `qoin_partial_banner.dart`, `qoin_load_error.dart` |
| `admin/qoin/widgets/` | `qoin_rate_input_field`, `qoin_rate_preview`, `qoin_dialog_shell`, `qoin_kill_switch_card`, `qoin_current_rate_card`, `qoin_scope_band`, `qoin_rate_chain`, `qoin_rate_confirm_dialog`, `qoin_rate_edit_form`, `qoin_bulk_resume`, `qoin_filter_chip`, `qoin_admin_ui` |
| `admin/qoin/` | `admin_qoin_settings_page` (**허브로 교체**), `admin_qoin_global_rate_page`, `admin_qoin_brand_rates_page`, `admin_qoin_brand_rate_edit_page`, `admin_qoin_store_rates_page`, `admin_qoin_store_rate_edit_page`, `admin_qoin_rate_history_page`, `providers/qoin_admin_providers.dart` |
| 수정 | `admin/more/admin_more_page.dart` (부제 `전역 기본값 3% · 적립 중`), `owner/my_store/my_store_page.dart` (`_StoreInfoSection` 에 읽기 행), `brand/brand_info/brand_info_page.dart` (승인된 브랜드에 카드 1개), `brand/stores/brand_stores_page.dart` (타일에 행 1개), `customer/qoin/widgets/qoin_balance_card.dart` (문구 교체, `비율 모름` 분기 삭제), `customer/qoin/providers/qoin_providers.dart` (config provider 이동) |

1차 `admin_qoin_settings_page.dart` 는 design §13 추출 표대로 **분해 후 재사용**했다: `_LoadError`→`QoinLoadError`, `_RateField`→`QoinRateInputField`(동작 그대로), `_RatePreview`→`QoinRatePreview`, `_dialog`→`QoinDialogShell`, `_CurrentConfigCard`→`QoinCurrentRateCard`, `_EnabledSwitchCard`+켜기/끄기 다이얼로그→`QoinKillSwitchCard`(문구 변경 없음, 캡션만 추가), `_RateChangeDialog`→`QoinRateConfirmDialog`(확장).

---

## 3. 데이터 모델 · 계약

```
config/qoin                 accrualRate(전역, 0 불가) / enabled
brands/{id}.qoinAccrualRate 부재=전역 상속 / 0=적립 안 함 / 0.001~0.2
stores/{id}.qoinAccrualRate 부재=상위 상속 / 0=적립 안 함 / 0.001~0.2

{config/qoin | brands/{id} | stores/{id}}/qoinRateHistory/{autoId}
  scope targetId targetName(D9 박제) field(accrualRate|enabled) before after
  changedBy changedByRole changedAt reason source(callable|bulk|direct) op(set|clear|bulkApply)
  [bulkApply] bulkMode status(in_progress|completed|partial)
              affectedCount clearedCount preservedCount processedCount totalCount lastProgressAt

users/{uid}/qoinTransactions/{txId}  + accrualRateSource('store'|'brand'|'global'; 과거 원장/옛 earn 상속분은 null)
```

- `setQoinAccrualRate({scope, targetId?, rate | clear:true, reason?})` → `{before, after, historyId, changed}`. rate/clear 정확히 하나, 전역은 `0`·`clear` 불가. **같은 값이면 아무것도 쓰지 않는다** (결과 불명 후 재시도해도 중복 이력 없음).
- `applyBrandQoinRate({brandId, rate | clear:true, mode, reason?, resumeHistoryId?})`. preserve 는 1 트랜잭션에서 값 + `completed` 이력까지 한 번에 쓴다. overwrite 는 **이력 선기록(in_progress) + 브랜드 값 1 write = 한 트랜잭션 → 개별 설정 ≤450건 청크 삭제 → 마감**. 실패 시 `partial` + `HttpsError('internal')`. 진행 중(최근 5분 이내 갱신) 이력이 있으면 새 시작 거부(`failed-precondition`). `isStale` 5분은 `BULK_STALE_MS` / `QoinPolicy.bulkStaleAfter` 각 1곳.
- 일괄 적용 수치 의미 (design 잔여 결정 7): `affectedCount` = 새 값을 따르게 된 매장 수 (preserve: N−M, overwrite: N), `clearedCount` = 지운 개별 설정 수, `preservedCount` = 유지된 개별 설정 수, `totalCount` = 시작 시 개별 설정 매장 수(partial 배너의 "T곳 중 P곳"). 단일 브랜드 값 쓰기도 `op: bulkApply` 로 남긴다.
- `onQoinConfigWritten`: `accrualRate`/`enabled` 변경 필드마다 1건. callable 이 방금 남긴 이력(`source:callable`, after 일치, 이벤트 시각 ±2분)이 있으면 skip, 아니면 `source:direct`, `changedBy:null`. 문서 ID `direct_{eventId}_{field}` 로 이벤트 재전달 중복 방지. 문서 삭제도 기록한다.

---

## 4. 1차 결함 재발 방지 — 어떻게 막았나

### ① F1 — 쓰기 경로 전수 (spec §9 의 12경로)

| 경로 | 차단 위치 | 하네스 |
|---|---|---|
| P1 customer/owner/brand `stores` update | `allow update: if !touchesQoinRate() && (…)` | RH1, RH1b, RH1c, RH1d, RH2 |
| P2 owner `stores` create | `&& !hasQoinRateOnCreate()` | RH4 (+RH4b 회귀) |
| P3 brand `stores` create | 같음 (+ owner 전용 규칙) | RH4c, RH4d(admin) |
| P4 brand/admin `brands` update·create | `!touchesQoinRate()` / `!hasQoinRateOnCreate()` | RH6b, RH6c, RH7, RH7b (+RH7c/7d/8/8b 회귀) |
| **P5 admin 전권 분기** `stores`/`brands` update | 최상위 조건이라 **전권도 예외 없음** | RH3, RH3b, RH3c, RH6 |
| **P6 admin `config` update·delete** | `accrualRate` 변경 금지, delete 금지 | RH9, RH9b, RH9c, RH9d, RH11c (+RH10 enabled 허용) |
| **P7 admin `config` create** | `accrualRate` 포함 금지 | RH11 (+RH11b 회귀) |
| P8/P9 callable 2종 | admin 서버 재검증 + 경계 검증 + 이력 동일 트랜잭션 | CF 에뮬레이터 CH19~CH24 |
| P10 `onOrderQoinSettled` | 읽기만 | 코드 |
| P11 Console / Admin SDK | Rules 로 막을 수 없음 — `config/qoin` 은 트리거가 `direct` 로 기록, `stores`/`brands` 는 **감시 없음(N6, 2차)** | CH26 |
| P12 `qoinRateHistory` 직접 쓰기 | 전부 `if false` | RH13~15 (3범위 × 4역할 × create/update/delete = 36건) |

**변이 검증**: 보호 조건을 일부러 제거하고 하네스를 돌려 해당 케이스가 FAIL 하는 것을 확인했다 (stores update 보호 제거 → RH3/3b/3c FAIL, create 보호 제거 → RH4/7/7b/11 FAIL, brands/config update·delete 보호 제거 → RH6/6b/6c/9/9b/9c/9d/11c FAIL). 복원 후 163/163.

### ② F3 — 경계는 양쪽에, 상수는 각 1곳

- Dart: `QoinPolicy.minTenths/maxTenths` 1곳. TS: `functions/src/qoinRate.ts` `MIN_RATE/MAX_RATE` 1곳. `onOrderQoinSettled` 의 로컬 선언 삭제.
- **같은 진리표** `test_fixtures/qoin_rate_truth_table.json` 을 `test/domain/qoin_rate_resolution_test.dart` 와 `functions/test/qoinRate.test.mjs` 가 읽는다. CF 에뮬레이터 스크립트도 같은 JSON 으로 resolve 20행을 **end-to-end**(실제 트리거)로 돌린다.
- **Dart 쪽 F3 도 발견·수정**: 1차 `QoinConfigModel` 이 전역 적립률을 `0..1` 로 검증하고 있었다 (CF 는 0.001~0.2). 지금은 `QoinRateSetting.fromRaw` → `QoinPolicy` 경계 (전역은 0 도 무효). 회귀 테스트 `qoin_rate_models_test.dart`.
- 자동 가드: Dart `qoin_architecture_guard_test.dart` (`minTenths` 선언 1곳), TS `qoinRate.test.mjs` (`MIN_RATE=` 선언 1곳 + 다른 파일에 `0.001`/`0.2` 리터럴 0건).

### ③ F2 교훈 — `accrualRateSource`

배포 전에 원장에 넣었다 (earn: 해석 결과, clawback: earn 상속). CH18 에서 실측.

---

## 5. 검증 결과 (전부 직접 실행)

| 항목 | 결과 |
|---|---|
| `flutter analyze` | **No issues found** |
| `flutter test` | **260건 전건 PASS** (1차 129 → +131: 해석 진리표 · UseCase · 모델 · 폼 위젯 19 · 읽기 행 11 · 관리자 화면 스모크 13 · 구조 가드 8) |
| `functions` `npm run build` (tsc) | 통과 |
| `functions` `npm test` | 50/50 PASS |
| **Rules 하네스** (`cd test_rules && npm test`) | **163/163 PASS** = 기존 73 + 신규 RH 90. 기존 73건 중 **71건은 무변경 PASS, 2건(QR16, QR16b)은 의도된 의미 변경**: 1차는 "admin 이 `config/qoin` 에 `accrualRate` 쓰기/신규 문서 create 허용" 이었으나 spec §8 에 따라 `accrualRate` 는 거부, `enabled` 만 허용으로 바꿨다 (케이스도 `enabled` 쓰기 / `accrualRate` 없는 create 로 수정) |
| **CF 에뮬레이터** (`cd functions && npm run test:emulator`) | **42/42 PASS** — 저장소에 스크립트 포함, `firebase.json` 에 functions 에뮬레이터 설정 추가 |

### CF 에뮬레이터 케이스 (spec §15.2 대응)

| ID | 검증 | 결과 |
|---|---|---|
| CH1~CH10 (+확장 R11~R20) | 진리표 20행 end-to-end (적립액 / `accrualRate` / `accrualRateSource` / INVALID 중단) | PASS |
| CH11 / 11b / 11c | **매장 0% · 브랜드 0% · 전역이 깨져도(0.5) 환불 회수는 정상** + 같은 매장 새 주문은 적립 안 됨 | PASS |
| CH12 | `enabled=false` → 적립·회수 모두 중단 (1차 회귀) | PASS |
| CH13 / CH14 | 매장 문서 없음 → 상속 / `storeId=''` → 중단 | PASS |
| CH16 | **read 수 실측** (아래) | PASS |
| CH17 / CH18 | 멱등 / 원장 `brandId`·`accrualRateSource` | PASS |
| CH19~CH21 | non-admin `permission-denied`, 비로그인 `unauthenticated`, 서버 경계(0.5/0.0005/-1/"3"/1/0.0305/null → `invalid-argument`), 전역 0·clear 거부, 값+이력 동시 생성(`before` 정확, `status`/`updatedAt` 불변), 같은 값 재호출 no-op | PASS |
| CH22 / 22b | 일괄 preserve (브랜드 값 1 write, 개별 설정 보존, 이력 1건), 입력 검증·권한·없는 브랜드(이력 0) | PASS |
| CH23 | 일괄 overwrite **매장 600곳** — 청크 처리, `affected 600 / cleared 200`, 이력 1건 | PASS |
| CH24 | 중단 후 `resumeHistoryId` 재개 — 멱등, 이력 1건 유지, completed 마감, 완료/진행 중 이력 재개 거부, 동시 시작 거부 | PASS |
| CH25 | 일괄 적용 **중** 폴링 108회 — override 없는 매장은 `옛 브랜드 값 → 새 값` 만, override 매장은 `자기 값 → 새 값` 만 관측. **전역/옛 값으로 떨어진 관측 0** | PASS |
| CH26 / CH27 / 27b | Admin SDK 직접 write → `source:direct` 1건, callable 직후 트리거 발화에도 중복 없음, 전역 최초 생성 이력 2건 | PASS |

### CH16 read 수 실측 (Firestore SDK 요청을 직접 센 값)

| 경로 | 문서 read | `batchGet` 왕복 | 계층 읽기 |
|---|---|---|---|
| earn (브랜드 소속) | **5** (config 1 + store 1 + brand 1 + 가드 1 + users 1) | 4 | `getAll` **1 라운드트립** |
| earn (개인 매장) | **4** | 4 | 〃 |
| clawback | **4** (1차와 동일) | 4 | **0** |

spec §1.6 의 "적립 4~5 / 회수 4" 와 일치.

---

## 6. 인덱스 실측 결과 (⑧)

**결론: admin 이력 화면의 `collectionGroup('qoinRateHistory') orderBy changedAt` 는 단일 필드 collection-group 인덱스가 필요하고, 자동 생성되지 않는다 → `firestore.indexes.json` 의 `fieldOverrides` 에 추가했다. 이 인덱스는 배포해야 한다.** 그 외 복합 인덱스는 쓰지 않도록 설계를 줄였다.

근거 (측정한 것 / 못 한 것을 구분한다):

| 사실 | 방법 | 결과 |
|---|---|---|
| 에뮬레이터는 인덱스를 강제하지 않는다 | 1차 test_report ⑧ + 이번에도 RH23 / CH 이력 쿼리가 통과 | **통과는 근거가 아니다** (같은 함정) |
| 운영에 배포된 인덱스 | `firebase firestore:indexes --project order-app-5957e` (**읽기 전용** 조회) | 11개 composite + 2개 fieldOverride(`menuItems.mainCategory`/`subCategoryId`). **`qoinRateHistory` 관련 항목 0건** |
| collection-group 단일 필드 인덱스가 자동인가 | 운영 설정 선례: `menuItems.mainCategory` 는 collection-group 쿼리를 위해 `fieldOverrides` 로 `COLLECTION_GROUP` 인덱스를 **명시 추가**해야 했다 (자동이었다면 override 가 필요 없다) | 자동 아님 (Firestore 규칙: collection-scope 단일 필드만 자동) |
| 운영에서 실제 쿼리 프로브 | **수행하지 않음** (배포 금지 + 1차에 운영 프로브가 권한 분류기에 막힌 전례). 따라서 위 결론은 "문서화된 규칙 + 프로젝트 선례" 에 근거한 것이지 운영 실행 결과가 아니다 | **배포 후 admin 이력 화면이 `failed-precondition` 없이 뜨는지로 최종 확인 필요** |

설계를 줄인 부분 (복합 인덱스 회피, design D10 "불가하면 축소"):

- **허브 partial 배너 · 브랜드 목록의 `적용 중단됨` 태그 · 이력 필터(전역/브랜드/매장/미완료)** 는 `where status …` 서버 쿼리를 쓰지 않는다. **최근 이력 페이지(50건) 안에서 클라이언트가 판정**한다. 따라서 가장 최근 50건 밖으로 밀려난 `partial` 은 허브에서 보이지 않는다 (브랜드 편집 화면은 그 브랜드의 최근 20건을 직접 조회하므로 보인다 — 브랜드 서브컬렉션 쿼리는 자동 인덱스).
- 서버 쿼리를 쓰는 곳이 모두 자동 인덱스 범위인지 점검: 대상별 이력 `orderBy changedAt desc limit` (collection scope, 자동), `histCol.where('status','==','in_progress')` (단일 필드 동등, 자동), CF 의 `stores where brandId ==` (동등 단독 + 기본 문서 ID 정렬 + `startAfter` — 에뮬레이터가 못 잡는 함정을 피하려고 **명시적 `orderBy(documentId)` 를 제거**했다), 트리거의 `orderBy changedAt desc limit 10` (자동).
- 인덱스 배포 전에 새 admin 이력 화면을 열면 일반 에러 뷰(`이력을 불러오지 못했어요`)가 뜬다 (인덱스 오류 문자열은 노출하지 않음).

---

## 7. 사용자 배포 명령 (순서 중요)

배포는 하지 않았다.

```
# 1) 인덱스 (collection-group 인덱스는 빌드에 시간이 걸린다. 가장 먼저)
cd /Users/Byeonguk/Developer/OrderApp && npx firebase-tools deploy --only firestore:indexes

# 2) Cloud Functions — Rules 보다 먼저 (callable 이 살아 있어야 새 앱이 적립률을 저장할 수 있다)
cd /Users/Byeonguk/Developer/OrderApp/functions && npm run build && cd /Users/Byeonguk/Developer/OrderApp && npx firebase-tools deploy --only functions:onOrderQoinSettled,functions:setQoinAccrualRate,functions:applyBrandQoinRate,functions:onQoinConfigWritten

# 3) Rules — 이 시점부터 1차 앱(admin 이 적립률을 직접 쓰던 버전)의 적립률 저장은 거부된다
cd /Users/Byeonguk/Developer/OrderApp && npx firebase-tools deploy --only firestore:rules

# 4) 앱 빌드/배포 (새 admin 화면은 callable 로 저장)
```

- 마이그레이션/백필 **불필요**: `config/qoin` 은 그대로 전역 기본값, `stores`/`brands` 필드는 부재 = 상속.
- 순서가 틀려도 데이터가 깨지지는 않는다: (2) 전에 앱이 callable 을 부르면 `not-found`, (3) 후 구앱의 직접 쓰기는 `permission-denied`. 어느 쪽도 "적립률이 이력 없이 바뀌는" 방향은 아니다.
- `onOrderQoinSettled` 새 버전은 필드가 없는 기존 데이터에서 1차와 동일하게 동작한다 (`source:'global'`).

---

## 8. 테스트 포인트 (tester)

### grep / 자동 확인

| 확인 | 명령 / 위치 |
|---|---|
| 경계 상수 중복 선언 0건 | `grep -rn "minTenths\|maxTenths" lib/ \| grep "static const"` → `qoin_policy.dart` 1곳. `grep -rn "MIN_RATE\|MAX_RATE" functions/src` → 선언은 `qoinRate.ts` 1곳. 자동: `qoin_architecture_guard_test.dart`, `qoinRate.test.mjs` 마지막 케이스 |
| 검증 문구가 공용 2파일에만 | `grep -rn "이상 입력해주세요\|까지 입력할 수 있어요\|소수 첫째 자리\|2배 이상이거나" lib/` → `qoin_rate_input_field.dart`, `qoin_rate_confirm_dialog.dart` 만 (**리터럴 `0.1% 이상` 은 `${QoinPolicy.minPercentLabel}%` 보간이라 grep 하면 안 잡힌다**) |
| 범위 페이지가 `validateRateInput` 직접 호출 0 | `grep -rn "validateRateInput" lib/presentation` → `qoin_rate_input_field.dart` 만 |
| Firebase import | `grep -rn "package:cloud_firestore\|package:cloud_functions\|package:firebase_" lib/presentation lib/domain` → 0건 (`cloud_functions_remote_data_source.dart` 같은 **파일명** 매칭은 패키지 import 가 아니다) |
| `Color(0x` | `grep -rn "Color(0x" lib/presentation/admin/qoin lib/presentation/common/widgets/qoin` → 0건 |
| 쓰기 맵에 `qoinAccrualRate` 0 | `grep -rn "'qoinAccrualRate'" lib/data` → 0건 (`FirestorePaths.qoinAccrualRateField` 상수로 **읽기만**) |

### 수동 UI (spec §15.4, 실결제 0회 — Console 로 `ready` → `completed` **수정**)

MH1~MH16 그대로. 특히:

- MH4+MH5: 매장을 `적립 안 함` 으로 둔 뒤 환불 → **회수는 된다.** (CF 에뮬레이터 CH11 로 검증됐으나 라이브 확인 필요)
- MH6/MH7: 전역·브랜드·매장 3범위에서 `0.03` / `30` 차단, 확인 다이얼로그 첫 줄에 범위+대상명.
- MH8/MH9: 일괄 적용 보존/덮어쓰기. 덮어쓰기 확인에 **영향 수 / 적립 안 함 N곳 재활성 / 재설정 안내**가 보이고 체크 전 버튼 비활성.
- 로딩 중 `0%`/이전 값이 그려지지 않는지 (네트워크 지연 상태에서 허브·목록·점주 화면).
- 점주·브랜드 화면에 **입력란/수정 버튼/값 chevron 없음** (읽기 행 11건 + 구조 테스트로 자동 확인됨).
- 허브 partial 배너와 `이어서 적용`: 실제 중단 재현은 어렵다 → Console 에서 이력 문서를 `status:'partial'` 로 편집해 확인 (CF 재개 로직 자체는 CH24 로 검증).
- 인덱스 배포 후 admin `변경 이력` 이 에러 없이 뜨는지 (§6).

### 내가 확인하지 못한 것

- 실기기/에뮬레이터 UI 육안 검증은 하지 않았다 (위젯 테스트 + 관리자 화면 스모크 13건까지). 스크린리더 라벨 실청취 미수행.
- 운영 Firestore 인덱스 프로브 미수행 (§6).

---

## 9. design / spec 대비 차이 · 판단

1. **`QoinRateSetting`(4값) 을 엔티티 필드로**: spec 은 `StoreEntity.qoinAccrualRate: double?` 였으나 `double?` 은 부재 / 무효 / 0 을 구분하지 못한다 (작업 지시 ⑤). `QoinConfigEntity` 는 기존 `accrualRate: double?` 를 유지하고 `accrualRateSetting` 을 추가했다 (기존 사용처 무수정).
2. **`WatchEffectiveQoinRateUseCase` 를 만들지 않았다**: 3스트림 결합은 Riverpod `AsyncValue` 합성이 로딩/에러 전파("3소스 모두 준비 전엔 숫자 금지")를 가장 직접 표현한다. 해석 규칙 자체는 순수 함수(`resolveEffectiveQoinRate`)라 테스트 가능하다. providers: `effectiveStoreQoinRateProvider`, `effectiveBrandQoinRateProvider`, 목록용 `resolveStoreQoinRate`.
3. **`QoinPartialBanner`, `QoinLoadError` 를 `common/widgets/qoin/` 에 둠** (design 은 `admin/qoin/widgets/`): 공용 이력 타일이 배너를 품고 이력 화면(점주·브랜드)이 에러 뷰를 쓰므로, `common → admin` import 를 만들지 않으려고 옮겼다. 구조 가드 테스트가 `common` 의 admin import 0건을 확인한다.
4. **이력 스키마 추가 필드**: `targetName`(D9 박제), `totalCount`, `preservedCount`, `lastProgressAt`. 전역 최초 생성 시 `enabled` 이력도 함께 남겨 `onQoinConfigWritten` 의 가짜 `direct` 이력을 막는다.
5. **callable 은 0.1% 격자(tenths 정수 배수)도 검증**한다 (`0.0305` 거부). 적립 시점 검증(`classifyRate`)은 범위만 본다 (Console 값은 격자 밖이어도 범위 안이면 그대로 쓴다 — 기존 동작).
6. **`config/qoin` delete 금지**: 삭제도 `accrualRate` 소멸 경로다. 1차에는 admin delete 가 열려 있었다. Console 삭제는 트리거가 `direct` 로 기록한다.
7. **회수 경로가 전역 적립률 유효성에 더 이상 의존하지 않는다**: 1차 `loadConfig` 는 전역 적립률이 무효면 회수도 막았다. 이제 kill switch(`enabled`)만 회수를 멈춘다 — 전역 값이 깨져도 환불 회수는 돼야 돈이 새지 않는다 (CH11c).
8. **허브 `전역 기본값` 버튼 문구**: 문서가 없을 때만 `전역 기본값 설정하기`.
9. 점주 읽기 행은 `pending`/`rejected` 매장에도 보인다 (`_StoreInfoSection` 이 모든 상태에서 쓰이고 admin 이 승인 전에 미리 정할 수 있으므로). 브랜드 정보 카드는 design 대로 승인된 브랜드에서만.
10. `이력` 의 변경자 이름은 admin 에게만 `users` 문서에서 조회(uid 당 1구독), 실패 시 `관리자 {uid 끝4}` (D9). 점주·브랜드에게는 항상 `관리자`.

---

## 10. 미구현 · 보류 · 알려진 한계

- **N6**: `stores`/`brands` 적립률의 Console 직접 편집은 감시하지 않는다 (spec 확정 한계). `enabled` 토글의 행위자는 알 수 없다(`changedBy:null`, U3 확정).
- **허브 partial 배너 축소 동작** (§6): 최근 50건 밖의 `partial` 은 허브/브랜드 목록에서 안 보인다. 브랜드 편집·해당 이력에서는 보인다.
- **backlog 후속**: 덮어쓰기가 `적립 안 함` 매장을 다시 적립하게 만든다 — 이번엔 확인 다이얼로그에 알리는 것까지 (`docs/backlog.md` 에 후속 과제로 기록됨, 계층화 라이브 검증 때 결정).
- `in_progress` 가 CF 타임아웃(540s)으로 끊긴 경우 서버는 마감하지 못하고 5분 후 클라이언트가 `partial` 취급한다 (재개 가능).
- 문서 갱신(`backlog.md` 완료 처리, `data_ownership.md` §2.5/2.7/§3, `audit_trail.md` §3 A1 해소, `role_flows.md`)은 하지 않았다 — architect 후속.
- 위젯/스모크 테스트 외 실기기 검증(MH1~MH16) 미수행.
- 임시 파일 · `--target` 빌드 없음. `dart format` 은 **신규 파일 + 전면 교체한 허브 페이지만 개별 지정**했고, 수정한 기존 파일은 포맷하지 않았다 (디렉터리 전체 실행 없음).

---

# 개정 2 구현 — tester FAIL 6건 + Q1(적립 스위치) + N4(브랜드 스위치 우선)

기준: spec §19(F1~F5·부가 B·H-2·H-3) → §20(Q1~Q3) → §20.3.1 개정판 · §20.14(N1~N8). 위 §1~§9 와 충돌하면 **이 절이 우선**한다. 배포·commit 하지 않았다. 운영 Firestore 접촉 0.

## R1. 구현 완료 항목

| 항목 | 내용 |
|---|---|
| F1 | 브랜드 신뢰원 = `stores/{storeId}.brandId`. `CartEntity` 에 brandId **미추가**, `verifyTossPayment` 는 cart 의 brandId 를 읽지 않고 `null` 기록. 주문 구성은 순수 함수 `functions/src/orderBuilder.ts`(`buildOrderData`/`buildOrderLogData`/`CONSUMED_CART_KEYS`). 원장 `brandId` = 해석에 쓴 값. 회수는 earn 원장 상속 |
| Q1 | `qoinAccrualEnabled`(false 만 저장, 켜면 필드 삭제). `setQoinAccrualEnabled` callable, 0 은 쓰기 측 전면 거부, 일괄 적용은 스위치를 쓰지 않음 |
| N4 | 해석 사슬 개정판: storeSwitch disabled → brandSwitch disabled → storeSwitch invalid → brandSwitch invalid → storeRate → brandRate → globalRate. TS·Dart 분기 순서 동일, 진리표 공유 |
| F2 | 매장별 `clearByBulk` 이력(ID `bulk_{bulkHistoryId}` 결정적), 분류 집계 `clearedValueCount`/`clearedInvalidCount`/`disabledUntouchedCount`/`brandDisabled`, CHUNK 450→225 |
| F3 | Rules `enabledChangedBy == uid()` 강제, 앱이 `enabledChangedBy/At` 기록, 트리거가 `source: app_direct` + 행위자. 이력 field `globalEnabled` |
| F4 | Rules 하네스 3건(+스위치 변형 2건) 고정 |
| F5 | 브랜드 포인터 `qoinBulkHistoryId/Status/At` 를 트랜잭션 안에서 검사(추가 read 0). 재개 재검증(포인터·브랜드 현재 값 = 이력 `after`), `resumedAt/resumeCount`, 단건 변경·스위치 변경도 진행 중 거부, stale 5분 |
| 부가 B / H-2 | `beforeState`/`beforeRaw`(적립률·스위치·config 전 경로), `qoinSettlementIssues/{orderId}`(invalid_rate/invalid_enabled/invalid_store/invalid_total, 멱등, Rules read admin·쓰기 차단). 스위치 off 는 미기록 |
| H-3 | 허브 배너 = brands 포인터 기반 + `AsyncValue.when` 3분기, "최근 변경" 에러 행 |
| 마이그레이션 | `migrateQoinZeroRates`(임시, dry-run/실행, 멱등, 무효 값 보고만) + 허브 카드 1파일 + 레거시 가드 + 판독 호환 분기 |
| N8 | `clearByBulk` 행은 문장만, 브랜드 이력 링크는 admin / 해당 브랜드 `role==brand` 에게만. Rules 변경 없음 |

## R2. 변경 파일 (백엔드; Dart 목록은 R7)

`functions/src/`: `qoinRate.ts`(RateCell 3값+legacyZero, `classifySwitch`, resolve 5입력, `isValidCallableSwitch`) · `qoinAdmin.ts`(`describeRaw`/`rateBeforeInfo`/`switchBeforeInfo`/`isBulkInProgress`) · `setQoinAccrualEnabled.ts`(신규) · `migrateQoinZeroRates.ts`(신규·임시) · `orderBuilder.ts`(신규) · `onOrderQoinSettled.ts` · `applyBrandQoinRate.ts`(전면 개정) · `setQoinAccrualRate.ts` · `onQoinConfigWritten.ts` · `verifyTossPayment.ts` · `index.ts`
`firestore.rules`: `touchesQoinManaged()`/`hasQoinManagedOnCreate()`/`qoinManagedFields()`(5필드 집합 1곳), `config` 의 `enabledChangedBy` 강제, `qoinSettlementIssues` 블록
테스트: `test_fixtures/qoin_rate_truth_table.json`(resolve 32 / resolve_legacy 3 / classify 13 / classifySwitch 7 / callable 12 / callableSwitch 4), `test_fixtures/qoin_cart_contract.json`(T2), `functions/test/*.mjs`, `test_rules/rules.test.mjs`

## R3. 테스트 결과 (전부 직접 실행)

| 항목 | 결과 |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **368 passed** (1차 기준선 260) |
| functions `npm run build` (tsc) | 오류 0 |
| functions `npm test` | **82/82** |
| Rules 하네스 `test_rules` `npm test` | **261/261** (기존 163 + 신규 98: 보호 5필드 × 경로 20 + 삭제 3 + F3 7 + issues 17 + F4 + N8) |
| CF 에뮬레이터 `npm run test:emulator` | **80/80** (마지막에 `clearedZeroCount` 단언 문자열 1줄만 바꾼 뒤 재실행하지 않음 — 동치 변경, `npm test` 로 grep 가드는 통과) |

에뮬레이터 1순위 회귀: Q1(일괄 덮어쓰기 후 `사용 안 함` 매장 미적립, 스위치 불변·60곳 600매장 규모) · N4 ①~⑥(①브랜드off+개별10% 적립0·이슈 미기록 ②환불 회수 통과 ③R23b ④R22b 기록 ⑤R21b 미기록 ⑥brandDisabled) · R25 · T3 3케이스 · F5(a)(c) · 마이그레이션 멱등 · 레거시 가드 · 진리표 32행 E2E(주문은 `buildOrderData` 로 생성, 손 시드 0).

## R4. 적립 1건당 read · 라운드트립 (에뮬레이터에서 SDK 요청을 직접 센 값)

| 경로 | 문서 read | batchGet 왕복 | 1차(직전) |
|---|---|---|---|
| earn 브랜드 소속 | 5 | **4** | 5 / 4 |
| earn 개인 매장 | 4 | **3** | 4 / 4 |
| clawback | 4 | 4 | 4 / 4 |

증가 **0**(개인 매장은 왕복 −1). 스위치는 이미 읽는 store/brand 문서의 필드라 read 추가 없음.

## R5. grep 0건 확인

`explicitOffRate` / `allowZero` / `skipped_rate_zero` / `clearedZeroCount` : lib·functions/src·firestore.rules 0건 (test 쪽은 "부재를 검증하는 가드 문자열"만 존재). `after.brandId` · `cart.brandId`(금액·원장 경로, 주석 제외) 0건 — `qoinRate.test.mjs` T4 가 자동 검사. design §18-12 삭제 대상 문구는 Dart 가드 테스트가 자동 검사(0건). `asData?.value == null → SizedBox.shrink` 0건(가드 테스트가 허브 `.when` 3분기를 검사).

## R6. 과도기 자산 5종 — 정리 커밋 일괄 삭제용 (`TRANSITIONAL(spec §20.4.5)` 로 grep 가능)

1. **호환 분기**: TS `qoinRate.ts`(`legacyZero`, resolve 의 legacy 2줄), `onOrderQoinSettled.ts` 로그의 `legacy`; Dart `qoin_rate_resolver.dart`, `qoin_rate_labels.dart`, 허브·사슬·힌트의 legacy 처리
2. **픽스처**: `resolve_legacy` 배열 + `transitionalExpect` 키(R16b/R16c, classify 0행) + 양쪽 테스트의 `expectOf`/legacy 그룹
3. **레거시 가드**: `applyBrandQoinRate.ts` `legacyZeroGuard`, Dart `QoinRateException.legacyZero*`·`qoin_callable.dart` details 파싱·`QoinMessages.legacyZeroGuard`
4. **callable**: `migrateQoinZeroRates.ts` + `index.ts` export + Dart 마이그레이션 파일 5개 + 에뮬레이터 섹션 I
5. **카드**: `admin_qoin_migration_card.dart`(허브에는 import+마운트 1줄) + 관련 테스트

## R7. Dart 변경 요약 (fork 구현 — 상세는 git diff)

신규: `qoin_callable.dart`, 마이그레이션 데이터/도메인 5파일, `set_qoin_accrual_enabled_use_case.dart`, `admin_qoin_migration_card.dart`, `qoin_accrual_switch_card.dart`, `qoin_reenable_hint.dart`(문장은 resolver 재해석으로 생성, 위젯 조립 없음), 테스트 5파일. 수정: spec §20.9 의 core/domain/data/presentation 전 목록. `payment_gateway_repository_impl.cartToMap` 은 `@visibleForTesting` 공개(T2). 쓰기 맵에는 어떤 `qoin*` 필드도 없음(테스트로 고정).

## R8. tester 전달 테스트 포인트

Q1 수용(일괄 덮어쓰기 후 미적립) 재현 · N4 6건 · 회수 통과 · 진리표 Dart/TS 동일 파일 · 20경로 독립 열거 · 마이그레이션 멱등/이력/행위자 · 과도기 자산 5종 삭제 가능성 · T1~T4(손 시드 주문 0건) · 허브 에러/로딩/없음 3상태 · N8 링크 게이팅 · 점주에게 브랜드 이력 DENIED.

## R9. 미구현 · 보류 · 설계 보고

- 미구현(범위 외 확정): 부가 A(격자 밖 값 표시), D-3 전체 이력 페이지네이션, Q2 소급 도구, `stores.delete` 정책, N6 Console 감시.
- 브랜드 편집 페이지 자체의 `이어서 적용` 배너는 해당 브랜드 이력 스트림을 읽어 이력 에러 때 아무것도 안 보인다(design §18-8 은 허브만 규정). 허브·브랜드 목록 태그·최근 변경은 포인터/3상태.
- F5(b) 동시 호출은 에뮬레이터에서 3동시 호출 시 `changed, noop, noop` 으로 관측(거부가 아닌 no-op 으로 귀결). 불변식(이력 1건·매장 이력 1500건 중복 0·카운트 이중 보고 0)만 단언. 진행 중 거부는 포인터 시드로 결정적 검증(F5-c).
- 설계 보고(뒤집지 않음): ① 레거시 0 가드는 브랜드 자신의 레거시 0 도 포함시켰다(spec 은 산하 매장만 언급; 브랜드 0 덮어쓰기 시 전체 적립 재개 위험 때문). ② 새 일괄 적용이 기존 `partial` 포인터를 대체하면 옛 partial 이력은 영구 `partial` 로 남는다(spec 미규정). ③ `enabledChangedAt` 은 Rules 가 강제하지 않는다(spec 은 `enabledChangedBy` 만) — 사칭은 막히나 시각 위조는 가능, 기록은 `direct` 로 안전 측. ④ 마이그레이션은 무효 값 탐지를 위해 `orderBy('qoinAccrualRate')` 로 필드 보유 문서만 스캔(전 매장 read 없음).
- 확인 불가: 운영 인덱스 동작·실제 배포 후 화면(배포 금지). `npm run test:emulator` 는 `functions/` 에서, Rules 는 `cd /Users/Byeonguk/Developer/OrderApp/test_rules && npm test` 로 재현.
- 임시 파일/실험용 엔트리포인트: `lib/tmp_*` 없음, 생성하지 않음. 스크래치패드 로그만 사용.

---

# 개정 3 구현 — 2차 검증 FAIL S1·S2·S3·S5·S6 + 정정 4건 (spec §21, design §19)

실결제 0회. **배포하지 않았다.** 보안 task(`docs/tasks/brand_authorization_hardening/implementation.md`)와 **같은 배포 창**이다. S4 는 그 문서에 있다.

## C1. 구현 완료 항목

| FAIL | 처리 | 핵심 |
|---|---|---|
| S2 포인터를 지울 수 없다 | 포인터를 **상태 기계**로 (`in_progress` / `partial` / `completed` / `superseded`) | 삭제 0. `partial` 뒤의 모든 CF 성공(새 일괄 overwrite·preserve · 브랜드 단건 · 브랜드 스위치)이 옛 이력 문서와 포인터를 **같은 트랜잭션**에 마감한다. 같은 값 + 지울 것 0 + `partial` 이면 새 이력 없이 옛 이력을 `completed(closedReason:'nothing_left', closedBy)` 로 닫고 `{changed:false, closed:true}`. 신규 필드·Rules·인덱스 0 |
| S3-a 빈 이력 | `scanStartedAt` 가드 | `sameValue && 포인터 종결(completed/superseded) && qoinBulkAt > scanStartedAt` → `{changed:false, staleScan:true}` + `console.warn`. **`partial` 은 가드에 넣지 않았다** |
| S3-b `changed` 미소비 | 소비 지점 전수 | 일괄 결과 카드(`_UnchangedCard`) · 단건 SnackBar(전역·매장) · 스위치 SnackBar · 이력 화면 재개. 전부 `changed == false` 분기를 **성공 분기보다 먼저** 검사 |
| S1 판정 출처 | `resolveBulkBanner(BrandEntity, now)` 단일 함수 | 허브 provider · 브랜드 목록 태그 · 브랜드 편집 배너 · 브랜드 정보 plate · 이력 행(포인터 일치 조건)이 공유. 수치만 `qoinBulkHistoryId` 로 이력 문서 1건을 **직접 읽는다**(`qoinBulkHistoryDocProvider`, 스트림 아님). 로딩·실패·문서 없음이어도 **배너와 `이어서 적용` 은 유지, 수치만 생략** |
| S6 과도기 마커 | 기계가 목록을 소유 | `qoin_architecture_guard_test` 가 레거시 토큰 10종으로 `lib/ functions/src/ functions/test/ test/ test_fixtures/` 를 grep → **파일 집합 == 허용 목록**(초과·누락 둘 다 FAIL) + 허용 목록 전 파일의 마커/`_transitional` 메타 키 단언 |
| S5 | 설계자가 직접 갱신 (완료) | — |
| 정정 1 | `enabledChangedAt == request.time` | Rules 1줄 (update 의 `enabled` 변경 시) |
| 정정 2 | 단건 `setQoinAccrualRate` 레거시 0 가드 | 대상의 현재 값이 레거시 0 이면 `failed-precondition` + `details{legacyZeroCount,storeIds}`. `LEGACY_MESSAGE_PREFIX` 는 `qoinAdmin.ts` 1곳으로 올려 일괄·단건이 공유 |
| 정정 4 | 마이그레이션 `raw` 표시 | **원인이 TS 가 아니라 Dart 였다** (아래 C6) |

## C2. 변경 파일 (백엔드)

| 파일 | 내용 |
|---|---|
| `functions/src/qoinAdmin.ts` | `BULK_STATUS`, `isBulkPartial` / `isBulkTerminal`, `readPartialHistory`(트랜잭션 안 read-before-write), `supersedePartialHistory`, `completePartialHistoryNothingLeft`, `supersededPointerFields`, `LEGACY_MESSAGE_PREFIX` |
| `functions/src/applyBrandQoinRate.ts` | 완료 시 포인터 **삭제 → `completed`**(overwrite·preserve·재개 모두), partial 마감, staleScan 가드, nothing_left, 재개는 `superseded` 이력도 거부 |
| `functions/src/setQoinAccrualRate.ts` · `setQoinAccrualEnabled.ts` | 브랜드 scope 성공 시 `superseded` 마감. 값이 같은 noop 은 닫지 않는다. 레거시 0 가드(rate) |
| `firestore.rules` | `config` update `enabledChangedAt == request.time` |
| `functions/test/emulator.test.mjs` | 기존 단언 정정(포인터 삭제 → completed, "이력 1건" → **문서 수 자체**) + 신규 K1~K9, L(CF1~CF8) |

## C3. 변경 파일 (Dart)

| 영역 | 파일 |
|---|---|
| 판정 | `domain/entities/qoin_bulk_banner.dart` (신규: `resolveBulkBanner`, `resolveHistoryRow`). `QoinRateChangeEntity.isUnfinished/isRunning` **삭제**, `QoinBulkStatus.superseded` 추가(미지 코드는 여전히 null), 이력 `closedReason` / `supersededByUid` |
| 결과 | `QoinBulkApplyResult` 에 `closed` / `staleScan`, 단건·스위치 결과에 `closed` (미지 키 관대) |
| 이력 문서 1건 | `QoinRateRepository.fetchHistory` + datasource + `GetQoinRateHistoryDocUseCase` + `qoinBulkHistoryDocProvider` |
| 화면 | `admin_qoin_brand_rate_edit_page.dart`(이력 스트림 → 포인터, `_UnchangedCard`, 마감 고지) · `qoin_partial_banner.dart`(`full` 은 `brandName/rate/stale/progress`) · `qoin_bulk_resume.dart`(시그니처: 이력 엔티티 → brandId/historyId/remaining) · `admin_qoin_rate_history_page.dart` · `qoin_rate_history_tile.dart`(종결 줄 2종, 포인터 일치 시에만 재개) · `qoin_rate_info_row.dart`(브랜드 정보 plate) · `qoin_accrual_switch_card.dart` · 전역/매장 편집 페이지 · `qoin_admin_ui.dart`(`QoinMessages.rateUnchanged` 등) · `admin_qoin_brand_rates_page.dart` · `qoin_admin_providers.dart` (`isBulkUnfinished` 삭제) |
| 마커 | 8개 파일에 `TRANSITIONAL(spec §20.4.5)` + JSON `_transitional` 메타 객체 (C7) |

## C4. 테스트 결과 (전부 직접 실행)

| 스위트 | 결과 |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **447 / 447 PASS** (개정 2: 368) |
| `functions` `npm run build` (tsc) | 오류 0 |
| `functions` `npm test` (TS 단위) | **86 / 86 PASS** (개정 2: 82) |
| `functions` `npm run test:emulator` | **97 / 97 PASS** |
| Rules 하네스 `test_rules` `npm test` | **332 / 332 PASS** (개정 2: 261) |
| 통합 `npm run test:flow` | **27 / 27 PASS** |

신규 CF 케이스: **K1** partial 뒤 새 overwrite → 옛 이력 `superseded(supersededBy=새 id)` · 이력 문서 2건 / **K2** preserve / **K3** 브랜드 단건(noop 은 닫지 않음) / **K4** 스위치(매장 단건은 무관) / **K5** `nothing_left`(`closed:true`, 새 이력 0, 옛 이력 `completed`+`closedReason`+`closedBy`, 2회차는 평범한 noop, 남은 일이 있으면 닫지 않고 진행) / **K6** completed 뒤 신선한 스캔 → 정상 진행 / **K7** staleScan 가드(종결 포인터 + 미래 `qoinBulkAt` → `staleScan:true`, 이력 0, 매장 불변. `superseded` 도 동일. 다른 값·과거 종결 포인터는 비대상. **`partial` 은 가드하지 않음**) / **K8** 3동시 × 1500곳 → **브랜드 이력 문서 수 = 1**, 보고 clearedCount 합 1500, `changed:true` 1건 / **K9** 단건 레거시 0 가드.

**mutation 검증**: 가드 비활성화 → K7 FAIL, partial 마감 제거 → K3·F5-(a) FAIL (로그 확인 후 원복).

## C5. 종결 4경로 · 구버전 호환 · 읽기 비용

- 종결 4경로: 새 일괄(overwrite·preserve) · 브랜드 단건 · 브랜드 스위치 · `nothing_left`. 모두 같은 트랜잭션, 이력 문서는 삭제하지 않는다(`status` 전이).
- 구버전 앱: `QoinBulkStatus.fromCode` 가 미지 코드(`superseded`)에 null → 판정 `none`. `completed` 는 구버전 enum 에 이미 있고 구버전 판정이 중단으로 읽지 않는다. 의미 일치.
- 추가 read: `partial` 포인터가 있을 때만 +1 (옛 이력 문서). 적립 경로(`onOrderQoinSettled`)·결제 경로는 **손대지 않았다** (`git diff` 0). CH16 실측: earn(브랜드 소속) 문서 read 5 / 왕복 4, 개인 매장 4 / 3, clawback 4 / 4 — 개정 2 와 동일.

## C6. 작업표와 현실이 다른 곳

1. **`describeRaw` (정정 4)**: 작업표는 `migrateQoinZeroRates.ts` 의 `describeRaw` 를 지목했으나 TS 는 이미 JSON 표기(`true` · `[1]` · `{}`)를 보낸다. 따옴표를 덧붙이는 쪽은 **Dart `_raw`** (`num.tryParse` 가 아니면 `"…"` 로 감쌈). 서버 계약을 단위 테스트로 고정하고(`describeRaw` 4종) Dart 쪽을 `AdminQoinMigrationCard.formatRaw` 로 고쳤다 (JSON 으로 해석되면 그대로, 해석 불가 문자열만 따옴표).
2. **마커 누락 7개 + 실제 8개**: spec 의 7개에 더해 토큰 grep 이 `migratedFromRate` 로 `qoin_rate_change_entity.dart` / `qoin_rate_change_model.dart` / `qoin_history_tile_test.dart` 를 추가로 잡았다 (이력 읽기 호환 필드이므로 정리 시 필드째 삭제 대상으로 목록에 올렸다). `qoin_hub_states_test.dart` 는 토큰이 없어 목록 밖이다. `.freezed.dart` 는 생성 파일이라 스캔에서 제외(원본 `.dart` 가 마커를 가진다).
3. **`isUnfinished(` 가드 vs 이력 행**: 이력 행도 `isUnfinished(` 를 쓰고 있었다. 가드를 지키려면 이력 행 판정도 판정 파일로 올려야 했다 → `resolveHistoryRow` (포인터 일치 조건 포함, design §19-7-1).

## C7. 과도기 자산 목록 (S6, 기계가 소유)

`test/presentation/qoin_architecture_guard_test.dart` 의 `allowed` 가 단일 목록이다 (30개). 정리 커밋은 토큰을 제거하며 이 목록을 **빈 집합**으로 만든다. 검증: 허용 목록에 없는 파일에 토큰을 넣으면 FAIL(초과), 허용 목록에 토큰 없는 파일을 넣으면 FAIL(누락) — 둘 다 직접 확인했다.

## C8. 테스트 포인트 (tester)

1. PROBE1/PROBE3 를 **재현으로**: 포인터 `partial` + 이력 읽기 실패 → 배너·`이어서 적용` 있음 / 포인터 종결 + 옛 이력 `partial` → 배너 없음, 이력 행은 `이후 변경으로 마감됐어요`.
2. `partial` 종결 4경로를 에뮬레이터에서 (K1~K5) + 허브·목록·편집·브랜드 정보 4표면이 같이 사라지는지.
3. `changed:false` 가 화면에 "적용/변경/마쳤어요" 로 보이지 않는지 (일괄 · 전역 · 매장 · 스위치 · 이력 재개).
4. 구버전 앱 + 신 CF 구간(② 후 ③ 전): `superseded` 포인터 → 구 앱 허브에 배너 없음.
5. 라이브 검증(spec §21.9-5): 레거시 0 매장 브랜드 일괄 적용 시 `details` 가 `Map` 으로 오는지 (실기기만 가능).

## C9. 미구현 · 보류 · 설계 보고

- **보류**: spec §20.4.5 정리 절차 6·7 문서 추가, §20.4.4 라이브 검증 1행, `tester_guide.md` R5 — 문서 작업이라 설계자 몫으로 남겼다.
- **설계 문제로 보이는 것 (뒤집지 않고 보고)**:
  1. **staleScan 가드의 전제가 overwrite 에만 성립한다.** "종결 포인터 = 끝까지 마쳤다 = 지울 것이 없다" 는 overwrite 완료에만 참이다. preserve 완료·브랜드 단건·스위치로 생긴 종결 포인터(`completed`/`superseded`) 뒤에 같은 값을 `덮어쓰고 적용` 하면, 스캔이 그 전이보다 앞서면 실제로 남은 개별 설정이 있어도 `staleScan` noop 이 된다(재누르면 새 스캔으로 정상 진행). 돈에는 영향 없는 방향이지만 "했는데 바뀐 게 없다" 가 거짓일 수 있다. 포인터에 "overwrite 로 끝났는가" 가 없어 구분할 수 없다.
  2. **stale `in_progress` 는 종결되지 않는다.** 새 적용이 오래 멈춘 `in_progress` 포인터를 교체하면 그 이력 문서는 영구 `in_progress` 로 남는다(spec 은 `partial` 만 마감). 행은 "끝나지 않음" plate 를 `이어서 적용` 없이 영구히 그린다.
  3. **`config` create 에는 `enabledChangedAt` 이 강제되지 않는다** (spec 은 update 만). `enabled` + `enabledChangedBy` 만 담은 create 는 여전히 통과한다. create 는 문서 최초 생성 1회뿐이라 영향은 작다.
  4. **`EntityApprovalStatus.fromString` 은 `status` 부재를 `approved` 로 읽는다.** `status` 가 없는 브랜드 문서는 승인 화면에서 `approved` 로 분류되지만 매장 create Rules(D5)는 명시적 `approved` 만 허용한다.

---

# 개정 4 구현 — 3차 검증 FAIL 6 + 부수 2건 (한 번에)

| ID | 처리 |
|---|---|
| F-2 stale `in_progress` | CF `isBulkUnfinished(snap, BULK_STALE_MS)` = `partial` 또는 5분 넘게 갱신 없는 `in_progress` 를 `qoinAdmin.ts` 에 두고 **마감 4경로 전부**(새 일괄·단건·스위치·`nothing_left`) 에 적용 (`isBulkPartial` 삭제 — 두 번째 기준을 남기지 않았다). 5분 기준은 `test_fixtures/qoin_bulk_policy.json` 을 Dart(`qoin_policy_test`)·TS(`qoinRate.test.mjs`)가 같이 읽는다. TS 쪽은 상수 선언이 `qoinRate.ts` 1곳임도 단언 |
| F-S2 | `BrandInfoPage._EmptyView` 에서 등록 버튼·거짓 문구 삭제 (`연결된 브랜드를 찾지 못했어요 · 관리자에게 문의`). 가드: `BrandInfoFormPage(brand: null)` 이 **lib 전체에서 게이트 1곳**이고 다른 호출은 `brand: brand` 뿐 |
| F-S1 | `isBrandSelfUpdate`: `submittedBy` 는 **본인 uid 로의 설정만** 허용 (`RM-S1`~`S1e`) |
| F-4 | `qoin_hub_states_test.dart` 에 마커 + 허용 목록. 가드 양방향: 마커 ⊂ 허용 목록, 그리고 "통째로 지워질 파일(첫 줄 TRANSITIONAL)을 import 하는 test/ 파일 ⊂ 허용 목록". 마커만 있는 임시 자산 8개도 목록에 올림 (목록 39개) |
| H-1 | `config` create 도 `enabledChangedAt == request.time` (`EC8*`) |
| F-1 | 일괄 결과 카드가 `staleScan` 을 소비 — "같은 값" 이 아니라 `방금 다른 곳에서 먼저 처리됐을 수 있어요 · …한 번 더 시도해 주세요` |
| F-3 | `storeBrandLinkProvider` 를 `common/providers` 로 이동해 메뉴 승인 큐 타일·점주 `내 매장` 이 공유. `'브랜드'`·`'브랜드 매장'` 폴백 삭제. design 인벤토리 5~8행 추가. 가드에서 **면제 주석·4파일 나열 삭제**, `lib/presentation` 전수 grep |
| 게이트 `_classify` | CF 가 `details.reason` + message `[reason]` 토큰(실기기 details 미수신 대비)을 싣는다 (`already_linked` · `not_brand_account` · `not_submitter` · `brand_not_found`). Dart `BrandClaimException.classify`: 사유 없는 `failed-precondition` 은 "이미 연결" 로 단정하지 않고 `retryable`. 신규 `notBrandAccount`(별도 문구, 재시도 없음) · `brandMissing`(`다시 연결` 대신 `다시 확인` = 재조회, 무한 재시도 없음) |

## 검증

- K10(신규): stale `in_progress` 4경로 + 신선한 `in_progress` 는 닫지 않음. **수정 전 기준(stale 을 안 보는 판정)으로 되돌려 돌리면 K10 (a) 에서 FAIL** — `옛 이력 expected superseded got in_progress`.
- Rules: `RM-S1`·`RM-S1b` 와 `EC8`·`EC8b` 는 수정 전 rules(HEAD)에서 ALLOW 가 나와 FAIL (4건), 수정 후 PASS.
- 가드 F-4: 허용 목록에서 파일을 빼면 마커 방향 FAIL, 목록 밖 테스트가 임시 자산을 import 하면 import 방향 FAIL — 둘 다 직접 확인.

## 못 고친 것 / 보고

- **F-1 의 서버 측 정밀화는 하지 않았다.** 리포트의 수정안 A(가드 분기에서 이력 1건을 읽어 `bulkMode == overwrite` 일 때만 발동)는 서버 동작을 바꾸므로 택하지 않고, 안 B(화면이 구분해 말함)만 했다. 가드는 여전히 preserve 완료 직후에도 발동할 수 있다(돈 영향 없음, 재시도로 해소).
- 실기기에서 `details` 가 Map 으로 오는지는 여전히 확인 불가 — message `[reason]` 토큰이 이중 안전장치다.


---

# 정리 커밋 (spec §20.4.5) + 문구 버그 2건 — 2026-10-26

운영 배포 완료, 마이그레이션 dry-run 0건 확인 뒤 **한 번에** 삭제했다 (쪼개지 않았다).

| 삭제 | 내용 |
|---|---|
| 1 판독 호환 분기 | TS `classifyRate` 의 `legacyZero` / `Resolved.legacy` / `onOrderQoinSettled` 의 `legacy` 로그 필드. Dart `QoinRateCellKind.legacyZero` · `QoinRateSetting.legacyZero/isLegacyZero` · `EffectiveQoinRate.legacy` · resolver·labels·허브·사슬·재활성 힌트·설정 모델의 분기. 저장된 0 은 무효 |
| 2 픽스처 | `resolve_legacy` 배열 · `transitionalExpect` 키 · `_transitional` 메타. R16b/R16c 활성 |
| 3 레거시 가드 | `applyBrandQoinRate` 의 스캔·`legacyZeroGuard`·청크 가드, `setQoinAccrualRate` 의 단건 가드, `LEGACY_MESSAGE_PREFIX`, Dart `QoinRateException.legacyZeroCount` · `QoinCallable` details 파싱 · `QoinMessages.legacyZeroGuard` |
| 4 마이그레이션 | `functions/src/migrateQoinZeroRates.ts` + `index.ts` export, Dart 5개(datasource · repository impl · repository · use case · result), 이력 `migratedFromRate` 필드 (옛 `source: migration` 이력 행 판독은 유지) |
| 5 카드 | `admin_qoin_migration_card.dart` + 허브 마운트 한 줄. `formatRaw` 도 함께 삭제 |

테스트: emulator 섹션 I(MG-0~3) → 신규 `I-1~3`(저장된 0 = 무효: 적립 중단 + `invalid_rate` 이슈 / 일괄이 0 을 `clearedInvalidCount` 로 지움 / 단건이 0 을 `beforeState:invalid` 로 박제하고 덮음), K9 삭제, 픽스처 행 수 테스트 갱신. 가드 테스트 허용 목록 **빈 집합**.

**`auditBrandLinks` 판정 — 상시 도구로 승격.** 근거: ① 브랜드 링크는 Console 편집·문서 삭제·복구 작업으로 언제든 다시 어긋난다(방금 `users`·`brands` 전체 삭제 사고에서 복구 검증에 실제로 쓰였다) ② 읽기 전용(쓰기 0, 인자 없음, 가드 테스트가 쓰기 호출 부재를 단언)이라 유지 위험이 작다 ③ 지우면 다음 사고에서 같은 도구를 급히 다시 만들어야 한다. 조치: `TRANSITIONAL` 마커·`임시` 알약·"카드가 사라져요" 문구 제거, 가드 토큰 목록에서 `auditBrandLinks` 제외.

## 문구 버그 2건

- **조사**: 적립률 우선순위 사슬의 스크린리더 문장이 `${label}은` 으로 조립돼 `브랜드은` 이 나왔다. `KoreanParticle`(`core/utils/korean_particle.dart`, 받침 유무로 은/는·이/가·을/를·과/와)을 만들어 `withTopic` 으로 교체. 같은 패턴을 `lib` 전체 grep(`}은|는|이|가|을|를|과|와|으로|로`)으로 훑었다: 동적 값 뒤 조사는 이 1곳과 `${금액}이`(금액 문자열이 `원`으로 끝나 항상 맞음)뿐이고 나머지는 `곳은` 같은 고정 어휘였다.
- **로고 필수 표시**: 라벨 `브랜드 로고 *`. 제출이 막히면 SnackBar 가 빠진 항목을 지목한다 (`다음 항목을 확인해주세요: 브랜드 로고, 회사명`, 형식 오류는 `사업자등록번호(000-00-00000 형식)`). `missingBrandFormFields` 순수 함수 1개를 `_canSubmit` 과 SnackBar 가 공유한다.
