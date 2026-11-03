# admin_user_moderation (관리자 유저 관리 — 계정 정지/해제 + 관리자 강제 탈퇴) 기능 명세

## 개요

- **목적**:
  1. **계정 정지/해제** — 악성·분쟁 유저 1차 대응. 계정·데이터는 **남긴 채** 로그인·결제·판매를 차단하고, 해제로 원복할 수 있게 한다. **전 역할(customer/owner/brand) 대상.**
  2. **관리자 강제 탈퇴** — account_deletion 의 Phase 2. admin 이 유저를 익명화·삭제한다. **이번 Phase 1 은 customer 전용** (owner/brand 는 매장·브랜드 고아 정리가 얽혀 Phase 2).
  3. 겸사: tester 가 보류로 남긴 **"deleted 사용자 결제 차단"** 을 같은 집행 지점(결제 게이트)에서 함께 해소한다.
- **작업 유형**: 신규 기능 (Cloud Function 2개 + Rules 1~2블록 + 결제 게이트 1지점 수정 + 앱 1화면 + 어드민 콘솔 신규 뷰). **런칭 필수 아님** — 운영 안전장치.
- **핵심 설계 방향**:
  - **정지는 플랫폼 레벨에서 끈다.** `users.suspended` 플래그는 앱 UX·게이트 판독용 신호일 뿐이고, **진짜 집행은 Firebase Auth `disabled` + `revokeRefreshTokens`** 다 (제공자 무관 — email/google/kakao/naver 전부 토큰 발급·갱신이 막힌다). 돈 게이트(`verifyTossPayment`)에는 **명시적 거절**을 더해 토큰 유효 잔여창(최대 1시간)을 닫는다.
  - **정지·해제·강제탈퇴는 전부 CF 전담 + 이력.** 권한을 좌우하는 값이므로 `audit_trail §4-1` 기본값을 따른다. 클라이언트·admin 직접 Firestore 편집으로 플래그만 바뀌어 Auth·이력이 따로 노는 것을 Rules 로 막는다.
  - **강제탈퇴는 account_deletion 의 `runDeleteMyAccount` 코어를 재사용**한다 (새 익명화 로직을 만들지 않는다). actor 만 admin uid 로 분리.
- **영향 범위**:
  - 화면(앱): `lib/presentation/common/role_router.dart` 에 **정지 유저 안내 화면** 분기 추가 (신규 `AccountSuspendedView`). 그 외 앱 화면 변경 없음.
  - 화면(어드민 콘솔, vanilla JS — **사용자가 별도 구현**, spec 은 명세만): `landing/console/assets/section-admin.js` 에 `회원 관리` NAV + 유저 검색/상세 뷰, `console-data.js` 에 조회·callable 래퍼.
  - Domain: (앱) `UserProfile` 엔티티에 `suspended` 등 판독 필드 추가. 강제탈퇴/정지는 admin 전용이라 앱 도메인 UseCase 신규 없음(콘솔이 수행).
  - Data: 앱쪽은 `UserProfile` 매핑만. 집행·CF 는 functions 레이어.
  - Firebase: **신규 CF `setUserSuspension`**(정지/해제, 멱등), **신규 CF `adminDeleteUser`**(강제탈퇴, customer 전용, `runDeleteMyAccount` 재사용), **신규 컬렉션 `userModerationHistory`**, `verifyTossPayment` 1지점 수정, `firestore.rules` 2블록(users 정지필드 CF 가드 + `userModerationHistory`).
  - 권한 / 환경 설정: 클라이언트 쓰기 경로 추가 없음(전부 CF). Rules 가드 추가.
- **비범위 (이번 작업 제외)**:
  - **owner/brand 강제 탈퇴** → Phase 2 (매장/브랜드 고아·정산 정리 수반, §0-3).
  - **브랜드 정지 시 산하 가맹점 전체 판매 중단 fan-out** → Phase 2 (§0-2). Phase 1 은 **직영 점주(store.ownerId) 정지 → 그 매장 판매 중단**까지.
  - **정지 중 진행 주문 자동 취소/환불** — 정지는 주문을 건드리지 않는다 (§0-7).
  - **per-write Rules 정지 검사** (주문 접수·환불 등 비-결제 쓰기를 Rules `get()` 으로 막기) — 비용·복잡도 과다, §0-1 로 제외. 플랫폼 kill + 돈 게이트로 커버.
  - 정지 사유 통계/대시보드, 정지 예약·자동 만료.

