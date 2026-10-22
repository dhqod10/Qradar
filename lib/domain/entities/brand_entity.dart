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
    // 사업자 정보 (Step 3 신규)
    @Default('') String companyName,                // 회사명 (필수)
    @Default('') String businessRegistrationNumber, // 사업자등록번호 000-00-00000 (필수)
    @Default('') String contactName,                // 담당자 이름 (필수)
    @Default('') String contactPhone,               // 담당자 연락처 (필수)
    String? headOfficeAddress,                      // 본사 주소 (선택)
    String? representativeName,                     // 대표자 이름 (선택)
    /// 브랜드 키 (V1). admin 승인 시점에 자동 발급. pending/rejected 상태에서는 빈 문자열.
    @Default('') String brandKey,
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
