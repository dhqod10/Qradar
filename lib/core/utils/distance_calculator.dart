import 'dart:math' as math;

/// Haversine 공식을 사용해 두 좌표 간 거리를 킬로미터(km) 단위로 계산.
class DistanceCalculator {
  DistanceCalculator._();

  static const double _earthRadiusKm = 6371.0;

  static double calculateKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  static double _toRadians(double degree) => degree * math.pi / 180.0;

  /// "1.2km" 형식으로 포맷.
  /// 1km 미만은 "m" 단위로 표시.
  static String formatKm(double km) {
    if (km < 1.0) {
      return '${(km * 1000).round()}m';
    }
    return '${km.toStringAsFixed(1)}km';
  }
}
