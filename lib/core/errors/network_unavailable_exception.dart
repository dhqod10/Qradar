/// 네트워크 불가(Firestore `unavailable` 등)를 data 레이어가 변환해 던지는 예외.
/// presentation 은 Firebase 를 import 할 수 없으므로 이 예외로 구분한다.
class NetworkUnavailableException implements Exception {
  const NetworkUnavailableException([this.message = '네트워크에 연결할 수 없어요']);

  final String message;

  @override
  String toString() => 'NetworkUnavailableException: $message';
}
