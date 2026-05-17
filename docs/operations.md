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
