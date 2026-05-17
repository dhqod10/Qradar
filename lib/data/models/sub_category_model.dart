import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/domain/entities/sub_category_entity.dart';

/// Firestore 부 카테고리 문서 매퍼.
///
/// - brand scope: `brands/{brandId}/subCategories/{id}`
/// - store scope: `stores/{storeId}/subCategories/{id}`
/// - legacy global: `subCategories/{id}` (scope == null)
class SubCategoryModel {
  final String id;
  final String mainCategory;
  final String name;
  final int displayOrder;
  final bool active;
  final String? scope;    // 'brand' | 'store' | null(legacy)
  final String? brandId;
  final String? storeId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SubCategoryModel({
    required this.id,
    required this.mainCategory,
    required this.name,
    this.displayOrder = 0,
    this.active = true,
    this.scope,
    this.brandId,
    this.storeId,
    this.createdAt,
    this.updatedAt,
  });

  factory SubCategoryModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    String? overrideBrandId,
    String? overrideStoreId,
    String? overrideScope,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    return SubCategoryModel(
      id: doc.id,
      mainCategory: (data['mainCategory'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      displayOrder: (data['displayOrder'] as num?)?.toInt() ?? 0,
      active: (data['active'] as bool?) ?? true,
      scope: overrideScope ?? (data['scope'] as String?),
      brandId: overrideBrandId ?? (data['brandId'] as String?),
      storeId: overrideStoreId ?? (data['storeId'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory SubCategoryModel.fromEntity(SubCategoryEntity entity) {
    return SubCategoryModel(
      id: entity.id,
      mainCategory: entity.mainCategoryCode,
      name: entity.name,
      displayOrder: entity.displayOrder,
      active: entity.active,
      scope: entity.scope?.name,
      brandId: entity.brandId,
      storeId: entity.storeId,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  SubCategoryEntity toEntity() {
    return SubCategoryEntity(
      id: id,
      mainCategoryCode: mainCategory,
      name: name,
      displayOrder: displayOrder,
      active: active,
      scope: scope == 'brand'
          ? SubCategoryScope.brand
          : scope == 'store'
              ? SubCategoryScope.store
              : null,
      brandId: brandId,
      storeId: storeId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'mainCategory': mainCategory,
        'name': name,
        'displayOrder': displayOrder,
        'active': active,
        if (scope != null) 'scope': scope,
        if (brandId != null) 'brandId': brandId,
        if (storeId != null) 'storeId': storeId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> toFirestoreCreate() => <String, dynamic>{
        ...toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
      };
}
