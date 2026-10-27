import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';

part 'brand_entity.freezed.dart';

/// 브랜드 1건.
///
/// Firestore `brands/{brandId}` 문서에 대응.
@freezed
abstract class BrandEntity with _$BrandEntity {
  const factory BrandEntity({
    required String id,
    required String name,
    @Default('') String logoUrl,
    String? description,
    // 사업자 정보 중 회사명만 부모 문서에 남는다. 사업자번호·담당자·대표자·본사 주소와 brandKey 는
    // `brands/{id}/private/profile` ([BrandPrivateProfileEntity]) 로 이동했다 (payment_server_authority B1).
    @Default('') String companyName,                // 회사명 (필수)
    @Default(EntityApprovalStatus.pending) EntityApprovalStatus status,
    String? submittedBy,
    DateTime? submittedAt,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectedReason,
    DateTime? createdAt,
    DateTime? updatedAt,

    /// Qoin 적립률 브랜드 설정 (`qoinAccrualRate`). 부재 = 전역 상속. 0 은 적립률이 아니다.
    /// **읽기 전용** — 쓰기는 CF 전담.
    @Default(QoinRateSetting.absent) QoinRateSetting qoinAccrualRate,

    /// 적립 스위치 (`qoinAccrualEnabled`). 부재/true = 사용, false = 이 브랜드 산하 전체 사용 안 함. **읽기 전용.**
    @Default(QoinSwitchSetting.enabled) QoinSwitchSetting qoinAccrualEnabled,

    /// 일괄 적용 포인터 (`qoinBulkHistoryId` / `qoinBulkStatus` / `qoinBulkAt`). 허브의 중단 판정 근거. **읽기 전용.**
    String? qoinBulkHistoryId,
    QoinBulkStatus? qoinBulkStatus,
    DateTime? qoinBulkAt,
  }) = _BrandEntity;
}
