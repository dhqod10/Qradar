# qoin_accrual_backfill_admin_ui 기능 명세

적립 소급(백필) 운영 도구의 **Phase 2 관리자 화면** — 대상/조건 선택 → `dryRun` 미리보기 → 실제 실행(2차 확인)을 어드민 **웹 콘솔**(`landing/console`)에 구현한다.

- 작업 유형: 기존 운영 도구의 **프론트엔드(웹 콘솔) 확장**. Cloud Function / Firestore Rules / 인덱스 변경 **없음**.
- 선행: `qoin_accrual_backfill/spec.md`(Phase 1, callable 구현·배포 완료). 그 §0 D0-5 가 "Phase 2 = UI" 로 미뤄둔 작업이다.
- 상태: **설계(spec) 단계.** developer 호출 전.

---

## §0 사용자 확인 필요 결정사항 (권고 포함)

> **✅ 2026-11-03 확정 (사용자 부재 중 "3번 전부 알아서 진행" 위임에 따라 전 항목 권고안대로 채택)**: D1 웹 콘솔 / D2 디자이너 생략 / D3 hosting 전용·CF 변경 없음 / **D4 commit 시 reason 필수·미리보기 선택** / **D5 overrideRate 고급 접힘+경고+별도확인** / D6 source 기본값 issues. 돌아온 뒤 D4·D5 UX 는 재검토 가능(설계 변경 없이 게이트만 완화/강화 가능).
>
> 설계자가 권고안을 정해두었다. 본문은 **권고안 기준**으로 작성돼 있다.

| # | 결정할 것 | 권고안 | 근거 / 트레이드오프 |
|---|---|---|---|
| **D1** | **구현 위치** | **웹 콘솔(`landing/console`) Phase 2** | 기존 백필 도구(`#/tools`)·회원 관리가 전부 웹 콘솔이다(`section-admin.js:64-65`). Flutter admin 화면이 아니다. → **디자이너 불필요**(아래 D2). |
| **D2** | **디자이너 호출 여부** | **불필요 (designer 생략)** | 웹 콘솔은 Flutter 가 아닌 빌드 없는 정적 사이트로 **Qradar Flutter 디자인 시스템(`AppColors` 등) 비적용 영역**이다(`console-data.js:5-8`). 기존 콘솔 컴포넌트(`console-ui.js` 의 `banner`/`field`/`kv`/`openDialog`/`toast`, `--border`/`--surface` 등 CSS 변수)를 그대로 재사용한다. 새 시각 언어를 만들 이유가 없다. |
| **D3** | **배포 경계** | **hosting 전용 배포** (CF/Rules/인덱스 변경 없음) | 배포된 callable `backfillQoinAccrual` 이 이미 모든 입력(`source`/`orderIds`/`storeId`/`from`/`to`/`limit`/`creditDisabledPeriod`/`overrideRate`/`reason`)과 `dryRun`/commit·멱등·이력(`qoinBackfillHistory`)을 지원한다(`functions/src/backfillQoinAccrual.ts:71-168, 391-484`). 화면은 그 범위 **안에서만** 설계한다. **functions 재배포 불필요.** 만약 리뷰 중 callable 변경이 필요해지면 그 사실과 "**functions 재배포는 사용자 몫**" 을 별도 표기하고 설계를 되돌린다 — 현재 설계는 **변경 불필요**로 성립한다. |
| **D4** | **commit 시 `reason`(사유) 필수 여부** | **commit 은 필수, `dryRun` 은 선택** | callable 은 `reason` 을 선택(nullable, trim 후 ≤200자, `qoinAdmin.ts:30-40`)으로 받지만, commit 은 **고객 돈의 사후 발행**이라 `qoinBackfillHistory.reason`(audit) 가치가 크다. UI 에서 commit 게이트로 사유 입력을 요구한다(미입력 시 실행 버튼 비활성). 미리보기는 사유 없이 가능. 반대로 마찰을 줄이려면 선택으로 낮춰도 설계 변경 없음(게이트만 완화). |
| **D5** | **`overrideRate`(강제 요율) UI 노출 수준** | **"고급" 접힘 영역 + 입력 시 경고 + 별도 확인** | `overrideRate` 는 "당시 요율" 이 아닌 강제값으로, 원장에 `rateReconstruction.method:'admin_override'` 로 영구 박제된다(`backfillQoinAccrual.ts:307-314`). 실수 입력이 가장 위험하므로 기본 접힘, 값이 있으면 미리보기/실행 전 경고 배너를 띄운다. 대안(상시 노출)은 오입력 위험↑. |
| **D6** | **source 기본 선택값** | **`issues`(미해결 적립 누락 이슈)** | 현행 버튼이 이미 `source='issues'` 다(`console-data.js:351`). 가장 안전·정밀한 대상(이미 "누락 확정" 목록). 나머지 3종은 opt-in. |

