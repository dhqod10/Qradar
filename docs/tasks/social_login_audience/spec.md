# social_login_audience 기능 명세

> 웹 인계 #1 — 카카오/네이버 소셜 로그인 커스텀 토큰 발급 시 **audience(우리 앱 전용성) 미검증** 보안 결함 수정.
> 출처: `docs/backlog.md` "웹 세션 인계 … 1. 카카오/네이버 토큰 audience" + "📌 계약 확정".
> 확정 방향: 사용자·웹세션 합의 **ⓐ** (아래 §1).

---

## 개요

- **목적**: `verifyKakaoToken` / `verifyNaverToken` Cloud Function 이 외부 토큰을 **우리 앱이 발급받은 것인지 검증하지 않고** Firebase 커스텀 토큰을 발급하는 구멍을 막는다. 현재는 "유효한 카카오/네이버 토큰" 이기만 하면, **다른 앱용으로 발급된 토큰**으로도 우리 서비스의 커스텀 토큰(= 세션)을 획득할 수 있다(토큰 혼동 / audience confusion).
- **작업 유형**: 기존 기능 수정 (보안 하드닝) + 네이버 인증 흐름 재설계.
- **영향 범위**:
  - 화면: 없음(로그인 버튼·화면 불변). 네이버만 **외부 로그인 화면의 표현이 바뀜**(네이버 SDK 네이티브 화면 → OS 제공 웹 인증 시트). §작업 분배/designer 참조.
  - Domain: **변경 없음** (`AuthRepository.signInWithNaver()` / `SignInWithNaverUseCase` 시그니처 유지).
  - Data: `auth_remote_data_source.dart` 의 **네이버 흐름만** 교체. 카카오·구글·이메일 불변.
  - Presentation: **변경 없음** (`auth_provider.dart` 의 loading/cancel 안전망 재사용. 아래 §에러처리 참조).
  - Cloud Functions: `verifyKakaoToken`(검증 추가) / `verifyNaverToken`(입력 계약 재설계).
  - 공통 컴포넌트: 없음.
  - 라우팅: 없음.
  - 권한 / 환경 설정:
    - functions 환경값 신설 — Naver `client_secret`(**Secret**), Naver `client_id`, Kakao `app_id`, Naver redirect_uri 화이트리스트.
    - **Android `strings.xml` / iOS `Info.plist` 에서 Naver `client_secret` 제거**(아래 §9 — 현재 앱에 평문 노출 중인 비밀).
    - Android `AndroidManifest.xml` / iOS `Info.plist` 에 네이버 code-flow redirect 콜백 등록.
    - 네이버/카카오 개발자 콘솔 설정(§11 체크리스트).
  - Firestore Rules: **무관**(이 작업은 Rules 를 건드리지 않는다). CF 는 커스텀 토큰만 발급하며 `users` 문서 생성은 기존 클라이언트 경로 그대로.
- **비범위** (§7):
  - 다중 provider 계정 통합(`kakao_*` / `naver_*` / email uid 병합) — `backlog.md` "다중 인증 제공자 계정 통합", 별도 task.
  - App Check 로 callable 남용 방어 — **후속 별도 task**(§8).
  - 구글/이메일 로그인 흐름 — 변경 없음.
  - 인증 거절 이력의 Firestore 영구 보존(`authRejections` 류) — §6 에서 사유와 함께 비범위로 명시.

---

## 1. 확정 방향 (ⓐ — 그대로 설계)

| provider | 방식 | 클라이언트 변경 |
|---|---|---|
| **카카오** | **서버만 수정.** `verifyKakaoToken` 이 `https://kapi.kakao.com/v1/user/access_token_info` 로 토큰의 `app_id`(audience)를 **우리 앱 app_id 와 대조**. 클라는 access token 을 그대로 전송(현행 유지). | **0** |
| **네이버** | **앱·웹 양쪽 Authorization Code Exchange 로 통일.** 토큰 방식 폐기. 클라는 **인증 코드**를 CF 에 전달, CF 가 server-side 로 `client_id + client_secret` 교환 → 프로필 → 커스텀 토큰. code 가 우리 앱 전용이라 audience 가 **구조적으로** 보장된다. | 있음(흐름 교체) |

