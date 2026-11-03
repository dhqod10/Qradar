# Qoin 정책 관리자 화면 기능 명세 (qoin_policy_admin_ui)

- 작성: 2026-11-03 / architect
- 한 줄 요약: 지금까지 Firebase Console 직접편집·수동 callable 호출로 바꾸던 **Qoin 적립 정책**(전역/브랜드/매장 적립률 + 브랜드/매장 적립 스위치 + 브랜드 일괄 적용)을 **웹 콘솔(landing/console)의 관리자 화면**으로 정리한다. **이미 배포된 callable 3종을 UI 에 배선**하는 작업이며 functions/Rules 변경이 없다(= hosting 전용 배포).

---

## §0 설계 판단 (옵션 + 권고) — 사용자 확인 필요

> **✅ 2026-11-03 확정 (사용자 부재 중 "3번 전부 알아서 진행" 위임에 따라 권고안대로 채택)**: D0-1 범위=✅ 6종(적립 정책), **D0-2 글로벌 비상정지 토글=옵션 A(읽기 카드 유지, 미포함)**, D0-3 spend 전면 비범위(게이트), D0-4 웹 콘솔·디자이너 불필요, D0-5 hosting 전용·CF/Rules 무변경, 배치=전역 전용화면+브랜드/매장 각 상세. **콘솔 Firestore 직접쓰기 없음(전부 callable 경유).** 돌아온 뒤 D0-2(비상정지 토글)·단일화면 선호는 재논의 가능.

이 절은 developer 진행 전에 사용자가 읽고 확정해야 하는 결정들이다. (위 확정 참조.)

### D0-1 범위 — 지금 관리 가능한 knob (코드 근거로 확정)

쓰기 경로가 **이미 배포된 callable** 로 존재하고, 지금 운영 중인 knob 만 다룬다.

| knob | 저장 위치 | 쓰기 callable | 상태 | 이번 범위 |
|---|---|---|---|---|
| 전역 적립률 | `config/qoin.accrualRate` | `setQoinAccrualRate` (`scope:'global'`) | 배포됨 (`index.ts:25`) | ✅ 포함 |
| 브랜드 적립률 | `brands/{id}.qoinAccrualRate` | `setQoinAccrualRate` (`scope:'brand'`) | 배포됨 | ✅ 포함 |
| 매장 적립률 | `stores/{id}.qoinAccrualRate` | `setQoinAccrualRate` (`scope:'store'`) | 배포됨 | ✅ 포함 |
| 브랜드 적립 스위치 | `brands/{id}.qoinAccrualEnabled` | `setQoinAccrualEnabled` (`scope:'brand'`) | 배포됨 (`index.ts:26`) | ✅ 포함 |
| 매장 적립 스위치 | `stores/{id}.qoinAccrualEnabled` | `setQoinAccrualEnabled` (`scope:'store'`) | 배포됨 | ✅ 포함 |
| 브랜드 일괄 적용 | 브랜드 값 + 산하 매장 개별값 처리 | `applyBrandQoinRate` | 배포됨 (`index.ts:29`) | ✅ 포함 |
| **Qoin 사용(spend) 정책** | `config/qoin.spendEnabled`/`minSpendUnit`/`minCashFloor` | `setQoinSpendPolicy` (`index.ts:28`) | 배포됨이나 **게이트 OFF** | ❌ **비범위 (D0-3)** |
| 1회성 0요율 마이그레이션 | — | `migrateQoinZeroRates` (임시) | 1회성 도구 | ❌ 비범위 (정책 knob 아님, 삭제 예정 도구) |

**권고**: 위 ✅ 6종을 이번 범위로 확정. spend 는 아래 D0-3 사유로 전면 제외.

### D0-2 글로벌 비상 정지(`config/qoin.enabled`) 토글 — 결정 필요

