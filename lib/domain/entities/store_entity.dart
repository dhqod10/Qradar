import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:qradar/core/utils/grade_calculator.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
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
  const StoreEntity._();

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

    /// admin **승인** 시점. 승인 행위에서만 쓴다 (반려는 [rejectedAt]).
    DateTime? approvedAt,

    /// admin **반려** 시점. 점주 재제출 시 null 로 클리어된다.
    DateTime? rejectedAt,

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

    /// 점주가 끈 메인 카테고리 코드 목록 (운영 필드, opt-out). 빈 목록 = 전부 노출.
    /// sticky: 한 번 끄면 이후 해당 카테고리 메뉴가 생겨도 계속 숨긴다.
    @Default([]) List<String> excludedMainCategories,

    /// 검색/홈 필터용 파생 메인 카테고리 코드 (Cloud Function 전담, 읽기 전용).
    /// 노출 메뉴의 mainCategory ∩ active − excluded. 부재 = 빈 목록.
    @Default([]) List<String> availableMainCategories,

    /// 최종 수정 시점.
    DateTime? updatedAt,

    /// Qoin 적립률 개별 설정 (`qoinAccrualRate`). 부재 = 상위 상속. 0 은 적립률이 아니다.
    /// **읽기 전용** — 쓰기는 CF(setQoinAccrualRate / applyBrandQoinRate) 전담.
    @Default(QoinRateSetting.absent) QoinRateSetting qoinAccrualRate,

    /// 적립 스위치 (`qoinAccrualEnabled`). 부재/true = 사용, false = 사용 안 함. **읽기 전용.**
    @Default(QoinSwitchSetting.enabled) QoinSwitchSetting qoinAccrualEnabled,
  }) = _StoreEntity;

  /// 등급 부여 여부(파생, 저장 필드 아님). 평가 수가 최소 기준 미만이면 false → '신규'.
  bool get isGraded => GradeCalculator.isGraded(reviewCount);
}
