import 'package:qradar/domain/entities/account_deletion_preview.dart';

/// customer 본인 회원 탈퇴 (서버 `deleteMyAccount` callable — 소프트 삭제/익명화).
///
/// 클라이언트는 `users` 문서·Auth 계정을 직접 지우지 않는다. 실패는 `AccountDeletionException`.
abstract class AccountDeletionRepository {
  /// 진행 중 주문 수 · 소멸 Qoin 미리보기. **쓰기 0건.** 실패는 예외 (호출자는 탈퇴 버튼을 끈다 — fail-closed).
  Future<AccountDeletionPreview> preview();

  /// 탈퇴 실행. 중간 실패 후 다시 호출하면 이어서 진행된다 (멱등).
  Future<AccountDeletionResult> deleteMyAccount({String reason = ''});
}
