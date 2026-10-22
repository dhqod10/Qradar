import 'package:qradar/data/datasources/remote/qoin_rate_remote_data_source.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_results.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/domain/repositories/qoin_rate_repository.dart';

class QoinRateRepositoryImpl implements QoinRateRepository {
  final QoinRateRemoteDataSource _ds;
  QoinRateRepositoryImpl(this._ds);

  @override
  Future<QoinRateSetResult> setRate({
    required QoinRateScope scope,
    String? targetId,
    double? rate,
    bool clear = false,
    String? reason,
  }) => _ds.setRate(
    scope: scope,
    targetId: targetId,
    rate: rate,
    clear: clear,
    reason: reason,
  );

  @override
  Future<QoinBulkApplyResult> applyBrandRate({
    required String brandId,
    double? rate,
    bool clear = false,
    required QoinBulkMode mode,
    String? reason,
    String? resumeHistoryId,
  }) => _ds.applyBrandRate(
    brandId: brandId,
    rate: rate,
    clear: clear,
    mode: mode,
    reason: reason,
    resumeHistoryId: resumeHistoryId,
  );

  @override
  Future<QoinAccrualEnabledResult> setAccrualEnabled({
    required QoinRateScope scope,
    required String targetId,
    required bool enabled,
    String? reason,
  }) => _ds.setAccrualEnabled(
    scope: scope,
    targetId: targetId,
    enabled: enabled,
    reason: reason,
  );

  @override
  Stream<List<QoinRateChangeEntity>> watchHistory(
    QoinRateScope scope,
    String targetId, {
    required int limit,
  }) => _ds.watchHistory(scope, targetId, limit: limit);

  @override
  Stream<List<QoinRateChangeEntity>> watchAllHistory({required int limit}) =>
      _ds.watchAllHistory(limit: limit);
}