- `config/qoin.enabled` 는 적립·회수·사용을 **모두** 멈추는 비상 정지다. 유일하게 **admin 직접 쓰기**가 열려 있다(CF 장애 중에도 꺼야 하므로 — data_ownership §2.11.2). 콘솔이 쓰려면 같은 write 에 **`enabled` + `enabledChangedBy == uid()` + `enabledChangedAt == FieldValue.serverTimestamp()` 세 필드를 반드시 함께** 써야 이력(`onQoinConfigWritten`)에 행위자가 남는다(셋 중 하나라도 빠지면 Console 직접편집과 구분 불가 → 행위자 `null`).
- 현재 `viewQoin` 은 이 값을 **읽기 카드**로만 보여준다(`section-admin.js:167`).
- **옵션 A (권고)**: 이번 범위에서 **토글은 넣지 않고 읽기 카드 유지**. 비상 정지는 빈도가 극히 낮고 오조작 시 매출·적립이 전면 중단되는 최고위험 knob이라, 적립 정책 정리와 분리한다. 비상 시 Firebase Console 직접 토글은 현행 유지.
- **옵션 B**: 넣는다면 **이중 확인 + 명시적 "비상 정지" 라벨 + 직접 Firestore write(3필드 동시)**. callable 이 아니므로 유일하게 콘솔에서 Firestore 를 직접 쓰는 경로가 된다(배선 방식이 나머지와 다름). 여전히 hosting 전용 배포.
- **권고: 옵션 A.** 사용자가 B 를 원하면 추가.

### D0-3 Spend 정책 비범위 — 사유 (핵심 제약)

Qoin **사용(spend)** 기능은 현재 **OFF** 이고 런칭 게이트(**토스 최소결제금액 + 점주 정산 N4 결정**)에 묶여 있다(MEMORY: `project_qoin_spend_enable_gate`). 이 화면은 **spend 를 활성화하거나 spend 정책을 켜는 조작을 일절 제공하지 않는다.**

- `setQoinSpendPolicy`(`spendEnabled`/`minSpendUnit`/`minCashFloor`)는 **배선하지 않는다.**
- `config/qoin.enabled` 가 spend 도 멈추지만, 이는 "끄는" 방향이라 게이트와 무관(D0-2 참조).
- spend 정책 화면은 **"게이트 해제 후 Phase 2"** 로 분리한다. 게이트 해제(토스 최소금액·N4 정산)는 사용자 결정 사항이며 현재 미확정이므로, spend UI 를 지금 설계하면 사용하지 못할 화면을 만들게 된다.

### D0-4 위치 — 웹 콘솔 (designer 불필요)

- 모든 어드민 도구가 **웹 콘솔(landing/console, vanilla JS)** 에 있다(브랜드/매장 승인, 회원관리, 백필, Qoin 현황 전부). Flutter admin 앱은 **없다**.
- 따라서 이 기능도 **웹 콘솔**에 둔다. **Flutter 쪽 작업 없음 → AppColors/Clean Architecture 레이어 설계는 N/A.** 기존 콘솔 스타일/컴포넌트(`a-*` 클래스, `openModal`, `banner`, `toast`)를 재사용한다.
- **designer 생략.** 신규 화면 레이아웃이 아니라 기존 `viewQoin`/브랜드·매장 상세 화면에 편집 컨트롤을 더하는 것이고, 콘솔 디자인 시스템이 이미 확립돼 있다.

### D0-5 쓰기 경로 / 배포 경계 (중요)

- **새 callable / Rules / Firestore 인덱스 변경 없음.** 3종 callable 이 이미 배포돼 있고, 읽기 권한(`getQoinConfig`/history read)도 이미 열려 있다.
- 따라서 **hosting 전용 배포**로 끝난다(landing deploy 규칙 준수: hosting 만, `firebase.json` 재수정 금지, `git add landing/` 만, landing 밖 소스 수정 금지 — docs/tasks 는 배포물 아님).
- ⚠️ **예외 — 콜렉션그룹 전역 이력 피드를 원하면 인덱스 배포가 선행**된다. `/{path=**}/qoinRateHistory` CG 쿼리는 복합 인덱스가 필요하다(data_ownership §2.11.3). **이번 범위는 CG 피드를 넣지 않고** 범위별 단일 부모 쿼리(`listQoinHistory`=전역, `listQoinHistoryOf(parentPath)`=브랜드/매장)만 쓴다 → 인덱스 불필요, hosting 전용 유지. (CG 통합 피드는 Phase 2 후보, 그때 인덱스 배포는 **사용자 몫**.)