---

## 0. 사용자 확인이 필요한 결정사항 (권고 포함)

> architect 가 권고와 함께 정리했다. 1~7 을 확정해야 developer 분배를 확정한다. 권고대로면 별도 회신 불필요.

| # | 결정 | 권고 | 근거 |
|---|---|---|---|
| 1 | **정지 집행 범위** (로그인/결제/쓰기) | **(a) Auth `disabled`+`revokeRefreshTokens`(로그인·토큰 kill, 제공자 무관) + (b) `verifyTossPayment` 명시적 거절(돈 게이트) + (c) 앱 RoleRouter 안내 화면.** per-write Rules 검사는 **안 함** | (a) 가 플랫폼 레벨 집행의 핵심. 단 기존 ID 토큰은 비활성 후에도 최대 1시간 유효하므로 (b) 로 돈 창을 닫고 (c) 로 즉시 UX 피드백. per-write Rules 는 모든 쓰기에 `get(users)` 를 달아 비용이 크고, 돈 아닌 쓰기(주문 상태 토글 등)의 1시간 잔여창은 1차 안전장치로 수용 가능 |
| 2 | **점주/브랜드 정지 시 매장 판매 전파** | **직영 점주 정지 → 그 매장 즉시 판매 중단(Phase 1).** 브랜드 정지 → 산하 가맹점 fan-out 은 **Phase 2** | `verifyTossPayment` 게이트는 이미 매장 문서를 읽어 `store.ownerId` 를 쥐고 있다(자기거래 가드). 그 ownerId 의 user 를 1회 더 읽어 `suspended/deleted` 면 거절 — **fan-out 쓰기 없이** 서버 권위로 중단, 해제 시 되돌릴 상태도 없다. 브랜드→가맹점은 보유자 uid 해석 or fan-out 이 필요해 분리. 전파 없으면 정지된 점주의 매장이 계속 결제를 받아 정지가 무의미 |
| 3 | **owner/brand 강제탈퇴 이번 포함** | **미포함, customer 전용(Phase 1)** | owner/brand 는 소유 매장/브랜드(권한 값 `brandId`)·산하 메뉴·정산이 고아가 된다. `deleteStore` 선행 호출 체인·브랜드 해체가 필요해 account_deletion 의 Phase 2 분리와 동일하게 미룬다. owner/brand 는 "정지" 로 1차 대응하고, 삭제가 필요하면 매장/브랜드를 먼저 정리 |
| 4 | **유저 조회 방식** (users 는 self/admin read) | **어드민 콘솔에서 admin 권한으로 Firestore 직접 조회** — 이메일 완전일치 쿼리(`where email==`) + uid 직접 get. 신규 조회 callable **불요** | Rules `users.read: isAdmin() OR self` 라 admin 은 컬렉션 쿼리·단건 get 이 모두 허용된다(console-data.js 가 이미 `getDocFromServer(doc(db,'users',uid))` 로 읽음). 이메일은 PII 지만 admin read 는 허용 범위. 부분검색·정렬이 필요해지면 후속에 검색 callable 도입 |
| 5 | **정지 필드 CF 전담(Rules 가드)** | **예 — `suspended/suspendedAt/suspendedBy/suspensionReason` 를 client·admin 양쪽에서 Rules 로 차단**(CF 만 쓰기) | `audit_trail §4-1`: 권한 값은 "client 쓰기 닫고 CF 전담 + 이력" 이 기본. 플래그만 직접 바뀌면 Auth 비활성·이력이 따로 놀아 "반쪽 정지" 가 생긴다. Qoin 보호필드(`touchesQoinManaged`) 패턴을 미러링(`touchesModerationManaged()`) |
| 6 | **(파생) 강제탈퇴 당한 계정 재가입** | **account_deletion §0-9 와 동일** — kakao/naver 동일 uid 는 `reactivateIfDeleted` 로 신규 재활성화 | 강제탈퇴도 `deleted:true` 익명화라 self-탈퇴와 재가입 경로가 같다. 추가 설계 불요. ⚠️ "강제탈퇴 유저의 재가입을 막아야 하는가" 는 별도 정책 — 막으려면 차단 목록이 필요하나 Phase 1 범위 밖 |
| 7 | **정지 중 진행 주문 처리** | **건드리지 않는다** (자동 취소/환불 없음) | 정지는 가역적 1차 조치다. 진행 주문 강제 종료는 PG 환불·분쟁이 얽혀 과하다. 강제탈퇴(customer)는 account_deletion 의 **진행중 주문 가드**를 그대로 승계(진행 주문 있으면 차단) |

