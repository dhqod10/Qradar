import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/notification_settings_entity.dart';
import 'package:qradar/domain/entities/user_role.dart';

part 'user_entity.freezed.dart';

@freezed
abstract class UserEntity with _$UserEntity {
  const factory UserEntity({
    required String uid,
    String? email,
    String? displayName,
    String? photoUrl,
    required String provider, // 'google' | 'kakao' | 'naver' | 'email'
    @Default(UserRole.customer) UserRole role,
    DateTime? createdAt,
    /// role='brand' 일 때만 존재. Firestore 콘솔에서 수동 발급.
    String? brandId,
    /// FCM 디바이스 토큰. 권한 거부/미발급 시 null.
    String? fcmToken,
    /// 마지막 FCM 토큰 갱신 시각 (운영 가시성).
    DateTime? fcmTokenUpdatedAt,
    /// 알림 권한 다이얼로그 노출 이력 (재요청 방지).
    @Default(false) bool notificationPermissionPrompted,
    /// 알림 카테고리별 on/off (부재 시 기본값 fallback).
    @Default(NotificationSettingsEntity())
    NotificationSettingsEntity notificationSettings,
  }) = _UserEntity;
}
