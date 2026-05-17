import 'package:flutter/material.dart';

/// 앱 전체 색상 토큰의 팔레트 모음.
///
/// 각 팔레트는 `abstract final class` + `static const` 로 정의되어 전체가
/// 컴파일 타임 상수다. [AppColors]는 이 중 한 팔레트를 가리키며, 테마 전환은
/// [AppColors] 파일 상단의 클래스 참조를 find/replace 하면 된다 (예:
/// `LightMidnightAccentPalette` → `DarkMidnightPalette`).
///
/// 새 팔레트를 추가하려면 같은 필드 셋을 가진 `abstract final class`를
/// 선언한 뒤 [AppColors]에서 참조 클래스명을 바꾸면 된다.
///
/// 주의: Dart `const` 제약상 인스턴스 필드 위임(`palette.primary`)은
/// const 컨텍스트에서 허용되지 않으므로, static const 멤버 방식을 사용한다.
///
/// ── 구성 토큰 규약 ─────────────────────────────────────────────────
///  Brand     : primary / primaryLight / primaryBright / primaryDeep / onPrimary / accent
///  Surfaces  : background / surface / surfaceElevated / border
///  Text      : textHeading / textBody / textMuted
///  Semantic  : success / error / warning / info
///  Misc      : backgroundGradient / brightness
/// ───────────────────────────────────────────────────────────────────

/// 라이트 테마 — 화이트 바탕 + 미드나잇 포인트 (현재 활성).
abstract final class LightMidnightAccentPalette {
  // Brand
  static const Color primary = Color(0xFF0F172A);      // midnight navy
  static const Color primaryLight = Color(0xFF334155); // slate-700
  static const Color primaryBright = Color(0xFF38BDF8);// sky-400 (로고색 유지)
  static const Color primaryDeep = Color(0xFF020617);  // slate-950
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFFFFD700);       // gold

  // Surfaces
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF3F4F6);      // gray-100
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);       // gray-200

  // Text
  static const Color textHeading = Color(0xFF0F172A);
  static const Color textBody = Color(0xFF1F2937);     // gray-800
  static const Color textMuted = Color(0xFF6B7280);    // gray-500

  // Semantic
  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF0EA5E9);

  // Misc
  static const Gradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
  );
  static const Brightness brightness = Brightness.light;
}

/// 다크 테마 — 미드나잇 바탕 (기존 컨셉, 팔레트 스왑 대기).
abstract final class DarkMidnightPalette {
  // Brand
  static const Color primary = Color(0xFF0EA5E9);
  static const Color primaryLight = Color(0xFF7DD3FC);
  static const Color primaryBright = Color(0xFF38BDF8);
  static const Color primaryDeep = Color(0xFF2563EB);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFFFFD700);

  // Surfaces
  static const Color background = Color(0xFF060D1A);
  static const Color surface = Color(0xFF0F172A);
  static const Color surfaceElevated = Color(0xFF1E293B);
  static const Color border = Color(0xFF1E293B);

  // Text
  static const Color textHeading = Color(0xFFF8FAFC);
  static const Color textBody = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF64748B);

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF38BDF8);

  // Misc
  static const Gradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF060D1A), Color(0xFF0F172A)],
  );
  static const Brightness brightness = Brightness.dark;
}