> **아래는 질문이 아니라 확정 사항이다**(안전 불변식):
> - **미리보기-실행 파라미터 일치 강제**: "실제 실행"(dryRun=false)은 **직전 미리보기와 동일한 입력**으로만 가능하다. 미리보기 성공 후 입력(폼) 중 하나라도 바뀌면 실행 버튼을 즉시 잠그고 재미리보기를 요구한다. (현행 `wireTool` 은 입력이 없어 이 잠금이 없다 — Phase 2 의 신규 필수 로직. `section-admin.js:270-318`)
> - **UI 는 Firestore 에 직접 쓰지 않는다.** 모든 쓰기(적립·이력)는 callable 서버가 한다. 콘솔은 호출·표시만.

---

## 1. 개요

### 목적

적립이 누락된 완료 주문에 Qoin 을 소급 적립하는 운영을, 지금의 "버튼 3개(이슈 전체 미리보기/실행)"(`section-admin.js:229-235, 259-268`)에서 **대상/조건을 골라 미리보기로 영향 범위(건수·소급 Qoin 합계·skip 사유)를 확인한 뒤 실행**하는 제대로 된 관리자 화면으로 끌어올린다.

### 영향 범위

- **웹 콘솔(변경)**:
  - `landing/console/assets/console-data.js` — wrapper `runBackfillQoinAccrual` 을 **전체 파라미터**를 받도록 확장(현재는 `dryRun`, `source='issues'` 만 전달, `console-data.js:351-355`).
  - `landing/console/assets/section-admin.js` — `#/tools` 의 **Qoin 적립 소급 패널을 폼 기반 전용 뷰**로 교체. `geo`/`search` 백필은 기존 단순 패널(`wireTool`) 유지.
  - (필요 시) `landing/console/assets/console.css` 또는 기존 CSS — 신규 클래스 없이 기존 변수/클래스(`a-field`/`a-banner`/`a-btn`/`a-kv`/`a-chips`)로 해결 가능하면 CSS 변경 0 을 목표로 한다.
- **Flutter 앱(`lib/`)**: 변경 **없음**.
- **Cloud Functions / Firestore Rules / 인덱스**: 변경 **없음**(D3).
- **권한**: 변경 없음. 조회·실행 모두 admin 전용 셸에서만 import 되며(`section-admin.js:6-8`), 최종 권위는 callable 의 `requireAdmin`(`backfillQoinAccrual.ts:393`).

### 비범위

- callable(`backfillQoinAccrual`) 로직·스키마 변경 — 건드리지 않는다(회귀 0).
- `geo`/`search` 백필 도구의 UI 변경 — 현행 유지.
- `qoinSettlementIssues` 목록을 콘솔에서 직접 조회/탐색하는 별도 화면 — 이번 범위 아님(`source='issues'` 미리보기 결과로 충분). 필요해지면 후속.
- 적립 비용 정산/청구(audit_trail §5).
- `qoinRateHistory` 도입 이전 구간의 과거 요율 복원 — 구조적 불가(Phase 1 비범위 그대로).
- Flutter admin 으로의 이식 — 하지 않는다(D1).

---

## 2. 요구사항

### 기능 요구사항

