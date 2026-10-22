/// 익명 작성자 표기. `Qrator` + uid 에서 유도한 4자리 코드.
///
/// uid **앞 4자**를 쓰면 소셜 로그인 사용자가 전부 같은 코드가 된다.
/// Custom Token 경로가 uid 에 provider 접두사를 붙이기 때문이다
/// (`functions/src/verifyKakaoToken.ts:82` → `kakao_...`,
///  `functions/src/verifyNaverToken.ts:82` → `naver_...`).
/// 그 경우 Kakao 사용자는 전원 `Qrator kaka`, Naver 는 전원 `Qrator nave` 가 되어
/// "작성자를 구분한다" 는 목적(A3)이 달성되지 않는다.
///
/// 그래서 uid **전체**를 FNV-1a 로 해싱해 4자리 16진수를 만든다.
/// - 접두사 형식과 무관하게 분포한다
/// - 같은 uid 는 언제나 같은 코드 (플랫폼·실행 간 안정)
/// - uid 원문을 역산할 수 없다
String maskedQratorName(String uid) {
  if (uid.isEmpty) return 'Qrator';

  // FNV-1a 32bit. Dart 의 String.hashCode 는 버전 간 안정성이 보장되지 않아 쓰지 않는다.
  var hash = 0x811c9dc5;
  for (final unit in uid.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }

  final code = (hash & 0xFFFF).toRadixString(16).padLeft(4, '0');
  return 'Qrator $code';
}