### 왜 네이버는 흐름을 통째로 바꾸나 (설계 근거)

- 토큰 방식은 "토큰 발급처가 우리 앱인가" 를 **서버가 사후 검증**해야 한다. 네이버는 카카오의 `access_token_info` 같은 **audience(app_id) 조회 API 가 없다** → 토큰만으로는 audience 를 증명할 방법이 마땅치 않다.
- Authorization Code flow 는 `code → token` 교환에 **우리만 가진 `client_secret`** 이 필요하므로, 교환 성공 자체가 "우리 앱 전용" 을 증명한다. audience 가 사후 검증이 아니라 **구조로** 보장된다.
- **부수 보안 이득(중요)**: 현재 네이버 `client_secret` 이 **Android `strings.xml`(L5, 값 `<redacted/rotated>`) 과 iOS `Info.plist`(`NidClientSecret`) 에 평문 임베드**되어 있다 — APK/IPA 에서 추출 가능한 노출된 비밀이다. code-exchange 로 가면 `client_secret` 이 **서버로만** 이동하고 앱에서 사라진다. (code flow 에서 클라는 `client_id` 만 필요하다.)
- Authorization Code flow 가 모바일 OAuth 현대 표준 → **두 번 고치지 않으려고** 앱·웹 통일(ⓐ).

---

## 2. 현재 코드 사실 (조사 완료)

| 파일 | 현재 동작 | 문제 |
|---|---|---|
| `functions/src/verifyKakaoToken.ts` | access token → `kapi.kakao.com/v2/user/me` → `id` → `createCustomToken('kakao_'+id)` | **app_id(audience) 검증 없음.** 타앱 토큰으로도 통과 |
| `functions/src/verifyNaverToken.ts` | `{accessToken}` → `openapi.naver.com/v1/nid/me` → `id` → `createCustomToken('naver_'+id)` | 같은 audience 미검증 |
| `lib/data/datasources/remote/auth_remote_data_source.dart` | 네이버: `flutter_naver_login`(pubspec `^2.1.0`) SDK → `FlutterNaverLogin.logIn()` + `getCurrentAccessToken()` → **access token** 을 `verifyNaverToken` 에 전달 | code 가 아니라 **토큰**. code-exchange 로 가려면 이 흐름을 Authorization Code 흐름으로 교체 |
| 〃 (카카오) | `kakao_flutter_sdk_user ^1.9.1`, access token 전송 | **유지** (클라 변경 0) |
| `android/.../strings.xml` L4~6 / `ios/Runner/Info.plist` L49~56 | `naver_client_id` / `naver_client_secret`(평문) / `naver_client_name` | **client_secret 평문 노출** → 제거 대상 |

- CF 는 모두 `onCall`, `asia-northeast3`.
- uid 유도: `kakao_<id>` / `naver_<id>` — **불변**(계정 동일성 유지, §5).
- 기존 Secret 주입 패턴 확인됨: `defineSecret("TOSS_SECRET_KEY")` + `secrets: [...]`(`functions/src/verifyTossPayment.ts`, `tossClient.ts`). 비밀 아닌 설정값은 `defineString(...)`(예: `PAYMENT_GATE_MODE`). **이 패턴을 그대로 재사용한다.**

---

## 3. 환경값 / 비밀 설계 (CLAUDE.md 절대규칙 4 — 하드코딩 금지)

| 키 | 종류 | 용도 | 주입 방법 |
|---|---|---|---|
| `NAVER_CLIENT_SECRET` | **Secret** (`defineSecret`) | 네이버 code→token 교환 | `firebase functions:secrets:set NAVER_CLIENT_SECRET` |
| `NAVER_CLIENT_ID` | `defineString` | 네이버 code→token 교환 (비밀 아님, 앱에도 노출되는 값) | `.env`(functions) 또는 파라미터 기본값 |
| `NAVER_ALLOWED_REDIRECT_URIS` | `defineString` | 클라가 보낸 `redirect_uri` 화이트리스트(콤마 구분) | 〃 |
| `KAKAO_APP_ID` | `defineString` | 카카오 `access_token_info` 의 `app_id` 대조 대상 | 〃 |

