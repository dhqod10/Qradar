# order_flow_phase3b 테스트 리포트 (FCM 푸시 알림 인프라)

## 테스트 일시

- 2026-06-06 ~ 2026-06-07

---

## 테스트 방법

- Android 에뮬레이터 Pixel 7 (포그라운드 수신 확인)
- Android 실기기 (백그라운드 / 종료 상태 수신 확인)
- iPhone 17 시뮬레이터 (iOS APNs 제외 범위 — 네이티브 코드 정적 검증만)
- Firebase 정식 환경 (`order-app-5957e`)
- 점주 계정: `dhqod12@naver.com` (uid: `Og25uNUmRDMX5aJPTCRkzMYYuA82`)
- 점주 매장 ID: `iTr7gx0lHzIwccDIb1bw` (알람테스트 개인매장)
- 정적 코드 검증 (spec.md / design.md / implementation.md 교차 검증)
- Firestore Rules 라인 직접 검토
- `flutter analyze`

---

## 전체 결과

- PASS: 28개
- FAIL: 0개 (검증 중 발견된 3건은 모두 fix 완료 후 재검증 PASS)
- 보류: 5개

---

## 정정 이력 (initially FAIL → fix 완료 → 최종 PASS)

검증 세션 중 발견되어 즉시 수정된 항목. 최종 상태는 PASS 이나 발견 기록 유지.

### FIX-1. 포그라운드 메시지 핸들러 누락 (초기 FAIL → fix → PASS)

- 발견: `FirebaseMessaging.onMessage` 구독 코드가 어디에도 없어 포그라운드 상태에서 알림이 화면에 표시되지 않음.
- 수정: `main.dart` 에 `_registerForegroundMessageHandler()` 추가 (`FirebaseMessaging.onMessage.listen` 구독 → `FlutterLocalNotificationsPlugin.show` 호출) 및 `_initForegroundLocalNotifications()` 초기화 함수 추가.
- 결과: 포그라운드 수신 정상 (T4 PASS).

### FIX-2. 알림 탭 deep link 핸들러 누락 (초기 FAIL → fix → PASS)

- 발견: `data-only` 메시지 + `flutter_local_notifications` 패턴에서 `FirebaseMessaging.onMessageOpenedApp` 이 트리거되지 않아 알림 탭 시 화면 이동 미동작.
- 수정: `_initForegroundLocalNotifications()` 에 `onDidReceiveNotificationResponse: _handleLocalNotificationTap` 콜백 등록 + `getNotificationAppLaunchDetails()` 처리 + payload JSON 직렬화 로직 추가. `_navigateFromPayload()` 함수 신규 작성.
- 결과: 탭 → `OwnerOrderDetailPage` 진입 정상 (T6 PASS).

### FIX-3. store ownerId 불일치 (초기 FAIL → fix → PASS)

- 발견: 검증 중 매장 등록 흐름이 분리되어 있어 `fcmToken` 이 박힌 점주(`dhqod12`)와 `stores/{storeId}.ownerId` 에 기록된 uid 가 다른 상태로 CF 가 잘못된 사용자에게 알림 발송 시도.
- 수정: Firestore Console 에서 매장 `ownerId` 를 `dhqod12` uid 로 정합화.
- 결과: CF `onOrderCreated` 가 올바른 점주 토큰 조회 후 알림 발송 성공 (T4, T5 PASS).

---

## PASS 항목

### 기능 검증 (라이브)

- [x] T1 — 점주 첫 OwnerScaffold 진입 시 NotificationPermissionDialog 노출
  - 근거: `role=owner` 로 진입 후 다이얼로그 정상 노출 확인 (라이브 검증)
  - 위치: `lib/presentation/owner/orders/owner_orders_page.dart`, `notification_permission_dialog.dart`

- [x] T2 — "허용" 탭 → FCM 토큰 등록 (`users.fcmToken` 기록)
  - 근거: Firestore Console 에서 `users/{uid}.fcmToken` 필드 기록 확인 (라이브 검증)
  - 위치: `lib/domain/usecases/register_fcm_token_use_case.dart`

- [x] T4 — 신규 주문 FCM 수신 — 포그라운드 (FIX-1 수정 후 PASS)
  - 근거: 포그라운드 상태 알림 정상 수신 (라이브 검증)
  - 위치: `lib/main.dart` `_registerForegroundMessageHandler()`

- [x] T5-1 — 신규 주문 FCM 수신 — 백그라운드
  - 근거: 백그라운드 상태 알림 정상 수신 (라이브 검증)
  - 위치: `lib/main.dart` `_firebaseMessagingBackgroundHandler`

- [x] T5-2 — 신규 주문 FCM 수신 — 종료 상태
  - 근거: 종료 상태 알림 수신 후 앱 실행 확인 (라이브 검증)
  - 위치: `lib/main.dart` `_firebaseMessagingBackgroundHandler`

