# Qradar 운영 매뉴얼 (Operations)

이 문서는 Qradar 프로젝트의 **기술 스택, 패키지, 빌드/실행 명령어, Firebase 설정, 환경 변수 관리** 등 운영성 정보를 모아둔다.

아키텍처 판단은 [docs/architecture.md](architecture.md) 를, 코드 컨벤션은 [docs/agents/developer_guide.md](agents/developer_guide.md) 를, 디자인 시스템은 [docs/agents/designer_guide.md](agents/designer_guide.md) 를 참고한다.

---

## 1. 기술 스택

| 분류 | 기술 |
|------|------|
| 프론트엔드 | Flutter (iOS / Android) |
| 상태관리 | Riverpod (`flutter_riverpod` + `hooks_riverpod`) |
| 라우팅 | `go_router` |
| 백엔드 (Phase 1, MVP) | Firebase (Auth, Firestore, Storage, Functions, FCM) |
| 백엔드 (Phase 2, 성장기) | AWS (ECS/EC2 + RDS + S3 + SNS) |
| 백엔드 (Phase 3, 대규모) | 자체 서버 |
| 결제 | 토스페이먼츠, 카카오페이, 네이버페이 |
| 지도 | Google Maps Flutter, Kakao Maps JS SDK (WebView) |
| 소셜 로그인 | Kakao, Naver, Google, 이메일 인증 |
| 배포 | Google Play Store, Apple App Store |
| 개발 도구 | VSCode, Xcode, Android Studio |

서버 마이그레이션 단계별 상세는 [docs/architecture.md §8](architecture.md) 를 참조한다.

---

## 2. 주요 패키지 (pubspec.yaml 기준)

```yaml
# 상태관리
flutter_riverpod: ^2.x
hooks_riverpod: ^2.x
flutter_hooks: ^0.x

# 라우팅
go_router: ^14.x

# 코드 생성
freezed: ^2.x
freezed_annotation: ^2.x
json_serializable: ^6.x
build_runner: ^2.x

# Firebase
firebase_core:
firebase_auth:
cloud_firestore:
firebase_storage:
firebase_messaging:

# 소셜 로그인
google_sign_in:
kakao_flutter_sdk_user:
# naver_login: (별도 확인 필요)

# 지도
google_maps_flutter:
geolocator:
webview_flutter: ^4.x   # Kakao Maps JS SDK 호스팅용

# 결제
# 토스페이먼츠: REST API 직접 연동 (dio 사용)
# 카카오페이: kakao_flutter_sdk 또는 REST API
# 네이버페이: REST API 직접 연동

# 네트워크
dio: ^5.x

# 로컬 저장소
shared_preferences:
flutter_secure_storage:

# UI
cached_network_image:
shimmer:
lottie:
```

---

## 3. Flutter 빌드 / 개발 명령어

```bash
# 의존성 설치
flutter pub get

# 코드 생성 (freezed, json_serializable)
dart run build_runner build --delete-conflicting-outputs

# 코드 생성 감시 모드
dart run build_runner watch --delete-conflicting-outputs

# iOS 실행
flutter run -d ios

# Android 실행
flutter run -d android

# 분석
flutter analyze

# 테스트
flutter test

# 특정 테스트 파일 실행
flutter test test/domain/usecases/orderUseCaseTest.dart

# iOS 릴리즈 빌드
flutter build ios --release

# Android 릴리즈 빌드 (AAB)
flutter build appbundle --release
```

---

## 4. Firebase 프로젝트 구성

### 설정 파일 위치

- `google-services.json` → `android/app/`
- `GoogleService-Info.plist` → `ios/Runner/`

### 보안

- 위 파일들은 `.gitignore` 에 포함한다 (저장소에 커밋 금지).
- 환경별 Firebase 프로젝트는 분리한다: `dev` / `prod`.

---

## 5. 환경 변수 / API 키 관리

- `.env` 또는 `--dart-define` 을 활용한 환경변수 관리.
- 환경 분기 예: `flutter run --dart-define=ENV=dev`.
- API 키, Firebase 설정, JS Key 등은 **절대 코드에 하드코딩 금지**.
- 클라이언트 노출이 불가피한 키 (예: Kakao Maps JS Key) 는 외부 콘솔에서 도메인/플랫폼 제한으로 남용을 막는다.

### 예: Kakao Maps JS Key 주입

```bash
flutter run -d <device> --dart-define=KAKAO_JS_KEY=<your-js-key>
flutter build ios --release --dart-define=KAKAO_JS_KEY=<your-js-key>
flutter build appbundle --release --dart-define=KAKAO_JS_KEY=<your-js-key>
```