- [ ] `#/tools` 의 Qoin 적립 소급 패널에서 **대상(source)** 을 고른다: `issues` / `orderIds` / `storeRange` / `range`. (callable 지원값 1:1, `backfillQoinAccrual.ts:42, 102-105`)
- [ ] source 에 따라 **조건 입력**을 조건부 노출한다(아래 §3 입력 매핑). callable 이 받지 않는 필터는 만들지 않는다.
- [ ] **미리보기**(dryRun=true): 쓰기 없이 영향 범위를 받아 **대상 건수 / 소급 Qoin 합계 / scan 수 / truncated 여부 / skip 사유별 집계 / 샘플 항목**을 표시한다(`backfillQoinAccrual.ts:422-432` 응답 스키마).
- [ ] **실제 실행**(dryRun=false): 미리보기 성공 후에만 활성화되며, **동일 입력**으로만 실행한다(§0 불변식). 2차 확인 통과 시 호출.
- [ ] 실행 결과: **적립 건수 / 소급 Qoin 합계 / skip 집계 / 이력 ID(`historyId`)** 를 표시하고, `historyWarning`(이력 기록 실패) 이 오면 **경고로 분명히 드러낸다**(§5 audit).
- [ ] `orderIds` 입력: 줄바꿈/쉼표 구분 다중 입력을 배열로 파싱, 중복 제거, `/` 포함·빈 문자열 거부(클라 1차 검증; 서버 재검증 `backfillQoinAccrual.ts:116-126`).
- [ ] `from`/`to`: 날짜·시각 입력. `to > from`, 기간 ≤ 31일을 클라에서 1차 안내(서버 경계 `ts:136-143`).
- [ ] `limit`: 1~500 정수, 기본 200(`ts:31-32, 107-113`).
- [ ] `creditDisabledPeriod`: 체크박스, 기본 꺼짐(`ts:145-147`).
- [ ] `overrideRate`: % 입력(0.1% 단위, 0.1%~20%), 내부적으로 소수(0.001~0.2)로 변환. 입력 시 경고(D5). 서버 경계 `isValidCallableRate`(`qoinRate.ts:103-108`, `MIN_RATE=0.001`/`MAX_RATE=0.2`/0.1% 격자).
- [ ] `reason`: 텍스트(≤200자). commit 필수(D4), 미리보기 선택.

### UI/표시 요구사항 (디자이너 생략 — 설계자가 콘솔 패턴으로 확정)

- [ ] 기존 콘솔 컴포넌트만 사용: 입력은 `field()`/`chipGroup()`/기존 인라인 input 스타일, 안내·경고·결과는 `banner()`, 요약은 `kv()`, 2차 확인은 `openDialog()` 또는 최소 `window.confirm`. (`console-ui.js:75-147, 249-337, 376-389, 446-449`)
- [ ] 미리보기 결과는 현재처럼 raw JSON `<pre>` 만 던지지 말고(현 `section-admin.js:278-281`), **요약(건수/합계/skip 집계)을 사람이 읽을 수 있는 블록**으로 먼저 보여주고, 전체 JSON 은 접힘/보조로 둔다.
- [ ] skip 사유 라벨을 한국어로 매핑해 보여준다(예: `already_earned`→"이미 적립됨", `rate_unrecoverable`→"당시 요율 복원 불가", `disabled_period`→"적립 꺼져 있던 기간", `self_dealing`→"자기적립 제외" 등. 사유 enum: `backfillQoinAccrual.ts:44-56`).
- [ ] `truncated=true` 면 "대상이 한 번에 다 담기지 않았어요 — 범위를 좁히거나 실행 후 다시 미리보기 하세요" 경고.
- [ ] 색/하드코딩 금지 규칙은 Flutter 영역 규칙이며 콘솔엔 적용되지 않으나, **기존 CSS 변수(`var(--border)` 등)만** 쓰고 새 색을 하드코딩하지 않는다.

### 상태 요구사항

- [ ] loading: 미리보기/실행 중 해당 버튼 스피너·비활성(기존 `setBusy` 패턴, `section-admin.js:282-285`).
- [ ] error: callable 거부(`invalid-argument`/`permission-denied`/타임아웃)는 기존 `writeErrorText`/`banner('error',...)` 경로로 표시(`section-admin.js:304-306`). 거부 시 적립이 일어나지 않았음이 분명해야 한다.
- [ ] empty: 미리보기 결과 `eligible=0` 이면 "소급할 대상이 없어요" 빈 상태 + 실행 버튼 비활성.
- [ ] 입력 변경: 미리보기 이후 입력이 바뀌면 실행 버튼 잠금 + "입력이 바뀌었어요. 다시 미리보기 하세요" 안내(§0 불변식).

---

## 3. 화면 / 입력 매핑 (callable 1:1)

패널 상단: 제목·설명(현행 `TOOLS.qoin.h2/desc` 문구 재사용 가능, `section-admin.js:230-231`), 그 아래 폼 → [미리보기] / [실제 실행(비활성)] → 미리보기 요약 → (접힘) 전체 JSON.

