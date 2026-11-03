import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/repositories/auth_repository.dart';

class SignUpWithEmailUseCase {
  final AuthRepository _repository;

  SignUpWithEmailUseCase(this._repository);

  Future<UserEntity> call({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) =>
      _repository.signUpWithEmail(
        email: email,
        password: password,
        name: name,
        phone: phone,
      );
}
