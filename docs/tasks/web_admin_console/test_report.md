# web_admin_console 테스트 리포트

- 검증일: 2026-10-29
- 기준: `spec.md` (§7.1·§9.4 2026-10-29 정정 포함) / `design.md` / `implementation.md` / `landing/admin/` 8개 파일
- **운영 데이터 쓰기 0건.** Firestore 에뮬레이터(프로젝트 ID `demo-admin-console-test`, 포트는 `emulators:exec` 자동 할당)만 사용했다. 운영 프로젝트에 대한 Firestore 쓰기, Cloud Function 호출, `firebase deploy` 는 실행하지 않았다.
- 코드 수정 없음. 테스트 스크립트는 저장소 밖 scratchpad 에만 있다 (아래 "재현 방법").

## 결과 요약

| 구분 | PASS | FAIL | 미검증 |
|---|---:|---:|---:|
| 정적 검증 (1~9) | 9 | 0 | 0 |
| Rules 통과 (10~12) | 3 | 0 | 0 |
| 동작 검증 (13~20) | 8 | 0 | 0 |
| 그 외 (spec §12 / §14) | - | - | 6 (아래 표) |

자동 실행 케이스: Rules 에뮬레이터 64건 + jsdom 가짜 데이터 계층 34건 + jsdom 실제 data 모듈 × 에뮬레이터 통합 16건. **전부 통과, FAIL 0건.**

---

## 1. 정적 검증

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 1 | `PAYLOAD_SHAPES` 가 앱 필드 집합과 일치 | **PASS** | `StoreModel.approveFields` = `status, approvedBy, approvedAt, rejectedReason(null), updatedAt` ↔ `storeApprove` 동일. `rejectFields` = `status, approvedBy, rejectedAt, rejectedReason, updatedAt` ↔ `storeReject` 동일. `brand_repository_impl.dart` 의 `approveBrand`(`status, approvedBy, approvedAt, rejectedReason:null, updatedAt`) ↔ `brandApprove`, `rejectBrand`(`status, approvedBy, rejectedReason, updatedAt`) ↔ `brandReject` 동일. 빌더가 실제로 내놓는 키 집합도 node 로 출력해 확인 |
| 2 | `QOIN_MANAGED_FIELDS` = `qoinManagedFields()` | **PASS** | `firestore.rules:75-78` 를 파싱해 정렬 비교: `qoinAccrualEnabled, qoinAccrualRate, qoinBulkAt, qoinBulkHistoryId, qoinBulkStatus` 5개, 집합 동일 (`EQUAL true`) |
| 3 | 매장 반려가 `rejectedAt` 에 쓰고 `approvedAt` 미접촉 | **PASS** | 빌더 코드 + `assertPayload` 가드 + **에뮬레이터 실측**: `rejectStore` 후 문서에 `rejectedAt` 있고 `approvedAt === undefined` (모듈 직접 호출, UI 경유 둘 다) |
| 4 | `approvedBy` 가 로그인 uid | **PASS** | 4개 액션 모두 에뮬레이터 실측으로 `approvedBy === 로그인 uid` (브랜드 승인/반려, 매장 승인/반려). `requireUid` 가 빈 값이면 throw. `currentUid()` 는 `auth.currentUser.uid`, 없으면 `unauthenticated` |
| 5 | `create` 없음 | **PASS** | `landing/admin` 에서 `setDoc/addDoc/writeBatch/updateDoc/deleteDoc/tx.set/tx.delete` 0건. Firestore 쓰기는 `admin-data.js` 의 `tx.update` 1곳뿐 (나머지 `.set(` 2건은 `Map.set`). `users` 는 `readUserRole` 의 읽기뿐, 역할 변경 코드 없음 |
| 6 | 브랜드 승인 2단계, 실패 시 문서 불변 | **PASS** | 코드 순서 `precheck → issueBrandKey → tx.update`. 에뮬레이터 실측: CF 가 throw 하면 `err.stage==='issueKey'` 이고 `brands/b3` 가 `pending`·`approvedBy` 없음 그대로. CF 응답에 `brandKey` 가 없으면 `parse` 로 실패 처리하는 분기는 코드 확인 (실행은 안 함 — CF 응답은 스텁) |
| 7 | Functions 리전 명시 | **PASS** | `getFunctions(app, FUNCTIONS_REGION)`, `FUNCTIONS_REGION='asia-northeast3'`. 에뮬레이터 통합 실행에서 `issueBrandKey` 호출이 `region: asia-northeast3`, `{brandId}` 로 기록됨 |
| 8 | 신규 색상값 0건 | **PASS** | `admin.css / admin.js / index.html` 에 `#hex`, `rgb(a)`, `hsl(a)` 0건 (색 이름 grep 도 `white-space` 외 없음). 사용된 `var(--…)` 18종 전부 `landing/assets/style.css` 에 정의됨. 연한 배경은 `color-mix` 로 변수끼리만. `style.css` 및 landing 4페이지 diff 0 |
| 9 | 매장 승인 버튼 활성 조건 = 앱 | **PASS** | 앱 `StoreBrandLink.approveEnabled`(`personal`/`approved` 만) ↔ 콘솔 `approveOk = personal \|\| approved`. 반려는 항상 활성. jsdom 으로 연결 브랜드 `pending` 일 때 승인 `disabled`·반려 활성 확인. 쓰기 직전 서버 재확인(`brand-not-approved`)도 에뮬레이터에서 확인 (브랜드 pending / 문서 없음 둘 다 문서 불변). design A5 문구와 앱의 불일치는 spec/design 쪽 정정 블록이 이미 반영 |

