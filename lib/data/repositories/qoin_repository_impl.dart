import 'package:qradar/data/datasources/remote/qoin_remote_data_source.dart';
import 'package:qradar/domain/entities/qoin_config_entity.dart';
import 'package:qradar/domain/entities/qoin_transaction_entity.dart';
import 'package:qradar/domain/repositories/qoin_config_admin_repository.dart';
import 'package:qradar/domain/repositories/qoin_repository.dart';

/// [QoinRepository] + [QoinConfigAdminRepository] 구현. 의존: [QoinRemoteDataSource] 만.
class QoinRepositoryImpl implements QoinRepository, QoinConfigAdminRepository {
  final QoinRemoteDataSource _ds;

  QoinRepositoryImpl(this._ds);

  @override
  Stream<List<QoinTransactionEntity>> watchTransactions(
    String uid, {
    required int limit,
  }) =>
      _ds.watchTransactions(uid, limit: limit);

  @override
  Stream<QoinConfigEntity?> watchConfig() => _ds.watchConfig();

  @override
  Future<void> saveAccrualRate(double rate) => _ds.saveAccrualRate(rate);

  @override
  Future<void> setEnabled(bool enabled) => _ds.setEnabled(enabled);
}
