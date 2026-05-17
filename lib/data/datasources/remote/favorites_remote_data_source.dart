import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/data/models/favorite_menu_item_model.dart';
import 'package:qradar/data/models/favorite_store_model.dart';

/// Firestore 즐겨찾기 원격 데이터소스.
///
/// 컬렉션:
/// - `users/{uid}/favoriteStores/{storeId}`
/// - `users/{uid}/favoriteMenuItems/{storeId}_{menuItemId}`
///
/// **Firestore 직접 사용은 본 파일에서만**. (Clean Architecture 절대 규칙)
class FavoritesRemoteDataSource {
  final FirebaseFirestore _firestore;

  FavoritesRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _favoriteStores(String uid) =>
      _firestore
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection(FirestorePaths.favoriteStores);

  CollectionReference<Map<String, dynamic>> _favoriteMenuItems(String uid) =>
      _firestore
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection(FirestorePaths.favoriteMenuItems);

  // ── Streams ────────────────────────────────────────────────────────────

  /// 즐겨찾기 매장 stream. addedAt desc.
  Stream<List<FavoriteStoreModel>> streamFavoriteStores(String uid) {
    return _favoriteStores(uid)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map(FavoriteStoreModel.fromFirestore)
            .toList(growable: false));
  }

  /// 즐겨찾기 매장-음료 페어 stream. addedAt desc.
  Stream<List<FavoriteMenuItemModel>> streamFavoriteMenuItems(String uid) {
    return _favoriteMenuItems(uid)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map(FavoriteMenuItemModel.fromFirestore)
            .toList(growable: false));
  }

  /// 단일 매장 즐겨찾기 doc 존재 여부 stream.
  Stream<bool> watchStoreExists(String uid, String storeId) {
    return _favoriteStores(uid).doc(storeId).snapshots().map((d) => d.exists);
  }

  /// 단일 매장-음료 페어 doc 존재 여부 stream.
  Stream<bool> watchMenuItemExists(
    String uid,
    String storeId,
    String menuItemId,
  ) {
    final id = FavoriteMenuItemModel.compositeId(
      storeId: storeId,
      menuItemId: menuItemId,
    );
    return _favoriteMenuItems(uid).doc(id).snapshots().map((d) => d.exists);
  }

  // ── Writes ─────────────────────────────────────────────────────────────

  /// 매장 즐겨찾기 추가 (이미 있으면 merge — race-safe).
  Future<void> setFavoriteStore(String uid, String storeId) async {
    await _favoriteStores(uid)
        .doc(storeId)
        .set(FavoriteStoreModel.toCreatePayload());
  }

  /// 매장 즐겨찾기 제거.
  Future<void> deleteFavoriteStore(String uid, String storeId) async {
    await _favoriteStores(uid).doc(storeId).delete();
  }

  /// 매장-음료 페어 즐겨찾기 추가.
  Future<void> setFavoriteMenuItem(
    String uid,
    String storeId,
    String menuItemId,
  ) async {
    final id = FavoriteMenuItemModel.compositeId(
      storeId: storeId,
      menuItemId: menuItemId,
    );
    await _favoriteMenuItems(uid).doc(id).set(
          FavoriteMenuItemModel.toCreatePayload(
            storeId: storeId,
            menuItemId: menuItemId,
          ),
        );
  }

  /// 매장-음료 페어 즐겨찾기 제거.
  Future<void> deleteFavoriteMenuItem(
    String uid,
    String storeId,
    String menuItemId,
  ) async {
    final id = FavoriteMenuItemModel.compositeId(
      storeId: storeId,
      menuItemId: menuItemId,
    );
    await _favoriteMenuItems(uid).doc(id).delete();
  }

  // ── Read once (toggle 시 exists 체크용) ────────────────────────────────

  Future<bool> getStoreExistsOnce(String uid, String storeId) async {
    final snap = await _favoriteStores(uid).doc(storeId).get();
    return snap.exists;
  }

  Future<bool> getMenuItemExistsOnce(
    String uid,
    String storeId,
    String menuItemId,
  ) async {
    final id = FavoriteMenuItemModel.compositeId(
      storeId: storeId,
      menuItemId: menuItemId,
    );
    final snap = await _favoriteMenuItems(uid).doc(id).get();
    return snap.exists;
  }
}