---

## 개요

- **목적**: Qoin 적립 정책 값(전역/브랜드/매장 적립률, 브랜드/매장 적립 스위치, 브랜드 일괄 적용)을 Firebase Console 직접편집·수동 callable 대신 **관리자 콘솔 화면**에서 안전하게(확인 단계·범위 검증·이력 자동) 변경한다.
- **작업 유형**: 기존 기능 수정 (읽기 전용 Qoin 현황 → 편집 가능) + 기존 콘솔 상세 화면에 편집 컨트롤 추가.
- **영향 범위**:
  - 화면(콘솔): `viewQoin`(전역 적립률 편집 + 범위별 이력), `viewBrandDetail`(브랜드 적립률/스위치/일괄), `viewStoreDetail`(매장 적립률/스위치). — `landing/console/assets/section-admin.js`
  - 데이터 계층(콘솔): Qoin **쓰기** 함수 신설 — `landing/console/assets/console-data.js`
  - 공통(콘솔): 기존 `openModal`/`banner`/`toast`/`writeErrorText`/rate 헬퍼 재사용 — `console-ui.js`, `console-format.js`
  - Firebase/Functions: **변경 없음** (기존 callable 호출만)
  - Rules / 인덱스: **변경 없음**
  - 권한: admin 전용(콘솔 자체가 admin 게이트, callable 이 서버에서 admin 재검증)
- **비범위**:
  - Qoin **사용(spend)** 정책 전반 (`setQoinSpendPolicy`) — 게이트 OFF, Phase 2 (D0-3)
  - 글로벌 비상 정지 `config/qoin.enabled` **쓰기** — 읽기 카드 유지 권고 (D0-2, 사용자 결정 시 추가)
  - 콜렉션그룹 전역 이력 통합 피드 — 인덱스 배포 필요, Phase 2 (D0-5)
  - `migrateQoinZeroRates` 등 1회성 마이그레이션 도구 UI (정책 knob 아님)
  - Flutter 앱 변경 (고객/점주 앱은 적립률을 읽기만 하며 변경 없음)

---

## 요구사항

### 기능 요구사항

- [ ] **전역 적립률 변경**: `viewQoin` 에서 현재 `config/qoin.accrualRate` 를 표시하고, 새 값 입력(0.1%~20%) → 확인 → `setQoinAccrualRate({scope:'global', rate})`. 전역은 `clear` 불가(항상 유효 숫자여야 함 — `setQoinAccrualRate.ts:79`).
- [ ] **브랜드 적립률 변경**: `viewBrandDetail` 에서 `setQoinAccrualRate({scope:'brand', targetId:brandId, rate})` 또는 `{clear:true}`(상위=전역 상속).
- [ ] **매장 적립률 변경**: `viewStoreDetail` 에서 `setQoinAccrualRate({scope:'store', targetId:storeId, rate})` 또는 `{clear:true}`(상위 상속).
- [ ] **브랜드/매장 적립 스위치**: `setQoinAccrualEnabled({scope, targetId, enabled})`. OFF=적립 중단(회수는 통과), ON=필드 삭제(기본값). 전역 스위치는 없음(`scope:'global'` 거부).
- [ ] **브랜드 일괄 적용**: `viewBrandDetail` 에서 `applyBrandQoinRate({brandId, rate|clear, mode:'preserve'|'overwrite', reason, resumeHistoryId?})`. `overwrite` 는 산하 매장 개별 적립률을 삭제(브랜드 값으로 통일), `preserve` 는 유지.
- [ ] **일괄 중단(partial) 재개**: 브랜드 포인터가 `partial` 이면 중단 배너 + 재개 버튼(`resumeHistoryId` 전달). 판정은 기존 `resolveBulkBanner` 재사용(data_ownership §2.11.1b).
- [ ] **변경 이력 표시**: 각 화면에서 해당 범위 `qoinRateHistory` 최근 N건(변경시각/항목/전→후/사유/행위자). 전역=`listQoinHistory`, 브랜드/매장=`listQoinHistoryOf(parentPath)`.
- [ ] **모든 쓰기는 callable 경유** — 콘솔에서 Firestore 직접 쓰기 금지(D0-2 옵션 B 채택 시 그 토글만 예외).

