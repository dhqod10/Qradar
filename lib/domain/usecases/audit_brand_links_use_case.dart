// TRANSITIONAL(brand_authorization_hardening §4): 임시 점검 자산. 정리 커밋에서 이 파일째 삭제한다.
import 'package:qradar/domain/entities/brand_link_audit_result.dart';
import 'package:qradar/domain/repositories/brand_link_audit_repository.dart';

class AuditBrandLinksUseCase {
  final BrandLinkAuditRepository _repo;
  const AuditBrandLinksUseCase(this._repo);

  Future<BrandLinkAuditResult> call() => _repo.audit();
}
