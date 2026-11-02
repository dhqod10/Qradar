# qoin_accrual_backfill — 구현 내역 (Phase 1)

기준: `spec.md`. Phase 1 = Cloud Functions 백엔드 전용 (UI/Flutter/Rules/인덱스 변경 없음). 배포 안 함.

## 생성 / 수정 파일

| 파일 | 구분 | 내용 |
|---|---|---|
| `functions/src/qoinRateReconstruct.ts` | 신규 | `qoinRateHistory` point-in-time 재구성. 순수(`pitRate`/`pitSwitch`/`reconstructRate`) + 읽기(`loadLayer`) |
| `functions/src/backfillQoinAccrual.ts` | 신규 | admin callable `backfillQoinAccrual` |
| `functions/src/index.ts` | 수정 | export 1줄 추가 |
| `functions/test/qoinRateReconstruct.test.mjs` | 신규 | 재구성 단위 테스트 7건 |
| `functions/package.json` | 수정 | `npm test` 목록에 위 테스트 추가 |

`onOrderQoinSettled` 등 라이브 코드는 수정하지 않았다. 새 원장 타입/멱등 체계 없음 (`earn_{orderId}` 재사용).

## 호출 규약

`backfillQoinAccrual({ dryRun?, source, orderIds?, storeId?, from?, to?, limit?, creditDisabledPeriod?, overrideRate?, reason? })`

- `dryRun` 기본 true. **정확히 `false`** 일 때만 쓴다. dryRun 은 쓰기 0 (실행 이력도 안 남김, `backfillAvailableMainCategories` 와 동일).
- `source`: `issues` | `orderIds`(1..500) | `storeRange`(storeId+from+to) | `range`(from+to). 필터 없으면 invalid-argument. 기간 최대 31일. `limit` 기본 200 / 최대 500. `truncated` 로 잘림 보고.
- 쿼리는 복합 인덱스를 요구하지 않는다: issues 는 `resolved==false` 만 쿼리 후 reason 메모리 필터(최대 2000 문서), 기간은 `completedAt` 범위만 쿼리 후 status/storeId 메모리 필터(최대 2000 문서).
- 응답: `{ dryRun, source, scanned, eligible, truncated, wouldCredit|credited, skippedCounts, totalQoin, results[], historyId? }`. 항목 `outcome`: `would_credit|credited|already_applied|skipped|failed`.

## 처리 흐름 (대상별)

1. 주문 로드. `status==='completed'` 아니면 스킵 (환불/취소 주문 적립 방지). `completedAt` 없으면 `no_completedAt`.
2. `earn_{orderId}` 존재 → `already_earned` (dryRun/commit 공통). 같은 `getAll` 로 이슈 문서도 읽어 `sourceIssueId` 결정 (적립 사유 4종 + `resolved=false` 만; spend 계열 이슈는 절대 건드리지 않음).
3. `totalPrice` 검증 → `invalid_total`. 매장 문서 없음 → `store_unresolvable`.
4. 라이브와 같은 자기적립 제외 → `self_dealing` (소급이 우회로가 되면 안 되므로 spec 에 없지만 추가).
5. 재구성(`reconstructRate`): 매장/브랜드/전역 이력 → 라이브와 같은 `resolveEffectiveRate`. 브랜드는 현재 `stores.brandId` (F1 신뢰원).
   - `disabled` → `disabled_period` 스킵 (`creditDisabledPeriod=true` 면 매장/브랜드 스위치를 전부 무시하고 그 시점 rate 로 적립, 원장에 `switchIgnored:true`).
   - 복원 불가 → `overrideRate` 없으면 `rate_unrecoverable` (사유 detail), 있으면 override 로 적립 (`method:'admin_override'`, `accrualRateSource:null`).
6. `computeEarnAmount` (floor) ≤ 0 → `zero_amount`.
7. commit: 트랜잭션 (`earn` 선존재 가드 → `users.qoinBalance` 절대값 갱신, 이 1필드만). 그 후 issue 문서 `resolved/resolvedBy/resolvedAt/resolvedTxId` 마킹 (실패는 경고만, 적립 유지).
8. 전역 kill switch(`config/qoin.enabled`)는 읽지 않는다 = 통과 (D0-4).
9. 대상별 예외는 해당 건만 `failed` 로 보고하고 계속 (멱등이라 재실행 안전).

