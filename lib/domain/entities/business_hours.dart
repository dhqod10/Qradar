import 'package:freezed_annotation/freezed_annotation.dart';

part 'business_hours.freezed.dart';

/// 매장 운영시간.
///
/// MVP: 요일 구분 없이 매일 동일한 open/close 단일 구간만 지원.
/// [closedDays] 는 향후 확장 대비 필드만 유지하며 현 단계에서는 항상 빈 리스트.
@freezed
abstract class BusinessHours with _$BusinessHours {
  const factory BusinessHours({
    /// "HH:mm" 24시 포맷 (e.g. "09:00")
    required String openTime,
    required String closeTime,
    @Default(<int>[]) List<int> closedDays,
  }) = _BusinessHours;
}
