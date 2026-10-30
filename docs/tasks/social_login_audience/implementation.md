# social_login_audience 구현 기록

## 수정/신설 파일
| 파일 | 내용 |
|---|---|
| `functions/src/verifyKakaoToken.ts` | `defineString("KAKAO_APP_ID")` + `kapi.kakao.com/v1/user/access_token_info` 로 `app_id` 대조, 불일치/조회실패 시 `unauthenticated`. 이후 `v2/user/me` -> `kakao_<id>` 불변 |
| `functions/src/verifyNaverToken.ts` | 입력 `{code,state,redirect_uri}` 로 재설계. `NAVER_ALLOWED_REDIRECT_URIS`(defineString, 콤마구분) 정확일치 검증 -> `nid.naver.com/oauth2.0/token` 교환(`NAVER_CLIENT_ID` defineString, `NAVER_CLIENT_SECRET` defineSecret + `secrets:[]`) -> `nid/me` -> `naver_<id>` 불변. 구 `{accessToken}` 은 invalid-argument (dual-accept 없음) |
| `functions/.env.example` | placeholder 만 추가 (KAKAO_APP_ID / NAVER_CLIENT_ID / NAVER_ALLOWED_REDIRECT_URIS) |
| `lib/data/datasources/remote/auth_remote_data_source.dart` | 네이버 흐름을 flutter_web_auth_2 Authorization Code flow 로 교체. state=Random.secure 32byte, 반환 state 불일치 시 throw, `NAVER_CLIENT_ID` 는 `String.fromEnvironment`. 시그니처 불변. 네이버 SDK `logOut` 호출 제거 |
| `lib/presentation/customer/auth/auth_provider.dart` | `signInWithNaver` 에 카카오와 동일한 timeout 안전망(120초) 추가 (spec 에러처리 표). 그 외 presentation/domain 불변 |
| `landing/auth/naver.html` (신설) | `?code&state` 를 `qradar://auth/naver?...` 로 즉시 bounce. firebase.json 무수정 |
| `android/app/src/main/AndroidManifest.xml` | `com.linusu.flutter_web_auth_2.CallbackActivity` 추가 (scheme `qradar`, host `auth`, path `/naver`). 네이버 SDK meta-data 3개 + `com.nhn.android.search` queries 제거 |
| `android/app/src/main/res/values/strings.xml` | 삭제 (네이버 문자열뿐이었음, client_secret 평문 제거) |
| `ios/Runner/Info.plist` | `NidClientID/NidClientSecret/NidAppName/NidUrlScheme`, `naversearchapp/naversearchthirdlogin` 제거. `qradar` 스킴은 기존 등록 재사용(ASWebAuthenticationSession) |
| `pubspec.yaml` / `pubspec.lock` | `flutter_naver_login` 제거, `flutter_web_auth_2: ^5.1.0` 추가. (crypto 불필요: `Random.secure` + base64Url) |
| linux/macos/windows generated plugin 파일 | `flutter pub add` 가 자동 갱신 (수동 수정 아님) |

## 네이버 OAuth 파라미터 확인
네이버 공식 token 엔드포인트 파라미터는 `grant_type, client_id, client_secret, code, state` (redirect_uri 는 받지 않음; 지식 기준 — 샌드박스에서 문서 재조회는 못 했으니 배포 후 실테스트로 확인 권장). 따라서 redirect_uri 는 token 요청에 보내지 않고 **서버 화이트리스트 대조에만** 사용한다. 실패도 HTTP 200 + `{error}` 로 올 수 있어 `access_token` 부재로 판정. code 는 1회용/단기(수분).

## 환경값
- 앱: `NAVER_CLIENT_ID` 는 `env.json` (`--dart-define-from-file=env.json`). redirect_uri 는 공개 상수(`https://order-app-5957e.web.app/auth/naver.html`)로 코드에 둠 (비밀 아님, 화이트리스트 값과 동일해야 함). 비어 있으면 명시적 예외.
- functions: 실값은 gitignored `.env.order-app-5957e` (주입 완료). 실값은 어떤 문서에도 기록하지 않음.

## 확인 필요 / 주의
- Android 의 `qradar` 스킴 필터가 MainActivity(스킴만)와 CallbackActivity(host=auth, path=/naver) 두 곳에 존재. Android 는 일치도가 높은(더 구체적인) 필터를 우선하므로 Toss/KakaoPay 콜백은 MainActivity, 네이버는 CallbackActivity 로 가야 한다. **실기기에서 Toss 복귀와 네이버 복귀 모두 확인 필요.**
- 네이버 이름/이메일/프로필 이미지는 더 이상 UserModel 에 채워지지 않음(커스텀 토큰 세션 값 사용, 보통 null). 표시가 필요하면 후속(nid/me 프로필을 CF 응답에 포함).
- iOS `pod install` 필요 (플러그인 교체).

## 테스트 포인트
1. 카카오: 정상 로그인 `kakao_<id>` 동일 uid / 타앱 토큰 거절 (functions 로그에 REJECTED audience mismatch).
2. 네이버: 웹 인증 시트 -> 승인 -> 앱 복귀 -> `naver_<id>` 동일 uid. 시트 취소 시 무한 로딩 없음.
3. 거절: 구 `{accessToken}` 호출, 화이트리스트 밖 redirect_uri, state 불일치(클라 throw).
4. grep: `NidClientSecret`/`naver_client_secret` 이 repo(앱 산출물)에 없는지. (docs/spec 에는 이력으로 남아 있음)
5. domain/presentation 이 flutter_web_auth_2 를 import 하지 않음.
6. Android/iOS Toss, KakaoPay 딥링크 복귀 회귀.

## 배포 순서 (사용자 실행)
1. Secret 주입 (functions 디렉터리): `cd /Users/Byeonguk/Developer/OrderApp/functions && firebase functions:secrets:set NAVER_CLIENT_SECRET`
2. 함수 배포 (프로젝트 루트): `cd /Users/Byeonguk/Developer/OrderApp && firebase deploy --only functions:verifyNaverToken,functions:verifyKakaoToken`
3. 중계 페이지 배포 (landing 규칙: hosting 만): `cd /Users/Byeonguk/Developer/OrderApp && firebase deploy --only hosting`
4. 중계 페이지 확인: 브라우저에서 `https://order-app-5957e.web.app/auth/naver.html?code=a&state=b` 접속 시 앱 스킴 이동 시도.
5. 앱 재빌드: `cd /Users/Byeonguk/Developer/OrderApp && flutter pub get && (cd ios && pod install) && flutter run --dart-define-from-file=env.json -d <device-id>`

## 검증 결과
- `flutter analyze`: No issues found.
- `cd functions && npm run build` (tsc): 에러 없음.

## 미구현/보류
- 웹 세션 네이버 구현(spec §12, 비범위), App Check, 거절 이력 영구 보존(비범위).
- 네이버 프로필(이름/이메일/이미지) 반영 — 위 주의 참조.
- 카카오 웹 플랫폼 추가 등 콘솔 작업은 사용자 몫(spec §11-2).