코드에서는 `String.fromEnvironment('KAKAO_JS_KEY')` 로 읽는다.

---

## 6. 결제 게이트 운영 (단일 진실원)

결제 서버(`verifyTossPayment`)가 돈이 움직이기 전에 거는 **서버 권위 검사**의 운영 매뉴얼이다.
각 게이트를 **왜 그렇게 설계했는가**는 그 task 의 spec 을 따른다. 이 절은 **운영 중에 무엇을
어떻게 켜고 끄고 확인하는가**의 단일 진실원이다.

> 배포 절차(한 번 하고 끝) 는 각 task 의 `deploy_runbook.md` 에 있다. 이 절은 **배포가 끝난 뒤에도
> 계속 쓰는 지식**(비상 정지·모드 확인·일일 점검)만 둔다.

### 6.1 모드 스위치

전역 환경변수다 — 그 함수를 타는 **모든 결제**에 일괄 적용된다. 특정 매장만 켜고 끌 수 없다.

| 스위치 | 무엇을 검사하나 | task |
|---|---|---|
| `PAYMENT_GATE_MODE` | 매장 판매 가능 여부(G1) + 메뉴 품절(G2) | `payment_server_authority` |
| `PAYMENT_PRICE_MODE` | 결제 금액을 서버가 재계산해 대조 | `payment_price_authority` |

**두 스위치는 독립이다.** 가격 쪽 오탐으로 `PAYMENT_PRICE_MODE` 를 내려도 품절 게이트는 그대로
유지된다. (검증 끝난 보호를, 검증 중인 다른 것 때문에 잃지 않게 나눴다.)

- **읽는 곳**: 둘 다 `functions/src/verifyTossPayment.ts` 의 `defineString("PAYMENT_GATE_MODE" | "PAYMENT_PRICE_MODE", { default: "off" })`
  이고, 값은 `resolveGateMode` / `resolvePriceMode`(= 같은 함수) 로 정규화된다 — 폴백이 같다. 둘 다 `verifyTossPayment`
  함수 하나의 환경변수라 **재배포 단위도 `functions:verifyTossPayment` 하나**다. 값은 **배포 머신의
  `functions/.env.order-app-5957e` 에 한 파일**에 같이 있다 — 한 키를 바꾸는 명령이 다른 키를 지우지 않게 아래 6.2 의
  `grep -v` 형식을 쓴다. **배포 머신에서 그 파일이 없으면 두 스위치가 함께 `off` 로 떨어진다.**
- **조합**: `PAYMENT_GATE_MODE=off` 인데 `PAYMENT_PRICE_MODE` 가 `shadow`/`enforce` 면 가격 모드가 매장·메뉴 문서를 **직접
  읽어** 금액을 계산한다(품절·판매 중단 판정은 하지 않는다). 가격 쪽은 플래그 조합과 무관하게 동작한다. 반대로
  `PAYMENT_PRICE_MODE=off` 면 옵션 그룹은 물론 메뉴 문서도 가격 목적으로 읽지 않는다(비용 0).

각 값:

| 값 | 동작 |
|---|---|
| `off` | 검사하지 않는다. 관련 문서 읽기 0 (비용 0 — 금액 모드는 옵션 그룹도 읽지 않는다). **기본값·미지값·오타·대소문자 불일치는 전부 `off`** — 설정 오타로 매출이 멈추는 것보다 구멍이 열려 있는 게 낫다는 판단(spec §17.0). |
| `shadow` | 검사하되 **거절하지 않고** `paymentGateRejections` 에 `detail.shadow:true` 로 기록만. "무엇이 막힐지" 를 돈 안 멈추고 본다. |
| `enforce` | 실제로 거절한다. |

### 6.2 모드 값 바꾸기

값은 배포 머신의 `functions/.env.order-app-5957e` 에 키마다 한 줄이다 (git 제외). **배포 시점에 박히므로
파일만 고치면 반영되지 않고 재배포해야 한다.** 아래는 `PAYMENT_GATE_MODE` 예시 — `PAYMENT_PRICE_MODE`
도 키 이름만 바꿔 같은 방식이다. `>` 로 덮어쓰지 않는다(다른 키가 있을 수 있다).

