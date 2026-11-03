# account_deletion (회원 탈퇴 / 계정 삭제) 기능 명세

## 개요

- **목적**:
  1. **애플 앱스토어 심사 필수 요건 충족** — 가입(소셜·이메일) 기능이 있는 앱은 **앱 내 회원 탈퇴 + 개인정보 삭제** 수단을 의무 제공해야 한다. 현재는 Console 수동 삭제뿐이라 심사 통과 불가. **런칭 게이트.**
  2. **개인정보(이름·전화 등 PII) 삭제 수단** 을 사용자에게 제공.
- **작업 유형**: 신규 기능 (presentation + domain + data + Cloud Function + Rules 1블록)
- **핵심 설계 방향**: **하드 삭제 금지 → 소프트 삭제 / 익명화.** 주문(`orders`)은 계정과 별개 문서이고 PII 를 담지 않으므로, 주문 기록은 **정산·감사·전자상거래법 보존의무** 때문에 보존하고, **PII 를 가진 `users/{uid}` 문서와 Firebase Auth 계정만** 제거/익명화한다.
- **영향 범위**:
  - 화면: `customer/more/more_page.dart` 에 탈퇴 진입점 추가 + 신규 전체화면 `AccountDeletionPage`
  - Domain: `AccountDeletionRepository`(인터페이스), `DeleteMyAccountUseCase`, `PreviewAccountDeletionUseCase`, 엔티티 `AccountDeletionPreview`, 예외 `AccountDeletionException`
  - Data: `AccountDeletionRemoteDataSource`, `AccountDeletionRepositoryImpl`
  - Presentation: `AccountDeletionController`(provider), `AccountDeletionPage`
  - Firebase: **신규 Cloud Function `deleteMyAccount`** (callable, Admin SDK), **신규 컬렉션 `accountDeletionHistory`**, `firestore.rules` 에 해당 컬렉션 1블록 추가
  - 권한 / 환경 설정: Rules 1블록 추가 외 클라이언트 쓰기 경로 추가 없음
- **비범위 (이번 작업에서 제외)**:
  - **admin 강제 탈퇴(악성 유저 정지/삭제)** → Phase 2 후속 (§0-7)
  - **owner / brand 역할 계정의 탈퇴** → Phase 2 후속 (매장/브랜드 정리·정산 수반). 이번엔 **customer 역할만** (§0-8)
  - 부분 환불·Qoin 환급 (Qoin 은 소멸 — §0-5)
  - 탈퇴 사유 통계/분석 대시보드
  - 소셜 계정 완전 unlink 는 best-effort (§0-4)

---

## 0. 사용자 확인이 필요한 결정사항 (권고 포함)

> architect 가 아래를 권고와 함께 정리했다. 사용자가 1~8을 확정해야 developer 분배를 확정한다. 권고대로 진행 시 별도 회신 불필요.

