import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/domain/entities/business_hours.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/store_grade.dart';
import 'package:qradar/domain/entities/user_location.dart';

part 'store_entity.freezed.dart';

/// 매장 도메인 엔티티.
///
/// 데이터 소스(Firestore/AWS)로부터 Repository가 반환하는 순수 비즈니스 객체.
/// sub-phase 2: 승인 게이트 필드 + 운영 필드 추가.
@freezed
abstract class StoreEntity with _$StoreEntity {
  const factory StoreEntity({
    required String id,
    required String name,
    required String imageUrl,
    required UserLocation location,
    required StoreGrade grade,
    required double averageScore,
    required int reviewCount,
    required List<String> menuCategories,
    required DateTime createdAt,
    @Default('') String ownerId,
    @Default('') String phone,
    @Default('') String address,
    String? description,
    BusinessHours? businessHours,
    double? distanceKm,

    // ── sub-phase 2 신규 필드 ────────────────────────────────────────────
    /// 브랜드 매장이면 brandId, 개인 매장(점주 직접 등록)이면 null.
    String? brandId,

    /// 승인 상태. missing status → approved fallback (T1, legacy 안전).
    @Default(EntityApprovalStatus.approved) EntityApprovalStatus status,

    /// 이번 신청을 제출한 사용자 uid.
    String? submittedBy,

    /// 점주 제출 시점.
    DateTime? submittedAt,

    /// admin 이 마지막으로 처리한 uid (approve/reject 양쪽).
    String? approvedBy,

    /// admin 처리 시점 (approve/reject 양쪽).
    DateTime? approvedAt,

    /// admin 반려 사유. status=rejected 일 때만 의미 있음.
    String? rejectedReason,

    /// 사업자등록번호 (핵심 필드).
    String? businessRegistrationNumber,

    /// 임시 휴무 토글 (운영 필드).
    @Default(false) bool temporaryClosed,

    /// 특정 날짜 휴무 리스트 (운영 필드).
    @Default([]) List<DateTime> closedDates,

    /// 대표 이미지 URL 목록. 기존 단일 imageUrl 과 병행 (호환성).
    @Default([]) List<String> imageUrls,

    /// 매장 안내 문구 (운영 필드).
    String? notice,

    /// 최종 수정 시점.
    DateTime? updatedAt,
  }) = _StoreEntity;
}
