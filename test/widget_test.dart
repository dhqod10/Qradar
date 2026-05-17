import 'package:flutter_test/flutter_test.dart';
import 'package:qradar/core/utils/distance_calculator.dart';
import 'package:qradar/core/utils/grade_calculator.dart';
import 'package:qradar/domain/entities/store_grade.dart';

void main() {
  group('GradeCalculator', () {
    test('fromAverage maps thresholds to the correct grade', () {
      expect(GradeCalculator.fromAverage(4.0), StoreGrade.s);
      expect(GradeCalculator.fromAverage(3.5), StoreGrade.s);
      expect(GradeCalculator.fromAverage(3.4), StoreGrade.a);
      expect(GradeCalculator.fromAverage(2.5), StoreGrade.a);
      expect(GradeCalculator.fromAverage(2.0), StoreGrade.b);
      expect(GradeCalculator.fromAverage(1.4), StoreGrade.c);
    });

    test('fromReviews falls back to C when empty', () {
      expect(GradeCalculator.fromReviews(const []), StoreGrade.c);
    });
  });

  group('DistanceCalculator', () {
    test('formatKm switches to meters under 1km', () {
      expect(DistanceCalculator.formatKm(0.2), '200m');
      expect(DistanceCalculator.formatKm(1.25), '1.3km');
    });

    test('calculateKm returns 0 for identical points', () {
      final d = DistanceCalculator.calculateKm(
        lat1: 37.5665,
        lon1: 126.9780,
        lat2: 37.5665,
        lon2: 126.9780,
      );
      expect(d, lessThan(0.0001));
    });
  });
}
