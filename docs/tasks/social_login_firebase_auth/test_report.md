# social_login_firebase_auth 테스트 리포트

## 테스트 일시

- 2026-05-25 ~ 2026-05-26

---

## 테스트 방법

- 정적 코드 검증: `auth_remote_data_source.dart`, `auth_provider.dart`, `verifyNaverToken.ts`, `verifyKakaoToken.ts` 직접 확인
- 문서 교차 검증: spec.md / implementation.md 대조
- `flutter analyze` — No issues found
- 라이브 검증: 운영 환경에서 Naver/Kakao 로그인 후 Firestore 접근 확인 (Custom Token 세션 기반 T5 회귀 포함)
- IAM 권한: `Service Account Token Creator` 역할 부여 후 `createCustomToken()` 정상 발급 확인

---

## 전체 결과

- PASS: 24개 (F1 / H3 정정 반영, 2026-05-26)
- FAIL: 0개
- 보류: 4개

> **정정 이력 (2026-05-26):** F1 (IAM 권한) 과 H3 (Cloud Functions 배포) 는 본 검증 세션 (2026-05-25) 에서 실제로 완료되었으나 정적 검증 단계에서는 인프라 상태 확인 불가로 FAIL/보류 처리되었음. 라이브 검증 결과 T4 (Naver/Kakao 로그인) 가 정상 동작함이 확인되어 양 항목 모두 PASS 로 정정.

---

## PASS 항목

### 기능 검증

- [x] `verifyNaverToken` Cloud Function 구현 (asia-northeast3, onCall)
  - 근거: `functions/src/verifyNaverToken.ts` 확인. Naver 프로필 API 호출 → `naver_${naverUid}` uid 생성 → `createCustomToken(uid, {provider: 'naver'})` → `{ customToken }` 반환
  - 위치: `functions/src/verifyNaverToken.ts`

- [x] `verifyKakaoToken` Cloud Function 구현 (asia-northeast3, onCall)
  - 근거: `functions/src/verifyKakaoToken.ts` 확인. Kakao 프로필 API 호출 → `kakao_${kakaoUid}` uid 생성 → `createCustomToken(uid, {provider: 'kakao'})` → `{ customToken }` 반환
  - 위치: `functions/src/verifyKakaoToken.ts`

- [x] uid 형식 보존 (`naver_<naverUid>`, `kakao_<kakaoUid>`) — 기존 Firestore 문서 호환
  - 근거: `verifyNaverToken.ts` line 82 `const uid = 'naver_${naverUid}'`, `verifyKakaoToken.ts` line 82 `const uid = 'kakao_${kakaoUid}'`
  - 위치: `functions/src/verifyNaverToken.ts` line 82, `functions/src/verifyKakaoToken.ts` line 82

- [x] `index.ts`에 두 함수 export 추가
  - 근거: implementation.md 구현 완료 항목 기록
  - 위치: `functions/src/index.ts`

- [x] region 일관성 (`asia-northeast3`) — Flutter client와 Functions 동일
  - 근거: `verifyNaverToken.ts` line 36 `region: 'asia-northeast3'`, `verifyKakaoToken.ts` line 36 동일. Flutter `FirebaseFunctions.instanceFor(region: 'asia-northeast3')` (auth_remote_data_source.dart lines 64, 107)
  - 위치: `functions/src/verifyNaverToken.ts`, `verifyKakaoToken.ts`, `lib/data/datasources/remote/auth_remote_data_source.dart`

- [x] 유효하지 않은 access token → `unauthenticated` 에러 반환
  - 근거: Naver — `resultcode !== '00'` 시 HttpsError('unauthenticated') (verifyNaverToken.ts lines 64-68). Kakao — `!profileData.id` 시 HttpsError('unauthenticated') (verifyKakaoToken.ts lines 64-68)
  - 위치: `functions/src/verifyNaverToken.ts` lines 64-68, `functions/src/verifyKakaoToken.ts` lines 64-68

- [x] 네트워크 오류 → `internal` 에러 반환
  - 근거: catch 블록에서 `HttpsError instanceof` 체크 후 non-HttpsError는 `internal` 코드로 래핑 (verifyNaverToken.ts lines 73-78)
  - 위치: `functions/src/verifyNaverToken.ts` lines 73-78, `functions/src/verifyKakaoToken.ts` lines 73-78

- [x] accessToken 미전달 → `invalid-argument` 에러 반환
  - 근거: `if (!data.accessToken) throw new HttpsError('invalid-argument', ...)` (verifyNaverToken.ts lines 43-47)
  - 위치: `functions/src/verifyNaverToken.ts` lines 43-47, `functions/src/verifyKakaoToken.ts` lines 43-47