---

## 요구사항

### 기능 요구사항 — 정지/해제 (전 역할)

- [ ] admin 이 콘솔에서 유저를 이메일/uid 로 조회한다 (§0-4).
- [ ] admin 이 유저를 **정지**한다 → CF `setUserSuspension(action:'suspend')`: ① `userModerationHistory` 이력 1건 ② `users.suspended=true`+메타 ③ Auth `disabled=true` ④ `revokeRefreshTokens(uid)`. **멱등**(이미 정지면 no-op, 이력 중복 없음).
- [ ] admin 이 유저를 **해제**한다 → `setUserSuspension(action:'unsuspend')`: 위 역으로 복구(`suspended=false`/삭제, Auth `disabled=false`). 토큰 재발급은 재로그인으로 자연 회복. **멱등**.
- [ ] 정지는 **customer/owner/brand** 대상. admin 대상 정지는 서버에서 거부(자기·동료 admin 보호 — §에러처리).
- [ ] **집행**: (a) 정지 유저는 로그인/토큰 갱신 불가(Auth disabled). (b) `verifyTossPayment` 가 **결제 유저 본인**이 `suspended||deleted` 면 Toss confirm 전에 거절. (c) **직영 점주 정지 시** 그 매장(`store.ownerId` 가 정지/삭제)의 결제를 거절(§0-2). (d) 앱 RoleRouter 가 `suspended` 프로필을 만나면 안내 화면.
- [ ] **deleted 유저 결제 차단**(tester 보류 해소): (b) 의 조건에 `deleted==true` 포함.

### 기능 요구사항 — 강제 탈퇴 (customer 전용, Phase 1)

- [ ] admin 이 콘솔에서 customer 를 **강제 탈퇴** → CF `adminDeleteUser`: `runDeleteMyAccount` 코어 재사용(익명화·Qoin 소멸·favorites 삭제·Auth 삭제·phase 멱등). 차이는 **actor=admin uid**(`deletedBy`), `byAdmin:true`.
- [ ] 강제탈퇴 전 **dryRun 미리보기**(진행중 주문 수·소멸 Qoin)와 **파괴적 확인 입력**(콘솔, fail-closed).
- [ ] 진행중 주문(`paid/accepted/making/ready`)이 있으면 **차단**(account_deletion 가드 승계, §0-7).
- [ ] owner/brand 강제탈퇴 요청은 서버에서 거부(`customer only`, Phase 1 — §0-3).
- [ ] 이력: `accountDeletionHistory` 재사용(`deletedBy`=admin uid, `byAdmin:true`).

### UI 요구사항

- [ ] (앱) `AccountSuspendedView`: 정지 안내 + 문의 경로. 역할 Scaffold·홈 대신 전체화면. 색상 `AppColors` 만.
- [ ] (콘솔, 사용자 구현) 회원 관리 뷰: 검색 입력 + 유저 상세(role/상태/provider/가입일/표시명) + `정지`/`해제`/`강제탈퇴` 버튼. 강제탈퇴는 dryRun→확인입력→실행(기존 `admin_store_delete` 패턴). 기존 승인/백필 UI 패턴 재사용.

### 상태 요구사항

- [ ] loading: 조회 중 / CF 처리 중.
- [ ] error: 서버 raw message 미노출, 토큰 분류(`[ACCOUNT_HAS_INFLIGHT_ORDERS]`, `[CANNOT_MODERATE_ADMIN]`, `[FORCE_DELETE_CUSTOMER_ONLY]`).
- [ ] empty: 검색 결과 없음(어드민).

