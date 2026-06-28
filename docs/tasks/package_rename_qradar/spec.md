# 패키지명 com.qradar.app 마이그레이션 (출시 전 작업)

## 목적

브랜드 정체성 (Qradar) 에 맞게 패키지명 / Bundle ID 를 `com.orderapp.*` → `com.qradar.app` 으로 정식 변경.
**App Store / Play Store 출시 직전** 에 진행한다.

---

## 배경

- 브랜드명을 OrderApp → Qradar 로 리브랜딩
- 개발 중 임시로 패키지명 변경했으나 외부 OAuth provider 등록이 누락되어 소셜 로그인 실패 → 임시 롤백 (`com.orderapp.order_app`) 상태
- Firebase Console 에는 `com.qradar.app` 으로 Qradar Android 앱이 이미 등록되어 있음 (App ID: `1:835847199015:android:1b45f24b099287e8327102`)
- `google-services.json` 에는 두 client 항목 모두 포함되어 즉시 전환 가능

---

## 사전 조건

- Apple Developer 계정 + Naver / Kakao / Google Developers 계정 admin 권한
- macOS 의 debug keystore SHA-1 / production keystore SHA-1 발급 가능
- App Store / Play Store 출시 전이라 외부 사용자 영향 없음

---

## 작업 체크리스트

### A. Android 패키지명 변경

- [ ] `android/app/build.gradle.kts` 의 `applicationId` 를 `"com.orderapp.order_app"` → `"com.qradar.app"` 로 변경
- [ ] `android/app/src/main/AndroidManifest.xml` 의 패키지 관련 항목 점검
- [ ] `MainActivity.kt` 의 패키지 선언 / 디렉토리 경로 확인 (디렉토리: `android/app/src/main/kotlin/com/qradar/app/`)
- [ ] `flutter clean` 후 빌드 확인

### B. iOS Bundle ID 변경

- [ ] `ios/Runner.xcodeproj` 의 Bundle Identifier 변경: `com.orderapp.sgrade` (또는 현재 값) → `com.qradar.app`
- [ ] `Info.plist` 의 Bundle ID 참조 확인
- [ ] Provisioning Profile / Signing 재설정

### C. Firebase Console 정리

- [ ] `com.qradar.app` Android 앱 — SHA-1 인증서 추가 (Google Sign-In 용):
  - debug keystore SHA-1: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`
  - production keystore SHA-1 (출시 키 발급 후)
- [ ] iOS 앱 — `com.qradar.app` 으로 새 iOS 앱 등록 (현재 S-Grade `com.orderapp.sgrade` 와 별개)
- [ ] 새 `GoogleService-Info.plist` 다운로드 → `ios/Runner/` 에 교체
- [ ] (선택) 기존 `com.orderapp.order_app` Android 앱 / `com.orderapp.sgrade` iOS 앱 삭제

### D. 카카오 Developers Console

- [ ] https://developers.kakao.com → 내 애플리케이션
- [ ] **플랫폼 등록 — Android**:
  - 패키지명: `com.qradar.app`
  - 키 해시 (debug):
    ```bash
    keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | openssl sha1 -binary | openssl base64
    ```
  - 키 해시 (release): production keystore 발급 후 동일 방법
- [ ] **플랫폼 등록 — iOS**:
  - Bundle ID: `com.qradar.app`
- [ ] 기존 `com.orderapp.order_app` 등록은 출시 후 일정 기간 유지 (롤백 안전망) 후 삭제

### E. Naver Developers Console

- [ ] https://developers.naver.com → 내 애플리케이션
- [ ] **Android 설정**:
  - 패키지명: `com.qradar.app`
- [ ] **iOS 설정**:
  - URL Scheme + Bundle ID 갱신
- [ ] 기존 `com.orderapp.order_app` 등록 정리

### F. Google Cloud Console (Google Sign-In 추가 점검)

- [ ] OAuth 2.0 클라이언트 ID 점검
- [ ] Firebase Console 에서 SHA-1 추가 (C 단계) 만 하면 자동 처리됨

### G. Android 네이티브 리소스 경로 갱신

- [ ] `android/app/src/main/kotlin/` 아래 디렉토리 구조 변경:
  - `com/orderapp/order_app/` → `com/qradar/app/`
- [ ] `MainActivity.kt` 의 `package com.qradar.app` 선언 변경
- [ ] 다른 Kotlin / Java 파일 같은 처리

### H. iOS 네이티브 리소스 경로 갱신

- [ ] Xcode 에서 Bundle ID 변경
- [ ] Provisioning Profile 재발급 / 다운로드
- [ ] (선택) Scheme 이름 정리

### I. 빌드 / 검증

- [ ] Android: `flutter clean && flutter run` 으로 정상 실행 확인
- [ ] iOS: Xcode 에서 정상 빌드 확인
- [ ] 4종 소셜 로그인 (Google / Kakao / Naver / 이메일) 모두 정상 작동 확인
- [ ] FCM 푸시 토큰 정상 발급 확인 (Firestore `users.fcmToken`)
- [ ] FCM 푸시 수신 확인

### J. 이전 패키지명 정리 (출시 후 일정 기간 후)

- [ ] Firebase Console 에서 `com.orderapp.order_app` 앱 삭제
- [ ] Firebase Console 에서 `com.orderapp.sgrade` iOS 앱 삭제
- [ ] 새 `google-services.json` / `GoogleService-Info.plist` 다운로드
- [ ] 카카오 / 네이버 Developers Console 의 기존 패키지명 등록 삭제

---

## 영향 / 위험

- **외부 사용자 영향 없음** — 출시 전이므로 기존 사용자 없음
- **개발 / 테스트 영향**: 작업 직후 SHA-1 / 키 해시 등록 누락 시 소셜 로그인 일시 실패 가능. 검증 직전 모든 provider 등록 완료해야 함
- **Provisioning Profile 갱신 시간** — 처음 발급 시 5~10분 소요 가능

---

## 참조

- Phase 3b implementation: [docs/tasks/order_flow_phase3b/implementation.md](../order_flow_phase3b/implementation.md)
- iOS APNs setup: [docs/tasks/ios_apns_setup/spec.md](../ios_apns_setup/spec.md)
- Firebase Console: https://console.firebase.google.com/project/order-app-5957e
- Kakao Developers: https://developers.kakao.com
- Naver Developers: https://developers.naver.com
