import Flutter
import UIKit
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, MessagingDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // ⚠️ FirebaseApp.configure() 호출 금지 — firebase_core 4.x 는 pigeon channel 기반.
    // Flutter 측 Firebase.initializeApp() 이 native 초기화까지 자동 처리.
    // 여기서 미리 configure() 호출하면 pigeon channel 등록 전에 FirebaseApp 인스턴스 생성되어
    // Flutter 측에서 "Unable to establish connection on channel" 에러 발생.

    // APNs 권한 / 토큰 등록 (시뮬레이터는 실제 APNs 토큰 발급 안 됨 — 무해)
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Flutter 3.41 implicit engine 패턴 — plugin 등록 + Messaging delegate 설정.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // FirebaseMessaging delegate — plugin 등록 직후 설정해야 firebase_core 와 충돌 없음
    Messaging.messaging().delegate = self
  }

  // APNs 토큰 → FirebaseMessaging 에 전달
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("[AppDelegate] APNs registration failed: \(error)")
  }

  // FCM 토큰 갱신 콜백 (Flutter FcmRemoteDataSource.onTokenRefresh 가 실제 처리)
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("[AppDelegate] FCM token refreshed")
  }
}
