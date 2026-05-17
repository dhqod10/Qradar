import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/domain/repositories/menu_override_repository.dart';

/// 가격 오버라이드 핵심 필드(priceOverride / excluded) 변경 UseCase.
///
/// status=pending 회귀 + submittedBy/At 갱신. brand 전용.
class UpsertMenuOverrideCoreUseCase {
  final MenuOverrideRepository _repository;

  UpsertMenuOverrideCoreUseCase(this._repository);

  Future<void> call(MenuOverrideEntity override) {
    return _repository.upsertOverrideCore(override);
  }
}