## 2. Rules 통과 검증 (에뮬레이터, 실제 `firestore.rules`, **실제 `admin-data.js` 코드 경로**)

`admin-data.js` 의 CDN import 만 로컬 `firebase` 패키지로 치환한 복사본(원본 무수정)을 에뮬레이터의 admin 컨텍스트에 연결해 호출했다. 즉 payload·트랜잭션·쿼리 모양이 실제 콘솔 코드 그대로다. Functions 만 스텁(호출 기록).

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 10 | R1~R13 admin 통과 | **PASS** | R1 `readUserRole`, R2 브랜드 대기 목록, R3 `private/profile`, R4 브랜드 승인, R5 브랜드 반려, R6 매장 대기 목록, R7 매장 승인(개인/승인 브랜드 연결 2경우), R8 매장 반려, R9 전체 매장, R10 `config/qoin`, R11 `qoinRateHistory`, R12 `menuItems` 컬렉션 그룹, R13 `menuOverrides` 컬렉션 그룹 전부 허용. `getCountFromServer` 4종, `loadBrandMap` 도 허용 |
| 11 | Qoin 관리 필드 혼입 거부 | **PASS** | 5개 필드 각각 × (`brands` / `stores`) = 10건 admin 계정으로도 `permission-denied`, 거부 후 문서 불변. 트랜잭션 안 혼입도 거부. 같은 상태의 정상 payload(R4/R7)는 통과하므로 양성 대조 성립 |
| 12 | 비admin 거부 | **PASS** | `customer`, `owner` 각각: `approveStore / rejectStore / rejectBrand / approveBrand` 최종 쓰기 모두 `permission-denied`, 문서 불변. `users/{admin}` 읽기, 타인 `private/profile` 읽기, `qoinRateHistory` 읽기도 거부. 참고로 customer 의 자기 `role=admin` 승격도 거부 |

## 3. 동작 검증