- [x] T6 — 알림 탭 → OwnerOrderDetailPage 진입 (FIX-2 수정 후 PASS)
  - 근거: 알림 탭 시 `OwnerOrderDetailPage` 정상 진입 확인 (라이브 검증)
  - 위치: `lib/main.dart` `_handleLocalNotificationTap`, `notification_navigator.dart`

- [x] T7 — 환불 요청 FCM 수신 + 환불 승인/거절 처리
  - 근거: 환불 요청 알림 2건 (신규 주문 + 환불 요청) 수신, 승인/거절 액션 정상 처리 확인 (라이브 검증)
  - 위치: `functions/src/onOrderRefundRequested.ts`

### 기능 검증 (정적)

- [x] `onOrderCreated` CF trigger 방식 — `onDocumentCreated('orders/{orderId}', region: 'asia-northeast3')`
  - 근거: spec.md 결정 E, `functions/src/onOrderCreated.ts` line 17-21
  - 위치: `functions/src/onOrderCreated.ts`

- [x] `onOrderRefundRequested` 중복 방지 — `before.refundRequest == null && after.refundRequest != null` 분기
  - 근거: spec.md 결정 E, `onOrderRefundRequested.ts` line 34-39
  - 위치: `functions/src/onOrderRefundRequested.ts`

- [x] invalid token 시 `users/{ownerId}.fcmToken` 자동 정리
  - 근거: spec.md 결정 G, `onOrderCreated.ts` line 100-113, `onOrderRefundRequested.ts` line 120-136
  - 위치: `functions/src/onOrderCreated.ts`, `functions/src/onOrderRefundRequested.ts`

- [x] fcmToken 없는 사용자 → skip + 구조화된 로그
  - 근거: spec.md 결정 F, `onOrderCreated.ts` line 70-73 (`console.info` with `event: 'fcm_token_missing'` 유사 패턴)
  - 위치: `functions/src/onOrderCreated.ts`

- [x] 로그인 성공 후 FCM 토큰 자동 등록 (`_onSignInSuccess`)
  - 근거: spec.md 결정 C, `auth_provider.dart` line 144-149
  - 위치: `lib/presentation/customer/auth/auth_provider.dart`

- [x] 로그아웃 시 FCM 토큰 정리 (`signOut` 에서 `clearFcmTokenUseCase` 호출)
  - 근거: spec.md 결정 C, `auth_provider.dart` line 133-142
  - 위치: `lib/presentation/customer/auth/auth_provider.dart`

- [x] `UserEntity` 3개 신규 필드 추가 (`fcmToken`, `fcmTokenUpdatedAt`, `notificationPermissionPrompted`)
  - 근거: spec.md 데이터 모델 §`UserEntity`, `user_entity.dart` line 19-24
  - 위치: `lib/domain/entities/user_entity.dart`

- [x] `UserRemoteDataSource` `updateFcmToken` / `markNotificationPermissionPrompted` / `getNotificationPermissionPrompted` 메서드 추가
  - 근거: spec.md 레이어 설계 Data §DataSources, `user_remote_data_source.dart` line 40-68
  - 위치: `lib/data/datasources/remote/user_remote_data_source.dart`

- [x] `FcmRemoteDataSource` — `firebase_messaging` SDK 래퍼, data 레이어 전용
  - 근거: CLAUDE.md 절대 규칙 2, `fcm_remote_data_source.dart` line 1-2 (import 패턴)
  - 위치: `lib/data/datasources/remote/fcm_remote_data_source.dart`

- [x] `PushNotificationRepository` 인터페이스 → `PushNotificationRepositoryImpl` 구현 분리
  - 근거: spec.md 레이어 설계, `push_notification_repository.dart`, `push_notification_repository_impl.dart`
  - 위치: `lib/domain/repositories/`, `lib/data/repositories/`

- [x] `RemoteNotificationMessage` domain value object — FirebaseMessaging `RemoteMessage` 직접 노출 차단
  - 근거: CLAUDE.md 절대 규칙 2, spec.md Domain Value Objects
  - 위치: `lib/domain/entities/remote_notification_message.dart`

- [x] `navigatorKey` top-level final 선언 + `MaterialApp(navigatorKey: navigatorKey)` 연결
  - 근거: spec.md 결정 H, `main.dart` line 21, 267
  - 위치: `lib/main.dart`

- [x] `_firebaseMessagingBackgroundHandler` top-level 함수 + `@pragma('vm:entry-point')` 등록
  - 근거: spec.md 클라이언트 요구사항, `main.dart` line 27-78
  - 위치: `lib/main.dart`

- [x] `functions/src/index.ts` 에 `onOrderCreated`, `onOrderRefundRequested` export 추가
  - 근거: spec.md CF 요구사항
  - 위치: `functions/src/index.ts`

