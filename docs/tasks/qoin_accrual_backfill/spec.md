# 적립 누락분 소급 적립 도구 (qoin_accrual_backfill) 기능 명세

- 작업 유형: 신규 기능 (운영 도구 / backend 전용)
- 선행 설계: `qoin_accrual_rate_hierarchy/spec.md` §19.4(H-2) / §20.7(Q2) — 이 도구를 **backlog 로 미뤄둔 바로 그 도구**다. 당시 미결 쟁점("어느 시점 요율로 줄 것인가")이 사용자 결정으로 확정되어 착수한다.
- 상태: **설계 (spec) 단계.** 구현·하위 에이전트 호출 전.

---

## 0. 사용자 확인이 필요한 결정 (권고안 + 대안)

> 이 절은 설계자가 **독단으로 확정하지 않는다.** 아래 D0-1 ~ D0-8 중 특히 ★ 표시는 돈·정책이 걸려 반드시 사용자 확정이 필요하다. 확정 전에는 developer 를 호출하지 않는다.

### D0-1 ★ 당시 요율 복원 방법 (가장 중요)

**사용자 확정 전제**: 소급 적립은 **그 주문이 완료된 시점(`completedAt`)에 유효했던 적립률 계층(매장→브랜드→전역)** 을 적용한다. 현재 요율이 아니다.

현실적 복원 방법 3가지를 조사했다.

| 방법 | 가능 여부 | 평가 |
|---|---|---|
| ⓐ **주문 스냅샷에 박제된 값 활용** | **불가** | 주문 문서(`orders/{id}`)에는 적립률이 박제돼 있지 않다. 적립률은 `onOrderQoinSettled` 가 완료 전이 시점에 **계층 해석으로 계산**해 `earn_{orderId}` 원장에만 박제한다(`accrualRate`/`accrualRateSource`). 소급 대상은 정의상 그 원장이 **없는** 주문이므로 박제값이 존재하지 않는다. |
| ⓑ **`qoinRateHistory` 시점조회 (point-in-time)** | **가능 (권고)** | 세 범위의 이력 컬렉션(`config/qoin`·`brands/{id}`·`stores/{id}` 의 `qoinRateHistory`)은 `changedAt`/`before`/`after`/`op`/`field` 를 남긴다. `changedAt <= completedAt` 중 각 필드의 최신 항목을 재구성해 **라이브 CF 와 같은 `resolveEffectiveRate`** 에 먹인다. |
| ⓒ **완료 시점 재현 (현재 문서값 사용)** | 가능하나 부정확 | 지금 `stores/{id}.qoinAccrualRate` 등을 그대로 읽으면 완료 후 요율이 바뀐 경우 "당시 요율" 이 아니다. 사용자 결정과 어긋난다. |

**권고: ⓑ (point-in-time 재구성) + ⓐ·ⓒ 는 폴백이 아니라 배제.**

ⓑ 재구성 알고리즘(각 범위·각 필드 `accrualRate`/`qoinAccrualEnabled` 독립):
1. 그 범위의 `qoinRateHistory` 를 `changedAt asc` 로 읽는다(범위별 건수가 적어 전량 읽고 메모리 필터 — 복합 인덱스 불필요).
2. `changedAt <= completedAt` 인 **최신** 항목의 `after` 가 그 시점 값. `op:'clear'` 면 그 시점 "설정 없음"(상위 상속).
3. `changedAt <= completedAt` 인 항목이 없고, `changedAt > completedAt` 인 **최초** 항목이 있으면 그 항목의 `before`/`beforeState` 가 완료 시점 값이다(그 사이 변경이 없었으므로). `beforeState:'absent'` → 상속, `'value'` → 그 값, `'invalid'` → 무효.
4. 이력이 아예 없으면(해당 범위에서 한 번도 설정된 적 없음) → 상위 상속.
5. 세 범위의 재구성값을 라이브와 동일한 `classifySwitch`/`classifyRate`/`resolveEffectiveRate` 에 넣어 `rate`/`source`/`disabled`/`ok` 를 얻는다.

