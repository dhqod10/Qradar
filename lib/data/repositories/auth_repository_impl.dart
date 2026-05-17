import 'package:qradar/data/datasources/remote/auth_remote_data_source.dart';
import 'package:qradar/data/models/user_model.dart';
import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _dataSource;

  AuthRepositoryImpl(this._dataSource);

  @override
  Future<UserEntity> signInWithGoogle() async {
    final model = await _dataSource.signInWithGoogle();
    return model.toEntity();
  }

  @override
  Future<UserEntity> signInWithKakao() async {
    final model = await _dataSource.signInWithKakao();
    return model.toEntity();
  }

  @override
  Future<UserEntity> signInWithNaver() async {
    final model = await _dataSource.signInWithNaver();
    return model.toEntity();
  }

  @override
  Future<UserEntity> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final model = await _dataSource.signInWithEmail(email: email, password: password);
    return model.toEntity();
  }

  @override
  Future<UserEntity> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final model = await _dataSource.signUpWithEmail(email: email, password: password);
    return model.toEntity();
  }

  @override
  Future<void> signOut() => _dataSource.signOut();

  @override
  Stream<UserEntity?> get authStateChanges {
    return _dataSource.authStateChanges.map((model) => model?.toEntity());
  }
}
