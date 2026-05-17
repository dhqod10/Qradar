import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/order_log_entity.dart';

part 'quick_reorder_candidate_entity.freezed.dart';

/// "다시 주문하기" 카드 1건.
///
/// 가장 최근 OrderLog 1~3건을 카드로 변환해 노출. 카드 onTap → 카트 채움 +
/// CartPage 진입. 채울 items 는 [sourceLog.items] 를 그대로 사용.
@freezed
abstract class QuickReorderCandidateEntity with _$QuickReorderCandidateEntity {
  const factory QuickReorderCandidateEntity({
    required String orderLogId,
    required String storeId,
    required String storeName,

    /// 메뉴 요약 — 첫 메뉴명 + 추가 항목 수. 예: `"아메리카노 외 1"`, 단일이면 `"아메리카노"`.
    required String summary,
    required int total,
    required DateTime paidAt,

    /// 카트 채울 때 items 그대로 사용.
    required OrderLogEntity sourceLog,
  }) = _QuickReorderCandidateEntity;
}
