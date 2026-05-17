import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/repositories/store_repository.dart';

/// 매장 핵심 필드 수정 UseCase (결정 J, T2).
///
/// 핵심 필드: name / address / lat·lng / menuCategories / businessRegistrationNumber.
/// 저장 시 status=pending 회귀. rejected 상태에서는 T3 재제출 동작.
class UpdateStoreCoreFieldsUseCase {
  final StoreRepository _repository;

  UpdateStoreCoreFieldsUseCase(this._repository);

  Future<void> call(StoreEntity store) {
    return _repository.updateStoreCoreFields(store);
  }
}
