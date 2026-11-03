import 'package:qradar/domain/entities/account_deletion_preview.dart';
import 'package:qradar/domain/repositories/account_deletion_repository.dart';

/// 회원 탈퇴 미리보기 (`deleteMyAccount` dryRun). 쓰기 0건.
class PreviewAccountDeletionUseCase {
  final AccountDeletionRepository _repository;
  const PreviewAccountDeletionUseCase(this._repository);

  Future<AccountDeletionPreview> call() => _repository.preview();
}