### UI 요구사항

- [ ] 적립률 입력은 **퍼센트 격자**(0.1% 단위, 0.1%~20%)로 받고 내부에서 소수(0.001~0.2)로 변환. 기존 `RATE_MIN=0.001`/`RATE_MAX=0.2`/`fmtRatePct`(`console-format.js:57,68`) 재사용.
- [ ] **변경 확인 단계 필수**(돈 직결): `openModal`(`console-ui.js`) 로 "전역 적립률을 X% → Y% 로 바꿀까요?" 전/후 명시 + 사유 입력(`validateReason`, `console-format.js:81`).
- [ ] 일괄 적용은 **영향 범위 고지**: 산하 매장 수 / `overwrite` 시 개별값 삭제됨 / 브랜드 스위치 OFF면 "산하 전체 적립 중단" 경고(`brandDisabled`).
- [ ] 스위치는 토글 UI + 확인. OFF 시 "적립이 멈춥니다(회수는 유지)" 고지.
- [ ] 성공 시 `toast` + 화면 값·이력 갱신, 실패 시 `banner('error', ...)` + `writeErrorText(e)`.

### 상태 요구사항

- [ ] loading: 기존 `skel`/`qoinSkel`(`section-admin.js:175`) 재사용, 쓰기 중 버튼 `a-spin` + disabled(회원관리 선례 `section-admin.js:431`).
- [ ] error: 읽기 실패 재시도 버튼(기존 `[data-retry]` 패턴), 쓰기 실패 배너.
- [ ] empty: `config/qoin` 문서 없음 = "아직 Qoin 설정이 없어요"(기존 `emptyBlock`). 전역 적립률 최초 설정은 `setQoinAccrualRate({scope:'global', rate})` 가 생성.
- [ ] 진행중 잠금: `qoinBulkStatus=='in_progress'` 면 해당 브랜드 쓰기 버튼 비활성 + 안내(callable 이 서버에서도 거부).

---

## 데이터 모델 (기존 — 변경 없음)

> 신규 스키마 없음. 아래는 developer 가 참조할 기존 구조.

### 정책 값
- `config/qoin.accrualRate` (number, 0.001~0.2) — 전역 기본 적립률
- `config/qoin.enabled` (bool) — 비상 정지 (쓰기 비범위, D0-2)
- `brands/{id}.qoinAccrualRate` / `stores/{id}.qoinAccrualRate` — 범위별 적립률(부재=상위 상속)
- `brands/{id}.qoinAccrualEnabled` / `stores/{id}.qoinAccrualEnabled` — 적립 스위치(부재=ON, `false`=OFF)
- `brands/{id}.qoinBulkHistoryId`/`.qoinBulkStatus`/`.qoinBulkAt` — 일괄 적용 포인터(상태기계: in_progress/partial/completed/superseded)

### 이력 (CF 가 값과 같은 트랜잭션에 자동 기록 — 신규 설계 불필요)
- `config/qoin/qoinRateHistory/{autoId}`, `brands/{id}/qoinRateHistory/{autoId}`, `stores/{id}/qoinRateHistory/{autoId}`
- 필드: `changedBy`(uid) / `changedAt` / `scope` / `targetId` / `before` / `after` / `reason` / `field`('accrualRate'|'accrualEnabled'|'globalEnabled') / `source`('callable'|'bulk'|'direct'...) / (일괄) `affected`
- read: 전역=admin, 브랜드=admin+brandHolder, 매장=admin+owner+brandHolder. **write=`if false`(admin 포함 CF 전담)** — 콘솔은 **읽기만**.

