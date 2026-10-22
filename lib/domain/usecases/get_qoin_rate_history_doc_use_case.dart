import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/domain/repositories/qoin_rate_repository.dart';

/// 이력 문서 1건 직접 읽기. 중단 배너의 본문 수치(처리 수/전체 수)용 보조 읽기다 — 판정 출처가 아니다 (spec §21.1).
class GetQoinRateHistoryDocUseCase {
  final QoinRateRepository _repo;
  const GetQoinRateHistoryDocUseCase(this._repo);

  Future<QoinRateChangeEntity?> call(
    QoinRateScope scope,
    String targetId,
    String historyId,
  ) {
    if (targetId.isEmpty || historyId.isEmpty) return Future.value(null);
    return _repo.fetchHistory(scope, targetId, historyId);
  }
}