---

## 데이터 모델

### `users/{uid}` — 정지 필드 (CF 전담, Rules 가드 §0-5)

| 필드 | 타입 | 설명 |
|---|---|---|
| `suspended` | bool | 정지 여부. 부재/false = 정상. **판독용 신호**(진짜 집행은 Auth disabled). 역할 무관 공통 |
| `suspendedAt` | Timestamp | 정지 시각. 해제 시 `FieldValue.delete()` |
| `suspendedBy` | string(uid) | 정지한 admin uid (`audit §4-4` 행위자) |
| `suspensionReason` | string? | 사유(선택) |

> `deleted`(account_deletion)·`role`·`qoinBalance` 등 기존 필드는 그대로. 정지는 `deleted` 와 **독립**(정지된 계정도 강제탈퇴 가능, 반대도 가능).

### 신규 이력 — `userModerationHistory/{uid}_{millis}` (CF 전담 write)

`storeDeletionHistory`/`accountDeletionHistory` 스키마 미러링.

| 필드 | 설명 |
|---|---|
| `uid` / `targetUid` | 대상 유저 |
| `action` | `'suspend'` / `'unsuspend'` |
| `before` / `after` | `{suspended, ...}` 정지 상태 전후 |
| `role` | 대상 당시 role (감사) |
| `changedBy` | admin uid |
| `changedAt` | serverTimestamp |
| `reason` | 사유(선택) |
| `authAction` | 실제 수행한 Auth 조치(`disabled`/`enabled`/`revoked`) — 집행 감사 |

### 강제탈퇴 이력 — `accountDeletionHistory` (재사용)

account_deletion 스키마 그대로 + `byAdmin: true`, `deletedBy`=admin uid. 신규 컬렉션 불요.

---

## 레이어 설계

### Cloud Functions (functions/)

- **`setUserSuspension.ts`** (신규, callable, `requireAdmin`):
  - 입력 `{ targetUid, action: 'suspend'|'unsuspend', reason? }`.
  - 포트/어댑터 + 멱등(이미 같은 상태면 이력·Auth 재조치 생략). 순서: ① 대상 read + role 검증(admin 대상 거부 → `[CANNOT_MODERATE_ADMIN]`) ② `userModerationHistory` 이력 ③ `users` 플래그 set(Admin SDK, Rules 우회) ④ Auth `updateUser(disabled)` ⑤ suspend 시 `revokeRefreshTokens`. ③~⑤ 를 phase 로 멱등 재진입.
  - 권한 헬퍼: `qoinAdmin.ts` 의 `requireAdmin`(서버 role 재검증) 재사용.
- **`adminDeleteUser.ts`** (신규, callable, `requireAdmin`):
  - 입력 `{ targetUid, reason?, dryRun }`.
  - **`deleteMyAccount.ts` 의 `runDeleteMyAccount(ports, {uid, reason, dryRun})` 코어를 재사용.** 코어에 `actorUid` 인자를 추가(기본값=uid)해 `deletedBy`/history `deletedBy` 를 admin uid 로 쓴다 — **최소 리팩터**(기존 self-탈퇴 동작 불변). `byAdmin` 마커는 어댑터의 writeHistory 패치에 추가.
  - customer-only 검증은 코어에 이미 있음(`role !== 'customer'` 거부). 토큰만 `[FORCE_DELETE_CUSTOMER_ONLY]` 로 분류.
  - 진행중 주문 가드·phase 멱등·dryRun·Auth 삭제 전부 코어가 수행.
- **`verifyTossPayment.ts`** (수정 1지점): 2-a/2-b 구역(Toss confirm 전, 매장 문서 read 직후)에 **유저 상태 가드** 추가.
  - 결제자 본인: `users/{uid}` 의 `suspended||deleted` → `recordGateRejection` + `HttpsError`(돈 안 움직임).
  - 직영 점주(§0-2): 이미 읽은 `signalStore.ownerId` 의 user 1회 read → `suspended||deleted` → 거절. 사유 토큰 예: `USER_SUSPENDED` / `STORE_OWNER_SUSPENDED`. `paymentGate.ts` 사유 enum·`buildRejectionMessage` 에 추가.
  - 비용: 정상 주문당 user read 1~2건 증가(결제자 + 점주). enforce 모드에서만 평가 권고.

