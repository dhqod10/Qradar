// TRANSITIONAL(spec §20.4.5): 임시 마이그레이션 자산. 정리 커밋에서 이 파일째 삭제한다.

/// 이전 대상 1건 (매장 또는 브랜드).
class QoinMigrationTarget {
  const QoinMigrationTarget({required this.id, required this.name, this.raw});
  final String id;
  final String name;

  /// 무효 값 목록에서만: 값의 원형 문자열.
  final String? raw;
}

/// `migrateQoinZeroRates` 결과. dry-run 이면 [migrated] / [skipped] 는 0 이다.
class QoinZeroMigrationResult {
  const QoinZeroMigrationResult({
    required this.dryRun,
    required this.zeroStores,
    required this.zeroBrands,
    required this.invalidStores,
    required this.invalidBrands,
    required this.migrated,
    required this.skipped,
  });

  final bool dryRun;
  final List<QoinMigrationTarget> zeroStores;
  final List<QoinMigrationTarget> zeroBrands;

  /// 무효 값(비number / 범위 밖) — **보고만 하고 자동 변환하지 않는다.**
  final List<QoinMigrationTarget> invalidStores;
  final List<QoinMigrationTarget> invalidBrands;
  final int migrated;
  final int skipped;

  int get zeroCount => zeroStores.length + zeroBrands.length;
  int get invalidCount => invalidStores.length + invalidBrands.length;
}
