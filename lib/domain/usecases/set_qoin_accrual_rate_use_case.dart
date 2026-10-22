import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/domain/entities/qoin_rate_results.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/domain/repositories/qoin_rate_repository.dart';

/// 한 범위(전역/브랜드/매장)의 적립률 설정. 1차 `SaveQoinAccrualRateUseCase` 를 대체한다.
///
/// 화면 검증을 우회해도 100배 오입력이 저장되지 않도록 한 번 더 막는다 ([ArgumentError]):
/// - 비율은 0.1% 단위 정수 [QoinRateValue.rate] 로만 받는다 (범위는 `QoinPolicy`).
/// - 전역은 `inherit` 불가 — 전역은 항상 유효한 숫자여야 한다.
/// - 사유는 최대 [QoinPolicy.reasonMaxLength] 자.
/// 서버(`setQoinAccrualRate`)는 같은 경계를 다시 검증한다.
class SetQoinAccrualRateUseCase {
  final QoinRateRepository _repo;
  const SetQoinAccrualRateUseCase(this._repo);

  Future<QoinRateSetResult> call({
    required QoinRateScope scope,
    String? targetId,
    required QoinRateValue value,
    String? reason,
  }) {
    if (scope != QoinRateScope.global &&
        (targetId == null || targetId.isEmpty)) {
      throw ArgumentError.value(targetId, 'targetId', 'required for $scope');
    }
    _checkReason(reason);
    switch (value) {
      case QoinRateValueRate(:final tenths):
        if (!QoinPolicy.isValidTenths(tenths)) {
          throw ArgumentError.value(tenths, 'tenths', 'out of range');
        }
        return _repo.setRate(
          scope: scope,
          targetId: targetId,
          rate: QoinPolicy.rateFromTenths(tenths),
          reason: _normalize(reason),
        );
      case QoinRateValueInherit():
        _requireNotGlobal(scope);
        return _repo.setRate(
          scope: scope,
          targetId: targetId,
          clear: true,
          reason: _normalize(reason),
        );
    }
  }

  static void _requireNotGlobal(QoinRateScope scope) {
    if (scope == QoinRateScope.global) {
      throw ArgumentError.value(scope, 'scope', 'global must be a valid rate');
    }
  }
}

void _checkReason(String? reason) {
  if (reason != null && reason.trim().length > QoinPolicy.reasonMaxLength) {
    throw ArgumentError.value(reason.length, 'reason', 'too long');
  }
}

String? _normalize(String? reason) {
  final t = reason?.trim();
  return (t == null || t.isEmpty) ? null : t;
}
