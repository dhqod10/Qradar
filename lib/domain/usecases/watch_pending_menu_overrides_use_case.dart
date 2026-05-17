import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/domain/repositories/menu_override_repository.dart';

/// admin 가격 오버라이드 승인 큐 (collectionGroup, status==pending) UseCase.
class WatchPendingMenuOverridesUseCase {
  final MenuOverrideRepository _repository;

  WatchPendingMenuOverridesUseCase(this._repository);

  Stream<List<MenuOverrideEntity>> call() {
    return _repository.watchPendingForAdmin();
  }
}
