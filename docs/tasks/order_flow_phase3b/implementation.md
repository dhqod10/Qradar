# Phase 3b — FCM 푸시 알림 구현 (implementation.md)

## 구현 완료 항목

### Domain 레이어
- `PushNotificationRepository` 인터페이스
- `RegisterFcmTokenUseCase` — 로그인 성공 후 FCM 토큰 Firestore 저장
- `ClearFcmTokenUseCase` — 로그아웃 전 FCM 토큰 삭제
- `RequestNotificationPermissionUseCase` — OS 권한 요청
- `HandleNotificationMessageUseCase` — 메시지 타입별 네비게이션 처리
- `NotificationPermissionStatus` 엔티티
- `RemoteNotificationMessage` 엔티티

### Data 레이어
- `FcmRemoteDataSource` — `firebase_messaging` / `flutter_local_notifications` 래퍼
  - Android 채널 초기화 (`qradar_orders`)
  - 토큰 발급/삭제, 권한 요청, 메시지 스트림
- `PushNotificationRepositoryImpl`

### Presentation 레이어
- `NotificationPermissionDialog` — 최초 1회 권한 요청 다이얼로그
- `NotificationDeniedBanner` — 거부 시 설정 유도 배너
- `PendingNotificationHolder` — 포그라운드 메시지 처리
- `NotificationNavigator` — 메시지 탭/앱 열기 시 화면 이동
- `notification_providers.dart` — 인프라/UseCase Provider
- `AuthNotifier` hooks — `_onSignInSuccess` / `signOut` 에 FCM 등록/정리 연결
- `OwnerScaffold` — 첫 진입 시 다이얼로그 노출

### main.dart
- `GlobalKey<NavigatorState> navigatorKey` 전역 선언
- `MaterialApp(navigatorKey: navigatorKey)` 연결
- `_firebaseMessagingBackgroundHandler` top-level 백그라운드 핸들러 등록
  - Background isolate에서 `Firebase.initializeApp` 재호출
  - `FlutterLocalNotificationsPlugin`으로 로컬 알림 표시
- `FirebaseMessaging.onBackgroundMessage` 등록 (`Firebase.initializeApp` 직후)

### UserEntity / UserModel 필드 추가
- `fcmToken`: FCM 디바이스 토큰
- `fcmTokenUpdatedAt`: 토큰 갱신 시각
- `notificationPermissionPrompted`: 다이얼로그 노출 이력 (false→true 일방향)

### Cloud Functions
- `onOrderCreated` — `onDocumentCreated('orders/{orderId}')` 트리거
  - storeId → ownerId → fcmToken 조회 → FCM data-only 발송
  - invalid token 시 Firestore fcmToken 필드 삭제 (결정 G)
  - 발송 실패 swallow (결정 G)
- `onOrderRefundRequested` — `onDocumentUpdated('orders/{orderId}')` 트리거
  - `before.refundRequest == null && after.refundRequest != null` 조건만 처리
  - 동일한 token 처리 / 에러 swallow 패턴

### Firestore Rules 변경
`isSelfProfileUpdate` 화이트리스트에 2개 필드 추가:
```
'fcmTokenUpdatedAt', 'notificationPermissionPrompted'
```
이전: `['role', 'displayName', 'photoUrl', 'fcmToken', 'updatedAt', 'brandId']`
이후: `['role', 'displayName', 'photoUrl', 'fcmToken', 'fcmTokenUpdatedAt', 'notificationPermissionPrompted', 'updatedAt', 'brandId']`

### iOS 네이티브 설정
- `ios/Runner/Info.plist`: `UIBackgroundModes` → `remote-notification`, `fetch` 추가
- `ios/Runner/AppDelegate.swift`: `MessagingDelegate` 적용
  - `UNUserNotificationCenter.current().delegate = self`
  - `application.registerForRemoteNotifications()`
  - `Messaging.messaging().delegate = self`
  - `didRegisterForRemoteNotificationsWithDeviceToken` → `Messaging.messaging().apnsToken` 전달

> 주의: iOS FCM 실기기 수신을 위해 **APNs Auth Key** 를 Firebase Console > Project Settings > Cloud Messaging 에 업로드해야 한다. 이는 본 Phase 비범위 — `docs/tasks/ios_apns_setup/spec.md` 에서 별도 처리.

### Android 네이티브 설정
- `android/app/src/main/AndroidManifest.xml`:
  - `POST_NOTIFICATIONS` 권한 추가 (Android 13+)
  - `com.google.firebase.messaging.default_notification_channel_id` → `qradar_orders` 메타 추가

---

## 신규/수정 파일 목록

