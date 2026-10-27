// TEMP_MIGRATION_CARD — 배포 ⑪ 정리 커밋에서 삭제한다.
import 'package:qradar/domain/entities/migration_report.dart';
import 'package:qradar/domain/repositories/migration_repository.dart';

class RunStoreApprovalMigrationUseCase {
  const RunStoreApprovalMigrationUseCase(this._repo);
  final MigrationRepository _repo;

  Future<StoreApprovalMigrationReport> call({required bool dryRun}) =>
      _repo.migrateStoreApprovalMeta(dryRun: dryRun);
}

class RunBrandProfileMigrationUseCase {
  const RunBrandProfileMigrationUseCase(this._repo);
  final MigrationRepository _repo;

  Future<BrandProfileMigrationReport> call({
    required BrandMigrationStage stage,
    required bool dryRun,
  }) => _repo.migrateBrandPrivateProfile(stage: stage, dryRun: dryRun);
}