**복원의 한계(반드시 사용자에게 고지) → D0-8 폴백과 연결:**
- (가) `qoinRateHistory` **도입 시점(=H7 배포) 이전**에 완료된 주문은 이력 자체가 없다 → 재구성 불가 구간.
- (나) `stores`/`brands` 의 **Console 직접 편집은 감시되지 않는다**(hierarchy N6, audit_trail §3 ⓑ). 그 구간의 요율 변경은 이력에 없어 재구성이 틀릴 수 있다. (`config/qoin` 전역값은 `onQoinConfigWritten` 가 Console 편집도 사후 포착하므로 전역은 안전.)

### D0-2 ★ 대상 선별 범위

| 티어 | 대상 | 비용/위험 | 권고 |
|---|---|---|---|
| **Tier 1 (권고 기본)** | `qoinSettlementIssues` 중 **적립 누락 사유**(`invalid_rate`/`invalid_enabled`/`invalid_store`/`invalid_total`)이고 `resolved=false` 인 문서 | 낮음·정밀 (이미 "누락 확정" 목록) | 채택 |
| **Tier 2 (opt-in, 범위 제한 필수)** | 명시 입력: `orderIds[]` **또는** `storeId + completedAt 기간` **또는** `completedAt 기간`. 각 후보는 `earn_{orderId}` **부재**로 2차 검증 | 중간 (쿼리 범위에 비례) | 입력 있을 때만 |
| ✗ 전체 컬렉션 무제한 스캔 | 전체 `orders` where status=completed | 높음·위험 | **금지 (기본 비활성)** |

- 과제의 대상 (a)트리거 실패 → Tier 1. (b)적립 꺼져 있던 동안 완료 / (c)기타 누락 → `qoinSettlementIssues` 에 **없다**(의도된 중단은 기록 안 함). 오직 Tier 2 로만 표면화된다.
- **`qoinSettlementIssues` 의 spend 계열 사유**(`spend_restore_skipped_disabled`/`spend_rollback_failed`)는 **적립 누락이 아니다** — 이 도구의 대상에서 제외한다(복구 방법이 다름).

### D0-3 ★ "적립이 꺼져 있던 동안 완료된 건"(대상 b) 을 적립할 것인가

스위치가 꺼져 있던 건 **의도된 정책**일 수도, 사고(꺼진 줄 몰랐던 기간)일 수도 있다. point-in-time 재구성은 그 시점 `disabled` 를 그대로 반영하므로 **기본적으로는 0 적립(스킵)** 이 된다.

- **권고**: 모드 플래그 `creditDisabledPeriod`(기본 `false`). `true` 일 때만 완료 시점 스위치를 **무시**하고 그 시점 `rate` 값으로 적립한다(스위치 off 로 인한 미적립을 소급). `rate` 값 자체가 무효/부재면 → D0-8 폴백.
- 대안: 항상 스킵(b 는 지원 안 함) / 항상 적립(위험 — 의도된 off 기간까지 소급).

### D0-4 ★ 전역 비상정지(`config/qoin.enabled=false`) 와의 관계

- **권고**: 소급 도구는 **전역 kill switch 를 통과**시킨다(라이브 트리거와 달리 admin 의 **의도된 복구 행위**이므로). 비상정지 중에도 과거 누락을 메꿀 수 있어야 한다. 단, 전역 적립률이 **당시** 무효였던 건은 D0-8 폴백 적용.
- 대안: kill switch 가 켜져 있으면 거부(복구가 막혀 비상정지 해제 전까지 누락이 쌓인다 — 비권장).

### D0-5 admin UI 범위

