/// `deleteMyAccount(dryRun: true)` 결과 — 쓰기 0건.
class AccountDeletionPreview {
  const AccountDeletionPreview({
    required this.inFlightOrderCount,
    required this.qoinToForfeit,
    this.alreadyDeleted = false,
  });

  /// 진행 중인 주문 수 (`paid`/`accepted`/`making`/`ready`).
  final int inFlightOrderCount;

  /// 탈퇴 시 소멸될 Qoin (0 이상).
  final int qoinToForfeit;

  /// 서버가 `{alreadyDeleted: true}` 만 돌려준 경우.
  final bool alreadyDeleted;

  /// 진행 중 주문이 없어야 탈퇴할 수 있다.
  bool get canDelete => !alreadyDeleted && inFlightOrderCount == 0;
}

/// `deleteMyAccount(dryRun: false)` 결과.
class AccountDeletionResult {
  const AccountDeletionResult({
    this.forfeitedQoin = 0,
    this.alreadyDeleted = false,
  });
  final int forfeitedQoin;
  final bool alreadyDeleted;
}
