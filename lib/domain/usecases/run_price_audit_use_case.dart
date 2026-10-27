// TEMP_PRICE_AUDIT_CARD — 배포 ⑩ 정리 커밋에서 삭제한다.
import 'package:qradar/domain/entities/price_audit_report.dart';
import 'package:qradar/domain/repositories/price_audit_repository.dart';

class RunPriceAuditUseCase {
  const RunPriceAuditUseCase(this._repo);
  final PriceAuditRepository _repo;

  Future<PriceAuditReport> call() => _repo.audit();
}