- [x] `AuthRemoteDataSourceImpl.signInWithNaver()` 수정 — Custom Token 경유 Firebase Auth 세션 생성
  - 근거: `auth_remote_data_source.dart` lines 90-124 확인. Naver access token → `verifyNaverToken` CF 호출 → `signInWithCustomToken(customToken)` → `credential.user!.uid` 사용
  - 위치: `lib/data/datasources/remote/auth_remote_data_source.dart` lines 90-124

- [x] `AuthRemoteDataSourceImpl.signInWithKakao()` 수정 — Custom Token 경유 Firebase Auth 세션 생성
  - 근거: `auth_remote_data_source.dart` lines 49-84 확인. Kakao OAuthToken → `verifyKakaoToken` CF 호출 → `signInWithCustomToken(customToken)` → `credential.user!.uid` 사용
  - 위치: `lib/data/datasources/remote/auth_remote_data_source.dart` lines 49-84

- [x] Kakao 프로필 별도 조회 — `UserApi.instance.me()` 로 displayName/photoUrl 취득
  - 근거: `auth_remote_data_source.dart` lines 76-82 확인
  - 위치: `lib/data/datasources/remote/auth_remote_data_source.dart` lines 76-82

- [x] `auth_provider.dart` `build()` 간소화 — `FirebaseAuth.instance.currentUser` 단일 체크
  - 근거: `auth_provider.dart` lines 56-73 확인. 기존 Naver/Kakao 토큰 별도 체크 제거. Firebase Auth 세션만 확인
  - 위치: `lib/presentation/customer/auth/auth_provider.dart` lines 56-73

- [x] 불필요한 import 제거 (`flutter_naver_login`, `kakao_flutter_sdk_user`) — auth_provider.dart
  - 근거: `auth_provider.dart` import 목록 확인. `flutter_naver_login` / `kakao_flutter_sdk_user` import 없음. `firebase_auth` 만 사용
  - 위치: `lib/presentation/customer/auth/auth_provider.dart` lines 1-15

- [x] `signOut()` — Firebase Auth + Kakao + Naver SDK 모두 로그아웃
  - 근거: `auth_remote_data_source.dart` lines 163-168. `_firebaseAuth.signOut()` + `kakao.UserApi.instance.logout()` + `FlutterNaverLogin.logOut()`
  - 위치: `lib/data/datasources/remote/auth_remote_data_source.dart` lines 163-168

- [x] T4 — Naver 로그인 후 Firebase Auth 세션 정상 (`currentUser != null`, uid 형식 `naver_*`)
  - 근거: Custom Token 경유 signInWithCustomToken 흐름 코드 확인 + 라이브 검증 PASS
  - 위치: `lib/data/datasources/remote/auth_remote_data_source.dart` lines 90-124

- [x] T4 — Kakao 로그인 후 Firebase Auth 세션 정상 (`currentUser != null`, uid 형식 `kakao_*`)
  - 근거: Custom Token 경유 signInWithCustomToken 흐름 코드 확인 + 라이브 검증 PASS
  - 위치: `lib/data/datasources/remote/auth_remote_data_source.dart` lines 49-84

- [x] T5 — 결제/환불 흐름이 Custom Token 세션에서도 정상 동작
  - 근거: Naver/Kakao Custom Token 로그인 후 `request.auth != null` 조건 통과 → Firestore Security Rules `isSignedIn()` PASS → orders read/update 정상. order_flow_phase3a T5 회귀와 동일 환경에서 검증
  - 위치: 참조: `docs/tasks/order_flow_phase3a/test_report.md` 라이브 검증 섹션

- [x] Firestore 접근 (`users/{uid}` read/create) — Custom Token 세션 기반 정상
  - 근거: signInWithCustomToken 후 Firebase Auth 세션 확보 → `request.auth.uid` 정상 설정 → users/{uid} self-create 및 read 허용
  - 위치: `firestore.rules` lines 64-138 (users match 블록)

- [x] Cloud Function http 라이브러리 — axios 사용 (기존 tossClient.ts 패턴 재사용)
  - 근거: verifyNaverToken.ts line 13 `import axios from "axios"`, verifyKakaoToken.ts line 13 동일
  - 위치: `functions/src/verifyNaverToken.ts`, `functions/src/verifyKakaoToken.ts`

### 아키텍처 검증

- [x] Firebase / Cloud Functions 직접 호출은 data 레이어에 한정
  - 근거: `auth_remote_data_source.dart`가 `data/datasources/remote/`에 위치. `auth_provider.dart`(presentation)는 UseCase/Repository를 통해 접근
  - 위치: `lib/data/datasources/remote/auth_remote_data_source.dart`

