import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/domain/repositories/user_repository.dart';

class WatchUserProfileUseCase {
  final UserRepository _repository;
  WatchUserProfileUseCase(this._repository);

  Stream<UserEntity?> call(String uid) => _repository.watchCurrent(uid);
}