| UI 입력 | callable 파라미터 | 노출 조건 | 검증(클라 1차) | 서버 경계(근거) |
|---|---|---|---|---|
| 대상 선택 (칩/셀렉트) | `source` | 항상 | 4값 중 1 | `ts:102-105` |
| 주문 ID 목록 (textarea) | `orderIds[]` | `source==orderIds` | 1~500개, 공백/`/` 제거, 중복 제거 | `ts:116-126` |
| 매장 ID (text) | `storeId` | `source==storeRange` | 비어있지 않음, `/` 불가 | `ts:128-134` |
| 시작 일시 / 종료 일시 | `from` / `to` | `source∈{storeRange,range}` | ISO/millis, `to>from`, ≤31일 | `ts:136-143` |
| 건수 상한 (number) | `limit` | 항상(기본 200) | 정수 1~500 | `ts:107-113` |
| 적립 꺼진 기간도 소급 (checkbox) | `creditDisabledPeriod` | 항상(기본 꺼짐) | bool | `ts:145-147, 289-299` |
| 강제 요율 % (고급·접힘) | `overrideRate` | 선택 | 0.1% 격자, 0.1~20%, 소수 변환 | `qoinRate.ts:103-108` |
| 사유 (text) | `reason` | 항상 | ≤200자, commit 필수(D4) | `qoinAdmin.ts:30-40` |

> `issues` source 는 추가 필수 입력이 없다(현행과 동일). `limit`/`creditDisabledPeriod`/`overrideRate`/`reason` 은 모든 source 에 공통으로 적용된다.

### 미리보기 응답 → 표시 매핑 (`backfillQoinAccrual.ts:422-432`)

- `eligible` / `wouldCredit` → "소급 대상 N건"
- `totalQoin` → "소급 예정 Qoin 합계 ... Q"
- `scanned`, `truncated` → "스캔 N건 / (truncated 시) 일부만 조회됨" 경고
- `skippedCounts` (사유→수 객체) → 한국어 라벨 리스트
- `results[]` → 샘플 테이블(orderId·outcome·rate·amount·reconstruction.method). 양이 많으면 상한 표시.

### 실행 응답 → 표시 매핑

- `credited`, `totalQoin`, `skippedCounts` → 결과 요약 + `toast('소급 적립을 실행했어요')`.
- `historyId` → "실행 이력 기록됨" / `historyWarning==='history_write_failed'` → **경고 배너**("적립은 완료됐지만 실행 이력 기록에 실패했어요 — 운영 기록을 수동 확인하세요", `ts:434-472`).

---

## 4. 데이터 흐름

```text
[#/tools Qoin 소급 패널]  (section-admin.js)
  └ 폼 입력 수집·클라 1차 검증 → params = {dryRun, source, orderIds?/storeId?/from?/to?, limit, creditDisabledPeriod, overrideRate?, reason?}
  └ 미리보기:  runBackfillQoinAccrual({ ...params, dryRun:true })   (console-data.js, 확장)
        └ httpsCallable('backfillQoinAccrual')  →  서버 재검증·재구성·쓰기 0  →  응답(eligible/totalQoin/skippedCounts/results/truncated)
        └ 성공 시 previewedParams 저장, "실제 실행" 활성화
  └ (입력 변경 감지 → previewedParams 무효화 → 실행 버튼 잠금)
  └ 실제 실행:  2차 확인(openDialog: 범위 요약 표시) → runBackfillQoinAccrual({ ...previewedParams, dryRun:false })
        └ 서버: earn_{orderId} 멱등·당시요율 재구성·users.qoinBalance 갱신·qoinSettlementIssues resolved·qoinBackfillHistory 1건
        └ 응답(credited/totalQoin/historyId) → 결과 표시 + toast
```

> developer 는 wrapper `runBackfillQoinAccrual(dryRun, source)`(현 `console-data.js:351-355`)를 **단일 params 객체**를 받는 형태로 확장하되, 서버가 모르는 키를 보내지 않도록(불필요 키 제거) 한다. `httpsCallable` 호출·타임아웃(`BACKFILL_TIMEOUT_MS`) 패턴은 그대로 재사용.

---

## 5. 이력 / 감사 추적 (audit_trail.md §4 체크리스트)

