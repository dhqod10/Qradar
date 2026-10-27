// TEMP_MIGRATION_CARD — 배포 ⑪ 정리 커밋에서 삭제한다.
import 'package:qradar/domain/entities/migration_report.dart';

abstract class MigrationRepository {
  /// 실패는 `MigrationCallException`. `dryRun:true` 는 쓰기 0.
  Future<StoreApprovalMigrationReport> migrateStoreApprovalMeta({
    required bool dryRun,
  });

  Future<BrandProfileMigrationReport> migrateBrandPrivateProfile({
    required BrandMigrationStage stage,
    required bool dryRun,
  });
}
