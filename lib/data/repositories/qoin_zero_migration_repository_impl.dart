// TRANSITIONAL(spec §20.4.5): 임시 마이그레이션 자산. 정리 커밋에서 이 파일째 삭제한다.
import 'package:qradar/data/datasources/remote/qoin_zero_migration_remote_data_source.dart';
import 'package:qradar/domain/entities/qoin_zero_migration_result.dart';
import 'package:qradar/domain/repositories/qoin_zero_migration_repository.dart';

class QoinZeroMigrationRepositoryImpl implements QoinZeroMigrationRepository {
  final QoinZeroMigrationRemoteDataSource _ds;
  QoinZeroMigrationRepositoryImpl(this._ds);

  @override
  Future<QoinZeroMigrationResult> migrate({required bool dryRun}) =>
      _ds.migrate(dryRun: dryRun);
}
