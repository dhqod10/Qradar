import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/repositories/store_repository.dart';

/// 매장 운영 필드 수정 UseCase (결정 J, T2).
///
/// 운영 필드: businessHours / temporaryClosed / closedDates / phone / imageUrls / description / notice.
/// status / 승인 메타 모두 보존. 즉시 반영.
class UpdateStoreOperationFieldsUseCase {
  final StoreRepository _repository;

  UpdateStoreOperationFieldsUseCase(this._repository);

  Future<void> call(StoreEntity store) {
    return _repository.updateStoreOperationFields(store);
  }
}
