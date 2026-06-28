# iOS APNs 설정 (출시 전 작업)

## 목적

Phase 3b (FCM 푸시 알림) 인프라 구축 시점에 iOS APNs Auth Key 미발급으로 보류된 작업.
**App Store 출시 1~2주 전** 에 진행한다.

---

## 배경

- Phase 3b 에서 `firebase_messaging` 통합 및 iOS 네이티브 코드 (AppDelegate / Info.plist / Capabilities) 는 모두 완성됨
- **APNs Auth Key 만 Firebase Console 에 미업로드** 상태
- Android 푸시는 정상 작동
- iOS 푸시는 본 작업 완료 후에만 작동

---

## 사전 조건

- **Apple Developer Program 가입** ($99/년) 완료
- Apple Developer 계정 admin 권한
- Firebase Console `order-app-5957e` 프로젝트 admin 권한
- macOS + Xcode 최신 버전 설치

---

## 작업 체크리스트

### 1. Apple Developer 에서 APNs Auth Key 발급

- [ ] https://developer.apple.com/account 접속
- [ ] **Certificates, Identifiers & Profiles** → **Keys**
- [ ] **+** 버튼 → Key Name 입력 (예: "Qradar APNs Production")
- [ ] **Apple Push Notifications service (APNs)** 활성화
- [ ] **Continue** → **Register**
- [ ] **Download** 클릭 → `AuthKey_XXXXXXXXXX.p8` 안전한 위치에 저장
  - ⚠️ **1회만 다운로드 가능**. 분실 시 새 Key 발급 필요
- [ ] **Key ID** (10자리) 기록
- [ ] **Team ID** (10자리, 우측 상단 또는 멤버십 페이지) 기록

### 2. Firebase Console 에 APNs Key 업로드

- [ ] https://console.firebase.google.com → `order-app-5957e` 선택
- [ ] ⚙️ **Project Settings** → **Cloud Messaging** 탭
- [ ] **Apple app configuration** 섹션 → **APNs Authentication Key** → **Upload**
- [ ] 업로드 폼:
  - APNs Auth Key file: `.p8` 파일
  - Key ID: 1단계에서 기록한 값
  - Team ID: 1단계에서 기록한 값
- [ ] **Upload** 클릭 → 성공 확인

### 3. Xcode Capability 확인

(Phase 3b 구현 시점에 이미 추가되어 있을 가능성 높음. 본 단계는 재확인)

- [ ] `ios/Runner.xcworkspace` 오픈
- [ ] Runner target → **Signing & Capabilities** 탭
- [ ] **Push Notifications** capability 존재 확인 (없으면 **+ Capability** 로 추가)
- [ ] **Background Modes** capability 존재 확인 → **Remote notifications** 체크 확인
- [ ] **Bundle Identifier** 가 Apple Developer 의 App ID 와 일치 확인

### 4. Provisioning Profile 점검

- [ ] Apple Developer → Profiles → Distribution Profile 의 capabilities 에 Push Notifications 포함 확인
- [ ] Xcode → Automatically manage signing 사용 중이면 자동 갱신됨
- [ ] Distribution Profile 갱신 후 Xcode 에서 재다운로드

### 5. 실기기 푸시 테스트

- [ ] 실기기 (iOS) 에 앱 설치 (시뮬레이터는 푸시 미지원)
- [ ] 점주 계정 로그인 → OwnerScaffold 첫 진입 → 알림 권한 요청 다이얼로그 노출 → 허용
- [ ] `users/{uid}.fcmToken` 이 Firestore 에 정상 저장됨 확인
- [ ] **포그라운드 테스트**: 점주가 앱을 켠 상태에서 다른 디바이스에서 결제 → 푸시 수신 확인
- [ ] **백그라운드 테스트**: 앱을 백그라운드로 보낸 상태에서 결제 → 푸시 수신 확인
- [ ] **종료 테스트**: 앱을 완전히 종료한 상태에서 결제 → 푸시 수신 확인
- [ ] **알림 탭 → deep link**: 알림 탭 시 OrderDetailPage 로 정상 진입 확인
- [ ] **환불 요청 알림**: 고객이 환불 요청 → 점주에게 푸시 수신 확인

### 6. 자주 발생하는 이슈 점검

- [ ] **Bundle ID 불일치**: Xcode Bundle Identifier ≠ Apple Developer App ID → 일치시킴
- [ ] **Sandbox vs Production 환경**: 디버그 빌드는 sandbox APNs, 릴리즈 빌드는 production APNs 사용. APNs Auth Key 는 양쪽 모두 호환되므로 환경 문제 없음
- [ ] **AppDelegate `didRegisterForRemoteNotifications` 콜백 누락**: Phase 3b 구현 시점 확인 필요
- [ ] **토큰 발급 실패**: `Messaging.instance.getAPNSToken()` null 반환 시 Capabilities + Bundle ID + Provisioning Profile 재확인

---

## 산출물

- iOS 실기기에서 푸시 정상 수신 확인 (포그라운드 / 백그라운드 / 종료 3종 상태)
- 환불 요청 알림 정상 수신 확인
- 알림 탭 → OrderDetailPage deep link 정상 동작 확인
- `docs/tasks/ios_apns_setup/test_report.md` 작성

---

## 영향 / 위험

- 본 작업 미완료 시 iOS 사용자는 푸시 알림 미수신 (앱은 정상 동작)
- 출시 직전 작업이므로 일정 여유 (1~2주) 확보 권장
- Apple Developer 가입이 처음이면 결제 / 본인 인증으로 1~3일 추가 소요 가능

---

## 참조

- Phase 3b spec: [docs/tasks/order_flow_phase3b/spec.md](../order_flow_phase3b/spec.md)
- Phase 3b implementation: [docs/tasks/order_flow_phase3b/implementation.md](../order_flow_phase3b/implementation.md)
- Firebase 공식 가이드: https://firebase.google.com/docs/cloud-messaging/ios/certs
