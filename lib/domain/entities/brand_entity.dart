import 'package:freezed_annotation/freezed_annotation.dart';
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
  }) = _BrandEntity;
}
