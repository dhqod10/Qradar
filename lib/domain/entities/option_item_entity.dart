import 'package:freezed_annotation/freezed_annotation.dart';

part 'option_item_entity.freezed.dart';

/// 옵션 그룹 안의 개별 항목.
///
/// 예: 온도 그룹의 "아이스"(priceDelta 0), 샷 그룹의 "+1샷"(priceDelta 500).
@freezed
abstract class OptionItemEntity with _$OptionItemEntity {
  const factory OptionItemEntity({
    required String id,
    required String label,
    @Default(0) int priceDelta,
  }) = _OptionItemEntity;
}
