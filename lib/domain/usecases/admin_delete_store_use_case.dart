import 'package:qradar/domain/entities/store_deletion.dart';
import 'package:qradar/domain/repositories/store_deletion_repository.dart';

/// admin 매장 삭제 (서버 `deleteStore` 실행). 점주용 삭제 UseCase 를 대체한다.
class AdminDeleteStoreUseCase {
  final StoreDeletionRepository _repository;
  const AdminDeleteStoreUseCase(this._repository);

  Future<StoreDeletionResult> call(String storeId, {required String reason}) =>
      _repository.delete(storeId, reason: reason.trim());
}