- `NAVER_CLIENT_ID` / `NAVER_ALLOWED_REDIRECT_URIS` / `KAKAO_APP_ID` 는 비밀이 아니므로 Secret 까지 쓸 필요는 없으나, **코드 하드코딩은 금지**(절대규칙 4) → `defineString` + functions `.env` 로 주입한다.
- ⚠️ **`KAKAO_APP_ID` 는 앱의 네이티브 키(`f55c641ec30d25ae3c5f426305cc7a9a`)가 아니라, 카카오 콘솔의 숫자형 `앱 ID`** 다 (access_token_info 응답의 `app_id` 와 같은 숫자). §11 체크리스트에서 혼동 주의.

---

## 4. 레이어 설계

### 4-A. Cloud Functions (data 바깥의 서버. Firebase Admin SDK 직접 사용 — 규칙상 CF 는 허용)

#### `verifyKakaoToken` — 검증 1단계 추가 (uid 유도 불변)

```
입력: { accessToken }                         ← 불변
흐름:
  1. accessToken 필수 검증 (현행)
  2. [신설] GET https://kapi.kakao.com/v1/user/access_token_info
       Authorization: Bearer <accessToken>
       → { id, expires_in, app_id }
     app_id(number) !== KAKAO_APP_ID  ⇒  HttpsError('unauthenticated', ...)  거절
  3. (기존) kapi.kakao.com/v2/user/me 로 프로필·id 확인
       ※ access_token_info 의 id 와 me 의 id 가 같은 사용자이므로,
         호출 횟수를 줄이려면 access_token_info 의 id 를 uid 유도에 바로 써도 된다(개발자 재량, 아래 주).
  4. createCustomToken('kakao_' + id, { provider: 'kakao' })   ← 불변
```

> 주: `access_token_info` 응답에 `id` 가 포함되므로 `user/me` 호출을 **합쳐 1회로 줄일 수 있다**. 단 프로필(email/nickname/image)은 클라가 Kakao SDK 로 직접 조회해 `UserModel` 을 채우므로(현행 `signInWithKakao`), CF 는 **uid 유도에 필요한 id 만** 확정하면 된다. 개발자가 호출 수 최소화 방향으로 정리하되 **uid 결과는 `kakao_<id>` 로 동일**해야 한다.

#### `verifyNaverToken` — 입력 계약 재설계 (토큰 → 코드)

```
입력(신):  { code: string, state: string, redirect_uri: string }
           ※ 구 { accessToken } 계약 폐기 (§다. 롤아웃)
흐름:
  1. code / redirect_uri 필수 검증. 없으면 HttpsError('invalid-argument')
  2. [보안] redirect_uri 가 NAVER_ALLOWED_REDIRECT_URIS 화이트리스트에
     정확히 일치하지 않으면 HttpsError('invalid-argument') 거절
       → 클라가 보낸 redirect_uri 를 그대로 신뢰하지 않는다(오픈 리다이렉트 방지, 웹세션 권고)
  3. POST https://nid.naver.com/oauth2.0/token
       grant_type=authorization_code
       client_id=NAVER_CLIENT_ID
       client_secret=NAVER_CLIENT_SECRET   ← 서버에서만
       code=<code>
       state=<state>
     → { access_token }  (교환 성공 = 우리 앱 전용 증명)
  4. GET https://openapi.naver.com/v1/nid/me  (Bearer access_token)
       → response.id  (resultcode '00' 검증, 현행 로직 유지)
  5. createCustomToken('naver_' + id, { provider: 'naver' })   ← 불변
```

