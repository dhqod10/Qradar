import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/domain/repositories/menu_override_repository.dart';

/// 특정 매장의 가격 오버라이드 목록 실시간 감시 UseCase (brand 전용).
class WatchMenuOverridesByStoreUseCase {
  final MenuOverrideRepository _repository;

  WatchMenuOverridesByStoreUseCase(this._repository);

  Stream<List<MenuOverrideEntity>> call(String storeId) {
    return _repository.watchByStore(storeId);
  }
}
