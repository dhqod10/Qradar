import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/qoin_rate_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/qoin_remote_data_source.dart';
import 'package:qradar/data/repositories/qoin_rate_repository_impl.dart';
import 'package:qradar/data/repositories/qoin_repository_impl.dart';
import 'package:qradar/domain/repositories/qoin_config_admin_repository.dart';
import 'package:qradar/domain/repositories/qoin_rate_repository.dart';
import 'package:qradar/domain/repositories/qoin_repository.dart';
import 'package:qradar/domain/usecases/apply_brand_qoin_rate_use_case.dart';
import 'package:qradar/domain/usecases/get_qoin_rate_history_doc_use_case.dart';
import 'package:qradar/domain/usecases/set_qoin_accrual_enabled_use_case.dart';
import 'package:qradar/domain/usecases/set_qoin_accrual_rate_use_case.dart';
import 'package:qradar/domain/usecases/set_qoin_enabled_use_case.dart';
import 'package:qradar/domain/usecases/watch_all_qoin_rate_history_use_case.dart';
import 'package:qradar/domain/usecases/watch_qoin_config_use_case.dart';
import 'package:qradar/domain/usecases/watch_qoin_rate_history_use_case.dart';
import 'package:qradar/domain/usecases/watch_qoin_transactions_use_case.dart';

// Qoin DI — customer / owner / brand / admin 이 공유하는 위치.
// (1차에서는 customer/qoin/providers 에 있어 admin 이 customer 를 import 했다 — 역할 간 import 정리.)

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

final setQoinEnabledUseCaseProvider = Provider<SetQoinEnabledUseCase>((ref) {
  return SetQoinEnabledUseCase(ref.watch(qoinConfigAdminRepositoryProvider));
});

// ── 적립률 (계층화) ───────────────────────────────────────────────────────────

final qoinRateRemoteDataSourceProvider = Provider<QoinRateRemoteDataSource>((
  ref,
) {
  return QoinRateRemoteDataSource();
});

final qoinRateRepositoryProvider = Provider<QoinRateRepository>((ref) {
  return QoinRateRepositoryImpl(ref.watch(qoinRateRemoteDataSourceProvider));
});

final setQoinAccrualRateUseCaseProvider = Provider<SetQoinAccrualRateUseCase>((
  ref,
) {
  return SetQoinAccrualRateUseCase(ref.watch(qoinRateRepositoryProvider));
});

final setQoinAccrualEnabledUseCaseProvider =
    Provider<SetQoinAccrualEnabledUseCase>((ref) {
      return SetQoinAccrualEnabledUseCase(
        ref.watch(qoinRateRepositoryProvider),
      );
    });

final applyBrandQoinRateUseCaseProvider = Provider<ApplyBrandQoinRateUseCase>((
  ref,
) {
  return ApplyBrandQoinRateUseCase(ref.watch(qoinRateRepositoryProvider));
});

final watchQoinRateHistoryUseCaseProvider =
    Provider<WatchQoinRateHistoryUseCase>((ref) {
      return WatchQoinRateHistoryUseCase(ref.watch(qoinRateRepositoryProvider));
    });

final watchAllQoinRateHistoryUseCaseProvider =
    Provider<WatchAllQoinRateHistoryUseCase>((ref) {
      return WatchAllQoinRateHistoryUseCase(
        ref.watch(qoinRateRepositoryProvider),
      );
    });

final getQoinRateHistoryDocUseCaseProvider =
    Provider<GetQoinRateHistoryDocUseCase>((ref) {
      return GetQoinRateHistoryDocUseCase(ref.watch(qoinRateRepositoryProvider));
    });
