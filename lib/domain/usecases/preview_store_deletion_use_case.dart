import 'package:qradar/domain/entities/store_deletion.dart';
import 'package:qradar/domain/repositories/store_deletion_repository.dart';

/// 매장 삭제 영향 범위 미리보기 (`deleteStore` dryRun). 쓰기 0건.
class PreviewStoreDeletionUseCase {
  final StoreDeletionRepository _repository;
  const PreviewStoreDeletionUseCase(this._repository);

  Future<StoreDeletionPreview> call(String storeId) =>
      _repository.preview(storeId);
}