방법: (a) jsdom + 가짜 데이터 계층(실제 `admin.js` 전체), (b) jsdom + **실제 `admin-data.js`** + 에뮬레이터 Rules.

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 13 | 비admin: 본문 미렌더 + 데이터 요청 0 + 5초 자동 로그아웃 + 안내 잔존 | **PASS** | `.a-nav`/`#view` 없음, `count.*`·`list*`·`get*` 호출 0건. "5초 후 자동으로 로그아웃돼요" 표시 → 5.3초 뒤 `signOut` 정확히 1회 → 로그아웃 후 로그인 화면에 "관리자 계정으로 로그인해주세요" 안내 잔존 |
| 14 | 미로그인 직접 접근 | **PASS** | 로그인 폼만 렌더, 셸 없음, 데이터 요청 0건 |
| 15 | DOM 에서 비활성 강제 해제 후 승인 → Rules 가 거부, 성공 표시 없음 | **PASS** | (a) 연결 브랜드 pending 매장의 `disabled` 를 제거하고 클릭 → 모달 열림(UI 는 막지 않음 = 의도). 서버가 거부하면 "저장되지 않았어요" 표시, 성공 토스트 없음, 해시·건수 불변. (b) **통합**: customer 계정 + `readUserRole` 만 강제 `true`(= UI 게이트 우회 가정)로 셸을 열고 매장 승인/반려, 브랜드 승인 시도 → 실제 Rules `permission-denied` → 콘솔이 "저장되지 않았어요" 표시, **DB 문서 전부 불변**, 반려 사유 textarea 보존 |
| 16 | `users/{uid}` 읽기 실패 fail-closed | **PASS** | 읽기 거부(throw) → "권한을 확인하지 못했어요" + 셸/데이터 요청 0건. 응답 지연 중에도 셸 없음. `users` 문서 없음 → `admin:false`. 타인 uid 읽기는 Rules 거부로 throw |
| 17 | 승인 실패 시 항목 유지, 사유 보존 | **PASS** | 실패 후 큐에 2건 모두 그대로, 모달 닫으면 상세에 실패 배너 잔존. 반려 실패 시 원문 사유(앞뒤 공백·줄바꿈 포함) 그대로 보존, 확정 버튼 재시도 가능 |
| 18 | 건수 로드 실패 ≠ 0 | **PASS** | 브랜드 건수 throw → 카드에 `–` / "불러오지 못했어요" / 다시 시도, `0`·"대기 없음" 없음. 실제 0건 카드는 "0 / 대기 없음"으로 구분됨. 실패 카드가 있으면 "처리할 대기 없음" 배너 안 뜸 |
| 19 | 쓰기 직전 재확인 | **PASS** | 에뮬레이터: 이미 `rejected` 인 매장 승인 시도 → `already-processed`, 문서 불변. 이미 `approved` 인 브랜드 승인 시도 → precheck 에서 중단되어 **`issueBrandKey` 추가 호출 0회**. UI: "이미 처리된 건이에요 (현재: …)" + 확정 잠금 + 성공 표시 없음 |
| 20 | 낙관적 UI 없음 | **PASS** | 응답 지연(미해결 promise) 중: 모달 `aria-busy`, 토스트 없음, 해시 불변, 큐 재조회 없음. 해소 후에만 큐 이동·토스트·서버 재조회(`listPendingStores` 재호출). trim 된 사유가 전달됨 |

추가로 확인한 정상 경로(통합, admin): 대시보드 건수 실제 표시, 매장 승인 → 문서 `approvedBy/approvedAt` + 큐에서 서버 재조회 결과로만 제거, 매장 반려(사유 trim) → `rejectedAt`·`approvedAt` 없음, 브랜드 승인 → CF 1회(asia-northeast3) 후 `status=approved`.

---

## 4. 미검증 (PASS 로 적지 않음)

| 항목 | 사유 | 권장 |
|---|---|---|
| 실제 Firebase Auth 로그인 (Email/Google), 승인된 도메인 | 운영 Auth 호출 금지 범위. 로그인 SDK 는 스텁 처리. 웹 앱은 이미 등록되어 `firebase-config.js` 에 값이 채워져 있음 | 배포 후 사용자가 실계정으로 로그인 확인 |
| 실제 `issueBrandKey` CF 응답 형태, CF 서버측 `requireAdmin()` | 운영 CF 호출 금지. Functions 에뮬레이터는 미사용 (빌드·기동 비용). 콘솔은 CF 를 스텁으로 검증했을 뿐이다 | 배포 후 **테스트 브랜드 1건**으로 승인 1회 확인 (이 작업은 운영 쓰기이므로 사용자가 판단) |
| 컬렉션 그룹/집계 쿼리의 운영 색인 | 에뮬레이터는 색인을 강제하지 않는다. `firestore.indexes.json` 에 `brands(status,submittedAt)`, `stores(status,submittedAt)`, `menuItems`(scope,status,submittedAt) 그룹, `menuOverrides`(status,submittedAt) 그룹이 선언된 것은 확인했으나 **운영에 배포·빌드 완료됐는지는 확인 불가** | 배포 후 대시보드 건수 4개 + 마스터 메뉴/커스텀 큐가 열리는지 확인 |
| 실제 브라우저 렌더링 (CSS 레이아웃, 1024px 미만, 포커스 트랩, 시각적 위계) | jsdom 은 레이아웃을 계산하지 않는다 | 배포 전 `python3 -m http.server` 로컬 확인 또는 배포 후 육안 확인 |
| 배포 후 landing 4페이지 회귀 | 배포하지 않음. 정적으로는 `landing/` 기존 파일 diff 0, landing 4개 html 에 `admin` 링크 0건 확인 | 배포 후 사용자가 4개 URL 확인 (spec §11) |
| 오프라인/타임아웃의 실제 SDK 동작 (쓰기 20초, CF 30초) | 가짜 계층에서 에러 객체를 주입해 UI 분기만 확인. 실제 네트워크 단절은 재현하지 않음 | 수동 확인 |

