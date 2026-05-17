import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
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
    return UserModel(
      uid: doc.id,
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      provider: (data['provider'] as String?) ?? 'unknown',
      role: (data['role'] as String?) ?? 'customer',
      createdAt: createdAtTs is Timestamp ? createdAtTs.toDate() : null,
      brandId: data['brandId'] as String?,
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