| # | 결정 | 권고 | 근거 |
|---|---|---|---|
| 1 | **삭제 방식**: 소프트/익명화 vs 하드 | **소프트 + 익명화** (권고) | 주문은 PII 가 없고(조사 확인) 정산·감사·전자상거래법상 거래기록 보존의무가 있어 **반드시 남겨야** 한다. `users/{uid}` 의 PII 만 제거 + Firebase Auth 삭제로 재로그인 차단. 애플 요건(앱 내 탈퇴 + 데이터 삭제)은 이것으로 충족 |
| 2 | **진행 중 주문 처리** (사용자 질문 핵심) | **(a) 탈퇴 차단** (권고) — "진행 중 주문(접수/조리/픽업대기)이 N건 있어요. 완료 후 다시 시도해 주세요" | `deleteStore` CF 가 동일 status 집합(`paid/accepted/making/ready`)에서 삭제를 막는 선례와 정합. 점주가 고객에게 연락할 PII 가 없어, 진행 중 주문을 남긴 채 탈퇴하면 주문이 깜깜이가 된다 |
| 3 | **Firebase Auth 레코드 삭제 여부** | **삭제** (권고, `admin.auth().deleteUser(uid)`) | 재로그인 원천 차단 = PII 삭제 실효성. 단 소셜(kakao/naver)은 uid 가 결정적(`kakao_<id>`)이라 **동일 소셜 재가입 시 같은 uid 재생성** → 익명화된 기존 `users` 문서와 충돌. 대응은 §0-9 |
| 4 | **소셜 연결 끊기(unlink)** | **best-effort** (권고) — CF 성공 후 클라이언트가 kakao `unlink` / naver 토큰 폐기 시도, 실패해도 탈퇴는 성립 | Firebase Auth 삭제로 세션은 끊긴다. 외부 소셜 동의 해제는 부가 조치라 실패가 탈퇴를 막지 않게 한다 |
| 5 | **Qoin 잔액 처리** | **소멸 + 사전 고지** (권고). 환급 대상 아님 | Qoin 은 적립 리워드이고 현금 환급·외부 이전 수단이 없다(qoin_spend 미활성 — MEMORY). 확인 탭에 "보유 Qoin N개는 소멸되며 복구되지 않습니다" 고지. 소멸은 **돈 값 변경**이라 원장 1건(`reason: accountDeletion`) + 이력 필수(§0-6). ⚠️ **"환급 대상 아님" 전제만 사용자 확정 필요** |
| 6 | **탈퇴 이력/감사** | **남긴다** (권고) — `accountDeletionHistory` | PII 영구 삭제 + Qoin 소멸(돈)이라 `audit_trail §4` 상 기록이 기본값. 삭제 직전 `users` 스냅샷 + `deletedBy`(=본인 uid) + `deletedAt` + `reason` + 소멸 Qoin 액 + 영향 범위를 CF 가 남긴다 |
| 7 | **admin 강제 삭제 이번 포함 여부** | **미포함, Phase 2** (권고) | 본인 탈퇴(Phase 1)가 애플 게이트. admin 강제(악성 유저)는 별도 권한·UI·분쟁 처리 필요 |
| 8 | **대상 역할 범위** | **customer 전용** (권고) | owner/brand 탈퇴는 매장·브랜드(권한 값 `brandId`)·정산 정리가 얽혀 Phase 2. owner/brand 에게는 "고객 모드 전환 후 또는 관리자 문의" 안내. 애플 리뷰어 계정은 customer 라 게이트 영향 없음 |
| 9 | **(파생) 소셜 재가입 처리** | **익명화 문서 재활성화** (권고) | kakao/naver 는 재가입 시 같은 uid → `getOrCreateUserProfile` 가 `deleted == true` 문서를 만나면 **재활성화**(deleted/deletedAt 클리어 + 프로필 재기입). email/google 은 새 uid 라 무관. ⚠️ 확정 필요 |

---

## 요구사항

### 기능 요구사항

- [ ] 고객 더보기(`more_page.dart`) 로그아웃 아래에 **"회원 탈퇴"** 진입점을 둔다.
- [ ] 탈퇴 화면 진입 시 **미리보기(dryRun)** 로 ① 진행 중 주문 건수 ② 소멸될 Qoin 잔액을 먼저 조회해 보여준다.
- [ ] 진행 중 주문(`paid/accepted/making/ready`)이 1건 이상이면 **탈퇴를 차단**하고 안내한다 (§0-2).
- [ ] 탈퇴 전 **파괴적 확인 절차**: 경고 문구 + 사유(선택/필수는 §0 확정) + **확인 문구 정확 입력**(예: "탈퇴합니다" 타이핑, fail-closed — `admin_store_delete_page.dart` 패턴 참고).
- [ ] 확인 시 Cloud Function `deleteMyAccount` 호출 → ① `accountDeletionHistory` 이력 기록 ② `users/{uid}` PII 익명화 ③ Qoin 소멸(잔액→0 + 원장 1건) ④ `favoriteStores`/`favoriteMenuItems` 서브컬렉션 삭제 ⑤ Firebase Auth 계정 삭제. **멱등**(phase 재진입).
- [ ] CF 성공 후 클라이언트는 소셜 unlink(best-effort) → `authProvider.signOut()` 경로로 세션을 null 로 만든다 → 기존 `ref.listen`/`RoleRouter` 가 `LoginPage` 로 보낸다.
- [ ] 주문(`orders`)·주문로그(`orderLogs`)·Qoin 원장(`qoinTransactions`)은 **보존**한다 (PII 없음, 정산·감사·법적 보존).
- [ ] customer 역할만 탈퇴 가능. owner/brand 는 진입점에서 안내 메시지로 차단 (§0-8).

