/// 매장 삭제로 사라지는 데이터의 개수 (`deleteStore` CF 가 센다).
///
/// 같은 카운트 함수를 `dryRun` 과 실행이 공유한다 (spec §11.3). **dryRun 숫자는 스냅샷이 아니다** —
/// 삭제 이력에 기록되는 값은 서버가 실행 시점에 다시 센 값이므로 화면 숫자를 이력에 쓰지 않는다.
class StoreDeletionAffected {
  const StoreDeletionAffected({
    this.menuItems = 0,
    this.menuOverrides = 0,
    this.subCategories = 0,
    this.optionGroups = 0,
    this.qoinRateHistory = 0,
    this.images = 0,
    this.inFlightOrders = 0,
  });

  final int menuItems;
  final int menuOverrides;
  final int subCategories;
  final int optionGroups;
  final int qoinRateHistory;
  final int images;

  /// 진행 중인 주문 (`paid`/`accepted`/`making`/`ready`). 1건 이상이면 삭제할 수 없다.
  final int inFlightOrders;
}

/// `deleteStore(dryRun: true)` 결과 — 쓰기 0건.
class StoreDeletionPreview {
  const StoreDeletionPreview({
    required this.affected,
    this.alreadyDeleted = false,
  });

  final StoreDeletionAffected affected;

  /// 서버가 `{alreadyDeleted: true}` 만 돌려준 경우 (매장 문서 없음 + 이력 `done`).
  final bool alreadyDeleted;

  /// 진행 중인 주문 때문에 삭제할 수 없는가 (`blockedBy.inFlightOrders > 0`).
  bool get isBlocked => affected.inFlightOrders > 0;
}

/// `deleteStore(dryRun: false)` 결과.
class StoreDeletionResult {
  const StoreDeletionResult({this.deletionId, this.alreadyDeleted = false});

  /// 삭제 이력 문서 ID. `alreadyDeleted` 면 null 일 수 있다.
  final String? deletionId;
  final bool alreadyDeleted;
}
