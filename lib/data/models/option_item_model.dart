import 'package:qradar/domain/entities/option_item_entity.dart';

/// 옵션 아이템 매퍼 (그룹 문서 내 배열 요소).
class OptionItemModel {
  final String id;
  final String label;
  final int priceDelta;

  const OptionItemModel({
    required this.id,
    required this.label,
    this.priceDelta = 0,
  });

  factory OptionItemModel.fromMap(Map<String, dynamic> map) {
    return OptionItemModel(
      id: (map['id'] as String?) ?? '',
      label: (map['label'] as String?) ?? '',
      priceDelta: (map['priceDelta'] as num?)?.toInt() ?? 0,
    );
  }

  factory OptionItemModel.fromEntity(OptionItemEntity entity) {
    return OptionItemModel(
      id: entity.id,
      label: entity.label,
      priceDelta: entity.priceDelta,
    );
  }

  OptionItemEntity toEntity() {
    return OptionItemEntity(
      id: id,
      label: label,
      priceDelta: priceDelta,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'label': label,
        'priceDelta': priceDelta,
      };
}
