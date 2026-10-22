/// 점주 매출 조회의 읽기 비용 방어선 (owner_sales spec §7).
///
/// 클라이언트 집계이므로 조회 문서 수 = read 비용이다. 상한에 닿으면
/// `StoreSalesEntity.isTruncated` 로 사용자에게 "일부만 집계" 를 알린다.
class SalesQueryLimits {
  SalesQueryLimits._();

  /// 단일 기간 query 의 최대 문서 수. 최신순이므로 초과 시 오래된 주문이 잘린다.
  static const int maxDocumentsPerQuery = 1000;

  /// 현재 달 기준 과거로 이동 가능한 최대 개월 수.
  static const int maxMonthsBack = 12;
}
