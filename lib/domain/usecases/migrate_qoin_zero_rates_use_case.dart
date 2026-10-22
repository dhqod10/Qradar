// TRANSITIONAL(spec §20.4.5): 임시 마이그레이션 자산. 정리 커밋에서 이 파일째 삭제한다.
import 'package:qradar/domain/entities/qoin_zero_migration_result.dart';
import 'package:qradar/domain/repositories/qoin_zero_migration_repository.dart';

class MigrateQoinZeroRatesUseCase {
  final QoinZeroMigrationRepository _repo;
  const MigrateQoinZeroRatesUseCase(this._repo);

  Future<QoinZeroMigrationResult> call({required bool dryRun}) =>
      _repo.migrate(dryRun: dryRun);
}