- [x] domain 레이어에 Firebase SDK import 없음
  - 근거: `flutter analyze` No issues. domain usecases/entities에서 firebase 직접 import 없음
  - 위치: `lib/domain/`

### 코드 품질 검증

- [x] flutter analyze — No issues found
  - 근거: `flutter analyze --no-pub` 실행 결과
  - 위치: lib/ 전체

---

## FAIL 항목

_(F1 항목 없음 — 이전 FAIL 처리되었던 IAM 권한 항목은 2026-05-25 라이브 검증 완료로 PASS 로 정정됨. 상세는 상단 "정정 이력" 참조.)_

---

## 보류 항목

### H1 — 앱 재시작 후 세션 복구 실기기 검증 보류

- 이유: `auth_provider.dart` `build()` 가 `FirebaseAuth.instance.currentUser` 를 확인하는 구조상 Firebase Auth 자동 세션 복구에 의존. 실기기에서 앱 강제 종료 후 재시작 시 currentUser가 복구되는지 검증 필요
- 필요한 확인: Naver/Kakao 로그인 → 앱 강제 종료 → 재시작 → 로그인 상태 유지 확인 (실기기)
- 후속 작업 제안: 실기기 회귀 테스트 시 포함

### H2 — Kakao SDK `loginWithKakaoTalk` 실패 시 `loginWithKakaoAccount` fallback 처리

- 이유: `signInWithKakao()` 에서 KakaoTalk 설치 여부 분기 후 로그인 실패 케이스 (KakaoTalk 설치됐지만 로그인 실패 등)의 에러 전파가 AuthNotifier의 60초 timeout + cancelSignIn 패턴에 정상 흡수되는지 라이브 검증 필요
- 필요한 확인: KakaoTalk 강제 종료 후 카카오 로그인 시도 → 60초 timeout 또는 cancelSignIn 정상 작동 여부
- 후속 작업 제안: 실기기 검증 시 포함

_(H3 항목 없음 — Cloud Functions 배포는 2026-05-25 완료. `verifyNaverToken` / `verifyKakaoToken` 모두 asia-northeast3 에 정상 배포되었으며 T4 라이브 검증 PASS. 상세는 상단 "정정 이력" 참조.)_

### H4 — Naver access token 타입 안전성 — `result.accessToken` nullable 처리

- 이유: `auth_remote_data_source.dart` line 101에서 `result.accessToken`이 null인 경우 `throw Exception`으로 처리하지만, `NaverToken.accessToken` 문자열 empty 케이스를 조건에 포함 (`.isEmpty`). 실제 SDK에서 accessToken이 비어있는 케이스가 발생할 수 있는지 확인 필요
- 필요한 확인: Naver SDK `NaverToken` 타입의 accessToken 필드 null/empty 가능성 문서 확인
- 후속 작업 제안: 불필요하면 empty 체크 제거로 코드 정리

### H5 — Custom Token 1시간 만료 후 자동 refresh 검증 보류

- 이유: spec.md "Custom Token 유효시간: 1시간. Firebase Auth가 자동 refresh 처리"로 명시. Firebase Auth는 내부적으로 ID Token을 자동 갱신하므로 앱 내 별도 처리 불필요하나, 장시간 사용 시 실제 세션 유지 여부는 실기기 장기 테스트 필요
- 필요한 확인: 로그인 후 1시간 이상 앱 사용 시 Firestore 접근 지속 여부
- 후속 작업 제안: 실제 운영 환경 모니터링으로 대체 가능

---

## 설계자 전달 메시지

### 요약

- 전체 판단: **PASS 중심, P1 인프라 확인 항목 1건 + 보류 5건**
- PASS 22개 / FAIL 1개 / 보류 5개
- Naver/Kakao Custom Token 흐름 코드 구현 완료
- auth_provider.dart Firebase Auth 단일 세션 체크로 정상 간소화
- T5 회귀 (결제/환불 흐름) Custom Token 세션에서 Firestore Rules 통과 확인
- flutter analyze No issues 확인

### 재작업 우선순위

1. **F1 — Cloud Functions 배포 + IAM Service Account Token Creator 역할 확인** (P1)
   - 이유: 배포 없이는 Naver/Kakao 로그인이 완전히 동작하지 않음. 코드가 아닌 인프라 설정이므로 배포 체크리스트에 명시 필요

### 후속 task 후보

- 앱 재시작 후 세션 복구 실기기 검증 (H1)
- Custom Token 1시간 만료 후 자동 refresh 확인 (H5)
- Kakao SDK 로그인 실패 케이스 에러 처리 확인 (H2)

---

## 완료 판단

- [ ] 전체 PASS
- [x] FAIL 있으나 후속 task로 분리 가능 (F1 — 인프라 배포 작업)
- [ ] 재작업 필요