> ✅ **검증 완료(2026-10-30)**: 네이버 `oauth2.0/token` 발급 요청은 `grant_type=authorization_code, client_id, client_secret, code, state` **5개만** 보낸다. **`redirect_uri` 는 token 요청에 보내지 않는다**(authorize 단계에서만 사용 — 카카오와 다른 네이버 특유 동작). 따라서 우리 설계의 `redirect_uri` 화이트리스트 대조는 token 요청 파라미터가 아니라 **클라가 보낸 값 검증(오픈리다이렉트 방지)** 용도로만 쓴다. 구현(verifyNaverToken.ts)이 이대로 되어 있음. `code → access_token → 프로필 → uid`, "client_secret 은 서버에서만" 불변 계약 유지. (네이버는 PKCE 미지원 — 아래 주.)
> **PKCE 주**: 네이버 OAuth 는 PKCE 를 지원하지 않는다. audience 보증은 **서버 보관 `client_secret` + `state`(CSRF) + `redirect_uri` 화이트리스트** 조합으로 달성한다. "PKCE 가능하면" 은 네이버에서는 해당 없음.

### 4-B. Data 레이어 (`auth_remote_data_source.dart` — 네이버 흐름만)

```
signInWithNaver():
  1. state = 암호학적 난수 생성 (CSRF 토큰, 1회용)
  2. 네이버 authorize URL 구성:
       https://nid.naver.com/oauth2.0/authorize
         ?response_type=code
         &client_id=<NAVER_CLIENT_ID>        ← 클라에 있어도 되는 공개 값
         &redirect_uri=<REDIRECT_URI>        ← https://order-app-5957e.web.app/auth/naver.html (§4-C 확정)
         &state=<state>
  3. OS 웹 인증 세션 호출(flutter_web_auth_2 등) → redirect_uri 로 돌아온
     콜백 URL 에서 code, state 파싱
  4. [CSRF] 돌아온 state 가 1에서 보낸 state 와 일치하는지 확인. 불일치 시 throw
  5. verifyNaverToken 호출: { code, state, redirect_uri }
  6. response.customToken → signInWithCustomToken → UserModel 구성
       (email/name/profileImage 는 커스텀 토큰 세션엔 없으므로,
        필요 시 nid/me 를 클라에서 별도 조회하거나 최초값 없이 구성 — 개발자 판단.
        기존에도 UserModel 의 displayName 등은 provider 별 소스가 달랐다.)
```

- `NAVER_CLIENT_ID` / `redirect_uri` 를 **클라에서도 하드코딩하지 않는다**(절대규칙 4) → `--dart-define` / `String.fromEnvironment` 또는 기존 앱의 설정 주입 방식과 **일관**되게 처리. (현재 `strings.xml`/`Info.plist` 에 있던 값들의 이전 — client_secret 은 **제거**, client_id/redirect 는 유지하되 주입 경로 정리.)
- **domain/presentation 레이어는 flutter_web_auth_2 / 네이버 SDK 를 직접 import 하지 않는다** — data 레이어 안에서만 사용(절대규칙 2). `AuthRepository.signInWithNaver()` 시그니처는 그대로이므로 상위 레이어는 변경 없음.

#### 라이브러리

- `flutter_naver_login`(`^2.1.0`) **의존 제거** → Authorization Code flow 용으로 교체.
- 권장 후보: `flutter_web_auth_2`(커스텀 스킴 콜백 지원, ASWebAuthenticationSession/Custom Tabs 사용). 난수 state 생성에 `crypto`/`dart:math Random.secure()`.
- 최종 라이브러리는 개발자가 pubspec 호환성 확인 후 확정. **선정 결과를 implementation.md 에 기록**.

### 4-C. redirect_uri / 플랫폼 콜백 — ✅ 확정 (플랜 B: https 중계)

> **2026-10-30 사용자 콘솔 확인 결과**: 네이버 개발자센터는 Callback URL 에 **커스텀 스킴(`qradar://auth/naver`)을 거부**한다("[로그인 오픈 API > PC 웹 > Callback URL] 설정을 확인해 주세요" 저장 실패). → 플랜 B(https 중계)로 **확정**.

**확정 redirect_uri (모바일·웹 공통, 단일값):**
```
https://order-app-5957e.web.app/auth/naver.html
```
- 네이버 콘솔 PC웹 환경에 **등록 완료** (서비스 URL `https://order-app-5957e.web.app`).
- 이 값이 authorize 요청 `redirect_uri`, 네이버 token 교환 `redirect_uri`, `NAVER_ALLOWED_REDIRECT_URIS` 에 **모두 정확히 동일**해야 한다.