| 구분 | 경로 |
|------|------|
| 신규 | `functions/src/onOrderCreated.ts` |
| 신규 | `functions/src/onOrderRefundRequested.ts` |
| 수정 | `functions/src/index.ts` — 두 함수 export 추가 |
| 수정 | `firestore.rules` — `isSelfProfileUpdate` 화이트리스트 갱신 |
| 수정 | `lib/main.dart` — navigatorKey, 백그라운드 핸들러, FCM 초기화 |
| 수정 | `lib/domain/entities/user_entity.dart` — FCM 관련 필드 3개 추가 |
| 수정 | `lib/domain/entities/user_entity.freezed.dart` — 재생성 |
| 수정 | `lib/data/models/user_model.dart` — FCM 관련 필드 3개 추가 |
| 수정 | `lib/data/models/user_model.freezed.dart` — 재생성 |
| 수정 | `lib/data/models/user_model.g.dart` — 재생성 |
| 신규 | `lib/data/datasources/remote/fcm_remote_data_source.dart` |
| 신규 | `lib/data/repositories/push_notification_repository_impl.dart` |
| 신규 | `lib/domain/repositories/push_notification_repository.dart` |
| 신규 | `lib/domain/usecases/register_fcm_token_use_case.dart` |
| 신규 | `lib/domain/usecases/clear_fcm_token_use_case.dart` |
| 신규 | `lib/domain/usecases/request_notification_permission_use_case.dart` |
| 신규 | `lib/domain/usecases/handle_notification_message_use_case.dart` |
| 신규 | `lib/domain/entities/notification_permission_status.dart` |
| 신규 | `lib/domain/entities/remote_notification_message.dart` |
| 신규 | `lib/presentation/common/notification/notification_permission_dialog.dart` |
| 신규 | `lib/presentation/common/notification/pending_notification_holder.dart` |
| 신규 | `lib/presentation/common/notification/notification_navigator.dart` |
| 신규 | `lib/presentation/common/notification/providers/notification_providers.dart` |
| 수정 | `lib/presentation/customer/auth/auth_provider.dart` — FCM 훅 연결 |
| 수정 | `ios/Runner/AppDelegate.swift` — MessagingDelegate 적용 |
| 수정 | `ios/Runner/Info.plist` — UIBackgroundModes 추가 |
| 수정 | `android/app/src/main/AndroidManifest.xml` — POST_NOTIFICATIONS, FCM 채널 메타 |
| 수정 | `pubspec.yaml` — firebase_messaging ^16.1.3, flutter_local_notifications ^18.0.1, app_settings ^5.1.1 |

---

## Cloud Functions 배포 명령

```bash
cd functions && npm run build
firebase deploy --only functions:onOrderCreated,functions:onOrderRefundRequested
firebase deploy --only firestore:rules
```

---

## 검증 시나리오 (Android 실기기 위주)

1. **FCM 토큰 등록 확인**
   - 앱 최초 실행 → 알림 권한 다이얼로그 노출 → 허용
   - Firestore `users/{uid}.fcmToken` 필드 기록 확인

2. **주문 생성 → 점주 FCM 수신**
   - 고객이 결제 완료 → `orders/{orderId}` 문서 생성
   - Cloud Function `onOrderCreated` 트리거 → 점주 기기에 `새 주문` 알림 수신
   - 백그라운드/포그라운드 양쪽 시나리오 확인

3. **환불 요청 → 점주 FCM 수신**
   - 고객이 환불 요청 → `orders/{orderId}.refundRequest` 필드 업데이트
   - Cloud Function `onOrderRefundRequested` 트리거 → 점주 기기에 `환불 요청` 알림 수신

4. **알림 탭 → 화면 이동**
   - 알림 탭 시 `NotificationNavigator` 가 해당 주문 상세 화면으로 이동

5. **로그아웃 시 토큰 정리**
   - 로그아웃 → Firestore `users/{uid}.fcmToken` 필드 삭제 확인

6. **invalid token 정리**
   - 기기 재설치 후 구 토큰으로 주문 생성 → Cloud Function 이 토큰 정리 후 로그 기록 확인

---

## 미구현 / 보류

- **iOS APNs Auth Key 업로드**: Firebase Console > Project Settings > Cloud Messaging 에서 업로드 필요. 실기기 iOS FCM 수신의 전제조건. 출시 전 `docs/tasks/ios_apns_setup/spec.md` 에서 별도 처리.
- **알림 권한 denied 후 재요청 배너 (NotificationDeniedBanner)**: OwnerScaffold 에 포함되어 있으나 UI 디자인 세부 조정은 향후 개선 가능.