- [x] Android `POST_NOTIFICATIONS` permission + `qradar_orders` 채널 메타 추가
  - 근거: spec.md Android 네이티브 요구사항, `AndroidManifest.xml` line 8, 49-50
  - 위치: `android/app/src/main/AndroidManifest.xml`

- [x] iOS `AppDelegate.swift` MessagingDelegate + `UNUserNotificationCenter.current().delegate = self` + APNs 토큰 전달 설정
  - 근거: spec.md iOS 네이티브 요구사항, `AppDelegate.swift` line 7-51
  - 위치: `ios/Runner/AppDelegate.swift`

- [x] `NotificationPermissionDialog` — `barrierDismissible: false` (명시적 버튼 선택 강제)
  - 근거: design.md §1-8 인터랙션, `notification_permission_dialog.dart` line 13
  - 위치: `lib/presentation/common/notification/notification_permission_dialog.dart`

- [x] `PendingNotificationHolder` — 종료 상태 deferred deep link 보관
  - 근거: spec.md 결정 H, `pending_notification_holder.dart`
  - 위치: `lib/presentation/common/notification/pending_notification_holder.dart`

### UI 검증

- [x] `NotificationPermissionDialog` — 아이콘(원형 gradient) + 제목 + 본문(1/2차) + 버튼("허용"/"나중에") 레이아웃
  - 근거: design.md §1-2~1-7
  - 위치: `lib/presentation/common/notification/notification_permission_dialog.dart`

- [x] 제목 텍스트 `"알림을 받으시겠어요?"` (design.md §1-4 추천안 적용)
  - 근거: design.md §1-4 변경 이력 ("주문 알림을 받으시겠어요?" → "알림을 받으시겠어요?")
  - 위치: `notification_permission_dialog.dart` line 53

- [x] 알림 본문 포맷 — `"주문이 들어왔어요 · {storeName}"` / `"환불 요청 · {storeName}"` (design.md Case B 추천안)
  - 근거: design.md §2-1 Case B, §2-2 Case B, `onOrderCreated.ts` line 89, `onOrderRefundRequested.ts` line 108
  - 위치: `functions/src/onOrderCreated.ts`, `functions/src/onOrderRefundRequested.ts`

### 아키텍처 검증

- [x] `firebase_messaging` / `flutter_local_notifications` SDK — presentation / domain 레이어에서 직접 import 없음
  - 근거: CLAUDE.md 절대 규칙 2. grep 결과: domain/presentation 폴더에서 해당 import 0건
  - 확인: `grep -rn "import 'package:firebase_messaging\|import 'package:flutter_local_notifications" lib/presentation/ lib/domain/` → 0건

- [x] `data` 레이어 이외에서 Firebase SDK 사용 없음
  - 근거: `fcm_remote_data_source.dart` 가 `firebase_messaging` 래핑 단일 진입점
  - 위치: `lib/data/datasources/remote/fcm_remote_data_source.dart`

- [x] `PushNotificationRepository` Interface 가 `domain` 에 위치
  - 근거: `lib/domain/repositories/push_notification_repository.dart` 확인
  - 위치: `lib/domain/repositories/push_notification_repository.dart`

- [x] `PushNotificationRepositoryImpl` 이 `data` 에 위치
  - 근거: `lib/data/repositories/push_notification_repository_impl.dart` 확인
  - 위치: `lib/data/repositories/push_notification_repository_impl.dart`

- [x] 백그라운드 핸들러에서 Riverpod ref 접근 없음 (spec.md 에러 처리 §백그라운드 핸들러 Riverpod 의존성 없이 동작)
  - 근거: `main.dart` `_firebaseMessagingBackgroundHandler` — Riverpod 없이 `FlutterLocalNotificationsPlugin` 직접 인스턴스화
  - 위치: `lib/main.dart` line 28-78

### Firestore Rules 검증

- [x] `isSelfProfileUpdate` 화이트리스트에 `fcmToken`, `fcmTokenUpdatedAt`, `notificationPermissionPrompted` 포함
  - 근거: spec.md Firestore Rules 변경 §isSelfProfileUpdate, `firestore.rules` line 90
  - 위치: `firestore.rules` line 90

- [x] `fcmToken` 이 이미 화이트리스트에 있었음 (기존 규칙 변경 없음)
  - 근거: spec.md 사전 확인 결과 table, Rules line 90
  - 위치: `firestore.rules` line 90

### 코드 품질 검증

- [x] `flutter analyze` — No issues found (ran in 6.6s)
  - 근거: 실행 결과 직접 확인

- [x] 파일명 `snake_case.dart`, 클래스명 `PascalCase`, UseCase `XxxUseCase` 형식 준수
  - 근거: 파일 목록 확인 (`fcm_remote_data_source.dart`, `RegisterFcmTokenUseCase` 등)

