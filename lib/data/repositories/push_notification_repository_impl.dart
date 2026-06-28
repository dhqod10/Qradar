import 'package:qradar/data/datasources/remote/fcm_remote_data_source.dart';
import 'package:qradar/domain/entities/notification_permission_status.dart';
import 'package:qradar/domain/entities/remote_notification_message.dart';
import 'package:qradar/domain/repositories/push_notification_repository.dart';

/// [PushNotificationRepository] 구현체.
///
/// [FcmRemoteDataSource] 를 감싸 domain 인터페이스를 구현한다.
class PushNotificationRepositoryImpl implements PushNotificationRepository {
  final FcmRemoteDataSource _dataSource;

  const PushNotificationRepositoryImpl(this._dataSource);

  @override
  Future<NotificationPermissionStatus> requestPermission() =>
      _dataSource.requestPermission();

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() =>
      _dataSource.getPermissionStatus();

  @override
  Future<String?> getToken() => _dataSource.getToken();

  @override
  Stream<String> onTokenRefresh() => _dataSource.onTokenRefresh();

  @override
  Future<void> deleteToken() => _dataSource.deleteToken();

  @override
  Stream<RemoteNotificationMessage> onMessage() => _dataSource.onMessage();

  @override
  Stream<RemoteNotificationMessage> onMessageOpenedApp() =>
      _dataSource.onMessageOpenedApp();

  @override
  Future<RemoteNotificationMessage?> getInitialMessage() =>
      _dataSource.getInitialMessage();

  @override
  Future<void> setForegroundNotificationPresentationOptions({
    required bool alert,
    required bool badge,
    required bool sound,
  }) =>
      _dataSource.setForegroundNotificationPresentationOptions(
        alert: alert,
        badge: badge,
        sound: sound,
      );
}
