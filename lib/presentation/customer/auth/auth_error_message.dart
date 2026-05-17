/// Firebase Auth / 일반 인증 예외를 사용자 친화적 한국어 메시지로 변환.
///
/// raw 메시지 (예: `[firebase_auth/invalid-credential] The supplied auth ...`)
/// 가 그대로 다이얼로그에 노출되는 것을 방지한다. 매핑되지 않은 코드는
/// 기본 메시지로 fallback.
String authFriendlyMessage(Object error) {
  final raw = error.toString();
  // FirebaseAuthException 의 toString 패턴: "[firebase_auth/{code}] {message}"
  // PlatformException 등 다른 형식도 raw 안에 code 가 포함되는 경우가 많음.
  final lower = raw.toLowerCase();

  if (lower.contains('invalid-credential') ||
      lower.contains('wrong-password') ||
      lower.contains('user-not-found') ||
      lower.contains('invalid-login-credentials')) {
    return '이메일 또는 비밀번호가 올바르지 않아요.';
  }
  if (lower.contains('invalid-email')) {
    return '올바른 이메일 형식이 아니에요.';
  }
  if (lower.contains('user-disabled')) {
    return '사용이 중지된 계정이에요.';
  }
  if (lower.contains('too-many-requests')) {
    return '시도가 너무 많아요. 잠시 후 다시 시도해주세요.';
  }
  if (lower.contains('network-request-failed') ||
      lower.contains('network')) {
    return '네트워크 연결을 확인해주세요.';
  }
  if (lower.contains('email-already-in-use')) {
    return '이미 사용 중인 이메일이에요.';
  }
  if (lower.contains('weak-password')) {
    return '비밀번호가 너무 약해요. 6자 이상으로 설정해주세요.';
  }
  if (lower.contains('operation-not-allowed')) {
    return '현재 이 로그인 방식은 사용할 수 없어요.';
  }

  return '로그인에 실패했어요. 잠시 후 다시 시도해주세요.';
}