- **권고 (Phase 1 = 이번)**: **UI 없음.** admin 전용 callable CF + `dryRun` 미리보기. 운영자는 콘솔/스크립트로 호출. → designer 불필요.
- **Phase 2 (backlog)**: `qoinSettlementIssues` 목록 + "소급 적립" 액션을 admin 정책 화면(H-D)과 묶는 UI. 착수 시 designer → developer 재분배.

### D0-6 ★ 자동 vs 검토 후

- **권고**: **`dryRun` 기본값 `true`.** 1차 호출은 **쓰지 않고** "줄 대상·재구성 요율·금액·source·폴백여부" 를 반환. `dryRun:false`(또는 `commit:true`) 2차 호출에서만 실제 적립. (`backfillAvailableMainCategories` 와 같은 패턴.)
- 대안: 자동 즉시 적립 — 돈이 걸려 비권장.

### D0-7 원장에 소급 적립 구분 표기

- **권고**: 멱등·불변식·clawback 호환을 위해 `type:'earn'` 과 `amount`/`accrualRate`/`accrualRateSource`/`orderTotalPrice`/`brandId` 등 **핵심 필드는 라이브 earn 과 동일**하게 쓰되, 감사용 추가 필드로 구별한다: `origin:'backfill'`, `backfilledBy`(admin uid), `backfilledAt`, `backfillReason`, `rateReconstruction`(아래 §5.2), `sourceIssueId`(Tier1 이면 해당 issue 문서 ID). → clawback 은 `earn_{orderId}` 를 ID 로 읽어 `amount` 를 반전하므로 **그대로 동작**(재검증 불필요).
- 대안: `type:'backfillEarn'` 신설 — clawback·정산 집계·잔액 불변식이 `earn` 만 보는 기존 코드와 어긋나 회귀 위험. 비권장.

### D0-8 ★ 복원 불가 시 폴백

당시 요율을 못 구하는 경우(D0-1 한계 가/나, 또는 당시값 `invalid`):
- **권고**: **fail-closed 스킵 + 플래그.** 적립하지 않고 결과에 `skipped: 'rate_unrecoverable'` 로 보고(라이브 CF 의 fail-closed 철학과 일치 — 틀린 금액을 주는 것보다 안전). 그 뒤 admin 이 판단해 **명시적 `overrideRate`**(배치 단위, 선택 인자)로 재실행할 수 있게 한다. override 사용 건은 원장 `rateReconstruction.method:'admin_override'` 로 박제해 "당시 요율이 아님" 을 영구히 남긴다.
- 대안: 완료 시점 전역 기본값으로 폴백(ⓒ 변형) / 현재 요율로 폴백 — 둘 다 "당시 요율" 보장을 깨므로 기본값으로 삼지 않는다.

---

## 1. 개요

### 목적

Qoin 적립이 누락된 완료 주문을 admin 이 **멱등하게 소급 적립**하는 운영 도구. 라이브 적립은 `onOrderQoinSettled` 가 `*→completed` 전이에서 `earn_{orderId}` 원장으로 처리하지만, 아래 사유로 누락이 발생한다.

- (a) 트리거 실패/무효 설정으로 `qoinSettlementIssues` 에 기록된 건 (`invalid_rate`/`invalid_enabled`/`invalid_store`/`invalid_total`).
- (b) 적립 스위치가 꺼져 있던 동안 완료된 건 (의도된 중단이라 이슈 기록 없음).
- (c) 기타 누락으로 `earn_{orderId}` 원장이 없는 완료 주문.

### 영향 범위

- 화면: **없음 (Phase 1)**. (Phase 2 UI 는 backlog)
- Domain / Data / Presentation (Flutter): **없음 (Phase 1)**. 이 도구는 `functions/` 전용이다.
- Firebase: **Cloud Functions 신규 callable 1개** + (선택) **신규 컬렉션 1개**(`qoinBackfillHistory`, 또는 기존 `migrationHistory` 재사용 — §4). `firestore.rules`/인덱스는 원칙상 변경 없음(§6).
- 권한: admin 전용 callable (`requireAdmin` 재사용).
- 기존 자산 재사용: `onOrderQoinSettled`/`qoinRate`/`qoinAdmin`/`qoinSettlementIssues` 의 패턴·원장·멱등 가드.

