import 'package:qradar/domain/entities/store_deletion.dart';

/// admin 전용 매장 삭제 (서버 `deleteStore` callable).
///
/// 클라이언트는 `stores/{id}` 를 직접 지우지 않는다 (Rules 도 admin 외 거부).
/// 실패는 `StoreDeletionException` 으로 던진다 — 호출자는 SDK 예외를 보지 않는다.
abstract class StoreDeletionRepository {
  /// 영향 범위 미리보기. **쓰기 0건.** 실패는 예외 (호출자는 삭제 버튼을 끈다 — fail-closed).
  Future<StoreDeletionPreview> preview(String storeId);

  /// 삭제 실행. [reason] 은 trim 후 2~200자 (서버가 재검증).
  /// 중간 실패 후 같은 매장으로 다시 호출하면 이어서 진행된다 (멱등).
  Future<StoreDeletionResult> delete(String storeId, {required String reason});
}
