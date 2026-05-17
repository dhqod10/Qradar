import 'package:qradar/domain/entities/order_item_entity.dart';
import 'package:qradar/domain/entities/selected_option.dart';

/// Firestore `orders/{orderId}.items[]` 라인 매퍼.
class OrderItemModel {
  final String menuItemId;
  final String menuItemName;
  final String imageUrl;
  final int quantity;
  final List<Map<String, dynamic>> selectedOptions;
  final int unitPriceWithOptions;
  final int lineTotal;

  const OrderItemModel({
    required this.menuItemId,
    required this.menuItemName,
    this.imageUrl = '',
    required this.quantity,
    required this.selectedOptions,
    required this.unitPriceWithOptions,
    required this.lineTotal,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    final rawOpts =
        (map['selectedOptions'] as List<dynamic>?) ?? const <dynamic>[];
    return OrderItemModel(
      menuItemId: (map['menuItemId'] as String?) ?? '',
      menuItemName: (map['menuItemName'] as String?) ?? '',
      imageUrl: (map['imageUrl'] as String?) ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      selectedOptions: rawOpts
          .whereType<Map<String, dynamic>>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList(growable: false),
      unitPriceWithOptions:
          (map['unitPriceWithOptions'] as num?)?.toInt() ?? 0,
      lineTotal: (map['lineTotal'] as num?)?.toInt() ?? 0,
    );
  }

  factory OrderItemModel.fromEntity(OrderItemEntity entity) {
    return OrderItemModel(
      menuItemId: entity.menuItemId,
      menuItemName: entity.menuItemName,
      imageUrl: entity.imageUrl,
      quantity: entity.quantity,
      selectedOptions: entity.selectedOptions
          .map((opt) => <String, dynamic>{
                'groupId': opt.groupId,
                'groupName': opt.groupName,
                'itemId': opt.itemId,
                'label': opt.label,
                'priceDelta': opt.priceDelta,
              })
          .toList(growable: false),
      unitPriceWithOptions: entity.unitPriceWithOptions,
      lineTotal: entity.lineTotal,
    );
  }

  OrderItemEntity toEntity() {
    return OrderItemEntity(
      menuItemId: menuItemId,
      menuItemName: menuItemName,
      imageUrl: imageUrl,
      quantity: quantity,
      selectedOptions: selectedOptions
          .map((m) => SelectedOption(
                groupId: (m['groupId'] as String?) ?? '',
                groupName: (m['groupName'] as String?) ?? '',
                itemId: (m['itemId'] as String?) ?? '',
                label: (m['label'] as String?) ?? '',
                priceDelta: (m['priceDelta'] as num?)?.toInt() ?? 0,
              ))
          .toList(growable: false),
      unitPriceWithOptions: unitPriceWithOptions,
      lineTotal: lineTotal,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'menuItemId': menuItemId,
        'menuItemName': menuItemName,
        'imageUrl': imageUrl,
        'quantity': quantity,
        'selectedOptions': selectedOptions,
        'unitPriceWithOptions': unitPriceWithOptions,
        'lineTotal': lineTotal,
      };
}
