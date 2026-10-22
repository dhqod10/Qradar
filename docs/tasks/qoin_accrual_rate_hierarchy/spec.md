# Qoin 적립률 계층화 기능 명세

- 작성: 2026-10-22 (architect)
- 선행: `docs/tasks/qoin/` (1차 — 설계·구현·라이브 검증 완료, 실결제 0회)
- 요구사항 출처: `docs/backlog.md` 의 `qoin_accrual_rate_hierarchy` 절 **H1~H7 (사용자 확정, 재논의 대상 아님)**
- 감사 추적 기준: `docs/processes/audit_trail.md` §4 (6개 체크리스트 — §13 에서 전건 통과)

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

> ⚠️ **배포 순서는 §19.7 을 따른다**: `firestore:indexes` → `firestore:rules` + `functions` → 앱 빌드. **Rules 와 앱 빌드는 같은 배포**에 올린다(§19.3 의 `enabledChangedBy` 강제 때문).

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

### ③ "설정 없음" 의 표현 → **필드 부재 = 상속 / `0` = 명시적 중단** (추천)

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

### 5.1 적립률 필드

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

### 5.2 변경 이력 (H7)

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

## 6. 계층 해석 알고리즘 (H3)

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

## 9. 보안 · 적립률 쓰기 경로 전수 (F1 재발 방지)

설계 후 `qoinAccrualRate` / `config/qoin.accrualRate` 에 **쓸 수 있는 모든 경로**:

> ⚠️ **12경로는 전수가 아니었다 (tester F4 / §19.4).** 13번째 경로가 있다 — 점주가 자기 매장을 `delete` 한 뒤 같은 ID 로 재생성하면 개별 설정이 **제거**된다. `status: 'pending'` 재승인이 필요하므로 **수용**하고 하네스로 동작을 고정한다. 아래 표의 "전수" 는 **13경로**로 읽는다.

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

## 13. 감사 추적 체크리스트 (`audit_trail.md` §4 — 6항목)

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

기존 73건 **전건 회귀 PASS** + 아래 신규. §9 의 12경로를 그대로 케이스화한다.

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
- §9 **12경로 전수**를 Rules 하네스 케이스로 1:1 매핑 (F1 교훈)
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
2. §9 의 12경로 전수가 Rules 하네스 케이스로 존재하고 기대대로 동작 (기존 73건 회귀 PASS)
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
- 이 절은 §1~§18 중 **틀린 판정을 정정**한다. 충돌하면 **이 절이 우선**이다. 정정 대상: §1.5 · §4-② · §4-⑩ · §7.2 · §9 · §13(체크 2·4·6).

## 19.0 판정 요약

| # | 항목 | 판정 | 배포 전/후 |
|---|---|---|---|
| F1 | 브랜드 단계 미적용 + 클라이언트 지정 `brandId` | **고친다** — 신뢰원을 `stores/{id}.brandId` 로 | **배포 전 (필수)** |
| F2 | 덮어쓰기가 매장별 이전 값을 기록 없이 지움 | **고친다** — 매장별 이력 + 브랜드 이력 분류 집계 | **배포 전** |
| F3 | `enabled` 이력에 `changedBy` 없음 | **고친다** (§4-⑩ 의 수용은 거짓 이분법이었다) | **배포 전** |
| F4 | 매장 delete → 같은 ID 재생성으로 0% 해제 | **수용** (+ 하네스 케이스, §9 13경로로 정정) | 배포 전 (문서·테스트만) |
| F5 | 일괄 적용 재개·동시 실행 보호 부족 | **고친다** — 브랜드 문서 잠금/포인터 1종 | **배포 전** |
| F6 | `data_ownership.md` 공백 | **고쳤다** (이 커밋) | 완료 |
| 부가 A | 오프-그리드 값 표시(`0.0015` → `0.2%`) | 고친다 | 배포 후 가능 |
| 부가 B | 무효 값 이력 `before: null` | **고친다** (소급 불가) | **배포 전** |
| H-1 | 0% 매장 덮어쓰기 정책 | **사용자 결정 대기** (추천 A + 서버 집행) | 결정 후 |
| H-2 | 무효 값 fail-closed 시 소급 수단 없음 | 기록 수단은 **고친다** / 소급 도구는 backlog | **배포 전**(기록) |
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

### H-1 — 0% 덮어쓰기 정책: **확정하지 않는다** (사용자 결정, Q1)

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
**§9 정정**: "12경로 전수" → **13경로**. 13번 = 점주 delete + 재생성(**수용된 경로**, 재승인 필요). §18 완료 기준 2 의 "12경로" 도 13으로 읽는다.

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

## 19.7 배포 전 / 배포 후

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

## 19.8 작업 분배

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

## 19.9 사용자 확인이 필요한 결정사항

| # | 질문 | 선택지 | 추천 |
|---|---|---|---|
| **Q1** | 브랜드 일괄 **덮어쓰기**가 `적립 안 함(0%)` 매장을 덮어야 하는가? (`backlog.md` 옵션) | **A** 0% 는 제외(잠금) / **B** 0% 매장 목록 개별 체크 / **C** 3택(전체·0%제외·0%포함) / **D** 현재안(알림만) | **A.** 화면 숫자는 실행 시점과 어긋날 수 있어 경고로는 보장이 안 된다. 서버가 0% 를 skip 하면 숫자 정확도와 무관하게 안전하다. **돈이 나가기 시작하는** 방향의 결정만 막는다. 해제는 그 매장에서 명시적으로 풀게 한다. B 는 매장이 많으면 비현실적, C 는 선택지 1개 추가 비용 대비 이득이 작다 |
| **Q2** | 무효 값 때문에 적립이 누락된 주문을 **소급 적립**할 것인가? 한다면 어느 요율로? | ⓐ 소급 안 함(기록만) / ⓑ **수정 후** 요율로 소급 / ⓒ 발생 시점의 **전역 기본값**으로 소급 | 지금은 **기록만** 만들고(배포 전) 도구는 backlog. 결정하면 ⓑ 가 설명하기 쉽다("정상값으로 고친 뒤 그 값으로 지급"). 다만 요율이 내려갔다면 고객에게 불리해질 수 있어 사용자 판단이 필요하다 |
| **Q3** | F4(매장 delete → 같은 ID 재생성으로 0% 해제)를 **수용**해도 되는가? | ⓐ 수용(하네스로 동작 고정) / ⓑ 막는다(재생성 시 admin 승인 전까지 0% 복원 등) | **ⓐ 수용.** 재생성은 `status: pending` 이라 **admin 승인 없이는 적립이 발생하지 않는다.** 대신 `stores.delete` 정책(점주 삭제 허용 / 삭제 이력 없음 / 이력 고아)을 별도 과제로 backlog 에 올린다 |