## 5. 관찰 사항 (FAIL 아님, 후속 후보)

1. **`landing/admin/README.md` 가 호스팅 공개 URL 로 함께 올라간다** (implementation.md §10 도 인지). 비밀 값은 없다. 필요하면 `firebase.json` 의 hosting `ignore` 에 `**/README.md` 추가 (hosting 블록 변경이라 다른 세션 협의 필요).
2. **`firebase.json` 의 `admin/assets/` 에는 캐시 헤더가 걸리지 않는다** (`/assets/**` 는 루트 `assets/` 만). 구버전 JS 가 남을 수 있다 — 기능 결함은 아님.
3. **"승인은 UI 가 막지 않는다"는 설계 의도 그대로 확인됨**: 연결 브랜드 pending 매장은 DOM 강제로 모달까지 열린다. 그 뒤 막는 것은 `approveStore` 의 클라이언트 재확인(편의)이며 **Rules 는 브랜드 상태를 강제하지 않는다** (spec §6-1: 편의이지 보안 장치 아님). 앱도 동일한 구조이므로 이 콘솔이 새로 만든 위험은 아니다.
4. `approveBrand` 의 `issueBrandKey` 성공 후 `status` 쓰기가 Rules 거부로 실패하면 키는 발급된 채 `pending` 이 남는다 (CF 멱등이라 재시도로 복구, UI 문구도 안내). 앱과 동일한 설계 한계.

## 6. 판정

### **GO** (배포 전 조건 2개는 아래)

근거:
- 지시된 20개 검증 항목 **FAIL 0건**. 가장 중요한 4개 — `approvedBy` = 로그인 uid, 매장 반려가 `rejectedAt` 만 쓰고 `approvedAt` 불변, Qoin 관리 필드 혼입 시 admin 도 거부, 브랜드 승인 2단계(CF 실패 시 문서 불변) — 를 **실제 Rules + 실제 콘솔 data 코드**로 실측했다.
- 권위 검증(§6-1)의 핵심 테스트를 통과했다: UI 게이트를 우회한 비admin 클라이언트가 승인/반려/브랜드 승인을 시도해도 Rules 가 거부하고 콘솔은 성공으로 표시하지 않으며 DB 는 변하지 않는다.
- 코드 변경 범위가 `landing/admin/**` 로 한정(`lib/`·`functions/`·`firestore.rules`·기존 landing 파일 diff 0), 콘솔은 `update` 만 보낸다.

배포(사용자 수행, PG 심사 종료 후) 직후 반드시 할 일 — 이 둘은 이번 환경에서 검증할 수 없었다:
1. 실계정 로그인 + 대시보드 건수 4종/큐 로딩 확인 (Auth 승인 도메인, 운영 색인).
2. `issueBrandKey` 실호출 경로 확인 (테스트 브랜드 1건). 이것이 통과하기 전에는 브랜드 승인을 운영 건에 쓰지 말 것 — 단 CF 가 실패하면 콘솔은 `brands/{id}` 를 건드리지 않으므로(실측) 최악의 경우도 "승인 안 됨"이다.

## 재현 방법 (scratchpad, 저장소 밖)

- Rules + 코드 경로: `scratchpad/rules/rules.admin.test.mjs`, 통합: `scratchpad/rules/integ.test.mjs`, 행동(가짜 계층): `scratchpad/dom/behavior.test.mjs`
- 에뮬레이터 실행 (프로젝트 루트에서, `demo-` 프로젝트 ID 라 운영 접근 불가):

```bash
cd /Users/Byeonguk/Developer/OrderApp && npx --yes firebase-tools@14 emulators:exec --only firestore --project demo-admin-console-test "node /private/tmp/claude-503/-Users-Byeonguk-Developer-OrderApp/c133e8b0-27b6-490e-afeb-77a7d2e2f96b/scratchpad/rules/rules.admin.test.mjs"
```

- 행동 테스트 (에뮬레이터 불필요):

```bash
cd /private/tmp/claude-503/-Users-Byeonguk-Developer-OrderApp/c133e8b0-27b6-490e-afeb-77a7d2e2f96b/scratchpad/dom && node behavior.test.mjs
```
