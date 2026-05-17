/// 등급 계산 임계값 상수.
///
/// 사용자가 매장에 S/A/B/C 4단계로 평가를 남기면,
/// 내부 점수(S=4, A=3, B=2, C=1)의 평균을 구해 아래 임계값으로 최종 등급 판정.
///
/// 향후 Firebase Remote Config로 전환 가능하도록 상수로 격리.
class GradeThresholds {
  GradeThresholds._();

  // 내부 점수 (사용자에게 노출되지 않음)
  static const int sScore = 4;
  static const int aScore = 3;
  static const int bScore = 2;
  static const int cScore = 1;

  // 평균 점수 → 등급 판정 임계값
  static const double sMin = 3.5;
  static const double aMin = 2.5;
  static const double bMin = 1.5;
  // C급: 1.0 ~ 1.4

  // 주변 매장 조회 반경 (km)
  static const double nearbyRadiusKm = 20.0;

  // 주문 화면 매장 조회 반경 + 개수 상한
  static const double orderRadiusKm = 10.0;
  static const int orderStoresLimit = 50;

  // 기본 위치 (서울 시청) — 위치 권한 거부 시 폴백
  static const double defaultLatitude = 37.5665;
  static const double defaultLongitude = 126.9780;
}
