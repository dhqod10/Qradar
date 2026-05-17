import 'package:qradar/domain/entities/user_role.dart';
import 'package:qradar/domain/repositories/user_repository.dart';

class DowngradeToCustomerUseCase {
  final UserRepository _repository;
  DowngradeToCustomerUseCase(this._repository);

  Future<void> call(String uid) =>
      _repository.updateRole(uid: uid, role: UserRole.customer);
}
