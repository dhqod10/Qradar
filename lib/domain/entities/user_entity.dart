import 'package:freezed_annotation/freezed_annotation.dart';
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
  }) = _UserEntity;
}