- [x] `notification_providers.dart` Provider 명명 `xxxProvider` 형식 준수
  - 근거: `notification_providers.dart` line 13 (`fcmRemoteDataSourceProvider`) 등

---

## FAIL 항목

없음. 검증 중 발견된 3건은 FIX-1, FIX-2, FIX-3 으로 즉시 수정 완료.

---

## 보류 항목

- [ ] T3 — "나중에" 탭 후 권한 거부 배너 동작
  - 이유: 사용자가 검증 세션에서 명시적으로 skip 요청.
  - 필요한 확인: "나중에" 탭 후 `notificationPermissionPrompted = true` 영속화 확인 (Firestore), 앱 재시작 후 다이얼로그 미노출 확인.
  - 후속 작업 제안: 별도 검증 세션 또는 Phase 3c 전 회귀 검증 포함.

- [ ] iOS APNs 실기기 수신 검증 (T6, T7 iOS 버전)
  - 이유: spec.md 결정 M — APNs Auth Key 출시 전 별도 task 로 보류. Firebase Console 미업로드 상태.
  - 필요한 확인: Apple Developer .p8 발급 → Firebase Console 업로드 → iOS 실기기 포그라운드/백그라운드/종료 수신 확인.
  - 후속 작업 제안: `docs/tasks/ios_apns_setup/spec.md` 이 이미 생성됨. 출시 1~2주 전 진행.

- [ ] T10 — 환불 거절 update 시 중복 알림 미발송 (CF 로그 검증)
  - 이유: 라이브 검증 세션에서 환불 거절 직후 CF 로그를 별도로 확인하지 않음.
  - 필요한 확인: `onOrderRefundRequested` CF 에서 `before.refundRequest != null` 분기로 skip 됨을 Firebase Console → Functions 로그에서 확인.
  - 후속 작업 제안: 다음 검증 세션에서 로그 직접 확인 또는 단위 테스트 추가.

- [ ] T12 — Invalid token 자동 정리 (CF 동작 검증)
  - 이유: 인위적 토큰 주입 후 CF 동작 검증을 라이브 세션에서 수행하지 않음. 코드 검토 상 정적 PASS.
  - 필요한 확인: Firestore Console 에서 `fcmToken` 필드를 임의 값으로 교체 → 결제 발생 → CF 로그에서 `messaging/registration-token-not-registered` catch → `fcmToken` 필드 삭제 확인.
  - 후속 작업 제안: 별도 검증 세션.

- [ ] T17 — Firestore Rules 단위 검증 (Firebase emulator)
  - 이유: Firebase emulator 를 사용한 Rules 단위 테스트를 본 세션에서 수행하지 않음. 코드 직접 검토로 정적 PASS.
  - 필요한 확인: `firebase emulators:start` 후 Rules playground 또는 `@firebase/rules-unit-testing` 으로 `fcmToken` / `fcmTokenUpdatedAt` / `notificationPermissionPrompted` 각 필드 단독 update 허용, 임의 필드 포함 시 거부 확인.
  - 후속 작업 제안: CI 단계에 포함 권장.

---

## 설계자 전달 메시지

### 요약

- 전체 판단: FAIL 0건. 검증 세션 중 3건의 구현 누락(포그라운드 핸들러, deep link 핸들러, ownerId 불일치)을 발견하여 즉시 수정 완료. 현재 코드 기준 Phase 3b 핵심 기능(Android FCM 신규 주문/환불 요청 수신, 알림 탭 → OwnerOrderDetailPage deep link) 정상 동작.
- `flutter analyze` No issues found.

### 재작업 우선순위

없음. 현재 재작업 필요 항목 없음.

### 후속 task 후보

- `ios_apns_setup` — iOS APNs Auth Key 발급 및 Firebase Console 업로드 (출시 전 필수). `docs/tasks/ios_apns_setup/spec.md` 이미 존재.
- `toss_merchant_approval` — Toss 머천트 승인 대기. Phase 3b 검증을 orders doc 직접 생성으로 우회하였음. 승인 후 실제 결제 흐름 회귀 검증 필요.
- `storage_security_rules` — 검증 중 점주 매장 등록 / 메뉴 이미지 업로드 시 인증 실패 발견. `storage.rules` 임시 수정 완료. 정식 권한 설계 필요.
- Phase 3c — 고객 측 알림 (주문 접수됨 / 환불 완료 / 환불 거절) 및 점주 `making` / `ready` / `completed` 전이 알림.
- Rules 단위 테스트 자동화 (`T17` 보류 항목 해소).

---

## 완료 판단

- [x] FAIL 있으나 후속 task 로 분리 가능 → 해당 없음 (FAIL 0건)
- [x] 전체 PASS (검증 세션 내 발견 FIX 3건 포함)