**중계 페이지(Firebase Hosting, `landing/auth/naver.html`):**
- 네이버가 `?code=...&state=...` 를 이 https 페이지로 보냄 → 페이지 JS 가 즉시 **앱 커스텀 스킴으로 bounce**: `qradar://auth/naver?code=...&state=...`.
- flutter_web_auth_2 의 `callbackUrlScheme`(= `qradar`)이 이 bounce 를 가로채 code/state 를 앱으로 전달.
- 정적 파일 1개만 추가 → **landing 배포 규칙 준수**(hosting 만, firebase.json 재수정 없음, `landing/` 안에서만).
- `firebase.json` 은 `cleanUrls:false` 이므로 **`.html` 확장자 포함 경로**(`/auth/naver.html`)로 등록·구현한다(리라이트/설정 변경 불필요).
- bounce 대상 스킴: 기존 `qradar` 스킴(Toss/KakaoPay 사용, AndroidManifest L40 / Info.plist)과 **host/path 로 분리**(`auth/naver`) + flutter_web_auth_2 콜백 액티비티를 별도 등록해 충돌 방지.

**웹 세션(별도)**: 같은 https redirect 로 code 수신 후 CF 호출(§8). 동일 `NAVER_ALLOWED_REDIRECT_URIS` 값 사용.

---

## 5. 계정 동일성

- uid = `naver_<id>` / `kakao_<id>` **유지**. code-exchange 로 바꿔도 `nid/me` 의 `response.id` 는 동일하므로 기존 네이버 사용자와 **같은 uid** 로 수렴한다 → 즐겨찾기/Log/Qoin 연속성 보존.
- ⚠️ **콘솔 경고(§11)**: 기존 카카오/네이버 **앱에 웹 플랫폼을 추가**한다. **새 앱을 만들지 않는다.** 새 앱으로 만들면 app_id/client_id 가 달라져 **기존 모든 소셜 계정의 uid 가 끊긴다**(되돌리기 어려움).

---

## 6. 이력 / 감사 추적 (audit_trail.md §4 체크리스트 통과)

| # | 항목 | 판정 |
|---|---|---|
| 1 | 돈·권한·정책 **값**을 바꾸는가 → 설정 변경 이력 필요? | **아니오.** 이 기능은 **인증 검증 로직(코드)** 을 강화할 뿐, Firestore 의 정책/설정 **문서 값을 쓰거나 덮어쓰지 않는다.** 적립률 같은 config 문서 변경이 없다. → **설정 변경 이력 대상 아님**(사유 명시 완료) |
| 2 | 덮어쓰기로 사라지는 값 | 없음 (문서 write 자체가 없음) |
| 3 | 거래/기록 문서가 정책 값을 참조만 하는가 | 해당 없음 (새 기록 문서 없음) |
| 4 | "누가" 기록 | 커스텀 토큰 발급은 곧 로그인 — uid 는 발급 결과 자체(`kakao_*`/`naver_*`). 별도 행위자 기록 불필요 |
| 5 | 일괄 처리 | 없음 |
| 6 | CF 로그 의존 | 아래 주 — **audience 거절**은 보안 신호이나 **영구 Firestore 이력은 이번 비범위**. 사유: 실사용자 0, 공격 탐지 수요가 아직 없고, `paymentGateRejections` 처럼 영구 컬렉션을 두는 것은 과설계. 거절을 `console.error` (Cloud Logging, 보존 기간 있음) 로 남기고, 장기 보존이 필요해지면 `authRejections` 컬렉션을 **후속 task** 로 분리. |
| 7 | 권한 판정 필드 create/update 교차 확인 | **해당 없음** — Rules 변경 없음. CF 는 커스텀 토큰만 발급하며 보호 대상 Firestore 필드를 쓰지 않는다 |

→ 결론: **설정 변경 이력 불필요(사유 명시)**. 거래 이력도 해당 없음. 체크리스트 6항목 의식적으로 통과.

---

## 7. 비범위 (재확인)

