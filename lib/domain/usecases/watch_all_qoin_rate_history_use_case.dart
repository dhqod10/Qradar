import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/repositories/qoin_rate_repository.dart';

/// 전체 적립률 변경 이력 (admin 전용, collectionGroup).
class WatchAllQoinRateHistoryUseCase {
  final QoinRateRepository _repo;
  const WatchAllQoinRateHistoryUseCase(this._repo);

  Stream<List<QoinRateChangeEntity>> call({required int limit}) =>
      _repo.watchAllHistory(limit: limit);
}
