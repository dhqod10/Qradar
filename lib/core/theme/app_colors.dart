import 'package:flutter/material.dart';
import 'package:qradar/core/theme/color_palette.dart';

/// 앱 전역 색상 접근자.
///
/// ┌─────────────────────────────────────────────────────────────────┐
/// │ 테마 전환 방법                                                  │
/// │   아래 `_P`의 참조 클래스를 교체한다.                           │
/// │   예) LightMidnightAccentPalette → DarkMidnightPalette          │
/// │   (또는 그 반대)                                                │
/// │ 새 팔레트를 만들려면 [color_palette.dart]에 추가 후 여기 연결.  │
/// └─────────────────────────────────────────────────────────────────┘
///
/// 소셜 로그인 브랜드 색은 팔레트와 무관하게 고정 상수로 둔다.
typedef _P = LightMidnightAccentPalette;

class AppColors {
  AppColors._();

  // ── Brand ────────────────────────────────────────────────────────────
  static const Color primary = _P.primary;
  static const Color primaryLight = _P.primaryLight;
  static const Color primaryBright = _P.primaryBright;
  static const Color primaryDeep = _P.primaryDeep;
  static const Color onPrimary = _P.onPrimary;
  static const Color accent = _P.accent;

  // ── Surfaces ─────────────────────────────────────────────────────────
  static const Color background = _P.background;
  static const Color surface = _P.surface;
  static const Color surfaceElevated = _P.surfaceElevated;
  static const Color border = _P.border;

  // ── Text ─────────────────────────────────────────────────────────────
  static const Color textHeading = _P.textHeading;
  static const Color textBody = _P.textBody;
  static const Color textMuted = _P.textMuted;

  /// 이전 명칭 호환용 — 신규 코드는 [textHeading] 사용.
  static const Color textDark = _P.textHeading;

  /// 이전 명칭 호환용 — 신규 코드는 [textBody] 사용.
  static const Color textDefault = _P.textBody;

  // ── Semantic ─────────────────────────────────────────────────────────
  static const Color success = _P.success;
  static const Color error = _P.error;
  static const Color warning = _P.warning;
  static const Color info = _P.info;

  // ── Gradient ─────────────────────────────────────────────────────────
  static const Gradient backgroundGradient = _P.backgroundGradient;

  // ── Brightness (ThemeData 전달용) ────────────────────────────────────
  static const Brightness brightness = _P.brightness;

  // ── Social Login (팔레트 무관 고정) ──────────────────────────────────
  static const Color kakao = Color(0xFFFEE500);
  static const Color naver = Color(0xFF03C75A);
}