### Firestore Rules (수정 2블록)

- `users` update/create: `touchesModerationManaged()` 헬퍼(`qoinManagedFields` 패턴)로 `suspended/suspendedAt/suspendedBy/suspensionReason` 를 **admin 전권 분기 포함 모든 클라이언트 쓰기에서 차단**. create 에도 동일 가드(`!hasModerationManagedOnCreate()`). CF(Admin SDK)만 우회.
- `match /userModerationHistory/{id}`: `read: isAdmin()`, `create/update/delete: if false`.

### Presentation (앱)

- `UserProfile` 엔티티/모델에 `suspended`(+필요 시 `suspensionReason`) 매핑 추가. `currentUserProfileProvider` 는 기존 users 스트림 그대로.
- `RoleRouter`: `user.suspended == true` 면 role switch 전에 `const AccountSuspendedView()` 반환.
- `AccountSuspendedView`(신규): 안내 전체화면. 로그아웃 버튼(세션 정리). 색상 `AppColors`.

### 어드민 콘솔 (vanilla JS — 사용자 구현, 명세만)

- `section-admin.js`: `NAV` 에 `{ key:'users', href:'#/users', label:'회원 관리' }`(운영 그룹). `match`: `#/users` → 검색 뷰, `#/users/{uid}` → 상세. 기존 `viewStoreDetail`/`navButtons`/파괴적 확인 패턴 재사용.
- `console-data.js`:
  - 조회: `searchUserByEmail(email)`(`query(users, where('email','==',email))`), `getUser(uid)`(`getDocFromServer(doc(db,'users',uid))`). 기존 `readUserProfile` 재사용 가능.
  - callable: `setUserSuspension(targetUid, action, reason)`, `adminDeleteUser(targetUid, {dryRun, reason})` — 기존 `httpsCallable` + 토큰 분류 래퍼 패턴.

---

## 데이터 흐름

```text
[정지/해제]  콘솔 회원관리 뷰 → console-data.setUserSuspension(callable)
  → CF setUserSuspension (requireAdmin)
      → userModerationHistory 이력 → users 플래그 set → Auth disabled → revokeRefreshTokens
  ← 앱: users 스트림 갱신 → RoleRouter → AccountSuspendedView (즉시) / 토큰 갱신 실패 → LoginPage

[강제탈퇴]  콘솔 → adminDeleteUser(dryRun) → 미리보기 → 확인입력 → adminDeleteUser(real, callable)
  → CF adminDeleteUser (requireAdmin) → runDeleteMyAccount 코어(actor=admin)
      → accountDeletionHistory(byAdmin) → Qoin 소멸 → users 익명화 → favorites 삭제 → Auth 삭제

[집행]  결제: checkout → verifyTossPayment
      → (confirm 전) 결제자 suspended/deleted? 점주 suspended/deleted? → 거절(paymentGateRejections)
```

---

## 에러 처리

| 케이스 | 처리 |
|---|---|
| 대상이 admin | `[CANNOT_MODERATE_ADMIN]` — 정지/강제탈퇴 거부 |
| 강제탈퇴 대상이 owner/brand | `[FORCE_DELETE_CUSTOMER_ONLY]` (Phase 1) |
| 강제탈퇴 대상 진행중 주문 존재 | `[ACCOUNT_HAS_INFLIGHT_ORDERS]`(account_deletion 토큰 승계) + 건수 |
| 이미 정지/해제 상태 재요청 | 멱등 no-op(성공 반환, 이력·Auth 재조치 없음) |
| 정지 유저 결제 시도 | 게이트 거절 + `paymentGateRejections` 기록(오탐 탐지) |
| 정지 점주 매장 결제(§0-2) | 동일 거절(`STORE_OWNER_SUSPENDED`) |
| Auth 조치만 실패(Firestore 완료 후) | phase 재진입으로 재조치 |
| CF 비권한(비admin) 호출 | `requireAdmin` → `permission-denied` |

---

