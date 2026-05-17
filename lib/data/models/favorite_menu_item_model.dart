import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/domain/entities/favorite_menu_item_entity.dart';

/// Firestore `users/{uid}/favoriteMenuItems/{compositeId}` 문서 매퍼.
///
/// - doc.id == `'${storeId}_${menuItemId}'` (composite, 파싱 X — 필드에 별도 저장)
/// - 필드:
///   - `storeId: String`
///   - `menuItemId: String`
///   - `addedAt: Timestamp`
class FavoriteMenuItemModel {
  final String storeId;
  final String menuItemId;
  final DateTime addedAt;

  const FavoriteMenuItemModel({
    required this.storeId,
    required this.menuItemId,
    required this.addedAt,
  });

  factory FavoriteMenuItemModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final ts = data['addedAt'];
    return FavoriteMenuItemModel(
      storeId: (data['storeId'] as String?) ?? '',
      menuItemId: (data['menuItemId'] as String?) ?? '',
      addedAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }

  factory FavoriteMenuItemModel.fromEntity(FavoriteMenuItemEntity entity) {
    return FavoriteMenuItemModel(
      storeId: entity.storeId,
      menuItemId: entity.menuItemId,
      addedAt: entity.addedAt,
    );
  }

  FavoriteMenuItemEntity toEntity() {
    return FavoriteMenuItemEntity(
      storeId: storeId,
      menuItemId: menuItemId,
      addedAt: addedAt,
    );
  }

  /// composite doc id 헬퍼.
  static String compositeId({
    required String storeId,
    required String menuItemId,
  }) =>
      '${storeId}_$menuItemId';

  /// Firestore set 용 페이로드. 서버 타임스탬프 사용.
  static Map<String, dynamic> toCreatePayload({
    required String storeId,
    required String menuItemId,
  }) =>
      <String, dynamic>{
        'storeId': storeId,
        'menuItemId': menuItemId,
        'addedAt': FieldValue.serverTimestamp(),
      };
}