### callable I/O (기존)
- `setQoinAccrualRate({scope:'global'|'brand'|'store', targetId?, rate(0.001~0.2) XOR clear:true, reason?})` — `rate`와`clear`정확히 하나, `0` 거부, 전역 `clear` 거부. (`setQoinAccrualRate.ts:4-6,56-88`)
- `setQoinAccrualEnabled({scope:'store'|'brand', targetId, enabled:boolean, reason?})` → `{before, after, historyId, changed}`. `scope:'global'` 거부. (`setQoinAccrualEnabled.ts`)
- `applyBrandQoinRate({brandId, rate XOR clear, mode:'preserve'|'overwrite', reason?, resumeHistoryId?})` → `{changed, historyId, status, affectedCount, ...}`. (`applyBrandQoinRate.ts`)

---

## 레이어 설계 (콘솔 모듈 경계 — Flutter Clean Architecture 아님)

> CLAUDE.md 절대규칙의 Clean Architecture/AppColors 는 **Flutter 레이어 작업에만** 적용된다. 이 작업은 vanilla JS 콘솔이므로 콘솔의 기존 모듈 분리를 따른다.

### 데이터 접근 (`console-data.js`) — 신규 쓰기 함수
- `setQoinRate(scope, targetId, { rate, clear, reason })` — `httpsCallable(functions, 'setQoinAccrualRate', {timeout: KEY_TIMEOUT_MS})` 래퍼. 기존 `setUserSuspension`(`console-data.js:382`) 패턴 복제.
- `setQoinEnabled(scope, targetId, enabled, reason)` — `setQoinAccrualEnabled` 래퍼.
- `applyBrandRate(brandId, { rate, clear, mode, reason, resumeHistoryId })` — `applyBrandQoinRate` 래퍼(일괄이므로 `BACKFILL_TIMEOUT_MS` 급 긴 타임아웃).
- (읽기는 기존 `getQoinConfig`/`listQoinHistory`/`listQoinHistoryOf` 재사용)

### 표현 (`section-admin.js`)
- `viewQoin`(기존, `section-admin.js:885`): "읽기 전용" 태그 제거 → 전역 적립률 **편집 버튼** 추가 + 전역 이력 유지. 비상정지는 읽기 카드 유지(D0-2).
- `viewBrandDetail`(기존, `section-admin.js:531`): 브랜드 적립률/스위치 편집 + 일괄 적용 패널 + 브랜드 이력(`listQoinHistoryOf(['brands', id])`).
- `viewStoreDetail`(기존, `section-admin.js:648`): 매장 적립률/스위치 편집 + 매장 이력(`listQoinHistoryOf(['stores', id])`).
- **배치 권고**: 전역은 전용 Qoin 화면, 브랜드/매장은 **해당 상세 화면**에 둔다(엔티티가 이미 로드돼 있어 중복이 없고 맥락이 분명). 대안(단일 Qoin 화면 + 대상 선택기)은 엔티티 로딩을 중복 구현해야 해 비권고 — 사용자가 "단일 화면" 을 강하게 원하면 재검토.

### 공통 (재사용, 신규 없음)
- 확인/사유 입력: `openModal`(`console-ui.js:250`), `validateReason`(`console-format.js:81`)
- 결과 표시: `banner`/`toast`/`writeErrorText`
- rate 변환/표시: `RATE_MIN`/`RATE_MAX`/`fmtRatePct`/`parseRateCell`/`parseSwitchCell`/`resolveEffectiveQoinRate`/`qoinRateText`(`console-format.js`)
- 일괄 중단 배너: `resolveBulkBanner`(기존, data_ownership §2.11.1b — 허브/목록/편집 3곳 공용)

