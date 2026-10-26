import 'package:qradar/domain/entities/brand_link_audit_result.dart';
import 'package:qradar/domain/repositories/brand_link_audit_repository.dart';

class AuditBrandLinksUseCase {
  final BrandLinkAuditRepository _repo;
  const AuditBrandLinksUseCase(this._repo);

  Future<BrandLinkAuditResult> call() => _repo.audit();
}
