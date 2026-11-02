import 'package:freezed_annotation/freezed_annotation.dart';

part 'business_hours.freezed.dart';

/// 요일 하나의 영업 구간. "HH:mm" 24시 KST. `open > close` = 자정 넘김 (심야 영업).
@freezed
abstract class BusinessDayHours with _$BusinessDayHours {
  const factory BusinessDayHours({
    required String open,
    required String close,
  }) = _BusinessDayHours;
}

/// 매장 영업 스케줄 (store_business_schedule).
///
/// [weeklyHours] key = 요일(1=월 … 7=일, ISO-8601). **엔트리 부재 = 그날 정기 휴무.**
/// 빈 맵 = 점주가 명시 저장한 "전체 휴무".
/// 스케줄이 **아예 없는 것**(= 시간 제한 없음, 항상 영업)은 `StoreEntity.businessHours == null` 로 표현한다 (필드 부재 ≠ 빈 맵).
@freezed
abstract class BusinessHours with _$BusinessHours {
  const BusinessHours._();

  const factory BusinessHours({
    @Default(<int, BusinessDayHours>{}) Map<int, BusinessDayHours> weeklyHours,
  }) = _BusinessHours;

  /// 순수 판정 모듈(`core/utils/store_sellability.dart`)의 입력 형태.
  Map<int, ({String open, String close})> get scheduleInput => {
        for (final e in weeklyHours.entries)
          e.key: (open: e.value.open, close: e.value.close),
      };
}
