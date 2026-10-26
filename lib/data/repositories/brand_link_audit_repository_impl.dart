import 'package:qradar/data/datasources/remote/brand_link_audit_remote_data_source.dart';
import 'package:qradar/domain/entities/brand_link_audit_result.dart';
import 'package:qradar/domain/repositories/brand_link_audit_repository.dart';

class BrandLinkAuditRepositoryImpl implements BrandLinkAuditRepository {
  final BrandLinkAuditRemoteDataSource _ds;
  BrandLinkAuditRepositoryImpl(this._ds);

  @override
  Future<BrandLinkAuditResult> audit() => _ds.audit();
}
