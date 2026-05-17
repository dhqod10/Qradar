import 'package:freezed_annotation/freezed_annotation.dart';

part 'selected_option.freezed.dart';

/// 카트 라인 안에 박힌 "선택된 옵션 1건" 스냅샷.
///
/// 가격/표시명을 시점 캡처해 저장하므로, 옵션 정의가 나중에 바뀌어도 카트는 안전하다.
/// 본 phase 에서는 인터페이스 호환용. 실제 사용은 Phase 1b 부터.
@freezed
abstract class SelectedOption with _$SelectedOption {
  const factory SelectedOption({
    required String groupId,
    required String groupName,
    required String itemId,
    required String label,
    @Default(0) int priceDelta,
  }) = _SelectedOption;
}
