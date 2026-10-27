// TEMP_MIGRATION_CARD — 배포 ⑪ 정리 커밋에서 삭제한다.
import 'package:qradar/data/datasources/remote/migration_remote_data_source.dart';
import 'package:qradar/domain/entities/migration_report.dart';
import 'package:qradar/domain/repositories/migration_repository.dart';

class MigrationRepositoryImpl implements MigrationRepository {
  MigrationRepositoryImpl(this._ds);
  final MigrationRemoteDataSource _ds;

  @override
  Future<StoreApprovalMigrationReport> migrateStoreApprovalMeta({
    required bool dryRun,
  }) => _ds.migrateStoreApprovalMeta(dryRun: dryRun);

  @override
  Future<BrandProfileMigrationReport> migrateBrandPrivateProfile({
    required BrandMigrationStage stage,
    required bool dryRun,
  }) => _ds.migrateBrandPrivateProfile(stage: stage, dryRun: dryRun);
}
