import 'package:qradar/domain/entities/store_grade.dart';

/// 등급 의미 문구 (선택 카드 단일 진실원).
extension StoreGradeCopy on StoreGrade {
  /// 굵게 표기되는 이름.
  String get reviewName => switch (this) {
    StoreGrade.s => '최고예요',
    StoreGrade.a => '좋아요',
    StoreGrade.b => '보통이에요',
    StoreGrade.c => '아쉬워요',
  };

  /// 1줄 설명.
  String get reviewDescription => switch (this) {
    StoreGrade.s => '다시 찾고, 주변에 먼저 추천하고 싶은 매장이에요',
    StoreGrade.a => '만족스러웠고 또 방문할 의향이 있어요',
    StoreGrade.b => '무난했지만 아쉬운 점도 있었어요',
    StoreGrade.c => '기대에 못 미쳤고 개선이 필요해요',
  };
}
