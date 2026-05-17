import 'package:qradar/core/utils/distance_calculator.dart';
import 'package:qradar/domain/entities/user_location.dart';

/// 두 좌표 간 거리(km)를 계산. 도메인 레벨에서 재사용 가능한 단일 책임.
class CalculateDistanceUseCase {
  CalculateDistanceUseCase();

  double call({required UserLocation from, required UserLocation to}) {
    return DistanceCalculator.calculateKm(
      lat1: from.latitude,
      lon1: from.longitude,
      lat2: to.latitude,
      lon2: to.longitude,
    );
  }
}
