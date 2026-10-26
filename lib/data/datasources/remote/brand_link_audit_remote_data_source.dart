import 'package:cloud_functions/cloud_functions.dart';
import 'package:qradar/domain/entities/brand_link_audit_result.dart';

class BrandLinkAuditRemoteDataSource {
  BrandLinkAuditRemoteDataSource({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFunctions _functions;

  /// 요청 인자가 없다 — 이 callable 은 절대 쓰지 않는다 (시험 실행 같은 모드 인자조차 없다).
  Future<BrandLinkAuditResult> audit() async {
    final res = await _functions
        .httpsCallable(
          'auditBrandLinks',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 300)),
        )
        .call<Object?>(<String, dynamic>{});
    final d = res.data;
    return parse(d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{});
  }

  /// 응답 파서 (테스트가 직접 쓴다). 모르는 분류·형식이 어긋난 항목은 건너뛴다 — 단 **건수는 모르는 분류가 있어도 보존**한다.
  static BrandLinkAuditResult parse(Map<String, dynamic> d, {DateTime? now}) {
    final countsRaw = d['counts'] is Map ? d['counts'] as Map : const {};
    final itemsRaw = d['items'] is Map ? d['items'] as Map : const {};
    final truncRaw = d['truncated'] is Map ? d['truncated'] as Map : const {};

    final counts = <BrandLinkClass, int>{
      for (final c in BrandLinkClass.values)
        c: (countsRaw[c.code] as num?)?.toInt() ?? 0,
    };
    final items = <BrandLinkClass, List<BrandLinkAuditItem>>{};
    for (final c in BrandLinkClass.values) {
      final list = itemsRaw[c.code];
      if (list is! List) continue;
      items[c] = [
        for (final e in list)
          if (e is Map)
            BrandLinkAuditItem(
              uid: e['uid'] as String?,
              email: e['email'] as String?,
              storeId: e['storeId'] as String?,
              storeName: e['storeName'] as String?,
              brandId: e['brandId'] as String?,
              brandName: e['brandName'] as String?,
              submittedBy: e['submittedBy'] as String?,
              status: e['status'] as String?,
            ),
      ];
    }
    return BrandLinkAuditResult(
      counts: counts,
      items: items,
      truncated: {
        for (final c in BrandLinkClass.values)
          if (truncRaw[c.code] == true) c,
      },
      checkedAt: now ?? DateTime.now(),
    );
  }
}
