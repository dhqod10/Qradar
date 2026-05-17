import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/repositories/auth_repository.dart';

class SignInWithEmailUseCase {
  final AuthRepository _repository;

  SignInWithEmailUseCase(this._repository);

  Future<UserEntity> call({required String email, required String password}) =>
      _repository.signInWithEmail(email: email, password: password);
}