원장 `earn_{orderId}`: 라이브 필드 동일 + `origin:'backfill'`, `backfilledBy`, `backfilledAt`, `backfillReason`, `sourceIssueId`, `rateReconstruction{method, anchor, resolvedSource, gaps}`.
실행 이력: commit 시 `qoinBackfillHistory/{autoId}` 1건 (changedBy/changedAt/source/params/reason/scanned/eligible/credited/skippedCounts/totalQoin/sampleResults 최대 50). 기록 실패 시 응답 `historyWarning`.

## spec 대비 판단 / 편차 (확인 요청)

1. **이력 없음 + 현재값 존재 → 복원 불가(fail-closed).** spec §D0-1 4항은 "이력 없으면 상위 상속" 이지만, 현재 문서에 값이 있는데 이력이 없으면 Console 직접 편집/H7 이전 설정이라 상속이 틀린 금액을 줄 수 있다. 사용자 결정(복원 불가는 skip)에 맞춰 더 엄격하게 구현. 전역은 이력이 없으면 항상 복원 불가.
2. 보조 스킵 사유 추가: `order_not_found`, `not_completed`, `no_user`, `self_dealing`, `zero_amount`, 그리고 outcome `failed`.
3. override 건의 `accrualRateSource` 는 `null` (거짓 출처 박제 방지). Dart 쪽은 이 필드를 파싱하지 않음(확인). 정산(N1) 집계 시 `origin`/`rateReconstruction.method` 로 구별 필요.
4. `dryRun` 은 실행 이력 미기록 (spec 3.3 은 "실행 1건" 이나 dryRun 쓰기 0 요구와 패턴 우선).
5. Tier1 사유 필터/기간 쿼리는 인덱스 비용을 피하려 메모리 필터 + 2000 문서 상한.

## 알려진 한계

- `config/qoin` 직접 편집으로 무효 문자열이 들어간 경우 이력 `after` 가 null(clear)로 기록돼 무효 구간을 "부재"로 읽는다 (→ 전역은 결국 부재 = 복원 불가라 안전 방향).
- 매장/브랜드 Console 편집은 감시되지 않아 `gaps:['store_console_untracked','brand_console_untracked']` 를 항상 고지.
- 매장의 브랜드 소속 이동 이력은 없어 현재 `brandId` 사용.

## 테스트 포인트 (tester)

- 멱등: 라이브가 이미 적립한 주문 → `already_earned`; 같은 commit 2회 → 1회만 적립; 라이브 earn 과 동시 경합 → 이중 적립 0.
- 재구성: 완료 후 요율 변경(매장/브랜드/전역 각각), `op:'clear'` 상속, 이후 최초 항목 `before` 사용, 이력 없음+현재값 → `rate_unrecoverable`.
- 스위치 off 기간: `creditDisabledPeriod` false → `disabled_period` / true → 적립 + `switchIgnored`.
- override: 복원 불가 건은 `overrideRate` 없으면 skip, 있으면 `admin_override` 박제. 복원 가능 건은 override 무시.
- kill switch(`enabled=false`) 중에도 통과. 자기적립 주문 skip. refunded/cancelled 주문 skip.
- dryRun(기본): 쓰기 0 (원장/잔액/이슈/이력). commit: 이슈 `resolved=true`, `qoinBackfillHistory` 1건.
- spend 계열 이슈는 대상/마킹 제외. 필터 없는 호출/31일 초과/limit 초과/비admin → 거부.
- 이후 환불 시 clawback 이 소급 earn 금액을 반전하는지. 불변식 `qoinBalance == Σ amount`.
- 에뮬레이터 통합 테스트는 이번에 작성하지 않음.

## 검증 결과

- `functions` `npm run build` (tsc): 통과.
- `node --test test/qoinRateReconstruct.test.mjs`: 7/7 pass. (전체 `npm test` 는 미실행)
- Dart 변경 없음 → `flutter analyze` 해당 없음.

## 미구현 / 보류

- Phase 2 admin UI (backlog). 에뮬레이터 동시성/통합 테스트. Security Rules 변경 없음 (`qoinBackfillHistory` 는 Rules 무규칙 = 클라이언트 접근 불가).
- 배포는 하지 않음 (사용자 직접).
