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
}
