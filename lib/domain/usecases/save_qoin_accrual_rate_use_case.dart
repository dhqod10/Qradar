import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/domain/repositories/qoin_config_admin_repository.dart';

/// 적립률 저장. 퍼센트(0.1% 단위) → 비율 환산은 정수 연산으로 한다.
///
/// [percentTenths]: 0.1% 단위 정수 (30 = 3.0%). 범위 밖이면 [ArgumentError] —
/// 화면 검증을 우회해도 100배 오입력이 저장되지 않도록 한 번 더 막는다.
class SaveQoinAccrualRateUseCase {
  final QoinConfigAdminRepository _repo;
  const SaveQoinAccrualRateUseCase(this._repo);

  Future<void> call(int percentTenths) {
    if (!QoinPolicy.isValidTenths(percentTenths)) {
      throw ArgumentError.value(percentTenths, 'percentTenths', 'out of range');
    }
    return _repo.saveAccrualRate(QoinPolicy.rateFromTenths(percentTenths));
  }
}
