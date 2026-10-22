import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_results.dart';
import 'package:qradar/domain/repositories/qoin_rate_repository.dart';

/// 브랜드 적립률 설정 + 산하 매장 개별 설정 처리 (보존 / 덮어쓰기). 서버가 이력 1건을 남긴다.
/// [resumeHistoryId] 로 partial 재개 (이때 값은 보내지 않는다 — 이미 브랜드에 쓰여 있다).
class ApplyBrandQoinRateUseCase {
  final QoinRateRepository _repo;
  const ApplyBrandQoinRateUseCase(this._repo);

  Future<QoinBulkApplyResult> call({
    required String brandId,
    QoinRateValue? value,
    required QoinBulkMode mode,
    String? reason,
    String? resumeHistoryId,
  }) {
    if (brandId.isEmpty) throw ArgumentError.value(brandId, 'brandId');
    if (reason != null && reason.trim().length > QoinPolicy.reasonMaxLength) {
      throw ArgumentError.value(reason.length, 'reason', 'too long');
    }
    final trimmed = reason?.trim();
    final r = (trimmed == null || trimmed.isEmpty) ? null : trimmed;

    if (resumeHistoryId != null) {
      if (mode != QoinBulkMode.overwrite) {
        throw ArgumentError.value(mode, 'mode', 'resume is overwrite only');
      }
      return _repo.applyBrandRate(
        brandId: brandId,
        mode: mode,
        reason: r,
        resumeHistoryId: resumeHistoryId,
      );
    }
    if (value == null) throw ArgumentError.notNull('value');
    switch (value) {
      case QoinRateValueRate(:final tenths):
        if (!QoinPolicy.isValidTenths(tenths)) {
          throw ArgumentError.value(tenths, 'tenths', 'out of range');
        }
        return _repo.applyBrandRate(
          brandId: brandId,
          rate: QoinPolicy.rateFromTenths(tenths),
          mode: mode,
          reason: r,
        );
      case QoinRateValueInherit():
        return _repo.applyBrandRate(
          brandId: brandId,
          clear: true,
          mode: mode,
          reason: r,
        );
    }
  }
}