### UI 요구사항

- [ ] 더보기 진입점: 로그아웃과 시각적으로 구분되는 저채도/보조 톤(파괴적 액션). 색상은 `AppColors` 만.
- [ ] 전체화면 탈퇴 페이지(다이얼로그 아님): 경고 카드 + 소멸 항목(Qoin·PII·즐겨찾기) 명시 + 보존 항목(주문 내역) 명시 + 확인 입력 + 하단 CTA.
- [ ] 진행 중 주문 차단 상태 전용 안내 카드(탈퇴 버튼 비활성).
- [ ] 로딩/처리 중 상태(탈퇴 진행), 실패 상태(재시도 안내).

### 상태 요구사항

- [ ] loading: dryRun 조회 중 / 탈퇴 처리 중
- [ ] error: CF 실패(네트워크/서버/진행중주문/권한) — 서버 raw message 노출 금지, 토큰 분류로 메시지 매핑
- [ ] empty: 해당 없음 (단건 대상)

---

## 데이터 모델

### 익명화 대상 — `users/{uid}` (CF 가 Admin SDK 로 수정)

| 필드 | 탈퇴 시 처리 |
|---|---|
| `displayName` | `'(탈퇴한 사용자)'` 로 치환 |
| `email` | `FieldValue.delete()` (제거) |
| `phone` | `FieldValue.delete()` (제거) — 로그 노출 금지 PII |
| `photoUrl` | `FieldValue.delete()` |
| `fcmToken` / `fcmTokenUpdatedAt` | `FieldValue.delete()` (알림 차단) |
| `qoinBalance` | `0` (소멸, 원장 1건 동반) |
| `uid` / `role` / `createdAt` / `provider` | **보존** (참조·감사 앵커) |
| `deleted` (신규) | `true` |
| `deletedAt` (신규) | `serverTimestamp` |
| `deletionReason` (신규, 선택) | 사유 |

> `orders` / `orderLogs` 는 PII 스냅샷이 없음(조사 확인) → **수정 불필요**, `userId` 유지. 점주 주문 화면은 pickupNumber 만 표시하므로 PII 유출 없음. `onOrderStatusChanged` 의 `users.fcmToken` 조회는 토큰 제거로 안전 no-op.

### 삭제 대상 서브컬렉션

- `users/{uid}/favoriteStores/*`, `users/{uid}/favoriteMenuItems/*` → 개인 취향 데이터, 정산 가치 없음 → **삭제**
- `users/{uid}/orderLogs/*`, `users/{uid}/qoinTransactions/*` → **보존** (PII 없음, 정산·감사·법적 보존)

### 신규 이력 — `accountDeletionHistory/{uid}_{millis}` (CF 전담 write)

`storeDeletionHistory` 스키마를 미러링한다.

| 필드 | 설명 |
|---|---|
| `uid` | 탈퇴 대상 |
| `provider` | email/google/kakao/naver |
| `snapshot` | 익명화 직전 `users` 문서 원본(PII 포함 — admin 전용 read) |
| `deletedBy` | 본인 uid |
| `deletedAt` | serverTimestamp |
| `reason` | 사유(선택/필수는 §0 확정) |
| `forfeitedQoin` | 소멸 Qoin 액 |
| `affected` | 삭제한 favorites 건수 등 |
| `phase` | 멱등 재진입 상태 |

### 신규 Qoin 원장 — `users/{uid}/qoinTransactions/{id}` (소멸 1건)

잔액 소멸을 원장에 박제(ledger 불변식 유지, `audit_trail` 거래 이력 원칙). `reason: 'accountDeletion'`, `amount: -balanceBefore`, `balanceAfter: 0`, 당시 값 박제.

---

## 레이어 설계

### Domain
- **Entity**: `AccountDeletionPreview { inFlightOrderCount, qoinToForfeit, canDelete }`
- **UseCase**:
  - `PreviewAccountDeletionUseCase` — dryRun 조회
  - `DeleteMyAccountUseCase` — 실제 탈퇴
