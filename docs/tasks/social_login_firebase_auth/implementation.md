# 소셜 로그인 Firebase Auth 통합 — Implementation

## 구현 완료 항목

### Cloud Functions (`functions/src/`)

| 파일 | 유형 | 설명 |
|------|------|------|
| `verifyNaverToken.ts` | 신규 | Naver access token 검증 후 Firebase Custom Token 발급 |
| `verifyKakaoToken.ts` | 신규 | Kakao access token 검증 후 Firebase Custom Token 발급 |
| `index.ts` | 수정 | 두 함수 export 추가 |

**공통 패턴:**
- region: `asia-northeast3`
- HTTP 라이브러리: `axios` (기존 `tossClient.ts`와 동일)
- uid 형식 유지: `naver_<naverUid>`, `kakao_<kakaoUid>` → 기존 Firestore 문서 호환
- `createCustomToken(uid, { provider })` — provider 클레임 포함

### Flutter (`lib/data/datasources/remote/`)

**`auth_remote_data_source.dart`** 수정:

`signInWithNaver()`:
- `result.accessToken` (`NaverToken`) 에서 `.accessToken` 문자열 취득
- `verifyNaverToken` Cloud Function 호출 → customToken 수신
- `_firebaseAuth.signInWithCustomToken(customToken)` → 정식 Firebase Auth 세션 생성
- `credential.user!.uid` 를 UserModel uid로 사용

`signInWithKakao()`:
- `kakao.TokenManagerProvider.instance.manager.getToken()` 으로 OAuthToken 취득
- `verifyKakaoToken` Cloud Function 호출 → customToken 수신
- `_firebaseAuth.signInWithCustomToken(customToken)` → 정식 Firebase Auth 세션 생성
- `credential.user!.uid` 를 UserModel uid로 사용
- 프로필 정보(`email`, `displayName`, `photoUrl`)는 Kakao SDK에서 별도 조회

**의존성 추가:** `cloud_functions` 패키지 import (`pubspec.yaml`에 이미 존재)

### Flutter (`lib/presentation/customer/auth/`)

**`auth_provider.dart`** 수정:

`build()` 간소화:
- 기존: Firebase Auth 확인 → Kakao 토큰 확인 → Naver 토큰 확인 (3단계)
- 변경: `FirebaseAuth.instance.currentUser` 만 확인 (1단계)
- 근거: Naver/Kakao 로그인도 Custom Token 경유로 Firebase Auth 세션에 통합되므로 별도 체크 불필요
- 불필요한 import(`flutter_naver_login`, `kakao_flutter_sdk_user`) 제거

## 파일 목록

```
functions/src/verifyNaverToken.ts    (신규)
functions/src/verifyKakaoToken.ts    (신규)
functions/src/index.ts               (수정)
lib/data/datasources/remote/auth_remote_data_source.dart  (수정)
lib/presentation/customer/auth/auth_provider.dart         (수정)
```

## flutter analyze 결과

```
No issues found! (ran in 5.5s)
```

## 테스트 포인트

1. **Naver 로그인 후 Firebase Auth 세션 확인**
   - 로그인 완료 후 `FirebaseAuth.instance.currentUser != null` 검증
   - `currentUser.uid`가 `naver_<naverUid>` 형식인지 확인

2. **Kakao 로그인 후 Firebase Auth 세션 확인**
   - 로그인 완료 후 `FirebaseAuth.instance.currentUser != null` 검증
   - `currentUser.uid`가 `kakao_<kakaoUid>` 형식인지 확인

3. **Firestore 접근 가능 여부**
   - 로그인 후 Firestore 읽기/쓰기가 Security Rules `isSignedIn()` 통과하는지 확인
   - 이전에 차단되던 `request.auth == null` 오류가 해소되는지 확인

4. **앱 재시작 후 세션 유지**
   - Naver/Kakao 로그인 후 앱 재시작 시 `auth_provider.build()`가 Firebase Auth 세션에서 사용자를 복구하는지 확인

5. **로그아웃 후 상태 초기화**
   - `signOut()` 호출 후 `currentUser == null` 및 Kakao/Naver SDK도 로그아웃되는지 확인

6. **Cloud Function 오류 처리**
   - 유효하지 않은 access token 전달 시 `unauthenticated` 오류 반환 확인
   - 네트워크 오류 시 `internal` 오류 반환 확인

## 미구현/보류 항목

- Cloud Functions 배포: `firebase deploy --only functions` 명령 별도 실행 필요
- 기존 `naver_XXX` / `kakao_XXX` UID로 만들어진 Firestore 문서는 uid 형식이 동일하게 유지되므로 마이그레이션 불필요 (spec.md 비범위 항목)