---

## 데이터 흐름

```text
콘솔 화면 (viewQoin / viewBrandDetail / viewStoreDetail)
  → 입력(퍼센트) → RATE 변환 + 범위검증 + openModal 확인 + 사유
  → console-data.js 래퍼 (setQoinRate / setQoinEnabled / applyBrandRate)
  → httpsCallable → Cloud Function (서버에서 admin 재검증 + 범위검증)
      → Firestore: 정책값 1필드 + qoinRateHistory 1건 (같은 트랜잭션)
  → 응답 {before, after, historyId, ...}
  → 화면: toast + 값/이력 갱신 (실패 시 banner + writeErrorText)
```

---

## 에러 처리

| 케이스 | 처리 |
|---|---|
| 범위 밖 요율(0 또는 20% 초과) | 입력 단에서 차단(제출 불가) + 안내. 서버도 `invalid-argument` 재거부 |
| `rate`/`clear` 동시/누락 | UI 가 상호배타 보장(요율 입력 vs "상위 상속" 선택) |
| 전역 `clear` 시도 | UI 에서 전역은 `clear` 옵션 미제공 |
| 일괄 진행중(in_progress) 재시도 | 버튼 잠금 + 안내. 서버도 거부 |
| 일괄 중단(partial) | 중단 배너 + 재개 버튼(resumeHistoryId) |
| 권한 없음 / 세션 만료 | `writeErrorText(e)` 배너 + 재로그인 유도(기존 패턴) |
| 네트워크/타임아웃 | 배너 + 버튼 복구(기존 try/finally 패턴) |
| `config/qoin` 없음 | empty 상태, 전역 설정으로 생성 |

---

## 이력 / 감사 추적 체크리스트 (audit_trail §4 — 6개 항목)

이 기능은 **돈·정책 값(적립률/스위치)** 을 바꾸므로 설정 변경 이력이 **기본값**이다. 결론: **이력은 전부 기존 CF 가 처리하므로 재사용으로 통과**한다.

1. 돈/권한/정책 값 변경? → **예(적립률·스위치).** 이력 필요 → `qoinRateHistory`(값과 같은 트랜잭션, CF 전담)로 **이미 보장**. 콘솔은 쓰기를 callable 에만 맡기므로 "이력 없는 변경" 이 구조적으로 불가.
2. 덮어쓰기로 사라지는 값? → 적립률/스위치는 덮어써지지만 before/after 가 이력에 박제됨.
3. 거래/기록이 정책값 참조만? → 적립 원장(`qoinTransactions`)은 당시 요율을 박제(기존). 이 작업과 무관하게 이미 충족.
4. "누가"? → `changedBy=uid`(callable 이 admin 재검증 후 기록). 콘솔이 임의로 못 씀.
5. 일괄(batch)? → `applyBrandQoinRate` 가 1건 이력 + `affected`(처리 매장 수) 기록 + 포인터 상태기계.
6. CF 로그 의존? → 아니오. Firestore `qoinRateHistory` 영구 보존.

➡️ **신규 이력 설계 불필요.** 단, developer 는 **콘솔에서 Firestore 정책/이력 직접 쓰기를 절대 하지 않을 것**(callable 경유만). D0-2 옵션 B(비상정지 토글)만 유일한 직접 write 예외이며, 그 경우 `enabled`+`enabledChangedBy`+`enabledChangedAt` **3필드 동시** 필수.

---

## 작업 분배

### designer
- **불필요.** 신규 레이아웃 아님, 콘솔 디자인 시스템 확립됨(D0-4). 기존 `a-*` 컴포넌트/모달 재사용.