```bash
cd /Users/Byeonguk/Developer/OrderApp && grep -v '^PAYMENT_GATE_MODE=' functions/.env.order-app-5957e > /tmp/psa_env.new ; echo "PAYMENT_GATE_MODE=enforce" >> /tmp/psa_env.new && mv /tmp/psa_env.new functions/.env.order-app-5957e && cat functions/.env.order-app-5957e && npx --yes firebase-tools@14 deploy --only functions:verifyTossPayment --project order-app-5957e
```

금액 스위치는 키 이름만 바꾼 같은 형식이다 (`cat` 출력에 **두 키가 다 보이는지** 눈으로 확인한다):

```bash
cd /Users/Byeonguk/Developer/OrderApp && grep -v '^PAYMENT_PRICE_MODE=' functions/.env.order-app-5957e > /tmp/ppa_env.new ; echo "PAYMENT_PRICE_MODE=enforce" >> /tmp/ppa_env.new && mv /tmp/ppa_env.new functions/.env.order-app-5957e && cat functions/.env.order-app-5957e && npx --yes firebase-tools@14 deploy --only functions:verifyTossPayment --project order-app-5957e
```

### 6.3 🚨 비상 정지 — 게이트가 정상 결제를 막고 있을 때

**가장 싼 비상 정지는 Rules 롤백도 CF 롤백도 아니다 — 해당 모드를 `off` 로 재배포하는 것이다.**
게이트가 평가조차 하지 않으므로 배포가 끝나는 즉시 이전 동작으로 돌아간다. 위 6.2 명령에서 값만
`off` 로 바꿔 친다.

- 품절·매장 상태 문제면 `PAYMENT_GATE_MODE=off`, 금액 문제면 `PAYMENT_PRICE_MODE=off`.
- ⚠️ **금액 게이트를 `off` 로 내린 상태는 "결제 금액을 클라이언트가 정하는 상태"(1원 결제 가능)다.** 품절 게이트의 `off` 보다 구멍이 크다.
- **무한 거절 루프 신호**: 같은 `uid` + 같은 `storeId` 의 `PRICE_MISMATCH` 가 `paymentGateRejections` 에 짧은 시간에 반복해서
  쌓이면(고객이 `최신 가격으로 다시 담기` 로도 못 빠져나온다) 원인을 찾기 전에 먼저 `PAYMENT_PRICE_MODE=off` 로 내린다.
- ⚠️ **`off` 로 내린 뒤 그대로 잊지 않는다.** `off` 는 구멍이 열린 상태다. 원인을 고치고
  `shadow` → `enforce` 를 다시 밟는다.

### 6.4 현재 운영값 확인

Console → Cloud Run → `verifytosspayment` → 컨테이너 → 변수 및 보안 비밀. 또는 소스 탭의
`.env.order-app-5957e`. **다만 값을 눈으로 보는 것보다 "양성 대조" 가 확실하다** — `shadow`/`enforce`
가 실제로 도는지는 의도적으로 위반 1건을 만들어 `paymentGateRejections` 에 기록이 생기는지로
확인한다(기본값이 `off` 라 "기록 없음" 은 "안 돈 것" 과 구분되지 않는다).

금액 스위치의 양성 대조는 **결제창(Toss)이 떠 있는 동안 그 메뉴의 `basePrice` 를 바꾸고** 결제를 마치는 것이다 —
신버전 앱은 결제 탭 직전에 카트를 재가격하므로 일반 조작으로는 서버 거절이 나지 않는다. 기대: `PRICE_MISMATCH` 1건,
`shadow` 일 때만 `detail.shadow:true`, `detail.delta` 부호가 변경 방향과 같다.

### 6.5 일일 점검 — `paymentGateRejections`

Console → Firestore → `paymentGateRejections`. 거절이 **"악용 차단"** 인지 **"데이터가 틀어져
정상 손님을 막은 것(오탐)"** 인지는 건수·분포로만 구분된다.

- **영업 중인 정상 매장 / 품절이 아닌 메뉴가 잡히면** → 오탐이다. 즉시 원인을 찾는다. 방치하면
  그 매장의 매출이 계속 멈춘다. 급하면 6.3 으로 내린다.
- 미승인·반려 매장, 실제 품절 메뉴만 잡히면 정상(게이트가 할 일을 한 것).

**금액 거절 (`PRICE_MISMATCH` · `OPTION_UNAVAILABLE`)** 은 `detail` 로 읽는다:

