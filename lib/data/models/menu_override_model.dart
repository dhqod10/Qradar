import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';

/// Firestore `stores/{storeId}/menuOverrides/{masterMenuItemId}` 문서 매퍼.
class MenuOverrideModel {
  final String masterMenuItemId;
  final String storeId;
  final String brandId;
  final int? priceOverride;
  final bool excluded;
  final bool soldOut;
  final List<String> disabledOptionGroupIds;
  final List<String> disabledOptionItemIds;
  final String status;
  final String? submittedBy;
  final DateTime? submittedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectedReason;
  final String? updatedBy;
  final DateTime? updatedAt;

  const MenuOverrideModel({
    required this.masterMenuItemId,
    required this.storeId,
    required this.brandId,
    this.priceOverride,
    this.excluded = false,
    this.soldOut = false,
    this.disabledOptionGroupIds = const [],
    this.disabledOptionItemIds = const [],
    this.status = 'pending',
    this.submittedBy,
    this.submittedAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectedReason,
    this.updatedBy,
    this.updatedAt,
  });

  factory MenuOverrideModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String storeId,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return MenuOverrideModel(
      masterMenuItemId: doc.id,
      storeId: storeId,
      brandId: data['brandId'] as String? ?? '',
      priceOverride: data['priceOverride'] as int?,
      excluded: data['excluded'] as bool? ?? false,
      soldOut: data['soldOut'] as bool? ?? false,
      disabledOptionGroupIds: List<String>.from(
        data['disabledOptionGroupIds'] as List? ?? [],
      ),
      disabledOptionItemIds: List<String>.from(
        data['disabledOptionItemIds'] as List? ?? [],
      ),
      status: data['status'] as String? ?? 'pending',
      submittedBy: data['submittedBy'] as String?,
      submittedAt: _toDateTime(data['submittedAt']),
      approvedBy: data['approvedBy'] as String?,
      approvedAt: _toDateTime(data['approvedAt']),
      rejectedReason: data['rejectedReason'] as String?,
      updatedBy: data['updatedBy'] as String?,
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  /// collectionGroup query 결과 doc 을 파싱할 때 storeId 를 경로에서 추출.
  factory MenuOverrideModel.fromFirestoreCollectionGroup(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    // path: stores/{storeId}/menuOverrides/{masterMenuItemId}
    final pathSegments = doc.reference.path.split('/');
    final storeId = pathSegments.length >= 2 ? pathSegments[1] : '';
    return MenuOverrideModel.fromFirestore(doc, storeId);
  }

  factory MenuOverrideModel.fromEntity(MenuOverrideEntity entity) {
    return MenuOverrideModel(
      masterMenuItemId: entity.masterMenuItemId,
      storeId: entity.storeId,
      brandId: entity.brandId,
      priceOverride: entity.priceOverride,
      excluded: entity.excluded,
      soldOut: entity.soldOut,
      disabledOptionGroupIds: entity.disabledOptionGroupIds,
      disabledOptionItemIds: entity.disabledOptionItemIds,
      status: entity.status.name,
      submittedBy: entity.submittedBy,
      submittedAt: entity.submittedAt,
      approvedBy: entity.approvedBy,
      approvedAt: entity.approvedAt,
      rejectedReason: entity.rejectedReason,
      updatedBy: entity.updatedBy,
      updatedAt: entity.updatedAt,
    );
  }

  MenuOverrideEntity toEntity() {
    return MenuOverrideEntity(
      masterMenuItemId: masterMenuItemId,
      storeId: storeId,
      brandId: brandId,
      priceOverride: priceOverride,
      excluded: excluded,
      soldOut: soldOut,
      disabledOptionGroupIds: disabledOptionGroupIds,
      disabledOptionItemIds: disabledOptionItemIds,
      status: EntityApprovalStatus.fromString(status),
      submittedBy: submittedBy,
      submittedAt: submittedAt,
      approvedBy: approvedBy,
      approvedAt: approvedAt,
      rejectedReason: rejectedReason,
      updatedBy: updatedBy,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'masterMenuItemId': masterMenuItemId,
      'storeId': storeId,
      'brandId': brandId,
      if (priceOverride != null) 'priceOverride': priceOverride,
      'excluded': excluded,
      'soldOut': soldOut,
      'disabledOptionGroupIds': disabledOptionGroupIds,
      'disabledOptionItemIds': disabledOptionItemIds,
      'status': status,
      if (submittedBy != null) 'submittedBy': submittedBy,
      if (submittedAt != null)
        'submittedAt': Timestamp.fromDate(submittedAt!),
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (approvedAt != null)
        'approvedAt': Timestamp.fromDate(approvedAt!),
      if (rejectedReason != null) 'rejectedReason': rejectedReason,
      if (updatedBy != null) 'updatedBy': updatedBy,
      if (updatedAt != null)
        'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  /// 승인 필드 업데이트 맵.
  Map<String, dynamic> toFirestoreForApprove(String adminUid) {
    return {
      'status': 'approved',
      'approvedBy': adminUid,
      'approvedAt': Timestamp.fromDate(DateTime.now()),
      'rejectedReason': null,
      'updatedBy': 'admin',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  /// 반려 필드 업데이트 맵.
  Map<String, dynamic> toFirestoreForReject(String adminUid, String reason) {
    return {
      'status': 'rejected',
      'approvedBy': adminUid,
      'approvedAt': Timestamp.fromDate(DateTime.now()),
      'rejectedReason': reason,
      'updatedBy': 'admin',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }
}

DateTime? _toDateTime(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  return null;
}
