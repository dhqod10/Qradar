# Qoin 적립률 계층화 기능 명세

- 작성: 2026-10-22 (architect)
- **정합 재확인: 2026-11-02 (architect)** — `qoin_spend` 랜딩(커밋 `70e3356`) 후 공유 인프라 충돌·중복 점검. 결과·상세는 **§22**. §0 에 사용자 결정 대기항목을 모았다.
- 선행: `docs/tasks/qoin/` (1차 — 설계·구현·라이브 검증 완료, 실결제 0회)
- 병행 랜딩: `docs/tasks/qoin_spend/` (Qoin 사용 — 커밋 `0c96b3a`·`70e3356`, 이 계층화의 CF·이력·Rules 패턴을 **재사용**해 올라탔다. §22)
- 요구사항 출처: `docs/backlog.md` 의 `qoin_accrual_rate_hierarchy` 절 **H1~H7 (사용자 확정, 재논의 대상 아님)**
- 감사 추적 기준: `docs/processes/audit_trail.md` §4 (6개 체크리스트 — §13 에서 전건 통과)

---

## 0. 사용자 확인이 필요한 결정사항 (먼저 읽을 것)

> 설계 본체는 §1~§21 에서 H1~H7 / Q1~Q3 / N1~N8 / S1~S6 을 **전건 확정**했다. 아래는 그중 **아직 열린 1건**과, 설계자가 닫았지만 **되돌림 비용이 있어 지금이 가장 싼 3건**, 그리고 2026-11-02 `qoin_spend` 정합 점검의 **결정 불요** 결론만 모은 것이다. 각 항목의 근거는 괄호 안 절을 본다.

### §0.1 지금 결정이 필요한 것 — **1건**

| # | 질문 | 권고안 | 대안 | 근거 |
|---|---|---|---|---|
| **D-A** | **결제 시점 매장 `status` 게이트**(미승인·재제출 중 매장이 callable 직접 호출로 결제·적립되는 구멍)를 이 계층화 배포 창에 넣을지 | **별도 task 로 분리** (`brand_authorization_hardening/spec.md` §9 Q-S1). 1차 결제부터 있던 Qoin 무관 구멍이고, 결제 거부는 "돈이 멈추는 방향" 이라 매장 `status` 한 건이라도 틀어지면 정상 결제가 막힌다. 계층화 창(Rules·CF·앱·마이그레이션)에 결제 경로를 섞으면 실패 시 원인 분리가 어렵다 | ⓐ 이번 배포에 포함(단일 창) ⓑ `rejected` 만 차단하는 축소판만 포함 | §21.5 · §21.10 · `brand_authorization_hardening/spec.md` §9 |

### §0.2 설계자 확정 — 되돌리려면 비용이 드는 3건 (다르게 원하면 지금이 가장 싸다)

| # | 확정 내용(=권고 유지) | 다르게 하려면(대안의 대가) | 근거 |
|---|---|---|---|
| **D-B** | **매장 적립 스위치를 다시 켜면 상위(브랜드) 요율로 적립** — 끄기 전 숫자를 보존하지 않는다 | 스위치에 "끄기 전 숫자" 를 딸려 저장 → 필드 2개의 정합성 유지 비용이 되돌아온다 | §20.6.1 · §20.13-1 |
| **D-C** | **브랜드 단계에도 스위치를 둔다** (상위가 하위를 이긴다 — N4/A안) | 빼면 브랜드 단위 적립 중단(R05)이 사라지고, "일부만 멈추기" 운영 지침(§20.3.1)도 흔들린다 | §20.3.1 · §20.13-2 |
| **D-D** | **0 을 적립률 입력값으로 완전 금지** (0% 는 스위치로 대체 — Q1) | 0 저장 허용 시 "적립 안 함" 출처가 2개가 되어 Q1 이 고친 문제가 부분 재발 | §20.2.1 · §20.13-3 |

### §0.3 `qoin_spend` 정합 — **결정 불요 (확인 결과)**

2026-11-02 점검 결론: `qoin_spend` 는 이 계층화가 만든 공유 인프라(① `config/qoin/qoinRateHistory` 이력 컬렉션 ② `onQoinConfigWritten` 트리거 ③ `config/{docId}` Rules 블록 ④ `setQoinAccrualRate` 의 "값+이력 동일 트랜잭션" CF 패턴)를 **그대로 재사용**해 올라탔다. **충돌·중복·회귀 없음.** 다만 이 spec 본문(§5.2·§7.4·§8·§9)이 `qoin_spend` 랜딩 **전** 기준이라 몇몇 필드 enum·필드 수 서술이 **낡았다** — 교정 주석을 **§22** 에 모았다(코드는 이미 정합, 문서만 갱신). 사용자 결정 불요.

---

## 개요

현재 Qoin 적립률은 `config/qoin.accrualRate` **전역 1개**다. 그 위에 **매장별 / 브랜드별** 계층을 얹는다.

바뀌는 것은 **"적립률을 어디서 읽는가"** 와 **관리자 화면**, 그리고 **적립률 변경 이력(H7)** 이다.
1차의 원장(`users/{uid}/qoinTransactions`) · 잔액 · 멱등성 · 회수 · 고객 화면은 **그대로 재사용**한다.

### 전제 — 적립률은 돈을 발행하는 값이다

1차에서 발견된 두 결함을 재발시키지 않는 것이 이 설계의 1순위 제약이다.

| 1차 결함 | 이번 설계에서의 대응 |
|---|---|
| **F1** — 잔액 보호가 `update` 에만 있고 `create` 에 없었다 (보안 구멍) | §9 에서 **적립률 필드의 쓰기 경로를 create/update/일괄/Console 까지 전수 열거**한다. 한 경로라도 비면 FAIL |
| **F3** — 화면은 0.1~20% 인데 CF 는 `0..1` 만 검사했다 | §10 — **모든 범위(전역/브랜드/매장)에서 Dart·TS 양쪽에 같은 경계**. 화면 검증은 우회된다는 전제로 설계 |

---

## 1. 사전 조사 결과 (실측, 2026-10-22)

추측하지 않았다. 아래는 모두 코드 / Rules / git 로그를 직접 확인한 결과다.

### 1.1 1차에서 이미 완성된 것 (중복 설계 금지)

| 항목 | 위치 | 상태 |
|---|---|---|
| 적립/회수 CF | `functions/src/onOrderQoinSettled.ts` (`onDocumentUpdated orders/{orderId}`, `retry: true`, asia-northeast3) | 적립률 읽는 지점만 바뀐다 |
| 멱등 가드 | `earn_{orderId}` / `clawback_{orderId}` + 트랜잭션 내 선존재 가드 | **변경 없음** |
| 원장 스키마 | `txId / type / orderId / storeId / storeName / brandId / orderTotalPrice / accrualRate / amount / balanceAfter / createdAt` | `accrualRateSource` 1필드만 추가 (§5.3) |
| 잔액 갱신 | 트랜잭션 내 절대값 갱신 (`increment` 금지) | **변경 없음** |
| 회수 산식 | `-earn.amount` (재계산 금지) | **변경 없음 — 회수는 적립률을 읽지 않는다** |
| 경계 검증 (순수) | `lib/core/utils/qoin_policy.dart` — tenths 정수 환산, `validateRateInput`, 하한 1 / 상한 200, 인상 경고 | **재사용 + 확장** |
| CF 측 경계 | `onOrderQoinSettled.ts` 의 `MIN_RATE 0.001 / MAX_RATE 0.2` (F3 수정분) | **재사용 + 계층 전 범위 적용** |
| 전역 설정 문서 | `config/qoin` = `{ accrualRate: number, enabled: bool }` | **재사용** (의미가 "전역 기본값" 으로 명확화) |
| 관리자 화면 | `lib/presentation/admin/qoin/admin_qoin_settings_page.dart` (894줄) | **분해 후 재사용 + 허브로 교체** (§4-⑧) |
| 고객 화면 | `qoin_page.dart` + 위젯 5개 | 문구 1곳만 수정 (§4-⑨) |

### 1.2 Rules 실측

| 경로 | 현재 규칙 | 계층화 시 문제 |
|---|---|---|
| `config/{docId}` | `read: isSignedIn()` / `write: isAdmin()` | admin 이 SDK 로 `accrualRate` 를 직접 덮어쓸 수 있다 → **이력 누락 가능** |
| `stores/{storeId}` | `read: isSignedIn()` / `update: isAdmin() OR isStoreOwnerFieldUpdate OR isStoreOwnerBrandUpdate` | owner/brand 분기는 `onlyChangedFields` 화이트리스트라 **새 필드는 자동 차단**. 단 **admin 분기는 전권**이라 직접 쓰기가 열려 있다 |
| `brands/{brandId}` | 동일 구조 (`isBrandSelfUpdate` 화이트리스트 + admin 전권) | 동일 |
| `users/{uid}/qoinTransactions` | create/update/delete 전부 `if false` (admin 도 불가) | 변경 없음 |
| fallback | `match /{document=**} { allow read, write: if false; }` | **새 서브컬렉션은 명시하지 않으면 전면 거부** — 이력 컬렉션 블록 필요 |

**중요 (추측 아님, Firebase 의 성질)**: Firebase Console / Admin SDK 쓰기는 **Rules 를 우회**한다. 따라서 "Rules 로 직접 쓰기를 막으면 이력이 100% 보장된다" 는 **거짓**이다. §7.4 의 감시 트리거가 이 구멍을 메운다.

### 1.3 `stores` / `brands` 쓰기 방식 실측 — 새 필드는 안전하다

`store_remote_data_source.dart` 의 모든 쓰기는 `update(fields)` (명시 필드 맵) 이며 `set()` / `SetOptions(merge)` 전역 덮어쓰기가 없다 (L81/89/97/134). 따라서 `stores/{id}` 에 적립률 필드를 추가해도 **점주/브랜드의 기존 수정 흐름이 그 값을 지우지 않는다.**

### 1.4 재사용 가능한 조회 경로 (신규 설계 불필요)

| 필요 | 이미 있는 것 |
|---|---|
| admin 전체 매장 목록 | `StoreRepository.watchAllForAdmin()` — `orderBy createdAt desc` **limit 없음** (대량 시 §12.2 의 검색/필터로 완화) |
| 브랜드 산하 매장 목록 | `BrandRepository.watchStoresByBrand(brandId)` |
| 브랜드 목록 | `BrandRepository.watchAll()` |
| 매장 단건 | `StoreRepository.watchById` / `getById` |
| admin 진입점 | `admin_more_page.dart` 의 `Qoin 설정` 타일 (부제에 전역 적립률 표시 중) |
| 점주 노출 지점 | `owner/my_store/my_store_page.dart` 의 `_StoreInfoSection` |
| 브랜드 노출 지점 | `brand/brand_info/brand_info_page.dart`, `brand/stores/brand_stores_page.dart` |

### 1.5 주문 문서에 `brandId` 가 이미 있다 — ⚠️ **오판정. §19.1 에서 정정됐다**

`verifyTossPayment.ts` L225/L252 가 `orders/{orderId}.brandId = cart.brandId ?? null` 로 기록하고, `OrderModel` 도 읽는다. 1차 F2 수정으로 **원장에도** `brandId` 가 박제된다.
→ **계층 해석에 매장 문서를 거쳐 브랜드를 역조인할 필요가 없다.** (§7.2 의 1 라운드트립 설계 근거)

> ⚠️ **이 절은 틀렸다 (tester F1 / §19.1).** `CartEntity` 에 `brandId` 필드가 없고 `_cartToMap` 이 보내지 않으므로 `cart.brandId` 는 **항상 undefined** → 앱이 만든 주문의 `brandId` 는 **항상 null** 이다. 브랜드 단계는 실제 앱에서 한 번도 적용되지 않았다. 신뢰원은 **`stores/{storeId}.brandId`** 로 옮긴다 — **§19.1 을 따른다.**

### 1.6 현재 CF 가 읽는 문서 수 (실측 카운트)

`onOrderQoinSettled` 1회 실행당 document read:

| 경로 | 현재 | 계층 후 |
|---|---|---|
| 적립 (earn) | `config/qoin` 1 + 멱등 가드 1 + `users` 1 = **3** | `config/qoin` 1 + `stores` 1 + `brands` 0~1 + 멱등 가드 1 + `users` 1 = **4~5** |
| 회수 (clawback) | `config/qoin` 1 + `earn_*` 1 + 가드 1 + `users` 1 = **4** | **4 (변화 없음)** — 회수는 적립률을 읽지 않는다 |

증가는 **적립 1건당 +1~+2 read**. 절감·완화 방안은 §7.2.

---

## 2. 요구사항

### 2.1 확정 요구사항 (H1~H7)

| # | 확정 | 이 spec 의 반영 지점 |
|---|---|---|
| H1 | 비용 부담 = 브랜드 / 매장 (플랫폼 아님) | §5.3 원장에 `accrualRateSource` 박제 (정산 선행 자산) |
| H2 | 설정 권한 = **admin 전용**, 점주·브랜드는 읽기만 | §8 Rules, §9 쓰기 경로 전수 |
| H3 | 해석 순서 = 매장 → 브랜드 → 전역 기본값 | §6 |
| H4 | 브랜드 일괄 적용 = 별도 기능, 하위 매장 전체 | §7.3 `applyBrandQoinRate` |
| H5 | 일괄 적용 시 개별 설정 = **선택식**(보존/덮어쓰기), 덮어쓰기 시 영향 매장 수 확인, 덮어쓰면 개별 설정 초기화 | §7.3 + §12.2 |
| H6 | 조회 = admin 전체 / 점주·브랜드는 자기 것 읽기 전용 | §8, §12.3 |
| H7 | 변경 이력 = 누가/언제/어느 범위/이전→새 값/사유(선택), 일괄은 1건 + 영향 매장 수 + 덮어쓰기 여부 | §5.2, §7.3, §13 |

### 2.2 1차 범위 (이번에 한다)

1. `stores/{id}` / `brands/{id}` 에 적립률 필드 추가 + 계층 해석 (CF + 클라이언트 동일 알고리즘)
2. 적립률 쓰기를 **Cloud Function 전담**으로 전환 (단일 설정 + 브랜드 일괄 적용)
3. 적립률 변경 이력 컬렉션 + 조회 화면 (admin 전체 / 점주·브랜드 자기 것)
4. 관리자 계층 화면 (전역 / 브랜드 / 매장) — 1차의 100배 오입력 방어를 **전 범위 유지**
5. 점주·브랜드 읽기 전용 노출
6. 매장 단위 적립 중단 수단 (명시적 0%)
7. Rules 변경 + 테스트(Rules 하네스 / CF 에뮬레이터 / Dart 단위) — **실결제 0회**

### 2.3 2차 범위 (이번에 하지 않음 — 명시적 제외)

| # | 항목 | 미루는 이유 |
|---|---|---|
| N1 | **적립 비용 정산 / 청구** | `audit_trail.md` §5 — 세금계산서·정산주기·분쟁까지 엮인 별 주제. 이번엔 `accrualRateSource` 박제로 **선행 자산만** 확보 |
| N2 | 고객에게 **매장별 적립률 표시** (매장 상세 / 장바구니 / 결제 화면) | 고객 동선 전반(매장 상세·메뉴·체크아웃)을 건드려 범위가 2배가 된다. 1차는 §4-⑨ 처럼 **틀린 숫자를 지우는 것**까지 |
| N3 | 점주·브랜드의 **적립률 변경 요청** 워크플로우 (요청 → admin 승인) | H2 는 "읽기만" 이 확정. 요청 기능은 승인 큐 설계가 따라붙는다 |
| N4 | 기간 예약 적립률 (프로모션 기간 한정) | 스케줄러 + 기간 중첩 해석이 필요. 계층 해석이 먼저 안정화돼야 한다 |
| N5 | 메뉴/카테고리 단위 적립률 | 계층이 4단이 되고 CF read 가 다시 늘어난다 |
| N6 | `stores`/`brands` 적립률 필드에 대한 **Console 직접 편집 감시 트리거** | §7.4 — 1차는 `config/qoin` 만. 매장 문서 트리거는 호출 빈도가 커 비용/노이즈 판단 필요 |
| N7 | 이력 기반 **롤백 버튼** (한 번에 이전 값 복원) | 이력에 `before` 가 남으므로 수동 복원은 가능. UI 는 2차 |
| N8 | 1차 미해결 보류 H2 (중단 중 건너뛴 적립의 영구 기록) | Qoin 1차의 잔여 항목. 이 작업과 독립 |

---

## 3. 영향 범위

### 3.1 인프라 (배포 필요)

> ⚠️ **배포 순서는 §20.11 을 따른다** (§19.7-10 교체): `firestore:indexes` → `functions` → **마이그레이션 dry-run·실행** → `firestore:rules` + 앱 빌드 → 정리 커밋. **Rules 와 앱 빌드는 같은 배포**에 올린다(§19.3 의 `enabledChangedBy` 강제 때문).
>
> 인프라 변경 목록도 §20.9 의 추가분(`setQoinAccrualEnabled.ts` · `migrateQoinZeroRates.ts` 신규, Rules 헬퍼 교체)을 더해 읽는다.

| 대상 | 변경 |
|---|---|
| `firestore.rules` | `config/{docId}` 블록 **수정**, `stores`/`brands` update 분기에 적립률 필드 차단 **추가**, `qoinRateHistory` 컬렉션 블록 **신규** + collection-group 블록 |
| `functions/src/onOrderQoinSettled.ts` | `loadConfig` → `resolveAccrualRate` (계층 해석) 로 **교체** |
| `functions/src/setQoinAccrualRate.ts` | **신규** (onCall) — 단일 범위 설정 + 이력 |
| `functions/src/applyBrandQoinRate.ts` | **신규** (onCall) — 브랜드 일괄 적용 + 이력 1건 |
| `functions/src/onQoinConfigWritten.ts` | **신규** (onDocumentWritten `config/qoin`) — out-of-band 편집 감시 |
| `functions/src/qoinRate.ts` | **신규** — 경계 상수 + 계층 해석 순수 함수 (CF 3개가 공유) |
| `functions/src/index.ts` | export 3줄 추가 |
| `firestore.indexes.json` | **미정 — developer 실측 확정** (§7.5) |

### 3.2 Flutter

| 레이어 | 변경 |
|---|---|
| core | `qoin_policy.dart` **확장** (명시적 0% 센티넬, 계층 해석 순수 함수, 범위 라벨) |
| domain | 엔티티 신규 3 (`QoinRateScope`, `EffectiveQoinRate`, `QoinRateChangeEntity`), `StoreEntity`/`BrandEntity` 필드 1개씩 추가, Repository 신규 1 + 1차 `QoinConfigAdminRepository` **쓰기 메서드 교체**, UseCase 신규 5 |
| data | 모델 매퍼 신규 1 + `StoreModel`/`BrandModel` 필드 추가, 데이터소스 신규 1 (CF callable + 이력 조회) |
| presentation | admin 화면 4 (허브/브랜드/매장/이력), 1차 전역 화면 **분해**, owner/brand 읽기 전용 행 추가, 고객 문구 1곳 수정 |

### 3.3 문서 (설계자 후속)

`docs/backlog.md`(H1~H7 절 완료 처리 + 2차 N1~N8 이관), `docs/processes/data_ownership.md`(§2.5/2.7/§3 갱신), `docs/processes/audit_trail.md`(§3 A1 해소), `docs/processes/role_flows.md`(§4.2/4.3/4.4 액션 추가).

---

## 4. 결정사항 — 선택지와 추천안

### ① 저장 위치 → **`stores/{id}` / `brands/{id}` 의 필드** (추천)

| 안 | 내용 | CF read | H6 조회 | 판단 |
|---|---|---|---|---|
| **A (추천)** | `stores/{id}.qoinAccrualRate`, `brands/{id}.qoinAccrualRate` 필드 | 적립당 +1~2 | 기존 `read: isSignedIn()` 로 **공짜** | **채택** |
| B | 별도 컬렉션 `qoinRates/{storeId}` / `{brandId}` | 동일 (+1~2) | 새 Rules 블록 필요. 매장 목록 화면이 **매장 목록 + 적립률 목록** 2중 조회 | 이득 없음 |
| C | `config/qoinRates` 단일 문서에 map (`stores: {id: rate}`) | **+0** (문서 1개) · 일괄 적용이 **1 write 로 원자적** | map 전체가 한 문서 → 점주가 **남의 매장 적립률까지 읽는다**. admin only 로 막으면 H6 의 점주/브랜드 읽기를 위해 미러 필드가 또 필요 | 기각 |

**A 채택 근거**
- read 증가분은 적립 1건당 +1~2. Firestore read 는 10만당 $0.03 수준이고, 주문 1건은 이미 `onOrderCreated` / `onOrderStatusChanged` / `onOrderQoinSettled` 가 동시에 도는 비용 구조다. 이 증가는 **의미 있는 비용이 아니다** (지연은 §7.2 의 `getAll` 로 1 라운드트립 유지).
- C 의 "read 0 증가 + 원자적 일괄" 은 매력적이지만, **적립률은 가맹점의 비용 조건**이다. 한 문서에 전 매장 값을 모으면 `isSignedIn()` 수준의 읽기에서 경쟁 매장의 비용 조건이 노출되거나, 막으면 H6 을 위해 미러를 또 만들어야 한다. 소유권 경계(`data_ownership.md` §2.5/2.7)와 어긋나는 쪽은 택하지 않는다.
- §1.3 실측대로 `stores`/`brands` 쓰기는 명시 필드 `update` 라 새 필드가 지워지지 않는다.
- C 가 해결해 주던 "일괄 적용 원자성" 은 §7.3 에서 **다른 방식으로** 해결한다(브랜드 값 쓰기가 1 write 이고, 개별 초기화는 실패해도 이전 상태가 남는 설계).

### ② CF 해석 비용 → **투기적 `getAll` 1 라운드트립** (추천)

§1.6 의 카운트 기준으로:

| 안 | read | 라운드트립 | 판단 |
|---|---|---|---|
| 순차 (store 읽고 없으면 brand) | 2~3 | **2~3** | 지연 최악 |
| ~~투기적 `getAll([config, store, brand?])`~~ | 2~3 | ~~1~~ | ⚠️ **철회 (§19.1).** `order.brandId` 가 항상 null 이라 전제가 무효. **순차 2단**(`getAll([config, store])` → `brands/{store.brandId}`)으로 바꾼다. 총 라운드트립은 **현행과 같은 2**이고 비브랜드 매장은 1로 줄어든다 |
| order 문서에 적립률 비정규화 | 1 | 1 | **기각** — 주문 생성 시점과 픽업 완료 시점이 다르다. 생성 시점 값을 박제하면 "오늘부터 5%" 가 어제 주문에 적용되지 않는 건 맞지만, 반대로 **며칠 전 주문이 옛 적립률로 적립**된다. 1차가 `* → completed` 를 트리거로 고른 설계와 충돌 |
| 캐시 (CF 인스턴스 메모리) | 평균 감소 | 1 | **기각** — 적립률 변경이 즉시 반영되지 않는다. 돈 값에 stale 캐시는 쓰지 않는다 |

부가 절감: **회수(clawback) 경로는 계층을 읽지 않는다** (회수액은 원장 반전). 적립률 조회를 `kind === "earn"` 분기 안으로 옮겨 회수 시 read 를 늘리지 않는다 — 현재 코드는 `loadConfig` 를 분기 **앞**에서 호출하므로 이 이동이 필요하다. 단, 전역 `enabled` kill switch 판정은 **회수에도 유지**해야 하므로 `config/qoin` 읽기는 공통 위치에 남긴다 (1차 §5.5 불변).

### ③ "설정 없음" 의 표현 → **필드 부재 = 상속 / `0` = 명시적 중단** (추천) — ⚠️ **§20 에서 정정됨**

> **정정**: `0` = 명시적 중단은 **폐기**됐다. "적립을 하냐" 는 별도 필드 `qoinAccrualEnabled` 로 분리되고 **`0` 은 적립률 값으로 금지**된다. 이 소절이 별도 bool 안을 기각한 근거("두 필드의 정합성")도 틀렸다 — 근거와 교체 설계는 **§20.1 · §20.2** 를 따른다.

| 안 | 상속 표현 | 명시적 0% | 판단 |
|---|---|---|---|
| **추천** | **필드 부재** (`FieldValue.delete()`) | **`qoinAccrualRate: 0`** | 단일 필드·단일 출처. 유효 범위가 `0.001~0.2` 라 `0` 은 입력으로 도달 불가능해 센티넬로 안전하다 |
| `null` | `qoinAccrualRate: null` | `0` | 부재와 null 두 상태가 같은 뜻 → 매퍼·CF 양쪽에 분기 2개. 기각 |
| `-1` | `-1` | `0` | 음수 센티넬은 "유효 범위 밖이면 fail-closed" 규칙과 충돌(로그가 invalid 로 오염됨). 기각 |
| 별도 bool | 부재 | `qoinAccrualEnabled: false` | 두 필드의 정합성을 항상 맞춰야 한다 (`rate` 있는데 `enabled:false` 같은 모순 상태). 기각 |

**"상위 상속" 과 "명시적 0%" 의 구분**: 위 표의 부재 vs `0`. 화면에는 셋을 **다른 표기**로 보여준다 — `브랜드 상속 (3%)` / `전역 기본 (3%)` / `적립 안 함 (0%)` / `5%`.

**매장 단위 적립 중단 수단은 필요하다** (판단: 필요). 근거 — 가맹점이 비용을 부담하므로(H1) "이 매장만 당분간 적립 제외" 는 운영상 반드시 생긴다. 1차의 `enabled` 토글은 **전역 비상 정지**이므로 대체물이 못 된다.

> **설계 함정 (반드시 지킨다)**: 매장/브랜드의 `0` 은 **적립만** 막는다. **회수는 계속 동작해야 한다.** 그렇지 않으면 "매장을 0% 로 바꾸면 과거 적립분이 환불돼도 회수되지 않는다" → Qoin 이 누수된다. 전역 `enabled=false` 만 적립·회수를 **둘 다** 멈춘다 (1차 §5.5 유지). 입력은 **전용 토글**로만 하고 퍼센트 입력란으로는 `0` 을 쓸 수 없게 한다 (100배 오입력 방어선 보존).

### ④ 일괄 적용의 원자성 → **CF + "브랜드 값 먼저, 개별 초기화는 재개 가능" ** (추천)

클라이언트 batch 는 **기각**: 500 한도, 권한 재검증 불가, 이력 위조 가능 (`data_ownership.md` §3 의 "A 가 쓴 문서로 B 소유 문서를 갱신하면 CF").

CF `applyBrandQoinRate` 의 순서:

1. **이력 문서 선기록** (`status: 'in_progress'`, 입력값·모드·예상 대상 수)
2. **브랜드 값 1 write** — 이 1 write 로 "개별 설정이 없는 매장 전체" 의 유효 적립률이 **원자적으로** 바뀐다. `mode: 'preserve'` 는 **여기서 끝** → 원자성 문제 자체가 없다
3. `mode: 'overwrite'` 만: 산하 매장의 개별 설정을 **≤450건 청크 batch** 로 `FieldValue.delete()` (chunk 간 순차, 각 chunk 는 원자)
4. 이력 문서를 `status: 'completed'` + 실제 `affectedCount` 로 마감. 중단 시 `status: 'partial'` + `processedCount`

**부분 실패가 안전한 이유**: 3단계는 "개별 설정을 지우는" 작업이다. 일부만 지워지면 나머지 매장은 **지우기 전의 자기 값**(= 기존 상태)을 유지한다. 중간 상태가 만들어지지 않는다. 또한 "이미 지워진 필드를 또 지우기" 는 no-op 이므로 **재실행이 멱등**하다 → 관리자 화면에 `이어서 적용` 을 제공한다 (`status: 'partial'` 이력 기반).

**순서가 2 → 3 인 이유**: 역순이면 개별 설정이 지워진 매장이 잠깐 **옛 브랜드 값 또는 전역 기본값**으로 떨어진다. 그 순간 픽업 완료되는 주문이 의도하지 않은 적립률을 받는다. 브랜드 값을 먼저 쓰면 어떤 매장도 의도 밖의 값을 거치지 않는다.

**영향 매장 수**: 확인 다이얼로그는 클라이언트의 `watchStoresByBrand` 로 미리보기 숫자를 보여주되, **이력에 남는 수는 CF 가 실제로 처리한 수**다 (클라이언트 숫자를 믿지 않는다).

### ⑤ 변경 이력의 위치와 스키마 → **대상 문서의 서브컬렉션 `qoinRateHistory`** (추천)

| 안 | 조회(H6) Rules | 판단 |
|---|---|---|
| 최상위 `qoinRateHistory/{id}` | 점주 읽기 허용을 위해 Rules 안에서 `get(stores/...)` 가 doc 마다 필요 → **get 호출 한도·비용 위험** | 기각 |
| **대상 서브컬렉션** (추천) | `stores/{id}/qoinRateHistory` → `isStoreOwner(storeId)` 로 **기존 헬퍼 그대로**. `brands/{id}/...` → `isBrandHolder(brandId)`. admin 전체는 `collectionGroup('qoinRateHistory')` | **채택** |
| 대상 문서 안의 배열 필드 | 1MB·무한 증가·동시 쓰기 충돌 | 기각 |

경로 (이름을 **세 범위 모두 동일**하게 둬야 collection group 조회가 된다):

```
config/qoin/qoinRateHistory/{autoId}      ← 전역
brands/{brandId}/qoinRateHistory/{autoId} ← 브랜드 (일괄 적용도 여기 1건)
stores/{storeId}/qoinRateHistory/{autoId} ← 매장
```

**쓰기 주체는 CF 전담** (`audit_trail.md` §4 "쓰기 주체는 Cloud Function 이 기본"). Rules 는 create/update/delete 전부 `if false` — **1차 원장(`qoinTransactions`)과 같은 패턴, admin 도 쓰기 불가.**

### ⑥ 관리자 화면 구조 → **허브 1 + 범위별 3** (추천)

한 화면에 전역·브랜드·매장을 모두 넣으면 (ⓐ) 매장 수가 많을 때 목록이 화면을 지배하고 (ⓑ) **"지금 내가 어느 범위를 바꾸는 중인지" 가 흐려진다** — 100배 오입력보다 위험한 건 **범위 오입력**(한 매장에 주려던 10% 를 전역에 주는 것)이다. 범위를 화면으로 분리해 그 사고를 구조적으로 막는다. 상세는 §12.2.

**100배 방어는 공용 위젯 1개로 전 범위 공유**한다 (§10) — 화면이 3개여도 검증 코드는 1개여야 드리프트가 안 생긴다.

### ⑦ 점주·브랜드 읽기 화면 → **기존 화면에 1행 추가** (추천)

새 화면을 만들지 않는다. 자기 비용은 **이미 보고 있는 화면**에 있어야 한다.

| 역할 | 위치 | 내용 |
|---|---|---|
| 점주 | `my_store_page.dart` 의 `_StoreInfoSection` 에 `Qoin 적립률` 행 | `3% (브랜드 상속)` + "적립 비용은 매장 부담이며 변경은 관리자 문의" 안내. 탭하면 **자기 매장 이력** |
| 브랜드 | `brand_info_page.dart` 에 동일 행 (자기 브랜드 값) | 탭하면 자기 브랜드 이력 |
| 브랜드 | `brand_stores_page.dart` 각 매장 타일에 유효 적립률 배지 | 가맹점별로 다른 값을 한눈에 |

편집 어피던스(입력란·버튼)를 **두지 않는다**. H2 가 읽기 전용이므로 비활성 입력란도 두지 않는다 (요청할 수 있다는 오해 방지).

### ⑧ 1차 자산의 처리

| 자산 | 처분 | 상세 |
|---|---|---|
| `config/qoin.accrualRate` | **재사용** | 의미만 "전역 기본값" 으로 명확화. 마이그레이션·백필 **불필요** |
| `config/qoin.enabled` | **재사용** | 전역 비상 정지. 적립·회수 **둘 다** 중단 (1차 §5.5 불변) |
| `qoin_policy.dart` 경계 검증 | **재사용 + 확장** | `validateRateInput` / 하한 1 / 상한 200 / 인상 경고 / tenths 환산 그대로. 추가: 명시적 0% 센티넬 상수, `resolveEffectiveRate` 순수 함수, 범위 라벨 |
| `admin_qoin_settings_page.dart` | **분해 후 재사용** (전면 폐기 아님) | 적립률 입력 카드 · 확인 다이얼로그 · 전역 kill switch 카드 · 로드 에러 뷰를 **공용 위젯으로 추출**해 3개 범위가 공유. 페이지 자체는 계층 허브로 교체 |
| `QoinConfigAdminRepository.saveAccrualRate` | **폐기 → CF 호출로 교체** | 클라이언트 직접 쓰기는 이력을 못 남긴다(H7) |
| `QoinConfigAdminRepository.setEnabled` | **재사용 (직접 쓰기 유지)** | §4-⑩ 참조 |
| `QoinConfigEntity` / `QoinConfigModel` | **재사용** | 전역 기본값 표현. 필드 추가 없음 |
| `onOrderQoinSettled.loadConfig` | **확장** | `resolveAccrualRate` 로 교체. `MIN_RATE`/`MAX_RATE` 는 `qoinRate.ts` 로 이동해 신규 CF 2개와 공유 |
| 원장 스키마 | **재사용 + 1필드 추가** | `accrualRateSource` (§5.3) |
| 멱등 · 잔액 · 회수 · 고객 화면 | **변경 없음** | |

### ⑨ 고객 문구 — 계층화가 만드는 **틀린 숫자** (설계자 발견, 1차 범위에 포함)

`qoin_balance_card.dart` L230 이 고객 Qoin 화면에 `픽업 완료 시 결제액의 3% 적립` 을 **전역 값으로** 표시한다. 매장별 값이 생기면 이 문구는 **매장에 따라 거짓**이 된다.

**추천**: 1차에서는 범위 무관 문구로 교체 — `픽업 완료 시 결제액의 일부가 적립돼요 (적립률은 매장마다 달라요)`. 매장별 숫자 표시는 N2(2차). `적립 중단` 분기(`_paused`)는 **전역 `enabled`/전역 기본값 기준 그대로 유지**한다.
원장 기반 **과거 내역 문구는 손대지 않는다** (당시 값 박제 — `audit_trail.md` §4.3).

### ⑩ `enabled` 토글의 이력 — **남긴다. 단 직접 쓰기는 유지** (⚠️ 행위자 미기록 부분은 **§19.3 에서 정정**)

`audit_trail.md` §4.1 기준 "돈·권한·정책 값" 이고, 1차 test_report §9 도 "비상 정지는 책임 추적 가치가 가장 크다" 고 지적했다. **남긴다.**

다만 토글을 CF 호출로 바꾸면 **CF 장애 시 비상 정지가 불가능**해진다. 비상 정지는 가장 단순한 경로로 남아야 한다.
→ **토글은 지금처럼 클라이언트 직접 쓰기 유지**, 이력은 §7.4 의 `onQoinConfigWritten` 트리거가 남긴다 (`changedBy` 는 트리거로 알 수 없으므로 `changedBy: null` + `source: 'direct'`, 시각·before·after 는 확실히 남는다). 행위자까지 남기려면 토글 직후 클라이언트가 CF 에 `reason`/actor 를 보고하는 경로가 필요한데, 비상 정지의 단순성을 깨므로 택하지 않는다 — **이 타협은 의도된 것이며 §13 체크 4 에 명시한다.**

---

## 5. 데이터 모델

### 5.1 적립률 필드  ⚠️ **§20.1.1 로 교체됨** (`0` 폐기 + `qoinAccrualEnabled` 추가)