### 비범위

- Phase 2 admin UI (backlog).
- 적립 비용 **정산/청구**(audit_trail §5, N1 — 별 주제).
- spend(사용) 계열 이슈 복구 — 이 도구의 대상 아님(D0-2).
- `qoinRateHistory` 도입 이전 구간의 과거 요율 복원 — 구조적으로 불가(D0-1 한계 가).
- 라이브 트리거 `onOrderQoinSettled` 의 로직 변경 — **건드리지 않는다**(회귀 0).

---

## 2. 요구사항

### 기능 요구사항

- [ ] admin 전용 callable `backfillQoinAccrual` 를 신설한다(`requireAdmin` 서버 재검증).
- [ ] 대상 선별: Tier 1(`qoinSettlementIssues` 적립 사유·`resolved=false`) + Tier 2(명시 `orderIds[]` / `storeId`+기간 / 기간). 무제한 스캔 금지 (D0-2).
- [ ] 각 후보는 처리 전 `earn_{orderId}` **부재**를 확인(선존재 가드와 별개의 사전 필터).
- [ ] 당시 요율을 `qoinRateHistory` point-in-time 재구성으로 구하고, 라이브와 **같은** `resolveEffectiveRate` 에 먹인다 (D0-1 ⓑ).
- [ ] 멱등: 적립은 `earn_{orderId}` ID 재사용 + 트랜잭션 내 선존재 가드 → 라이브 트리거가 이미 적립했거나 동시에 적립해도 **중복 생성 안 됨**.
- [ ] `dryRun` 기본 `true`. `commit` 시에만 실제 쓰기 (D0-6).
- [ ] 완료 시 ① earn 원장(소급 구분 필드 포함) ② 해당 `qoinSettlementIssues` 문서 `resolved=true` 마킹 ③ 실행 1건을 `qoinBackfillHistory`(/`migrationHistory`) 에 기록 (§4, audit_trail §4-5).
- [ ] `creditDisabledPeriod`(기본 false, D0-3), `overrideRate`(선택, D0-8), 전역 kill switch 통과(D0-4) 를 지원.

### 상태 요구사항 (callable 응답)

- 정상: `{ dryRun, scanned, eligible, credited|wouldCredit, skipped[], totalQoin, historyId? }`.
- 각 대상 결과: `{ orderId, outcome: 'credited'|'already_applied'|'skipped', skipReason?, rate?, rateSource?, amount?, reconstruction }`.
- 스킵 사유: `already_earned` / `no_completedAt` / `rate_unrecoverable` / `disabled_period`(creditDisabledPeriod=false) / `invalid_total` / `store_unresolvable`.

---

## 3. 데이터 모델

### 3.1 입력 (callable request)

```
{
  dryRun?: boolean           // 기본 true
  source: 'issues' | 'orderIds' | 'storeRange' | 'range'
  orderIds?: string[]        // source=orderIds (상한 e.g. 500)
  storeId?: string           // source=storeRange
  from?: ISO/millis, to?: ISO/millis   // storeRange | range
  limit?: number             // 안전 상한
  creditDisabledPeriod?: boolean   // 기본 false (D0-3)
  overrideRate?: number      // 선택, 0.001~0.2 격자 (D0-8). 쓰면 당시요율 아님 박제
  reason?: string            // parseReason 재사용
}
```

### 3.2 earn 원장 (기존 `users/{uid}/qoinTransactions/earn_{orderId}` 재사용 + 추가 필드)

라이브 earn 과 **동일 필드**(`txId`,`type:'earn'`,`orderId`,`storeId`,`storeName`,`brandId`,`orderTotalPrice`,`accrualRate`,`accrualRateSource`,`amount`,`balanceAfter`,`createdAt`) +

