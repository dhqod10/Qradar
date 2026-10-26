/// 적립률 callable 실패 분류.
///
/// - [rejected]       서버가 확정적으로 거부 (권한 없음 / 입력 무효 / 대상 없음 / 이미 진행 중 …). 반영되지 않았다.
/// - [unknownOutcome] 타임아웃 / 네트워크 끊김 — **서버에서는 반영됐을 수 있다.** 재시도를 권하면 안 된다.
enum QoinRateFailureKind { rejected, unknownOutcome }

class QoinRateException implements Exception {
  const QoinRateException(
    this.kind, {
    this.code,
  });
  final QoinRateFailureKind kind;

  /// 서버 에러 코드 (`permission-denied` 등).
  final String? code;

  bool get isUnknownOutcome => kind == QoinRateFailureKind.unknownOutcome;

  @override
  String toString() => 'QoinRateException($kind, $code)';
}
