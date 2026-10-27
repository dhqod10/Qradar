// TEMP_MIGRATION_CARD — payment_server_authority 배포 ③⑤⑨ 용 임시 자산. 배포 ⑪ 정리 커밋에서 삭제한다.
// (migrate_report 계열 파일 목록은 docs/tasks/payment_server_authority/implementation.md §11 참조)

/// 마이그레이션 callable 이 돌려준 "무효" 1건 (`{id, status}` 또는 `{brandId, reason}`).
class MigrationInvalidItem {
  const MigrationInvalidItem(this.id, this.detail);
  final String id;

  /// 매장: 실제 status 값, 브랜드: 사유. 서버 report 데이터이지 오류 문자열이 아니다.
  final String detail;
}

class MigrationStoreRef {
  const MigrationStoreRef(this.id, this.name);
  final String id;
  final String? name;
}

/// ⓓ 백필을 가정한 뒤에도 canSellNow 가 false 인 매장.
class MigrationWillBeRejected {
  const MigrationWillBeRejected({
    required this.id,
    required this.name,
    required this.status,
    required this.hasApprovedAt,
  });
  final String id;
  final String? name;
  final String? status;
  final bool? hasApprovedAt;
}

/// `migrateStoreApprovalMeta` 응답. **필드가 null 이면 "응답에 그 분류가 없었다" 이고, 빈 리스트/0 은 "있고 0건" 이다.**
/// 둘을 화면에서 구분하기 위해 기본값 0 을 채우지 않는다.
class StoreApprovalMigrationReport {
  const StoreApprovalMigrationReport({
    required this.dryRun,
    required this.total,
    required this.setStatusApproved,
    required this.backfillApprovedAt,
    required this.invalid,
    required this.anomalies,
    required this.ambiguousRejected,
    required this.ambiguousSelfRegress,
    required this.willBeRejected,
    required this.written,
    required this.receivedAt,
  });
  final bool? dryRun;
  final int? total;
  final List<String>? setStatusApproved;
  final List<String>? backfillApprovedAt;
  final List<MigrationInvalidItem>? invalid;
  final List<String>? anomalies;
  final List<MigrationStoreRef>? ambiguousRejected;
  final List<MigrationStoreRef>? ambiguousSelfRegress;
  final List<MigrationWillBeRejected>? willBeRejected;

  /// 실행(dryRun:false) 응답에만 있다.
  final int? written;
  final DateTime receivedAt;

  /// ⓒ — 서버가 실행을 멈추는 조건. 분류가 응답에 없으면(null) 멈춰야 하는 쪽으로 본다.
  bool get blocksExecution =>
      anomalies == null ||
      invalid == null ||
      anomalies!.isNotEmpty ||
      invalid!.isNotEmpty;
}

enum BrandMigrationStage {
  copy('copy'),
  cleanup('cleanup');

  const BrandMigrationStage(this.code);
  final String code;
}

/// `migrateBrandPrivateProfile` 응답.
class BrandProfileMigrationReport {
  const BrandProfileMigrationReport({
    required this.stage,
    required this.dryRun,
    required this.total,
    required this.toCopy,
    required this.toClean,
    required this.invalid,
    required this.written,
    required this.receivedAt,
  });
  final String? stage;
  final bool? dryRun;
  final int? total;
  final int? toCopy;
  final int? toClean;
  final List<MigrationInvalidItem>? invalid;
  final int? written;
  final DateTime receivedAt;

  bool get blocksExecution => invalid == null || invalid!.isNotEmpty;
}
