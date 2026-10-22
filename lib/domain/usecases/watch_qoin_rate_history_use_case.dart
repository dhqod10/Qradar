import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/qoin_rate_scope.dart';
import 'package:qradar/domain/repositories/qoin_rate_repository.dart';

/// 한 대상(전역/브랜드/매장)의 적립률 변경 이력. 점주·브랜드·admin 공용 (읽기 전용).
class WatchQoinRateHistoryUseCase {
  final QoinRateRepository _repo;
  const WatchQoinRateHistoryUseCase(this._repo);

  Stream<List<QoinRateChangeEntity>> call(
    QoinRateScope scope,
    String targetId, {
    required int limit,
  }) => _repo.watchHistory(scope, targetId, limit: limit);
}
