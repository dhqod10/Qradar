import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/store_grade.dart';

/// Kakao Maps(JS SDK / WebView) 연동 설정.
///
/// AppColors 는 [Color] 객체라 WebView HTML/JS 로 그대로 넘길 수 없다.
/// 등급별 마커 색상은 이 파일의 [markerColorHexForGrade] 에서
/// 단일 진실원(AppColors)으로부터 hex 문자열로 변환해 JS 측에 전달한다.
class MapConfig {
  MapConfig._();

  /// Kakao JavaScript SDK 키. `--dart-define=KAKAO_JS_KEY=xxx` 로 주입.
  static const String kakaoJsKey =
      String.fromEnvironment('KAKAO_JS_KEY', defaultValue: '');

  /// Kakao Maps 기본 줌 레벨 (약 1km 반경).
  static const int defaultZoomLevel = 5;

  /// WebView `loadHtmlString` baseUrl. Kakao 콘솔의
  /// "JavaScript SDK 도메인" 등록값과 일치해야 SDK 가 정상 로드됨.
  static const String webViewBaseUrl = 'http://localhost';

  /// 등급별 마커 색상 hex (JS 전달용).
  static String markerColorHexForGrade(StoreGrade grade) {
    switch (grade) {
      case StoreGrade.s:
        return _toHex(AppColors.accent);
      case StoreGrade.a:
        return _toHex(AppColors.primaryBright);
      case StoreGrade.b:
        return _toHex(AppColors.primary);
      case StoreGrade.c:
        return _toHex(AppColors.textMuted);
    }
  }

  static String _toHex(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
