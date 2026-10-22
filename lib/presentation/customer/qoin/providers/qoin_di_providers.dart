import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/qoin_remote_data_source.dart';
import 'package:qradar/data/repositories/qoin_repository_impl.dart';
import 'package:qradar/domain/repositories/qoin_config_admin_repository.dart';
import 'package:qradar/domain/repositories/qoin_repository.dart';
import 'package:qradar/domain/usecases/save_qoin_accrual_rate_use_case.dart';
import 'package:qradar/domain/usecases/set_qoin_enabled_use_case.dart';
import 'package:qradar/domain/usecases/watch_qoin_config_use_case.dart';
import 'package:qradar/domain/usecases/watch_qoin_transactions_use_case.dart';

final qoinRemoteDataSourceProvider = Provider<QoinRemoteDataSource>((ref) {
  return QoinRemoteDataSource();
});

final _qoinRepositoryImplProvider = Provider<QoinRepositoryImpl>((ref) {
  return QoinRepositoryImpl(ref.watch(qoinRemoteDataSourceProvider));
});

final qoinRepositoryProvider = Provider<QoinRepository>(
  (ref) => ref.watch(_qoinRepositoryImplProvider),
);

final qoinConfigAdminRepositoryProvider = Provider<QoinConfigAdminRepository>(
  (ref) => ref.watch(_qoinRepositoryImplProvider),
);

final watchQoinTransactionsUseCaseProvider =
    Provider<WatchQoinTransactionsUseCase>((ref) {
  return WatchQoinTransactionsUseCase(ref.watch(qoinRepositoryProvider));
});

final watchQoinConfigUseCaseProvider = Provider<WatchQoinConfigUseCase>((ref) {
  return WatchQoinConfigUseCase(ref.watch(qoinRepositoryProvider));
});

final saveQoinAccrualRateUseCaseProvider =
    Provider<SaveQoinAccrualRateUseCase>((ref) {
  return SaveQoinAccrualRateUseCase(
    ref.watch(qoinConfigAdminRepositoryProvider),
  );
});

final setQoinEnabledUseCaseProvider = Provider<SetQoinEnabledUseCase>((ref) {
  return SetQoinEnabledUseCase(ref.watch(qoinConfigAdminRepositoryProvider));
});
