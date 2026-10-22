import 'package:qradar/domain/repositories/qoin_config_admin_repository.dart';

/// 적립 on/off (kill switch). 적립률 폼과 독립된 저장 경로.
class SetQoinEnabledUseCase {
  final QoinConfigAdminRepository _repo;
  const SetQoinEnabledUseCase(this._repo);

  Future<void> call(bool enabled) => _repo.setEnabled(enabled);
}
