import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/repositories/auth_repository.dart';

class SignInWithNaverUseCase {
  final AuthRepository _repository;

  SignInWithNaverUseCase(this._repository);

  Future<UserEntity> call() => _repository.signInWithNaver();
}