```
origin           : 'backfill'
backfilledBy     : <admin uid>
backfilledAt     : serverTimestamp
backfillReason   : string | null
sourceIssueId    : <issue doc id> | null      // Tier1
rateReconstruction : {                         // §5.2
  method   : 'history_pit' | 'admin_override',
  anchor   : <completedAt millis>,
  resolvedSource : 'store'|'brand'|'global',
  gaps     : string[]      // 예: ['store_console_untracked'] (D0-1 한계 고지)
}
```

### 3.3 실행 이력 `qoinBackfillHistory/{autoId}` (또는 `migrationHistory` 재사용 — §4 결정)

```
name: 'backfillQoinAccrual', changedBy: <admin uid>, changedAt: serverTimestamp,
dryRun, source, params(필터 요약), reason,
scanned, eligible, credited, skippedCounts{...}, totalQoin,
sampleResults[] (상한 N건)      // 전수는 응답으로, 요약은 영구 기록
```

---

## 4. 레이어 설계

Phase 1 은 **Clean Architecture Flutter 레이어를 쓰지 않는다** (backend 운영 도구). `functions/` 내부 구성만 정의한다.

### functions/

- **`backfillQoinAccrual.ts`** (신규, export in `index.ts`): callable 진입점. `requireAdmin` → 입력 파싱 → 대상 수집 → 대상별 (요율 재구성 → `dryRun` 분기 → 적립 트랜잭션 → issue 마킹) → 실행 이력 1건.
- **`qoinRateReconstruct.ts`** (신규, 순수에 가까움): `qoinRateHistory` 3범위를 읽어 `completedAt` 시점 각 필드값 재구성 + `resolveEffectiveRate` 호출 → `{ok, rate, source, disabled, gaps}`. **테스트 용이성 위해 read 주입/분리**.
- **재사용**: `qoinRate.ts`(`classifyRate`/`classifySwitch`/`resolveEffectiveRate`/`computeEarnAmount`/`isValidCallableRate`), `qoinAdmin.ts`(`requireAdmin`/`parseReason`/`historyCollection`/`describeRaw`/`REGION`), `onOrderQoinSettled` 의 `applyTransaction` 패턴(선존재 가드 트랜잭션 — 공통 헬퍼로 추출하거나 복제).

### 적립 트랜잭션 (멱등 핵심 — `onOrderQoinSettled.applyTransaction` 과 동일 형태)

```
runTransaction:
  txSnap = get(earn_{orderId})
  if txSnap.exists: return 'already_applied'   // 라이브가 이미 했거나 동시 실행
  userSnap = get(users/{uid})
  before = qoinBalance (수치 아니면 0)
  after = before + amount
  set(earn_{orderId}, {라이브 earn 필드 + 소급 구분 필드})
  update(users/{uid}, {qoinBalance: after})   // 이 1필드만
```

> 동시성: 라이브 트리거와 소급이 같은 `earn_{orderId}` 를 동시에 노려도 Firestore 가 트랜잭션을 직렬화하고, 뒤에 든 쪽은 `exists` 를 보고 `already_applied` 로 빠진다 → **이중 적립 불가**.

---

## 5. 데이터 흐름

### 5.1 전체

```
admin → callable backfillQoinAccrual(dryRun=true, source, filters)
  requireAdmin (users/{uid}.role=='admin')
  대상 수집:
    Tier1: qoinSettlementIssues where reason∈적립사유 && resolved==false
    Tier2: orderIds | (storeId+기간) | 기간  → orders 조회
  대상별:
    order 로드 → completedAt, totalPrice, storeId 확인
    earn_{orderId} 사전 부재 확인 (있으면 already_earned 스킵)
    요율 재구성 (§5.2) → {ok, rate, source, disabled, gaps}
    적립 가능 판정:
      disabled && !creditDisabledPeriod → 스킵(disabled_period)
      !ok && overrideRate 없음 → 스킵(rate_unrecoverable)
      !ok && overrideRate → rate=overrideRate, method=admin_override
    amount = computeEarnAmount(totalPrice, rate); amount<=0 → 스킵
    dryRun ? 보고만 : [적립 트랜잭션 → issue resolved=true → 결과 집계]
  실행 이력 1건(qoinBackfillHistory) + 응답 반환
```