- 다중 provider 계정 통합 / phone 인증 — 별도 task.
- App Check — §8 후속.
- 구글·이메일 로그인 — 불변.
- 인증 거절의 Firestore 영구 이력 — §6 사유와 함께 비범위.
- 카카오 흐름의 클라이언트 변경 — **없음**(서버만).

---

## 8. 참고(비범위) — App Check

callable 남용(무차별 호출) 방어는 Firebase **App Check** 로 다룬다. audience 검증과는 별개 레이어이며 **별도 후속 task** 로 분리한다. 이 spec 에서는 언급만 한다.

---

## 9. 앱에 노출된 네이버 client_secret 제거 (이 작업에 포함)

code-exchange 전환으로 client_secret 은 서버 전용이 된다. 따라서 아래 **평문 비밀을 앱에서 제거**한다(제거 자체가 보안 목적).

- `android/app/src/main/res/values/strings.xml` — `naver_client_secret`(값 redacted/rotated) 제거. `AndroidManifest.xml` L74~76 의 `com.naver.sdk.clientSecret` meta-data 제거. (`flutter_naver_login` SDK 제거와 함께 `clientId`/`clientName` meta-data 도 정리 — code flow 는 SDK meta-data 를 쓰지 않는다.)
- `ios/Runner/Info.plist` — `NidClientSecret`(값 redacted/rotated) 제거. `NidClientID`/`NidAppName`/`NidUrlScheme` 는 SDK 의존 제거에 맞춰 정리(code flow 가 요구하는 콜백 스킴만 남김).
- ⚠️ **노출 이력**: 이 secret 은 이미 배포본에 포함된 적이 있을 수 있으므로, §11 에서 **네이버 콘솔에서 client_secret 재발급(rotate)** 을 권고한다. (제거만으로는 과거 추출분이 무효화되지 않는다.)

---

## 10. 롤아웃 / 호환 (다. 항목)

- 테스트 단계(**실사용자 0**) → **clean cutover** 가능.
- 배포 순서: **functions 먼저 또는 동시 + 앱 재빌드 배포**. 네이버는 CF 입력 계약이 `{accessToken}` → `{code,...}` 로 **비호환 변경**이므로:
  - `verifyNaverToken` 은 `code` 부재 시 `invalid-argument` 로 거절(과도기 **dual-accept 하지 않음** — 실사용자 0 이므로 토큰 경로 유지는 과설계 + 구멍 존속).
  - 구 앱 빌드는 네이버 로그인이 동작하지 않게 됨(의도된 결과). 카카오는 입력 계약 불변이라 구 앱도 계속 동작(검증만 강화).
- Rules 배포 없음. 배포 대상: `functions:verifyNaverToken,verifyKakaoToken` + functions Secret/env + 앱 재빌드(사용자).

---

## 11. 외부 셋업 체크리스트 (사용자 작업 — 반드시 수행)

> 명령은 한 줄 전체로 표기하고 어디서 실행하는지 밝힌다(MEMORY: 명령어 안내 명확성).

### 11-1. 네이버 개발자 콘솔 (https://developers.naver.com — 기존 앱 "S-Grade")

1. ✅ **[선행 확인 완료]** 커스텀 스킴 거부 확인(2026-10-30) → 플랜 B 확정(§4-C).
2. ✅ **[완료] PC웹 환경 등록** — 서비스 URL `https://order-app-5957e.web.app`, Callback URL `https://order-app-5957e.web.app/auth/naver.html`. 기존 앱에 추가(§5).
3. ✅ **[완료]** `NAVER_CLIENT_ID` 확인 → gitignored env 주입 완료.
4. ✅ **[완료]** `client_secret` 재발급(rotate) 완료(§9 노출 대응). → 남은 작업: 새 값을 Secret 으로 주입(아래 명령, **사용자 실행**):
   - functions 디렉터리에서 한 줄로: `firebase functions:secrets:set NAVER_CLIENT_SECRET`
5. ✅ **[완료]** `NAVER_ALLOWED_REDIRECT_URIS` = 위 단일 https 중계 값으로 주입 완료.

> 2·3·5 의 실값은 **gitignored env 파일**(`functions/.env.order-app-5957e`, `env.json`)에 주입 완료. secret(4) 만 `secrets:set` 로 사용자가 넣는다. **실값은 어떤 커밋 파일/문서에도 기록하지 않는다.**

