import 'package:qradar/domain/entities/user_role.dart';
import 'package:qradar/domain/repositories/user_repository.dart';

class UpgradeToBrandUseCase {
  final UserRepository _repository;
  UpgradeToBrandUseCase(this._repository);

  Future<void> call(String uid) =>
      _repository.updateRole(uid: uid, role: UserRole.brand);
}