### 5.2 요율 재구성 (qoinRateReconstruct)

```
for layer in [store(storeId), brand(store.brandId), global(config/qoin)]:
  hist = read(layer.qoinRateHistory) 전량, field∈{accrualRate, accrualEnabled/globalEnabled}
  rateAtT   = pitValue(hist, 'accrualRate', completedAt)      // §0 D0-1 ⓑ 2~4
  switchAtT = pitValue(hist, accrualEnabled, completedAt)     // store/brand만
resolveEffectiveRate(storeSwitch, storeRate, brandSwitch, brandRate, globalRate)
gaps: store/brand 에서 Console 편집 감시 공백 가능성 표기(D0-1 한계 나)
```

> **전역은 `onQoinConfigWritten` 이 Console 편집도 포착**하므로 재구성이 안전. 매장/브랜드는 N6 로 공백 가능 → `gaps` 로 고지.

---

## 6. 에러 처리 / 권한 / 감사

### 에러 처리

| 케이스 | 처리 |
|---|---|
| 비admin 호출 | `HttpsError permission-denied` (`requireAdmin`) |
| 무제한 스캔 요청(필터 없음) | `invalid-argument` 거부 (D0-2) |
| `completedAt` 없음 (완료 주문 아님) | 스킵 `no_completedAt`, 적립 안 함 |
| `earn_{orderId}` 이미 존재 | 스킵 `already_earned` (dryRun·commit 공통) |
| 요율 재구성 불가 | 스킵 `rate_unrecoverable` (override 없을 때) |
| `totalPrice` 무효 | 스킵 `invalid_total` |
| store/brandId 미해결 | 스킵 `store_unresolvable` |
| Firestore 일시 장애 | 해당 대상만 실패 보고(부분 성공 허용), 나머지 계속. 멱등하므로 재실행 안전 |
| issue 마킹 실패 | 적립은 유지(원장이 진실원), 로그 + 결과에 경고 |

### 권한 / 소유권 (data_ownership §2.11.4/§2.11.5)

- `qoinTransactions`·`users.qoinBalance`·`qoinSettlementIssues` 는 모두 **CF 전담(클라이언트 `if false`)**. 이 callable 은 Admin SDK 로 쓰므로 **Rules 변경 불필요**.
- `qoinRateHistory` 는 읽기만(admin read 허용) — Admin SDK read 라 역시 변경 불필요.
- `qoinBackfillHistory` 를 신설하면 `migrationHistory` 처럼 **Rules 무규칙(=클라이언트 접근 불가)** 로 두거나, `migrationHistory` 를 재사용(규칙 없음)한다. → **결정 필요**: 신규 컬렉션 vs 재사용. **권고: 신규 `qoinBackfillHistory`**(의미 분리, 조회 용이). 대안: `migrationHistory` 재사용(`name` 으로 구분).

### audit_trail §4 체크리스트 (6개 + 상시 7)

