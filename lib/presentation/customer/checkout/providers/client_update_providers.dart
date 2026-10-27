import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/app_config_remote_data_source.dart';
import 'package:qradar/data/repositories/app_config_repository_impl.dart';
import 'package:qradar/domain/repositories/app_config_repository.dart';
import 'package:qradar/domain/usecases/check_client_update_required_use_case.dart';

final appConfigRepositoryProvider = Provider<AppConfigRepository>(
  (ref) => AppConfigRepositoryImpl(AppConfigRemoteDataSource()),
);

/// 결제 경로 진입 직전에 부른다 (카트 `결제하기` · 체크아웃 결제 탭). 실패하면 false — 막지 않는다.
final checkClientUpdateRequiredUseCaseProvider =
    Provider<CheckClientUpdateRequiredUseCase>(
      (ref) => CheckClientUpdateRequiredUseCase(
        ref.watch(appConfigRepositoryProvider),
      ),
    );
