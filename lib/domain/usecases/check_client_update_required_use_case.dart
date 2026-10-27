import 'package:qradar/core/constants/app_client_level.dart';
import 'package:qradar/core/utils/client_update.dart';
import 'package:qradar/domain/repositories/app_config_repository.dart';

/// 이 빌드가 결제 경로를 막아야 하는 구버전인가 (payment_price_authority H-01).
///
/// **fail-open**: 설정 읽기가 실패·시간 초과·값 없음이면 `false` (막지 않는다). 막는 것은 서버가 알려 준 최소 수준이 이 빌드의
/// 수준보다 **확인된 경우뿐**이다. 선검증과 같은 원칙 — 정상 손님의 결제를 이 게이트가 멈추면 안 된다.
class CheckClientUpdateRequiredUseCase {
  CheckClientUpdateRequiredUseCase(
    this._repo, {
    this.clientLevel = kPaymentClientLevel,
    this.timeout = const Duration(seconds: 3),
  });

  final AppConfigRepository _repo;
  final int clientLevel;
  final Duration timeout;

  Future<bool> call() async {
    try {
      final min = await _repo.fetchMinClientLevel().timeout(timeout);
      return isClientUpdateRequired(
        clientLevel: clientLevel,
        minClientLevel: min,
      );
    } catch (_) {
      return false;
    }
  }
}
