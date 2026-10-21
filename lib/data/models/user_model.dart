import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/notification_category.dart';
import 'package:qradar/domain/entities/notification_settings_entity.dart';
import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/entities/user_role.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// 인증 응답 + Firestore `users/{uid}` 문서 매퍼.
///
/// - Auth 응답(JSON 직렬화): `fromJson` / `toJson` — 소셜 로그인 페이로드 호환용.
/// - Firestore 영속화: [UserModelFirestoreX] 확장 메서드 사용.
@freezed
abstract class UserModel with _$UserModel {
  const factory UserModel({
    required String uid,
    String? email,
    @JsonKey(name: 'display_name') String? displayName,
    @JsonKey(name: 'photo_url') String? photoUrl,
    required String provider,
    @Default('customer') String role,
    DateTime? createdAt,
    /// role='brand' 일 때만 존재. Firestore 콘솔에서 수동 발급.
    String? brandId,
    /// FCM 디바이스 토큰 (Phase 3b). JSON 직렬화 제외 (Firestore 전용 필드).
    @JsonKey(includeFromJson: false, includeToJson: false) String? fcmToken,
    /// 마지막 FCM 토큰 갱신 시각 (Phase 3b). JSON 직렬화 제외.
    @JsonKey(includeFromJson: false, includeToJson: false)
    DateTime? fcmTokenUpdatedAt,
    /// 알림 권한 다이얼로그 노출 이력 (Phase 3b). JSON 직렬화 제외.
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(false)
    bool notificationPermissionPrompted,
    /// 알림 카테고리별 설정 (Phase 3c-3). JSON 직렬화 제외.
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(NotificationSettingsEntity())
    NotificationSettingsEntity notificationSettings,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}

extension UserModelX on UserModel {
  UserEntity toEntity() => UserEntity(
        uid: uid,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        provider: provider,
        role: UserRole.fromString(role),
        createdAt: createdAt,
        brandId: brandId,
        fcmToken: fcmToken,
        fcmTokenUpdatedAt: fcmTokenUpdatedAt,
        notificationPermissionPrompted: notificationPermissionPrompted,
        notificationSettings: notificationSettings,
      );
}

/// Firestore `users/{uid}` 문서 매퍼.
extension UserModelFirestoreX on UserModel {
  /// 신규 프로필 생성용 맵. `createdAt` 은 서버 타임스탬프로 기록.
  Map<String, dynamic> toFirestoreForCreate() => <String, dynamic>{
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'provider': provider,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

class UserModelFactory {
  const UserModelFactory._();

  static UserModel fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdAtTs = data['createdAt'];
    final fcmTokenUpdatedAtTs = data['fcmTokenUpdatedAt'];
    return UserModel(
      uid: doc.id,
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      provider: (data['provider'] as String?) ?? 'unknown',
      role: (data['role'] as String?) ?? 'customer',
      createdAt: createdAtTs is Timestamp ? createdAtTs.toDate() : null,
      brandId: data['brandId'] as String?,
      fcmToken: data['fcmToken'] as String?,
      fcmTokenUpdatedAt: fcmTokenUpdatedAtTs is Timestamp
          ? fcmTokenUpdatedAtTs.toDate()
          : null,
      notificationPermissionPrompted:
          (data['notificationPermissionPrompted'] as bool?) ?? false,
      notificationSettings: _parseNotificationSettings(
        data['notificationSettings'],
      ),
    );
  }

  /// map 이 아니거나 키 부재/비bool 이면 해당 키만 기본값 fallback.
  static NotificationSettingsEntity _parseNotificationSettings(Object? raw) {
    if (raw is! Map) return const NotificationSettingsEntity();
    bool read(NotificationCategory c) {
      final v = raw[c.asString];
      return v is bool ? v : c.defaultValue;
    }

    return NotificationSettingsEntity(
      orderProgress: read(NotificationCategory.orderProgress),
      pickupComplete: read(NotificationCategory.pickupComplete),
      newOrder: read(NotificationCategory.newOrder),
      refundRequest: read(NotificationCategory.refundRequest),
    );
  }

  static UserModel fromEntity(UserEntity entity) {
    return UserModel(
      uid: entity.uid,
      email: entity.email,
      displayName: entity.displayName,
      photoUrl: entity.photoUrl,
      provider: entity.provider,
      role: entity.role.asString,
      createdAt: entity.createdAt,
    );
  }
}
