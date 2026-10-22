// TRANSITIONAL(brand_authorization_hardening §4): 임시 점검 자산. 정리 커밋에서 이 파일째 삭제한다.
import 'package:qradar/domain/entities/brand_link_audit_result.dart';

abstract class BrandLinkAuditRepository {
  /// 브랜드 계정·브랜드·매장의 연결 상태를 분류해 보고한다. **쓰기 0** (인자도 없다).
  Future<BrandLinkAuditResult> audit();
}
