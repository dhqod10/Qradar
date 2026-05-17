import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/utils/grade_calculator.dart';
import 'package:qradar/data/models/business_hours_model.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/user_location.dart';

/// Firestore stores/{storeId} 문서 매퍼.
///
/// freezed 대신 수동 매퍼를 사용: Firestore의 GeoPoint/Timestamp는
/// json_serializable로 직렬화가 까다롭고, Repository에서 읽기/쓰기 모두 단순하게 다룬다.
///
/// sub-phase 2: 승인 게이트 필드 + 운영 필드 추가.
/// T1: missing status → EntityApprovalStatus.approved fallback (legacy 안전).
class StoreModel {
  final String id;
  final String ownerId;
  final String name;

  /// 기존 단일 이미지 URL (Phase 1a 호환성 유지).
  final String imageUrl;

  final double latitude;
  final double longitude;
  final String phone;
  final String address;
  final String? description;
  final double averageScore;
  final int reviewCount;
  final List<String> menuCategories;
  final BusinessHoursModel? businessHours;
  final DateTime createdAt;

  // ── sub-phase 2 신규 필드 ────────────────────────────────────────────────
  final String? brandId;
  final EntityApprovalStatus status;
  final String? submittedBy;
  final DateTime? submittedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectedReason;
  final String? businessRegistrationNumber;
  final bool temporaryClosed;
  final List<DateTime> closedDates;
  final List<String> imageUrls;
  final String? notice;
  final DateTime? updatedAt;