| 필드 | 읽는 법 |
|---|---|
| `delta` (= 클라 선언액 − 서버 계산액, 부호 있음) | **시점 차이는 양·음 양방향으로 흩어지고 금액이 작다.** 조작은 음수로 크게 치우친다(공격자는 적게 낸다). 이 부호 분포가 둘을 사후에 가르는 유일한 수단이다 |
| `checks` (c1~c6) | 판정식 어느 항이 깨졌나. c1~c3 은 클라 값끼리의 정합성(권위 아님), **c4~c6 이 권위** |
| `lines[]` | 라인별 `clientLineTotal` / `serverLineTotal` / `quantity`. `unusable` 이 있으면 그 라인은 계산할 수 없었다(메뉴 해석 불가·수량 이상) |
| `optionIssues[]` | `missing` `disabled` `inactive` `notInRefs` `requiredEmpty` `multiInSingle` `duplicate` |
| `failure` (READ_FAILED 일 때) | `storeUnreadable` `optionGroupsUnreadable` `optionGroupCapExceeded` — **`optionGroupCapExceeded` 는 1건이라도 나오면 멈추고 원인부터** (도달 불가 가정이 틀렸다) |

- **정상 결제가 잡히면(오탐)** 즉시 원인을 찾는다. 급하면 `PAYMENT_PRICE_MODE=off`(6.3).
- 가격 변경 이력(`priceHistory`, admin 읽기 전용)으로 "그 시점에 가격이 바뀌었나" 를 확인한다 — 같은 `targetId` 의 `changedAt` 근처.

### 6.6 아직 검증되지 않은 것

- **"요금도 청구되지 않았어요" 문구의 사실성**: 테스트 키 환경에서는 증명할 수 없다. 실연동 키로
  전환하는 시점에 거절 1건을 실제로 일으켜 **카드사 알림·토스 결제 내역에 아무것도 남지 않는지**
  확인한다. 남으면 그 문구는 거짓이므로 `아직 결제가 완료되지 않았어요` 로 즉시 바꾼다.
  (`payment_server_authority/deploy_runbook.md` ⑩-c)

### 6.7 Qoin 사용(qoin_spend) 운영

Qoin 사용은 `PAYMENT_GATE_MODE` / `PAYMENT_PRICE_MODE` 와 **독립**이며, 켜고 끄는 값은 `config/qoin` 문서에 있다 (재배포 불필요).

| 필드 | 의미 | 부재 시 |
|---|---|---|
| `spendEnabled` | 사용 kill switch. `false` → **신규 사용만** 차단 (환불·취소 복원은 통과) | **꺼짐 (fail-closed)** |
| `minCashFloor` | 결제수단 무관 단일 최소 현금 결제액. 초기 **300원** (토스 수단별 최소금액 중 최대치 — 머천트 계약별로 다를 수 있으니 토스 콘솔값 확인) | 사용 차단 |
| `minSpendUnit` | 최소 사용 단위 (기본 1) | 1 |
| `enabled` (기존) | 전역 비상정지 — 적립·회수·**사용·복원** 전부 멈춘다 (복원이 멈추면 `qoinSettlementIssues` 에 `spend_restore_skipped_disabled` 로 남는다) | 차단 |

- **값 변경 수단**: callable `setQoinSpendPolicy` (admin, 변경 이력 동시 기록). Console 직접 편집도 되지만 Rules 를 우회하므로 `onQoinConfigWritten` 이 사후 이력(`source:'direct'`)만 남긴다.
- **켜는 순서**: `minCashFloor` 확인 → (선택) `minSpendUnit` → `spendEnabled: true`. `PAYMENT_PRICE_MODE` 와 무관하게 Qoin 주문은 서버가 소계를 다시 만들어 enforce 한다.
- **비상 정지**: `spendEnabled = false` 한 필드. 앱은 다음 정책 스트림 갱신에서 Qoin 섹션을 숨기고 기존 결제로 폴백한다. 이미 진행 중인 요청은 서버가 거절(`QOIN_SPEND_DISABLED`, confirm 전)한다.
- **일일 점검**: `paymentGateRejections` 의 `reason` 이 `QOIN_*` 인 건수 — `QOIN_BELOW_CASH_FLOOR` 가 반복되면 토스 최소금액과 `minCashFloor` 가 어긋난 것일 수 있다. `qoinSettlementIssues` 의 `reason: spend_rollback_failed` / `spend_restore_skipped_disabled` 는 **고객 Qoin 이 걸려 있는 수동 복구 대상**이다.
- **고아 예약 점검**: `users/*/qoinTransactions/spend_*` 중 `orders/{orderId}` 가 없고 `spendRefund_{orderId}` 도 없는 것은 서버가 차감 직후 죽은 잔재다 (현재 자동 청소 없음 — `docs/tasks/qoin_spend/implementation.md` 보류 항목).
