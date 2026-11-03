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
    /// 휴대폰 번호 (숫자만, 예: 01012345678). 이메일 가입 시 입력. 읽기 전용 PII — 화면에 노출/로그 금지.
    String? phone,
    required String provider, // 'google' | 'kakao' | 'naver' | 'email'
    @Default(UserRole.customer) UserRole role,
    DateTime? createdAt,
    /// role='brand' 일 때만 존재. **Cloud Function `claimSubmittedBrand` 만 쓴다** (클라이언트·Rules 로는 쓸 수 없다 —
    /// 권한 값이라 본인이 선언하면 임의 브랜드의 보유자가 된다). 교정은 admin 전용.
    String? brandId,
    /// FCM 디바이스 토큰. 권한 거부/미발급 시 null.
    String? fcmToken,
    /// 마지막 FCM 토큰 갱신 시각 (운영 가시성).
    DateTime? fcmTokenUpdatedAt,
    /// OS 권한 시트 소진 이력 (다이얼로그에서 `허용` 선택). 재노출 제외 가드.
    @Default(false) bool notificationPermissionPrompted,
    /// 알림 권한 다이얼로그에서 `나중에` 를 선택한 횟수. 부재 시 0 fallback.
    @Default(0) int notificationPermissionLaterCount,
    /// 알림 카테고리별 on/off (부재 시 기본값 fallback).
    @Default(NotificationSettingsEntity())
    NotificationSettingsEntity notificationSettings,
    /// Qoin 잔액. Cloud Function 만 쓴다 (고객 쓰기 불가). 필드 부재 → 0.
    /// **clamp 하지 않는다** — 원장 불변식(`qoinBalance == Σ amount`) 의 감사 수단.
    @Default(0) int qoinBalance,
    /// 계정 정지 여부 (admin_user_moderation). **읽기 전용** — Cloud Function 만 쓴다. 사유 등 메타는 앱에 매핑하지 않는다.
    /// 부재 → false. 판독용 신호일 뿐이며 진짜 집행은 Firebase Auth disabled + 토큰 revoke 다.
    @Default(false) bool suspended,
  }) = _UserEntity;
}
