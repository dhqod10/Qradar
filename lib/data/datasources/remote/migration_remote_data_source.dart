// TEMP_MIGRATION_CARD — payment_server_authority 배포 ③⑤⑨ 용 임시 자산. 배포 ⑪ 정리 커밋에서 삭제한다.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:qradar/domain/entities/migration_call_exception.dart';
import 'package:qradar/domain/entities/migration_report.dart';

/// `migrateStoreApprovalMeta` / `migrateBrandPrivateProfile` (admin 전용 임시 callable, asia-northeast3).
///
/// **SDK 예외는 이 파일 밖으로 나가지 않는다.** 서버 message 는 어디에도 싣지 않는다.
/// 파서는 "없는 필드" 를 0 으로 채우지 않는다 (null 로 둔다) — 0건과 "그 분류가 응답에 없음" 을 구분하기 위해서다.
/// 형식이 깨진 항목은 건너뛰지 않고 응답 전체를 [MigrationCallFailure.malformedResponse] 로 처리한다.
class MigrationRemoteDataSource {
  MigrationRemoteDataSource({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFunctions _functions;

  // CF timeoutSeconds 540 보다 길게 — 클라이언트가 먼저 포기하지 않게.
  static const _timeout = Duration(seconds: 560);

  Future<StoreApprovalMigrationReport> migrateStoreApprovalMeta({
    required bool dryRun,
  }) async {
    final d = await _call('migrateStoreApprovalMeta', <String, dynamic>{
      'dryRun': dryRun,
    });
    return parseStore(d);
  }

  Future<BrandProfileMigrationReport> migrateBrandPrivateProfile({
    required BrandMigrationStage stage,
    required bool dryRun,
  }) async {
    final d = await _call('migrateBrandPrivateProfile', <String, dynamic>{
      'stage': stage.code,
      'dryRun': dryRun,
    });
    return parseBrand(d);
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> args,
  ) async {
    final Object? data;
    try {
      final res = await _functions
          .httpsCallable(name, options: HttpsCallableOptions(timeout: _timeout))
          .call<Object?>(args);
      data = res.data;
    } on FirebaseFunctionsException catch (e) {
      throw classifyError(e.code, e.details, brand: name.contains('Brand'));
    } catch (_) {
      throw const MigrationCallException(MigrationCallFailure.failed);
    }
    if (data is! Map) {
      throw const MigrationCallException(
        MigrationCallFailure.malformedResponse,
      );
    }
    return Map<String, dynamic>.from(data);
  }

  /// 테스트가 직접 쓴다.
  static MigrationCallException classifyError(
    String code,
    Object? details, {
    required bool brand,
  }) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return MigrationCallException(
          MigrationCallFailure.permissionDenied,
          code: code,
        );
      case 'deadline-exceeded':
        return MigrationCallException(MigrationCallFailure.timeout, code: code);
      case 'unavailable':
        return MigrationCallException(MigrationCallFailure.network, code: code);
      case 'failed-precondition':
        final m = details is Map ? details : const {};
        try {
          return MigrationCallException(
            MigrationCallFailure.stoppedByServer,
            code: code,
            anomalies: brand ? null : _strList(m['anomalies']),
            invalid: _invalidList(m['invalid'], brand: brand),
          );
        } on MigrationCallException {
          // details 를 읽지 못해도 "서버가 멈췄다" 는 사실은 보존한다.
          return MigrationCallException(
            MigrationCallFailure.stoppedByServer,
            code: code,
          );
        }
      default:
        return MigrationCallException(MigrationCallFailure.failed, code: code);
    }
  }

  static const _bad = MigrationCallException(
    MigrationCallFailure.malformedResponse,
  );

  static List<String>? _strList(Object? v) {
    if (v == null) return null;
    if (v is! List) throw _bad;
    return [
      for (final e in v)
        if (e is String) e else throw _bad,
    ];
  }

  static String? _optStr(Object? v) {
    if (v == null) return null;
    if (v is String) return v;
    throw _bad;
  }

  static List<MigrationInvalidItem>? _invalidList(
    Object? v, {
    required bool brand,
  }) {
    if (v == null) return null;
    if (v is! List) throw _bad;
    return [
      for (final e in v)
        if (e is Map)
          if (brand)
            MigrationInvalidItem('${e['brandId']}', '${e['reason']}')
          else
            MigrationInvalidItem('${e['id']}', '${e['status']}')
        else
          throw _bad,
    ];
  }

  static List<MigrationStoreRef>? _refList(Object? v) {
    if (v == null) return null;
    if (v is! List) throw _bad;
    return [
      for (final e in v)
        if (e is Map && e['id'] is String)
          MigrationStoreRef(e['id'] as String, _optStr(e['name']))
        else
          throw _bad,
    ];
  }

  static List<MigrationWillBeRejected>? _rejectedList(Object? v) {
    if (v == null) return null;
    if (v is! List) throw _bad;
    return [
      for (final e in v)
        if (e is Map && e['id'] is String)
          MigrationWillBeRejected(
            id: e['id'] as String,
            name: _optStr(e['name']),
            status: e['status']?.toString(),
            hasApprovedAt: e['hasApprovedAt'] is bool
                ? e['hasApprovedAt'] as bool
                : null,
          )
        else
          throw _bad,
    ];
  }

  static int? _int(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    throw _bad;
  }

  static bool? _bool(Object? v) {
    if (v == null) return null;
    if (v is bool) return v;
    throw _bad;
  }

  static StoreApprovalMigrationReport parseStore(
    Map<String, dynamic> d, {
    DateTime? now,
  }) => StoreApprovalMigrationReport(
    dryRun: _bool(d['dryRun']),
    total: _int(d['total']),
    setStatusApproved: _strList(d['setStatusApproved']),
    backfillApprovedAt: _strList(d['backfillApprovedAt']),
    invalid: _invalidList(d['invalid'], brand: false),
    anomalies: _strList(d['anomalies']),
    ambiguousRejected: _refList(d['ambiguousRejected']),
    ambiguousSelfRegress: _refList(d['ambiguousSelfRegress']),
    willBeRejected: _rejectedList(d['willBeRejected']),
    written: _int(d['written']),
    receivedAt: now ?? DateTime.now(),
  );

  static BrandProfileMigrationReport parseBrand(
    Map<String, dynamic> d, {
    DateTime? now,
  }) => BrandProfileMigrationReport(
    stage: _optStr(d['stage']),
    dryRun: _bool(d['dryRun']),
    total: _int(d['total']),
    toCopy: _int(d['toCopy']),
    toClean: _int(d['toClean']),
    invalid: _invalidList(d['invalid'], brand: true),
    written: _int(d['written']),
    receivedAt: now ?? DateTime.now(),
  );
}
