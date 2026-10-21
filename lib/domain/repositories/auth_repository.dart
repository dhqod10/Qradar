import 'package:qradar/domain/entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> signInWithGoogle();
  Future<UserEntity> signInWithKakao();
  Future<UserEntity> signInWithNaver();
  Future<UserEntity> signInWithEmail({
    required String email,
    required String password,
  });
  Future<UserEntity> signUpWithEmail({
    required String email,
    required String password,
  });
  Future<void> signOut();
  Stream<UserEntity?> get authStateChanges;

  /// 현재 로그인된 사용자 (없으면 null). 동기 조회.
  UserEntity? get currentUser;
}
