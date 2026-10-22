// TRANSITIONAL(spec §20.4.5): 임시 마이그레이션 자산. 정리 커밋에서 이 파일째 삭제한다.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:qradar/data/datasources/remote/qoin_callable.dart';
import 'package:qradar/domain/entities/qoin_zero_migration_result.dart';

class QoinZeroMigrationRemoteDataSource {
  QoinZeroMigrationRemoteDataSource({FirebaseFunctions? functions})
    : _callable = QoinCallable(
        functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3'),
      );

  final QoinCallable _callable;

  Future<QoinZeroMigrationResult> migrate({required bool dryRun}) async {
    final d = await _callable.call('migrateQoinZeroRates', <String, dynamic>{
      'dryRun': dryRun,
    }, timeout: const Duration(seconds: 300));
    return parse(d);
  }

  /// 응답 파서 (테스트가 직접 쓴다). 형식이 어긋난 항목은 건너뛴다.
  static QoinZeroMigrationResult parse(Map<String, dynamic> d) {
    List<QoinMigrationTarget> list(Object? v) {
      if (v is! List) return const [];
      return [
        for (final e in v)
          if (e is Map && e['id'] is String)
            QoinMigrationTarget(
              id: e['id'] as String,
              name: (e['name'] as String?) ?? '',
              raw: e['raw']?.toString(),
            ),
      ];
    }

    return QoinZeroMigrationResult(
      dryRun: d['dryRun'] == true,
      zeroStores: list(d['zeroStores']),
      zeroBrands: list(d['zeroBrands']),
      invalidStores: list(d['invalidStores']),
      invalidBrands: list(d['invalidBrands']),
      migrated: (d['migrated'] as num?)?.toInt() ?? 0,
      skipped: (d['skipped'] as num?)?.toInt() ?? 0,
    );
  }
}
