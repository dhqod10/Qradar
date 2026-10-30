# social_login_audience — Test Report

검증일: 2026-10-30 / 기준: spec.md(플랜 B), implementation.md, 실제 코드 (정적 검증 + 실기기 결과 기록)

## 결과 요약

| 구분 | PASS | FAIL | 보류 |
|---|---|---|---|
| 정적 검증 (7항목) | 7 | 0 | 0 |
| 실기기 | iOS 3 | 0 | Android 2 |
| 보안 후속 (신규) | - | - | 1 (권고) |

FAIL 0건.

## 정적 검증

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 1 | CF verifyKakaoToken | PASS | `access_token_info` 로 app_id 조회 후 `KAKAO_APP_ID`(defineString) 와 String 비교, 불일치/조회 실패 모두 `unauthenticated` 거절, KAKAO_APP_ID 미설정 시 internal. uid `kakao_<id>` 불변. |
| 2 | CF verifyNaverToken | PASS | 입력 `{code,state,redirect_uri}` 필수 검증, 구 `{accessToken}` 계약은 invalid-argument 로 거절(dual-accept 없음). `NAVER_ALLOWED_REDIRECT_URIS` 정확 일치 화이트리스트. 토큰 교환 파라미터 `grant_type,client_id,client_secret,code,state` (redirect_uri 미전송). client_secret 은 `defineSecret` 서버 전용. 200+error 응답 처리. uid `naver_<id>` 불변. |
| 3 | 앱 auth_remote_data_source | PASS | `Random.secure` 32바이트 state, `FlutterWebAuth2.authenticate(callbackUrlScheme:'qradar')`, 콜백 state 불일치/error/code 누락 시 예외, redirect_uri=`https://order-app-5957e.web.app/auth/naver.html`, `signInWithNaver()` 시그니처 불변. NAVER_CLIENT_ID 는 `String.fromEnvironment`. landing/auth/naver.html 은 code/state 를 qradar://auth/naver 로 bounce 만 하며 저장/전송 없음. |
| 4 | 절대규칙 (레이어) | PASS | `flutter_web_auth_2` import 는 `lib/data/datasources/remote/auth_remote_data_source.dart` 1곳뿐. presentation/domain 누출 없음. `auth_provider.dart` 의 네이버 120초 timeout 안전망은 SDK import 없는 허용 변경으로 확인. |
| 5 | 하드코딩 금지 | PASS | 커밋 추적 파일 grep 에서 secret/client_id/app_id 실값 없음. `functions/.env.example` 은 `KAKAO_APP_ID=`, `NAVER_CLIENT_ID=` 빈값 + 예시 URL placeholder, secret 은 안내 주석만. |
| 6 | 네이티브 잔여참조 | PASS | `NidThirdPartyLogin`/`com.naver.sdk.*`/`com.nhn.android.search` 는 코드에 없음(SceneDelegate 주석 언급만). SceneDelegate 는 Google 핸들러만 유지. Manifest 에 flutter_web_auth_2 CallbackActivity(qradar://auth/naver, host/path 분리) 추가, `@string/naver_*` 참조 잔존 없음. |
| 7 | 빌드 | PASS | `flutter analyze`: No issues found. `functions npm run build` (tsc): 에러 없음. |

## 실기기 검증 (기록)

| 플랫폼 | 항목 | 결과 |
|---|---|---|
| iOS | 카카오 로그인 (서버 app_id 통과 + Firebase 로그인) | PASS |
| iOS | 네이버 로그인 (code-exchange 성공). Firebase Auth Users 에 `kakao_4831227666`, `naver_mIyISn…` 생성 확인 | PASS |
| iOS | Toss 결제 후 주문상세 복귀 (딥링크 충돌 없음) | PASS |
| Android | 설치 (에뮬레이터 저장공간 확보 후 성공) | PASS |
| Android | 로그인(카카오/네이버) / 결제 딥링크 충돌 | 보류 (사용자 테스트 중단) |

## 운영 수정 이력

1. 네이버 secret 중복 입력(secrets:set 시 값이 두 번 이어붙어 저장됨) → 재설정 + 재배포로 해결.
2. iOS SceneDelegate 의 `NidThirdPartyLogin` import 잔여 → 제거 (재확인 완료, 잔여 없음).

## 보류 / 후속

1. **(권고, 보안) 네이버 client_secret 회전**: 삭제된 `android/app/src/main/res/values/strings.xml` 은 HEAD 에 커밋되어 있고 `naver_client_secret` 실값이 포함돼 있다. 현재 워킹트리에서는 삭제(미커밋)됐지만 git history(8c3e803)에 남는다. 삭제 커밋 후에도 이력에 존재하므로 네이버 콘솔에서 secret 재발급 후 `NAVER_CLIENT_SECRET` 재설정/재배포를 권장한다. 저장소가 공개/공유되었다면 우선순위 높음.
2. Android 로그인 및 qradar 스킴 딥링크 충돌 실기기 검증 (MainActivity 의 Toss/KakaoPay 스킴과 CallbackActivity 가 host/path 로 분리돼 정적으로는 문제 없음, 실측 필요).
3. 카카오/네이버 로그인 후 프로필(email/name) null — CF 가 프로필을 반환하지 않음. 후속 후보.
4. `order_item_row.dart` 가 raw `Image.network` + image_not_supported 플레이스홀더 사용 → 앱 표준(CachedNetworkImage + 공통 플레이스홀더)과 불일치. UI polish 후속 (본 기능 범위 밖).
5. 미커밋 변경(`.firebase/`, `.firebaserc`, `landing/auth/`, `docs/tasks/social_login_audience/`)은 landing 배포 규칙(hosting 만, `git add landing/` 만)에 맞춰 정리 필요.

## 우선순위

FAIL 없음. 가장 먼저 처리할 것: 보류 1(secret 회전 검토) -> 보류 2(Android 실기기).
