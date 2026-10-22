import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/domain/entities/qoin_rate_results.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/domain/repositories/qoin_rate_repository.dart';

/// 매장·브랜드의 `적립 사용` 스위치 (단일 책임). 전역은 스위치가 없다 — 전역 비상 정지는 `SetQoinEnabledUseCase`.
///
/// 화면 검증을 우회해도 막는다 ([ArgumentError]): 전역 scope / 빈 targetId / 사유 길이. 서버도 같은 경계를 다시 검증한다.
class SetQoinAccrualEnabledUseCase {
  final QoinRateRepository _repo;
  const SetQoinAccrualEnabledUseCase(this._repo);

  Future<QoinAccrualEnabledResult> call({
    required QoinRateScope scope,
    required String targetId,
    required bool enabled,
    String? reason,
  }) {
    if (scope == QoinRateScope.global) {
      throw ArgumentError.value(scope, 'scope', 'global has no switch');
    }
    if (targetId.isEmpty) {
      throw ArgumentError.value(targetId, 'targetId', 'required');
    }
    if (reason != null && reason.trim().length > QoinPolicy.reasonMaxLength) {
      throw ArgumentError.value(reason.length, 'reason', 'too long');
    }
    final t = reason?.trim();
    return _repo.setAccrualEnabled(
      scope: scope,
      targetId: targetId,
      enabled: enabled,
      reason: (t == null || t.isEmpty) ? null : t,
    );
  }
}
