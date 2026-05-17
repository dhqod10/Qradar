import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/repositories/auth_repository.dart';

class SignInWithKakaoUseCase {
  final AuthRepository _repository;

  SignInWithKakaoUseCase(this._repository);

  Future<UserEntity> call() => _repository.signInWithKakao();
}
