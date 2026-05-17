import 'package:qradar/domain/entities/user_role.dart';
import 'package:qradar/domain/repositories/user_repository.dart';

class UpgradeToOwnerUseCase {
  final UserRepository _repository;
  UpgradeToOwnerUseCase(this._repository);

  Future<void> call(String uid) =>
      _repository.updateRole(uid: uid, role: UserRole.owner);
}
