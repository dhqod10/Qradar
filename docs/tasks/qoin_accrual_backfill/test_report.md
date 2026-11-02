# qoin_accrual_backfill 테스트 리포트

검증일: 2026-11-02 / 방식: 코드 정독 + spec·implementation 대조 + 빌드·테스트 실행 (배포 없음, Emulator 실행 없음)

## 요약
PASS 17 / FAIL 1 / 보류 3

## 실행 결과
- `npm run build` (tsc): PASS
- `node --test test/qoinRateReconstruct.test.mjs`: 7/7 PASS
- `npm test` 전체: 525 중 524 PASS, **1 FAIL** (회귀, 아래 F-1)

## FAIL
### F-1 (우선 수정) 기존 회귀 테스트 `경계 상수는 qoinRate.ts 1곳에서만 선언된다 (F3 재발 방지)` 깨짐
- 위치: `functions/src/backfillQoinAccrual.ts:151` 에러 메시지 문자열 `"overrideRate must be 0.001..0.2 in 0.1% steps"` 안의 리터럴 `0.001`, `0.2`.
- `test/qoinRate.test.mjs:127` 가 qoinRate.ts 외 파일의 코드(주석 제외)에서 경계 리터럴을 중복 선언으로 간주. 동작 버그는 아니나 `npm test` 가 실패하므로 머지 불가.
- 수정안: 메시지를 `"overrideRate invalid"` 처럼 숫자 없이 바꾸거나 qoinRate 의 MIN_RATE/MAX_RATE 를 import 해 템플릿으로 조립.

## PASS (중점 항목)
1. dryRun 기본 true (`d.dryRun !== false`), dryRun 시 `processOne` 이 트랜잭션 전(L331)에 반환 → 원장/users/이슈 쓰기 0, 이력(qoinBackfillHistory)도 `!p.dryRun` 일 때만. 수집·요율 이력 읽기만 수행.
2. 멱등: 사전 earn_{orderId} 존재 skip(already_earned) + 트랜잭션 내 `t.get(earnRef)` 재가드(already_applied). 라이브 trigger 와 동일 ID 체계 → 경합 시 이중 적립 없음. 같은 commit 2회 → 2회차는 already_earned.
3. 불변식: 같은 트랜잭션에서 balance 읽기 → `after = before + amount`, 원장 balanceAfter=after, users 는 `qoinBalance` 1필드만 update(updatedAt 없음). increment 미사용.
4. fail-closed: unrecoverable 은 overrideRate 없으면 rate_unrecoverable skip. override 는 unrecoverable 분기에서만 사용(복원 가능 건은 history_pit 로 override 무시). override 적립은 method `admin_override`, accrualRateSource null 로 거짓 출처 미박제. 이력 없음+현재값 존재/전역 이력 없음/무효 before 모두 unrecoverable(단위테스트 확인). disabled 기간은 creditDisabledPeriod 명시 시에만 적립.
5. scoping: source 필수·화이트리스트, storeRange/range 는 from/to 필수 + 31일 상한, limit 1..500 정수, orderIds 1..500, 쿼리 `.limit(2000)`, issues 도 `.limit(2000)`, truncated 응답. 필터 없는 호출은 invalid-argument.
6. 제외: status != completed(not_completed), self_dealing(findSelfDealing), spend 계열 이슈 사유는 ACCRUAL_ISSUE_REASONS 로 제외, invalid_total, store_unresolvable, zero_amount.
7. 권한: `requireAdmin` (users.role=='admin', 미인증 unauthenticated, 비admin permission-denied) 가 파싱·읽기보다 먼저 실행.
8. 원장/감사: origin:'backfill', backfilledBy/At, backfillReason, sourceIssueId, rateReconstruction.method(history_pit|admin_override)+anchor+gaps 기록. qoinBackfillHistory 는 commit 시 1건(sampleResults 50 상한), 실패 시 historyWarning. 이슈 해소 실패는 적립을 되돌리지 않고 경고.
- 절대규칙: Admin SDK 는 functions 에만 존재, `Color(0x`/API key/secret 하드코딩 없음.
- 범위: git diff 상 수정된 기존 파일은 `functions/src/index.ts`(export 1줄), `functions/package.json`(test 스크립트에 신규 테스트 추가)뿐. onOrderQoinSettled, firestore.rules, indexes 는 무변경. (작업 트리의 lib/*, pubspec 변경은 다른 작업 store_list_pagination 으로 이 기능과 무관.) 신규 컬렉션은 Rules fallback deny → admin SDK 전용.

## 보류
- H-1: 백필 callable 자체(dryRun 쓰기 0, 멱등 2회 실행, 경합)의 자동화 테스트 없음 — 현재는 순수 함수 단위테스트와 코드 정독으로만 검증. Emulator 테스트 추가 권장(dryRun 전후 문서 스냅샷 동일, 2회 실행 시 잔액 1회분).
- H-2: `docs/processes/data_ownership.md` 에 `qoinBackfillHistory` 컬렉션(admin SDK 전용 쓰기) 항목 반영 여부 미확인(grep 0건) — 문서 동기화 필요.
- H-3: 전역 kill switch(config/qoin.enabled) 통과는 D0-4 의도된 설계. 운영 시 켜진 상태에서 소급되므로 실제 commit 전 dryRun 결과 검토 필수(운영 절차 명시 권장). 또한 매장/브랜드 Console 직접 편집은 이력에 없어 gaps(store_console_untracked) 로만 고지됨.