- **Repository Interface**: `AccountDeletionRepository { preview(), deleteMyAccount({reason}) }`
- **Exception**: `AccountDeletionException { inFlightOrders, failed, unauthenticated }` (`store_deletion_exception.dart` 패턴)

### Data
- **DataSource**: `AccountDeletionRemoteDataSource` — `FirebaseFunctions.instanceFor(region:'asia-northeast3')` 로 `deleteMyAccount` 호출(dryRun / real). **SDK 예외를 도메인 예외로 변환, 서버 message 는 화면에 싣지 않고 토큰(`[ACCOUNT_HAS_INFLIGHT_ORDERS]` 등)으로만 분류** (`authority_callables_remote_data_source.dart` 패턴)
- **Repository Impl**: `AccountDeletionRepositoryImpl`
- **재인증**: **불필요** — Admin SDK CF(`admin.auth().deleteUser`)는 최근 로그인(reauthenticate)을 요구하지 않는다. 클라이언트 `user.delete()` 를 쓰지 않으므로 재인증 플로우 제거. 대신 **앱 내 확인 입력**으로 오작동을 방어 (§0-3·4)

### Presentation
- **Provider**: `accountDeletionControllerProvider` (dryRun 조회 + 탈퇴 실행 상태)
- **Page**: `AccountDeletionPage` (전체화면)
- **Widget**: 더보기 진입 타일, 확인 입력 필드, 진행중주문 차단 카드

### Cloud Function — `functions/src/deleteMyAccount.ts`
`deleteStore.ts` 패턴 복제: 포트/어댑터 + phase 멱등 + 이력(스냅샷) + dryRun + HttpsError 토큰 분류.

- **권한**: `requireSelf(request)` — `request.auth.uid` 존재 검증(신규 헬퍼, `requireAdmin` 대응). role 이 customer 인지도 서버 재검증(§0-8).
- **진행 중 주문 가드**: `orders where userId==uid, status in [paid,accepted,making,ready]` count. >0 이면 이력 쓰기 **전에** `HttpsError('failed-precondition', '... [ACCOUNT_HAS_INFLIGHT_ORDERS]', {inFlightOrders})`.
- **phase 순서**: `started → historyWritten → qoinForfeited → firestoreAnonymized → favoritesDeleted → authDeleted → done`. **Auth 삭제는 마지막** (삭제 후 `request.auth` 무효화되므로 Firestore 작업을 먼저 끝낸다). 실패 시 재호출이 미완료 phase 부터 재개.
- **dryRun**: 쓰기 0건, `{inFlightOrders, qoinToForfeit}` 반환 → 미리보기.
- **Auth 삭제**: `admin.auth().deleteUser(uid)` (신규, 선례 없음 — 조사 확인).

---

## 데이터 흐름

```text
AccountDeletionPage
  → accountDeletionControllerProvider
  → PreviewAccountDeletionUseCase / DeleteMyAccountUseCase
  → AccountDeletionRepository (interface)
  → AccountDeletionRepositoryImpl
  → AccountDeletionRemoteDataSource
  → Cloud Function deleteMyAccount (Admin SDK)
      → [dryRun] inFlight count + qoinBalance 반환
      → [real] accountDeletionHistory → users 익명화 → qoin 소멸(원장) → favorites 삭제 → auth.deleteUser → done
  ← 성공 후 클라이언트: 소셜 unlink(best-effort) → authProvider.signOut() → RoleRouter → LoginPage
```

---

## 에러 처리

| 케이스 | 처리 방식 |
|---|---|
| 진행 중 주문 존재 | 차단 안내 카드 + 탈퇴 버튼 비활성 (`[ACCOUNT_HAS_INFLIGHT_ORDERS]` 토큰) |
| 네트워크/서버 실패 | 실패 안내 + 재시도 (멱등이라 재호출 안전) |
| 미인증/세션 만료 | 로그인 화면 유도 |
| Auth 삭제만 실패(Firestore 완료 후) | 재시도 시 `authDeleted` phase 부터 재개 |
| 소셜 unlink 실패 | 무시(best-effort) — 탈퇴는 이미 성립 |
| owner/brand 역할 | 진입점에서 사전 차단 + 안내 (CF 도 서버 재검증) |

---