```
config/qoin
  accrualRate : number   0.001~0.2        ← 전역 기본값 (필수. 부재 = fail-closed)
  enabled     : boolean                   ← 전역 비상 정지 (적립·회수 모두)

brands/{brandId}
  qoinAccrualRate : number  0.001~0.2 | 0 ← 부재 = 전역 상속, 0 = 이 브랜드 적립 안 함

stores/{storeId}
  qoinAccrualRate : number  0.001~0.2 | 0 ← 부재 = 상위 상속, 0 = 이 매장 적립 안 함
```

- 단위는 1차와 같은 **비율 double** (tenths 가 아니다). 1차에서 `tenths 1..200` 전부 `round(rate*1000) == tenths` 왕복 일치가 실측 확인됐고(test_report ①), 원장의 `accrualRate` 와 단위가 같아야 박제값이 일관된다.
- 입력·표시는 `QoinPolicy` 의 tenths 경로를 그대로 쓴다. **저장 직전에만** `rateFromTenths` 로 변환.
- 유효 범위를 벗어난 값(비number/NaN/음수/0 초과 0.001 미만/0.2 초과)은 **그 범위의 설정이 없는 것으로 보지 않고 fail-closed** — §6 참조.

### 5.2 변경 이력 (H7)  ⚠️ **§20.5.2 · §20.5.5 로 갱신됨** (`field` 3값 / `clearedZeroCount` 삭제 / `disabledUntouchedCount` 추가)

```
{config/qoin | brands/{id} | stores/{id}}/qoinRateHistory/{autoId}

  scope          'global' | 'brand' | 'store'
  targetId       'qoin' | brandId | storeId
  field          'accrualRate' | 'enabled'          ← ⑩ 때문에 두 종류가 한 컬렉션에 들어온다
  before         number | boolean | null            ← null = 설정 없음(상속) 이었다
  after          number | boolean | null            ← null = 상속으로 되돌림
  changedBy      uid | null                         ← null = out-of-band (Console) 편집
  changedByRole  'admin' | null
  changedAt      serverTimestamp
  reason         string | null                      ← 선택 (최대 200자)
  source         'callable' | 'bulk' | 'direct'
  op             'set' | 'clear' | 'bulkApply'

  // op == 'bulkApply' 일 때만
  bulkMode       'preserve' | 'overwrite'
  affectedCount  number        ← CF 가 실제 처리한 매장 수
  clearedCount   number        ← overwrite 로 초기화된 개별 설정 수
  status         'in_progress' | 'completed' | 'partial'
  processedCount number        ← 재개용
```

`audit_trail.md` §4 의 권장 형식(`changedBy / changedAt / scope / targetId / before / after / reason / affected`)을 **전건 충족**하고, H7 의 "일괄은 1건 + 영향 매장 수 + 덮어쓰기 여부" 를 `op/bulkMode/affectedCount/clearedCount` 로 담는다.

### 5.3 원장 1필드 추가 — `accrualRateSource`

```
users/{uid}/qoinTransactions/{txId}
  accrualRate       : number                        ← 기존 (당시 적립률 박제)
  accrualRateSource : 'store' | 'brand' | 'global'  ← 신규
```

**지금 넣는 이유**: 1차 F2(원장에 `brandId` 누락)와 **완전히 같은 함정**이다. 나중에 추가하면 과거 원장에 값이 없어 소급 집계가 불가능하다. H1 이 비용 부담을 브랜드/매장으로 확정했으므로 정산(N1)에서 "이 적립이 누구 정책 때문에 발생했는지" 가 반드시 필요해진다. clawback 은 earn 문서에서 상속한다 (기존 `brandId` 와 동일 패턴).

---

## 6. 계층 해석 알고리즘 (H3)  ⚠️ **§20.3.1 로 교체됨** (스위치 2셀 추가 / 진리표는 §20.2.3)

**CF(TS)와 클라이언트(Dart)가 동일한 규칙을 구현한다.** 함수는 순수 함수로 각 1개만 둔다.

```
resolveEffectiveRate(storeRate, brandRate, globalRate) -> (rate, source) | INVALID

  // 각 입력은 '부재' / '유효(0.001~0.2)' / '명시적 0' / '무효' 중 하나
  if storeRate is 명시적 0            -> (0,          'store')     // 적립 안 함
  if storeRate is 유효                -> (storeRate,  'store')
  if storeRate is 무효                -> INVALID                  // fail-closed
  if brandRate is 명시적 0            -> (0,          'brand')
  if brandRate is 유효                -> (brandRate,  'brand')
  if brandRate is 무효                -> INVALID
  if globalRate is 유효               -> (globalRate, 'global')
  return INVALID                                                  // 전역 기본값 부재/무효
```

진리표 (설계 확정 — CF 와 Dart 의 단위 테스트가 **이 표를 그대로** 케이스로 쓴다)

| store | brand | global | 결과 | source |
|---|---|---|---|---|
| 부재 | 부재 | 0.03 | 0.03 | global |
| 부재 | 0.05 | 0.03 | 0.05 | brand |
| 0.10 | 0.05 | 0.03 | 0.10 | store |
| **0** | 0.05 | 0.03 | **적립 없음** | store |
| 부재 | **0** | 0.03 | **적립 없음** | brand |
| 0.10 | **0** | 0.03 | 0.10 | store |
| 부재 | 부재 | 부재 | **INVALID** (적립 중단) | — |
| 0.5 (범위 초과) | 0.05 | 0.03 | **INVALID** — 상위로 폴백하지 않는다 | — |
| 부재 | 0.5 | 0.03 | **INVALID** | — |
| 부재 | 부재 | 0.5 | **INVALID** | — |

**무효 값이 상위로 폴백하지 않는 이유**: 폴백하면 "매장 값이 깨진 것" 이 조용히 덮여 **아무도 모르게 다른 금액이 발행**된다. 1차의 fail-closed 원칙(§5.5)과 F3 의 교훈이 같은 방향을 가리킨다 — 돈 값이 이상하면 **멈추고 로그를 남긴다.**

브랜드 미소속 매장(`brandId == null`): brand 단계를 건너뛰고 global 로 간다.

---

## 7. Cloud Function 설계

### 7.1 쓰기를 CF 로 넘기는 이유 (`data_ownership.md` §3 판단)

- 이력을 클라이언트가 쓰면 **위조·누락**이 가능하다 (`audit_trail.md` §4).
- 일괄 적용은 다중 문서 batch + 권한 재검증 (`data_ownership.md` §3 "다중 collection batch + 권한 재검증 → CF").
- 적립률은 **발행되는 돈의 계수**다. 1차가 원장·잔액을 CF 전담으로 둔 것과 같은 급.

### 7.2 `onOrderQoinSettled` 수정 (교체 범위 최소)

```
1) before/after, status 전이 판정                    (현행 유지)
2) config/qoin 읽기 → enabled 판정                   (현행 유지. 회수에도 적용)
3) kind === 'clawback'  -> 적립률을 읽지 않고 현행 로직 그대로
4) kind === 'earn'
   # ⚠️ §19.1 에서 정정: 브랜드는 after.brandId 가 아니라 store.brandId 에서 얻는다
   getAll([config/qoin, stores/{after.storeId}])      ← 1 라운드트립
   brandId = storeSnap.get('brandId')                 ← 유일한 신뢰원 (order 값은 쓰지 않는다)
   if brandId: get(brands/{brandId})                  ← 2번째 라운드트립 (수용, §19.1)
   resolveAccrualRate(...)  → INVALID 이면
        console.error('skipped_invalid_rate', {scope, storeId, brandId, values})  후 return
   rate === 0 이면
        console.info('skipped_rate_zero', {source, storeId})  후 return   ← 적립만 중단
   amount = computeEarnAmount(total, rate)           (현행 ppm 정수 산식 유지)
   원장 fields 에 accrualRate, accrualRateSource 기록 (나머지 현행 유지)
```

- `config/qoin` 읽기는 **분기 앞에 유지**(전역 kill switch 가 회수에도 걸리므로), **계층 읽기만** earn 분기 안으로 넣는다 → 회수 경로 read 증가 0 (§1.6).
- 매장 문서가 없으면(`!snap.exists`) 매장 설정 부재로 보고 상위로 간다. 단 `storeId` 자체가 빈 문자열이면 `skipped_invalid_store` 로 **중단** (조용한 빈 값 방지 — 1차 보류 H3 과 같은 맥락).
- `retry: true` / 멱등 가드 / 트랜잭션 / 잔액 갱신은 **손대지 않는다.**
- 로그 라벨을 범위별로 분리해 "어느 범위 때문에 멈췄는지" 가 로그만으로 판별되게 한다.

### 7.3 `setQoinAccrualRate` (onCall) / `applyBrandQoinRate` (onCall)

공통: region `asia-northeast3`, `request.auth` 필수, **`users/{uid}.role === 'admin'` 서버 재검증**(H2 — 클라이언트 역할을 믿지 않는다), 입력 검증은 §10 의 공유 경계.

`setQoinAccrualRate({ scope, targetId, rate | 'clear' | 0, reason? })`
1. admin 검증 → 2. 입력 경계 검증 (0 또는 0.001~0.2, `clear` 는 필드 삭제) → 3. 대상 문서 존재 확인 → 4. **트랜잭션**: 현재 값 읽어 `before` 확보 → 값 쓰기 + 이력 1건 생성 (같은 트랜잭션 → 이력 없는 변경이 **구조적으로 불가능**) → 5. `{ before, after, historyId }` 반환
- `scope: 'global'` 은 `config/qoin.accrualRate` 1필드만 쓴다 (`enabled` 불변 — 1차 ⑥ "비상 정지 분리" 유지).

`applyBrandQoinRate({ brandId, rate | 'clear' | 0, mode: 'preserve'|'overwrite', reason?, resumeHistoryId? })`
→ §4-④ 의 1~4 단계. `resumeHistoryId` 로 `partial` 재개. 반환: `{ affectedCount, clearedCount, status }`.
- 2단계(브랜드 값 쓰기)와 1단계(이력 선기록)는 **한 트랜잭션**. 3단계는 청크 batch.
- 산하 매장 조회: `stores where brandId == brandId` (Admin SDK). 매장 수가 많을 때를 대비해 **커서 페이징**으로 읽고 청크마다 `processedCount` 를 갱신한다.

### 7.4 `onQoinConfigWritten` (onDocumentWritten `config/qoin`) — out-of-band 감시

Firebase Console / Admin SDK 쓰기는 **Rules 를 우회한다**(§1.2). 전역 적립률·kill switch 가 콘솔에서 바뀌면 callable 경로를 아무리 막아도 이력이 비는데, 운영상 콘솔 편집은 실제로 쓰인다(1차 배포 절차가 그랬다).

- `accrualRate` 또는 `enabled` 가 바뀐 경우만 처리, 그 외 early return.
- **직전 callable 이 만든 이력이 있으면 중복 기록하지 않는다**: callable 이 쓴 이력에 `source: 'callable'` 과 `after` 가 있으므로, 트리거는 최신 이력 1건을 읽어 `after` 가 일치하면 skip, 불일치면 `source: 'direct'` / `changedBy: null` 로 1건 기록.
- `config/qoin` **단일 문서** 트리거라 호출 빈도가 사실상 운영자 행위 수준 — 비용 무시 가능.
- `stores`/`brands` 필드의 동일 감시는 **N6(2차)**. 매장 문서는 쓰기가 잦아(영업 토글 등) 트리거 비용·노이즈 판단이 필요하다. **이 한계를 §13 체크 6 에 명시한다.**

### 7.5 인덱스 — developer 실측 확정

필요 쿼리: ⓐ `stores where brandId == X` (1차 이전부터 쓰이는 기존 쿼리) ⓑ 대상별 이력 `orderBy changedAt desc limit N` ⓒ admin 전체 이력 `collectionGroup('qoinRateHistory') orderBy changedAt desc limit N`.

ⓒ 의 collection-group 단일 필드 정렬이 자동 인덱스로 커버되는지 **단정하지 않는다**. 1차 §7.3 과 같은 방식으로 developer 가 실측해 `firestore.indexes.json` 반영 여부를 확정한다. 에뮬레이터는 인덱스를 강제하지 않으므로 **에뮬레이터 통과는 근거가 아니다** (1차 test_report ⑧ 의 교훈).

---

## 8. Firestore Rules 변경

| 경로 | 변경 | 내용 |
|---|---|---|
| `config/{docId}` | **수정** | `accrualRate` 변경은 거부, `enabled` 는 admin 허용 (⑩). `allow write` 를 `create/update` 로 분리하고 `affectedKeys().hasAny(['accrualRate'])` 차단. **`config/qoin` 생성(create) 경로도 같이 막는다 — F1 의 교훈** |
| `stores/{storeId}` | **수정** | update 3분기 **전부**(admin 전권 분기 포함) 에 `!affectedKeys.hasAny(['qoinAccrualRate'])`. **create 경로**(`allow create: if isOwner() ...`)에도 `!('qoinAccrualRate' in request.resource.data)` — F1 과 동일 패턴의 구멍 |
| `brands/{brandId}` | **수정** | 동일 (update 2분기 + create 2분기 모두) |
| `{config,brands,stores}/.../qoinRateHistory/{id}` | **신규** | `read`: 전역=admin / 브랜드=`isAdmin() OR isBrandHolder(brandId)` / 매장=`isAdmin() OR isStoreOwner(storeId) OR isBrandHolder(store.brandId)`. `create/update/delete`: **전부 `if false`** (admin 도 불가 — 1차 원장과 같은 패턴) |
| `match /{path=**}/qoinRateHistory/{id}` | **신규** | collection group 조회용. `read: if isAdmin()` 만 (admin 전체 조회). 쓰기 없음 |

**기존 블록을 수정한다** — 1차의 "기존 블록 비수정" 원칙의 예외다. 근거: F1 이 바로 "쓰기 경로 하나를 안 건드려서" 생긴 구멍이었고, 적립률을 CF 전담으로 만들려면 기존 분기를 좁히는 수밖에 없다. developer 는 변경 후 **기존 Rules 하네스 73건 전건 PASS 를 회귀로 확인**한다.

> `stores`/`brands` 의 brand/owner 분기는 `onlyChangedFields` 화이트리스트라 새 필드가 이미 차단된다(§1.2). 그래도 **명시적으로 추가**한다 — 나중에 누가 화이트리스트에 필드를 보탤 때 방어선이 보이게.

---

## 9. 보안 · 적립률 쓰기 경로 전수 (F1 재발 방지)  ⚠️ **§20.5.6 에서 20경로로 재정정**

설계 후 `qoinAccrualRate` / `config/qoin.accrualRate` 에 **쓸 수 있는 모든 경로**:

> ⚠️ **12경로는 전수가 아니었다 (tester F4 / §19.4).** 13번째 경로가 있다 — 점주가 자기 매장을 `delete` 한 뒤 같은 ID 로 재생성하면 개별 설정이 **제거**된다. `status: 'pending'` 재승인이 필요하므로 **수용**하고 하네스로 동작을 고정한다. 아래 표의 "전수" 는 ⚠️ **§20.5.6 의 20경로**로 읽는다 (스위치 필드 추가분 7경로 포함).

| # | 경로 | 결과 | 검증 |
|---|---|---|---|
| 1 | customer/owner/brand 의 `stores` **update** | ❌ 화이트리스트 + 명시 차단 | Rules 하네스 |
| 2 | owner 의 `stores` **create** (신규 매장 등록) | ❌ `!('qoinAccrualRate' in ...)` | Rules 하네스 |
| 3 | brand 의 `stores` create (brand 경유 등록) | ❌ 동일 | Rules 하네스 |
| 4 | brand 의 `brands` update / create | ❌ 명시 차단 | Rules 하네스 |
| 5 | **admin 의 `stores`/`brands` update (전권 분기)** | ❌ 명시 차단 (전권에서 이 필드만 제외) | Rules 하네스 |
| 6 | **admin 의 `config/{docId}` write** | ❌ `accrualRate` 차단 / ✅ `enabled` 허용 | Rules 하네스 |
| 7 | admin 의 `config/qoin` **create** (문서가 없을 때) | ❌ `accrualRate` 포함 create 차단 | Rules 하네스 |
| 8 | `setQoinAccrualRate` CF | ✅ admin 서버 재검증 + 경계 검증 + 이력 동일 트랜잭션 | CF 에뮬레이터 |
| 9 | `applyBrandQoinRate` CF | ✅ 동일 + 멱등 재개 | CF 에뮬레이터 |
| 10 | `onOrderQoinSettled` | 적립률을 **읽기만** 한다 (쓰기 없음) | 코드 리뷰 |
| 11 | **Firebase Console / Admin SDK** | ⚠️ **Rules 로 막을 수 없다**. `config/qoin` 은 §7.4 트리거가 `source:'direct'` 로 기록. `stores`/`brands` 는 **감시 없음 → N6(2차)** | 설계 한계로 명시 |
| 12 | `qoinRateHistory` 직접 쓰기 (모든 역할) | ❌ 전부 `if false` | Rules 하네스 |

**11번이 유일한 미봉**이고, 그것이 Firebase 의 구조적 성질임을 명시한다. 1차 §4.4 가 admin 직접 쓰기를 "알려진 구멍, 수용" 으로 기록한 것과 같은 수준의 처리다.

---

## 10. 경계 검증의 이중화 (F3 재발 방지)

적립률 경계(`0.001~0.2` + 명시적 0)는 **네 곳**에 있고 값의 출처는 **한 곳씩** 이어야 한다.

| 위치 | 책임 | 상수 출처 |
|---|---|---|
| 관리자 화면 (전역/브랜드/매장 **3범위 공용 위젯 1개**) | 입력 UX, 100배 오입력 차단, 확인 다이얼로그 | `QoinPolicy` (Dart) |
| `SetQoinAccrualRateUseCase` | 화면 우회 방어 (`ArgumentError`) | `QoinPolicy` (Dart) |
| `setQoinAccrualRate` / `applyBrandQoinRate` CF | **서버 경계** — 호출자를 믿지 않는다 | `functions/src/qoinRate.ts` (TS) |
| `onOrderQoinSettled` | **발행 직전 경계** — 저장된 값을 믿지 않는다 (Console 편집 대비) | `functions/src/qoinRate.ts` (TS) |

Dart·TS 두 구현은 드리프트 위험이다. 완화책:
1. 경계 상수를 **각 언어에 1곳씩만** 두고 (`QoinPolicy` / `qoinRate.ts`) 어디서도 재선언하지 않는다.
2. §6 의 진리표와 경계 케이스 표를 **양쪽 단위 테스트가 동일 케이스로** 검증한다 (1차 test_report ①②가 쓴 방식).
3. spec 의 이 표를 tester 가 **grep 으로 직접 확인**한다 (상수 중복 선언 0건).

---

## 11. 레이어 설계 (Clean Architecture)

### 11.1 Core (`lib/core/utils/qoin_policy.dart` 확장)

- 기존 전부 유지. 추가: `explicitOffRate = 0`(센티넬 상수), `isValidRate(double)`, `resolveEffectiveRate({storeRate, brandRate, globalRate})` → `EffectiveQoinRate`, 범위 라벨(`전역 기본 / 브랜드 상속 / 매장 설정 / 적립 안 함`).
- Firebase / Flutter 비의존 유지.

### 11.2 Domain (순수 Dart, Firebase import 금지)

- 엔티티: `QoinRateScope` (enum), `EffectiveQoinRate` (rate + source + 각 단계 원본값 — 화면이 "어디서 왔는지" 를 보여주려면 원본이 필요), `QoinRateChangeEntity` (§5.2 매핑).
- 기존 엔티티 필드 추가: `StoreEntity.qoinAccrualRate` (`double?`), `BrandEntity.qoinAccrualRate` (`double?`).
- Repository (추상): `QoinRateRepository`
  - 쓰기: `setRate(scope, targetId, rate?/clear, reason?)`, `applyBrandRate(brandId, rate?/clear, mode, reason?, resumeHistoryId?)` — **구현은 CF 호출**
  - 읽기: `watchHistory(scope, targetId, limit)`, `watchAllHistoryForAdmin(limit)`
- 1차 `QoinConfigAdminRepository`: `saveAccrualRate` **제거**, `setEnabled` **유지**.
- UseCase: `SetQoinAccrualRateUseCase`, `ApplyBrandQoinRateUseCase`, `WatchQoinRateHistoryUseCase`, `WatchAllQoinRateHistoryUseCase`, `WatchEffectiveQoinRateUseCase` (store/brand/global 3스트림 결합 → `EffectiveQoinRate`).

### 11.3 Data

- `QoinRateRemoteDataSource` **신규** — `FirebaseFunctions` callable 2개 + 이력 쿼리. **Firebase 직접 사용은 여기까지.**
- `QoinRateChangeModel` **신규** 매퍼 — 알 수 없는 `scope`/`op` 는 **null 반환, 폴백 금지** (1차 `QoinTransactionType.fromCode` 와 같은 정책).
- `StoreModel` / `BrandModel`: `qoinAccrualRate` 읽기 추가. **쓰기 맵(`toFirestoreFor*`)에는 절대 넣지 않는다** — 넣으면 점주의 매장 수정이 적립률을 덮어쓴다 (1차 `UserModel.toFirestoreForCreate` 에서 `qoinBalance` 를 뺀 것과 같은 판단).
- `QoinRepositoryImpl`: `saveAccrualRate` 삭제, `setEnabled` 유지.

### 11.4 Presentation

§12. `presentation` / `domain` 에서 Firebase import 0건, 색상은 `AppColors` 만, 신규 색 토큰 0 (1차와 동일 기준).
1차 test_report ⑩ 의 지적(`admin` 이 `presentation/customer/qoin/providers/*` 를 import) 을 이번에 정리한다 — `config` 읽기 provider 를 공용 위치로 이동.

---

## 12. 화면 구조

### 12.1 디자이너 호출 필요 여부 → **필요**

새 화면 4개 + 범위 배지/출처 표기 체계 + 일괄 적용 확인 플로우(H5) + 점주·브랜드 읽기 전용 행. 1차의 밝은 캔버스 + 미드나잇 네이비 컨셉과 Qoin 1차 화면의 톤을 이어야 한다.

### 12.2 관리자 (4화면)

| 화면 | 내용 |
|---|---|
| `AdminQoinSettingsPage` (**교체**) | 허브. ⓐ 전역 카드(적립률 + 1차 kill switch 스위치 — **추출한 위젯 재사용**) ⓑ `브랜드별 적립률` 진입 ⓒ `매장별 적립률` 진입 ⓓ `변경 이력` 진입 |
| `AdminQoinBrandRatesPage` | 브랜드 목록(`watchAll`) + 각 브랜드의 설정값/상속 표기 + 설정 + **`하위 매장 일괄 적용`** |
| `AdminQoinStoreRatesPage` | 매장 목록(`watchAllForAdmin`) + **검색 / 브랜드 필터 / 출처 필터** + 각 매장의 유효 적립률 + 출처 배지 + 설정 |
| `AdminQoinRateHistoryPage` | `collectionGroup` 이력 (최신순, 범위 필터). 각 행: 누가/언제/범위/대상/`before→after`/사유/일괄 메타. `partial` 행에는 **`이어서 적용`** |

**전 범위 공통 (1차 방어선 유지 — 타협 불가)**
- 퍼센트 입력 + `%` 접미사 고정 + 하한 0.1 / 상한 20 + 소수 1자리
- `0.03` 입력은 반드시 `tooLow` (하한 검사가 소수 자릿수 검사보다 **먼저**)
- 저장 전 **항상** 확인 다이얼로그: 범위·대상명 + `현재 → 변경` + 10,000원 환산 + 인상 경고(2배 이상 또는 10% 이상)
- **범위 오입력 방어**: 확인 다이얼로그 첫 줄에 범위와 대상명을 크게 (`전역 기본값` / `브랜드 ○○` / `매장 ○○`)
- 명시적 0% 는 입력란이 아니라 **전용 토글**(`이 매장은 적립하지 않음`)로만. 되돌리기는 `상위 설정 상속으로 되돌리기`
- 설정 사유(선택) 입력 1행 — 이력의 `reason`

**일괄 적용 플로우 (H4/H5)**
1. 적립률 또는 `상속으로 되돌리기` 선택
2. 모드 선택 — `개별 설정 보존` / `개별 설정 덮어쓰기`
3. `덮어쓰기` 선택 시 확인: `산하 매장 N곳 중 개별 설정이 있는 M곳의 설정이 초기화되고, 다시 설정해야 합니다` + 인상 경고 + 사유
4. 실행 → 결과(`affectedCount` / `clearedCount` / `status`). `partial` 이면 `이어서 적용` 노출

### 12.3 점주 / 브랜드 (읽기 전용)

§4-⑦. 추가로 `enabled=false`(전역 중단) 중이면 `현재 전체 적립이 중단되어 있어요` 를 함께 표기 — 자기 적립률이 5% 인데 적립이 안 되는 상황을 오해하지 않게.

### 12.4 고객

§4-⑨ 문구 1곳만. 과거 내역 문구는 불변.

---

## 13. 감사 추적 체크리스트 (`audit_trail.md` §4 — 6항목)  ⚠️ **§19.6 → §20.5.7 로 재판정됨**

| # | 체크 | 결과 |
|---|---|---|
| 1 | 돈·권한·정책 값을 바꾸는가 → 설정 변경 이력 | **통과.** §5.2 의 `qoinRateHistory` 가 전역/브랜드/매장 + `enabled` 까지 커버. H7 의 7항목(누가/언제/범위/이전→새 값/사유/일괄 묶음/영향 수·덮어쓰기 여부) 전건 매핑 |
| 2 | 덮어쓰기로 사라지는 값 | ⚠️ **FAIL (§19.2 에서 정정).** 원래 판정: **통과.** callable 이 **같은 트랜잭션**에서 `before` 를 읽어 이력에 남긴다 → 이력 없는 변경이 구조적으로 불가능. H5 의 "개별 설정 초기화" 도 `clearedCount` 로 남는다 → **이 부분이 오판정이다.** 일괄 덮어쓰기는 매장별 이전 값(3%/0%/무효)을 **어디에도** 남기지 않는다. §19.2 의 매장별 이력으로 고친다 |
| 3 | 기록이 정책 값을 참조만 하는가 → 당시 값 박제 | **통과.** 원장은 1차대로 `accrualRate` 박제 + §5.3 `accrualRateSource` **추가**. 계층이 바뀌어도 과거 내역은 불변 |
| 4 | "누가" 가 기록되는가 | ⚠️ **ⓐ FAIL (§19.3 에서 정정).** 원래 판정: **통과(한계 명시).** callable 경로는 `changedBy`=admin uid + `changedByRole`. **예외 2개**: ⓐ `enabled` 토글은 비상 정지 단순성을 위해 직접 쓰기를 유지하므로 `changedBy: null` / `source:'direct'` (§4-⑩ 의 의도된 타협) → **이 타협은 거짓 이분법이었다.** 직접 쓰기를 유지하면서 `enabledChangedBy` 를 Rules 로 강제하면 행위자가 남는다 (§19.3) ⓑ Console 편집은 행위자를 알 수 없다. **둘 다 before/after/시각은 남는다** |
| 5 | 일괄 처리 → 1건 + 영향 범위 | **통과.** `op:'bulkApply'` 1건에 `bulkMode / affectedCount / clearedCount / status / processedCount`. 수치는 **CF 가 실제 처리한 값** |
| 6 | CF 로그에 의존하지 않는가 | ⚠️ **ⓐ FAIL (§19.4 H-2 에서 정정).** 원래 판정: **통과(한계 명시).** 설정 변경은 Firestore 에 영구 기록. **남는 로그 의존 2건**: ⓐ 적립 시 `skipped_rate_zero` / `skipped_invalid_rate` 는 Cloud Logging 뿐 (1차 보류 H2 와 동종 — N8) → **`skipped_invalid_*` 는 고객 돈의 누락이므로 로그만으로는 §4-6 위반.** `qoinSettlementIssues` 로 Firestore 기록한다 (§19.4). `skipped_rate_zero` 는 의도된 정책이라 로그 유지 ⓑ `stores`/`brands` 의 Console 직접 편집 감시 없음 (N6) |

---

## 14. 역할 흐름 / 엔티티 lifecycle 영향

`docs/processes/role_flows.md` 확인 결과 — 끼어드는 지점:

| 역할 | 흐름 | 변화 |
|---|---|---|
| admin | §4.4 운영 액션 | `더보기 > Qoin 설정` 이 **단일 설정 → 계층 허브**. 액션 4개 추가(브랜드별/매장별 설정, 일괄 적용, 이력 조회) |
| owner | §4.2 내 매장 | `내 매장` 에 적립률 **읽기 전용** 행 + 이력 조회. 액션 추가 없음(H2) |
| brand | §4.3 브랜드 정보 / 가맹점 목록 | 동일하게 읽기 전용 행 2곳 |
| customer | 변화 없음 | 적립 결과만 바뀐다 (문구 §4-⑨) |

`docs/processes/entity_lifecycle.md` 확인 결과 — **status 전이는 바뀌지 않는다.**

- `order`: 전이 매트릭스 불변 (`* → completed` 적립 / `completed → refunded` 회수).
- `store` / `brand`: **적립률 변경이 `status` 를 pending 으로 회귀시키지 않는다.** 승인 플로우와 완전히 무관한 축이며, CF 가 `qoinAccrualRate` 1필드만 쓴다(`status`/`updatedAt` 불변 — `onReviewWritten` 이 `stores.updatedAt` 을 건드리지 않는 것과 같은 원칙: **소유권 경계를 넘는 쓰기는 최소 필드**).
- `refund`: 불변. 회수는 여전히 원장 금액 반전.

---

## 15. 테스트 전략 — 실행 가능 형태 / **실결제 0회**

### 15.1 Rules 하네스 (`test_rules/rules.test.mjs`) — 결제 0회

```
cd /Users/Byeonguk/Developer/OrderApp/test_rules && npm test
```

기존 73건 **전건 회귀 PASS** + 아래 신규. §9 의 경로를 그대로 케이스화한다 (**§20.5.6 의 20경로**로 읽는다).