> 이 기능은 **돈(Qoin 적립)** 을 움직인다. 그러나 **설정 변경 이력/거래 발행 이력을 쓰는 주체는 이미 callable 서버**이며, 이번 작업은 그 callable 을 **호출하는 프론트엔드**일 뿐이다. 콘솔은 Firestore 에 직접 쓰지 않는다.

| # | 항목 | 판정 |
|---|---|---|
| 1 | 돈·권한·정책 값을 바꾸는가? → 설정 변경 이력 필요? | **예(돈).** 단 **발행 이력은 이미 존재**한다 — commit 시 서버가 `qoinBackfillHistory/{autoId}` 1건을 `changedBy`(admin uid)/`changedAt`/`source`/`params`/`reason`/`credited`/`totalQoin`/`skippedCounts`/`truncated`/`sampleResults` 로 남긴다(`backfillQoinAccrual.ts:436-468`, data_ownership.md:396). **UI 는 이력을 쓰지 않는다.** UI 의 책무는 그 이력이 **기록됐는지(`historyId`)/실패했는지(`historyWarning`)를 운영자에게 드러내는 것** → 요구사항에 포함(§3). |
| 2 | 덮어쓰기로 사라지는 값이 있는가? | 없음. 원장은 append-only(`earn_{orderId}`), 잔액은 서버 트랜잭션 절대값 갱신. UI 는 읽기/호출만. |
| 3 | 거래 문서가 정책 값을 참조만 하는가? | 해당 없음(UI 는 문서를 만들지 않음). 서버가 당시 요율·금액을 원장에 박제(`ts:342-363`). |
| 4 | "누가" 가 기록되는가? | **예.** `changedBy`/`backfilledBy` = 호출한 admin uid(서버가 `requireAdmin` 으로 확정). UI 가 별도로 행위자를 넣을 필요 없음. **UI 는 `reason` 을 실어 "왜" 를 보강**한다(D4). |
| 5 | 일괄 처리(batch)가 있는가? | 예(여러 주문 일괄 소급). 영향 범위(`credited`/`totalQoin`/`skippedCounts`/`truncated`/`sampleResults`)가 `qoinBackfillHistory` 1건에 이미 남는다(§4-5 형식 충족). |
| 6 | CF 로그에 의존하는가? | 아니오. 영구 기록은 `qoinBackfillHistory`(Firestore). UI 는 응답의 `historyId` 로 그 사실을 확인·표시. |
| 7 | 권한 판정 필드의 create/update 양쪽 확인 | 해당 없음. UI 는 Rules 판정 입력 필드를 쓰지 않는다. callable 의 admin 재검증이 유일한 권위(`ts:393`). |

**설정 변경 이력을 UI 가 추가로 남기지 않는 사유(명시)**: 소급 발행의 감사 흔적(`qoinBackfillHistory`)은 **이미 서버가 commit 마다 남긴다.** 프론트엔드가 별도 이력을 쓰면 위조·누락 위험만 늘고(audit_trail §4 "쓰기 주체는 CF 가 기본"), 이중 기록이 된다. 따라서 **UI 는 이력을 쓰지 않고, 서버 이력의 성공/실패를 드러내는 책무만** 진다.

---

## 6. 에러 처리

| 케이스 | 처리 |
|---|---|
| source 별 필수 입력 누락(orderIds/storeId/from/to) | 제출 전 인라인 안내, 미리보기 차단 |
| 기간 > 31일 / `to ≤ from` | 제출 전 안내(서버도 거부 `ts:141-142`) |
| limit 범위 밖 / overrideRate 격자 밖 | 제출 전 안내(서버도 거부) |
| commit 인데 reason 빈값(D4) | 실행 버튼 비활성 + 안내 |
| callable `invalid-argument` | `banner('error', '실패', writeErrorText(e).text)`, 적립 미발생 명시 |
| `permission-denied`/세션만료 | 기존 콘솔 권한 재확인 흐름 재사용 |
| 타임아웃(결과 불명) | "반영 여부를 확인하지 못했어요 — 같은 입력으로 다시 미리보기 하면 이미 적립된 건은 `already_earned`/`already_applied` 로 스킵돼요(멱등)" 안내(`ts:257, 334-336, 368`) |
| 미리보기 후 입력 변경 | 실행 버튼 잠금(§0 불변식) |
| `historyWarning` | 적립은 성공했음을 알리되, 이력 기록 실패 경고를 별도로 표시 |

> 멱등 덕분에 재시도는 안전하다 — 안내 문구가 이 점을 활용해 운영자의 불안을 덜도록 한다.

