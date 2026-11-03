# admin_user_moderation — 구현 기록 (Phase 1)

기준: `spec.md`, `design.md` (사용자 §0 결정 전부 권고대로 확정). 배포(firebase deploy)는 하지 않았다.

## 구현 항목

### Cloud Functions (functions/src)
| 파일 | 내용 |
|---|---|
| `setUserSuspension.ts` (신규) | admin callable. 입력 `{targetUid, action:'suspend'|'unsuspend', reason?}` → 응답 `{changed, action, historyId}`. 순서: 대상 read → admin/본인 거부 `[CANNOT_MODERATE_ADMIN]` → (상태가 바뀔 때만) `userModerationHistory/{uid}_{millis}` + users 플래그를 **한 batch** → Auth `updateUser({disabled})` → 정지 시 `revokeRefreshTokens`. 이미 같은 상태면 이력 없음(멱등), Auth 는 항상 재정합(③ 후 ④ 실패 재진입). 정지 필드: `suspended/suspendedAt/suspendedBy/suspensionReason`, 해제 시 하위 3개 delete + `suspended:false`. 이력: `before/after/role/changedBy/changedAt/reason/authAction`. |
| `adminDeleteUser.ts` (신규) | admin callable. 입력 `{targetUid, reason?, dryRun?}`. 본인/admin 대상 → `[CANNOT_MODERATE_ADMIN]`, owner/brand → `[FORCE_DELETE_CUSTOMER_ONLY]`(failed-precondition), 그 외는 `runDeleteMyAccount` 코어 재사용(진행주문 가드 `[ACCOUNT_HAS_INFLIGHT_ORDERS]`, phase 멱등, dryRun, Auth 삭제 승계). |
| `deleteMyAccount.ts` (최소 수정) | 코어 args 에 선택 `actorUid` 추가. `deletedBy = actorUid ?? uid`, `actorUid` 가 있고 uid 와 다를 때만 `byAdmin:true` 추가. actorUid 없으면 기존 payload 와 동일(회귀 테스트 추가). |
| `userStateGuard.ts` (신규) | 순수 판정 `buyerBlockReason`(deleted→USER_DELETED, suspended→USER_SUSPENDED), `ownerBlockReason`(→STORE_OWNER_SUSPENDED). |
| `verifyTossPayment.ts` | Toss confirm 전 유저 가드 2지점(모드 스위치 없이 상시): 2-0 결제자 본인 users read, 2-a' 매장 `ownerId`(≠결제자) users read. 거절 시 `recordGateRejection` + HttpsError(`USER_SUSPENDED`/`USER_DELETED` permission-denied, `STORE_OWNER_SUSPENDED` failed-precondition). 유저 문서 없음 → 판정 안 함(기존 동작), read 실패 → `unavailable`+`READ_FAILED`(confirm 안 부름). tester 보류 "deleted 사용자 결제 차단" 해소. |
| `paymentGate.ts` | `GateReason`/`GATE_HTTPS_CODE`/`GATE_TEXT` 에 3개 사유 추가. |
| `index.ts` | `setUserSuspension`, `adminDeleteUser` export. |

### Firestore Rules
- `moderationManagedFields()/touchesModerationManaged()/hasModerationManagedOnCreate()` 추가. `users` **create**(`!hasModerationManagedOnCreate()`) 와 **update**(`!touchesModerationManaged() && (isAdmin() || self)`) 에 적용 → admin 포함 모든 클라이언트 쓰기 차단(CF 만 우회).
- `userModerationHistory`: read admin / write false.

