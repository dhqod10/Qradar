import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/repositories/user_repository.dart';

class GetOrCreateUserProfileUseCase {
  final UserRepository _repository;
  GetOrCreateUserProfileUseCase(this._repository);

  Future<UserEntity> call(UserEntity authUser) =>
      _repository.getOrCreateUserProfile(authUser);
}
