# fcm_token_refresh_sync 테스트 리포트

검증 범위: 코드/정적/단위. 실기기는 백로그 배치 실테스트로 이월.

## 결과: PASS 8 / FAIL 0 / 보류 1

| # | 항목 | 결과 |
|---|---|---|
| 1 | build() 에서 pushNotificationRepositoryProvider.onTokenRefresh().listen + ref.onDispose(cancel) | PASS |
| 2 | uid 를 이벤트마다 `state.asData?.value?.uid` 로 읽음(캡처 없음), null 이면 return | PASS |
| 3 | registerFcmTokenUseCaseProvider.call(uid) 재사용, 신규 use case 없음, try/catch + onError silent | PASS |
| 4 | presentation 에 firebase_messaging 직접 import 없음 (repository 경유) | PASS |
| 5 | 로그아웃 AsyncLoading 구간 토큰은 uid null 로 걸러짐 / build 재호출 시 onDispose 로 중복·누수 없음 (코드 리뷰) | PASS |
| 6 | 범위: lib 변경은 auth_provider.dart 단일 파일 +18/-0, 포맷 노이즈 없음 | PASS |
| 7 | Clean Architecture 준수, AppColors 무관 | PASS |
| 8 | flutter analyze: No issues / flutter test: 921 전체 통과 | PASS |
| 9 | onTokenRefresh 발화 → register 호출 / 미로그인 무시 단위 테스트 | 보류 (기존 테스트 없음, 필수 아님) |

## 우선 수정 FAIL
없음.

## 후속 후보
- 단위 테스트: onTokenRefresh StreamController 주입 Fake + register UseCase Fake 로 "로그인 시 발화 → call(uid) / 미로그인·AsyncLoading 무시 / invalidate 후 구독 1개" 검증.
- 실기기 배치 테스트: 토큰 로테이션 갱신, 로그아웃 직후 fcmToken 부활 없음, 권한 거부 skip, getToken null 후 치유.
