// TEMP_PRICE_AUDIT_CARD — 배포 ⑩ 정리 커밋에서 삭제한다.
import 'package:qradar/domain/entities/price_audit_report.dart';

abstract class PriceAuditRepository {
  /// 읽기 전용. 실패는 `MigrationCallException`.
  Future<PriceAuditReport> audit();
}
