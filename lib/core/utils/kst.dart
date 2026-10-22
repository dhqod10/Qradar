/// KST(UTC+9, DST 없음) 변환 유틸. 매출 기간 경계와 표시 시각의 단일 변환 지점.
///
/// 규약
/// - "instant" : 절대 시각. UTC 로 정규화된 [DateTime] (`isUtc == true`).
/// - "KST wall": KST 달력/시계 값을 UTC 플래그 [DateTime] 에 그대로 담은 값.
///   `year/month/day/hour/weekday` 가 곧 한국 시각이다. 연산 전용이며
///   저장/전송하지 않는다.
class Kst {
  Kst._();

  static const Duration offset = Duration(hours: 9);

  /// instant → KST wall.
  static DateTime toWall(DateTime instant) => instant.toUtc().add(offset);

  /// KST wall (년월일시분초) → instant.
  static DateTime fromWall(
    int year, [
    int month = 1,
    int day = 1,
    int hour = 0,
    int minute = 0,
  ]) => DateTime.utc(year, month, day, hour, minute).subtract(offset);
}
