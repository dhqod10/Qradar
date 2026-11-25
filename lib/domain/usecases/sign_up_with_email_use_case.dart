import 'package:qradar/domain/entities/demographics.dart';
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
    /// 선택 수집(통계 전용). 입력하지 않으면 null — 저장되지 않는다.
    Gender? gender,
    int? birthYear,
  }) =>
      _repository.signUpWithEmail(
        email: email,
        password: password,
        name: name,
        phone: phone,
        gender: gender,
        birthYear: birthYear,
      );
}
