import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/domain/entities/main_category_entity.dart';

/// Firestore `mainCategories/{id}` 문서 매퍼.
class MainCategoryModel {
  final String id;
  final String label;
  final int displayOrder;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MainCategoryModel({
    required this.id,
    required this.label,
    this.displayOrder = 0,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  factory MainCategoryModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return MainCategoryModel(
      id: doc.id,
      label: (data['label'] as String?) ?? '',
      displayOrder: (data['displayOrder'] as num?)?.toInt() ?? 0,
      active: (data['active'] as bool?) ?? true,
      createdAt: _toDate(data['createdAt']),
      updatedAt: _toDate(data['updatedAt']),
    );
  }

  factory MainCategoryModel.fromEntity(MainCategoryEntity entity) {
    return MainCategoryModel(
      id: entity.id,
      label: entity.label,
      displayOrder: entity.displayOrder,
      active: entity.active,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  MainCategoryEntity toEntity() {
    return MainCategoryEntity(
      id: id,
      label: label,
      displayOrder: displayOrder,
      active: active,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'label': label,
        'displayOrder': displayOrder,
        'active': active,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
