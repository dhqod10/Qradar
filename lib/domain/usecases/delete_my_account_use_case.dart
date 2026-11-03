import 'package:qradar/domain/entities/account_deletion_preview.dart';
import 'package:qradar/domain/repositories/account_deletion_repository.dart';

/// 회원 탈퇴 실행 (서버 `deleteMyAccount`). 성공 후 세션 정리(signOut)는 호출자 몫이다.
class DeleteMyAccountUseCase {
  final AccountDeletionRepository _repository;
  const DeleteMyAccountUseCase(this._repository);

  Future<AccountDeletionResult> call({String reason = ''}) =>
      _repository.deleteMyAccount(reason: reason.trim());
}
