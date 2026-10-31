# social_login_profile (SL-1) — implementation

## 원인 재확인
- 네이버: CF 가 nid/me 프로필을 받고도 `{customToken}` 만 반환(프로필 폐기). 앱은 code-flow 라 access token 없음.
- 카카오: 앱이 `UserApi.me()` 로 프로필을 받아 UserModel 에 담음(로그인 직후 auth state 에는 반영됨). 단 users/{uid} 문서에는 "문서 최초 생성 시"에만 기록됨.
- **홈 user 소스 추적**: `HomeHeader` 는 `authProvider`(AsyncNotifier<UserEntity?>) 만 읽었다. 로그인 직후엔 sign-in 반환 UserModel, **앱 재시작 후엔 `FirebaseAuth.currentUser`** (커스텀 토큰 세션이라 displayName/email 없음) → 'Qrator' 폴백. users/{uid} 문서(`currentUserProfileProvider`)는 홈이 읽지 않았다.

## 수정 파일
- `functions/src/verifyNaverToken.ts` — 반환 `{ customToken, profile: { email?, name?, imageUrl? } }` (값 없으면 키 생략). uid 유도/입력 계약 불변.
- `lib/data/datasources/remote/auth_remote_data_source.dart` — `signInWithNaver` 가 CF `profile` 로 email/displayName/photoUrl 채움(구버전 CF 응답이면 기존 Firebase 값으로 폴백). 시그니처 불변.
- `lib/data/datasources/remote/user_remote_data_source.dart` — `fillProfile(uid, displayName?, photoUrl?)` 추가 (update, 전달된 키 + updatedAt 만).
- `lib/data/repositories/user_repository_impl.dart` — `getOrCreateUserProfile`: 기존 문서면, 문서 값이 비어 있고 로그인 UserEntity 에 값이 있을 때만 displayName/photoUrl 채움. 이미 값이 있으면 덮지 않음, role/brandId/qoin 등 다른 필드 무접촉. 실패해도 로그인 무영향(try/catch).
- `lib/presentation/customer/home/widgets/home_header.dart` — 이름 우선순위: users 프로필 displayName → auth displayName → auth/프로필 email 앞부분 → 'Qrator'. (재시작 후에도 영속 프로필이 도달)

## 기존 프로필-없는 문서 처리
로그인 시 `currentUserProfileProvider` 가 auth 변화로 재실행 → `getOrCreateUserProfile` 에서 위 보강 수행(merge 성격의 부분 update).

## 제약 / 보류
- **email 은 기존 문서에 보강하지 않음**: Rules `isSelfProfileUpdate` 화이트리스트에 `email` 이 없어 update 시 permission-denied. 신규 문서 create 시에만 기록. (필요하면 rules 에 `email` 추가가 별도 결정 필요 — 보안 영향 검토 후.) 홈 인사말은 displayName 우선이라 영향 적음.
- 이미 displayName 이 채워진 문서는 provider 쪽 변경을 동기화하지 않음(비범위).
- 동의항목 미승인 등 값 부재 시 폴백 유지.

## 테스트 포인트
1. 네이버 신규 로그인 → 홈 인사말에 네이버 이름, users/{uid} 에 displayName/photoUrl/email 저장.
2. 네이버 기존(프로필 없음) 계정 재로그인 → users 문서 displayName/photoUrl 채워지고 role/brandId/qoinBalance 불변.
3. 앱 완전 종료 후 재실행 → 홈 인사말이 'Qrator' 가 아니라 저장된 이름.
4. 카카오 동일 시나리오(기존 문서 보강).
5. 이미 이름이 있는 문서는 덮이지 않음. Google/email 로그인 회귀 없음.
6. 구 CF(profile 없음)와 신 앱 조합에서 크래시 없음.

## 사용자 배포 순서
1. `functions` 에서 `verifyNaverToken` 만 배포 (`firebase deploy --only functions:verifyNaverToken`).
2. 앱 재빌드/배포. (앱 먼저 나가도 구 CF 응답에서 안전하게 폴백.)
Rules 변경 없음.

## 검증
- `flutter analyze`: No issues (아래 보고 참조), functions `npm run build`(tsc) 통과, `flutter test` 결과는 최종 보고 참조.
- 신규 테스트 미추가(Firestore/CF 의존 경로; 순수 로직 분리 없음).
