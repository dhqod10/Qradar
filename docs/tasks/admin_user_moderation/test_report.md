# admin_user_moderation — Test Report (Phase 1)

검증일: 2026-11-03 / 기준: spec.md, design.md, implementation.md + 실제 코드. 배포 없음.

## 자동 검증
| 항목 | 결과 |
|---|---|
| functions `npm test` (tsc 포함) | PASS 590/590 (userModeration 21건 포함) |
| test_rules `npm test` | PASS 534/534 |
| `flutter analyze` | PASS 0 issues |
| `flutter test` | PASS 전체 (1101, account_suspended_view 포함) |

## 중점 항목
1. 정지 집행 (setUserSuspension) — PASS. Auth updateUser({disabled}) + 정지 시 revokeRefreshTokens, users 정지필드 + userModerationHistory 는 한 batch. 멱등: 같은 상태면 이력 생략·Auth 는 항상 재적용. 본인/admin 대상 [CANNOT_MODERATE_ADMIN]. admin 아니면 requireAdmin 거부.
2. 결제 가드 — PASS. confirm 전 2-0(결제자 USER_DELETED/USER_SUSPENDED), 2-a'(ownerId≠결제자, STORE_OWNER_SUSPENDED). users 부재는 판정 안 함, read 실패는 unavailable+READ_FAILED. 거절 시 recordGateRejection. 점주 정지→매장 판매 중단 성립. 기존 tester 보류 "deleted 사용자 결제 차단" 해소. selfDealing assertion 변경(users read 0→2)은 가드 추가 read 와 일치해 타당.
3. 강제탈퇴 — PASS. runDeleteMyAccount 재사용, customer 전용(owner/brand FORCE_DELETE_CUSTOMER_ONLY), 진행주문 [ACCOUNT_HAS_INFLIGHT_ORDERS](코드 기준 확인), dryRun/phase 승계. self-탈퇴 회귀 없음: deleteMyAccount diff 는 actorUid 선택 인자뿐이며 actorUid 부재 시 deletedBy=uid, byAdmin 미포함으로 기존과 동일 (기존 테스트 전부 통과 + 회귀 테스트).
4. Rules — PASS. 정지 4필드 create/update 차단(admin 포함), userModerationHistory read admin / write false. 정상 가입·프로필·admin 일반 update 회귀 통과(UM-1~7).
5. 앱 — PASS. suspended 만 매핑(사유 미매핑). role_router 정지 분기는 user==null 다음, deep link 소비 이전. _ProfileLoadError: permission-denied 자동 signOut, raw error/stack 미노출. AccountSuspendedView: 연타 방지, 실패 showErrorDialog(고정 문구). user-disabled 문구 이메일/소셜 모두 적용. kSupportContact 공용 상수, more_page 참조.
6. 절대규칙 — PASS. lib 쪽 Firebase import/Color(0x) 없음, AppColors 만 사용. secret 하드코딩 없음. landing/console 미접촉. account_deletion 코어 변경은 actorUid 추가뿐.

## FAIL
- F-1 (문서 drift, 낮음~중간) docs/processes/data_ownership.md 가 코드와 불일치. Rules 가 단일 진실원인 문서에서 silent drift 발생:
  - 정지 필드명: 문서 `suspendedReason` vs 코드·Rules `suspensionReason` (L43, L51).
  - userModerationHistory (L393): 문서 `{autoId}`, `suspended`, `suspendedBy`, `at` vs 코드 문서 ID `{uid}_{millis}`, 필드 `action/before/after/changedBy/changedAt/reason/authAction/role/uid/targetUid`.
  - setUserSuspension 입력 (L434): 문서 `{targetUid, suspended, reason?}` vs 코드 `{targetUid, action:'suspend'|'unsuspend', reason?}`. 콘솔 구현자가 문서를 따르면 invalid-argument 발생.
  수정은 문서만 (코드 변경 불필요).

## 보류 / 메모
- H-1 spec.md 의 [USER_HAS_INFLIGHT_ORDERS] 표기는 실제 토큰 [ACCOUNT_HAS_INFLIGHT_ORDERS] 로 정정 필요(콘솔 분류용).
- H-2 에뮬/실환경 통합(Auth disabled 실제 적용, 재로그인 user-disabled, 실기기 AccountSuspendedView 레이아웃·글꼴 확대)은 미실행.
- H-3 _ProfileLoadError 의 permission-denied 판정은 문자열 매칭 (취약하나 동작상 허용).
- H-4 kSupportContact 는 placeholder — 출시 전 교체. 점주 정지 게이트는 매장 ownerId 1명만 판독(브랜드 보유자·fan-out 은 Phase 2).
- 후속: 콘솔 UI(사용자 작업), owner/brand 강제탈퇴 Phase 2.

## 요약
PASS: 6개 중점 영역 전부 / FAIL: 1 (문서 drift F-1) / 보류: 4
