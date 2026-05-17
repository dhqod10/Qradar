import 'package:qradar/core/constants/grade_thresholds.dart';
import 'package:qradar/domain/entities/store_grade.dart';

/// 평균 점수를 StoreGrade로 변환.
///
/// 평균 점수는 Qrator가 남긴 S/A/B/C 평가의 산술 평균(S=4 … C=1).
/// 리뷰가 없는 경우 C 등급으로 폴백.
class GradeCalculator {
  GradeCalculator._();

  static StoreGrade fromAverage(double averageScore) {
    if (averageScore >= GradeThresholds.sMin) return StoreGrade.s;
    if (averageScore >= GradeThresholds.aMin) return StoreGrade.a;
    if (averageScore >= GradeThresholds.bMin) return StoreGrade.b;
    return StoreGrade.c;
  }

  /// 리뷰 개별 등급 리스트로부터 최종 매장 등급 계산.
  /// 리뷰가 0개이면 C로 폴백.
  static StoreGrade fromReviews(List<StoreGrade> grades) {
    if (grades.isEmpty) return StoreGrade.c;
    final sum = grades.fold<int>(0, (acc, g) => acc + g.score);
    final avg = sum / grades.length;
    return fromAverage(avg);
  }
}
