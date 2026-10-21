import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/notification_category.dart';

part 'notification_settings_entity.freezed.dart';

/// 사용자 알림 설정 (Firestore `users/{uid}.notificationSettings`).
///
/// 기본값은 [NotificationCategory.defaultValue] 및 CF
/// `NOTIFICATION_SETTING_DEFAULTS` 와 일치해야 한다.
@freezed
abstract class NotificationSettingsEntity with _$NotificationSettingsEntity {
  const NotificationSettingsEntity._();

  const factory NotificationSettingsEntity({
    @Default(true) bool orderProgress,
    @Default(false) bool pickupComplete,
    @Default(true) bool newOrder,
    @Default(true) bool refundRequest,
  }) = _NotificationSettingsEntity;

  bool valueOf(NotificationCategory category) => switch (category) {
        NotificationCategory.orderProgress => orderProgress,
        NotificationCategory.pickupComplete => pickupComplete,
        NotificationCategory.newOrder => newOrder,
        NotificationCategory.refundRequest => refundRequest,
      };
}
