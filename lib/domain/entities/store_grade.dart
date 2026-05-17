import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 매장 품질 등급.
///
/// Qrator(사용자)가 매장에 남긴 평가의 평균값으로 결정.
/// 내부 점수: S=4, A=3, B=2, C=1.
enum StoreGrade {
  s,
  a,
  b,
  c;

  /// Firestore 저장값 → 등급.
  static StoreGrade fromString(String value) {
    switch (value.toUpperCase()) {
      case 'S':
        return StoreGrade.s;
      case 'A':
        return StoreGrade.a;
      case 'B':
        return StoreGrade.b;
      case 'C':
      default:
        return StoreGrade.c;
    }
  }

  /// Firestore 저장값.
  String get asString {
    switch (this) {
      case StoreGrade.s:
        return 'S';
      case StoreGrade.a:
        return 'A';
      case StoreGrade.b:
        return 'B';
      case StoreGrade.c:
        return 'C';
    }
  }

  /// UI 표기("S급" 등).
  String get label {
    switch (this) {
      case StoreGrade.s:
        return 'S급';
      case StoreGrade.a:
        return 'A급';
      case StoreGrade.b:
        return 'B급';
      case StoreGrade.c:
        return 'C급';
    }
  }

  /// 내부 점수.
  int get score {
    switch (this) {
      case StoreGrade.s:
        return 4;
      case StoreGrade.a:
        return 3;
      case StoreGrade.b:
        return 2;
      case StoreGrade.c:
        return 1;
    }
  }
}

extension StoreGradeColor on StoreGrade {
  /// 등급별 주색상 (배지·악센트에 사용).
  Color get color {
    switch (this) {
      case StoreGrade.s:
        return AppColors.accent;
      case StoreGrade.a:
        return AppColors.primaryBright;
      case StoreGrade.b:
        return AppColors.primaryLight;
      case StoreGrade.c:
        return AppColors.textMuted;
    }
  }
}
