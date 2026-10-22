/// 적립률 callable 실패 분류.
///
/// - [rejected]       서버가 확정적으로 거부 (권한 없음 / 입력 무효 / 대상 없음 / 이미 진행 중 …). 반영되지 않았다.
/// - [unknownOutcome] 타임아웃 / 네트워크 끊김 — **서버에서는 반영됐을 수 있다.** 재시도를 권하면 안 된다.
enum QoinRateFailureKind { rejected, unknownOutcome }

class QoinRateException implements Exception {
  const QoinRateException(
    this.kind, {
    this.code,
    this.legacyZeroCount,
    this.legacyZeroStoreIds = const [],
  });
  final QoinRateFailureKind kind;

  /// 서버 에러 코드 (`permission-denied` 등).
  final String? code;

  /// TRANSITIONAL(spec §20.4.5): 일괄 적용 레거시 가드(`failed-precondition`)가 담아 보낸 레거시 0 매장 수.
  final int? legacyZeroCount;
  final List<String> legacyZeroStoreIds;

  // TRANSITIONAL(spec §20.4.5)
  bool get isLegacyZeroGuard => legacyZeroCount != null;

  bool get isUnknownOutcome => kind == QoinRateFailureKind.unknownOutcome;

  @override
  String toString() => 'QoinRateException($kind, $code)';
}
