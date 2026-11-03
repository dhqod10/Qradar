# account_deletion — 구현 기록 (Phase 1: customer 본인 탈퇴)

기준: `spec.md` + `design.md`, 사용자 확정 결정 §0 전부 권고대로. **firebase deploy 하지 않았다.**

## 1. 구현 항목

### Cloud Function (functions/)
| 파일 | 내용 |
|---|---|
| `src/deleteMyAccount.ts` (신규) | callable `deleteMyAccount`. 포트/어댑터 + phase 멱등 (`deleteStore` 구조 준용). dryRun, 진행 중 주문 가드 `[ACCOUNT_HAS_INFLIGHT_ORDERS]`, 이력 스냅샷, `requireSelf`, customer 서버 재검증 |
| `src/accountReactivation.ts` (신규) | `reactivateIfDeleted` — 소셜 재가입 시 `deleted==true` users 문서를 신규 상태로 재초기화 (§0-9) |
| `src/verifyKakaoToken.ts`, `src/verifyNaverToken.ts` | customToken 발급 직전에 `reactivateIfDeleted` 호출 (실패 시 로그인 거부 — deleted 문서 방치 금지) |
| `src/index.ts` | export 추가 |
| `test/deleteMyAccount.test.mjs` (신규), `package.json` | 테스트 11건 등록 |

phase 순서: `started → qoinForfeited → anonymized → favoritesDeleted → authDeleted → done`. Auth 삭제는 마지막.
- 진행 중 주문 가드는 이력 쓰기 **전** (차단은 탈퇴 시도가 아니다, 이력 없음).
- Qoin 소멸: 한 트랜잭션에서 `users/{uid}/qoinTransactions/forfeit_{deletionId}` (`type:'forfeit'`, `reason:'accountDeletion'`, `amount:-잔액`, `balanceAfter:0`) 생성 + `qoinBalance:0`. 원장 문서가 이미 있으면 no-op (이중 소멸 불가). 잔액 0 이면 원장 없음. balance==Σamount 유지.
- 익명화: `displayName='(탈퇴한 사용자)'`, `email/phone/photoUrl/fcmToken/fcmTokenUpdatedAt` 삭제, `deleted:true`, `deletedAt`. `uid/role/provider/createdAt` 보존 (소셜 uid 문자열 `kakao_<id>` 자체는 문서 ID 앵커로 남는다).
- 완료 후 재호출은 `{alreadyDeleted:true}` no-op. owner/brand/admin 은 `permission-denied`.

### Rules / 하네스
- `firestore.rules`: `accountDeletionHistory` 1블록 (`read: isAdmin()`, `write: false`). `users.delete` 는 admin 전용 그대로.
  - 주의: 프롬프트의 "client read/write false" 중 read 는 spec 체크리스트 7 및 `storeDeletionHistory` 선례에 맞춰 **admin read 허용**(snapshot 에 PII, 클라이언트=고객/점주는 불가).
- `test_rules/rules.test.mjs`: AD1~AD3b 10건 추가 (고객 read/create/update/delete 거부, admin create/delete 거부, admin read 허용, 본인 users.delete 거부, 본인 `deleted` 플래그 set 거부). 에뮬레이터 실행 전체 PASS, FAIL 0.

### Dart
- domain: `entities/account_deletion_preview.dart`, `repositories/account_deletion_repository.dart`, `usecases/preview_account_deletion_use_case.dart`, `usecases/delete_my_account_use_case.dart`
- core: `errors/account_deletion_exception.dart` (inFlightOrders / unauthenticated / failed)
- data: `datasources/remote/account_deletion_remote_data_source.dart` (SDK 예외 변환, 서버 message 미노출, 토큰 분류, dryRun 응답 숫자 누락 시 실패=fail-closed), `repositories/account_deletion_repository_impl.dart`
- presentation (`customer/more/account_deletion/`): `account_deletion_providers.dart` (preview FutureProvider + Controller Notifier), `account_deletion_page.dart` (private 위젯만, 신규 공통 컴포넌트 없음)
- `customer/more/more_page.dart`: 로그아웃과 버전 사이 `회원 탈퇴` (12px textMuted 밑줄). customer(또는 프로필 미로드) → `AccountDeletionPage`, 그 외 역할 → `showErrorDialog('탈퇴 안내')`. 연락처는 파일 상단 단일 상수 `_supportContact = '고객센터 문의: (추후 입력)'`. role 은 `currentUserProfileProvider`(Firestore) 기준 — `authProvider` 의 role 은 Auth 세션 기본값이라 쓰지 않았다.
- 성공 시 `authProvider.notifier.signOut()` 만 호출 (수동 pop/push 없음, RoleRouter 가 LoginPage 로). 처리 중 `PopScope(canPop:false)` + 뒤로가기 제거, 확인 문구 `trim()==탈퇴합니다` (TextEditingController 리스너로 IME 조합 중에도 재평가), CTA 는 일치+미리보기 성공+비차단+비처리일 때만 활성.
- `test/presentation/customer/more/account_deletion_test.dart`: 활성 조건 / 토큰 분류 / 파싱 5건.