### 11-2. 카카오 개발자 콘솔 (https://developers.kakao.com — 기존 앱)

1. ✅ **[완료]** 숫자형 `앱 ID` 확인(네이티브 키 `f55c...` 아님, §3) → `KAKAO_APP_ID` gitignored env 주입 완료.
2. 웹 플랫폼은 웹 세션 요구에 따라 추가(카카오 웹 로그인 쓰는 경우). **기존 앱에 추가**, 새 앱 금지(§5).

### 11-3. functions 환경값 주입 (functions 디렉터리에서)

- `NAVER_CLIENT_SECRET` → Secret (위 11-1-4).
- `NAVER_CLIENT_ID` / `NAVER_ALLOWED_REDIRECT_URIS` / `KAKAO_APP_ID` → functions `.env`(비밀 아님, 하드코딩 금지). 기존 `defineString` 주입 규약(`docs/operations.md`)에 맞춘다.

### 11-4. 테스트 절차 (배포 후)

1. **카카오** — 정상 로그인 → `kakao_<id>` 로 기존과 **동일 uid** 로그인 확인. (서버만 바뀌었으므로 구 앱에서도 동작.)
2. **네이버** — 재빌드한 앱에서 로그인 시 **OS 웹 인증 시트**가 뜨고, 승인 후 `naver_<id>` 로 **동일 uid** 로그인 확인. 기존 네이버 사용자의 즐겨찾기/Log 연속성 확인.
3. **거절 경로** — (가능하면) 타앱 토큰/엉뚱한 redirect_uri 로 `unauthenticated`/`invalid-argument` 거절 확인.
4. 웹 네이버 로그인(웹 세션 구현분)과 **같은 uid 수렴** 확인.

---

## 12. 웹 세션에 전달할 계약 (웹 네이버 — 비범위 구현이나 계약 고정)

- 웹은 OAuth authorize(리다이렉트) → code 수신 후 `verifyNaverToken({ code, state, redirect_uri })` 호출. (CF 계약은 §4-A 와 동일.)
- 웹 redirect_uri 는 `NAVER_ALLOWED_REDIRECT_URIS` 에 등록된 값과 **정확히 일치**해야 한다.
- uid 결과는 모바일과 동일하게 `naver_<id>`.

---

## 데이터 흐름

### 카카오 (서버만 강화)
```
Kakao SDK (access token, 클라 불변)
  → verifyKakaoToken(accessToken)
      → kapi.kakao.com/v1/user/access_token_info  → app_id == KAKAO_APP_ID ? (신설 게이트)
      → id 확정
      → createCustomToken('kakao_'+id)
  → signInWithCustomToken → Firebase 세션
```

### 네이버 (code exchange 로 전환)
```
Page/Widget (로그인 버튼, 불변)
  → authProvider.signInWithNaver (불변)
  → SignInWithNaverUseCase (불변)
  → AuthRepository.signInWithNaver (불변)
  → AuthRemoteDataSourceImpl.signInWithNaver (교체)
       state 생성 → authorize(웹 인증 시트) → {code, state} 수신 → state 검증
  → verifyNaverToken({code, state, redirect_uri})
       redirect_uri 화이트리스트 → nid token 교환(client_secret 서버) → nid/me → id
       → createCustomToken('naver_'+id)
  → signInWithCustomToken → Firebase 세션
```

---

## 에러 처리

| 케이스 | 처리 |
|---|---|
| 카카오 app_id 불일치(타앱 토큰) | CF `unauthenticated` 거절. 클라는 기존 catch 로 로그인 실패 메시지 |
| 네이버 redirect_uri 화이트리스트 밖 | CF `invalid-argument` 거절 |
| 네이버 code 누락/만료/교환 실패 | CF `invalid-argument`/`internal`. 클라 로그인 실패 |
| 네이버 state 불일치(CSRF) | data 레이어에서 throw → `AsyncValue.guard` 로 실패 상태 |
| 사용자가 웹 인증 시트 취소/외부 앱 강제종료 | 기존 `auth_provider` 안전망 재사용 — 네이버에도 **카카오와 동일한 timeout + `cancelSignIn()`** 패턴 적용 권장(현재 네이버에는 timeout 미적용. §작업분배 developer) |
| 네트워크 실패 | CF `internal`, 클라 실패 메시지 |