  const StoreModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.averageScore,
    required this.reviewCount,
    required this.menuCategories,
    required this.createdAt,
    this.ownerId = '',
    this.phone = '',
    this.address = '',
    this.description,
    this.businessHours,
    // sub-phase 2
    this.brandId,
    this.status = EntityApprovalStatus.approved,
    this.submittedBy,
    this.submittedAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectedReason,
    this.businessRegistrationNumber,
    this.temporaryClosed = false,
    this.closedDates = const [],
    this.imageUrls = const [],
    this.notice,
    this.updatedAt,
  });

  factory StoreModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final geoPoint = data['location'] as GeoPoint?;
    final createdAtTs = data['createdAt'] as Timestamp?;
    final hoursMap = data['businessHours'] as Map<String, dynamic>?;

    // sub-phase 2 Timestamp 파싱 헬퍼
    DateTime? tsField(String key) {
      final raw = data[key] as Timestamp?;
      return raw?.toDate();
    }

    // closedDates: List<Timestamp> → List<DateTime>
    final closedDatesRaw = data['closedDates'] as List<dynamic>?;
    final closedDates = closedDatesRaw
            ?.whereType<Timestamp>()
            .map((t) => t.toDate())
            .toList(growable: false) ??
        const <DateTime>[];

    // imageUrls: List<String>
    final imageUrlsRaw = data['imageUrls'] as List<dynamic>?;
    final imageUrls = imageUrlsRaw
            ?.whereType<String>()
            .toList(growable: false) ??
        const <String>[];

    return StoreModel(
      id: doc.id,
      ownerId: (data['ownerId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      imageUrl: (data['imageUrl'] as String?) ?? '',
      latitude: geoPoint?.latitude ?? 0.0,
      longitude: geoPoint?.longitude ?? 0.0,
      phone: (data['phone'] as String?) ?? '',
      address: (data['address'] as String?) ?? '',
      description: data['description'] as String?,
      averageScore: (data['averageScore'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      menuCategories: ((data['menuCategories'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      businessHours:
          hoursMap != null ? BusinessHoursModel.fromMap(hoursMap) : null,
      createdAt: createdAtTs?.toDate() ?? DateTime.now(),
      // sub-phase 2 — T1: missing status → approved fallback
      brandId: data['brandId'] as String?,
      status: EntityApprovalStatus.fromString(data['status'] as String?),
      submittedBy: data['submittedBy'] as String?,
      submittedAt: tsField('submittedAt'),
      approvedBy: data['approvedBy'] as String?,
      approvedAt: tsField('approvedAt'),
      rejectedReason: data['rejectedReason'] as String?,
      businessRegistrationNumber:
          data['businessRegistrationNumber'] as String?,
      temporaryClosed: (data['temporaryClosed'] as bool?) ?? false,
      closedDates: closedDates,
      imageUrls: imageUrls,
      notice: data['notice'] as String?,
      updatedAt: tsField('updatedAt'),
    );
  }

  factory StoreModel.fromEntity(StoreEntity entity) {
    return StoreModel(
      id: entity.id,
      ownerId: entity.ownerId,
      name: entity.name,
      imageUrl: entity.imageUrl,
      latitude: entity.location.latitude,
      longitude: entity.location.longitude,
      phone: entity.phone,
      address: entity.address,
      description: entity.description,
      averageScore: entity.averageScore,
      reviewCount: entity.reviewCount,
      menuCategories: entity.menuCategories,
      businessHours: entity.businessHours != null
          ? BusinessHoursModel.fromEntity(entity.businessHours!)
          : null,
      createdAt: entity.createdAt,
      // sub-phase 2
      brandId: entity.brandId,
      status: entity.status,
      submittedBy: entity.submittedBy,
      submittedAt: entity.submittedAt,
      approvedBy: entity.approvedBy,
      approvedAt: entity.approvedAt,
      rejectedReason: entity.rejectedReason,
      businessRegistrationNumber: entity.businessRegistrationNumber,
      temporaryClosed: entity.temporaryClosed,
      closedDates: entity.closedDates,
      imageUrls: entity.imageUrls,
      notice: entity.notice,
      updatedAt: entity.updatedAt,
    );
  }

  StoreEntity toEntity({double? distanceKm}) {
    return StoreEntity(
      id: id,
      name: name,
      imageUrl: imageUrl,
      location: UserLocation(latitude: latitude, longitude: longitude),
      grade: GradeCalculator.fromAverage(averageScore),
      averageScore: averageScore,
      reviewCount: reviewCount,
      menuCategories: menuCategories,
      createdAt: createdAt,
      ownerId: ownerId,
      phone: phone,
      address: address,
      description: description,
      businessHours: businessHours?.toEntity(),
      distanceKm: distanceKm,
      // sub-phase 2
      brandId: brandId,
      status: status,
      submittedBy: submittedBy,
      submittedAt: submittedAt,
      approvedBy: approvedBy,
      approvedAt: approvedAt,
      rejectedReason: rejectedReason,
      businessRegistrationNumber: businessRegistrationNumber,
      temporaryClosed: temporaryClosed,
      closedDates: closedDates,
      imageUrls: imageUrls,
      notice: notice,
      updatedAt: updatedAt,
    );
  }

  /// 신규 매장 생성용 (점주 등록 — status=pending, brandId=null 강제).
  Map<String, dynamic> toFirestoreForCreate() => <String, dynamic>{
        'ownerId': ownerId,
        'name': name,
        'imageUrl': imageUrl,
        'location': GeoPoint(latitude, longitude),
        'phone': phone,
        'address': address,
        'description': description,
        'averageScore': 0.0,
        'reviewCount': 0,
        'menuCategories': menuCategories,
        if (businessHours != null) 'businessHours': businessHours!.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        // sub-phase 6 (V4) — 폼이 brandKey 매칭 후 brandId 채워서 보냄.
        // 개인 매장 = null, 브랜드 가맹점 = brandId 매칭값. status 는 pending 강제.
        'brandId': brandId,
        'status': EntityApprovalStatus.pending.asString,
        'submittedBy': submittedBy,
        'submittedAt': FieldValue.serverTimestamp(),
        'businessRegistrationNumber': businessRegistrationNumber,
        'imageUrls': imageUrls,
      };

  /// 핵심 필드 수정용 (status=pending 회귀, approvedBy/At 보존).
  Map<String, dynamic> toFirestoreForCoreUpdate({
    required bool isResubmit,
  }) =>
      <String, dynamic>{
        'name': name,
        'address': address,
        'location': GeoPoint(latitude, longitude),
        'menuCategories': menuCategories,
        'businessRegistrationNumber': businessRegistrationNumber,
        'status': EntityApprovalStatus.pending.asString,
        'submittedBy': submittedBy,
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // T3: 재제출 시 approved/rejected 메타 클리어
        if (isResubmit) ...{
          'approvedBy': null,
          'approvedAt': null,
          'rejectedReason': null,
        },
      };

  /// 운영 필드 수정용 (status / 승인 메타 무변경, partial update).
  Map<String, dynamic> toFirestoreForOperationUpdate() => <String, dynamic>{
        'phone': phone,
        'description': description,
        'notice': notice,
        'businessHours':
            businessHours != null ? businessHours!.toMap() : FieldValue.delete(),
        'temporaryClosed': temporaryClosed,
        'closedDates': closedDates
            .map((d) => Timestamp.fromDate(d))
            .toList(growable: false),
        'imageUrls': imageUrls,
        'imageUrl': imageUrls.isNotEmpty ? imageUrls.first : imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// brand 신규 매장 등록용 (brandId 포함, status=pending 강제).
  Map<String, dynamic> toFirestoreForBrandCreate() => <String, dynamic>{
        'ownerId': ownerId,
        'name': name,
        'imageUrl': imageUrl,
        'location': GeoPoint(latitude, longitude),
        'phone': phone,
        'address': address,
        'description': description,
        'averageScore': 0.0,
        'reviewCount': 0,
        'menuCategories': menuCategories,
        if (businessHours != null) 'businessHours': businessHours!.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'brandId': brandId,
        'status': EntityApprovalStatus.pending.asString,
        'submittedBy': submittedBy,
        'submittedAt': FieldValue.serverTimestamp(),
        'businessRegistrationNumber': businessRegistrationNumber,
        'imageUrls': imageUrls,
      };

  /// admin 승인용 partial update.
  static Map<String, dynamic> approveFields(String adminUid) =>
      <String, dynamic>{
        'status': EntityApprovalStatus.approved.asString,
        'approvedBy': adminUid,
        'approvedAt': FieldValue.serverTimestamp(),
        'rejectedReason': null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// admin 반려용 partial update.
  static Map<String, dynamic> rejectFields(
          String adminUid, String reason) =>
      <String, dynamic>{
        'status': EntityApprovalStatus.rejected.asString,
        'approvedBy': adminUid,
        'approvedAt': FieldValue.serverTimestamp(),
        'rejectedReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