### 문서
`data_ownership.md` (users 익명화·deleted, `accountDeletionHistory`, `deleteMyAccount` 카탈로그), `audit_trail.md` (이력 1줄), `entity_lifecycle.md` (참고 1단락).

## 2. 검증
- `functions: npm test` (tsc 포함) 569 pass / 0 fail (deleteMyAccount 11건 포함: dryRun 쓰기 0, 진행중주문 차단·이력 없음, 익명화·스냅샷·Qoin 소멸·순서, Qoin 0, 이미 탈퇴 no-op, 비 customer 거부, not-found, qoin/anon/fav/auth 각 단계 중단 후 재개(이력·원장 1건, Auth 1회), 완료 후 재호출 no-op).
- `npm --prefix test_rules test`: FAIL 0.
- `flutter analyze`: No issues. `flutter test`: 전체 통과.

## 3. tester 테스트 포인트
1. customer 더보기 → 회원 탈퇴 진입, 로딩 → 폼. Qoin>0 이면 강조 카드 + `보유 Qoin` 행, Qoin 0 이면 둘 다 숨김.
2. 진행 중 주문 있는 계정 → 차단 카드(N건) + `확인` 만 노출, 탈퇴 UI 없음. 미리보기 이후 새 주문이 생긴 경우 실행 시 서버가 차단 → 차단 화면 전환.
3. 확인 문구 정확 일치(앞뒤 공백 허용)에서만 버튼 활성. 한글 조합 중 비활성. 처리 중 뒤로가기/취소/입력 불가.
4. 성공 → LoginPage. Firestore: users 익명화 필드, `accountDeletionHistory` 1건(phase done, snapshot PII), Qoin 원장 `forfeit_*` 1건, favorites 삭제, orders/orderLogs/qoinTransactions 보존, Auth 계정 삭제.
5. 중간 실패 후 재시도(멱등), 실패 인라인 문구에 서버 raw 메시지 없음.
6. owner/brand 계정이 더보기에서 탈퇴 탭 → 안내 다이얼로그 (페이지 이동 없음). 서버는 비 customer 를 `permission-denied` 로도 거부.
7. 카카오/네이버 탈퇴 후 같은 계정으로 재가입 → 깨끗한 신규 customer 상태(Qoin 0, deleted 없음, 프로필 재보강).

## 4. 미구현 / 보류 / 유의
- **owner/brand 고객센터 연락처**: placeholder (`more_page.dart` 의 `_supportContact`). 운영 확정 후 교체.
- **admin 강제 삭제, owner/brand 탈퇴**: Phase 2.
- **클라이언트 소셜 unlink (kakao unlink / naver 토큰 폐기, §0-4)**: 미구현. 해당 SDK 호출이 AuthRemoteDataSource/Repository/UseCase 체인(auth 파일)을 건드려야 해서 "다른 기능 파일 수정 금지" 범위를 지켜 보류. Firebase Auth 삭제로 앱 세션/재로그인은 차단되므로 애플 요건에는 영향 없고, 외부 소셜 동의 해제만 남는다. 후속 필요.
- 성공 후 `signOut()` 이 기존 흐름대로 FCM 토큰 정리를 위해 `users/{uid}` 에 `fcmToken:null/fcmTokenUpdatedAt/updatedAt` 을 쓰려 한다 (실패는 삼켜짐). 성공 시 PII 는 아니지만 `fcmTokenUpdatedAt` 키가 익명화 문서에 재생길 수 있다 (무해). 필요하면 후속으로 탈퇴 전용 signOut 분리.
- 동일 소셜 재가입 시 이전 `qoinTransactions` 서브컬렉션(소멸 원장 포함)은 같은 uid 아래 남는다 (잔액 0, 불변식 유지).
- 로그인 직후 완료 SnackBar(design 3-6)는 라우터 전환 유실 가능성이 있어 선택 사항으로 구현하지 않았다.
- **사고 보고**: 구현 중 `dart format lib/domain` 이 기존 파일 48개를 포맷만 변경했고, 되돌리려던 `git restore` 가 권한 정책으로 거부되어 **그대로 남아 있다** (내용 변경 없음, 포맷 전용). 목록: scratchpad `accidental_format_files.txt`. 이 48개는 시작 시점에 clean 이었으므로 `git restore -- $(cat <목록>)` 로 안전하게 되돌릴 수 있다. 커밋 시 제외 필요.
