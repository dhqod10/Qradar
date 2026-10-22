/// 데이터 소스에서 권한 부족(Firestore `permission-denied`)이 발생했을 때
/// data 레이어가 변환해 던지는 예외.
///
/// presentation 은 Firebase 를 import 할 수 없으므로 이 예외로 권한 에러를 구분한다.
class PermissionDeniedException implements Exception {
  const PermissionDeniedException([this.message = '권한이 없어요']);

  final String message;

  @override
  String toString() => 'PermissionDeniedException: $message';
}