---

## 작업 분배

### designer
- **UI 변경 없음 → design.md 불필요.**
- 근거: 로그인 화면·버튼 불변. 네이버만 **OS 제공 웹 인증 시트**(ASWebAuthenticationSession / Chrome Custom Tabs)로 바뀌며 이는 시스템 UI 라 디자인 대상이 아니다. 로딩/취소 상태 UI 는 기존 `auth_provider` 자산 재사용.
- designer 생략 사유를 spec 에 명시(이 항목).

### developer
- **CF**: `verifyKakaoToken` access_token_info + app_id 대조 게이트 추가(uid 유도 불변). `verifyNaverToken` 입력 계약 `{code,state,redirect_uri}` 재설계 + redirect_uri 화이트리스트 + server-side 교환.
- **환경값**: `defineSecret`/`defineString` 패턴(§3). 하드코딩 금지(절대규칙 4).
- **data**: `auth_remote_data_source.dart` 네이버 흐름을 Authorization Code flow 로 교체. `flutter_naver_login` 제거, 교체 라이브러리 선정·기록. domain/presentation 불변(시그니처 유지).
- **네이버 timeout/cancel**: 카카오와 동일한 안전망을 네이버에도 적용(에러처리 표).
- **플랫폼 설정**: Android/iOS 콜백 등록, **네이버 client_secret 평문 제거**(§9), client_id/redirect 주입 경로 정리(하드코딩 금지).
- **재사용**: 기존 Toss Secret 패턴, `auth_provider` loading/cancel, uid 유도 규약.
- **네이버 OAuth 세부 파라미터·커스텀 스킴 허용 여부는 공식 문서/콘솔로 검증**(§4-A 주, §4-C 리스크). 라이브러리·redirect_uri 최종값을 implementation.md 에 기록.
- 산출물: `docs/tasks/social_login_audience/implementation.md`.

### tester
- 카카오: 정상 로그인 `kakao_<id>` 동일 uid / **타앱 app_id 거절**.
- 네이버: code-exchange 정상 로그인 `naver_<id>` 동일 uid / redirect_uri 화이트리스트 밖 거절 / state 불일치 거절 / 취소·timeout 무한로딩 없음.
- **client_secret 이 앱 빌드 산출물에서 사라졌는지** 확인(strings.xml/Info.plist, grep).
- 구 입력 계약(`{accessToken}`)으로 네이버 CF 호출 시 거절(dual-accept 아님).
- domain/presentation 레이어가 네이버 SDK/web_auth 를 import 하지 않는지(절대규칙 2) 정적 확인.
- 산출물: `docs/tasks/social_login_audience/test_report.md`.

---

## 완료 기준

- [ ] `verifyKakaoToken` 이 `access_token_info` 로 `app_id` 를 `KAKAO_APP_ID` 와 대조하고 불일치 시 거절한다.
- [ ] `verifyNaverToken` 이 `{code,state,redirect_uri}` 를 받아 server-side 교환하고, redirect_uri 를 화이트리스트로 검증한다. client_secret 은 서버에만 있다.
- [ ] 모바일 네이버가 Authorization Code flow 로 동작하고 `flutter_naver_login` 의존이 제거됐다.
- [ ] 앱 빌드 산출물에서 네이버 `client_secret` 평문이 제거됐다.
- [ ] 모든 환경값이 `defineSecret`/`defineString`/dart-define 로 주입되고 코드 하드코딩이 없다(절대규칙 4).
- [ ] uid 가 `kakao_<id>`/`naver_<id>` 로 불변이고 기존 계정 연속성이 유지된다.
- [ ] §11 외부 셋업 체크리스트가 implementation.md/배포 노트에 반영된다.
- [ ] `implementation.md` / `test_report.md` 작성 완료, FAIL 없음 또는 후속 분리.
- [ ] design.md 불필요(UI 변경 없음) 명시.
