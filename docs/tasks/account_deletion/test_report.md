# account_deletion — 테스트 리포트 (Phase 1: customer 본인 탈퇴)

검증 방식: spec/design/implementation 대조 + 코드 직접 읽기 + 자동 테스트 실행. 배포 안 함.

## 자동 검증
| 항목 | 결과 |
|---|---|
| functions `npm test` (tsc 포함) | 569 pass / 0 fail (deleteMyAccount 11건 포함) |
| test_rules `npm test` | 518/518 PASS, FAIL 0 (AD1~AD3b 포함) |
| `flutter analyze` | No issues |
| `flutter test` | 전체 통과 (1098+) |

## 항목별 결과
| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 1 | 익명화/phase 순서 | PASS | 이력(started, snapshot)→Qoin소멸→익명화(displayName 치환, email/phone/photoUrl/fcmToken/fcmTokenUpdatedAt 삭제, deleted/deletedAt)→favorites recursiveDelete→Auth 삭제→done. Auth 가 마지막(테스트 `calls` 순서 검증). orders/orderLogs/qoinTransactions 는 건드리지 않음 |
| 2 | 진행 중 주문 차단 | PASS | 서버 `countInFlightOrders`(paid/accepted/making/ready, deleteStore 의 IN_FLIGHT_STATUSES 재사용) > 0 이면 `failed-precondition [ACCOUNT_HAS_INFLIGHT_ORDERS]`, 이력 쓰기 전 차단. 클라 dryRun canDelete + 실행 시 서버 재검증 이중. 토큰 없는 failed-precondition 은 가드로 오분류 안 함 |
| 3 | Qoin 소멸·불변식 | PASS | 단일 runTransaction: `forfeit_{deletionId}` 원장(amount -잔액, balanceAfter 0) + qoinBalance 0. 원장 이미 있으면 no-op(이중 소멸 불가). 잔액 0 이면 원장 없음. history.forfeitedQoin 스냅샷 |
| 4 | 멱등 | PASS | 완료 후 `{alreadyDeleted:true}`, 각 단계 중단 후 재개 4종 테스트(이력 1·원장 1·Auth 1회). 가드는 phase<=started 에서만 재평가(타당) |
| 5 | 권한 | PASS | `requireSelf`, role != customer → permission-denied(익명화 후에도 role 보존이라 재진입 동일). Rules `users.delete` admin 전용 유지(AD3), 클라가 `deleted` set 불가(AD3b) |
| 6 | 소셜 재활성화 | PASS | `reactivateIfDeleted` 트랜잭션 set(merge 아님)으로 신규 상태 재초기화; kakao/naver 모두 createCustomToken 직전 호출, 실패 시 로그인 거부(fail-closed). 클라는 deleted 를 못 지움 |
| 7 | UI | PASS | 진입점 로그아웃·버전 사이 12px textMuted 밑줄, 진입 단계 빨강 없음. owner/brand → showErrorDialog + `_supportContact` 상수. 확인문구 trim 완전일치, 컨트롤러 리스너로 IME 재평가, CTA fail-closed(preview 성공+canDelete+일치+비처리+비차단), Qoin 0 이면 카드/행 숨김, PopScope(canPop: !processing)+뒤로가기 제거, raw message 미노출(토큰 분류만), 성공 시 signOut 만, 차단 카드 |
| 8 | 역할 분기 | PASS | `currentUserProfileProvider`(Firestore) 기준. 프로필 미로드(null)는 customer 경로로 가나 서버가 최종 재검증 |
| 9 | 절대규칙 | PASS | domain/presentation 에 firebase/cloud_functions import 없음(SDK 는 data datasource 에만). `Color(0x` 없음, AppColors + withValues(alpha:) 만. secret 하드코딩 없음. 범위 외 수정 없음(변경 10개 파일 모두 기능 관련, 포맷 사고 파일 정리됨) |
| 10 | Rules | PASS | `accountDeletionHistory` read admin / write false. snapshot 에 PII(phone 등)가 있어 admin read 한정은 storeDeletionHistory 선례와 동일하며 타당(고객 본인 read 도 거부). AD1~AD3b 10건은 read 3, 고객 CUD 3, admin create/delete 거부 2, users.delete/deleted-set 회귀 2로 충분히 타당 |

## 개수
PASS 10 / FAIL 0 / 보류 3

## FAIL
없음.

## 보류 / 후속 후보 (우선순위 순)
1. **[중] `reactivateIfDeleted` 전용 테스트 없음.** 재가입 재초기화(잔여 필드 제거, deleted 아닌 문서 no-op, 문서 없음 no-op)가 자동 테스트로 보호되지 않는다. 코드는 올바르나 회귀 방지용 단위 테스트(fake db) 추가 권장.
2. **[저] 중단된 탈퇴(이력 phase != done) 상태에서 소셜 재로그인 시 재활성화 후 재시도 경로.** Auth 삭제 이전 단계에서 멈춘 경우 `deleted:true` 문서가 재초기화되고, 사용자가 다시 탈퇴를 누르면 미완료 이력 재진입(가드 생략: phase>=qoinForfeited)으로 이어진다. 실제 영향은 사용자가 다시 탈퇴를 누른 경우에 한정되고 결과도 탈퇴 완료이므로 위험 낮음. 실제 중단 시나리오 수동 확인 권장.
3. **[저] 가드와 Auth 삭제 사이 경합 및 ID 토큰 잔존.** 가드 통과 후 새 결제가 들어오는 극소 창, 삭제 후 ID 토큰 최대 1시간 유효. 클라는 signOut 하므로 실사용 영향 낮음. 결제 CF 에서 users.deleted 거부는 후속 검토 후보.

## 개발자 보류항목 타당성 (수정 요구 아님)
- 클라 소셜 unlink 보류: 타당. Auth 계정 삭제로 앱 재로그인 세션이 막혀 애플 삭제 요건과 충돌하지 않고, auth 체인 수정은 범위 밖. 외부 소셜 동의 해제는 후속으로 등재.
- 고객센터 연락처 placeholder: 타당(상수 1곳). 단 출시 전 반드시 교체해야 하는 체크리스트 항목이며 앱 심사 전 확정 필요.
- admin 강제 삭제 / owner·brand 탈퇴 Phase 2: 타당. 현재는 안내 다이얼로그 + 서버 거부로 안전하게 막혀 있음.
- 부가: signOut 의 FCM 토큰 정리 쓰기는 Auth 삭제 후라 Rules 상 거부·삼켜짐, 익명화 문서에 PII 재생성 없음(무해).

## 가장 먼저 할 일
FAIL 없음. 우선 후속은 보류 1번(reactivateIfDeleted 단위 테스트). 배포 전 `_supportContact` 실제 값 확정.