### Dart 앱
- `UserEntity`/`UserModel` 에 `suspended`(bool, 기본 false)만 매핑(읽기전용, JSON 제외). 사유 미매핑. freezed 재생성(두 모델만 diff).
- `lib/presentation/common/account_suspended_view.dart` 신규(design.md 준수: 원형 배지·제목·본문·문의 카드·하단 로그아웃, 연타 방지 스피너, 실패 시 `showErrorDialog`, 작은 화면 스크롤 대응).
- `role_router.dart`: `user==null` 다음·알림 deep link 소비 이전에 `user.suspended` 분기. 기존 `_ErrorView`(raw error/stack 노출)를 `_ProfileLoadError` 로 교체: 오류 문자열에 `permission-denied` 면 **자동 signOut → LoginPage**(그 사이 로딩 표시), 그 외는 raw 비노출 안내 + 다시 시도/로그아웃. (정지 직후 토큰 무효화 경로를 이번에 고침.)
- `lib/core/constants/support_contact.dart` 신규 `kSupportContact`(기존 placeholder 이동). `more_page.dart` 의 private `_supportContact` 제거 후 공용 상수 참조 → **출시 전 교체 지점 1곳**.
- 로그인: `auth_error_message.dart` 에 `kAccountRestrictedMessage`("이용이 제한된 계정이에요. 고객센터에 문의해 주세요.") + `isAccountDisabledError`. 이메일 로그인(기존 `user-disabled` 매핑 문구 교체), 소셜 로그인(`login_page.dart` 에러 리스너)에서 적용.

### 건드리지 않은 것
`landing/console` 일절 미수정(콘솔 UI = 사용자 작업). 콘솔이 쓸 callable 계약은 위 표의 입출력/토큰.

## 검증
- `functions: npm test` (tsc 포함) 590/590 통과. 신규 `test/userModeration.test.mjs` 21개(정지/해제/멱등/admin·본인 거부, 강제탈퇴 customer·owner·brand·admin·진행주문·dryRun, self-탈퇴 회귀, 결제 가드 5종+read 실패) + package.json 등록. 기존 `selfDealing.test.mjs` 1건 assertion 수정(타인 매장 통과 시 users read 0 → 2; 상태 가드의 의도된 추가 읽기). deleteMyAccount 기존 테스트 전부 통과.
- Rules 하네스 `test_rules` 534/534 통과(신규 UM-1~7: 본인·admin 정지필드 update 거부, create 거부, 정상 가입/프로필/admin 일반 필드 회귀, userModerationHistory 클라/admin write 거부·admin read 허용).
- `flutter analyze` 0 issues, `flutter test` 전체 통과(신규 `test/presentation/common/account_suspended_view_test.dart` 3개).
- dart format 은 내가 만든/수정한 파일에만 적용.

## 테스트 포인트 (tester)
1. 정지 → 해당 계정 Auth disabled·토큰 revoke 실제 적용(에뮬/실환경), 앱: 스트림 갱신 시 AccountSuspendedView, 토큰 무효로 permission-denied 시 자동 LoginPage, 재로그인 시도 시 `user-disabled` 안내(이메일/소셜).
2. 해제 → 재로그인 정상, 이력 2건(suspend/unsuspend), 중복 호출 이력 증가 없음.
3. 정지 유저/점주 정지 매장/deleted 유저 결제 거절 + `paymentGateRejections` 기록.
4. 강제탈퇴: dryRun→실행, `accountDeletionHistory.deletedBy=admin, byAdmin:true`, owner/brand 거부, 진행주문 차단, 재가입(reactivate).
5. Rules: 정지 필드 client/admin 쓰기 거부 확인(자동화 완료), 실기기 AccountSuspendedView 레이아웃·글꼴 확대.

## 미구현 / 보류 / 메모
- owner/brand 강제탈퇴, 브랜드 정지→가맹점 fan-out: Phase 2 (비범위).
- 어드민 콘솔 UI(회원 관리 뷰, 정지/해제/강제탈퇴 버튼): 사용자가 별도 구현.
- `kSupportContact` 는 placeholder("고객센터 문의: (추후 입력)") — 출시 전 `lib/core/constants/support_contact.dart` 1곳 교체.
- 인플라이트 토큰: spec 본문은 `[USER_HAS_INFLIGHT_ORDERS]` 로 적었으나 코어의 실제 토큰은 `[ACCOUNT_HAS_INFLIGHT_ORDERS]`(self-탈퇴 호환, 승계). 콘솔은 후자로 분류해야 한다.
- 점주 정지 게이트는 매장 `ownerId` 1명만 판독(브랜드 보유자 정지는 Phase 2). 에뮬레이터 통합 테스트(`test:emulator`)·배포는 실행하지 않음.
- 운영 문서(`data_ownership.md` 등)에 신규 컬렉션/필드 권한 행 추가는 이번에 하지 않음(필요 시 architect/문서 후속).
