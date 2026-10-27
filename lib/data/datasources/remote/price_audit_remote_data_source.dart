// TEMP_PRICE_AUDIT_CARD — payment_price_authority 배포 ②⑨ 용 임시 자산. 배포 ⑩ 정리 커밋에서 삭제한다.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:qradar/data/datasources/remote/migration_remote_data_source.dart';
import 'package:qradar/domain/entities/migration_call_exception.dart';
import 'package:qradar/domain/entities/price_audit_report.dart';

/// `auditOrderPriceIntegrity` (admin 전용 임시 callable, asia-northeast3, **읽기 전용**).
///
/// SDK 예외는 이 파일 밖으로 나가지 않고 서버 message 는 어디에도 싣지 않는다. 파서는 "없는 필드" 를 0 으로 채우지 않는다
/// (null) — 0건과 "그 분류가 응답에 없음" 을 구분하기 위해서다. 형식이 깨진 항목은 건너뛰지 않고 응답 전체를 형식 오류로 본다.
class PriceAuditRemoteDataSource {
  PriceAuditRemoteDataSource({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFunctions _functions;

  // CF timeoutSeconds 540 보다 길게 — 클라이언트가 먼저 포기하지 않게.
  static const _timeout = Duration(seconds: 560);

  Future<PriceAuditReport> audit() async {
    final Object? data;
    try {
      final res = await _functions
          .httpsCallable(
            'auditOrderPriceIntegrity',
            options: HttpsCallableOptions(timeout: _timeout),
          )
          .call<Object?>(const <String, dynamic>{});
      data = res.data;
    } on FirebaseFunctionsException catch (e) {
      throw MigrationRemoteDataSource.classifyError(
        e.code,
        e.details,
        brand: false,
      );
    } catch (_) {
      throw const MigrationCallException(MigrationCallFailure.failed);
    }
    if (data is! Map) {
      throw const MigrationCallException(
        MigrationCallFailure.malformedResponse,
      );
    }
    return parse(Map<String, dynamic>.from(data));
  }

  static const _bad = MigrationCallException(
    MigrationCallFailure.malformedResponse,
  );

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

  static String? _str(Object? v) {
    if (v == null) return null;
    if (v is String) return v;
    throw _bad;
  }

  static Map<String, dynamic>? _map(Object? v) {
    if (v == null) return null;
    if (v is Map) return Map<String, dynamic>.from(v);
    throw _bad;
  }

  static List<T>? _list<T>(Object? v, T Function(Map<String, dynamic>) f) {
    if (v == null) return null;
    if (v is! List) throw _bad;
    return [
      for (final e in v)
        if (e is Map) f(Map<String, dynamic>.from(e)) else throw _bad,
    ];
  }

  /// 테스트가 직접 쓴다.
  static PriceAuditReport parse(Map<String, dynamic> d, {DateTime? now}) {
    final window = _map(d['window']);
    final orders = _map(d['orders']);
    final ovr = _map(d['selfApprovedOverrides']);
    final refs = _map(d['storeScopeRefs']);
    final byCheckRaw = _map(orders?['byCheck']);
    return PriceAuditReport(
      windowFrom: _str(window?['from']),
      windowTo: _str(window?['to']),
      ordersScanned: _int(orders?['scanned']),
      ordersViolationCount: _int(orders?['violationCount']),
      byCheck: byCheckRaw == null
          ? null
          : {for (final e in byCheckRaw.entries) e.key: _int(e.value) ?? 0},
      orderViolations: _list(
        orders?['violations'],
        (m) => PriceAuditOrderViolation(
          orderId: _str(m['orderId']) ?? '',
          storeId: _str(m['storeId']),
          failed: [
            for (final f
                in (m['failed'] is List ? m['failed'] as List : const []))
              if (f is String) f else throw _bad,
          ],
          malformed: _bool(m['malformed']) ?? false,
          clientSubtotal: _int(m['clientSubtotal']),
          sumOfLineTotals: _int(m['sumOfLineTotals']),
          amount: _int(m['amount']),
        ),
      ),
      ordersTruncated: _bool(orders?['truncated']),
      overridesScanned: _int(ovr?['scanned']),
      selfApprovedCount: _int(ovr?['count']),
      opsOnlyApproved: _int(ovr?['opsOnlyApproved']),
      selfApproved: _list(
        ovr?['items'],
        (m) => PriceAuditOverrideItem(
          storeId: _str(m['storeId']) ?? '',
          masterMenuItemId: _str(m['masterMenuItemId']) ?? '',
          priceOverride: _int(m['priceOverride']),
          excluded: _bool(m['excluded']) ?? false,
          status: _str(m['status']),
          approvedBy: _str(m['approvedBy']),
        ),
      ),
      refCount: _int(refs?['count']),
      refStorePairs: _int(refs?['storePairs']),
      refItems: _list(
        refs?['items'],
        (m) => PriceAuditRefItem(
          brandId: _str(m['brandId']) ?? '',
          menuItemId: _str(m['menuItemId']) ?? '',
          groupId: _str(m['groupId']) ?? '',
          franchiseStores: _int(m['franchiseStores']) ?? 0,
        ),
      ),
      receivedAt: now ?? DateTime.now(),
    );
  }
}
