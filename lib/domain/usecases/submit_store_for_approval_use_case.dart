import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/repositories/store_repository.dart';

/// 점주 매장 등록 / 핵심 필드 수정 / 재제출 통합 UseCase.
///
/// - [store.id] 가 빈 문자열이면 신규 등록 (status=pending 자동).
/// - [store.id] 가 있으면 핵심 필드 수정 (approved→pending 회귀 또는 rejected→T3 재제출).
class SubmitStoreForApprovalUseCase {
  final StoreRepository _repository;

  SubmitStoreForApprovalUseCase(this._repository);

  Future<void> call(StoreEntity store) {
    return _repository.submitStoreForApproval(store);
  }
}
