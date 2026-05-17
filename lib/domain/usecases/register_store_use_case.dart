import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/repositories/store_repository.dart';

class RegisterStoreUseCase {
  final StoreRepository _repository;
  RegisterStoreUseCase(this._repository);

  /// 매장 등록. 반환값은 생성된 Firestore 문서 id.
  Future<String> call(StoreEntity store) => _repository.createStore(store);
}