## 감사 추적 체크리스트 (`audit_trail §4`) 통과 확인

1. **돈·권한·정책 값 변경?** → Qoin 소멸(돈) → `qoinTransactions` 원장 1건 + `accountDeletionHistory` **남긴다** ✓
2. **덮어쓰기로 사라지는 값?** → `users` PII → 익명화 **직전 `snapshot`** 을 이력에 박제 ✓
3. **거래문서가 정책값 참조만?** → orders 는 당시 값 박제 구조, 추가 조치 불요 ✓
4. **누가?** → `deletedBy` = 본인 uid, `deletedAt` ✓
5. **batch?** → 단건 대상이나 `affected`(삭제 favorites 수)·`forfeitedQoin` 기록 ✓
6. **CF 로그 의존?** → No, `accountDeletionHistory` Firestore 영구 보존 ✓
7. **(상시) 권한 판정 필드 create/update 교차** → `accountDeletionHistory` 는 클라이언트 create/update/delete 모두 `if false`, read `isAdmin()` ✓

---

## 작업 분배

### designer (필요)
- UI 변경: **있음**
- 산출물: `docs/tasks/account_deletion/design.md`
- 전달 사항:
  - 더보기 로그아웃 아래 **회원 탈퇴 진입점** (파괴적·저위험 톤, `AppColors`)
  - 전체화면 `AccountDeletionPage`: 경고 + 소멸 항목(Qoin·PII·즐겨찾기) + **보존 항목(주문 내역)** 명시 + 확인 입력(fail-closed) + CTA
  - 진행 중 주문 **차단 카드** (버튼 비활성)
  - Qoin 소멸 고지 문구 (§0-5)
  - owner/brand 안내(차단) 문구 (§0-8)
  - 참고 레퍼런스: `admin_store_delete_page.dart`(전체화면 파괴적 플로우)

### developer
- 구현 항목: 위 Domain/Data/Presentation + Cloud Function `deleteMyAccount` + Rules `accountDeletionHistory` 블록 + `getOrCreateUserProfile` 재활성화 분기(§0-9 확정 시)
- 재사용할 기존 구조: `deleteStore.ts`(포트/어댑터·phase 멱등·이력·dryRun·토큰), `qoinAdmin.ts`(권한 헬퍼 → `requireSelf` 신규), `authority_callables_remote_data_source.dart`(예외 변환), `admin_store_delete_page.dart`(UI), `store_deletion_*`(repository/usecase/exception 계층)
- 주의할 레이어 규칙: Firebase/Auth/Admin SDK 는 **data/functions 에만**. presentation/domain 직접 import 금지. 익명화·Qoin 소멸·Auth 삭제는 **전부 CF(Admin SDK)** 가 수행(클라이언트 쓰기 경로 추가 금지). Auth 삭제는 phase 마지막.

### tester
- 주요 검증 기준:
  - 진행 중 주문 가드(차단 + 토큰 분류)
  - 익명화 결과(PII 제거·displayName 치환·deleted 플래그) + 주문/원장 **보존**
  - Qoin 소멸(잔액 0 + 원장 1건) + `accountDeletionHistory` 스냅샷
  - **멱등성**: phase 중단 후 재호출 시 중복 없이 재개, Auth 삭제 후 상태
  - CF 성공 후 세션 null → `LoginPage` 전환
  - Rules: `accountDeletionHistory` 클라이언트 create/update/delete 거부 회귀 케이스
- 반드시 확인할 예외 케이스: 소셜 재가입(§0-9, 확정 시) 동일 uid 재활성화 / owner·brand 차단 / Auth 삭제만 실패 후 재시도 / 소셜 unlink 실패 시 탈퇴 성립

---

## 완료 기준

- [ ] §0 결정사항 1~9 사용자 확정 (특히 2·5·9)
- [ ] `design.md` 작성 완료
- [ ] `implementation.md` 작성 완료 (CF + 클라이언트 + Rules)
- [ ] `test_report.md` 작성 완료
- [ ] 애플 심사 최소 요건(앱 내 탈퇴 + PII 삭제) 충족 확인
- [ ] FAIL 항목이 없거나 후속(Phase 2: admin 강제, owner/brand 탈퇴)으로 분리됨
