import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/repositories/store_repository.dart';

/// 매장 단건 조회 UseCase (admin 상세 진입용).
class GetStoreByIdUseCase {
  final StoreRepository _repository;

  GetStoreByIdUseCase(this._repository);

  Future<StoreEntity?> call(String storeId) {
    return _repository.getById(storeId);
  }
}
