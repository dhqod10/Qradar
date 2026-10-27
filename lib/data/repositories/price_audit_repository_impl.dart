// TEMP_PRICE_AUDIT_CARD — 배포 ⑩ 정리 커밋에서 삭제한다.
import 'package:qradar/data/datasources/remote/price_audit_remote_data_source.dart';
import 'package:qradar/domain/entities/price_audit_report.dart';
import 'package:qradar/domain/repositories/price_audit_repository.dart';

class PriceAuditRepositoryImpl implements PriceAuditRepository {
  PriceAuditRepositoryImpl(this._ds);
  final PriceAuditRemoteDataSource _ds;

  @override
  Future<PriceAuditReport> audit() => _ds.audit();
}
