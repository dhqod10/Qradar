/// 비로그인 상태에서 인증이 필요한 동작을 시도했을 때 발생.
///
/// Repository 구현체가 토글 등 RW 동작 전에 uid 가 null 이면 던진다.
/// Presentation 은 사전 가드(다이얼로그)로 호출 자체를 막는 게 1차 방어선이고,
/// 본 예외는 race / 누락 가드 시의 안전망 역할.
class UnauthenticatedException implements Exception {
  const UnauthenticatedException([this.message = '로그인이 필요해요']);

  final String message;

  @override
  String toString() => 'UnauthenticatedException: $message';
}
