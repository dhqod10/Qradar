import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_item_scope.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/option_scope.dart';

/// Firestore 메뉴 아이템 문서 매퍼.
///
/// - 매장 메뉴: `stores/{storeId}/menuItems/{id}`
/// - 브랜드 마스터 메뉴: `brands/{brandId}/menuItems/{id}`
///
/// 신규 필드(`scope`, `brandId`, `tags`, `visible`, `status` 등)는 누락 시
/// 기존 매장 메뉴에 영향이 없도록 default 값으로 처리한다.
class MenuItemModel {
  final String id;
  final String storeId;
  final String name;
  final String imageUrl;
  final String? description;
  final String mainCategory;
  final String? subCategoryId;
  final int basePrice;
  final List<Map<String, dynamic>> optionGroupRefs;
  final bool soldOut;
  final int displayOrder;
  final DateTime? createdAt;
  // ── Phase 1b 신규 필드 ───────────────────────────────────────────────
  final String scope; // 'brand' | 'store'
  final String? brandId;
  final List<String> tags;
  final bool visible;
  final List<String> disabledOptionGroupIds;
  final List<String> disabledOptionItemIds;
  final String? status; // 'pending' | 'approved' | 'rejected' | null
  final String? submittedBy;
  final DateTime? submittedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectedReason;
  final DateTime? updatedAt;

  const MenuItemModel({
    required this.id,
    required this.storeId,
    required this.name,
    this.imageUrl = '',
    this.description,
    required this.mainCategory,
    this.subCategoryId,
    required this.basePrice,
    this.optionGroupRefs = const [],
    this.soldOut = false,
    this.displayOrder = 0,
    this.createdAt,
    this.scope = 'store',
    this.brandId,
    this.tags = const [],
    this.visible = true,
    this.disabledOptionGroupIds = const [],
    this.disabledOptionItemIds = const [],
    this.status,
    this.submittedBy,
    this.submittedAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectedReason,
    this.updatedAt,
  });

