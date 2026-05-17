import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/domain/entities/favorite_store_entity.dart';

/// Firestore `users/{uid}/favoriteStores/{storeId}` 문서 매퍼.
///
/// - doc.id == storeId
/// - 필드: `addedAt: Timestamp` (서버 타임스탬프)
class FavoriteStoreModel {
  final String storeId;
  final DateTime addedAt;

  const FavoriteStoreModel({
    required this.storeId,
    required this.addedAt,
  });

  factory FavoriteStoreModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final ts = data['addedAt'];
    return FavoriteStoreModel(
      storeId: doc.id,
      addedAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }

  factory FavoriteStoreModel.fromEntity(FavoriteStoreEntity entity) {
    return FavoriteStoreModel(
      storeId: entity.storeId,
      addedAt: entity.addedAt,
    );
  }

  FavoriteStoreEntity toEntity() {
    return FavoriteStoreEntity(
      storeId: storeId,
      addedAt: addedAt,
    );
  }

  /// Firestore set 용 페이로드. 서버 타임스탬프 사용.
  static Map<String, dynamic> toCreatePayload() => <String, dynamic>{
        'addedAt': FieldValue.serverTimestamp(),
      };
}
