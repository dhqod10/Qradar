// TEMP_MIGRATION_CARD — 배포 ⑪ 정리 커밋에서 삭제한다.
import 'package:qradar/domain/entities/migration_report.dart';

enum MigrationCallFailure {
  /// `permission-denied` / `unauthenticated` — admin 이 아니다.
  permissionDenied,

  /// `deadline-exceeded` — 서버는 계속 돌고 있을 수 있다. "0건" 도 "실패 확정" 도 아니다.
  timeout,

  /// `unavailable` 등 — 서버에 닿지 못했다.
  network,

  /// `failed-precondition` — 서버가 이상치/무효 값을 이유로 실행을 멈췄다. 목록을 함께 싣는다.
  stoppedByServer,

  /// 응답 형식이 알아볼 수 없다.
  malformedResponse,

  failed,
}

class MigrationCallException implements Exception {
  const MigrationCallException(
    this.kind, {
    this.code,
    this.anomalies,
    this.invalid,
  });
  final MigrationCallFailure kind;

  /// `FirebaseFunctionsException.code`. 서버 message 는 싣지 않는다.
  final String? code;
  final List<String>? anomalies;
  final List<MigrationInvalidItem>? invalid;

  @override
  String toString() => 'MigrationCallException(${kind.name}, code: $code)';
}
