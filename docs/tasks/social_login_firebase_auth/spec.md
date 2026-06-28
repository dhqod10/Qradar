# 소셜 로그인 Firebase Auth 통합 (Naver / Kakao)

## 배경 및 문제

현재 Naver·Kakao 로그인은 각 SDK에서 사용자 정보를 받아 synthetic UID(`naver_XXX`, `kakao_XXX`)를 생성하지만,  
**Firebase Auth 세션을 만들지 않는다.**

```
// AuthRemoteDataSourceImpl.signInWithNaver()
return UserModel(
  uid: 'naver_${account.id}',  // Firebase Auth 세션 없음
  ...
);
```

그 결과 Firestore 요청 시 `request.auth == null` → Security Rules `isSignedIn()` = false → **전체 차단**.

현재 임시 조치: **admin은 이메일/비밀번호 로그인 사용**.  
일반 고객 중 Naver·Kakao 로 가입한 사용자는 Firestore 접근 불가 상태이므로 해당 로그인 방법은 비활성화하거나 이 phase 전까지 사용 금지.

---

## 목표

Naver·Kakao 로그인 후 Firebase Custom Token을 발급하여  
`FirebaseAuth.signInWithCustomToken()`으로 정식 Firebase Auth 세션을 생성한다.

---

## 설계 개요

### 흐름

```
[앱] Naver SDK 로그인 → access token 획득
  → [Cloud Function] verifyNaverToken(accessToken)
      → Naver API로 token 검증 + uid 확인
      → Firebase Admin SDK createCustomToken(uid)
      → return { customToken }
  → [앱] FirebaseAuth.signInWithCustomToken(customToken)
      → 정상 Firebase Auth 세션 확보
      → Firestore 접근 가능
```

### 동일 구조를 Kakao에도 적용

---

## 구현 범위

### Cloud Functions (functions/src/)

| 함수 | 역할 |
|------|------|
| `verifyNaverToken` | Naver access token → 사용자 정보 조회 → custom token 발급 |
| `verifyKakaoToken` | Kakao access token → 사용자 정보 조회 → custom token 발급 |

- Naver 프로필 API: `https://openapi.naver.com/v1/nid/me`
- Kakao 프로필 API: `https://kapi.kakao.com/v2/user/me`
- Firebase Admin SDK `auth().createCustomToken(uid)` 사용
- uid 형식은 현재와 동일하게 유지 (`naver_XXX`, `kakao_XXX`) → 기존 Firestore 문서 uid 호환

### Flutter (data layer)

`AuthRemoteDataSourceImpl.signInWithNaver()` 수정:
```dart
// Before
return UserModel(uid: 'naver_${account.id}', ...);

// After
final accessToken = result.accessToken; // Naver access token
final customToken = await _callVerifyNaverToken(accessToken);
final credential = await _firebaseAuth.signInWithCustomToken(customToken);
return UserModel(uid: credential.user!.uid, ...);
```

`AuthRemoteDataSourceImpl.signInWithKakao()` 동일 패턴 적용.

### AuthNotifier (auth_provider.dart)

- `build()` 의 Naver/Kakao 세션 복구 로직도 Firebase Auth 기반으로 통일  
  (`FlutterNaverLogin.isLoggedIn()` 체크 제거 또는 보조 수단으로만 사용)

---

## 비범위

- 기존 `naver_XXX` / `kakao_XXX` UID로 만들어진 Firestore 문서 마이그레이션  
  (uid 형식을 유지하므로 마이그레이션 불필요)
- Apple 로그인 등 추가 소셜 provider

---

## 주의사항

- Naver access token은 앱 측에서 Cloud Function으로 전달되므로 HTTPS callable function 사용
- Kakao REST API 키는 Firebase Secret Manager에서 관리 (현재 앱 코드에 하드코딩된 `nativeAppKey` 와 별개)
- Custom Token 유효시간: 1시간. Firebase Auth가 자동 refresh 처리하므로 앱 측 별도 대응 불필요
- 기존 email/Google 로그인 흐름은 변경 없음

---

## 작업 순서 (예상)

1. `/architect` — Cloud Function 설계 + Flutter data layer 설계
2. `/developer` — Cloud Function 2개 + Flutter signInWithNaver/Kakao 수정
3. `/tester` — Naver·Kakao 로그인 후 Firestore 접근 검증

---

## 현재 상태

- **대기 중** — 이전 phase 완료 후 진입
- admin은 이메일/비밀번호 로그인으로 임시 운영
- Naver·Kakao 로그인 버튼은 일반 사용자에게 노출되어 있으나 Firestore 접근 불가 상태  
  → 해당 버튼 비활성화 또는 안내 문구 추가 여부는 별도 결정 필요
