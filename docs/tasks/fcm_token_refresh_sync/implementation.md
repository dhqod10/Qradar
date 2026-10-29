# fcm_token_refresh_sync 구현 결과

## 수정 지점
- `lib/presentation/customer/auth/auth_provider.dart` — `AuthNotifier.build()` 만 수정 (+18줄, 구독 추가분만). 신규 파일/Domain/Data/main.dart/Rules/CF 변경 없음.

## 구현 내용
- `ref.read(pushNotificationRepositoryProvider).onTokenRefresh().listen(...)` 구독 (FirebaseMessaging 직접 import 없음, repository 경유).
- 콜백: 이벤트마다 `state.asData?.value?.uid` 를 읽음 (캡처 없음). null(미로그인/AsyncLoading/로그아웃 중)이면 return. 있으면 `registerFcmTokenUseCaseProvider.call(uid)` 재사용 (신규 use case 없음). try/catch + onError 로 silent 처리.
- 로그아웃 레이스: signOut() 이 먼저 `AsyncLoading` 으로 바꾸므로 그 사이 도착한 토큰은 uid null 로 걸러짐. signOut 로직 미변경.

## 구독 생명주기
- `ref.onDispose(tokenRefreshSub.cancel)` 로 취소 등록. build 가 재실행/Provider 폐기되면 이전 구독이 취소된 뒤 새로 구독되므로 중복/누수 없음. (build 는 로컬 변수로 구독, 필드 불필요.)
- dart format 미실행, 수동 들여쓰기만.

## flutter analyze
- auth_provider.dart: No issues found.

## 테스트 포인트
1. 로그인 상태에서 토큰 로테이션(재설치/`deleteToken` 후 재발급) 시 `users/{uid}.fcmToken`, `fcmTokenUpdatedAt` 갱신.
2. 로그아웃 직후 `deleteToken()` 유발 재발급 토큰이 fcmToken 을 되살리지 않음 (null 유지).
3. 미로그인 상태 토큰 이벤트 무시 (Firestore write 없음).
4. 알림 권한 거부 사용자: 토큰 이벤트가 와도 register 의 권한 게이팅으로 skip.
5. 로그인 직후 getToken()==null 케이스가 이후 onTokenRefresh 발화로 치유되는지.
6. authProvider invalidate 후 구독 1개만 유지되는지.
