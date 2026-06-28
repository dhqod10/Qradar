import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:qradar/domain/entities/notification_permission_status.dart';
import 'package:qradar/domain/entities/remote_notification_message.dart';

/// Firebase Messaging SDK 래퍼 (data 레이어 전용).
///
/// `firebase_messaging` / `flutter_local_notifications` 는 이 클래스에서만 사용.
/// domain / presentation 레이어는 이 클래스를 통해서만 접근.
class FcmRemoteDataSource {
  FcmRemoteDataSource({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  // ── 로컬 알림 채널 초기화 ─────────────────────────────────────────────────

  /// Android 알림 채널 + 로컬 알림 플러그인 초기화.
  /// `main.dart` 에서 앱 시작 시 1회 호출.
  Future<void> initialize() async {
    const androidChannel = AndroidNotificationChannel(
      'qradar_orders',
      'Qradar 주문 알림',
      description: '새 주문 및 환불 요청 알림',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    const initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );

    await _localNotifications.initialize(initSettings);
  }

  // ── 권한 ──────────────────────────────────────────────────────────────────

  Future<NotificationPermissionStatus> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return _mapAuthStatus(settings.authorizationStatus);
  }

  Future<NotificationPermissionStatus> getPermissionStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return _mapAuthStatus(settings.authorizationStatus);
  }

  NotificationPermissionStatus _mapAuthStatus(
      AuthorizationStatus status) {
    return switch (status) {
      AuthorizationStatus.authorized => NotificationPermissionStatus.authorized,
      AuthorizationStatus.provisional =>
        NotificationPermissionStatus.provisional,
      AuthorizationStatus.denied => NotificationPermissionStatus.denied,
      _ => NotificationPermissionStatus.notDetermined,
    };
  }

  // ── 토큰 ──────────────────────────────────────────────────────────────────

  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  Stream<String> onTokenRefresh() => _messaging.onTokenRefresh;

  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
    } catch (_) {}
  }

  // ── 메시지 스트림 ──────────────────────────────────────────────────────────

  Stream<RemoteNotificationMessage> onMessage() {
    return FirebaseMessaging.onMessage.map(
      (msg) => RemoteNotificationMessage.fromData(
        Map<String, dynamic>.from(msg.data),
      ),
    );
  }

  Stream<RemoteNotificationMessage> onMessageOpenedApp() {
    return FirebaseMessaging.onMessageOpenedApp.map(
      (msg) => RemoteNotificationMessage.fromData(
        Map<String, dynamic>.from(msg.data),
      ),
    );
  }

  Future<RemoteNotificationMessage?> getInitialMessage() async {
    final msg = await _messaging.getInitialMessage();
    if (msg == null) return null;
    return RemoteNotificationMessage.fromData(
      Map<String, dynamic>.from(msg.data),
    );
  }

  // ── iOS 포그라운드 알림 표시 설정 ─────────────────────────────────────────

  Future<void> setForegroundNotificationPresentationOptions({
    required bool alert,
    required bool badge,
    required bool sound,
  }) async {
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: alert,
      badge: badge,
      sound: sound,
    );
  }

  // ── 로컬 알림 표시 (백그라운드 핸들러용 — data-only 메시지) ────────────────

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'qradar_orders',
      'Qradar 주문 알림',
      channelDescription: '새 주문 및 환불 요청 알림',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _localNotifications.show(id, title, body, details, payload: payload);
  }
}