| ID | 케이스 | 기대 |
|---|---|---|
| RH1 | owner 가 `stores.qoinAccrualRate` update | deny |
| RH2 | brand 가 가맹점 `stores.qoinAccrualRate` update | deny |
| RH3 | **admin 이 `stores.qoinAccrualRate` update** | deny |
| RH4 | owner 가 `stores` **create** 에 `qoinAccrualRate` 포함 | deny |
| RH5 | admin 이 `stores` 의 다른 필드 update (회귀) | allow |
| RH6~RH8 | `brands` 에 대해 RH3/RH4/RH5 대응 | deny/deny/allow |
| RH9 | admin 이 `config/qoin.accrualRate` update | **deny** |
| RH10 | admin 이 `config/qoin.enabled` update | **allow** |
| RH11 | admin 이 `config/qoin` 을 `accrualRate` 포함해 create | deny |
| RH12 | 비로그인/customer 의 `config` write | deny |
| RH13~16 | `qoinRateHistory` create/update/delete — customer/owner/brand/**admin** | 전부 deny |
| RH17 | 점주가 **자기 매장** 이력 read | allow |
| RH18 | 점주가 **남의 매장** 이력 read | deny |
| RH19 | brand 가 **자기 산하** 매장 이력 read | allow |
| RH20 | brand 가 **남의 브랜드** 이력 read | deny |
| RH21 | admin 이 전역/브랜드/매장 이력 read | allow |
| RH22 | customer 가 임의 이력 read | deny |
| RH23 | admin 의 `collectionGroup('qoinRateHistory')` 조회 | allow |
| RH24 | owner 의 collection group 조회 | deny |

### 15.2 CF 에뮬레이터 — 결제 0회

1차 test_report ⑧ 이 "스크립트가 scratchpad 일회성이라 재현 불가, `firebase.json` 에 functions 에뮬레이터 설정이 없다" 를 지적했다. **이번에는 스크립트를 저장소에 커밋하고 `firebase.json` 에 functions 에뮬레이터 + npm 스크립트를 추가한다** (이 작업 범위에 포함).

| ID | 케이스 | 기대 |
|---|---|---|
| CH1~CH10 | §6 진리표 10행 전건 | 표대로 (적립액 / source / INVALID 중단) |
| CH11 | 매장 `0` + 환불 | **회수는 정상 동작** (§4-③ 의 함정) |
| CH12 | 전역 `enabled=false` | 적립·회수 **모두** 중단 (1차 회귀) |
| CH13 | 매장 문서 없음 | 상위 상속 |
| CH14 | `storeId` 빈 문자열 | `skipped_invalid_store` 중단 |
| CH15 | brandId 없는 개인 매장 | brand 단계 생략, global 적용 |
| CH16 | 적립 1건당 read 수 | **earn 4~5 / clawback 4** (§1.6 수치 실측 확인) |
| CH17 | 멱등 (`completed→ready→completed`) | `already_applied` (1차 회귀) |
| CH18 | 원장에 `accrualRateSource` 기록 | earn 기록 / clawback 상속 |
| CH19 | `setQoinAccrualRate` 를 non-admin 이 호출 | `permission-denied` |
| CH20 | `setQoinAccrualRate` 에 `0.5` / `0.0005` / `-1` / `'3'` | `invalid-argument` (서버 경계) |
| CH21 | `setQoinAccrualRate` 성공 | 값 + 이력이 **함께** 생성 (`before` 정확) |
| CH22 | 일괄 `preserve` | 브랜드 값만 1 write, 개별 설정 보존, 이력 1건 |
| CH23 | 일괄 `overwrite` (매장 600개) | 청크 처리, `affectedCount/clearedCount` 정확, 이력 **1건** |
| CH24 | 일괄 중단 후 `resumeHistoryId` 재개 | 멱등, 중복 이력 없음, `completed` 마감 |
| CH25 | 일괄 중 적립 발생 | 적립률이 과거 값/전역으로 **떨어지지 않음** (브랜드-우선 순서 검증) |
| CH26 | Console 편집 모사 (Admin SDK 로 `config/qoin` 직접 write) | `onQoinConfigWritten` 이 `source:'direct'` 이력 1건 |
| CH27 | callable 직후 트리거 발화 | **중복 이력 없음** (§7.4 의 skip 판정) |

### 15.3 Dart 단위 테스트 (환경 불필요)

```
cd /Users/Byeonguk/Developer/OrderApp && flutter test
```

- `resolveEffectiveRate` — §6 진리표 **10행 전건** (CH1~CH10 과 **같은 케이스 표**)
- `validateRateInput` 회귀 — `0.03`/`0`/`0.1`/`3`/`20`/`20.1`/`0.25` (1차 케이스 유지)
- 명시적 0% 센티넬: `0` 은 입력 검증에서 `tooLow`, 토글 경로로만 생성됨
- `SetQoinAccrualRateUseCase` 범위 밖 → `ArgumentError`
- `QoinRateChangeModel` 매퍼: 미지 `scope`/`op` → null, 누락 필드, `before: null` 왕복
- 기존 129건 전건 회귀 PASS

### 15.4 수동 UI 검증 — **실결제 0회**

적립 발화는 **Console 로 주문 status 를 `ready` → `completed` 로 수정**한다. `completed` 로 **생성하면 발화하지 않는다** (`onDocumentUpdated`).

| ID | 시나리오 |
|---|---|
| MH1 | 전역 3% / 브랜드·매장 미설정 → 10,000원 주문 `ready→completed` → **300 Q**, 원장 `source: 'global'` |
| MH2 | 브랜드 5% 설정 → 같은 매장 새 주문 → **500 Q**, `source: 'brand'` |
| MH3 | 매장 10% 설정 → **1,000 Q**, `source: 'store'` |
| MH4 | 매장만 `적립 안 함` 토글 → 적립 0 (로그 `skipped_rate_zero`) |
| MH5 | MH3 의 주문을 `refunded` 로 수정 → **-1,000 Q 회수** (매장이 0% 여도 회수됨 = MH4 직후 수행) |
| MH6 | 관리자: 각 범위에서 `0.03` 입력 → **차단**, `30` 입력 → **차단** |
| MH7 | 확인 다이얼로그에 **범위와 대상명**이 보이는가 (전역/브랜드/매장 3회) |
| MH8 | 브랜드 일괄 `보존` → 개별 설정 매장은 자기 값 유지 |
| MH9 | 브랜드 일괄 `덮어쓰기` → 영향 매장 수 확인 문구 → 실행 후 개별 설정이 상속 표기로 바뀜 |
| MH10 | 이력 화면: MH1~MH9 가 시간순으로, `before→after` / 사유 / 일괄 메타가 맞는가 |
| MH11 | 점주 `내 매장` 에 적립률 + 출처 표기, **편집 수단 없음** |
| MH12 | 브랜드 `브랜드 정보` + `매장` 목록에 적립률 표기 |
| MH13 | 점주/브랜드가 **이력 조회** 가능, 남의 것은 안 보임 |
| MH14 | 전역 `enabled=false` 중 점주 화면에 중단 안내 표기 |
| MH15 | 고객 Qoin 화면에 **전역 숫자 문구가 사라졌는가** (§4-⑨) |
| MH16 | 고객 과거 내역의 `결제액 18,000원의 3%` 가 계층 변경 후에도 **그대로** |

---

## 16. 작업 분배

### designer — **호출 필요**

산출물 `docs/tasks/qoin_accrual_rate_hierarchy/design.md`

- 관리자 4화면 (§12.2) — 허브 / 브랜드별 / 매장별 / 이력
- **출처 표기 체계**: `매장 설정` / `브랜드 상속` / `전역 기본` / `적립 안 함` 4상태의 배지·카피 (기존 `brand_scope_badge.dart` / `store_scope_badge.dart` 재사용 가능성 검토)
- 일괄 적용 플로우 (H5 2단 선택 + 영향 매장 수 확인 + 결과/`partial` 재개)
- 범위 오입력 방어가 보이는 확인 다이얼로그
- 점주·브랜드 읽기 전용 행 3곳 (§12.3) + 전역 중단 안내
- 고객 문구 1곳 (§4-⑨)
- 1차 `admin_qoin_settings_page.dart` 에서 **추출할 공용 위젯 경계** 명시
- 제약: `AppColors` 만, 신규 색 토큰 0 목표, 매장 목록 대량 시 검색/필터 UX

### developer — **호출 필요** (designer 완료 후)

산출물 `docs/tasks/qoin_accrual_rate_hierarchy/implementation.md`

순서 권장: ① `qoinRate.ts` 공유 경계·해석 → ② `onOrderQoinSettled` 교체 → ③ callable 2개 + 감시 트리거 → ④ Rules + 하네스 → ⑤ Dart core/domain/data → ⑥ 화면 → ⑦ 테스트.

반드시 지킬 것
- §9 **전수 경로**를 Rules 하네스 케이스로 1:1 매핑 (F1 교훈) — **§20.5.6 의 20경로**로 읽는다
- 경계 상수는 Dart·TS **각 1곳** (F3 교훈). §10 표 준수
- `StoreModel`/`BrandModel` 의 **쓰기 맵에 `qoinAccrualRate` 를 넣지 않는다**
- 매장/브랜드 `0` 은 **적립만** 막고 **회수는 통과** (§4-③)
- 계층 읽기는 earn 분기 안 + `getAll` 1 라운드트립 (§7.2)
- 멱등 가드 / 트랜잭션 / 잔액 갱신 / 회수 산식은 **손대지 않는다**
- 인덱스는 **실측 확정** (§7.5). 에뮬레이터 통과를 근거로 쓰지 않는다
- CF 에뮬레이터 스크립트를 **저장소에 커밋** + `firebase.json` functions 에뮬레이터 + npm 스크립트 (1차 ⑧ 지적 해소)
- 보고: 적립 1건당 실제 read 수 (CH16), Rules 기존 73건 회귀 결과, 기존 129 테스트 회귀 결과

### tester — **호출 필요**

산출물 `docs/tasks/qoin_accrual_rate_hierarchy/test_report.md`

중점
1. **적립률 쓰기 경로 전수** (§9) — 한 경로라도 비면 FAIL (F1 재발)
2. **Dart·TS 경계 일치** (§10) — 상수 중복 선언 0건을 grep 으로 확인 (F3 재발)
3. **§6 진리표** 가 양쪽 테스트에서 같은 케이스로 검증되는지
4. **매장 0% 에서 회수가 되는지** (§4-③ 함정)
5. **일괄 적용**: 원자성·재개 멱등·이력 1건·수치 정확 (CH22~CH25)
6. **이력**: `before` 정확성, 같은 트랜잭션 보장, Console 편집 `source:'direct'`, 중복 없음
7. `audit_trail.md` §4 6항목 (§13) 재검증 — 특히 체크 4·6 의 **명시된 한계가 실제 그 한계인지**
8. 아키텍처 절대 규칙 (presentation/domain 에 Firebase import 0, `AppColors` 만, 하드코딩 0)
9. 1차 회귀: 멱등 / 회수 산식 / 전역 kill switch / 고객 과거 내역 불변
10. **실결제 0회** 유지 (§15.4 방식)

---

## 17. 사용자 확인이 필요한 결정사항 — **전건 확정 (2026-10-22)**

**U1~U7 모두 확정됐다.** U1 · U2 · U4 는 사용자에게 직접 확인했고, 나머지는 근거가 명확해 수용했다.

| # | 항목 | 확정 | 방식 |
|---|---|---|---|
| **U1** | 적립률을 매장 문서에 저장 → `isSignedIn()` 수준 공개 | **수용 (A안)** | 사용자 직접 확인 |
| **U2** | 매장/브랜드 **명시적 0% = 적립 안 함** 수단 신설 | **채택** | 사용자 직접 확인 |
| **U4** | 고객 Qoin 화면에서 **적립률 숫자 제거** | **채택** | 사용자 직접 확인 |
| U3 | `enabled` 토글 직접 쓰기 유지 → 행위자 미기록 | **수용** | 아래 |
| U5 | 기존 Rules 블록(`config`/`stores`/`brands`) 수정 | **수용** | 계층이 세 컬렉션에 걸쳐 불가피 |
| U6 | `stores`/`brands` 의 Console 직접 편집 감시 없음 (2차) | **수용** | Console 은 Rules 를 우회하므로 완전 차단 불가 |
| U7 | 원장에 `accrualRateSource` **지금** 추가 | **채택** | 아래 |

### U1 — 공개를 수용한 이유

`stores` 는 이미 `allow read: if isSignedIn()` 이다(`firestore.rules:258`). 적립률은 **고객에게 보여주는 혜택**이라 어차피 드러나는 정보다.
감추려면 별도 컬렉션 + 점주·브랜드용 미러 문서(H6)가 필요해 동기화 로직이 붙는다. **감출 가치보다 복잡도가 크다.**

### U2 — 0% 수단이 필요한 이유

비용을 **매장·브랜드가 부담**하므로(H1), 특정 매장만 적립을 멈추는 수단이 없으면 "우리는 빼달라"는 요구에 답할 수 없다.
전용 토글로만 입력받아 **100배 오입력 방어선(0.1~20%)은 그대로 유지**한다.

> ⚠️ **0% 는 적립만 막고 회수는 반드시 통과해야 한다.** 회수까지 막으면 환불된 주문의 Qoin 이 남아 **돈이 샌다.** spec 본문 §③ 참조.

### U3 — 행위자 기록을 포기한 이유

`enabled` 토글을 CF 경유로 바꾸면 **CF 장애 시 비상 정지가 불가능**해진다. 끄는 수단은 어떤 상황에서도 살아 있어야 한다.
`onQoinConfigWritten` 트리거가 before/after/시각은 남기고 `changedBy` 만 null 이다. **의도된 타협**이며 `audit_trail.md` 기준으로도 한계를 명시했다.

### U4 — 숫자를 빼는 이유

현재 `qoin_balance_card.dart:228` 이 **전역 적립률**을 `결제액의 3% 적립` 으로 보여준다. 계층이 생기면 매장마다 달라져 **이 문장이 거짓**이 된다.
범위 무관 문구로 바꾸고, 매장별 표시는 2차(N2)로 미룬다.

### U7 — 지금 추가해야 하는 이유

**1차 F2(`brandId` 누락)와 똑같은 함정이다.** 배포 후에 추가하면 과거 원장에 값이 없어 "이 적립이 매장 설정이었나 전역이었나" 를 영영 알 수 없다.
`audit_trail.md` §4-3(정책 값 박제)의 직접 적용이다.

---

### (원문) 결정사항과 선택지

H1~H7 은 확정이므로 재논의하지 않는다. 아래는 **이 설계 과정에서 새로 생긴** 판단이다.

| # | 항목 | 추천 | 확인 필요한 이유 |
|---|---|---|---|
| U1 | 저장 위치 = `stores`/`brands` 필드 (§4-①) | **A안** | 적립률이 `isSignedIn()` 수준에서 **누구나 읽을 수 있게** 된다 (매장 문서가 이미 전체 공개). 경쟁 매장의 비용 조건 노출을 수용하는지. 수용 못 하면 C안 + 미러로 설계가 커진다 |
| U2 | 매장/브랜드 명시적 0% = `적립 안 함` 수단 신설 (§4-③) | **신설** | 적립 중단 수단이 전역 1개에서 3계층으로 늘어난다. 운영 혼선 가능성 |
| U3 | `enabled` 토글은 직접 쓰기 유지 → 이력에 `changedBy` 없음 (§4-⑩) | **유지** | 비상 정지의 단순성과 행위자 기록을 교환했다. 행위자가 꼭 필요하면 토글도 CF 경유로 바꿔야 한다 |
| U4 | 고객 Qoin 화면에서 적립률 **숫자를 제거** (§4-⑨) | **제거** | 고객이 보는 정보가 줄어든다. 매장별 숫자 표시는 N2(2차) |
| U5 | 기존 Rules 블록(`config`/`stores`/`brands`) **수정** (§8) | **수정** | 1차의 "기존 블록 비수정" 원칙의 예외. 회귀 위험을 73건 하네스로 관리 |
| U6 | `stores`/`brands` 의 Console 직접 편집은 **감시 없음** (N6) | 2차 | 전역(`config/qoin`)만 감시한다. 매장 적립률을 콘솔로 바꾸면 이력이 비는 것을 수용하는지 |
| U7 | 원장에 `accrualRateSource` 추가 (§5.3) | **추가** | 배포 후에 추가하면 과거 행이 비어 소급 집계 불가 (F2 와 같은 함정). 지금 넣는 것에 동의가 필요 |

---

## 18. 완료 기준

1. §6 진리표 10행이 CF 와 Dart 양쪽에서 동일 케이스로 PASS
2. §9 의 전수 경로(**§20.5.6 의 20경로**)가 Rules 하네스 케이스로 존재하고 기대대로 동작 (기존 163건 회귀 PASS)
3. 적립률 변경이 **이력 없이** 발생할 수 있는 앱 내 경로가 **0** (Console 은 §9-11 의 명시된 한계)
4. 브랜드 일괄 적용이 보존/덮어쓰기 양 모드에서 동작, 중단 후 재개가 멱등, 이력 **1건**에 영향 수·덮어쓰기 여부 기록
5. 관리자 3범위 전부에서 `0.03` / `30` 입력이 차단되고 확인 다이얼로그에 **범위와 대상명**이 보인다
6. 점주·브랜드가 자기 적립률과 그 출처, 자기 이력을 볼 수 있고 **편집 수단이 없다**
7. 매장 0% 에서 **회수가 정상 동작**
8. 1차 회귀: 멱등 / 회수 산식 / 전역 kill switch / 고객 과거 내역 불변
9. `flutter analyze` 무경고, `flutter test` 전건 PASS, `functions` 빌드 PASS
10. `audit_trail.md` §4 6항목 통과 (§13) — 한계 2건이 spec 에 명시된 그대로
11. **실결제 0회**

---

# 19. 재검토 — tester FAIL 6건 (2026-10-22, 배포 전)

- 대상: `68ee77a`(백엔드) + `9068fa9`(앱/테스트). **미배포.** F1 때문에 배포를 멈춘 상태.
- 입력: `test_report.md` (PASS 14 / FAIL 6 / 보류 3)
- 이 절은 §1~§18 중 **틀린 판정을 정정**한다. 충돌하면 **이 절이 §1~§18 보다 우선**이고, **§20(사용자 결정 확정)이 이 절보다 우선**이다. 정정 대상: §1.5 · §4-② · §4-⑩ · §7.2 · §9 · §13(체크 2·4·6).

## 19.0 판정 요약

| # | 항목 | 판정 | 배포 전/후 |
|---|---|---|---|
| F1 | 브랜드 단계 미적용 + 클라이언트 지정 `brandId` | **고친다** — 신뢰원을 `stores/{id}.brandId` 로 | **배포 전 (필수)** |
| F2 | 덮어쓰기가 매장별 이전 값을 기록 없이 지움 | **고친다** — 매장별 이력 + 브랜드 이력 분류 집계 | **배포 전** |
| F3 | `enabled` 이력에 `changedBy` 없음 | **고친다** (§4-⑩ 의 수용은 거짓 이분법이었다) | **배포 전** |
| F4 | 매장 delete → 같은 ID 재생성으로 0% 해제 | **수용** (+ 하네스 케이스) — **§20.8 에서 Q3 ⓐ 로 확정.** 경로 수는 §20.5.6 에서 **20경로**로 재정정 | 배포 전 (문서·테스트만) |
| F5 | 일괄 적용 재개·동시 실행 보호 부족 | **고친다** — 브랜드 문서 잠금/포인터 1종 | **배포 전** |
| F6 | `data_ownership.md` 공백 | **고쳤다** (이 커밋) | 완료 |
| 부가 A | 오프-그리드 값 표시(`0.0015` → `0.2%`) | 고친다 | 배포 후 가능 |
| 부가 B | 무효 값 이력 `before: null` | **고친다** (소급 불가) | **배포 전** |
| H-1 | 0% 매장 덮어쓰기 정책 | ⚠️ **§20 에서 종결.** 사용자가 추천 A 를 **기각**하고 **적립 스위치 분리**로 확정 (§20.1~§20.6) | 배포 전 (설계 변경) |
| H-2 | 무효 값 fail-closed 시 소급 수단 없음 | 기록 수단은 **고친다** / 소급 도구는 backlog — **§20.7 에서 Q2 ⓐ 로 확정** | **배포 전**(기록) |
| H-3 | 허브 partial "조용히 생략" + 50건 | **결함이다 → 고친다** / 50건은 수용(+페이지네이션) | **배포 전**(구조) |

---

## 19.1 F1 — 적립률 계층의 브랜드 신뢰원을 `stores/{id}.brandId` 로 옮긴다

### 정정: §1.5 는 틀렸다

§1.5 는 "주문 문서에 `brandId` 가 이미 있다 → 매장 경유 역조인 불필요" 로 §7.2 의 1 라운드트립을 정당화했다. **사실이 아니다.** `CartEntity` 에 `brandId` 필드가 없고 `_cartToMap`(`payment_gateway_repository_impl.dart:175`)이 보내지 않으므로 `verifyTossPayment.ts:225,252` 의 `data.cart.brandId ?? null` 은 **항상 null** 이다. 주문 문서를 만드는 경로는 `verifyTossPayment.ts:263` 한 곳뿐이다. 따라서 `onOrderQoinSettled.ts:151` 이 읽는 `after.brandId` 는 언제나 null 이고, **브랜드 단계는 실제 앱에서 한 번도 적용되지 않는다.** 원장의 `brandId` 도 항상 null 이라 `audit_trail.md` §5(정산 대비)가 요구한 필드가 무효다.

### 결정 — 신뢰원은 `stores/{storeId}.brandId`, 평가 시점은 **적립(완료) 시점**

```
earn 경로의 브랜드 결정:
  storeSnap = stores/{after.storeId}            ← 이미 읽는다
  brandId   = storeSnap.get('brandId')          ← 유일한 신뢰원
  order.brandId / cart.brandId 는 금액 결정에 쓰지 않는다
```

근거 (세 가지):

1. **결제 경로를 건드리지 않는다.** 돈이 오가는 `verifyTossPayment` 에 문서 읽기를 추가하지 않는다.
2. **이미 생성된 주문(brandId null)도 함께 고쳐진다.** 박제 방식이면 과거 주문은 영구히 전역값으로 남는다.
3. **스푸핑 차단.** `cart` 는 클라이언트 값이다. 앱을 우회해 callable 을 직접 호출하면 무관한 고효율 브랜드(최대 20%)를 지정해 요율을 얻을 수 있다. 이번 변경이 `order.brandId` 를 **금액 결정에 쓰기 시작하면서** 신뢰 경계가 됐다. 매장 문서를 신뢰원으로 쓰면 이 구멍이 닫힌다.

### "주문 시점의 브랜드" vs "완료 시점의 브랜드" — 완료 시점이 맞다

대안으로 검토한 것: `verifyTossPayment` 가 매장 문서를 읽어 **서버 권위로 `brandId` 를 박제**하고 CF 는 매장 문서 fallback. 적립은 결제가 아니라 **완료 시점**에 일어나므로 그 사이 매장이 브랜드를 떠나면 박제값이 낡는다. 비용 부담 주체 관점에서 판단한 결과 **기각**한다.

| 관점 | 판단 |
|---|---|
| 설계 일관성 | §4-② 가 "적립률은 **완료 시점** 값" 을 이미 확정했다(주문에 요율 비정규화를 기각한 이유). 요율은 완료 시점인데 **소속 브랜드만 주문 시점**이면 해석 사슬이 내부적으로 불일치한다 — 매장 값은 최신, 소속은 박제 |
| 비용 부담 | 비용을 부담하는 주체는 **그 Qoin 이 발행되는 순간의 가맹 관계**다. 매장이 브랜드를 떠난 뒤 발행되는 Qoin 을 옛 브랜드에 청구할 근거가 없다. 반대로 떠난 브랜드의 요율(최대 20%)이 계속 적용되는 쪽이 분쟁 소지가 크다 |
| 괴리 창 | 결제 → 픽업 완료는 실무상 수 분~수 시간. 브랜드 이탈은 드문 행정 사건이고, 그 순간 처리 중인 주문이 걸릴 확률·금액은 1건 단위 |
| 비용 | 박제안은 결제 CF 에 read +1(사용자가 대기하는 경로) + fallback 코드를 **영구히** 유지 + 기존 주문은 여전히 null. 이득이 없다 |

→ **계층 전체를 적립 시점 기준으로 평가한다.** 매장 요율 · 매장의 브랜드 소속 · 브랜드 요율 · 전역 기본값 모두 "지금" 의 값.

### 정정: 라운드트립 (§4-② / §7.2 / §1.6)

brandId 를 매장 문서를 읽은 **뒤에** 알게 되므로 브랜드 소속 매장의 계층 해석은 **순차 2단**이 된다. 이 비용을 수용한다.

- read 수는 §1.6 의 예측(earn 4~5)과 **동일**하다. 늘어나는 것은 지연뿐이다.
- 적립은 픽업 완료 후 도는 **백그라운드 트리거**다. 사용자가 응답을 기다리는 경로가 아니고, 1차 설계가 `retry: true` 로 지연 허용을 이미 전제했다.
- 권장 구현: `config/qoin` 읽기를 earn 경로에서 매장 읽기와 합친다.
  - earn: `getAll([config/qoin, stores/{storeId}])` = 1 RT → brandId 있으면 `brands/{brandId}` = 1 RT → **총 2 RT** (현행 `loadConfig` 1 RT + `getAll` 1 RT 과 **같다**). 브랜드 없는 매장은 **1 RT 로 줄어든다**
  - clawback: `config/qoin` 단독 1 RT (현행 유지, read 증가 0)
  - 단 `enabled` kill switch 판정은 회수에도 유지한다(§4-② 불변). 합치는 것은 **읽기 묶음**뿐이고 판정 위치는 그대로다.
- `storeSnap` 이 없거나(`!exists`) `brandId` 가 빈 문자열/비문자열이면 **브랜드 단계 없음**으로 보고 전역으로 간다(기존 `classifyRate` 의 "문서 부재 = 상속" 과 같은 규칙). `storeId` 자체가 빈 값이면 현행대로 `skipped_invalid_store` 로 중단.

### 원장 `brandId`

**해석에 쓴 값(= `stores/{id}.brandId`)을 쓴다.** `after.brandId` 를 쓰면 정산 집계의 브랜드와 요율을 결정한 브랜드가 달라져 정산이 성립하지 않는다(`audit_trail.md` §5 의 목적 자체가 깨진다). clawback 은 현행대로 earn 문서에서 상속한다(재계산 금지).

### `order.brandId` / `orderLogs.brandId` 의 처리

- **필드는 유지**한다(모델 호환). 다만 `verifyTossPayment` 는 `data.cart.brandId` 를 **읽지 않고** `brandId: null` 로 기록한다 — 1줄 변경, read 추가 0. 클라이언트 지정 값을 **저장 자체 하지 않음**으로써 "나중에 누가 다시 신뢰원으로 쓰는" 재발 경로를 끊는다.
- 실측: `orders` 를 `brandId` 로 질의하는 코드는 없다(`where('brandId')` 는 `stores`/`brands` 컬렉션 조회 2곳뿐). 주문 화면이 브랜드를 보여줘야 하면 매장 문서에서 읽는다.
- `CartEntity` 에 `brandId` 를 추가하지 않는다. 추가하면 "앱이 보내는 브랜드" 라는 **거짓 권위**가 다시 생긴다.

### 이 결함이 테스트에 안 잡힌 이유 — 그리고 요구하는 테스트 (F1 본체보다 중요)

원인: **모든 자동 테스트가 주문을 `brandId` 가 들어간 채로 직접 시드한다**(`emulator.test.mjs` L80 `completeOrder`). `앱 → verifyTossPayment → orders → 적립` 최종 경로를 지나는 테스트가 **하나도 없다**. 테스트가 "주문 문서의 모양" 을 손으로 쓸 수 있는 한, 앱이 그 모양을 만들지 못하는 사실은 영원히 보이지 않는다.

필수 요구 (developer, 완료 기준에 추가):

- **T1 — 주문 문서 구성의 단일 출처화.** `verifyTossPayment` 의 주문/로그 문서 구성을 순수 함수 `buildOrderData(cart, uid, paymentInfo)` / `buildOrderLogData(...)` 로 분리한다. **에뮬레이터 E2E 는 주문을 손으로 시드하지 않고 이 함수로 만든다.** Toss API 호출은 모킹 대상이라 callable 전체를 통과시키지는 않되, "테스트가 쓰는 주문" 과 "운영이 쓰는 주문" 의 모양이 **같은 코드에서 나오게** 한다. 이것이 F1 클래스를 구조적으로 막는 유일한 수단이다.
- **T2 — cart 입력 계약 골든 테스트.** ⓐ Dart: `_cartToMap` 의 **키 집합**을 골든으로 고정. ⓑ TS: `verifyTossPayment` 가 `data.cart` 에서 **소비하는 키 집합**을 상수로 노출하고 골든으로 고정. ⓒ spec 의 대조표(아래)와 둘이 일치하는지 tester 가 확인. 한쪽만 바뀌면 골든이 깨져 대조가 강제된다.

  | `_cartToMap` 이 보내는 키 | `verifyTossPayment` 가 쓰는 키 | 비고 |
  |---|---|---|
  | storeId / storeName / subtotal / discount / totalPrice / items | 동일 | 전건 일치 |
  | (없음) | `brandId` | **이 행이 F1 이었다.** 수정 후 TS 쪽에서 제거 |

- **T3 — 적립이 `order.brandId` 와 무관함 (3 케이스).**
  1. `order.brandId = null` + `store.brandId = A`(5%) → 500 Qoin / `accrualRateSource: 'brand'` / 원장 `brandId = A`
  2. `order.brandId = B`(20%) + `store.brandId = A`(5%) → **5% 적용** / 원장 `brandId = A` (스푸핑 차단 회귀)
  3. `order.brandId = A` + `store.brandId` 부재 → 전역값 / 원장 `brandId = null`
- **T4 — grep 체크(tester).** 금액·원장 경로에서 `after.brandId` / `data.cart.brandId` 참조 **0건**.

---

## 19.2 F2 + H-1 — 덮어쓰기 기록, 그리고 0% 보호

### 정정: §13 체크 2 의 "통과" 판정은 사실과 다르다

§13 체크 2(L578)는 개별 설정 초기화를 "`clearedCount` 로 남는다 → 통과" 로 판정했다. **오판정이다.** `applyBrandQoinRate.clearOverrides` 는 매장 `qoinAccrualRate` 를 `FieldValue.delete()` 하고 `stores/{id}/qoinRateHistory` 에는 **아무것도 쓰지 않는다**. 브랜드 이력에는 `clearedCount` 숫자만 남아 **어느 매장의 어떤 값(3% / 0% / 무효)이 지워졌는지 어디에도 없다.** `audit_trail.md` §4-2("덮어쓰기로 사라지는 값") 위반이고, 점주 입장에서는 **자기 매장 이력에 아무 기록 없이 적립률이 바뀐다.** → 체크 2 는 **FAIL**. 아래로 고친다.

### 기록 설계 (고친다, 배포 전)

1. **지우는 매장마다 매장 이력 1건.**

```
stores/{storeId}/qoinRateHistory/{autoId}
  scope          'store'
  targetId       storeId
  field          'accrualRate'
  op             'clearByBulk'                  ← 신규
  before         number | null                  ← 지워진 값
  beforeState    'value' | 'invalid'            ← 19.4-B 와 공용
  beforeRaw      string | null
  after          null                           ← 상속으로 되돌림
  changedBy      실행 admin uid                  ← 일괄이라도 행위자는 있다
  changedByRole  'admin'
  source         'bulk'
  bulkHistoryId  브랜드 이력 ID                   ← 신규. 브랜드 1건 ↔ 매장 N건 연결
  bulkMode       'overwrite'
  changedAt      serverTimestamp
```

점주의 "왜 내 매장 적립률이 바뀌었나" 가 이 1건으로 답된다(F2 재현 경로의 핵심 불만).

2. **브랜드 이력에 분류 집계 추가**: `clearedZeroCount` / `clearedInvalidCount` / `clearedValueCount` (합 = `clearedCount`). 0% 수가 남아야 H-1 의 A/C 안 판단 근거가 생긴다.

3. **구현 주의 — 배치 한도.** 매장 1건당 `update` 1 + 이력 `create` 1 = **2 write**. `CHUNK` 을 **450 → 225** 로 낮춘다(500 한도). 600매장 전체 덮어쓰기 시 write 1,200 — 운영자 행위 빈도이므로 비용 수용.

4. 매장 이력 쓰기 주체는 CF 전담(Rules `if false`) — 기존 패턴 그대로.

### H-1 — 0% 덮어쓰기 정책: ⚠️ **§20 에서 확정됨 (추천 A 기각)**

> **이 소절은 역사 기록이다.** 사용자는 아래 추천안 A(서버가 0% 매장을 skip)를 **기각**하고, **"적립 사용 안 함" 을 적립률과 분리된 별도 스위치로 두는 설계**를 택했다. 일괄 적용은 0% 매장도 포함해 **숫자를 덮고**, 스위치는 건드리지 않는다. 결정과 설계는 **§20** 을 따른다. 아래 A~D 논의와 분류 집계(`clearedZeroCount`)는 **§20.5.5 로 교체**됐다.

`docs/backlog.md` 에 옵션 A~D 가 기록돼 있고 A 가 추천돼 있다. 사용자는 "해결책도 나중에 같이 구상하겠지?" 라고만 했고 **아직 안을 고르지 않았다.** 설계자가 임의 확정하지 않는다.

**추천: A (0% 는 덮어쓰기에서도 제외) + 서버 집행.**

- 0% 는 "값" 이 아니라 **의도(잠금)** 다. 3% → 5% 통일은 합리적이지만 0% → 5% 는 "적립 안 함" 결정의 무효화다. 돈이 **나가기 시작하는** 방향의 결정이므로 마찰이 타당하다.
- **화면 경고로는 구조적으로 보장되지 않는다.** 현재 다이얼로그의 "적립 안 함 N곳도 다시 적립해요" 의 N 은 화면 스트림에서 센 값이라 실행 시점과 다를 수 있다(그 사이 다른 admin 이 0% 를 걸면 다이얼로그 숫자보다 많이 덮인다). 서버가 `qoinAccrualRate === 0` 을 **skip** 하면 다이얼로그 숫자 정확도와 무관하게 안전해진다.
- A 를 택하면 다이얼로그 문구가 경고("…도 다시 적립해요" + 체크박스)에서 **정보**("적립 안 함 N곳은 그대로 유지돼요")로 바뀌어, 숫자가 틀려도 결과가 안전하다 → **스트림 숫자 괴리 문제가 같이 사라진다.** 체크박스는 제거 가능.

**A 를 택하지 않을 경우의 괴리 처리(B/C/D 공통)**: 사전 숫자의 정확성은 분산 상태에서 보장할 방법이 없다. 따라서 ⓐ 다이얼로그 숫자는 "약" 임을 문구로 드러내고(`약 N곳`), ⓑ **서버가 실제로 덮은 수**(`clearedZeroCount`)를 응답으로 돌려 **완료 화면이 사후 확정 고지**("적립 안 함이었던 3곳이 다시 적립돼요"), ⓒ 매장별 이력(위)으로 사후 추적 — 세 겹으로 닫는다. **어느 안이든 ⓑ·ⓒ 와 매장별 이력은 필수다.**

---

## 19.3 F3 — `enabled` 토글의 행위자: **tester 가 맞다. 고친다**

§4-⑩ / §13 체크 4-ⓐ 는 "CF 경유로 바꾸면 CF 장애 시 비상 정지가 불가능하다" 를 이유로 행위자 미기록을 수용했다. **이 수용은 거짓 이분법 위에 서 있었다.** 선택지는 "CF 경유" 와 "행위자 포기" 둘이 아니다. 제3안이 있고, 비용이 사실상 없다.

### 제3안 — 직접 쓰기를 유지하면서 행위자를 남긴다

```
클라이언트(admin) 1회 write:
  config/qoin  { enabled: false,
                 enabledChangedBy: <auth.uid>,      ← 신규
                 enabledChangedAt: request.time }   ← 신규

Rules: config/qoin update 에서 enabled 가 바뀌면
  request.resource.data.enabledChangedBy == request.auth.uid  강제

onQoinConfigWritten: after.enabledChangedBy 가 있으면
  changedBy = 그 uid / changedByRole = 'admin' / source = 'app_direct'
                        없으면 (= Console 편집)
  changedBy = null / source = 'direct'   ← 현행 유지
```

| 기준 | 결과 |
|---|---|
| 비상 정지의 단순성 | **보존.** 여전히 클라이언트 직접 쓰기 1회. CF 는 경로에 없다. CF 가 죽어 있어도 토글은 즉시 반영되고, 이력만 트리거 복구 후(재시도) 남는다 |
| 행위자 | 남는다. Rules 가 `== auth.uid` 를 강제하므로 다른 admin 사칭 불가 |
| 앱 토글 vs 콘솔 편집 구별 | **된다.** `source: 'app_direct'` vs `'direct'` — F3 가 요구한 것 그대로 |
| 비용 | Rules 1분기 + 클라이언트 2필드 + 트리거 분기 1개 |

→ **§4-⑩ / §13 체크 4-ⓐ / U3 을 정정한다.** 남는 한계는 ⓑ Console 편집의 행위자 미상 **1건뿐**이며, 그것은 Firebase 의 구조적 성질이다(§9-11 과 동급).

**배포 전에 싣는다.** 이미 F1 로 배포가 멈춘 상태이므로 추가 비용이 없고, 지나간 이력은 소급 불가다(U7 과 같은 논리).

> ⚠️ **배포 순서 제약**: Rules 가 `enabledChangedBy` 를 강제하므로 **Rules 와 앱 빌드를 같은 배포에** 올린다. Rules 를 먼저 올리면 구버전 앱의 토글이 거부된다 — **돈을 멈추는 스위치가 막히는** 최악의 순서다. 미배포 상태이므로 지금은 문제없고, §3.1 배포 목록에 순서를 명시한다.

---

## 19.4 F4 · 부가 판정

### F4 — 매장 delete → 같은 ID 재생성: **수용** (고치지 않는다)

| 근거 | 내용 |
|---|---|
| 돈으로 이어지지 않는다 | 재생성 문서는 Rules 가 `status: 'pending'` 을 강제한다. 재승인 전까지 주문을 받지 못하므로 **적립이 발생하지 않는다.** 0% 해제가 돈이 되려면 **admin 의 명시적 승인 행위**를 반드시 거친다 |
| 방어선 위치 | 점주의 `stores.delete` 는 이 기능과 무관하게 **이미 매장 문서 전체를 파괴**한다(훨씬 큰 권한). 적립률 1필드만 따로 막는 것은 방어선의 위치가 틀렸다 |
| 진짜 문제는 다른 것 | `stores.delete` 가 점주에게 열려 있고, 삭제가 **이력에 남지 않으며**, 이력 서브컬렉션이 고아가 된다. → **`stores.delete` 정책(소프트 삭제 / admin 전용 / 삭제 이력)** 으로 `backlog.md` 에 올린다. 이 spec 범위 밖 |

**요구 (어느 쪽이든 필수)**: Rules 하네스에 이 경로 케이스를 추가한다 — ⓐ 점주 `delete` **ALLOWED** ⓑ 같은 ID 로 `status:'pending'` 재생성 **ALLOWED** ⓒ `qoinAccrualRate` 를 포함한 재생성 **DENIED**. 현재 동작을 명시적으로 고정해 다음 사람이 "전수" 를 다시 오해하지 않게 한다.
**§9 정정**: "12경로 전수" → **13경로**. 13번 = 점주 delete + 재생성(**수용된 경로**, 재승인 필요). ⚠️ **§20.5.6 에서 다시 20경로로 정정됐다** (스위치 필드 7경로 추가).

### 부가 A — 오프-그리드 값 표시 (배포 후 가능)

Console 로 넣은 `0.0015` 는 CF 가 0.15% 로 정확히 계산하지만 화면은 `0.2%` 로 반올림 표시한다. **표시가 거짓**이므로 고친다(돈은 틀리지 않으므로 배포 차단 아님).
정책: 저장값이 격자(1/1000 단위)와 **왕복 일치하지 않으면 반올림 표시를 금지**한다. 정확한 값(`0.15%`)을 보여주고 **admin 화면에만** `격자 밖 값 (콘솔 편집)` 배지를 붙인다. CF 계산은 변경 없음(유효 범위 안이면 그대로 발행 — fail-closed 대상 아님). 점주/고객 화면은 소수 둘째 자리까지 표기만 정확히 한다.

### 부가 B — 무효 값의 이력 `before` (배포 전, 소급 불가)

`setQoinAccrualRate` 가 이전 값이 무효(문자열 등)였을 때 이력 `before` 를 `null` 로 기록해 **"설정 없음(상속)" 과 구별되지 않는다.** 감사 정밀도 문제이고 **사후 복원이 불가능**하다(§5.2 가 `null` 의 뜻을 "설정 없음" 으로 정의해버렸다).
→ 이력 스키마에 추가(callable 2개 + `onQoinConfigWritten` 공용):

```
beforeState  'absent' | 'invalid' | 'value'
beforeRaw    string | null      ← 무효값의 원형 문자열 (최대 100자, 비number 만)
```

`before` 자체의 의미는 유지(number|null)하고 모호성만 제거한다. 기존 판독 코드는 `beforeState` 부재를 `'value'|'absent'` 로 관대히 해석한다.

### H-2 — 무효 값 fail-closed 시 소급 적립: **기록은 지금, 소급 도구는 backlog**

무효 값은 Console 편집으로만 생긴다. 그런데 그 사이 완료된 주문은 `skipped_invalid_rate` **로그만** 남기고 트리거가 `return` 으로 성공 처리되어 재시도되지 않는다. 값을 고쳐도 그 주문들은 영영 적립되지 않고, 근거는 Cloud Logging 보존 기간(30일)에만 있다 — `audit_trail.md` §4-6("영구 보존이 필요하면 Firestore") 위반이며, 사라지는 것이 **고객 돈**이다.

**고친다 (배포 전, 기록 수단만)**: 적립이 중단된 주문을 Firestore 에 1건 기록한다.

```
qoinSettlementIssues/{orderId}        ← CF 전담 쓰기, read: admin
  orderId / userId / storeId / brandId
  reason     'invalid_rate' | 'invalid_store' | 'invalid_total'
  scope      'store' | 'brand' | 'global' | null     ← 어느 단계가 무효였나
  values     { store, brand, global }                ← 그때 본 원시 값
  totalPrice number
  occurredAt serverTimestamp
  resolved   false
```

- `skipped_rate_zero` 는 **기록하지 않는다** — 의도된 정책이고 빈도가 높다(노이즈).
- 멱등: 문서 ID 를 `orderId` 로 고정.
- **소급 적립 도구 자체는 만들지 않는다.** "어느 시점 요율로 줄 것인가"(발생 시점 / 수정 후 / 전역 기본)는 정책 결정이 필요하다 → **Q2** + `backlog.md`. 다만 위 기록이 있으면 **나중에 만들 수 있다**. 지금 기록하지 않으면 그때 대상 목록 자체가 없다(F2·U7 과 같은 함정).

---

## 19.5 F5 + H-3 — 일괄 적용 서버 보호와 중단 가시성 (한 필드로 닫는다)

### 판정 — tester 의 동시 실행 추론은 **코드 확인 결과 사실이다**

`applyBrandQoinRate.ts` 실측: `running` 조회(`where status == 'in_progress'`)와 이력 생성이 **분리**돼 있고, 트랜잭션이 읽는 것은 `brands/{id}` **하나뿐**이다. 두 호출이 scan 구간에 겹치면 서로 충돌하지 않는다. 두 번째 호출은 브랜드 값이 이미 같으므로 `sameValue = true` 지만, `mode === 'overwrite'` 에서 **자기 스캔의 `scan.withOverride > 0`** 로 noop 분기를 빠져나가 **이력 2건 + `clearOverrides` 2중 실행 + 카운트 이중 보고**가 된다. → 고친다.

### 해법 — 브랜드 문서에 잠금/포인터 필드 (추가 read 0)

```
brands/{brandId}
  qoinBulkHistoryId : string | null
  qoinBulkStatus    : 'in_progress' | 'partial' | null
  qoinBulkAt        : timestamp
```

- 트랜잭션이 **이미 `brands/{id}` 를 읽고 있으므로 read 증가 0.** 트랜잭션 **안에서** `qoinBulkStatus == 'in_progress'` 이고 stale 아니면 거부 → 같은 문서 경합이므로 Firestore 가 직렬화한다. **이력 2건이 구조적으로 불가능**해진다 (현재의 트랜잭션 밖 사전 조회는 보조 수단으로만 남긴다).
- `completed` 로 마감할 때 세 필드 제거, 실패 시 `'partial'` 유지.
- **Rules**: 클라이언트 쓰기 차단. `stores`/`brands` 의 `qoinAccrualRate` 차단 분기에 이 3필드를 **같이** 넣는다(`touchesQoinRate()` 확장). create 경로도 동일.
- `StoreModel`/`BrandModel` 의 쓰기 맵에 넣지 않는다(§16 규칙 그대로).

### (a) 재개 재검증 — 고친다

`resumeHistoryId` 경로가 트랜잭션 안에서 다음을 확인하고, 하나라도 어긋나면 `failed-precondition` 으로 **거부**한다("브랜드 값이 그 뒤에 변경됐어요. 다시 적용하세요"):

1. `brands/{id}.qoinBulkHistoryId == resumeHistoryId`
2. `brands/{id}.qoinAccrualRate` 가 그 이력의 `after` 와 일치 (부재 ↔ `after: null` 포함)

이력에 `resumedAt` / `resumeCount` 를 기록한다. 이렇게 하면 "이력은 5% 로 덮어씀인데 실제 브랜드 값은 3%" 상태가 만들어지지 않는다.

### (c) 일괄 진행 중 단건 변경 — 고친다 (저비용)

`setQoinAccrualRate` 가 `scope: 'store'` 이고 그 매장에 `brandId` 가 있으면 브랜드 문서를 읽어 `qoinBulkStatus == 'in_progress'`(not stale) 이면 거부한다("이 브랜드에 일괄 적용이 진행 중이에요"). 매장 문서는 이미 읽으므로 **read +1**, 빈도는 운영자 행위 수준. 브랜드 단건 변경(`scope: 'brand'`)도 동일하게 막는다.

### H-3 — "조용히 생략" 은 **그 자체로 결함이다** (판정)

`admin_qoin_settings_page.dart` 의 `_PartialSection` 은 `asData?.value == null` 이면 `SizedBox.shrink()` 를 돌려준다(주석도 "실패·로딩이면 조용히 생략한다"). 이 표면은 **중단된 일괄 적용을 알리는 유일한 상시 표면**이다. 그것이 에러일 때 사라지면 화면상 **"중단 없음" 과 "알 수 없음" 이 구별되지 않는다.** 안전 측 실패가 아니다 — 특히 인덱스 미배포 상태에서는 CG 쿼리가 `failed-precondition` 으로 항상 실패하므로 **중단된 일괄 적용이 허브에 영원히 보이지 않는다.** → **결함으로 판정하고 고친다.**

| # | 수정 | 배포 |
|---|---|---|
| D-1 | **구조**: 허브의 중단 판정을 CG 이력이 아니라 **`brands` 스트림의 `qoinBulkStatus`** 로 한다(위 포인터). 허브는 이미 `qoinAdminBrandsProvider` 를 쓰므로 **추가 조회 0**. 인덱스 미배포·50건 윈도우와 **무관하게** 중단이 보인다 | 배포 전 |
| D-2 | **표면**: "최근 변경" 서브타이틀과 이력 화면은 에러를 **조용히 생략하지 않고** 에러 행("이력을 불러올 수 없어요 · 다시 시도")을 보인다. 로딩과 에러를 구별한다 | 배포 전 |
| D-3 | **50건 한계는 수용.** 포인터가 "놓치면 위험한 것"(중단)을 떼어냈으므로 남는 것은 최신순 열람 편의다. 단 전체 이력 화면은 50건 고정이 아니라 **페이지네이션(더 보기)** 을 요구한다 — 600매장 초기 세팅에서 50건은 반나절 분량이다(tester §7 시나리오 1) | 전체 이력 페이지네이션은 배포 후 가능 |
| D-4 | **배포 순서**: `firestore:indexes` 를 **앱 배포 전에** 올린다. CG 이력 쿼리가 인덱스를 요구한다(에뮬레이터는 인덱스를 강제하지 않아 테스트로 못 잡는다 — §7.5 의 교훈이 여기서 실제화됐다) | 배포 전 |

---

## 19.6 §13 감사 추적 체크리스트 — 재판정

| # | 체크 | 1차 판정 | **재판정** |
|---|---|---|---|
| 1 | 설정 변경 이력 | 통과 | **통과** (변동 없음) |
| 2 | 덮어쓰기로 사라지는 값 | 통과 | **FAIL → 19.2 로 수정.** 일괄 덮어쓰기가 매장별 이전 값을 기록 없이 지웠다. 매장별 이력 + 분류 집계로 통과시킨다 |
| 3 | 당시 값 박제 | 통과 | **통과.** 단 원장 `brandId` 가 항상 null 이던 것은 **박제 실패**였다 → 19.1 로 수정(해석에 쓴 `store.brandId` 를 박제) |
| 4 | "누가" | 통과(한계 2) | **ⓐ FAIL → 19.3 으로 수정**(`enabled` 행위자). ⓑ Console 편집 미상은 **수용 유지**(구조적). 일괄의 매장별 기록에도 실행 admin uid 를 남긴다(19.2) |
| 5 | 일괄 = 1건 + 영향 범위 | 통과 | **통과 + 보강.** 브랜드 1건은 유지하고 매장별 1건을 **추가**한다(묶음은 `bulkHistoryId` 로 연결). 동시 실행 시 이력 2건 문제는 19.5 로 수정 |
| 6 | CF 로그 의존 | 통과(한계 2) | **ⓐ FAIL → 19.4(H-2) 로 수정.** 적립 중단(= 고객 돈 누락)을 로그에만 남기는 것은 §4-6 위반. `qoinSettlementIssues` 로 Firestore 기록. `skipped_rate_zero` 는 의도된 정책이라 로그 유지(수용). ⓑ `stores`/`brands` Console 편집 감시 없음은 **수용 유지**(N6) |

---

## 19.7 배포 전 / 배포 후  ⚠️ **§20.10 · §20.11 로 교체됨**

### 배포 전 필수 (이것들이 끝나야 배포)

| # | 내용 | 이유 |
|---|---|---|
| 1 | **F1** — 브랜드 신뢰원 `store.brandId` + 원장 `brandId` 일치 + `cart.brandId` 미사용 | 이대로 배포하면 브랜드 단계가 죽은 채 화면만 "5%" 라 말한다. 클라이언트 지정 brandId 로 임의 요율 획득 가능 |
| 2 | **F1 테스트** — T1(주문 구성 단일 출처) · T2(계약 골든) · T3(3 케이스) | 같은 클래스의 결함을 테스트가 못 보는 구조 자체가 결함 |
| 3 | **F2** — 매장별 이력 + 분류 집계 (+ CHUNK 225) | 소급 불가. 지금 덮으면 지워진 값이 영구 소실 |
| 4 | **F3** — `enabled` 행위자 (Rules + 앱 2필드 + 트리거) | 소급 불가. 배포가 이미 멈춘 상태라 추가 비용 0 |
| 5 | **F5** — 브랜드 잠금/포인터 + 재개 재검증 + 진행 중 단건 차단 | 이력 중복·거짓 이력은 감사 자산을 오염시킨다 |
| 6 | **H-3 D-1/D-2** — 허브 중단 판정을 포인터 기반으로, 에러 무음 제거 | 인덱스 미배포 구간에서 중단이 영원히 안 보인다 |
| 7 | **부가 B** — `beforeState` / `beforeRaw` | 소급 불가 |
| 8 | **H-2 기록** — `qoinSettlementIssues` | 소급 불가(대상 목록 자체가 사라진다) |
| 9 | **F4 하네스 케이스** + §9 13경로 정정 | 코드 변경 없음. "전수" 주장의 정직성 |
| 10 | **배포 순서**: `firestore:indexes` → `firestore:rules` + `functions` → 앱 빌드. **Rules 와 앱은 같은 배포**(F3) | D-4 / 19.3 |
| 11 | **H-1 사용자 결정(Q1)** — 서버 집행이 필요하면 CF 변경이 생긴다 | 0% 를 덮는 것은 **돈이 나가기 시작하는** 방향 |

### 배포 후 처리 가능

| # | 내용 |
|---|---|
| 1 | **부가 A** — 오프-그리드 값 정확 표시 + `격자 밖 값` 배지 (돈은 정확하다) |
| 2 | **H-3 D-3** — 전체 이력 화면 페이지네이션(더 보기) |
| 3 | **H-2 소급 적립 도구** — 정책 결정(Q2) 후 |
| 4 | `stores.delete` 정책 재설계 (소프트 삭제 / 삭제 이력) — `backlog.md` |
| 5 | N6 — `stores`/`brands` Console 편집 감시 |

---

## 19.8 작업 분배  ⚠️ **§20.12 로 교체됨** (아래는 Q1 결정 이전 판)

### designer — **호출 필요** (소폭, 배포 전)

`design.md` 에 증분 추가:

1. **일괄 적용 다이얼로그** — H-1 결정(Q1)에 따라 분기. A 안이면 경고 줄("적립 안 함 N곳도 다시 적립해요") + 체크박스를 **정보 줄**("적립 안 함 N곳은 그대로 유지돼요")로 교체하고 체크박스 제거. A 안이 아니면 숫자에 "약" 표기 + **완료 화면의 사후 확정 고지**(서버가 실제로 덮은 0% 수)
2. **허브** — partial 배너의 **에러 상태**(현재는 무음) + "최근 변경" 서브타이틀의 에러 행. 로딩/에러/없음 3상태 구분
3. **매장 이력 화면** — `op: 'clearByBulk'` 행의 표기("브랜드 일괄 적용으로 초기화 · 이전 값 0%"), 브랜드 이력으로 가는 연결(`bulkHistoryId`)
4. **`격자 밖 값(콘솔 편집)` 배지** (배포 후 가능) — admin 화면 전용
5. 전체 이력 화면 **더 보기** (배포 후 가능)
6. 제약 그대로: `AppColors` 만, 신규 색 토큰 0 목표

### developer — **호출 필요** (파일 단위)

**백엔드 (TS)**

| 파일 | 작업 |
|---|---|
| `functions/src/onOrderQoinSettled.ts` | ① 브랜드를 `storeSnap.get('brandId')` 에서 얻는다(`after.brandId` 미사용) ② earn: `getAll([config/qoin, stores/{id}])` → brandId 있으면 `brands/{id}` 순차. clawback 의 config 단독 읽기 유지 ③ 원장 `brandId` = 해석에 쓴 `store.brandId` ④ `skipped_invalid_*` 에서 `qoinSettlementIssues/{orderId}` 기록(`skipped_rate_zero` 제외) |
| `functions/src/verifyTossPayment.ts` | ① `data.cart.brandId` 참조 제거 → `brandId: null` (orders / orderLogs 둘 다) ② 주문·로그 문서 구성을 순수 함수 `buildOrderData` / `buildOrderLogData` 로 분리 + 소비 키 집합 상수 export (T1/T2) |
| `functions/src/applyBrandQoinRate.ts` | ① 동시 보호를 **트랜잭션 안으로** — `brands/{id}.qoinBulkStatus/qoinBulkHistoryId/qoinBulkAt` ② 재개 재검증(포인터 일치 + 브랜드 값이 이력 `after` 와 일치) + `resumedAt`/`resumeCount` ③ `clearOverrides` 가 매장별 이력 1건 동시 생성, **CHUNK 450 → 225** ④ 브랜드 이력에 `clearedZeroCount`/`clearedInvalidCount`/`clearedValueCount` ⑤ 마감 시 포인터 제거 ⑥ (Q1 이 A/C 면) 0% skip 집행 |
| `functions/src/setQoinAccrualRate.ts` | ① 일괄 진행 중이면 거부(brandId 있는 매장 / 해당 브랜드) ② 이력에 `beforeState`/`beforeRaw` |
| `functions/src/onQoinConfigWritten.ts` | ① `after.enabledChangedBy` 를 `changedBy` 로, `source: 'app_direct'`, 없으면 현행 `'direct'` ② `beforeState`/`beforeRaw` |
| `functions/src/qoinRate.ts` | 격자 왕복 판정 헬퍼(부가 A) — TS 쪽 상수는 여기 1곳 유지 |
| `firestore.rules` | ① `config/qoin` update: `enabled` 변경 시 `enabledChangedBy == auth.uid` 강제 ② `touchesQoinRate()` 에 `qoinBulkHistoryId`/`qoinBulkStatus`/`qoinBulkAt` 추가(stores·brands, create/update 전 분기) ③ `qoinSettlementIssues`: `read: isAdmin()`, 쓰기 `if false` |
| `firestore.indexes.json` | CG 이력 인덱스 확정 + **배포를 앱보다 먼저**(D-4) |

**앱 (Dart)**

| 파일 | 작업 |
|---|---|
| `lib/data/repositories/payment_gateway_repository_impl.dart` | `_cartToMap` 변경 없음. 키 집합 골든 테스트 대상(T2). `brandId` 를 **추가하지 않는다** |
| `lib/presentation/admin/qoin/admin_qoin_settings_page.dart` | `_PartialSection` 판정을 `brands` 스트림의 `qoinBulkStatus` 로 교체 + 에러 상태 렌더 / `_historySubtitle` 에러 행 |
| `lib/presentation/common/widgets/qoin/qoin_rate_confirm_dialog.dart` | H-1 결정에 따른 문구·체크박스 + 완료 사후 고지 |
| `lib/domain/entities/qoin_rate_change_entity.dart`, `lib/data/models/qoin_rate_change_model.dart` | `beforeState` / `beforeRaw` / `bulkHistoryId` / `clearedZeroCount` 등 / `op: 'clearByBulk'` / `source: 'app_direct'` 매핑(미지값 관대 처리) |
| `lib/data/models/brand_model.dart`, `store_model.dart` | 포인터 필드를 **쓰기 맵에 넣지 않는다**. 필요한 읽기만 노출 |
| `lib/presentation/admin/qoin/*` (비상 정지 카드) | 토글 write 에 `enabledChangedBy`/`enabledChangedAt` 동시 기록 |
| `lib/core/utils/qoin_policy.dart` | 격자 왕복 판정 + 격자 밖 값 표시(부가 A). 경계 상수는 여기 1곳 유지(§10) |
| `lib/presentation/admin/qoin/admin_qoin_rate_history_page.dart` | 페이지네이션(배포 후 가능) |

**테스트**

- `functions/test/emulator.test.mjs`: 주문을 `buildOrderData` 로 생성(T1) / T3 3케이스 / 일괄 동시 호출 2회 → 이력 1건 / 재개 재검증 거부 / `clearOverrides` 가 매장 이력을 쓰는지 / `qoinSettlementIssues` 기록
- `test_rules/rules.test.mjs`: F4 케이스 3건 / 포인터 3필드 차단(create·update·admin 전권) / `enabledChangedBy` 불일치 DENY · 일치 ALLOW / `qoinSettlementIssues` 쓰기 DENY
- Dart: `_cartToMap` 키 골든(T2) / 격자 왕복 표시 / 이력 모델 신규 필드
- 보고: 적립 1건당 **실제 read 수와 라운드트립 수**(브랜드 매장 / 비브랜드 매장 각각), Rules 하네스 전건 회귀, flutter test 전건 회귀

### tester — 재검증 (developer 완료 후)

중점: ① T1~T4 가 실제로 F1 클래스를 막는지(주문을 손으로 시드하는 테스트가 **남아 있지 않은지**) ② 매장별 이력의 `before` 정확성(0%·무효·유효 3종) ③ 동시 호출 2회 실제 재현(이번엔 추론이 아니라 재현) ④ 인덱스 미배포 상태에서 허브가 중단을 보여주는지(포인터 기반이므로 가능해야 한다) ⑤ `enabled` 토글의 `changedBy` 와 콘솔 편집 구별 ⑥ §19.6 재판정 6항목 ⑦ 실결제 0회

---

## 19.9 사용자 확인이 필요한 결정사항 — ✅ **전건 확정 (2026-10-22)**

**Q1 / Q2 / Q3 모두 사용자 결정으로 확정됐다. 결정 내용과 설계는 §20 을 따른다.** 아래 표는 질문 원문과 당시 추천을 남긴 역사 기록이다.

| # | **확정** | 추천과의 관계 |
|---|---|---|
| **Q1** | **추천 A 기각.** 적립률과 분리된 **매장·브랜드 단위 "적립 사용 안 함" 스위치**를 둔다. 일괄 적용은 0% 매장도 포함해 숫자를 덮고 스위치는 건드리지 않는다. 0% 설정은 스위치 끄기로 대체되고 **0 은 적립률 값으로 금지**된다 (§20.1~§20.6) | **기각** — 예외 규칙(0 skip) 대신 스키마 분리로 문제를 제거 |
| **Q2** | **ⓐ 기록만.** `qoinSettlementIssues/{orderId}` 기록 수단만 배포 전에 만들고 소급 적립 도구는 backlog (§20.7) | 추천과 동일 |
| **Q3** | **ⓐ 수용.** Rules 하네스 3케이스 필수. `stores.delete` 정책은 backlog 별도 과제 (§20.8) | 추천과 동일 |

### (원문) 질문과 당시 추천

| # | 질문 | 선택지 | 추천 |
|---|---|---|---|
| **Q1** | 브랜드 일괄 **덮어쓰기**가 `적립 안 함(0%)` 매장을 덮어야 하는가? (`backlog.md` 옵션) | **A** 0% 는 제외(잠금) / **B** 0% 매장 목록 개별 체크 / **C** 3택(전체·0%제외·0%포함) / **D** 현재안(알림만) | **A.** 화면 숫자는 실행 시점과 어긋날 수 있어 경고로는 보장이 안 된다. 서버가 0% 를 skip 하면 숫자 정확도와 무관하게 안전하다. **돈이 나가기 시작하는** 방향의 결정만 막는다. 해제는 그 매장에서 명시적으로 풀게 한다. B 는 매장이 많으면 비현실적, C 는 선택지 1개 추가 비용 대비 이득이 작다 |
| **Q2** | 무효 값 때문에 적립이 누락된 주문을 **소급 적립**할 것인가? 한다면 어느 요율로? | ⓐ 소급 안 함(기록만) / ⓑ **수정 후** 요율로 소급 / ⓒ 발생 시점의 **전역 기본값**으로 소급 | 지금은 **기록만** 만들고(배포 전) 도구는 backlog. 결정하면 ⓑ 가 설명하기 쉽다("정상값으로 고친 뒤 그 값으로 지급"). 다만 요율이 내려갔다면 고객에게 불리해질 수 있어 사용자 판단이 필요하다 |
| **Q3** | F4(매장 delete → 같은 ID 재생성으로 0% 해제)를 **수용**해도 되는가? | ⓐ 수용(하네스로 동작 고정) / ⓑ 막는다(재생성 시 admin 승인 전까지 0% 복원 등) | **ⓐ 수용.** 재생성은 `status: pending` 이라 **admin 승인 없이는 적립이 발생하지 않는다.** 대신 `stores.delete` 정책(점주 삭제 허용 / 삭제 이력 없음 / 이력 고아)을 별도 과제로 backlog 에 올린다 |


---

# 20. Q1·Q2·Q3 확정 — 적립 스위치 분리 (2026-10-22, 사용자 결정)

- 입력: §19.9 의 Q1 / Q2 / Q3 에 대한 **사용자 결정 3건**. 전건 확정이며 재논의 대상이 아니다.
- 이 절은 §19 를 다시 정정한다. **충돌하면 이 절이 §19 보다, §19 가 §1~§18 보다 우선**이다.
- 정정 대상: §4-③ · §5.1 · §5.2 · §6 · §7.2 · §7.3 · §8 · §9(13경로) · §10 · §11 · §12 · §13 · §19.0(H-1) · §19.2(F2 분류 집계) · §19.7 · §19.8 · §19.9.
- **§20.14 (designer 확인 8건 / 사용자 결정 N4 / 배포 순서 N6)** 가 §20.1~§20.13 을 다시 정정한다. 충돌하면 **§20.14 와 그것이 개정한 §20.3.1 · §20.11 이 우선**이다.

## 20.0 결정 요약

| # | 질문 | **확정** | §19 추천과의 관계 |
|---|---|---|---|
| **Q1** | 일괄 덮어쓰기가 `적립 안 함(0%)` 매장을 덮어야 하는가 | **덮는다. 단 "적립 사용 안 함" 을 적립률과 분리된 별도 스위치로 둔다.** 일괄 적용은 숫자만 덮고 스위치는 건드리지 않는다. 적립률 0% 설정은 **스위치를 끄는 동작**으로 대체된다 | **추천 A(서버가 0% 매장 skip) 기각.** backlog 옵션 A~D 전부 종결 |
| **Q2** | 무효 값 때문에 누락된 적립을 소급할 것인가 | **ⓐ 기록만.** `qoinSettlementIssues/{orderId}` 기록 수단만 이번에 만들고 소급 적립 도구는 backlog | 추천과 동일 |
| **Q3** | F4(매장 delete → 같은 ID 재생성) 를 수용하는가 | **ⓐ 수용.** Rules 하네스 케이스 3건 필수. `stores.delete` 정책은 backlog 별도 과제 | 추천과 동일 |

### Q1 이 A 안보다 나은 이유 (결정 근거 — 사용자가 짚은 구조 문제)

지금 `qoinAccrualRate` **한 필드가 두 가지를 겸하고 있다.**

| 필드가 겸하는 의미 | 일괄 적용이 덮어도 되는가 |
|---|---|
| **숫자** — "적립률은 얼마냐" (3% / 5% / 10%) | **된다.** 브랜드 단위 요율 통일은 일괄 적용의 존재 이유다 |
| **스위치** — "적립을 하냐" (`0` = 적립 안 함) | **안 된다.** 돈이 나가기 시작하는 방향의 결정을 무효화한다 |

두 의미가 **같은 필드**에 있으므로 일괄 적용은 둘을 구분할 수 없었다. 추천안 A 는 여기에 **"값이 0이면 건너뛴다" 는 예외 규칙**을 덧붙여 때우는 안이었다. 예외 규칙은 ⓐ 서버·클라이언트·다이얼로그 문구·이력 집계 네 곳에 같은 분기를 심고 ⓑ "왜 이 매장만 안 바뀌었나" 를 설명해야 하고 ⓒ 나중에 "0% 도 덮고 싶다" 가 나오면 다시 선택지를 만들어야 한다.

**스위치를 별도 필드로 분리하면 예외 자체가 사라진다.**

```
일괄 적용  : 숫자(qoinAccrualRate) 만 쓴다.          스위치는 읽지도 쓰지도 않는다
스위치     : 전용 경로(setQoinAccrualEnabled) 만 쓴다. 일괄 적용에서 도달 불가능
```

- 일괄 적용 코드에 "0 인지" 를 묻는 분기가 **0개**다. 구조적으로 덮을 수 없으므로 집행 누락이 불가능하다.
- A 안이 해결하려던 "다이얼로그 숫자와 실행 시점의 괴리"(§19.2) 도 같이 사라진다. 숫자가 틀려도 **스위치는 덮이지 않으므로** 결과가 안전하다.
- 0% 는 **적립률이 아니다**. 0.1~20% 가 유효 범위인데 0 을 센티넬로 끼워 넣은 것이 §4-③ 의 설계 부채였다. 그 부채를 여기서 청산한다.

> **§4-③ 정정**: §4-③ 은 "별도 bool (`qoinAccrualEnabled`)" 을 **"두 필드의 정합성을 항상 맞춰야 한다 (`rate` 있는데 `enabled:false` 같은 모순 상태)" 를 이유로 기각**했다. 이 기각 근거는 **틀렸다.** `rate: 0.05` + `enabled: false` 는 모순이 아니라 **의도된 상태**다 — "5% 로 설정돼 있지만 지금은 적립을 중단한다". 정합성을 맞춰야 할 두 필드가 아니라, **독립적인 두 축**이다. 모순 상태가 없으므로 정합성 유지 비용도 없다.

---

## 20.1 필드 설계

### 20.1.1 스위치 필드

```
stores/{storeId}
  qoinAccrualRate    : number 0.001~0.2   ← 부재 = 상위 상속. **0 은 더 이상 유효하지 않다**
  qoinAccrualEnabled : false              ← 부재 = 적립 사용 (기본값). false 만 저장한다

brands/{brandId}
  qoinAccrualRate    : number 0.001~0.2   ← 동일
  qoinAccrualEnabled : false              ← 동일

config/qoin
  accrualRate : number 0.001~0.2          ← 전역 기본값 (0 불가, 부재 불가 — 변동 없음)
  enabled     : boolean                   ← 전역 비상 정지. **적립·회수 둘 다** 멈춘다 (변동 없음)
```

**선택 근거 — 별도 필드 (`qoinAccrualEnabled`) 를 택한다.** 대안이었던 "`QoinRateSetting` 타입에 상태 추가" 는 기각한다.

| 안 | 판단 |
|---|---|
| **별도 bool 필드** (채택) | 숫자와 스위치가 **저장 단위부터 분리**된다. 일괄 적용이 쓰는 필드 집합(`qoinAccrualRate`)에 스위치가 없으므로 **덮어쓰기가 코드가 아니라 스키마 차원에서 불가능**하다. Rules 차단 헬퍼·이력·CF 가 전부 기존 패턴 그대로 확장된다 |
| 타입 안에 상태 추가 (`qoinAccrualRate: 'off'` 등 비number 센티넬) | 필드가 여전히 하나다 → 일괄 적용이 쓰는 필드와 스위치가 **같은 필드**로 남는다. Q1 이 고치려는 문제가 그대로 남는다. 또한 "비number 는 fail-closed" 규칙(§5.1)과 정면 충돌한다. **기각** |
| 숫자 범위 확장 (`-1` = off 등) | §4-③ 이 이미 기각한 음수 센티넬. 변동 없이 기각 |

### 20.1.2 명명

- `qoinAccrualEnabled` — 기존 `qoinAccrualRate` 와 **같은 접두(`qoinAccrual`)** 를 쓴다. Rules 의 차단 필드 목록과 모델의 "쓰기 맵에 넣지 않는 필드" 목록이 접두로 묶여 읽힌다.
- `config/qoin.enabled` (전역 비상 정지) 와 **이름이 다르다.** 의미가 다르기 때문이다 — 전역 `enabled` 는 **적립·회수 둘 다** 멈추는 비상 정지이고, `qoinAccrualEnabled` 는 **적립만** 멈춘다(회수는 통과). 이름을 같게 하면 "매장을 끄면 환불 회수도 멈추나?" 를 매번 다시 확인해야 한다.
- 이력 문서의 `field` 값도 구별한다: `'accrualRate'` / `'accrualEnabled'`(매장·브랜드 스위치) / `'globalEnabled'`(전역 비상 정지). §5.2 가 정의한 `'enabled'` 는 **`'globalEnabled'` 로 개명**한다 (미배포이므로 소급 대상 없음. 판독 측은 `'enabled'` 를 `'globalEnabled'` 로 관대히 해석한다).

### 20.1.3 부재 = 사용 (그리고 `false` 만 저장하는 이유)

```
필드 부재      → 적립 사용 (기본값)
false          → 적립 사용 안 함
true           → 적립 사용 (= 부재와 같다. 저장하지 않지만 읽기는 허용)
그 외 (비bool) → **무효 → fail-closed** (적립 중단 + qoinSettlementIssues 기록)
```

- **기본값을 "사용" 으로 둔다** → 기존 전체 매장·브랜드 문서에 필드를 심는 마이그레이션이 **불필요**하다. 이전해야 할 것은 `qoinAccrualRate: 0` 인 소수 문서뿐이다 (§20.4).
- **다시 켤 때는 필드를 삭제**한다 (`FieldValue.delete()`). `true` 를 저장하지 않는 이유: 부재/`true`/`false` 3값을 만들면 "부재와 true 가 같다" 를 네 곳(Dart·TS·Rules 설명·화면)에서 반복 설명해야 한다. **예외적인 상태(`false`)만 문서에 보인다** → Firestore Console 을 열면 "적립을 끈 매장" 이 한눈에 걸러진다.
- 판독은 `true` 도 받는다. Console 로 누가 `true` 를 넣어도 정상 동작해야 한다 (관대한 판독 / 엄격한 쓰기).
- **비bool 값은 무효**다. 적립률의 "비number = fail-closed" 와 **같은 원칙**이다. "애매하면 돈을 내보내지 않는다."

---

## 20.2 `QoinRateSetting` 4-값 타입의 재정의

### 20.2.1 결론 — (a) 0 을 적립률 입력값으로 금지한다

선택지 (a) "0 을 금지하고 스위치만 쓴다" 를 택한다. (b) "0 은 계속 저장 가능하되 스위치가 집행한다" 를 기각한다.

| | (a) 0 금지 **(채택)** | (b) 0 저장 허용 |
|---|---|---|
| 상태 수 | 적립률 셀 **3값** (부재 / 유효 / 무효) + 스위치 셀 4값 | 적립률 셀 **4값 유지** + 스위치 셀 4값 |
| "적립 안 함" 의 출처 | **1개** (스위치) | **2개** (rate 0, 스위치 false) → 해석 사슬에 우선순위 규칙이 또 필요하다 |
| 일괄 적용 | 숫자를 덮는다. 끝 | 0 을 덮으면 "0 이 사라졌다" 가 다시 발생 → **Q1 이 고치려던 문제가 재발** |
| 화면 | "적립 안 함" 토글 1개 | 토글 + 0% 입력 두 경로가 같은 결과를 만든다 → 사용자 혼란 |
| 진리표 | 20행 → 32행 (스위치 축 추가, 0 행 교체, N4 정합 3행) | 20행 → 36행 이상 (0 × 스위치 조합 전수) |

(b) 는 Q1 의 결정("0% 를 하면 자동으로 사용 안 함 상태가 된다")을 **두 상태의 동거**로 구현하는 안이다. 사용자 의도는 **0% 라는 숫자가 스위치로 승격되는 것**이므로 (a) 가 의도에 맞다.

> **운영 영향 1건 (사용자 확인 불필요, 결정에 포함됨)**: 브랜드 단위 `0%`(진리표 R05) 도 사라진다. 그 기능은 **브랜드 스위치**(`brands/{id}.qoinAccrualEnabled`)로 **이동**한다 — §20.3.2 참조. 기능을 없애지 않고 옮긴다.

### 20.2.2 타입 변경 (Dart / TS 공통)

```
RateCell  (적립률 1칸)        : absent | valid(rate) | invalid(raw)         ← zero 삭제
SwitchCell (스위치 1칸) 신규   : absent | enabled | disabled | invalid(raw)
```

- `classifyRate(raw, allowZero)` → **`classifyRate(raw)`**. `allowZero` 매개변수를 **삭제**한다 (0 은 어느 범위에서도 유효하지 않으므로 범위별 분기가 사라진다 — `functions/src/qoinRate.ts`, `lib/core/utils/qoin_policy.dart` 양쪽).
- `isValidCallableRate(raw, allowZero)` → **`isValidCallableRate(raw)`**. 0 은 항상 거부.
- `QoinPolicy.explicitOffRate` **삭제**. 참조처(화면 토글 등)는 스위치 경로로 교체.
- 신규 `classifySwitch(raw)` (TS) / `QoinPolicy.classifySwitch(Object? raw)` (Dart). 상수·판정의 출처는 기존 규칙 그대로 **각 언어 1곳**(`qoinRate.ts` / `qoin_policy.dart`)만.
- `Resolved` 에 **`disabled` 결과를 추가**한다: `{ ok: true, disabled: true, source: 'store'|'brand' }`. 기존 `rate === 0` 으로 "적립 안 함" 을 표현하던 관용은 **삭제**한다 (0 이 더는 유효값이 아니므로 `rate` 로 off 를 표현할 수 없다).
- `invalid` 사유 확장: `invalid_store | invalid_brand | invalid_global | invalid_store_enabled | invalid_brand_enabled`.

### 20.2.3 진리표 변경 — `test_fixtures/qoin_rate_truth_table.json` 행 단위

셀 표기에 `storeEnabled` / `brandEnabled` 2열이 추가된다. 두 열의 기본값은 `"absent"` 이며, 기존 행은 이 값으로 읽는다.

#### `resolve` 배열 (20행 → **32행**) — ⚠️ **N4 개정 반영 (R06 기대값 반전 + R21b·R22b·R23b 신규)**

| 행 | 변경 | 내용 |
|---|---|---|
| R01 | **유지** | store 부재 / brand 부재 / global 0.03 → 0.03 global. 2열 추가(absent) |
| R02 | **유지** | 0.05 brand |
| R03 | **유지** | 0.10 store |
| **R04** | **교체** | 기존 `store: 0 → (0, store)` **삭제**. 새 R04: `storeEnabled: false`, store 부재, brand 0.05 → **`{disabled: 'store'}`** |
| **R04b** | **신규** | `storeEnabled: false`, **store 0.10**, brand 0.05 → **`{disabled: 'store'}`**. ⚑ Q1 핵심 케이스 — **숫자가 있어도 스위치가 이긴다** |
| **R05** | **교체** | 기존 `brand: 0 → (0, brand)` **삭제**. 새 R05: `brandEnabled: false`, store 부재, brand 0.05 → **`{disabled: 'brand'}`** |
| **R06** | **교체 + ⚠️ N4 로 기대값 반전** | 기존 `store 0.10 / brand 0 → (0.10, store)`. 새 R06: `brandEnabled: false`, **store 0.10** → **`{disabled: 'brand'}`**. ⚑ **N4 핵심 케이스** — 상위 스위치가 하위 개별 숫자를 이긴다. (N4 결정 전 초안은 `(0.10, store)` 였다. 이 행이 뒤집힌 유일한 기대값이다) |
| R07 | **유지** | 전부 부재 → `invalid_global` |
| R08 | **유지** | store 0.5 → `invalid_store` |
| R09 | **유지** | brand 0.5 → `invalid_brand` |
| R10 | **유지** | global 0.5 → `invalid_global` |
| R11 | **유지** | store NaN → `invalid_store` |
| R12 | **유지** | store "3" → `invalid_store` |
| R13 | **유지** | store null → `invalid_store` |
| R14 | **유지** | store −0.01 → `invalid_store` |
| R15 | **유지** | store 0.0005 → `invalid_store` |
| **R16** | **유지 (사유 변경)** | `global: 0 → invalid_global`. 결과 동일. 단 사유가 "전역만 0 금지(`allowZero=false`)" 에서 **"0 은 어느 범위에서도 적립률이 아니다"** 로 바뀐다. `note` 갱신 |
| **R16b** | **신규** | `store: 0`, brand 0.05 → **`invalid_store`**. ⚑ (a) 안의 직접 결과 — 0 은 이제 매장에서도 무효다. ※ 마이그레이션 완료 전에는 §20.4.3 의 호환 분기가 이 행을 `resolve_legacy` 로 우회한다 |
| **R16c** | **신규** | `brand: 0`, store 부재 → **`invalid_brand`** |
| R17 | **유지** | store 0.001 → 유효 (하한) |
| R18 | **유지** | store 0.2 → 유효 (상한) |
| R19 | **유지** | store 0.2001 → `invalid_store` |
| R20 | **유지** | 브랜드 미소속 개인 매장 → global |
| **R21** | **신규** | `storeEnabled: "str:false"` (문자열), 꺼진 스위치 없음 → **`invalid_store_enabled`**. 비bool fail-closed |
| **R21b** | **신규 (N4)** | `storeEnabled: "str:false"` + **`brandEnabled: false`** → **`{disabled: 'brand'}`**. ⚑ `disabled` 가 `무효` 보다 앞이다(규칙 3) — 브랜드가 꺼져 있으면 매장 스위치가 깨져 있어도 **누락 사건으로 기록하지 않는다** |
| **R22** | **신규** | `brandEnabled: 1` (number), store 부재 → **`invalid_brand_enabled`** |
| **R22b** | **신규 (N4)** | `brandEnabled: 1` (number) + **store 0.10** → **`invalid_brand_enabled`**. ⚑ 상위 스위치가 **무효**일 때도 하위 개별 숫자가 그것을 이기지 못한다 (규칙 1 이 `disabled` 뿐 아니라 `invalid` 에도 적용됨을 고정) |
| **R23** | **신규** | `storeEnabled: true` (명시적 true), store 부재, brand 0.05 → **`(0.05, brand)`**. 명시적 true = 부재 |
| **R23b** | **신규 (N4)** | `storeEnabled: true` (명시적 true) + **`brandEnabled: false`** → **`{disabled: 'brand'}`**. ⚑ 명시적 `true` 는 "브랜드가 꺼졌어도 이 매장만 적립" 을 뜻하지 **않는다** |
| **R24** | **신규** | `storeEnabled: false` + `brandEnabled: false` → **`{disabled: 'store'}`**. 매장 스위치가 먼저(규칙 4). `source` 가 화면 배지를 결정하므로 행으로 고정. **N4 로도 변동 없음 — 재확인 완료** |
| **R25** | **신규** | `storeEnabled: false`, store·brand·global **전부 부재** → **`{disabled: 'store'}`** (❗`invalid_global` 이 **아니다**). 스위치가 전역 검사 **앞에서** 단락한다 → 전역 설정이 깨져 있어도 사용 안 함 매장은 `qoinSettlementIssues` 를 만들지 않는다 |
| **R26** | **신규** | `brandEnabled: false`, store 부재, brand·global 부재 → **`{disabled: 'brand'}`** |

> **행 수 정정**: 개정 전 이 표를 "26행" 으로 적었으나 실제 열거는 **29행**이었다(단순 집계 오류). N4 신규 3행을 더해 **32행**이 정확한 수다. 내역: 기존 20 + R04b·R16b·R16c·R21~R26(9) + R21b·R22b·R23b(3) = 32.

#### `resolve_legacy` 배열 (**신규, 과도기 한정 — 마이그레이션 완료 후 배열째 삭제**)

| 행 | 내용 |
|---|---|
| L01 | `store: 0`, brand 0.05, global 0.03 → **`{disabled: 'store', legacy: true}`** |
| L02 | `brand: 0`, store 부재 → **`{disabled: 'brand', legacy: true}`** |
| L03 | `store: 0` + `storeEnabled: false` → **`{disabled: 'store'}`** (중복이어도 결과 동일 — 마이그레이션 중단·재실행 안전) |

#### `classify` 배열 (14행 → **13행**, `allowZero` 키 전건 삭제)

| 행 | 변경 |
|---|---|
| `{raw: 0, allowZero: true, expect: "zero"}` | **삭제** |
| `{raw: 0, allowZero: false, expect: "invalid"}` | **`{raw: 0, expect: "invalid"}`** 로 통합 (두 행 → 1행) |
| 나머지 12행 (`absent` / 0.001 / 0.0009 / 0.2 / 0.2001 / 0.03 / −1 / 1 / 0.5 / NaN / "3" / null) | **`allowZero` 키만 삭제**, 기대값 변동 없음 |

#### `classifySwitch` 배열 (**신규 7행**)

| id | raw | expect |
|---|---|---|
| S01 | `absent` | `enabled` (부재 = 사용) |
| S02 | `true` | `enabled` |
| S03 | `false` | `disabled` |
| S04 | `"str:false"` | `invalid` |
| S05 | `0` | `invalid` (number 는 bool 이 아니다) |
| S06 | `1` | `invalid` |
| S07 | `null` | `invalid` |

#### `callable` 배열 (13행 → **12행**, `allowZero` 키 전건 삭제)

| 행 | 변경 |
|---|---|
| `{raw: 0, allowZero: true, expect: true}` | **`{raw: 0, expect: false}`** 로 교체 |
| `{raw: 0, allowZero: false, expect: false}` | **삭제** (위 행과 통합) |
| 나머지 11행 (0.03 / 0.001 / 0.2 / 0.025 / 0.0305 / 0.5 / 0.0005 / −1 / "3" / NaN / null) | **`allowZero` 키만 삭제**, 기대값 변동 없음 |

#### `callableSwitch` 배열 (**신규 4행** — `setQoinAccrualEnabled` 입력 경계)

| id | enabled 입력 | expect |
|---|---|---|
| C01 | `true` | accept |
| C02 | `false` | accept |
| C03 | `"false"` | reject (`invalid-argument`) |
| C04 | `0` | reject |

**양쪽 테스트가 같은 파일을 읽는 규칙은 변동 없다** (§10-2). `resolve_legacy` / `classifySwitch` / `callableSwitch` 도 Dart·TS 양쪽이 같이 읽는다.

---

## 20.3 해석 사슬에서 스위치의 위치

### 20.3.1 알고리즘 (§6 교체) — ⚠️ **N4 결정(2026-10-22, 사용자 A안)으로 개정됨**

**원칙: 스위치는 스위치만 이기고, 아랫단계의 숫자는 상위 스위치를 이길 수 없다.**

스위치 단계를 **숫자 단계보다 통째로 앞에** 둔다 (매장·브랜드 스위치를 **둘 다** 먼저 평가한 뒤 숫자 상속으로 내려간다).

```
resolveEffectiveRate(storeSwitch, storeRate, brandSwitch, brandRate, globalRate)

  # ── 1단계: 스위치 (숫자보다 먼저. 매장 → 브랜드 순) ──────────────
  if storeSwitch is disabled  -> DISABLED(source 'store')
  if brandSwitch is disabled  -> DISABLED(source 'brand')
  if storeSwitch is 무효      -> INVALID(invalid_store_enabled)
  if brandSwitch is 무효      -> INVALID(invalid_brand_enabled)

  # ── 2단계: 숫자 (상속) ─────────────────────────────────────────
  if storeRate   is 무효      -> INVALID(invalid_store)
  if storeRate   is 유효      -> (storeRate, 'store')
  if brandRate   is 무효      -> INVALID(invalid_brand)
  if brandRate   is 유효      -> (brandRate, 'brand')
  if globalRate  is 유효      -> (globalRate, 'global')
  INVALID(invalid_global)
```

규칙 4가지를 명시한다.

1. **스위치 단계가 숫자 단계를 통째로 앞선다.** 상위(브랜드) 스위치가 꺼져 있으면 **개별 적립률이 설정된 산하 매장도 함께 멈춘다.** → 진리표 **R06**(개정).
2. **매장 스위치가 꺼져 있으면 숫자를 아예 읽지 않는다.** 일괄 적용이 숫자를 덮어도 적립이 되지 않는 것이 이 줄에서 나온다. → R04b.
3. **`disabled` 판정이 `무효` 판정보다 앞이다.** 중단된 상태는 "애초에 돈이 나갈 예정이 없었던" 상태이므로 `qoinSettlementIssues`(= 고객 돈 누락 기록)를 만들지 않는다. 반면 아무것도 꺼져 있지 않은데 값이 무효라면 **나갔어야 할 돈이 안 나간 것**이므로 기록한다. → R21b · R25.
4. **매장이 브랜드보다 먼저 평가된다** → 둘 다 꺼져 있으면 `source: 'store'` 로 결정적이다. 화면 배지(`매장에서 중단` / `브랜드에서 중단`)가 흔들리지 않는다. → R24.

#### ⚠️ 정정 — 기존 규칙 ③ 이 뒤집혔다

개정 전 규칙 ③ 은 **"매장 개별 숫자는 브랜드 스위치를 이긴다"**(기존 R06 `store 0.10` + `brand 0` → `0.10`) 였다. **사용자 결정(N4 = A안)으로 반대가 됐다.**

| 근거 | 내용 |
|---|---|
| ⓐ **전역 비상 정지와 의미가 일관된다** | `config/qoin.enabled = false` 는 개별 설정을 보지 않고 전부 멈춘다. 브랜드 스위치가 "산하 매장 중 개별 설정이 없는 곳만" 멈춘다면, **같은 "끈다" 가 계층마다 다른 범위**를 갖게 된다 |
| ⓑ **"끈다" 는 말이 상황에 따라 다르게 동작하지 않는다** | admin 이 브랜드를 끌 때 기대하는 것은 "이 브랜드에서 적립이 안 나간다" 다. 개별 요율 매장의 존재 여부를 머릿속에 들고 있어야 하는 설계는 돈을 다루는 조작으로서 부적절하다 |
| ⓒ **designer 가 올린 설명 불가능한 귀결** (N4 제기 사유) | 개정 전 설계에서는 ⓐ admin 이 브랜드를 꺼도 개별 요율 매장은 **계속 적립**하고 ⓑ 그 상태에서 일괄 **덮어쓰기**를 하면 개별 요율이 지워지면서 **그때서야** 적립이 멈춘다. "브랜드를 끈 시점" 과 "적립이 멈춘 시점" 이 어긋나고, 멈춘 원인이 스위치가 아니라 **일괄 적용의 부작용**이 된다. 사고 조사 때 설명할 수 없는 인과다 |
| 상속 규칙과의 관계 | 숫자의 상속(매장 → 브랜드 → 전역)은 **그대로**다. 바뀐 것은 "스위치는 상속 체계의 바깥, 그보다 위" 라는 위치 규정뿐이다 |

#### 매장 스위치가 **명시적으로 켜진** 경우 (`true` 판독)

**브랜드가 꺼졌을 때 "이 매장만 예외" 를 표현할 수단은 없다. 그것이 A안의 의도된 결과다.**

- `qoinAccrualEnabled: true` 는 **"꺼져 있지 않다"** 는 뜻일 뿐이고 "상위를 무시한다" 는 뜻이 아니다. 1단계에서 매장이 `disabled` 가 아니면 **그대로 브랜드 스위치 판정으로 넘어간다.** → 진리표 **R23b**(신규).
- 애초에 쓰기 경로가 `true` 를 저장하지 않는다 (다시 켜면 필드 삭제 — §20.1.3). Console 로 `true` 를 넣어도 부재와 **완전히 동일**하게 동작한다.
- "이 매장만 예외" 를 지원하려면 **세 번째 상태**(매장 단위 강제 켜기)가 필요하고, 그것은 ⓑ("끈다 가 상황에 따라 다르게 동작하지 않는다")를 정면으로 깨뜨린다. 또한 §20.3.2 가 거부한 **범위 확대**에 해당한다.
- **운영상의 대안**: 브랜드 안에서 일부 매장만 적립하려면 **브랜드 스위치를 켠 상태로 두고, 적립을 멈출 매장들의 스위치를 각각 끈다.** 브랜드 스위치는 "이 브랜드 전체 정지" 용도로만 쓴다. 이 지침을 끄기 확인 다이얼로그에 넣는다 (§20.14-N4).

### 20.3.2 브랜드 단계에도 스위치를 둔다 (범위 판단)

**결론: 둔다.** 단 이것은 **범위 확대가 아니라 기능 이동**이다.

| 판단 | 내용 |
|---|---|
| 지금 설계에 이미 있다 | 현행(미배포) 설계는 `brands/{id}.qoinAccrualRate: 0` = **브랜드 단위 적립 중단**을 지원한다 (진리표 R05, `data_ownership.md` §2.11.1). Q1 이 0 을 금지하므로, 스위치를 브랜드에 두지 않으면 **이미 설계·구현된 기능이 조용히 사라진다** |
| "범위를 넓히지 않는다" 와의 관계 | 넓히는 것은 **새 계층을 만드는 것**(예: 메뉴별 스위치)이다. 기존 3계층 중 2계층이 이미 갖고 있던 능력을 같은 2계층에 **다른 필드로 옮기는 것**은 확대가 아니다. 계층 수는 3개로 불변 |
| 한계 비용 | 필드 1개 · 해석 사슬 2줄 · Rules 차단 필드 목록 1항목 · 진리표 3행 · 브랜드 편집 화면 토글 1개. 판정 코드(`classifySwitch`)·이력·CF·Rules 헬퍼는 **매장 스위치와 전부 공용** |
| 비대칭의 비용 | 브랜드만 빼면 "브랜드는 왜 못 끄나" 를 운영 중에 다시 만난다. 그때 추가하면 매장/브랜드 판정이 비대칭으로 갈라질 위험이 있다 (1차 F1 이 바로 "보호가 한 경로에만 걸려 있던" 사고였다) |

**전역에는 스위치를 추가하지 않는다.** `config/qoin.enabled` 가 이미 있고, 의미가 더 강하다 — **적립·회수 둘 다** 멈추는 비상 정지다. `qoinAccrualEnabled` 를 전역에 또 두면 "전역에 끄는 스위치가 2개" 가 되어 비상 정지의 단순성(§4-⑩ / §19.3 이 지키려 한 성질)을 해친다. `setQoinAccrualEnabled` 는 `scope: 'global'` 을 **`invalid-argument` 로 거부**한다.

### 20.3.3 회수(clawback)는 스위치와 무관하다 — 불변

**매장·브랜드 스위치가 꺼져 있어도 회수는 통과한다.** 적립 분기(`kind === 'earn'`) 안에서만 계층을 읽는 현행 구조가 이 성질을 보장한다 (§7.2, test_report PASS-13). 막으면 "매장을 끄면 환불된 주문의 Qoin 이 회수되지 않는다" → Qoin 누수. 전역 `enabled=false` 만 적립·회수를 둘 다 멈춘다. **§4-③ 의 "설계 함정" 경고는 0 에서 스위치로 대상만 바뀌어 그대로 유효하다.**

### 20.3.4 로그 라벨

- `skipped_rate_zero` → **`skipped_accrual_disabled`** 로 개명. 페이로드에 `{ source: 'store'|'brand', storeId, brandId }`.
- **`qoinSettlementIssues` 에 기록하지 않는다** (의도된 정책 + 빈도 높음 — §19.4 의 판단 유지).
- 신규 `skipped_invalid_enabled` 는 **기록한다** (`reason: 'invalid_enabled'`, `scope: 'store'|'brand'`). 비bool 값은 Console 편집으로만 생기고, 그 사이 완료된 주문은 **고객 돈이 영구 누락**되는 §19.4 H-2 와 완전히 같은 사건이다.

---

## 20.4 마이그레이션 — 운영에 남은 `qoinAccrualRate: 0`

운영 Firestore 에 `qoinAccrualRate: 0` 인 매장이 있다 (사용자가 라이브 검증 중 설정). **설계자는 운영 Firestore 를 읽을 수 없다** — 따라서 "몇 건인지" 를 전제하지 않는 설계로 간다.

### 20.4.1 방식 — 임시 callable + admin 허브의 1회성 카드 (dry-run 선행)

| 안 | 판단 |
|---|---|
| **임시 callable `migrateQoinZeroRates` + 허브 카드** (채택) | 사용자가 **앱에서** 대상 목록·건수를 보고 실행한다. 서비스 계정·`gcloud` 자격증명 불필요. Admin SDK 라 Rules 우회 → Rules 배포 순서와 독립. **정리 커밋에서 callable·카드·호환 분기를 함께 삭제**한다 (§20.4.5) |
| 로컬 Admin SDK 스크립트 | 사용자에게 `GOOGLE_APPLICATION_CREDENTIALS` 또는 ADC 설정을 요구한다. 1회성 작업에 환경 구성 비용이 크고, 실패 시 원인 분리가 어렵다. **기각** |
| Rules 가 과도기 동안 양쪽 해석 | Rules 는 적립률을 **읽지도 해석하지도 않는다** (쓰기 차단만 한다). 애초에 Rules 로 할 수 있는 일이 아니다. **기각** |
| 사용자가 Console 에서 수동 | 대상 수를 모른다. 매장마다 ⓐ `qoinAccrualRate` 삭제 ⓑ `qoinAccrualEnabled: false` 추가 를 **이력 없이** 수동 수행하게 되어 `audit_trail.md` §4-2·4-4 를 정면 위반한다. **기각** |

### 20.4.2 `migrateQoinZeroRates` (onCall, admin 전용, 임시)

```
요청: { dryRun: boolean }
스캔: stores where qoinAccrualRate == 0     (기존 인덱스로 충분 — 단일 필드 등식)
      brands where qoinAccrualRate == 0
      ※ 같은 스캔에서 '무효 값'(비number / 범위 밖) 도 수집해 **보고만** 한다 (자동 변환 금지)

dryRun: true  → 쓰기 0. { zeroStores: [{id, name}], zeroBrands: [...],
                          invalidStores: [{id, name, raw}], invalidBrands: [...] } 반환

dryRun: false → 대상 1건당 한 트랜잭션:
      qoinAccrualRate  : FieldValue.delete()
      qoinAccrualEnabled : false
      + {stores|brands}/{id}/qoinRateHistory/{autoId} 1건
          field 'accrualEnabled' / op 'set'
          before null / beforeState 'absent' / after false
          changedBy  실행 admin uid          ← 행위자를 남긴다 (audit_trail §4-4)
          changedByRole 'admin'
          source 'migration'                 ← 신규 source 값
          reason '적립률 0% → 적립 사용 안 함 이전 (Q1)'
          migratedFromRate 0                 ← 신규. "숫자 0 이 여기서 사라졌다" 를 박제
      멱등: 이미 qoinAccrualEnabled == false 이고 rate 가 없으면 **skip** (이력도 쓰지 않는다)
```

- 트랜잭션 1건 = 문서 1개 + 이력 1개. 대상 수가 적으므로 청크·재개 설계는 **두지 않는다** (600건을 넘으면 그때 재호출 — 멱등이므로 안전).
- **무효 값은 자동으로 손대지 않는다.** 0 은 의도가 명확하지만(= 적립 안 함) 무효 값은 의도를 추측할 수 없다 → fail-closed 원칙. 보고만 하고 사용자가 `setQoinAccrualRate` / 스위치로 정한다.

### 20.4.3 과도기 호환 분기 (배포~마이그레이션 사이의 창)

`functions` 배포 직후부터 마이그레이션 실행 전까지는 운영에 `qoinAccrualRate: 0` 이 남아 있다. 그 구간에서 `0` 을 그냥 무효로 보면 **의도된 중단이 "고객 돈 누락 사건"(`qoinSettlementIssues`) 으로 오기록**된다.

→ **판독 측에만** 좁은 호환 분기를 둔다.

```
classifyRate(0) → { kind: 'legacyZero' }        ← 읽기 전용. 과도기 한정
resolve: legacyZero 를 disabled 와 **동일 취급** (source 유지, 이슈 기록 없음,
          로그 라벨 skipped_accrual_disabled + { legacy: true })
```

- **쓰기 측에는 예외가 없다.** `isValidCallableRate(0)` = false, Rules 는 필드 자체를 차단. 0 은 **새로 만들어질 수 없다.**
- 이것은 Q1 이 없애려던 "일괄 적용의 0 skip 예외" 와 **다른 것**이다. 일괄 적용은 여전히 0 을 묻지 않는다 — 대신 아래 가드로 **아예 실행을 거부**한다.
- **일괄 적용 가드 (과도기 한정)**: `applyBrandQoinRate` 가 산하 매장 스캔 중 `qoinAccrualRate === 0` 을 하나라도 만나면 `failed-precondition` 으로 **중단**한다 (`"레거시 0% 매장 N곳이 있어요. Qoin 설정 허브에서 마이그레이션을 먼저 실행하세요"`). 응답에 `legacyZeroCount` 와 매장 ID 목록(최대 50개)을 담는다.
  - **정책 판단을 코드가 하지 않는다.** "0 을 덮을까 말까" 를 서버가 결정하는 것이 A 안이었다. 여기서는 **결정하지 않고 멈춘다** — 과도기에만 존재하고, 마이그레이션이 끝나면 조건이 영구히 거짓이 되어 함께 삭제된다.

### 20.4.4 사용자가 Console 에서 확인/조작할 것

마이그레이션 카드가 건수를 보고하므로 **Console 조작은 없다.** 확인만 한다 (선택이지만 권장 — 값이 돈이다).

| # | 위치 | 확인 |
|---|---|---|
| 1 | 앱 admin → Qoin 설정 허브 → 마이그레이션 카드 | **dry-run 결과**: 0% 매장/브랜드 목록과 건수. 기억하는 매장과 일치하는지. **무효 값 목록이 비어 있는지** (있으면 Console 편집 흔적 — 각 건의 `raw` 값을 보고 어떻게 할지 정한다) |
| 2 | 같은 카드 | 실행 후 `migrated` 건수 = dry-run 건수 인지, `skipped` 가 0 인지 |
| 3 | Firebase Console → Firestore → `stores` | 이전 대상 매장 1곳을 열어 **`qoinAccrualRate` 필드가 없고** `qoinAccrualEnabled: false` 인지 |
| 4 | 같은 매장 → `qoinRateHistory` | 이력 1건이 `source: 'migration'` / `changedBy` = 본인 uid / `migratedFromRate: 0` 으로 있는지 |
| 5 | Firebase Console → `config/qoin` | `accrualRate` 가 `0.001~0.2` 의 number 인지 (여기 0 이나 문자열이 있으면 **전역이 fail-closed** 라 전체 적립이 멈춘다) |
| 6 | 앱 admin → 해당 매장 상세 | 우선순위 사슬이 `사용 안 함` 으로 보이는지 (`0%` 로 보이면 §20.6-2 미반영) |
| 7 | 재확인 (정리 커밋 전) | dry-run 을 한 번 더 눌러 **0건** 인지. 0건이어야 §20.4.5 를 실행한다 |

### 20.4.5 정리 커밋 (마이그레이션 0건 확인 후)

한 커밋에서 함께 삭제한다. 과도기 자산이 남으면 "0 이 어딘가에서 유효하다" 는 오해가 재발한다.

1. `classifyRate` 의 `legacyZero` 분기 + `resolve` 의 동일 취급 분기 (TS·Dart 양쪽)
2. `test_fixtures/qoin_rate_truth_table.json` 의 **`resolve_legacy` 배열째** → 이때 **R16b/R16c 가 활성화**된다 (0 = `invalid_store`/`invalid_brand`)
3. `applyBrandQoinRate` 의 `legacyZeroCount` 가드
4. `migrateQoinZeroRates` callable + `index.ts` export
5. admin 허브의 마이그레이션 카드
6. 이 절(§20.4)에 완료일과 이전 건수를 기록

> **정리 완료 (2026-10-26)**: 운영 배포 후 마이그레이션 dry-run **0건**(운영에 `qoinAccrualRate: 0` 인 매장·브랜드 없음) 확인 뒤 1~5 를 한 커밋으로 삭제했다. 이전(실행) 건수는 0건이다 — 실행한 적이 없다. `legacyZero` / `isLegacyZero` / `resolve_legacy` / `transitionalExpect` / `legacyZeroCount` / `LEGACY_MESSAGE_PREFIX` / `migrateQoinZeroRates` / `migratedFromRate` 는 저장소에 0건이고, 가드 테스트(`qoin_architecture_guard_test`)의 허용 목록은 **빈 집합**이다 (양방향 단언이 그대로 남아 재도입을 막는다). R16b/R16c 가 활성화됐다 (저장된 0 = `invalid_store` / `invalid_brand`).
> 예외: `auditBrandLinks` 와 브랜드 링크 점검 카드는 `brand_authorization_hardening §4` 의 임시 자산이었으나 **상시 운영 도구로 승격**했다 (읽기 전용·쓰기 0·인자 없음, 데이터 유실 사고의 복구 검증에서 값을 했다). TRANSITIONAL 목록에서 뺐다.


---

## 20.5 쓰기 권한과 이력

### 20.5.1 스위치도 CF 전담 쓰기 + 변경 이력 대상이다

`audit_trail.md` §4-1 — "돈·권한·정책 값을 바꾸는가 → 설정 변경 이력이 기본값". 스위치는 **적립이 발생하는지 자체를 결정**하므로 적립률보다 약하지 않다. 따라서 적립률과 **완전히 동일**하게 다룬다.

- 클라이언트 직접 쓰기 **전 역할 차단** (admin 전권 분기 포함)
- 쓰기는 CF 전담 — 신규 callable **`setQoinAccrualEnabled`**
- 값 쓰기와 이력 1건을 **같은 트랜잭션** → 이력 없는 변경이 구조적으로 불가능
- 이력 컬렉션은 기존 `qoinRateHistory` 를 **그대로 재사용** (`field: 'accrualEnabled'`). 새 컬렉션을 만들지 않는다 — 컬렉션을 늘리면 collection group 조회와 Rules 가 갈라지고, "적립률 이력" 과 "스위치 이력" 을 운영자가 두 화면에서 봐야 한다
- `config/qoin.enabled`(전역 비상 정지)의 직접 쓰기 유지 결정(§19.3)은 **변동 없다.** 매장·브랜드 스위치는 비상 정지가 아니므로 같은 예외를 적용하지 않는다

### 20.5.2 `setQoinAccrualEnabled` (onCall, 신규)

```
요청: { scope: 'store'|'brand', targetId, enabled: boolean, reason? }
      scope: 'global' → invalid-argument (전역은 config/qoin.enabled, §20.3.2)
      enabled 가 bool 이 아니면 invalid-argument (진리표 callableSwitch)

1. requireAdmin (서버 재검증 — H2)
2. 일괄 적용 진행 중 거부 (§19.5-(c) 와 동일 가드: 매장이면 그 브랜드, 브랜드면 자신)
   ※ 일괄 적용이 스위치를 건드리지 않더라도 거부한다 — 진행 중 설정 변경을 금지하는
     §19.5 의 규칙은 "운영자 2명이 같은 브랜드를 동시에 만지는 것" 을 막는 것이고,
     그 목적은 스위치에도 동일하다
3. 트랜잭션: 현재 값 읽어 before 확보
   enabled == false → qoinAccrualEnabled: false
   enabled == true  → qoinAccrualEnabled: FieldValue.delete()   (부재 = 사용, §20.1.3)
   + 이력 1건 (field 'accrualEnabled', op 'set'|'clear',
               before true|false|null, beforeState 'absent'|'value'|'invalid',
               beforeRaw (비bool 일 때만), after false|null,
               changedBy uid, changedByRole 'admin', source 'callable', reason)
4. 값이 이미 같으면 아무것도 쓰지 않는다 (재시도 중복 이력 방지 — 기존 패턴)
5. 반환 { before, after, historyId | null, changed }
```

**`op` 값은 기존 `'set'|'clear'` 를 재사용**한다 (구조적 의미: 필드를 쓰는가 / 지우는가). "사용/사용 안 함" 라벨은 `(field, after)` 조합으로 화면이 만든다 — 새 enum 값을 늘리지 않는다.

### 20.5.3 `applyBrandQoinRate` 는 스위치를 읽지도 쓰지도 않는다

- 쓰기 필드 집합에 `qoinAccrualEnabled` 가 **없다.** 코드 리뷰 + 에뮬레이터 테스트로 고정한다 (일괄 실행 후 `qoinAccrualEnabled: false` 가 그대로인지).
- **읽기는 집계 목적으로만 1곳**: 산하 매장 스캔 시 `qoinAccrualEnabled == false` 인 매장 수를 세어 `disabledUntouchedCount` 로 **보고**한다 (§20.5.5). 이 값은 어떤 분기도 바꾸지 않는다 — 조건으로 쓰면 Q1 이 없앤 예외 규칙이 되살아난다.

### 20.5.4 Rules 변경 — `touchesQoinRate()` 를 필드 **집합** 헬퍼로 교체

지금 보호 대상이 1필드가 아니므로 헬퍼 이름과 형태를 바꾼다.

```
function qoinManagedFields() {
  return ['qoinAccrualRate', 'qoinAccrualEnabled',
          'qoinBulkHistoryId', 'qoinBulkStatus', 'qoinBulkAt'];   // §19.5 포인터 포함
}
function touchesQoinManaged() {               // 기존 touchesQoinRate() 교체
  return request.resource.data.diff(resource.data).affectedKeys().hasAny(qoinManagedFields());
}
function hasQoinManagedOnCreate() {           // 기존 hasQoinRateOnCreate() 교체
  return request.resource.data.keys().hasAny(qoinManagedFields());
}
```

- **필드 목록을 Rules 안에서도 1곳만** 둔다. §19.5 가 "포인터 3필드를 `touchesQoinRate()` 에 추가" 로 처리한 것을 여기서 집합 헬퍼로 일반화한다 — 다음에 또 필드가 늘 때 분기 6곳을 찾아다니지 않게 하기 위한 것이다 (1차 F1 의 교훈).
- 적용 지점은 기존과 동일: `stores` create 1곳 / `stores` update 최상위 1곳(admin 전권 포함) / `brands` create 1곳 / `brands` update 최상위 1곳.
- `config/{docId}` 블록은 **변동 없다** (`accrualRate` 차단 + `enabled` 의 `enabledChangedBy == uid()` 강제, §19.3).

### 20.5.5 F2 분류 집계 갱신 (§19.2-2 정정)

0 이 적립률 값이 아니게 되었으므로 **"0% 가 지워졌다" 는 사건이 더는 발생하지 않는다.**

| 필드 | 상태 |
|---|---|
| `clearedZeroCount` | **삭제.** 0% 개별 설정이 존재할 수 없다 (과도기에는 §20.4.3 가드가 실행 자체를 거부하므로 이 카운트가 필요한 상황도 없다) |
| `clearedValueCount` | **유지** — 유효 숫자가 지워진 매장 수 |
| `clearedInvalidCount` | **유지** — 무효 값(Console 편집)이 지워진 매장 수 |
| **`disabledUntouchedCount`** | **신규** — 산하 매장 중 `qoinAccrualEnabled == false` 라서 **일괄 적용 후에도 적립되지 않는** 매장 수. `cleared*` 가족과 **이름을 분리**한다: 지운 것이 아니라 **영향이 없었던 것**을 세는 값이다 |
| 합 불변식 | `clearedValueCount + clearedInvalidCount == clearedCount`. `disabledUntouchedCount` 는 **합에 들어가지 않는다** |

- 매장별 이력(`op: 'clearByBulk'`)은 **그대로 필수**다 (§19.2-1). 점주의 "왜 내 매장 적립률이 바뀌었나" 는 Q1 과 무관하게 남는 질문이다. 다만 `before: 0` 이 나올 수 없으므로 `before` 는 `number | null`, `beforeState` 는 `'value' | 'invalid'` 2값으로 좁아진다.
- `disabledUntouchedCount` 는 **완료 화면의 사후 고지**에도 쓴다: **"`사용 안 함` 3곳은 새 값을 받아도 적립이 시작되지 않아요."** (§20.14-N3 — "영향을 받지 않아요" 는 그 매장의 개별 요율이 실제로 지워지므로 부정확하다.) 이것이 Q1 결정을 운영자에게 설명하는 유일한 표면이다.
- **`brandDisabled: boolean` 신규** — 일괄 적용 시점에 **브랜드 자신의 스위치가 꺼져 있었는지**. N4(상위 스위치가 하위 숫자를 이긴다) 때문에 이때는 `disabledUntouchedCount` 와 무관하게 **산하 매장 전체가 적립되지 않는다.** 응답·브랜드 이력에 담고 완료 화면이 **이 고지를 우선** 표시한다: "브랜드가 `사용 안 함` 이라 산하 매장 전체가 적립되지 않아요." 이것이 없으면 admin 이 요율만 통일하고 "됐다" 고 믿는 사고가 난다.

### 20.5.6 §9 쓰기 경로 전수 — **13 → 20 경로**

보호 대상이 `qoinAccrualRate` 1필드에서 **`qoinAccrualRate` + `qoinAccrualEnabled`** 2필드로 늘었다. §9 의 "13경로" 를 아래로 갱신한다 (1~13 은 §9/§19.4 의 기존 경로, 14~20 이 추가분).

| # | 경로 | 대상 필드 | 결과 | 검증 |
|---|---|---|---|---|
| 1~5 | `stores`/`brands` 의 create·update (customer/owner/brand/**admin 전권**) | rate | ❌ 차단 | Rules 하네스 (기존) |
| 6~7 | admin 의 `config/{docId}` write·create | `accrualRate` | ❌ 차단 / `enabled` 만 ✅ | Rules 하네스 (기존) |
| 8 | `setQoinAccrualRate` CF | rate | ✅ admin 재검증 + 경계 + 이력 동일 트랜잭션 | CF 에뮬레이터 |
| 9 | `applyBrandQoinRate` CF | rate | ✅ 동일 + 멱등 재개. **스위치는 쓰지 않는다** | CF 에뮬레이터 (스위치 불변 검증 포함) |
| 10 | `onOrderQoinSettled` | rate·switch | 읽기만 | 코드 리뷰 |
| 11 | Firebase Console / Admin SDK | rate | ⚠ 막을 수 없다. `config/qoin` 만 §7.4 트리거가 사후 기록 | 설계 한계 |
| 12 | `qoinRateHistory` 직접 쓰기 | — | ❌ 전부 `if false` | Rules 하네스 |
| 13 | 점주 `stores.delete` → 같은 ID 재생성 | rate | ⚠ **수용** (재승인 필요, Q3) | Rules 하네스 (신규 3케이스) |
| **14** | customer/owner/brand 의 `stores` **update** | **switch** | ❌ `touchesQoinManaged()` | Rules 하네스 (신규) |
| **15** | owner / brand 의 `stores` **create** | **switch** | ❌ `hasQoinManagedOnCreate()` | Rules 하네스 (신규) |
| **16** | brand 의 `brands` create / update | **switch** | ❌ 동일 | Rules 하네스 (신규) |
| **17** | **admin 의 `stores`/`brands` update (전권 분기)** | **switch** | ❌ 전권에서도 이 필드 제외 | Rules 하네스 (신규) |
| **18** | **`setQoinAccrualEnabled` CF** (신규) | **switch** | ✅ admin 재검증 + bool 검증 + 이력 동일 트랜잭션 + 일괄 진행 중 거부 | CF 에뮬레이터 (신규) |
| **19** | Firebase Console / Admin SDK | **switch** | ⚠ **막을 수 없다. 감시도 없다** (`stores`/`brands` 트리거 미설치 — N6 와 동일 한계) | 설계 한계로 명시 |
| **20** | **`migrateQoinZeroRates` CF** (임시) | rate + switch | ✅ admin 재검증 + 이력 1건/건 + 멱등. **정리 커밋에서 삭제** (§20.4.5) | CF 에뮬레이터 (신규) |

**추가로, #13 의 결과가 확대된다**: 매장을 delete 후 같은 ID 로 재생성하면 적립률뿐 아니라 **스위치도 제거**된다 → 재생성 매장은 "적립 사용" 상태로 돌아온다. Q3 의 수용 근거(재생성은 `status: 'pending'` 이라 admin 재승인 전까지 주문을 받지 못하므로 적립이 발생하지 않는다)는 스위치에도 **그대로 성립**한다. 하네스 케이스 ⓒ 를 `qoinAccrualRate` **와 `qoinAccrualEnabled` 둘 다** 포함한 재생성으로 확장한다.

미봉은 **#11 · #19 · #13** 세 개이고, 모두 Firebase 의 구조적 성질 또는 명시적 수용이다.

### 20.5.7 `audit_trail.md` §4 체크리스트 — 스위치 반영 재판정 (§13 / §19.6 갱신)

| # | 체크 | 판정 | 근거 |
|---|---|---|---|
| 1 | 설정 변경 이력 | **통과** | 스위치 변경 = `qoinRateHistory` 1건 (`field: 'accrualEnabled'`), 값과 **같은 트랜잭션** |
| 2 | 덮어쓰기로 사라지는 값 | **통과** | ⓐ 매장별 이력(`clearByBulk`) 유지 ⓑ **"적립 안 함" 의도는 일괄 적용이 접근할 수 없는 필드에 있으므로 덮어써 사라지는 일이 구조적으로 불가능**해졌다 — F2 의 가장 아픈 부분이 코드가 아니라 스키마로 닫혔다 ⓒ 마이그레이션도 `migratedFromRate: 0` 으로 사라지는 0 을 박제 |
| 3 | 당시 값 박제 | **통과** | 원장은 `accrualRate` / `accrualRateSource` / `brandId`(= `store.brandId`, §19.1). 스위치가 꺼진 매장은 원장 자체가 생기지 않으므로 박제 대상이 없다 |
| 4 | "누가" | **통과 (한계 2건, 수용)** | 스위치는 callable 전담이라 `changedBy` 가 항상 있다. 마이그레이션도 실행 admin uid 를 남긴다. 한계: ⓐ `config/qoin` **Console** 편집(§9-11) ⓑ `stores`/`brands` **Console** 편집(§9-19, N6). 둘 다 구조적 |
| 5 | 일괄 = 1건 + 영향 범위 | **통과** | 브랜드 1건 + 매장 N건(`bulkHistoryId` 연결) + `clearedValueCount`/`clearedInvalidCount`/**`disabledUntouchedCount`** |
| 6 | CF 로그 의존 | **통과 (수용 1건)** | `invalid_enabled` 는 `qoinSettlementIssues` 에 Firestore 기록. `skipped_accrual_disabled` 는 **로그만** — 의도된 정책이고 빈도가 높다(노이즈). **남기지 않는 사유를 여기 명시한다**: 이 사건은 "값이 사라진 것" 이 아니라 "설정대로 동작한 것" 이고, 그 설정 자체는 스위치 이력에 영구 보존되어 있으므로 사건별 기록이 필요 없다 |

---

## 20.6 설계자가 사용자에게 미리 설명한 것 (spec 반영)

### 20.6.1 다시 켜면 0% 가 아니라 **브랜드 요율**로 적립된다

일괄 덮어쓰기 뒤 스위치를 다시 켜면, 그 매장은 **0% 가 아니라 상위(브랜드 또는 전역) 요율**로 적립을 시작한다.

```
① 매장 S: 적립률 0% 로 잠금          →  (신설계) qoinAccrualEnabled: false, rate 부재
② 브랜드 일괄 적용 (덮어쓰기, 5%)     →  S 의 rate 는 원래 부재였으므로 변화 없음.
                                        스위치는 건드리지 않음 → S 는 계속 적립 안 함
③ admin 이 S 의 스위치를 다시 켬      →  rate 부재 → 브랜드 5% 상속 → **5% 로 적립**
```

**근거**: `0%` 라는 **숫자는 애초에 저장되지 않는다.** 남는 것은 "사용 안 함" 이라는 **상태**뿐이다. 따라서 "되돌릴 0%" 라는 값이 존재하지 않는다. 의미상으로도 **"다시 켠다" = "현재 요율로 적립에 참여한다"** 가 자연스럽다 — 끄기 전의 숫자로 돌아가는 것이 아니다 (끄기 전 숫자가 브랜드 요율과 다를 이유도 없다).

> 설계자가 이 해석을 사용자에게 설명하고 **의도와 다르면 알려달라고 요청했으며, 사용자는 이의를 제기하지 않았다.** 이 해석을 확정으로 둔다. 바꾸고 싶다면 "끄기 전 숫자를 보존해 켤 때 복원" 이 필요하고, 그것은 스위치에 숫자를 딸려 보내는 설계(= 필드 2개의 정합성 유지 비용 복귀)이므로 **별도 결정이 필요하다.**

화면에도 같은 말을 쓴다 — 스위치 off 상태의 매장 상세에 보조 문구: **"다시 켜면 브랜드 5% 가 적용돼요"** (상위 유효 요율을 계산해 보여준다).

### 20.6.2 우선순위 사슬 화면은 `사용 안 함` 으로 보여야 한다

스위치가 꺼진 매장의 우선순위 사슬(`qoin_rate_chain.dart`)은 `5%` 가 **아니라 `사용 안 함`** 으로 표시한다.

```
[잘못됨]  매장 5%  ← 브랜드 5%  ← 전역 3%
[옳음]    매장 사용 안 함  (브랜드 5% · 전역 3% 는 적용되지 않음)
                 └ 다시 켜면 브랜드 5% 가 적용돼요
```

- 1차 F1 의 교훈이 그대로 적용된다 — **화면이 말하는 숫자와 실제 발행되는 돈이 달라지면 안 된다.**
- `source` 가 `'store'|'brand'` 중 어디서 꺼졌는지 보여준다 (R24 가 이 표기를 고정한다).
- 점주·브랜드 화면(§12.3 의 1행)도 `적립률 5%` 가 아니라 **`적립 사용 안 함`** 으로 보인다. 고객 화면(§12.4)은 적립률 숫자를 이미 제거했으므로(§4-⑨) 변경 없다.

### 20.6.3 F2(매장별 이력)는 이 설계에서도 그대로 필요하다

§19.2-1 의 매장별 이력(`op: 'clearByBulk'`)은 **유지**한다. 분류 집계만 §20.5.5 로 갱신된다. 근거: 일괄 덮어쓰기가 **유효 숫자**(3% → 상속)와 **무효 값**을 지우는 것은 Q1 과 무관하게 계속 일어나고, 점주가 "왜 내 매장 적립률이 바뀌었나" 를 물을 경로도 그대로다.

---

## 20.7 Q2 확정 — ⓐ 기록만 (보강)

**확정: `qoinSettlementIssues/{orderId}` 기록 수단만 이번에 만든다. 소급 적립 도구는 `backlog.md`.**

§19.4 H-2 의 설명을 아래로 보강한다 (사용자가 "무효 값" 과 "적립이 멈춘다" 의 뜻을 물었고, 설계자가 답한 내용).

### "무효 값" 이란

`qoinAccrualRate` / `qoinAccrualEnabled` 에 **정상 경로로는 들어갈 수 없는 값**이 들어간 상태다.

| 종류 | 예 | 어떻게 생기나 |
|---|---|---|
| 범위 밖 숫자 | `0.5`(50%), `-0.01`, `0.0005`(0.05%) | **Firebase Console 직접 편집 / Admin SDK** 뿐 |
| 비숫자 | `"3"`, `null`, `true`, `[]`, `NaN` | 동일 |
| 비bool 스위치 | `qoinAccrualEnabled: "false"`, `: 1` | 동일 |
| 격자 밖 숫자 | `0.0015`(0.15%) | 동일. **단 유효 범위 안이므로 무효가 아니다** — 정상 계산되고 표시만 정확히 해야 한다 (§19.4 부가 A) |

callable 은 서버 경계에서 거부하고(§10), Rules 는 필드 자체를 차단하므로(§20.5.6) **앱·Rules 경로로는 무효 값이 만들어지지 않는다.** 남는 입구는 Console / Admin SDK 하나뿐이고, 그것은 Rules 를 우회한다.

### "적립이 멈춘다" 의 뜻 — 왜 영구 누락인가

```
1. 무효 값을 만난다  → CF 는 **추측하지 않는다** (상위로 폴백하면 아무도 모르게
                        다른 금액이 발행된다 — §6 fail-closed)
2. console.error 후 **return**  → 트리거는 **정상 종료**로 처리된다
3. 정상 종료이므로 Cloud Functions 가 **재시도하지 않는다** (`retry: true` 는
                        **예외로 실패할 때만** 작동한다)
4. 값을 고쳐도 그 주문들은 **다시 처리되지 않는다** — 트리거 조건이
                        `orders` 의 `* → completed` 전이이고, 그 전이는 이미 지나갔다
5. 근거는 Cloud Logging 에만 있고 **보존 기간(30일)** 이 지나면 사라진다
   → 누구에게 얼마를 못 줬는지 **대상 목록 자체가 소멸**한다
```

**사라지는 것이 고객 돈**이므로 `audit_trail.md` §4-6("영구 보존이 필요하면 Firestore") 위반이다. 따라서 **기록 수단은 배포 전 필수**다. 기록이 없으면 나중에 소급 도구를 만들어도 **대상을 복원할 수 없다** (F2·U7 과 같은 함정).

### 소급 적립 도구를 지금 만들지 않는 이유

"어느 시점 요율로 줄 것인가" 가 **정책 결정**이다 — ⓐ 발생 시점에 의도했던 값(알 수 없다) ⓑ 수정 후 값 ⓒ 그때의 전역 기본값. 요율이 내려갔다면 ⓑ 가 고객에게 불리해질 수 있다. 기록이 쌓이면 **실제 건수와 금액을 보고** 결정하는 편이 정확하다. → `backlog.md` 신규 과제.

---

## 20.8 Q3 확정 — ⓐ 수용

**확정: F4(매장 delete → 같은 ID 재생성)를 수용한다.** 근거는 §19.4 그대로이며 스위치에도 성립한다(§20.5.6 말미).

**필수 (배포 전, 코드 변경 없음)**: `test_rules/rules.test.mjs` 에 3케이스.

| # | 케이스 | 기대 |
|---|---|---|
| ⓐ | owner 가 `qoinAccrualEnabled: false` 인 자기 매장 `delete` | **ALLOWED** |
| ⓑ | 같은 ID 로 `{ownerId, name, status: 'pending'}` 재생성 | **ALLOWED** |
| ⓒ | 같은 ID 로 `qoinAccrualRate` **또는** `qoinAccrualEnabled` 를 포함해 재생성 | **DENIED** (`hasQoinManagedOnCreate()`) |

`stores.delete` 정책(점주 삭제 허용 / 삭제 이력 없음 / 이력 서브컬렉션 고아)은 **이 spec 범위 밖** → `backlog.md` 신규 과제.

---

## 20.9 영향 범위 (Q1 추가분만)

### Core
- `lib/core/utils/qoin_policy.dart` — `explicitOffRate` 삭제, `classifyRate` 의 `allowZero` 삭제, `classifySwitch` 추가
- `lib/core/utils/qoin_rate_resolver.dart` — 스위치 2셀 추가, `disabled` 결과 추가, `legacyZero` 과도기 분기

### Domain (순수 Dart)
- `lib/domain/entities/qoin_rate_results.dart` — `EffectiveQoinRate` 에 `disabled` / `disabledSource`, `invalid_*_enabled` 사유
- `lib/domain/entities/qoin_rate_change_entity.dart` — `field` 에 `accrualEnabled`/`globalEnabled`, `source` 에 `migration`, `migratedFromRate`
- `lib/domain/entities/store_entity.dart` · `brand_entity.dart` — `qoinAccrualEnabled` (읽기 전용)
- `lib/domain/repositories/qoin_rate_repository.dart` — `setAccrualEnabled` / (임시) `migrateZeroRates`
- 신규 UseCase `SetQoinAccrualEnabledUseCase` (단일 책임)

### Data
- `lib/data/models/store_model.dart` · `brand_model.dart` — `qoinAccrualEnabled` **읽기만**. `toFirestore*` 쓰기 맵에 **넣지 않는다** (§16 규칙, test_report PASS-5 가 지키는 성질)
- `lib/data/models/qoin_rate_change_model.dart` — 신규 필드 매핑 (미지값 관대 처리)
- `qoin_rate_remote_data_source` / `repository_impl` — 신규 callable 2개

### Presentation
- `admin_qoin_store_rate_edit_page.dart` · `admin_qoin_brand_rate_edit_page.dart` — **`적립 사용` 스위치**(켜짐 = 적립함, 꺼진 상태 라벨 `사용 안 함` — §20.14-N1) + 0% 입력 경로 제거
- `widgets/qoin_rate_chain.dart` — `사용 안 함` 표시 + "다시 켜면 …" 보조 문구
- `widgets/qoin_rate_confirm_dialog.dart` — 경고/체크박스 제거, 완료 사후 고지(`disabledUntouchedCount`)
- `widgets/qoin_rate_edit_form.dart` · `qoin_rate_input_field.dart` — 0 관련 분기 제거
- `common/widgets/qoin/qoin_rate_labels.dart` · `qoin_rate_source_badge.dart` · `qoin_rate_info_row.dart` — `사용 안 함` 라벨
- `admin_qoin_settings_page.dart` — (임시) 마이그레이션 카드

### 인프라
- `functions/src/qoinRate.ts` · `setQoinAccrualEnabled.ts`(신규) · `migrateQoinZeroRates.ts`(신규, 임시) · `onOrderQoinSettled.ts` · `applyBrandQoinRate.ts` · `qoinAdmin.ts` · `index.ts`
- `firestore.rules` — `touchesQoinRate` → `touchesQoinManaged` (필드 집합 헬퍼)
- `test_fixtures/qoin_rate_truth_table.json` — §20.2.3
- **인덱스 변동 없음** (스위치는 등식 단일 필드 질의만. 기존 CG 이력 인덱스 그대로)

### 역할 흐름 / 엔티티 lifecycle
- **엔티티 status 전이 변경 없음.** 스위치는 `stores.status` / `brands.status` 와 무관한 독립 필드다 (`entity_lifecycle.md` 수정 불필요)
- `role_flows.md`: admin 흐름에 "매장·브랜드 적립 사용 토글" 1건, owner/brand 흐름에 읽기 전용 1행. ※ `role_flows.md` 가 Qoin 을 아직 **"미구현"** 으로 적고 있는 기존 drift 는 별도 과제로 `backlog.md` 에 올린다

---

## 20.10 배포 전 필수 / 배포 후 가능 (§19.7 교체)

### 배포 전 필수

| # | 내용 | Q1 반영 |
|---|---|---|
| 1 | **F1** — 브랜드 신뢰원 `store.brandId` + 원장 `brandId` 일치 + `cart.brandId` 미사용 | 변동 없음 |
| 2 | **F1 테스트** — T1 / T2 / T3 / T4 | 변동 없음 |
| 3 | **Q1 — 스위치 분리**: 필드 · `classifySwitch` · 해석 사슬 · `setQoinAccrualEnabled` · Rules 집합 헬퍼 · 진리표 §20.2.3 | **신규** |
| 4 | **Q1 — 마이그레이션**: `migrateQoinZeroRates` + 허브 카드 + 과도기 호환 분기 + 일괄 적용 레거시 가드 | **신규** |
| 5 | **F2** — 매장별 이력 + CHUNK 225 + 분류 집계(`clearedZeroCount` **삭제**, `disabledUntouchedCount` **추가**) | **갱신** |
| 6 | **F3** — `enabled` 행위자 (Rules + 앱 2필드 + 트리거) | 변동 없음 |
| 7 | **F5** — 브랜드 잠금/포인터 + 재개 재검증 + 진행 중 단건 차단(**스위치 변경도 차단**) | **갱신** |
| 8 | **H-3 D-1/D-2** — 허브 중단 판정 포인터 기반 + 에러 무음 제거 | 변동 없음 |
| 9 | **부가 B** — `beforeState` / `beforeRaw` (스위치 이력에도 적용) | **갱신** |
| 10 | **H-2 기록(Q2 ⓐ)** — `qoinSettlementIssues` (+ `reason: 'invalid_enabled'`) | **갱신** |
| 11 | **F4 하네스 3케이스(Q3 ⓐ)** + §9 **20경로** 정정 | **갱신** |
| 12 | **화면**: 우선순위 사슬 `사용 안 함` 표기 · "다시 켜면 …" 문구 · 다이얼로그 경고/체크박스 제거 | **신규** |
| 13 | **배포 순서**: §20.11 | **갱신** |

> §19.7 의 11번("H-1 사용자 결정 대기")은 **종결**됐다. Q1 이 확정이므로 대기 항목이 없다.

### 배포 후 가능

| # | 내용 |
|---|---|
| 1 | **부가 A** — 격자 밖 값 정확 표시 + `격자 밖 값(콘솔 편집)` 배지 |
| 2 | **H-3 D-3** — 전체 이력 화면 페이지네이션 |
| 3 | **Q2 소급 적립 도구** — 기록이 쌓인 뒤 정책 결정 → `backlog.md` |
| 4 | **정리 커밋(§20.4.5)** — 마이그레이션 0건 확인 후 과도기 자산 전부 삭제 |
| 5 | `stores.delete` 정책 재설계 — `backlog.md` |
| 6 | N6 — `stores`/`brands` Console 편집 감시 (`qoinAccrualEnabled` 포함) |
| 7 | `role_flows.md` 의 Qoin "미구현" drift 정정 — `backlog.md` |

---

## 20.11 배포 순서 — ⚠️ **N6 으로 재확정 (designer 지적 반영)**

### 모순의 정체

designer 지적: 마이그레이션 카드는 **새 앱 안에** 있는데, 개정 전 §20.11 은 마이그레이션을 **앱 배포 앞**에 뒀다.

**사실 확인**: 이 프로젝트에 앱 스토어 배포는 없다. **"앱 배포" = 사용자가 로컬에서 빌드해 기기에 설치하는 것**이다. 따라서 designer 가 가정한 "로컬 빌드로 카드를 쓴다" 와 개정 전 §20.11 의 "앱 배포" 는 **같은 행위**였고, 그 둘을 다른 단계로 적은 것이 모순의 정체였다. 카드를 쓰려면 앱이 먼저 깔려 있어야 한다.

### 확정 순서

```
① firestore:indexes                     ← CG 이력 쿼리 (불변)
② functions                             ← 신규 callable 2개 + 과도기 호환 분기 + 레거시 가드
③ 앱 빌드·설치 (로컬)                    ← **당긴다.** 마이그레이션 카드가 여기서 생긴다
④ firestore:rules                       ← ③ **직후.** 아래 "④ 를 ③ 바로 뒤에 두는 이유"
⑤ 마이그레이션 dry-run  → 사용자 확인 (§20.4.4 의 1·5)
⑥ 마이그레이션 실행     → 사용자 확인 (§20.4.4 의 2·3·4)
⑦ 라이브 검증 (§20.4.4 의 6)
⑧ dry-run 재확인 0건  →  정리 커밋 (§20.4.5)
```

### ③ 을 Rules 앞으로 당겨도 되는 근거 — 검증 결과

**"Rules 와 앱 빌드는 같은 배포 창" 제약의 근거는 §19.3 의 한 방향뿐이었다**: 새 Rules 가 `enabledChangedBy == uid()` 를 강제하므로 **Rules 를 먼저 올리면 구버전 앱의 비상 정지 토글이 거부된다** — 돈을 멈추는 스위치가 막히는 최악의 순서. **앱을 먼저 깔면 이 위험은 소멸한다** (거부될 구버전 앱이 그 기기에 없다). 코디네이터의 이 논리는 **맞다.**

**반대 방향(새 앱 + 구 Rules)에 위험이 있는가 — 쓰기 경로 전수 확인**

| 새 앱의 쓰기 | 구 Rules 하에서 | 판정 |
|---|---|---|
| **비상 정지 토글** — `config/qoin` 에 `{enabled, enabledChangedBy, enabledChangedAt}` write | 구 Rules 의 `config` 쓰기는 admin 에게 더 **넓다**(`accrualRate` 차단·`enabledChangedBy` 강제가 아직 없다). 추가 2필드도 통과 | ✅ **ALLOWED.** 돈을 멈추는 스위치가 막히지 않는다 |
| 적립률 설정 / **스위치 토글** / 일괄 적용 / 마이그레이션 | 전부 **CF callable**(Admin SDK) → **Rules 를 우회**한다 | ✅ Rules 버전과 무관 |
| `qoinAccrualEnabled` 를 클라이언트가 직접 쓰는 경로 | **존재하지 않는다** (CF 전담, §20.5.6 #18). 구 Rules 가 이 필드를 모르는 것은 **무해**하다 — 쓰려는 코드가 없다 | ✅ 보호 공백 0 |
| `stores`/`brands` 운영 필드 저장 (기존 화면) | 모델이 Qoin 필드를 쓰기 맵에 넣지 않는다 (test_report PASS-5) | ✅ 변동 없음 |

→ **새 앱이 구 Rules 에서 실패하는 쓰기는 없다.**

**단 하나, 읽기가 막힌다 (수용, 사용자 고지 필수)**

③~④ 구간에는 `qoinRateHistory` 3경로와 collection-group 경로가 **구 Rules 에 아예 없다** → fallback `allow read, write: if false` 로 **`permission-denied`**. 영향: ⓐ admin 허브의 "최근 변경" ⓑ 범위별 이력 화면 ⓒ 전체 이력 화면. **읽기 전용 화면뿐이고 돈 경로가 아니다.**

- 사용자가 **결함으로 오해할 가능성이 높다** (방금 D-2 로 "이력을 불러올 수 없어요 · 다시 시도" 에러 행을 넣었으므로 눈에 잘 띈다). → 배포 절차에 **"③ 직후에는 이력 화면이 권한 오류를 냅니다. ④ 를 올리면 해소됩니다"** 를 명시한다.
- **그래서 ④ 를 ③ 바로 뒤에 둔다.** 코디네이터 초안은 Rules 를 마이그레이션·검증 **뒤**(⑥)에 뒀는데, 그러면 사용자가 앱에서 결과를 확인하는 ⑤~⑦ 구간 내내 이력 화면이 깨져 있다. ④ 를 앞으로 옮기면 깨진 창이 **수 분**으로 줄고, 마이그레이션(Admin SDK)은 Rules 버전과 무관하므로 **잃는 것이 없다.**
- ④ 를 ⑤ 앞에 두어도 마이그레이션이 막히지 않는 이유: `migrateQoinZeroRates` 는 Admin SDK 다. 새 Rules 가 `qoinAccrualRate`/`qoinAccrualEnabled` 클라이언트 쓰기를 전면 차단해도 **CF 는 영향받지 않는다**.

### 비상 정지(돈을 멈추는 스위치)의 전 구간 안전성 — 제1 제약

| 구간 | 앱 | Rules | 토글 | 근거 |
|---|---|---|---|---|
| ①~② | 구버전 | 구버전 | ✅ | 기존 동작 (CF 배포는 토글 경로에 없다) |
| ③~④ 사이 | **신버전** | 구버전 | ✅ | 구 Rules 가 더 넓다. 추가 2필드도 통과 |
| ④ 이후 | 신버전 | 신버전 | ✅ | 새 앱이 `enabledChangedBy` 를 보낸다 |
| (해당 없음) | 구버전 | 신버전 | ❌ | **이 조합이 발생하는 구간이 없다** — ③ 이 ④ 보다 앞이므로 |

- 전 구간에서 비상 정지는 **클라이언트 직접 쓰기 1회**이고 **CF 에 의존하지 않는다** (§19.3 의 성질 보존). 인덱스에도 의존하지 않는다.
- ⚠️ **사용자 확인 필요 사항(결정이 아니라 조작 지시)**: admin 조작에 쓰는 기기가 **2대 이상**이면, ④ 이후 **구버전 빌드가 남은 기기의 비상 정지 토글은 거부된다**. ③ 에서 **admin 용 기기 전부에 새 빌드를 설치**하거나, 비상 정지는 새 빌드 기기에서만 조작한다. 배포 절차에 명시한다.

### 롤백

④ 이후 문제가 생기면 **Rules 만 되돌리지 않는다** (새 앱이 쓰는 필드 보호가 사라진다). 되돌림 단위는 **③+④ 를 함께** — 구버전 빌드를 다시 설치하고 구 Rules 로 되돌린다. `functions`(②)는 과도기 호환 분기 덕에 **구 앱과도 호환**되므로 되돌리지 않아도 된다 (레거시 0 을 그대로 "사용 안 함" 으로 읽는다).

## 20.12 작업 분배 (§19.8 교체)

### designer — **호출 필요** (배포 전)

`design.md` 에 증분 추가. 제약 그대로: `AppColors` 만, 신규 색 토큰 0 목표.

| # | 항목 | 배포 |
|---|---|---|
| 1 | **매장/브랜드 적립률 편집 화면의 `적립 사용` 스위치**(켜짐 = 적립함. §20.14-N1) — 적립률 입력란과 **시각적으로 분리**된 독립 섹션. 켜짐/꺼짐 상태의 카피, 꺼짐일 때 입력란의 처리(비활성 vs 그대로 — **그대로 두는 쪽을 권장**: 숫자와 스위치가 독립임을 화면이 말해야 한다), 끄기 확인 다이얼로그 | 배포 전 |
| 2 | **우선순위 사슬의 `사용 안 함` 표기** (§20.6.2) — 매장/브랜드 중 어디서 꺼졌는지 + 보조 문구 "다시 켜면 브랜드 5% 가 적용돼요" | 배포 전 |
| 3 | **일괄 적용 다이얼로그** — 경고 줄("적립 안 함 N곳도 다시 적립해요")과 **체크박스 제거**(§20.14-N2). 정보 줄은 **"`사용 안 함` N곳은 새 값을 받아도 적립이 시작되지 않아요"**(§20.14-N3 — "영향을 받지 않아요" 는 개별 요율이 지워지므로 부정확하다) + **완료 화면의 사후 고지**(`disabledUntouchedCount`). **브랜드 자신이 꺼져 있으면**(`brandDisabled`) "브랜드가 `사용 안 함` 이라 산하 매장 전체가 적립되지 않아요" 를 **우선** 표시 (§20.14-N4) | 배포 전 |
| 4 | **점주/브랜드 읽기 1행** (§12.3) — `적립률 5%` 대신 `사용 안 함` | 배포 전 |
| 5 | **매장 이력 화면** — `field: 'accrualEnabled'` 행 표기("적립 사용 → 사용 안 함" / "사용 안 함 → 적립 사용"), `source: 'migration'` 행 표기, `op: 'clearByBulk'` 행 + `bulkHistoryId` 연결 | 배포 전 |
| 6 | **허브 partial 배너의 에러 상태** + "최근 변경" 에러 행 (로딩/에러/없음 3상태) — §19.8-2 유지 | 배포 전 |
| 7 | **(임시) 마이그레이션 카드** — dry-run 결과(0% 목록 / 무효 값 목록) · 실행 버튼 · 결과 표시. **정리 커밋에서 삭제됨을 전제로 최소 구성** | 배포 전 |
| 8 | `격자 밖 값(콘솔 편집)` 배지 / 전체 이력 더 보기 | 배포 후 |

### developer — **호출 필요** (designer 완료 후, 파일 단위)

**백엔드 (TS)**

| 파일 | 작업 |
|---|---|
| `functions/src/qoinRate.ts` | ① `RateCell` 에서 `zero` **삭제**, `classifyRate` 의 `allowZero` **삭제** ② `SwitchCell` + `classifySwitch` 신규 ③ `resolveEffectiveRate` 를 §20.3.1 5입력으로 교체, `disabled` 결과 + `invalid_*_enabled` 추가 ④ `isValidCallableRate` 의 `allowZero` 삭제(0 항상 거부) ⑤ **과도기**: `legacyZero` 분기 ⑥ 격자 왕복 헬퍼(부가 A) ⑦ TS 경계 상수는 여기 1곳 유지 |
| `functions/src/setQoinAccrualEnabled.ts` | **신규** — §20.5.2 전체 |
| `functions/src/migrateQoinZeroRates.ts` | **신규(임시)** — §20.4.2 전체. dry-run 우선 |
| `functions/src/onOrderQoinSettled.ts` | ① 스위치 2셀을 해석에 투입(추가 read **0** — `stores`/`brands` 문서를 이미 읽는다) ② `skipped_rate_zero` → `skipped_accrual_disabled`(+`source`, `legacy`) ③ `invalid_enabled` 를 `qoinSettlementIssues` 에 기록 ④ §19.1 분(브랜드 신뢰원·원장 `brandId`)은 그대로 |
| `functions/src/applyBrandQoinRate.ts` | ① 쓰기 필드 집합에 스위치 **없음**(고정) ② 스캔 시 `qoinAccrualEnabled == false` 수를 세어 `disabledUntouchedCount` **보고만** ③ `clearedZeroCount` **삭제** ④ **과도기**: `qoinAccrualRate === 0` 발견 시 `failed-precondition` + `legacyZeroCount` ⑤ §19.5 분(포인터·재개 재검증·CHUNK 225·매장별 이력)은 그대로 |
| `functions/src/setQoinAccrualRate.ts` | ① 0 입력 거부(`allowZero` 제거의 귀결) ② 일괄 진행 중 거부 ③ `beforeState`/`beforeRaw` |
| `functions/src/onQoinConfigWritten.ts` | ① 이력 `field` 를 `'globalEnabled'` 로 ② `enabledChangedBy` → `source: 'app_direct'`(§19.3) ③ `beforeState`/`beforeRaw` |
| `functions/src/qoinAdmin.ts` · `index.ts` | 신규 callable 2개 export + `historyCollection` 재사용 |
| `firestore.rules` | ① `touchesQoinRate`/`hasQoinRateOnCreate` → **`touchesQoinManaged`/`hasQoinManagedOnCreate`** (필드 집합 1곳, §20.5.4) ② 적용 지점 4곳(stores create·update / brands create·update) ③ `config/qoin` 의 `enabledChangedBy == uid()` 강제(§19.3) ④ `qoinSettlementIssues`: `read: isAdmin()`, 쓰기 `if false` |
| `firestore.indexes.json` | CG 이력 인덱스 확정. **변동 없음**(스위치는 인덱스 불요) |
| `functions/src/verifyTossPayment.ts` | §19.1 분 그대로 — `cart.brandId` 미사용 + `buildOrderData`/`buildOrderLogData` 분리(T1/T2) |

**앱 (Dart)**

| 파일 | 작업 |
|---|---|
| `lib/core/utils/qoin_policy.dart` | `explicitOffRate` **삭제**, `classifyRate` 의 `allowZero` **삭제**, `classifySwitch` 추가, 격자 왕복(부가 A). Dart 경계 상수는 여기 1곳 유지 |
| `lib/core/utils/qoin_rate_resolver.dart` | §20.3.1 로 교체 + `legacyZero` 과도기 분기 |
| `lib/domain/entities/qoin_rate_results.dart` | `disabled` / `disabledSource` / `invalid_*_enabled` |
| `lib/domain/entities/qoin_rate_change_entity.dart` + `.model` | `field` 3값 / `source` 에 `migration`·`app_direct` / `beforeState` / `beforeRaw` / `bulkHistoryId` / `migratedFromRate` / `disabledUntouchedCount` (미지값 관대 처리) |
| `lib/domain/entities/store_entity.dart` · `brand_entity.dart` | `qoinAccrualEnabled` (읽기 전용) |
| `lib/data/models/store_model.dart` · `brand_model.dart` | 읽기만. **쓰기 맵에 넣지 않는다** (PASS-5 성질 보존) |
| `lib/domain/repositories/qoin_rate_repository.dart` + impl + datasource | `setAccrualEnabled` / (임시) `migrateZeroRates` |
| `lib/domain/usecases/qoin/` | `SetQoinAccrualEnabledUseCase` 신규 (단일 책임) |
| `admin_qoin_store_rate_edit_page.dart` · `admin_qoin_brand_rate_edit_page.dart` | 토글 섹션 + 0% 입력 경로 제거 |
| `widgets/qoin_rate_chain.dart` | `사용 안 함` + "다시 켜면 …" |
| `widgets/qoin_rate_confirm_dialog.dart` | 경고·체크박스 제거 + 완료 사후 고지 |
| `widgets/qoin_rate_edit_form.dart` · `qoin_rate_input_field.dart` | 0 분기 제거 |
| `common/widgets/qoin/qoin_rate_labels.dart` · `qoin_rate_source_badge.dart` · `qoin_rate_info_row.dart` | 라벨 |
| `admin_qoin_settings_page.dart` | `_PartialSection` 포인터 기반 + 에러 렌더(§19.8) / **(임시) 마이그레이션 카드** |
| `admin_qoin_rate_history_page.dart` | 신규 `field`·`source` 표기 / 페이지네이션(배포 후) |

**테스트**

- `test_fixtures/qoin_rate_truth_table.json` — §20.2.3 전체 (**resolve 32** / resolve_legacy 3 / classify 13 / classifySwitch 7 / callable 12 / callableSwitch 4). **Dart·TS 양쪽이 같은 파일을 읽는 규칙 유지**
- `functions/test/emulator.test.mjs` — ① **일괄 적용 후 `qoinAccrualEnabled: false` 가 불변**(Q1 핵심 회귀) ② 스위치 off 매장은 적립 0 / **회수는 통과**(§20.3.3) ③ 스위치 off + 전역 설정 부재 → `qoinSettlementIssues` **미기록**(R25) ④ `invalid_enabled` → 기록 ⑤ 레거시 0 매장 있는 브랜드의 일괄 적용 **거부** ⑥ 마이그레이션 멱등(2회 실행 → 이력 1건) ⑦ §19.8 의 기존 항목 전건(T1/T3/동시 호출/재개/매장별 이력) ⑧ 주문은 `buildOrderData` 로 생성
- `test_rules/rules.test.mjs` — ① 스위치 차단 4경로(#14~17, create·update·admin 전권) ② F4 3케이스(ⓒ 는 두 필드 모두) ③ `enabledChangedBy` 불일치 DENY · 일치 ALLOW ④ `qoinSettlementIssues` 쓰기 DENY ⑤ 포인터 3필드 차단 ⑥ **기존 163건 전건 PASS 회귀**
- Dart — `classifySwitch` / 해석 사슬 26+3행 / `_cartToMap` 키 골든(T2) / 이력 모델 신규 필드 / 라벨
- 보고 필수: ⓐ 적립 1건당 **실제 read 수·라운드트립 수**(브랜드 매장 / 비브랜드 매장) — 스위치 추가로 **증가 0** 이어야 한다 ⓑ `grep` 으로 `explicitOffRate` / `allowZero` / `clearedZeroCount` / `skipped_rate_zero` **잔존 0건** ⓒ Rules 하네스·flutter test 전건 회귀

### tester — 재검증 (developer 완료 후)

중점: ① **일괄 덮어쓰기 후에도 `적립 사용 안 함` 매장이 적립되지 않는지** (Q1 의 수용 기준 — 코드 추론이 아니라 에뮬레이터 재현) ② 스위치 off 매장의 **회수 통과** ③ 진리표 **32**+3+13+7+12+4 행이 Dart·TS 양쪽에서 같은 파일로 도는지 (특히 **R06 의 반전**과 R21b·R22b·R23b) ④ 0 이 어느 쓰기 경로로도 들어가지 않는지(§20.5.6 의 20경로 **독립 열거**) ⑤ 마이그레이션 멱등·이력·행위자 ⑥ 과도기 자산이 §20.4.5 목록 그대로 **삭제 가능한 형태로 모여 있는지** ⑦ T1~T4 가 F1 클래스를 막는지(주문을 손으로 시드하는 테스트 잔존 0건) ⑧ §20.5.7 체크리스트 6항목 ⑨ **실결제 0회**

---

## 20.13 남은 사용자 결정사항

**없다.** Q1 / Q2 / Q3 전건 확정이며, Q1 의 세부 설계(필드 형태 · `QoinRateSetting` 재정의 · 스위치의 사슬 위치 · 브랜드 스위치 범위 · 마이그레이션 방식)는 설계자가 §20.1~§20.4 에서 근거와 함께 확정했다.

설계자 판단으로 확정한 것 중 **되돌리려면 비용이 드는 3건**을 기록해 둔다 (사용자가 다르게 원하면 지금이 가장 싸다).

| # | 확정 내용 | 다르게 하려면 |
|---|---|---|
| 1 | **다시 켜면 상위(브랜드) 요율로 적립** — 끄기 전 숫자를 보존하지 않는다 (§20.6.1) | 스위치에 "끄기 전 숫자" 를 딸려 저장해야 한다 → 필드 2개의 정합성 유지 비용이 돌아온다 |
| 2 | **브랜드 단계에도 스위치를 둔다** (§20.3.2) | 빼면 현행 설계의 브랜드 단위 적립 중단(R05) 기능이 사라진다 |
| 3 | **0 을 적립률 입력값으로 완전 금지** (§20.2.1) | 0 저장을 허용하면 "적립 안 함" 의 출처가 2개가 되고 Q1 이 고친 문제가 부분적으로 재발한다 |

---

# 20.14 designer 확인 사항 8건 — 설계자 판정 (2026-10-22)

입력: `design.md` §18-15 의 N1~N8. **전건 처리됐다. 미결 0건.**

| # | 사항 | 판정 | 결과 |
|---|---|---|---|
| **N1** | 스위치 극성·제목 (`적립 사용 안 함` 토글이 이중 부정) | **designer 안 (a) 수용** | spec 용어를 **`적립 사용` 스위치**(켜짐 = 적립함, 꺼진 상태 라벨 `사용 안 함`)로 **정정했다** (§20.9 · §20.12). designer 지적이 맞다 — "켜면 멈춘다" 는 **돈이 멈추는 방향의 오조작**을 늘린다. 저장 형태는 불변(`qoinAccrualEnabled: false` = 중단, 부재 = 사용) |
| **N2** | 체크박스 제거 유지 | **수용 (유지)** | 경고 plate + `덮어쓰고 적용` 동사 버튼이 남아 있고, 지워지는 개별 요율은 매장별 `clearByBulk` 이력에 박제된다(§19.2-1). **마찰의 총량이 줄지 않았다** — 체크박스는 "읽었다" 를 받는 장치였고, 그 역할은 이제 **사후 추적 가능성**이 대신한다 |
| **N3** | 정보 줄 문구 | **designer 안 수용. spec 쪽을 정정했다** | `…3곳은 영향을 받지 않아요` → **`사용 안 함` N곳은 새 값을 받아도 적립이 시작되지 않아요**. 덮어쓰기는 그 매장의 **개별 요율을 실제로 지우므로** "영향 없음" 은 거짓이었다. §20.5.5 · §20.12-3 반영 |
| **N4** | 브랜드 스위치 off 와 개별 요율 매장 | **사용자 결정 A — 전부 멈춘다.** §20.3.1 개정 | 해석 사슬·규칙·진리표 R06 반전 + R21b·R22b·R23b 신규. designer 가 제기한 사유(설명 불가능한 인과)를 §20.3.1 에 근거 ⓒ 로 기록 |
| **N5** | 꺼진 매장도 개별 숫자는 남는다 (R04b) | **수용. N4 의 영향 있음 — 조건이 붙는다** | R04b(**매장** 스위치 off + 개별 숫자 유지)는 **불변**이다. 그러나 **다시 켰을 때 그 숫자가 적용되는지는 브랜드 스위치에 달린다** — 브랜드가 꺼져 있으면 켜도 적립되지 않는다(R23b). 따라서 사슬 하단 문장의 **A 경우가 D 경우에 가려진다** (아래 developer 특이사항) |
| **N6** | 마이그레이션 카드 배포 순서 모순 | **모순 확인. §20.11 재확정** | 앱 설치를 Rules 앞으로 당기고(③), Rules 를 그 직후(④)에 둔다. 비상 정지가 전 구간 안전함을 표로 검증. designer 의 "로컬 빌드" 가정이 사실상 맞았고, spec 쪽이 "앱 배포" 를 별개 단계로 적은 것이 오류였다 |
| **N7** | 허브 배너 탭 동작 (이력 필터 → 브랜드 편집/목록) | **수용 (현행)** | H-3 의 요구는 "**인덱스 미배포·에러 상황과 독립**하게 중단이 보여야 한다"(§19.5 D-1)였다. 탭 목적지가 CG 이력 쿼리에 의존하면 그 요구가 다시 깨진다. designer 판단이 D-1 의 취지에 맞다 |
| **N8** | 점주에게 브랜드 이력 링크를 보일지 | **설계자 판정: 숨긴다 (designer 기본값 확정).** developer 재량 아님 | 아래 §20.14-N8 |

---

## 20.14-N4 — developer / designer 에게 전달할 특이사항

### designer 재호출: **필요 (소폭, 배포 전)**

문구 3건이 N4 로 **사실과 달라졌다.** 돈의 동작을 말하는 문장이고, 틀리면 1차 F1 과 같은 종류("화면과 돈이 어긋난다")의 결함이 된다. 범위를 좁혀 재호출한다.

| # | `design.md` 위치 | 현재 (N4 전) | 고쳐야 할 내용 |
|---|---|---|---|
| 1 | §18-3 **브랜드 줄이 꺼져서 매장이 멈춘 경우** 의 보조 문장 — `이 매장만 적립하려면 '직접 설정' 으로 적립률을 정하세요` | 개별 요율을 정하면 그 매장은 적립된다는 뜻 | **A안에서는 불가능하다.** 개별 요율을 정해도 브랜드가 꺼져 있으면 적립되지 않는다(R22b·R23b). → `브랜드의 '적립 사용' 을 켜야 이 매장이 적립해요` 로 교체. **"개별 요율로 우회" 를 암시하는 표현을 모두 제거** |
| 2 | §18-3 `QoinReenableHint` 표의 **우선순위** | A(개별 요율) 가 먼저 읽히게 배열 | **D(브랜드 꺼짐) 가 A 보다 앞선다.** 해석을 한 번 더 돌리는 구조(§18-3 주석 2) 자체는 그대로 맞으므로 **함수는 자동으로 옳아진다** — 표의 서술 순서와 A 경우 각주("매장에 개별 적립률이 실제로 남아 있으면 스위치를 켜도 그 숫자가 적용된다")에 **"브랜드가 켜져 있을 때" 전제**를 명시 |
| 3 | §18-15 **N4 행** + 브랜드 끄기 확인 다이얼로그의 영향 줄 | "개별 적립률이 있는 M곳은 계속 적립" / "덮어쓰기 시 그때 멈춘다" | **"산하 매장 전부가 멈춥니다 (개별 적립률이 있는 M곳도 포함)"** 로 재작성. 그리고 §20.3.1 의 운영 지침을 한 줄 넣는다 — **"일부 매장만 멈추려면 브랜드는 켠 채 매장별로 끄세요"** |
| 4 | 일괄 적용 완료 화면 | `disabledUntouchedCount` 고지만 | **`brandDisabled` 고지를 우선 표시**("브랜드가 `사용 안 함` 이라 산하 매장 전체가 적립되지 않아요") — 신규 상태 1개 (§20.5.5) |

> N1·N2·N3·N5·N7 은 designer 안이 그대로 확정이므로 **design.md 수정 불필요**하다 (spec 쪽을 고쳤다). N6 는 배포 절차 문서이므로 design.md 와 무관하다.

### developer 작업 변경분 (§20.12 에 대한 델타)

| 파일 | 변경분 |
|---|---|
| `functions/src/qoinRate.ts` | `resolveEffectiveRate` 를 **§20.3.1 개정판**으로 — 스위치 2개를 숫자보다 **앞에서 모두** 평가, `disabled` 를 `invalid` 보다 **앞에서** 판정. ⚠️ 개정 전 초안대로 "매장요율 → 브랜드스위치" 순서로 쓰면 **R06 이 깨진다** |
| `lib/core/utils/qoin_rate_resolver.dart` | 동일 (Dart·TS 분기 순서가 같아야 한다 — test_report PASS-7 이 지키는 성질) |
| `functions/src/applyBrandQoinRate.ts` | **`brandDisabled: boolean` 추가** — 트랜잭션에서 이미 읽는 `brands/{id}` 의 `qoinAccrualEnabled` 를 보고 응답·브랜드 이력에 담는다 (**추가 read 0**). `clearedZeroCount` 삭제 / `disabledUntouchedCount` 는 그대로 |
| `lib/presentation/.../qoin_rate_confirm_dialog.dart` | N3 문구 + **`brandDisabled` 고지 우선 표시** |
| 사슬·힌트 위젯 (`qoin_rate_chain.dart`) | `QoinReenableHint` 는 **해석 함수를 재사용**하므로 resolver 수정만으로 D 가 A 를 앞선다. **문장을 위젯에서 따로 조립하지 말 것** (design §18-3 주석 2). 하드코딩된 "직접 설정으로 우회" 문장만 교체 |
| `admin_qoin_*_edit_page.dart` | N1 — 스위치 제목 `적립 사용`, 켜짐 = 적립함 |

### 테스트 — **1순위 회귀로 추가**

| # | 케이스 | 기대 |
|---|---|---|
| **1 (최우선)** | **브랜드 스위치 off + 산하 매장에 개별 적립률 10% + 주문 완료** | **적립 0.** 원장 문서 생성 없음. 로그 `skipped_accrual_disabled { source: 'brand' }`. `qoinSettlementIssues` **미기록** |
| 2 | 같은 상태에서 **환불** | **회수는 통과**한다 (§20.3.3 — 스위치는 적립만 막는다) |
| 3 | 브랜드 switch off + 매장 switch `true` 명시 | 적립 0 (R23b) — "명시적 true 는 예외가 아니다" |
| 4 | 브랜드 switch 무효(`1`) + 매장 개별 요율 10% | 적립 0 + `qoinSettlementIssues` **기록**(`invalid_enabled`, scope `brand`) (R22b) |
| 5 | 매장 switch 무효 + 브랜드 switch off | 적립 0 + **기록 없음** (R21b — `disabled` 가 `invalid` 보다 앞) |
| 6 | 브랜드 switch off 상태로 일괄 적용 실행 | 응답·이력에 `brandDisabled: true` |

`test_rules/rules.test.mjs` 요구는 변동 없다 (스위치 차단 4경로 + F4 3케이스 + 기존 회귀).

---

## 20.14-N8 — 점주의 브랜드 이력 열람 권한: **읽을 수 없다. 링크를 숨긴다**

`firestore.rules` 실측 결과로 판정했다 (developer 에게 미루지 않는다).

```
match /brands/{brandId}/qoinRateHistory/{historyId} {
  allow read: if isAdmin() || isBrandHolder(brandId);
}
function isBrandHolder(brandId) {
  return isBrand() && userDoc().get('brandId','') == brandId;   // role == 'brand' 필수
}
match /{path=**}/qoinRateHistory/{historyId} { allow read: if isAdmin(); }
```

- 가맹점주는 `role == 'owner'` 다. `isBrand()` 가 거짓이므로 `isBrandHolder` 도 거짓 → **브랜드 이력 문서를 읽을 수 없다.**
- collection-group 와일드카드도 `isAdmin()` 만 주므로 **우회 경로가 없다.** 링크를 노출하면 점주는 반드시 `permission-denied` 를 만난다 → **designer 의 "숨김" 기본값은 취향이 아니라 Rules 가 강제하는 결론**이다.

### 열어주지 않는 이유 (Rules 를 완화하지 않는다)

| 근거 | 내용 |
|---|---|
| 정보 경계 | 브랜드 이력에는 **다른 가맹점 전체에 대한 일괄 조작**과 브랜드 요율 변경사가 들어 있다. 가맹점주 1명에게 형제 매장의 정책 이력을 주는 것은 소유권 경계를 넘는다 |
| Rules 비용 | 허용하려면 이력 문서마다 `get(stores/...)` 역조인이 필요하다 — §4-⑤ 가 최상위 이력 컬렉션 안을 **기각한 바로 그 비용**(get 호출 한도)이다 |
| 필요가 없다 | 점주가 알아야 할 사실은 **자기 매장 이력 1건**(`op: 'clearByBulk'`)에 전부 있다 — 지워진 이전 값(`before`/`beforeState`) · 시각 · 실행 admin · `bulkMode`. "왜 내 매장 적립률이 바뀌었나" 가 그 1건으로 답된다(§19.2-1 의 설계 목적) |

### 확정 사항

- `bulkHistoryId` 는 문서에 **그대로 유지**한다. 단 그것은 **admin 용 상관 키**이고 점주용 링크가 아니다.
- UI: `op: 'clearByBulk'` 행은 **문장으로만** 표기("브랜드 일괄 적용으로 초기화 · 이전 값 3%"). **탭 타깃을 만들지 않는다.** admin / 해당 브랜드 보유자에게만 브랜드 이력으로 가는 링크를 붙인다 (뷰어 역할로 분기).
- Rules 변경 **없음.** 하네스에 회귀 1건 추가: **owner 가 자기 매장이 소속된 브랜드의 `qoinRateHistory` 읽기 → DENIED.** 지금 동작을 고정해 다음 사람이 "열어도 되나" 를 다시 묻지 않게 한다.

---

## 20.14 남은 사용자 결정사항

**없다.** N1~N8 전건 판정 완료이고, N4 는 사용자 결정(A)을, N6 는 코디네이터 확인 사실("앱 배포 = 로컬 빌드")을 반영했다.

**결정이 아니라 조작 지시 1건** — §20.11 에 기록했다: admin 조작용 기기가 2대 이상이면 ③ 단계에서 **전 기기에 새 빌드를 설치**한다. 그러지 않으면 ④(Rules) 이후 구버전 빌드가 남은 기기에서 **비상 정지 토글이 거부**된다.

---

# 21. 3차 — 2차 검증 FAIL 6건 처리 (2026-10-22, 배포 전)

> **§21 이 최신이다.** §20 과 충돌하면 §21 을 따른다. 입력: `test_report.md` "2차" 절(S1~S6 + 정정 4건 + 보류 1건), 대상 커밋 `2caf3d3`.
>
> **사용자 결정 2건은 확정이며 되돌리지 않는다**: ⓐ 보안 구멍을 이번 배포에 포함 ⓑ FAIL 6건을 배포 전에 전부 고친다.
>
> **S4 는 이 문서에 없다.** Qoin 범위 밖이므로 [`docs/tasks/brand_authorization_hardening/spec.md`](../brand_authorization_hardening/spec.md) 로 분리했다. 배포는 같은 창에서 함께 나간다 (§21.6).

| FAIL | 처리 | 산출물 |
|---|---|---|
| S1 배너 출처 불일치 | §21.1 + §21.7(재발 방지) | design 신규 항목 → developer |
| S2 포인터를 지울 수 없다 | §21.2 — **설계자 확정. 사용자 결정 불요** | developer |
| S3 빈 이력 / `changed` 미소비 | §21.3 | design 문구 + developer |
| S4 Rules 보안 | 별도 task | `brand_authorization_hardening/spec.md` |
| S5 `data_ownership.md` 드리프트 | §21.5 — **설계자가 직접 갱신 완료** | 문서 (완료) |
| S6 과도기 마커 불완전 | §21.4 | developer (가드 테스트) |

---

## 21.1 S1 — 중단 판정의 출처를 포인터 하나로 모은다

### 결함의 정체

허브·브랜드 목록은 **브랜드 문서의 포인터**로, 브랜드 편집 페이지만 **이력 스트림**(`qoinRateHistoryProvider(brand, limit 20)`)으로 같은 사실을 판정한다. 두 방향으로 깨진다 (tester 위젯 테스트 PROBE1/PROBE3).

- 포인터 `partial` + 이력 읽기 실패 → 편집 페이지에 **배너·`이어서 적용`·에러가 전부 없다.** 유일한 복구 버튼이 그 화면에만 있으므로 허브 배너 탭 → **막다른 길**이다.
- 포인터는 종결됐는데 옛 이력이 `partial` → **거짓 경고 + 항상 실패하는 버튼**이 영구히 남는다.
- 중단 뒤 단건·스위치 변경이 20건 쌓이면 포인터가 `partial` 인데 배너가 사라진다 (같은 뿌리).

### 확정 — 판정 함수 1개, 호출 지점 3개

**중단 판정은 `BrandEntity` 의 포인터만 본다. 이력 스트림은 판정에 쓰지 않는다.**

```
domain (순수 Dart, 신규 1곳)
  QoinBulkBanner resolveBulkBanner(BrandEntity brand, DateTime now)

    brand.qoinBulkStatus == partial                        -> unfinished(partial)
    brand.qoinBulkStatus == inProgress
        && now - brand.qoinBulkAt > BULK_STALE             -> unfinished(stale)
    그 외 (null · completed · superseded · 신선한 inProgress) -> none
```

- **본문의 처리 수/전체 수는 `brand.qoinBulkHistoryId` 로 이력 문서 1건을 읽어 채운다.** 그 읽기가 실패하거나 문서가 없으면 **숫자만 생략**하고 **배너와 `이어서 적용` 버튼은 유지**한다. 스트림(`limit 20`)이 아니라 **문서 1건 직접 읽기**다 — CG 인덱스에 의존하지 않고 20건 창 문제도 없다.
- 호출 지점 3개(허브 배너 / 브랜드 목록 태그 / 브랜드 편집 페이지 배너)가 **같은 함수**를 쓴다. 화면이 포인터 필드를 직접 비교하지 않는다.
- `QoinPartialBanner` 는 이미 3곳 공용 위젯이다(design §18 항목 11·166). 바뀌는 것은 **그 위젯에 넣는 상태를 누가 만드는가**다.

### H-3 가 이 화면에 그대로 적용된다

1차 H-3 판정("배너가 에러일 때 사라지면 '중단 없음' 과 '알 수 없음' 이 화면상 같아진다 — 안전 측 실패가 아니다")은 **표면마다 다시 적용돼야 하는 요구**였다. 포인터는 브랜드 문서와 같은 스트림으로 오므로 그 읽기가 실패하면 **브랜드 편집 페이지 자체가 에러 상태**다 → "중단 없음" 으로 오독될 화면이 남지 않는다. 숫자 보조 읽기만 실패하면 배너는 남고 숫자가 빈다. **이것이 S1 의 수용 기준이다.**

→ 재발 방지는 §21.7.

---

## 21.2 S2 — 중단 상태의 종결 (설계자 확정, 사용자 결정 불요)

### 규정이 없었던 것

포인터 `partial` 뒤에 ⓐ 브랜드 단건 변경 ⓑ 스위치 토글 ⓒ preserve 적용 중 하나를 하면 포인터가 `partial` + 옛 id 로 남아 **허브 경고가 영구화**되고 재개는 항상 거부된다. 같은 값이고 남은 개별 설정이 0 이면 noop 이라 **지울 방법이 없다.**

### 선택지와 판단

| 안 | 판단 |
|---|---|
| ⓐ admin 수동 동작 `중단 기록 닫기` 버튼 | **기각.** 데이터가 그대로인데 경고만 끄는 장치다. 운영자가 "안 보이게" 눌러 치우는 길을 열면 중단 경고가 신뢰를 잃는다. 표면이 하나 늘어 S1 과 같은 드리프트 후보가 된다 |
| ⓑ 포인터 TTL (오래되면 자동 소멸) | **기각.** 시간이 지났다는 것이 "처리됐다" 를 뜻하지 않는다. 미적용 매장이 남은 채 경고만 사라진다 — **안전 측 실패가 아니다** (H-3 와 같은 종류) |
| ⓒ **포인터를 지우지 않고 종결 상태로 전이시킨다** (채택) | 포인터는 **지워지는 값이 아니라 상태 기계**가 된다. 신규 필드 0, Rules 변경 0, 인덱스 변경 0. 같은 변경이 **S3 의 빈 이력까지 함께 닫는다**(§21.3) |

### 확정 — 포인터는 상태 기계이고 종결 상태를 가진다

`qoinBulkStatus` ∈ `in_progress` · `partial` · **`completed`** · **`superseded`** (뒤 2개 신규). **포인터 3필드를 삭제하지 않는다.** `qoinBulkHistoryId` 는 항상 마지막 시도를, `qoinBulkAt` 은 마지막 전이 시각을 가리킨다.

| 전이 | 하는 곳 | 결과 |
|---|---|---|
| → `in_progress` | `applyBrandQoinRate` overwrite 시작 | 기존과 동일 (잠금) |
| → `completed` | overwrite 정상 완료 / preserve 완료 | **삭제 대신 `completed`.** `resolveBulkBanner` 가 `none` 으로 읽는다 |
| → `partial` | overwrite 중단 | 기존과 동일 |
| `partial` → `superseded` | **포인터를 쓰는 모든 CF 경로**가 성공할 때: 새 `applyBrandQoinRate`(preserve·overwrite 모두) · `setQoinAccrualRate`(브랜드) · `setQoinAccrualEnabled`(브랜드) | 옛 이력 문서를 `status: 'superseded'` + `supersededBy`(새 historyId 또는 null) + `supersededAt` + `supersededByUid` 로 **마감**하고, 포인터는 새 시도의 것으로 교체되거나 `superseded` 로 전이한다. **같은 트랜잭션** |
| `partial` → `completed` | same-value overwrite 인데 지울 개별 설정이 0 인 경우 (§21.3 의 "남은 일이 없다") | 새 이력을 만들지 않고 **옛 이력을 `completed` 로 마감** (`closedReason: 'nothing_left'`, `closedBy: uid`) + 포인터 `completed`. 응답 `{ changed: false, closed: true }` |

이로써 **"지울 방법이 없는 상태" 가 존재하지 않는다**: 설정을 바꾸면 superseded 로 닫히고, 아무것도 안 바뀌었지만 남은 일도 없으면 completed 로 닫힌다. 남은 일이 **실제로 있는** 경우에만 `partial` 이 유지되고, 그때 `이어서 적용` 은 유효하다.

- **거짓 경고 + 항상 실패하는 버튼(PROBE3)도 함께 사라진다.** 옛 이력이 영구 `partial` 로 남지 않는다.
- **구버전 앱 호환**: `QoinBulkStatus.fromCode` 는 모르는 코드에 null 을 돌려주고, 포인터 null = 판정 `none` 이다. ② functions 배포 후 ③ 설치 전까지 구 앱은 `completed`/`superseded` 를 "중단 없음" 으로 읽는다 — **의미가 정확히 일치**하므로 과도기 창이 안전하다 (추가 조치 불요).
- `op` 에 새 값을 만들지 않는다. 마감은 기존 이력 문서의 `status` 전이다.
- **Rules·인덱스 변동 없음**: 3필드는 이미 `qoinManagedFields()` 에 있다. 허브의 `partial` 조회는 CG 이력이 아니라 브랜드 문서를 읽으므로 인덱스가 늘지 않는다.
- **이력 문서를 삭제하지 않는다** (`audit_trail.md` — append-only 성질 보존). 마감은 상태 필드 전이다.

---

## 21.3 S3 — 빈 이력을 만들지 않는다 + `changed` 를 화면이 말한다

### (a) 빈 이력 — 오래된 스캔을 트랜잭션 안에서 불신한다

`scanStores` 는 트랜잭션 **밖**이다. 첫 호출이 1500곳을 전부 지운 뒤 트랜잭션에 도달한 호출은 `sameValue` + **스캔의 `withOverride=1500`** 을 믿고 "할 일 있음" 으로 판단해 포인터를 잠그고 **빈 이력**을 만든다 (tester 실측: 3동시 → 이력 3건, 실제 1 + 빈 2, 응답 모두 `changed=true`).

**확정 가드** — §21.2 의 종결 상태가 이것을 그대로 닫는다.

```
scanStartedAt = Date.now()            // 스캔 직전
scan = await scanStores(...)
runTransaction:
   snap = get(brandRef)
   if isBulkInProgress(snap)                        -> failed-precondition   (기존)
   sameValue 계산                                     (기존)
   # 신규 — 스캔 무효화
   if sameValue
      && snap.qoinBulkStatus in {completed, superseded}
      && snap.qoinBulkAt > scanStartedAt            -> { changed:false, staleScan:true }
   if sameValue && (preserve || scan.withOverride == 0)
      -> partial 포인터가 남아 있으면 §21.2 의 partial→completed 마감
         아니면 { changed:false }                     (기존)
```

- 성립 근거: 포인터가 **종결 상태**이고 그 전이 시각이 **내 스캔 시작보다 뒤**라면, 다른 호출이 내 스캔 이후에 일괄 적용을 **끝까지 마쳤다**는 뜻이다. 끝까지 마쳤다면 지울 개별 설정은 남아 있지 않다 → 내 `withOverride` 는 반드시 낡은 값이다. **`partial` 은 이 가드에 넣지 않는다** — 그때는 실제로 남은 일이 있으므로 진행해야 한다.
- 실패 방향: `qoinBulkAt` 은 Firestore 서버 시각, `scanStartedAt` 은 함수 컨테이너 시각이다. 컨테이너 시각이 앞서면 가드가 **발동하지 않고** 현행 동작(빈 이력)으로 떨어진다 — 더 나빠지지 않는다. 뒤서면 할 일이 있는데 noop 이 되는데, 그때 화면이 `이미 같은 값이에요` 를 말하고 admin 이 다시 누르면 **새 스캔**이 실제 값을 읽는다. **양쪽 모두 돈에 영향이 없다.** developer 는 가드 발동을 `console.warn` 으로 남긴다.
- **단언 정정**: implementation 개정 2 의 "브랜드 이력 1건" 불변식은 틀렸다(`clearedCount>0` 인 이력만 세어 통과했다). 테스트는 **브랜드 이력 문서 수 자체**를 세야 한다 (§21.8).

### (b) `changed` 를 화면이 소비한다 — "했는데 아무 일도 안 일어났다"

Dart 어디에서도 `changed` 를 읽지 않는다(tester grep: presentation·usecases 소비 0). 결과 카드는 `status == completed` 만 보고 noop 에도 **"적용을 마쳤어요 · 적용된 매장 0곳"** 을 그린다.

**확정**: `changed == false` 는 **적용 결과가 아니라 "바뀐 것이 없음"** 으로 말한다. 적용 결과 카드를 그리지 않는다.

| 경로 | `changed == false` 일 때 |
|---|---|
| `applyBrandQoinRate` (일괄) | 결과 카드 대신 **`이미 같은 값이에요` 안내**. `closed: true` 면 한 줄 추가: `끝나지 않은 일괄 적용은 처리가 끝나 있어서 닫았어요`. 카운트 행(적용된 매장 / 초기화된 개별 설정)은 **보이지 않는다** |
| `setQoinAccrualRate` (단건) | SnackBar `이미 같은 값이에요` (현재는 값이 같아도 "변경했어요" 라고 말할 가능성이 크다 — tester 코드 확인). **설계자 판정: 고친다.** 돈의 값을 바꿨다고 말하는 문장이 거짓이면 운영자가 "바뀐 줄 알고" 화면을 떠난다 |
| `setQoinAccrualEnabled` (스위치) | 동일. 이미 응답에 `changed` 가 있다 (§20.5.2-5) |
| `staleScan: true` | 사용자에게 구분해 보여주지 않는다 (`이미 같은 값이에요` 로 수렴). 서버 로그로만 구분한다 — 운영자가 알아야 할 사실이 아니다 |

**불변식 (가드 테스트 대상)**: Qoin 쓰기 callable 의 응답을 소비하는 모든 화면은 `changed` 를 읽는다. 읽지 않고 성공 문구를 그리는 경로가 있으면 FAIL.

---

## 21.4 S6 — 정리 커밋이 안전하게 되도록

마커(`TRANSITIONAL(spec §20.4.5)`)가 붙은 파일은 21개지만, **마커 없이 레거시 분기를 가진 파일이 7개**다: `qoin_rate_chain.dart`(L120) · `qoin_reenable_hint.dart`(L58·64·93·97) · `qoin_config_model.dart`(L24) · `functions/test/emulator.test.mjs`(섹션 I·`expectOf`) · `test/data/qoin_rate_models_test.dart` · `test/presentation/qoin_hub_states_test.dart` · `test_fixtures/qoin_rate_truth_table.json`(`resolve_legacy`·`transitionalExpect` — JSON 이라 주석 불가). 마커 grep 으로만 정리하면 컴파일이 깨진다.

**마커를 더 붙이는 것으로는 닫히지 않는다.** 다음에 레거시 분기를 추가하는 사람이 마커를 빠뜨리면 같은 일이 반복된다. **기계가 목록을 강제하게** 만든다.

### 확정 — 과도기 자산 목록을 테스트가 소유한다

1. **마커를 7개 파일에 추가**한다. JSON 은 주석이 불가하므로 최상위 메타 키를 둔다:
   ```json
   { "_transitional": { "ref": "spec §20.4.5",
                        "arrays": ["resolve_legacy"],
                        "keys": ["transitionalExpect"] }, ... }
   ```
2. **`qoin_architecture_guard_test` 를 확장**한다 (현재 3개 파일만 확인).
   - **레거시 토큰 집합**을 테스트에 선언한다: `legacyZero` · `isLegacyZero` · `QoinRateCellKind.legacyZero` · `resolve_legacy` · `transitionalExpect` · `legacyZeroCount` · `LEGACY_MESSAGE_PREFIX` · `migrateQoinZeroRates` · `migratedFromRate` · `auditBrandLinks`.
   - 저장소 전체(`lib/` `functions/src/` `functions/test/` `test/` `test_fixtures/`)를 그 토큰으로 grep 해서 **나온 파일 집합이 테스트에 적힌 허용 목록과 정확히 같은지** 단언한다 (초과도 FAIL, 누락도 FAIL).
   - 그 허용 목록에 적힌 **모든** 파일에 마커(또는 JSON 메타 키)가 있는지 단언한다.
   - **마커를 grep 하지 않는다. 레거시를 실제로 만드는 토큰을 grep 한다.** 마커는 사람에게 보여주는 표지이고, 기계가 보는 것은 토큰이다. 이 역전이 S6 의 핵심 수정이다.
3. **정리 커밋 절차**를 spec §20.4.5 에 추가한다 (아래 6·7 신규):
   6. 허용 목록 파일 전체에서 토큰 제거 → 가드 테스트의 허용 목록을 **빈 집합**으로 만든다
   7. `flutter analyze` 이슈 0 · `flutter test` 전건 · `npm --prefix functions test` 전건 · Rules 하네스 전건이 **모두 통과**해야 커밋한다. 하나라도 실패하면 정리 커밋을 쪼개지 않고 되돌린다
4. 선행 조건은 불변: **마이그레이션 dry-run 0건**(§20.4.4 의 7) + `auditBrandLinks` 0건(보안 task §4.3 의 6).

---

## 21.5 S5 — `data_ownership.md` 드리프트 (설계자가 직접 갱신했다)

| tester 지적 | 조치 |
|---|---|
| L119·L219 가 없는 함수명(`hasQoinRateOnCreate()` / `touchesQoinRate()`) | `hasQoinManagedOnCreate()` / `touchesQoinManaged()` 로 교정 + 보호 필드 **집합**임을 §2.5 / §2.11.1 양쪽에 명시 |
| L118·L121·L159 가 `qoinAccrualRate` 만 말한다 | 보호 필드 5개 집합으로 교체 |
| 포인터 3필드를 설명하는 곳이 없다 | **§2.11.1b 신설** — 의미 · 작성자(`applyBrandQoinRate` 만) · 읽는 쪽(허브·브랜드 목록·브랜드 편집) · 상태 기계(§21.2) |
| §2.11.5 가 "미구현" 인데 구현됐다 / `skipped_rate_zero` 는 삭제됨 | 제목에서 "미구현" 제거 + 사유 코드를 현재 코드와 일치시킴(`skipped_accrual_disabled` 는 기록하지 않음, `skipped_invalid_enabled` 는 기록) |
| L120 "pending 은 주문·적립 불가" 가 서버 보증이 아니다 | **문서만 고칠 문제가 아니다 — 판정했다.** 아래 |

### L120 — 실제로 보증해야 하는가

**사실**: `verifyTossPayment` 는 `stores` 를 읽지 않고(grep 0) 적립 트리거도 `status` 를 보지 않는다. 즉 `pending` 매장도 callable 직접 호출로 결제가 성립하고, 성립한 주문은 적립된다. **UI 에서만 막힌다.**

**판정**:

1. **문서는 즉시 교정한다** — "서버가 보증하지 않는다. UI 차단뿐이다" 로 적는다. 완료.
2. **§20.5.6 #13(Q3 수용)의 근거가 약해진다.** 수용 문장은 "재생성 매장은 `pending` 이라 재승인 전까지 주문·적립이 없다" 였는데 그 전제가 서버 보증이 아니다. 실제 잔여 위험: **적립이 중단(`qoinAccrualEnabled: false`)된 매장의 점주가 자기 매장을 삭제·재생성해 중단 상태를 지우고, 미승인 상태로 직접 호출 결제를 태워 적립을 재개할 수 있다.** 돈이 나가는 방향이다. **#13 의 수용은 유지하되 근거를 이 사실로 교체**했다 (아래 §21.5-#13).
3. **게이트를 지금 넣는 것은 설계자가 단독 확정하지 않는다.** 결제 거부는 **돈이 멈추는 방향**의 실패이고, 매장 `status` 데이터가 틀어진 한 건이 정상 결제를 막는다. 이번 배포는 이미 Rules·CF·앱·마이그레이션이 한 창에 들어가 있어 결제 경로를 같이 건드리면 실패 시 원인 분리가 어렵다. → **사용자 질문 Q-S1** (`brand_authorization_hardening/spec.md` §9 에 1건으로 통합. 설계자 추천: 별도 task)

### §20.5.6 #13 의 수용 근거 교체

| | 내용 |
|---|---|
| 기존 근거 | 재생성 매장은 `status: 'pending'` 이라 재승인 전까지 주문·적립이 발생하지 않는다 |
| **정정** | 그 보증은 **UI 에만** 있다. 수용 근거는 ⓐ 실행에 **점주 본인의 SDK 직접 조작**이 필요하다 ⓑ 재생성은 개별 요율과 스위치를 **둘 다 지우므로** 결과는 "브랜드/전역 요율로 적립" 이고 임의 요율을 **올릴 수는 없다**(상한은 브랜드 또는 전역) ⓒ 재생성된 매장은 admin 승인 화면에 `pending` 으로 다시 올라오므로 **사후에 보인다** 로 교체한다. 잔여 위험은 "중단 상태의 우회" 1건이고 금액 상한은 상위 계층 요율이다 |
| 후속 | Q-S1 ⓐ 를 택하면 이 경로는 서버에서 닫힌다. ⓑ 면 `backlog.md` 에 남는다 |

---

## 21.6 배포 순서 — 재확인 결과 **변경 없음**

보안 Rules 수정(별도 task §7)이 들어와도 §20.11 의 순서를 **그대로 쓴다.**

```
① indexes → ② functions → ③ 앱 빌드·설치 → ④ rules
→ ⑤ 브랜드 링크 점검(신규, auditBrandLinks) → ⑥ 마이그레이션 dry-run → ⑦ 실행
→ ⑧ 라이브 검증 → ⑨ dry-run·점검 재확인 0건 → ⑩ 정리 커밋
```

| 재확인 항목 | 결과 |
|---|---|
| 보안 Rules 를 어느 단계에 넣는가 | **④ 그대로.** 별도 단계를 만들지 않는다 — Rules 배포는 파일 1개의 원자적 교체이고, Qoin 보호 필드와 `users`/`isBrandHolder`/`stores` create 변경을 **다른 시점에 올릴 방법이 없다** |
| ③ → ④ 순서가 여전히 맞는가 | **더 강하게 맞다.** ④ 가 먼저면 구버전 앱의 **브랜드 신규 등록이 전면 실패**한다(batch 에 `users.brandId` 가 있어 batch 전체 거부). 기존에는 비상 정지 토글 하나가 근거였고, 이제 근거가 2개다 |
| 새 앱 + 구 Rules(③~④ 구간)에 새 위험이 생겼는가 | **없다.** 새 앱이 `users.brandId` 를 **더 이상 쓰지 않고** `claimSubmittedBrand`(CF, Rules 우회)를 쓴다. 구 Rules 는 그 결과를 막을 수 없다. 승인 화면 강화는 읽기뿐이다 |
| 비상 정지가 전 구간 안전한가 | **그대로 안전하다.** 보안 task 는 `config/{docId}` 블록을 건드리지 않는다. Qoin 쪽에서 추가되는 `enabledChangedAt == request.time`(§21.9-1)은 **④ 이후**에만 걸리고, 새 앱은 `FieldValue.serverTimestamp()` 를 보내므로(`qoin_remote_data_source.dart` L71) `request.time` 과 일치해 통과한다. ③~④ 구간은 구 Rules 라 무조건 통과. **구버전 앱 + 신 Rules 조합이 발생하는 구간은 없다** |
| ⚠️ 조작 지시 (재강조) | **admin 조작용 기기가 2대 이상이면 ③ 에서 전 기기에 새 빌드를 설치한다.** ④ 이후 구버전 빌드가 남은 기기에서는 ⓐ 비상 정지 토글(`enabledChangedAt` 미강제 → 거부) ⓑ 브랜드 신규 등록(batch 거부) **둘 다** 막힌다. 근거가 하나 늘었다 |
| ⑤ 를 ④ 뒤에 두는 이유 | `auditBrandLinks` 는 Admin SDK 라 Rules 와 무관하지만, **구멍이 닫힌 뒤에 세어야** 집계 중에 새 오염이 들어오지 않는다. 또 점검 카드가 ③ 의 산출물이므로 ③ 뒤여야 한다 |
| 롤백 단위 | **③+④ 를 함께** (변동 없음). ②(functions)는 구 앱과 호환되므로 되돌리지 않는다 |
| ③~④ 구간 고지 (tester 요청 반영) | 기존 "이력 화면이 권한 오류" 고지에 **한 줄 추가**: ~~"브랜드 편집 페이지의 중단 배너도 보이지 않는다"~~ → **S1 수정 후에는 보인다.** 포인터는 브랜드 문서에서 오고 브랜드 문서 read 는 구 Rules 에서도 열려 있다. 고지는 "본문의 처리 수/전체 수만 비어 보인다" 로 **완화**된다 |

---

## 21.7 재발 방지 — "같은 패턴이 다른 화면에 남는" 문제 (H-3 → S1)

**개별 화면을 하나씩 고치는 방식이면 또 놓친다.** H-3 를 허브에서 고쳤는데 같은 결함이 브랜드 편집 페이지에 남은 이유는, design §18-8 이 **"허브" 라는 표면 1개만 규정**했기 때문이다. 명세가 표면을 1개로 가정하면 구현도 1개만 고친다.

### 규칙 (이 저장소의 상시 규칙으로 승격한다)

**R1. 한 사실에는 하나의 판정 함수.**
돈·중단·정책 상태를 화면에 말하는 판정은 **domain 의 단일 함수**를 통과한다. 화면은 그 결과만 렌더하고 원시 필드·스트림을 직접 비교하지 않는다. 출처가 둘 이상(포인터 vs 이력 스트림)이면 설계 결함으로 본다.

**R2. 표면 인벤토리를 spec 에 표로 둔다.** 한 사실 = 한 행이고, 그 사실을 말하는 **모든 화면을 전수 열거**한다. 열마다 ⓐ 판정 출처 ⓑ **출처 읽기가 실패했을 때 무엇이 보이는가** ⓒ 복구 동작이 있는가 를 채운다. **ⓑ 가 빈 칸이면 미설계다** (H-3 의 요구가 바로 ⓑ 였다). 새 화면을 추가하면서 이 표에 행을 추가하지 않으면 리뷰 FAIL.

**R3. 기계로 고정한다.** 가드 테스트가 "판정 함수 밖에서 원시 출처를 읽는 곳이 없다" 를 grep 으로 단언한다. S1 에 대한 구체 단언: `isUnfinished(` 호출과 `qoinBulkStatus` 직접 비교는 **`resolveBulkBanner` 가 있는 파일 1곳**에서만 나온다.

**R4. 알림과 복구를 같은 곳에 두거나, 알림에서 복구로 가는 길이 깨지지 않음을 증명한다.** S1 의 치명도는 "유일한 복구 버튼이 깨진 화면에만 있다" 에서 왔다. **알리는 곳과 고치는 곳이 다르면 그 경로는 테스트 대상**이다.

**R5. tester 상시 항목.** "같은 사실을 말하는 표면을 전수 열거했는가" 를 `tester_guide.md` 체크리스트에 올린다 (이번 분배에 포함).

### 이번 적용 — 중단(partial) 사실의 표면 인벤토리

| 표면 | 판정 출처 | 출처 실패 시 | 복구 동작 |
|---|---|---|---|
| admin 허브 배너 | `resolveBulkBanner(brand)` | 브랜드 목록 자체가 에러 → `QoinLoadError` + `다시 시도` | 없음 (알림 전용) → 편집 페이지로 이동 |
| 브랜드 목록 태그 `적용 중단됨` | 같은 함수 | 목록 에러 행 | 없음 |
| 브랜드 편집 페이지 배너 | 같은 함수 | 브랜드 문서 에러 → 페이지 에러. **보조 숫자 읽기 실패 시 배너·버튼 유지, 숫자만 생략** | **`이어서 적용`** (유일) |
| 이력 행의 `partial` plate | 이력 문서 자신의 `status` (그 행이 **그 문서에 대한 표시**이므로 출처가 같다 — 판정이 아니라 렌더다) | 이력 화면 에러 행 | admin 에게만 `이어서 적용` |
| 점주·브랜드 읽기 화면 | 같은 함수 (plate 만, 버튼 없음) | 상위 화면 에러 | 없음 |

`superseded`/`completed` 이력 행은 `partial` plate 를 **그리지 않는다** (§21.2).

---

## 21.8 작업 분배

### designer — **호출 필요 (소폭, 배포 전)**

| # | 항목 | 근거 |
|---|---|---|
| 1 | **§18-8 에 "브랜드 편집 페이지" 항목 추가** — 판정은 포인터, 본문 숫자는 `qoinBulkHistoryId` 로 읽는 이력 1건, **숫자 읽기 실패 시 배너·버튼 유지 + 숫자만 생략**. §21.7-R2 의 표면 인벤토리 표를 design 에 그대로 옮긴다 (§18-8 을 "허브만" 규정한 것이 S1 의 원인이다) | S1 |
| 2 | **`이미 같은 값이에요` 상태** — 일괄 결과 카드의 신규 분기(카운트 행 없음), 단건·스위치 SnackBar 문구. `closed: true` 일 때의 한 줄 | S3-(b) |
| 3 | **`적용 중단됨` 태그·배너가 사라지는 조건** 문구 보정 — 포인터가 종결(`completed`/`superseded`)되면 아무것도 보이지 않는다. "중단 기록 닫기" 같은 **사용자 동작은 없다** (§21.2-ⓐ 기각) | S2 |
| 4 | **일괄 완료 화면의 K 줄 숨김을 form 섹션에도 적용** — design 에 한 줄 추가 (tester "과하지 않다" 판정, 문서 후행) | 정정 |
| 5 | **매장 승인 상세 화면** — 브랜드 이름(폴백 금지) + **상속될 적립률** + 미존재/비승인 브랜드 warning plate + 승인 버튼 비활성 | 보안 task D5 |
| 6 | **`_BrandIdMissingView`** — "브랜드 연결 중" / 자동 재연결 실패 안내 / 중복 등록 안내 3분기 | 보안 task D1-2 |
| 7 | **(임시) 브랜드 링크 점검 카드** — 5분류 목록·건수. 마이그레이션 카드와 같은 형태, 정리 커밋에서 삭제 전제 | 보안 task §4.1 |

제약 그대로: `AppColors` 만, 신규 색 토큰 0 목표. **신규 화면은 없다** — 전부 기존 화면의 상태 추가다.

### developer — **파일 단위** (designer 완료 후)

**백엔드 (TS)**

| 파일 | 작업 |
|---|---|
| `functions/src/applyBrandQoinRate.ts` | ① 완료 시 포인터 **삭제 → `completed`** (§21.2) ② `partial` 포인터 발견 시 `superseded` 마감(옛 이력 문서 + 포인터, 같은 트랜잭션) ③ `scanStartedAt` 가드 — 종결 포인터가 스캔보다 뒤면 `{changed:false, staleScan:true}` + `console.warn` (§21.3-a) ④ same-value + 남은 일 0 + 포인터 `partial` → 옛 이력 `completed`(`closedReason:'nothing_left'`) + `{changed:false, closed:true}` ⑤ preserve 완료도 `completed` 포인터를 남긴다 |
| `functions/src/setQoinAccrualRate.ts` | ① 브랜드 scope 성공 시 `partial` 포인터 `superseded` 마감 ② **레거시 0 가드 추가** (§21.9-2) ③ `changed` 반환 보장 |
| `functions/src/setQoinAccrualEnabled.ts` | ① 브랜드 scope 성공 시 `superseded` 마감 ② `changed` 반환 (이미 있음 — 유지) |
| `functions/src/qoinRate.ts` | `QoinBulkStatus` 에 `completed`·`superseded` 추가(TS 측 상수). 판정 헬퍼는 포인터 1곳 |
| `firestore.rules` | ① `config/{docId}`: `enabled` 변경 시 `request.resource.data.enabledChangedAt == request.time` 요구 (§21.9-1) ② 보안 task 의 D1·D2·D5 + `roleHistory` 블록 |
| `functions/src/claimSubmittedBrand.ts` | **신규** — 보안 task D1 |
| `functions/src/auditBrandLinks.ts` | **신규(임시)** — 보안 task §4.1. `TRANSITIONAL(brand_authorization_hardening §4)` |
| `functions/src/migrateQoinZeroRates.ts` | `describeRaw` — bool·배열·객체를 따옴표로 감싸지 않는다 (§21.9-4) |
| `functions/src/index.ts` | 신규 callable 2개 export |

**앱 (Dart)**

| 파일 | 작업 |
|---|---|
| `lib/domain/entities/qoin_bulk_banner.dart` (신규) 또는 `qoin_rate_change_entity.dart` | **`resolveBulkBanner(BrandEntity, DateTime)`** 단일 판정 함수 (§21.1). `QoinBulkStatus` 에 `completed`·`superseded` 코드 추가, 미지 코드는 null 유지 |
| `admin_qoin_brand_rate_edit_page.dart` | 배너 판정을 **이력 스트림 → `resolveBulkBanner`** 로 교체. 본문 숫자는 `qoinBulkHistoryId` 로 **이력 문서 1건** 읽기(신규 provider), 실패 시 숫자만 생략 |
| `admin_qoin_settings_page.dart` | `_PartialSection` 을 같은 함수로 통일 + (임시) 브랜드 링크 점검 카드 |
| 브랜드 목록(태그) 화면 | 같은 함수로 통일 |
| `widgets/qoin_rate_confirm_dialog.dart` / 결과 카드 | `changed == false` → `이미 같은 값이에요`(카운트 행 없음), `closed` 한 줄 (§21.3-b) |
| 단건·스위치 호출 지점 (usecase → 화면) | `changed` 를 반환·소비. SnackBar 분기 |
| `lib/domain/repositories/qoin_rate_repository.dart` + impl + datasource | 응답의 `changed`/`closed`/`staleScan` 전달 (미지 키 관대) |
| `lib/data/repositories/brand_repository_impl.dart` | `upsertBrand` 신규 분기: batch 에서 **`users` 쓰기 제거**, 브랜드 문서 1건 → `claimSubmittedBrand` 호출 |
| `_BrandIdMissingView` + brand providers | `brands where submittedBy == uid` 조회 + 자동 재연결 3분기 |
| `admin_store_approval_detail_page.dart` · `brand_scope_badge.dart` | 브랜드 이름 폴백 금지 + 상속 적립률 + 미존재/비승인 경고 + 승인 버튼 비활성 |
| 마커 7개 파일 | `TRANSITIONAL` 주석 / JSON `_transitional` 메타 키 (§21.4-1) |

**테스트**

- `test/.../qoin_architecture_guard_test.dart` — ① **레거시 토큰 집합 ↔ 허용 목록 일치** 단언 (§21.4-2) ② `isUnfinished(`·`qoinBulkStatus` 직접 비교가 판정 함수 파일 1곳에만 있는지 (§21.7-R3) ③ Qoin 쓰기 응답 소비 지점이 `changed` 를 읽는지
- `functions/test/` — ① **브랜드 이력 문서 수 자체**로 세는 동시 호출 테스트 (1500곳 3동시 → 이력 **1건**) ② `partial` 뒤 preserve / 단건 / 스위치 → 포인터 `superseded`, 허브 판정 `none`, 옛 이력 `superseded` ③ `partial` + 남은 개별 설정 0 + same value → `closed: true`, 포인터 `completed` ④ `completed` 포인터 뒤 같은 값 재적용(스캔 신선) → 정상 진행 ⑤ 보안 task CF1~CF8
- `test_rules/rules.test.mjs` — ① 보안 task **RM01~RM20** ② `enabled` 변경 시 `enabledChangedAt` 생략 → **DENY**, `serverTimestamp` 동반 → ALLOW ③ 기존 전건 회귀
- Dart 위젯 — ① 포인터 `partial` + 이력 읽기 실패 → 배너·버튼 **있음**(PROBE1 회귀 핀) ② 포인터 종결 + 옛 이력 `partial` → 배너 **없음**(PROBE3 회귀 핀) ③ `changed:false` → `이미 같은 값이에요`
- 보고 필수: ⓐ 적립 1건당 read 수 **증가 0** ⓑ `grep` 잔존 0건 (기존 목록 + `qoinBulkStatus` 직접 비교) ⓒ 전건 회귀

### tester — 재검증

중점: ① S1 양방향(PROBE1/PROBE3) **재현으로** 확인 ② `partial` 종결 4경로(새 apply·preserve·단건·스위치) + `nothing_left` 닫기 ③ 1500곳 3동시 → **이력 1건** ④ `changed:false` 가 화면에 "적용" 으로 보이지 않는지 ⑤ **RM 스위트가 역할을 변조하며 때리는지** (고정 시드 재사용 0) + `brandId` 필드가 **없는** 매장 케이스(RM07)가 D2 없이는 ALLOW 임을 확인 ⑥ `claimSubmittedBrand` 멱등·이력·행위자 ⑦ 브랜드 전환 흐름 9단계(보안 task D1-2) **처음부터 끝까지** 1회 ⑧ 과도기 토큰 ↔ 허용 목록 일치가 기계로 단언되는지 ⑨ `audit_trail.md` §4 6항목 (Qoin §20.5.7 + 보안 task §6) ⑩ 실결제 0회

### 설계자 (완료)

- `docs/processes/data_ownership.md` 갱신 (§21.5)
- `docs/processes/audit_trail.md` A4 행 갱신
- `docs/backlog.md` 신규 항목
- `docs/tasks/brand_authorization_hardening/spec.md` 신규

---

## 21.9 tester 정정 4건 + 보류 1건 — 설계자 판정

### 1. `enabledChangedAt` 미강제 → **고친다 (Rules 1줄)**

developer 의 "시각 위조는 가능하나 안전 측" 은 **사유가 틀렸다.** tester 정정이 맞다.

- 시각 위조는 무해하다: 이력의 `changedAt` 은 `serverTimestamp` 이고 행위자는 `enabledChangedBy == uid()` 로 사칭 불가.
- **실제 틈은 생략이다.** `enabledChangedBy` 만 쓰거나, 이전에 토글한 **같은 admin** 이 `enabled` 만 단독으로 쓰면 통과하고, 이력이 `source:'direct'` / `changedBy:null` 로 남아 **행위자가 지워진다.** 에뮬레이터 실측으로 확인됐다.
- `audit_trail.md` **§4-4("누가 가 기록되는가")에 정면으로 걸린다.** 그리고 대상이 **비상 정지** — 돈을 멈추는 조작이고, 사고 조사에서 "누가 멈췄나" 를 가장 먼저 묻는 값이다. `onQoinConfigWritten` 이 `source` 를 `enabledChangedAt` 변동으로 판정하므로, 생략형은 **Console 편집과 구별되지 않는다** — 앱에서 한 조작이 Console 편집으로 기록된다.
- **판정: 고친다.** `config/{docId}` update 에서 `enabled` 가 affectedKeys 에 있으면 `request.resource.data.enabledChangedAt == request.time` 을 요구한다.
- **안전성**: 새 앱은 `FieldValue.serverTimestamp()` 를 보내므로(`qoin_remote_data_source.dart` L71) `request.time` 과 같아 통과한다. 비상 정지가 막히는 조합은 **구버전 앱 + 신 Rules** 뿐이고 그 구간은 발생하지 않는다 (§21.6). 그래도 "전 기기에 새 빌드" 지시의 근거가 하나 늘었으므로 §21.6 에 재강조했다.

### 2. 단건 `setQoinAccrualRate` 에 레거시 0 가드 없음 → **추가한다**

UI 는 브랜드 쓰기를 항상 일괄 CF 로 보내므로 admin 직접 호출만 해당한다(낮음). 그래도 추가한다: ⓐ **비용이 한 줄**이고 ⓑ 정리 커밋에서 **어차피 함께 삭제**되는 코드이고 ⓒ "보호가 한 경로에만 걸려 있다" 가 1차 F1 의 사고 형태였다. 과도기 자산이므로 §21.4 의 허용 목록에 포함한다.

### 3. K 줄 숨김을 form 섹션에도 적용 → **수용. design 에 한 줄 추가** (§21.8 designer-4)

브랜드가 꺼져 있으면 산하 **전체**가 멈추므로 "어느 쪽을 골라도 적립이 시작되지 않아요" 는 부분 사실이 되어 전체 정지 plate 와 모순된다. design §18 의 규칙을 같은 이유로 확장한 것이고, **코드가 앞서갔으니 문서를 맞춘다** (코드를 되돌리지 않는다).

### 4. 마이그레이션 `raw` 표시 — bool·배열·객체에 따옴표가 덧붙는다 → **고친다 (낮음)**

표시 전용 결함이지만 `raw` 의 **존재 이유가 "어떤 타입의 쓰레기 값이 들어 있나" 를 보여주는 것**이다. `true` 가 `"true"` 로 보이면 그 목적이 깨져 사용자가 Console 에서 잘못된 판단을 한다(§20.4.4 의 1 — 사용자가 `raw` 를 보고 처리 방법을 정한다). `describeRaw` 가 bool·배열·객체를 그대로 직렬화한다.

### 5. 보류 — 실기기 `FirebaseFunctionsException.details` 가 `Map` 인지 → **라이브 검증 항목으로 넘긴다**

에뮬레이터·위젯 테스트로 확인 불가하고, 플러그인이 `additionalData` 를 넘기는 경로는 **실기기에서만** 재현된다. 실패 시 영향은 "레거시 가드 문구가 일반 실패 문구로 보인다" 로 **읽기 전용·돈 무영향**이고, 폴백 문구도 실패를 정확히 알린다(안전 측). 배포를 막지 않는다.

**§20.4.4 에 라이브 검증 1행을 추가한다**: 레거시 `qoinAccrualRate: 0` 매장이 하나 있는 브랜드에서 일괄 적용(`덮어쓰고 적용`) → **"레거시 0% 매장이 있어요 (N곳)"** 가 뜨면 PASS. 일반 실패 문구가 뜨면 `details` 가 넘어오지 않은 것 → `backlog.md` 로 (마이그레이션 실행으로 조건이 소멸하므로 그 뒤에는 재현 불가·무해).

---

## 21.10 남은 사용자 결정사항

**1건.** `brand_authorization_hardening/spec.md` §9 의 **Q-S1** (결제 시점 매장 `status` 게이트를 이번 배포에 넣을지). 설계자 추천은 **별도 task**다. 근거는 §21.5 와 보안 task §9.

그 외는 전건 설계자 확정이다 — S2 의 포인터 수명주기(§21.2)는 운영 판단이 아니라 기술 설계로 닫혔으므로 질문하지 않는다.

---

# 22. `qoin_spend` 정합 재확인 (2026-11-02, architect)

> **이 절이 §1~§21 보다 최신이다.** §5.2·§7.4·§8·§9·§20.5 의 서술과 이 절이 **필드 enum·필드 수·Rules 분기** 에서 충돌하면 **이 절의 "랜딩 현실" 표를 따른다.** §1~§21 의 **설계 의도·근거는 불변**이며, 이 절은 그 의도가 `qoin_spend` 랜딩 후 코드에 어떻게 반영돼 있는지를 실측으로 못박고 낡은 서술만 교정한다.
>
> 입력: `qoin_spend` 커밋 `0c96b3a`(feat)·`70e3356`(test), `docs/tasks/qoin_spend/spec.md`. 실측 대상: `functions/src/{onQoinConfigWritten,setQoinSpendPolicy,setQoinAccrualRate,applyBrandQoinRate,setQoinAccrualEnabled}.ts`, `firestore.rules`.

## 22.0 결론 — 충돌·중복·회귀 없음

`qoin_spend` 는 **이 계층화가 먼저 만든 4개 공유 인프라에 올라탔다.** 새 컬렉션·새 트리거·새 Rules 블록을 만들지 않았고, 이 계층화의 패턴을 **그대로 복제**했다. 따라서 두 기능은 같은 표면을 **공동 점유**하며, 이는 의도된 재사용이다(계층화 §20.5.1 의 "컬렉션을 늘리지 않는다" 원칙이 `qoin_spend` 에도 그대로 적용됐다).

| 공유 인프라 | 계층화가 만든 것 | `qoin_spend` 가 한 것 | 판정 |
|---|---|---|---|
| ① 이력 컬렉션 `config/qoin/qoinRateHistory` | 전역 적립률·스위치 이력 (§5.2·§20.5) | 같은 컬렉션에 사용정책 3필드 이력을 **같은 스키마**로 기록 (`setQoinSpendPolicy`) | 재사용 ✅ |
| ② 트리거 `onQoinConfigWritten` | `accrualRate`/`enabled` Console 편집 감시 (§7.4) | `FIELDS` 에 `spendEnabled`/`minSpendUnit`/`minCashFloor` **추가** (2→5필드) | 확장 ✅ |
| ③ Rules `config/{docId}` 블록 | `accrualRate` create/update/delete 차단 (§8) | `qoinSpendPolicyFields()` 헬퍼로 3필드 동일 차단 | 확장 ✅ |
| ④ CF 패턴 "값+이력 동일 트랜잭션" | `setQoinAccrualRate` (§7.3) | `setQoinSpendPolicy` 가 **패턴 복제** (주석에 명시) | 재사용 ✅ |

**회귀 0 근거**: `qoin_spend` 는 계층화의 CF 파일(`setQoinAccrualRate`/`applyBrandQoinRate`/`setQoinAccrualEnabled`/`migrateQoinZeroRates`, 커밋 `f089751`)을 **수정하지 않았다**. 적립 경로(`onOrderQoinSettled` 의 earn 분기)와 사용 경로(spend)는 트랜잭션·멱등 ID 가 분리돼 있다(`earn_{orderId}` vs `spend_{orderId}`/`spendRefund_{orderId}` — `qoin_spend/spec.md` §5.5). 계층화의 적립률 해석(§6/§20.3.1)에 `qoin_spend` 가 손대지 않았다.

## 22.1 공유 이력 컬렉션 — `field` enum 이 늘었다 (§5.2 교정)

`config/qoin/qoinRateHistory` 와 `{brands,stores}/{id}/qoinRateHistory` 는 **여러 기능의 설정 변경 이력을 한 컬렉션에서** 받는다. `field` 값으로 구분한다. 랜딩 현실의 전체 enum:

| `field` 값 | 범위 | 쓰는 CF / 트리거 | 출처 |
|---|---|---|---|
| `accrualRate` | global·brand·store | `setQoinAccrualRate` · `applyBrandQoinRate` · `onQoinConfigWritten` | 계층화 |
| `globalEnabled` | global (`config.enabled` 비상 정지) | `setQoinAccrualRate`(enabled 경유) · `onQoinConfigWritten` | 계층화 |
| `accrualEnabled` | brand·store (적립 스위치) | `setQoinAccrualEnabled` | 계층화 |
| `spendEnabled` | global | `setQoinSpendPolicy` · `onQoinConfigWritten` | **qoin_spend** |
| `minSpendUnit` | global | `setQoinSpendPolicy` · `onQoinConfigWritten` | **qoin_spend** |
| `minCashFloor` | global | `setQoinSpendPolicy` · `onQoinConfigWritten` | **qoin_spend** |

- **§5.2 의 `field: 'accrualRate' | 'enabled'` 는 낡았다.** 실제는 ⓐ `'enabled'` 가 아니라 `'globalEnabled'`(전역 비상 정지) + `'accrualEnabled'`(브랜드·매장 스위치, §20.5.1)로 **분리**됐고, ⓑ 위 3개 `qoin_spend` 값이 **같은 컬렉션에 공존**한다.
- **공유 스키마는 양 기능이 동일하다**(실측): `scope`/`targetId`/`targetName`/`field`/`before`/`beforeState`('absent'|'value'|'invalid')/`beforeRaw`/`after`/`changedBy`/`changedByRole`/`changedAt`/`reason`/`source`/`op`. `qoin_spend` 의 `setQoinSpendPolicy` 가 이 15필드를 그대로 쓴다 → **admin 이력 화면이 두 기능을 한 목록·한 collection-group 쿼리로** 본다.
- **영향 없음 확인**: admin 이력 화면이 적립률만 보여주려면 `field in ('accrualRate','globalEnabled','accrualEnabled')` 로 **클라이언트 필터**하면 된다(새 인덱스 불요 — 이미 `changedAt desc` 단일 정렬). collection-group read Rules(`match /{path=**}/qoinRateHistory/{id}: read if isAdmin()`, §8)는 `qoin_spend` 이력에도 그대로 맞다.

## 22.2 `onQoinConfigWritten` — FIELDS 2→5 (§7.4 교정)

랜딩 현실(`functions/src/onQoinConfigWritten.ts`):

- `FIELDS = ['accrualRate','enabled','spendEnabled','minSpendUnit','minCashFloor']` — **5필드.** §7.4 가 적은 "`accrualRate` 또는 `enabled` 만" 은 2필드 시절 서술이다.
- `enabled` 의 이력 `field` 는 `'globalEnabled'` 로 매핑된다(§22.1).
- **중복 방지(§7.4 의 핵심 설계)는 유지·강화됐다**: callable 이 방금 남긴 이력과 `(field, after, 이벤트시각 ±2분)` 으로 대조해 skip. `setQoinSpendPolicy` 이력도 `source: 'callable'` 이므로 이 dedup 에 **자동으로 포함**된다 → Console 이 아닌 callable 경로로 사용정책을 바꿔도 이력이 2건 생기지 않는다.
- **F3 행위자 기록**(§19.3)은 `enabled` 에만 적용(`app_direct` + `enabledChangedBy`). 사용정책 3필드는 callable 전용(직접 쓰기 Rules 차단)이라 Console 편집만 `source: 'direct'`/`changedBy: null` 로 남는다 — 적립률과 동일 처리.
- 이력 문서 ID 가 `{source}_{eventId}_{field}` 로 고정돼 5필드가 한 이벤트에서 바뀌어도 **필드당 1건**, 이벤트 재전달에도 중복 없음(ALREADY_EXISTS 무시).

## 22.3 Rules `config/{docId}` — 사용정책 3필드도 CF 전담 (§8·§9 교정)

랜딩 현실(`firestore.rules` `match /config/{docId}`):

- `accrualRate` 차단에 더해 **`qoinSpendPolicyFields() = ['spendEnabled','minSpendUnit','minCashFloor']`** 를 create·update 양쪽에서 동일 차단. `delete: if false`.
- `enabled` 직접 쓰기는 유지하되(비상 정지는 CF 장애 중에도 꺼야 함) **`enabledChangedAt == request.time` + `enabledChangedBy == uid()` 를 강제**(§19.3 F3 의 랜딩형). 이는 §8 표의 "`enabled` 는 admin 허용" 을 **구체화**한 것이지 뒤집은 게 아니다.
- **§9/§20.5.6 쓰기 경로 전수표에 행을 추가해야 정확하다**(설계 의도 불변, 표만 확장): `config/{docId}` 의 사용정책 3필드 create·update 차단(✅ `qoinSpendPolicyFields()`), `setQoinSpendPolicy` CF(✅ admin 재검증+경계+이력 동일 트랜잭션). 단 이는 **`qoin_spend` 의 보호 대상**이므로 전수 관리 책임은 `qoin_spend/spec.md` §8 에 있다. 계층화의 "보호 대상 2필드(`qoinAccrualRate`+`qoinAccrualEnabled`)" 범위는 **변동 없다.**

## 22.4 이 절이 바꾸지 않는 것 (경계 명시)

- 적립률 **계층 해석**(§6/§20.3.1 진리표), **스위치 2단**(브랜드·매장, N4/A안), **일괄 적용 원자성·포인터**(§19.5/§21.1~§21.2), **원장 `accrualRateSource`**(§5.3) — 전부 불변. `qoin_spend` 는 이 중 어느 것도 읽거나 쓰지 않는다.
- `qoin_spend` 의 **사용(spend) 로직·환불 복원·금액 게이트**는 이 계층화 범위 밖이다(`qoin_spend/spec.md`). 두 기능의 유일한 접점은 §22.0 의 4개 공유 인프라뿐이다.

## 22.5 작업 분배 — 이 정합 패스의 결론

| 역할 | 판정 | 사유 |
|---|---|---|
| **designer** | **호출 불요** | 공유 인프라는 백엔드(이력·트리거·Rules)다. 화면 변경 없음. 계층화 admin 화면(§12)·`qoin_spend` 화면은 각 task 에서 이미 확정 |
| **developer** | **호출 불요 (코드 변경 0)** | §22.0~§22.3 은 **코드가 이미 정합**임을 실측 확인한 결과다. 충돌·중복이 발견되지 않았으므로 수정할 코드가 없다. 교정은 **이 spec 문서**(§0·§22)에 한정 |
| **tester** | **선택(권장, 비차단)** | 두 기능이 공유 표면을 **공동 점유**하게 됐으나, 그 결합을 명시적으로 검증한 테스트는 아직 없다. `qoin_spend`(불변식 9/9 PASS)·계층화(test_report) 는 각자 통과했다. 아래 §22.6 결합 케이스를 1회 회귀로 넣으면 "한 기능 변경이 공유 컬렉션/트리거에서 다른 기능을 깨뜨리지 않는다" 를 못박을 수 있다 |

## 22.6 tester 선택 회귀 — 공유 표면 결합 케이스 (권장, 비차단)

| # | 케이스 | 기대 |
|---|---|---|
| 1 | `onQoinConfigWritten` 가 한 쓰기에서 `accrualRate` + `spendEnabled` 동시 변경을 받음 | `qoinRateHistory` 에 `field: 'accrualRate'` 1건 + `field: 'spendEnabled'` 1건, **각각 doc ID `{source}_{eventId}_{field}`** |
| 2 | `setQoinSpendPolicy` callable 직후 같은 값이 `onQoinConfigWritten` 로 재감지 | **dedup 성립** — 중복 이력 0건(`source:'callable'` ±2분 매칭) |
| 3 | admin 이력 화면 collection-group 쿼리가 적립률·사용정책 이력을 **한 목록**으로 읽음 | Rules `read if isAdmin()` 통과, `field` 클라이언트 필터로 분리 가능, 새 인덱스 미요구 |
| 4 | Rules 하네스: `config/qoin` update 로 `spendEnabled`/`minSpendUnit`/`minCashFloor` 직접 쓰기 | **전부 거부** (admin 포함). `accrualRate`·`qoinSpendPolicyFields()` 동시 차단 회귀 |
| 5 | 적립(earn)·사용(spend) 가 같은 주문에서 공존 시 | 멱등 ID 분리(`earn_*` vs `spend_*`)로 상호 간섭 0 — 계층화 적립률 해석은 spend 와 무관 |

> 1순위는 #1·#2(공유 트리거의 필드당 멱등·dedup)와 #4(공유 Rules 블록). #3·#5 는 각 task 테스트가 부분 커버하므로 여력 있을 때.