---

## 7. 작업 분배

### designer — 호출하지 않음

- 사유: 웹 콘솔은 Flutter 디자인 시스템 비적용 영역이며(D1/D2), 기존 콘솔 컴포넌트·CSS 변수를 재사용한다. 새 시각 자산·토큰이 없다.

### developer — `docs/tasks/qoin_accrual_backfill_admin_ui/implementation.md`

구현 항목:
- `console-data.js`: `runBackfillQoinAccrual` 을 **params 객체**(dryRun 포함, source 별 조건 키) 수신형으로 확장. 서버 미지원 키 미전송. 타임아웃/`httpsCallable` 패턴 유지.
- `section-admin.js`: `#/tools` 의 Qoin 패널을 **폼 기반 전용 뷰 + 전용 wiring**(회원 관리 `viewUsers`/`wireUserCard` 를 패턴 선례로, `section-admin.js:325-488`)으로 교체. source 조건부 입력, 클라 1차 검증, 미리보기 요약 렌더, skip 사유 한국어 매핑, truncated/historyWarning 경고, **미리보기-실행 파라미터 일치 잠금**, 2차 확인(`openDialog` 권고) 구현. `geo`/`search` 는 기존 `wireTool` 유지.
- (가능하면) CSS 변경 0 — 기존 클래스로 해결.

반드시 지킬 것:
- **callable 입력/출력 스키마를 코드(`backfillQoinAccrual.ts`)에서 다시 읽고 1:1 로 맞춘다.** 지원하지 않는 필터를 만들지 않는다. (과거 필드명 추측 오류 전례)
- **UI 에서 Firestore 직접 쓰기 금지** — 모든 쓰기는 callable.
- landing 배포 규칙 준수: **hosting 만** 배포, `firebase.json` 재수정 금지, `git add landing/` 만, landing 밖 수정 금지(§memory landing 배포 규칙). CF/Rules/인덱스 변경 없음.

### tester — `docs/tasks/qoin_accrual_backfill_admin_ui/test_report.md`

호출 시점: **developer 구현 완료 후.** (CF/Rules 변경이 없으므로 Rules 하네스 신규 케이스는 없다.)

주요 검증:
- source 전환 시 조건부 입력 노출/숨김, 클라 1차 검증(필수 누락·기간·limit·overrideRate 격자).
- 미리보기 응답 → 요약(건수/합계/skip 집계/truncated) 표시 정확성, raw JSON 보조 표시.
- **미리보기-실행 파라미터 일치 잠금**: 미리보기 후 입력 변경 → 실행 버튼 잠금 재현.
- commit reason 게이트(D4), overrideRate 경고(D5).
- 실행 결과 표시(credited/totalQoin/historyId) 및 `historyWarning` 경고 경로.
- 에러 경로: `invalid-argument`/`permission-denied`/타임아웃 표시, 적립 미발생 명시.

**반드시 지킬 테스트 안전수칙(돈)**:
- **실제 commit(dryRun=false)을 운영 데이터에 함부로 실행하지 않는다.** 검증은 (1) dryRun 경로, (2) 파라미터 전달/검증/UI 상태 전이, (3) 콜러블 입력 경계에 집중한다. commit 실제 호출은 **별도 테스트 환경 또는 소급 대상이 0건임이 미리보기로 확인된 입력**에서만, 사용자 승인하에 수행한다. 멱등이라 재시도는 안전하나, 임의 매장/기간 commit 은 고객 잔액을 실제로 바꾼다.

---

## 8. 완료 기준

- [ ] §0 D1~D6 가 사용자 확인으로 확정됨
- [ ] `runBackfillQoinAccrual` wrapper 가 전체 파라미터를 전달하도록 확장됨(서버 미지원 키 미전송)
- [ ] `#/tools` Qoin 패널이 폼 기반 미리보기→실행 뷰로 교체됨(geo/search 는 현행 유지)
- [ ] 미리보기 요약·skip 한국어 매핑·truncated/historyWarning 경고·실행 결과 표시 구현
- [ ] 미리보기-실행 파라미터 일치 잠금, 2차 확인, commit reason 게이트 동작
- [ ] CF/Rules/인덱스 변경 0, hosting 전용 배포 경계 유지
- [ ] `implementation.md` / `test_report.md` 작성, FAIL 없음(또는 후속 분리)