## 감사 추적 체크리스트 (`audit_trail §4`) 통과 확인

1. **돈·권한·정책 값 변경?** → 정지/해제는 **행동 권한**을 좌우 → `userModerationHistory` **남긴다** ✓. 강제탈퇴는 돈(Qoin 소멸)+PII → `accountDeletionHistory` 승계 ✓
2. **덮어쓰기로 사라지는 값?** → 정지 전후를 `before/after` 로 박제, 익명화는 `snapshot`(account_deletion) ✓
3. **거래문서 정책값 참조만?** → 해당 없음(정지는 거래 아님) ✓
4. **누가?** → `changedBy`/`deletedBy`=admin uid, `changedAt` ✓
5. **batch?** → 단건 대상. 정지는 fan-out 없음(§0-2), `affected` 불요 ✓
6. **CF 로그 의존?** → No, Firestore 영구 보존 ✓
7. **(상시) 권한 판정 필드 create/update 교차** → `suspended` 등을 `touchesModerationManaged()` 로 **create·update 양쪽 차단**, 정상 payload 회귀 케이스 포함. `userModerationHistory` 는 create/update/delete `if false` ✓

---

## 작업 분배

### designer (필요 — 앱 1화면만)
- 산출물: `docs/tasks/admin_user_moderation/design.md`
- 전달: `AccountSuspendedView`(정지 안내 전체화면 — 사유 노출 여부는 보안상 최소, 문의 경로, 로그아웃 CTA, `AppColors`). 어드민 콘솔 UI 는 vanilla JS 라 **designer 범위 밖**(사용자 직접 구현).

### developer
- 구현: CF `setUserSuspension`·`adminDeleteUser`(+`runDeleteMyAccount` 에 `actorUid` 인자 최소 추가), `verifyTossPayment` 유저 가드 1지점, `paymentGate.ts` 사유 추가, Rules 2블록(`touchesModerationManaged`+`userModerationHistory`), 앱 `UserProfile.suspended` 매핑 + `RoleRouter` 분기 + `AccountSuspendedView`.
- 재사용: `deleteMyAccount.ts`(코어·포트·phase·토큰), `deleteStore.ts`(IN_FLIGHT_STATUSES), `qoinAdmin.ts`(`requireAdmin`), `setQoinAccrualEnabled.ts`(admin callable+이력 동일 트랜잭션 패턴), `touchesQoinManaged()`(Rules 가드 미러), `authority_callables_remote_data_source.dart`(토큰 분류), `admin_store_delete_page.dart`(파괴적 확인).
- 레이어 규칙: Firebase/Auth/Admin SDK 는 **functions/data 에만**. 정지·삭제 쓰기는 전부 CF(클라이언트 쓰기 경로 추가 금지). Auth 삭제는 phase 마지막.
- **콘솔(landing)**: 사용자가 별도 구현(hosting 전용 규칙 준수). developer 는 콘솔이 호출할 **callable 계약(입출력·토큰)** 을 CF 쪽에 정확히 맞춘다.

### tester
- 검증: 정지 멱등(중복 이력 없음)/해제 원복 / Auth disabled·revoke 실제 적용 / 결제자·점주 정지·deleted 결제 거절(+`paymentGateRejections`) / admin 대상 거부 / owner·brand 강제탈퇴 거부 / 강제탈퇴 진행주문 가드 / `runDeleteMyAccount` 재사용 후 self-탈퇴 회귀(actorUid 기본값) / Rules: `suspended` 등 client·admin update·create 거부 + 정상 프로필 update 회귀 / `userModerationHistory` 클라 write 거부.

---

## 완료 기준

- [ ] §0 결정 1~7 사용자 확정 (특히 1·2·3·5)
- [ ] `design.md`(AccountSuspendedView) 작성
- [ ] `implementation.md` 작성 (CF 2 + verifyTossPayment 가드 + Rules + 앱)
- [ ] `test_report.md` 작성
- [ ] 콘솔 callable 계약이 CF 입출력과 일치 (사용자 콘솔 구현의 기준)
- [ ] FAIL 없거나 후속(Phase 2: owner/brand 강제탈퇴·브랜드 정지 fan-out)으로 분리
</content>
</invoke>
