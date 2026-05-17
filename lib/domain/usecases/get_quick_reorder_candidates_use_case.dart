import 'package:qradar/core/constants/recommendation_thresholds.dart';
import 'package:qradar/domain/entities/order_log_entity.dart';
import 'package:qradar/domain/entities/quick_reorder_candidate_entity.dart';
import 'package:qradar/domain/repositories/order_log_repository.dart';

/// "다시 주문하기" 카드 candidate 목록 stream.
///
/// 알고리즘:
/// 1. uid 없으면 `Stream.value(const [])`
/// 2. 가장 최근 OrderLog `quickReorderMaxItems` 건 take
/// 3. summary / total / paidAt 합성 → [QuickReorderCandidateEntity]
/// 4. sourceLog 동봉 (카트 채울 때 items 그대로 사용)
class GetQuickReorderCandidatesUseCase {
  final OrderLogRepository _repository;
  final String? Function() _currentUidGetter;

  GetQuickReorderCandidatesUseCase(this._repository, this._currentUidGetter);

  Stream<List<QuickReorderCandidateEntity>> call() {
    final uid = _currentUidGetter();
    if (uid == null) {
      return Stream<List<QuickReorderCandidateEntity>>.value(
        const <QuickReorderCandidateEntity>[],
      );
    }
    return _repository.watchUserLogs(uid).map(_toCandidates);
  }

  static List<QuickReorderCandidateEntity> _toCandidates(
    List<OrderLogEntity> logs,
  ) {
    if (logs.isEmpty) return const <QuickReorderCandidateEntity>[];
    final take = logs.length > RecommendationThresholds.quickReorderMaxItems
        ? logs.sublist(0, RecommendationThresholds.quickReorderMaxItems)
        : logs;
    return take
        .map(
          (log) => QuickReorderCandidateEntity(
            orderLogId: log.id,
            storeId: log.storeId,
            storeName: log.storeName,
            summary: _summarize(log.items),
            total: log.total,
            paidAt: log.paidAt,
            sourceLog: log,
          ),
        )
        .toList(growable: false);
  }

  static String _summarize(List<OrderLogItem> items) {
    if (items.isEmpty) return '';
    final first = items.first.menuItemName;
    if (items.length == 1) return first;
    return '$first 외 ${items.length - 1}';
  }
}
