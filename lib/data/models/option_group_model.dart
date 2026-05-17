import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/data/models/option_item_model.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/option_scope.dart';
import 'package:qradar/domain/entities/option_selection_type.dart';

/// 옵션 그룹 매퍼.
///
/// - 글로벌(master): `optionGroups/{id}` (scope=master)
/// - 브랜드(brand):  `brands/{brandId}/optionGroups/{id}` (scope=brand)
/// - 매장(store):    `stores/{storeId}/optionGroups/{id}` (scope=store)
class OptionGroupModel {
  final String id;
  final String scope; // 'master' | 'brand' | 'store'
  final String? brandId;
  final String? storeId;
  final String name;
  final String selectionType; // 'single' | 'multi'
  final bool required;
  final List<OptionItemModel> items;
  final int displayOrder;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OptionGroupModel({
    required this.id,
    required this.scope,
    this.brandId,
    this.storeId,
    required this.name,
    required this.selectionType,
    this.required = false,
    this.items = const [],
    this.displayOrder = 0,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  factory OptionGroupModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String scope,
    String? brandId,
    String? storeId,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawItems = (data['items'] as List<dynamic>?) ?? const [];
    final createdAtTs = data['createdAt'];
    final updatedAtTs = data['updatedAt'];
    return OptionGroupModel(
      id: doc.id,
      scope: scope,
      brandId: brandId,
      storeId: storeId,
      name: (data['name'] as String?) ?? '',
      selectionType: (data['selectionType'] as String?) ?? 'single',
      required: (data['required'] as bool?) ?? false,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(OptionItemModel.fromMap)
          .toList(growable: false),
      displayOrder: (data['displayOrder'] as num?)?.toInt() ?? 0,
      active: (data['active'] as bool?) ?? true,
      createdAt: createdAtTs is Timestamp ? createdAtTs.toDate() : null,
      updatedAt: updatedAtTs is Timestamp ? updatedAtTs.toDate() : null,
    );
  }

  factory OptionGroupModel.fromEntity(OptionGroupEntity entity) {
    return OptionGroupModel(
      id: entity.id,
      scope: entity.scope.asString,
      brandId: entity.brandId,
      storeId: entity.storeId,
      name: entity.name,
      selectionType: entity.selectionType.asString,
      required: entity.required,
      items:
          entity.items.map(OptionItemModel.fromEntity).toList(growable: false),
      displayOrder: entity.displayOrder,
      active: entity.active,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  OptionGroupEntity toEntity() {
    return OptionGroupEntity(
      id: id,
      scope: OptionScope.fromString(scope),
      brandId: brandId,
      storeId: storeId,
      name: name,
      selectionType: OptionSelectionType.fromString(selectionType),
      required: required,
      items: items.map((m) => m.toEntity()).toList(growable: false),
      displayOrder: displayOrder,
      active: active,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Firestore 저장용 Map. scope/brandId/storeId 는 컬렉션 경로에서 결정되므로 미포함.
  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'name': name,
        'selectionType': selectionType,
        'required': required,
        'items': items.map((m) => m.toMap()).toList(growable: false),
        'displayOrder': displayOrder,
        'active': active,
      };
}
