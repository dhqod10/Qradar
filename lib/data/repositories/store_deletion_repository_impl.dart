import 'package:qradar/data/datasources/remote/authority_callables_remote_data_source.dart';
import 'package:qradar/domain/entities/store_deletion.dart';
import 'package:qradar/domain/repositories/store_deletion_repository.dart';

/// [StoreDeletionRepository] 구현 — `deleteStore` callable 위임.
class StoreDeletionRepositoryImpl implements StoreDeletionRepository {
  StoreDeletionRepositoryImpl(this._dataSource);
  final AuthorityCallablesRemoteDataSource _dataSource;

  @override
  Future<StoreDeletionPreview> preview(String storeId) =>
      _dataSource.previewDeleteStore(storeId);

  @override
  Future<StoreDeletionResult> delete(
    String storeId, {
    required String reason,
  }) => _dataSource.deleteStore(storeId, reason: reason);
}