1. **돈·권한·정책 값을 바꾸는가** → **그렇다(돈=Qoin 적립).** 설정 변경 이력이 기본값. **남긴다**: 거래 이력=earn 원장(당시 값 박제), **운영 행위 이력=`qoinBackfillHistory`**(admin 운영 행위 — audit_trail A5 공백을 이 기능 범위에서 메움). *거래 이력(원장)이 있다고 운영 이력이 자동으로 있는 것이 아니다 — 둘 다 남긴다.*
2. **덮어쓰기로 사라지는 값** → 없음. 원장 append-only. issue 는 삭제 아닌 `resolved=true` + `resolvedBy`/`resolvedAt`/`resolvedTxId` 추가(이력 보존).
3. **정책 값 참조만 하는가 → 박제** → earn 원장에 재구성한 `accrualRate`/`accrualRateSource` + `rateReconstruction`(method/anchor/gaps) 박제. 당시 요율임을(또는 override 임을) 영구 증명.
4. **"누가"** → `backfilledBy`(원장) + `changedBy`(실행 이력) = admin uid.
5. **batch 영향 범위** → 실행 이력에 `scanned`/`eligible`/`credited`/`skippedCounts`/`totalQoin`/`dryRun` 기록.
6. **CF 로그 의존 금지** → 영구 기록은 Firestore(`qoinBackfillHistory`), Cloud Logging 보조.
7. (상시 create/update 교차) → 쓰기 경로가 Admin SDK 전담이고 클라이언트 쓰기는 기존 `if false` 가 이미 막음. **Rules 변경이 없어** 신규 구멍 없음 — tester 가 "클라이언트는 earn/issue/balance 를 못 쓴다" 회귀만 확인.

---

## 7. 작업 분배

### designer
- **Phase 1 UI 변경 없음** (callable + dryRun 전용). design.md **불필요**(명시).
- Phase 2(admin UI, H-D 화면 연계)는 backlog — 착수 시 재호출.

### developer
- 구현: `functions/src/backfillQoinAccrual.ts`(callable), `functions/src/qoinRateReconstruct.ts`(point-in-time 재구성), `index.ts` export, (신규 컬렉션 택1 시) 없음=Rules 무변경.
- 재사용 강제: `qoinRate`/`qoinAdmin`/`onOrderQoinSettled.applyTransaction` 패턴. 새 원장 타입·새 멱등 체계 **만들지 말 것**(회귀 위험).
- 레이어 규칙: Firebase/Admin SDK 는 `functions` 에서만(정상). Flutter 레이어 손대지 않음.
- **라이브 `onOrderQoinSettled` 수정 금지.**
- §0 미확정 항목은 구현 전 설계자/사용자 확정 대기.

### tester
- 멱등: 라이브 트리거가 이미 적립한 주문 → 소급 `already_applied`(중복 0). 소급 2회 → 1회만.
- 동시성(에뮬레이터): 라이브 earn 과 소급이 같은 `earn_{orderId}` 경합 → 이중 적립 없음.
- 요율 재구성: 완료 후 요율이 바뀐 케이스에서 **완료 시점 값**이 적용되는지 (매장/브랜드/전역 계층 각각). `op:'clear'` 상속, 이력 공백 폴백.
- 스위치 off 기간: `creditDisabledPeriod` false→스킵 / true→그 시점 rate 적립.
- 폴백: 재구성 불가 → `rate_unrecoverable` 스킵, `overrideRate` 로만 적립 + `method:'admin_override'` 박제.
- kill switch(enabled=false) 중에도 소급 통과(D0-4).
- dryRun: 쓰기 0, 응답에 예상치. commit: issue `resolved=true` + 실행 이력 1건.
- 회귀: 클라이언트는 `qoinTransactions`/`qoinBalance`/`qoinSettlementIssues` 쓰기 불가(기존 Rules 유지). 라이브 적립/회수/사용 복원 불변.
- 불변식: `qoinBalance == Σ amount`.

---

## 8. 완료 기준

- [ ] §0 의 ★ 결정이 사용자 확정됨 (특히 D0-1/D0-2/D0-3/D0-6/D0-8).
- [ ] 요구사항 구현 또는 보류 사유 명시.
- [ ] design.md: Phase 1 UI 없음 명시 / implementation.md / test_report.md 작성.
- [ ] 멱등·이중적립 방지·요율 재구성·감사(원장+실행이력)·폴백 테스트 PASS.
- [ ] 회귀 0 (라이브 적립/회수/사용 복원, 클라이언트 쓰기 차단 불변).
- [ ] FAIL 없거나 후속 작업 분리.
