import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/entities/user_role.dart';

/// 사용자 프로필 Repository (Firestore `users/{uid}` 문서 전담).
///
/// Firebase Auth 세션과는 별개로, 역할(role)을 비롯한 추가 프로필 필드를 관리.
abstract class UserRepository {
  /// 인증 사용자 기준으로 `users/{uid}` 문서를 조회하되, 없으면 기본값(customer)으로 생성한 뒤 반환.
  Future<UserEntity> getOrCreateUserProfile(UserEntity authUser);

  /// role 업데이트.
  Future<void> updateRole({required String uid, required UserRole role});

  /// 현재 사용자 프로필 실시간 감시.
  Stream<UserEntity?> watchCurrent(String uid);
}