  factory MenuItemModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String storeId,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawRefs = (data['optionGroupRefs'] as List<dynamic>?) ?? const [];
    final rawTags = (data['tags'] as List<dynamic>?) ?? const [];
    final rawDisabledGroups =
        (data['disabledOptionGroupIds'] as List<dynamic>?) ?? const [];
    final rawDisabledItems =
        (data['disabledOptionItemIds'] as List<dynamic>?) ?? const [];
    return MenuItemModel(
      id: doc.id,
      storeId: storeId,
      name: (data['name'] as String?) ?? '',
      imageUrl: (data['imageUrl'] as String?) ?? '',
      description: data['description'] as String?,
      mainCategory: (data['mainCategory'] as String?) ?? 'coffee',
      subCategoryId: data['subCategoryId'] as String?,
      basePrice: (data['basePrice'] as num?)?.toInt() ?? 0,
      optionGroupRefs: rawRefs
          .whereType<Map<String, dynamic>>()
          .map((m) => <String, dynamic>{
                'scope': (m['scope'] as String?) ?? 'master',
                'id': (m['id'] as String?) ?? '',
              })
          .toList(growable: false),
      soldOut: (data['soldOut'] as bool?) ?? false,
      displayOrder: (data['displayOrder'] as num?)?.toInt() ?? 0,
      createdAt: _toDate(data['createdAt']),
      scope: (data['scope'] as String?) ?? 'store',
      brandId: data['brandId'] as String?,
      tags: rawTags.whereType<String>().toList(growable: false),
      visible: (data['visible'] as bool?) ?? true,
      disabledOptionGroupIds:
          rawDisabledGroups.whereType<String>().toList(growable: false),
      disabledOptionItemIds:
          rawDisabledItems.whereType<String>().toList(growable: false),
      status: data['status'] as String?,
      submittedBy: data['submittedBy'] as String?,
      submittedAt: _toDate(data['submittedAt']),
      approvedBy: data['approvedBy'] as String?,
      approvedAt: _toDate(data['approvedAt']),
      rejectedReason: data['rejectedReason'] as String?,
      updatedAt: _toDate(data['updatedAt']),
    );
  }

  factory MenuItemModel.fromEntity(MenuItemEntity entity) {
    return MenuItemModel(
      id: entity.id,
      storeId: entity.storeId,
      name: entity.name,
      imageUrl: entity.imageUrl,
      description: entity.description,
      mainCategory: entity.mainCategoryCode,
      subCategoryId: entity.subCategoryId,
      basePrice: entity.basePrice,
      optionGroupRefs: entity.optionGroupRefs
          .map((r) => <String, dynamic>{
                'scope': r.scope.asString,
                'id': r.id,
              })
          .toList(growable: false),
      soldOut: entity.soldOut,
      displayOrder: entity.displayOrder,
      createdAt: entity.createdAt,
      scope: entity.scope.asString,
      brandId: entity.brandId,
      tags: entity.tags,
      visible: entity.visible,
      disabledOptionGroupIds: entity.disabledOptionGroupIds,
      disabledOptionItemIds: entity.disabledOptionItemIds,
      status: entity.status?.asString,
      submittedBy: entity.submittedBy,
      submittedAt: entity.submittedAt,
      approvedBy: entity.approvedBy,
      approvedAt: entity.approvedAt,
      rejectedReason: entity.rejectedReason,
      updatedAt: entity.updatedAt,
    );
  }

  MenuItemEntity toEntity() {
    return MenuItemEntity(
      id: id,
      storeId: storeId,
      name: name,
      imageUrl: imageUrl,
      description: description,
      mainCategoryCode: mainCategory,
      subCategoryId: subCategoryId,
      basePrice: basePrice,
      optionGroupRefs: optionGroupRefs
          .map((m) => OptionGroupRef(
                scope:
                    OptionScope.fromString(m['scope'] as String? ?? 'master'),
                id: (m['id'] as String?) ?? '',
              ))
          .toList(growable: false),
      soldOut: soldOut,
      displayOrder: displayOrder,
      createdAt: createdAt,
      scope: MenuItemScope.fromString(scope),
      brandId: brandId,
      tags: tags,
      visible: visible,
      disabledOptionGroupIds: disabledOptionGroupIds,
      disabledOptionItemIds: disabledOptionItemIds,
      status: status != null ? EntityApprovalStatus.fromString(status) : null,
      submittedBy: submittedBy,
      submittedAt: submittedAt,
      approvedBy: approvedBy,
      approvedAt: approvedAt,
      rejectedReason: rejectedReason,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'name': name,
        'imageUrl': imageUrl,
        if (description != null) 'description': description,
        'mainCategory': mainCategory,
        if (subCategoryId != null) 'subCategoryId': subCategoryId,
        'basePrice': basePrice,
        'optionGroupRefs': optionGroupRefs,
        // countUsage fallback: optionGroupRefs.id 평면 배열
        // Firestore arrayContains 는 Map 내 필드 비교 불가 → 별도 평면 필드로 유지
        'optionGroupRefIds': optionGroupRefs
            .map((r) => (r['id'] as String?) ?? '')
            .where((id) => id.isNotEmpty)
            .toList(growable: false),
        'soldOut': soldOut,
        'displayOrder': displayOrder,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        'scope': scope,
        if (brandId != null) 'brandId': brandId,
        'tags': tags,
        'visible': visible,
        'disabledOptionGroupIds': disabledOptionGroupIds,
        'disabledOptionItemIds': disabledOptionItemIds,
        if (status != null) 'status': status,
        if (submittedBy != null) 'submittedBy': submittedBy,
        if (submittedAt != null)
          'submittedAt': Timestamp.fromDate(submittedAt!),
        if (approvedBy != null) 'approvedBy': approvedBy,
        if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
        if (rejectedReason != null) 'rejectedReason': rejectedReason,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
