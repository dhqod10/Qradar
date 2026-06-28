import 'package:qradar/domain/entities/notification_permission_status.dart';
import 'package:qradar/domain/entities/remote_notification_message.dart';

/// FCM 푸시 알림 Repository 인터페이스.
///
/// data 레이어의 `FcmRemoteDataSource` 를 감싸 FirebaseMessaging SDK 의존을
/// domain / presentation 에서 격리한다.
abstract class PushNotificationRepository {
  /// OS 알림 권한을 사용자에게 요청한다.
  Future<NotificationPermissionStatus> requestPermission();

  /// 현재 OS 알림 권한 상태를 반환한다 (요청 없이 조회만).
  Future<NotificationPermissionStatus> getPermissionStatus();

  /// 현재 FCM 디바이스 토큰을 반환한다. 권한 없으면 null.
  Future<String?> getToken();

  /// FCM 토큰 갱신 스트림. 로그인 상태에서 구독해야 한다.
  Stream<String> onTokenRefresh();

  /// 디바이스 측 FCM 토큰을 무효화한다 (로그아웃 시 호출).
  Future<void> deleteToken();

  /// 포그라운드 메시지 스트림.
  Stream<RemoteNotificationMessage> onMessage();

  /// 백그라운드 상태에서 알림 탭 스트림.
  Stream<RemoteNotificationMessage> onMessageOpenedApp();

  /// 앱 종료 상태에서 알림 탭 후 앱이 열렸을 때의 메시지를 1회 반환.
  Future<RemoteNotificationMessage?> getInitialMessage();

  /// iOS 포그라운드 알림 표시 옵션 설정.
  Future<void> setForegroundNotificationPresentationOptions({
    required bool alert,
    required bool badge,
    required bool sound,
  });
}
