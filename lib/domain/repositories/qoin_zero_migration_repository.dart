// TRANSITIONAL(spec §20.4.5): 임시 마이그레이션 자산. 정리 커밋에서 이 파일째 삭제한다.
import 'package:qradar/domain/entities/qoin_zero_migration_result.dart';

abstract class QoinZeroMigrationRepository {
  /// `qoinAccrualRate: 0` 인 매장·브랜드를 `qoinAccrualEnabled: false` 로 이전한다. [dryRun] 이면 쓰기 0.
  Future<QoinZeroMigrationResult> migrate({required bool dryRun});
}
