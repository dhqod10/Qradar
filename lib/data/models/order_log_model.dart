import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/domain/entities/order_log_entity.dart';
import 'package:qradar/domain/entities/selected_option.dart';

/// Firestore `users/{uid}/orderLogs/{logId}` 문서 매퍼.
///
/// 필드:
/// - `userId: String`
/// - `storeId: String`, `storeName: String`
/// - `items: List<Map>` — `{menuItemId, menuItemName, quantity, optionsSnapshot[], lineTotal}`
///   - `optionsSnapshot[i]`: `{groupId, groupName, itemId, label, priceDelta}`
/// - `total: int`
/// - `paidAt: Timestamp`
/// - `paymentMethod: String` (현재 시드는 `'seed'`)
class OrderLogModel {
  final String id;
  final String userId;
  final String storeId;
  final String storeName;
  final List<Map<String, dynamic>> items;
  final int total;
  final DateTime paidAt;
  final String paymentMethod;

  const OrderLogModel({
    required this.id,
    required this.userId,
    required this.storeId,
    required this.storeName,
    required this.items,
    required this.total,
    required this.paidAt,
    this.paymentMethod = '',
  });

  factory OrderLogModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final ts = data['paidAt'];
    final rawItems = (data['items'] as List<dynamic>?) ?? const [];
    return OrderLogModel(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      storeId: (data['storeId'] as String?) ?? '',
      storeName: (data['storeName'] as String?) ?? '',
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList(growable: false),
      total: (data['total'] as num?)?.toInt() ?? 0,
      paidAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      paymentMethod: (data['paymentMethod'] as String?) ?? '',
    );
  }

  factory OrderLogModel.fromEntity(OrderLogEntity entity) {
    return OrderLogModel(
      id: entity.id,
      userId: entity.userId,
      storeId: entity.storeId,
      storeName: entity.storeName,
      items: entity.items
          .map((it) => <String, dynamic>{
                'menuItemId': it.menuItemId,
                'menuItemName': it.menuItemName,
                'quantity': it.quantity,
                'optionsSnapshot': it.optionsSnapshot
                    .map((opt) => <String, dynamic>{
                          'groupId': opt.groupId,
                          'groupName': opt.groupName,
                          'itemId': opt.itemId,
                          'label': opt.label,
                          'priceDelta': opt.priceDelta,
                        })
                    .toList(growable: false),
                'lineTotal': it.lineTotal,
              })
          .toList(growable: false),
      total: entity.total,
      paidAt: entity.paidAt,
      paymentMethod: entity.paymentMethod,
    );
  }

  OrderLogEntity toEntity() {
    return OrderLogEntity(
      id: id,
      userId: userId,
      storeId: storeId,
      storeName: storeName,
      items: items.map(_mapItem).toList(growable: false),
      total: total,
      paidAt: paidAt,
      paymentMethod: paymentMethod,
    );
  }

  static OrderLogItem _mapItem(Map<String, dynamic> raw) {
    final rawOpts =
        (raw['optionsSnapshot'] as List<dynamic>?) ?? const <dynamic>[];
    return OrderLogItem(
      menuItemId: (raw['menuItemId'] as String?) ?? '',
      menuItemName: (raw['menuItemName'] as String?) ?? '',
      quantity: (raw['quantity'] as num?)?.toInt() ?? 0,
      optionsSnapshot: rawOpts
          .whereType<Map<String, dynamic>>()
          .map(
            (m) => SelectedOption(
              groupId: (m['groupId'] as String?) ?? '',
              groupName: (m['groupName'] as String?) ?? '',
              itemId: (m['itemId'] as String?) ?? '',
              label: (m['label'] as String?) ?? '',
              priceDelta: (m['priceDelta'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(growable: false),
      lineTotal: (raw['lineTotal'] as num?)?.toInt() ?? 0,
    );
  }

  /// Firestore set 페이로드. paidAt 은 Timestamp 로 변환.
  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'userId': userId,
        'storeId': storeId,
        'storeName': storeName,
        'items': items,
        'total': total,
        'paidAt': Timestamp.fromDate(paidAt),
        'paymentMethod': paymentMethod,
      };
}