### developer
- 구현 항목:
  1. `console-data.js`: `setQoinRate`/`setQoinEnabled`/`applyBrandRate` 쓰기 래퍼 3종(기존 `setUserSuspension` 패턴).
  2. `section-admin.js` `viewQoin`: 전역 적립률 편집(모달+확인+사유) + "읽기 전용" 태그 제거. 비상정지 카드는 읽기 유지(D0-2 A).
  3. `viewBrandDetail`: 브랜드 적립률/스위치 편집 + 일괄 적용 패널(mode preserve/overwrite, 영향 고지, partial 재개) + 브랜드 이력.
  4. `viewStoreDetail`: 매장 적립률/스위치 편집 + 매장 이력.
- 재사용할 기존 구조: `openModal`, `banner`/`toast`, `writeErrorText`, `validateReason`, `RATE_MIN`/`RATE_MAX`/`fmtRatePct`/`parseRateCell`/`parseSwitchCell`/`resolveEffectiveQoinRate`/`qoinRateText`, `resolveBulkBanner`, `listQoinHistory`/`listQoinHistoryOf`, 회원관리 쓰기 흐름(`section-admin.js:421-487`).
- 주의:
  - **모든 쓰기는 callable 경유** — Firestore 직접 write 금지(이력 보장).
  - 요율은 **퍼센트↔소수 변환** 주의, `0` 거부, 전역 `clear` 미제공.
  - landing 배포 규칙: `landing/` 밖 소스 수정 금지, `firebase.json` 손대지 말 것, hosting 전용.
  - functions/Rules/인덱스 **건드리지 말 것**(이미 배포됨). CG 이력 피드 만들지 말 것(인덱스 필요).

### tester
- 주요 검증:
  - 전역/브랜드/매장 각 적립률 변경 → 값 반영 + 이력 1건(before/after/changedBy/reason) 생성.
  - 스위치 ON/OFF → `false` 저장/필드 삭제, 이력 기록. 전역 스위치 시도 불가.
  - 일괄 적용 preserve/overwrite → affectedCount 반영, overwrite 시 산하 개별값 삭제, partial 재개 멱등.
  - `clear`(상위 상속) 동작, 전역 clear 미제공 확인.
- 반드시 확인할 예외:
  - 범위 밖/0 요율 차단(UI+서버), `rate`/`clear` 상호배타.
  - in_progress 중 쓰기 잠금, partial 재개.
  - 콘솔이 Firestore 정책/이력을 **직접 쓰지 않음**(callable 만) — 네트워크 탭/코드 리뷰로 확인.
  - **spend 관련 조작이 화면에 전혀 없음**(게이트 준수) — 회귀 체크.
  - hosting 외 배포물 변경 없음(`git status` 에 functions/rules/firebase.json 변화 없음).

---

## 완료 기준

- [ ] ✅ 6종 knob 편집 UI 가 callable 경유로 동작(전역·브랜드·매장 적립률 + 브랜드·매장 스위치 + 브랜드 일괄).
- [ ] 변경 시 범위별 `qoinRateHistory` 이력 1건 생성(before/after/changedBy/reason) — tester 확인.
- [ ] spend 조작 UI 부재(게이트 준수), 비상정지 쓰기 미포함(D0-2 A) 또는 사용자 승인 후 포함.
- [ ] `design.md`: UI 변경 없음(designer 생략) 명시.
- [ ] `implementation.md` 작성.
- [ ] `test_report.md` 작성, FAIL 없음(또는 후속 분리).
- [ ] 배포 영향: hosting 전용(functions/Rules/인덱스/firebase.json 무변경) 확인.

---

## 보류 / 사용자 결정 필요 (요약)

- **D0-2**: 글로벌 비상정지 토글 — 권고 "읽기 유지(미포함)". 포함 원하면 통보.
- **D0-3**: spend 정책은 게이트 때문에 **전면 비범위(Phase 2)**. 진행 불가 영역이며 추측 금지.
- **배치(§레이어 설계)**: 전역=전용 화면 / 브랜드·매장=상세 화면 권고. "단일 Qoin 관리 화면" 선호 시 재검토.
- 그 외는 기존 callable·이력·권한이 모두 갖춰져 있어 **지금 바로 developer 진행 가능**.
