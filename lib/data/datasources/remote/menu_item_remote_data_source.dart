import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/data/models/menu_item_model.dart';

/// Firestore `stores/{storeId}/menuItems` 서브컬렉션 원격 데이터소스.
class MenuItemRemoteDataSource {
  final FirebaseFirestore _firestore;

  MenuItemRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _menuItems(String storeId) =>
      _firestore
          .collection(FirestorePaths.stores)
          .doc(storeId)
          .collection(FirestorePaths.menuItems);

  /// 매장 메뉴 stream. displayOrder asc.
  Stream<List<MenuItemModel>> streamByStore(String storeId) {
    return _menuItems(storeId)
        .orderBy('displayOrder')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MenuItemModel.fromFirestore(doc, storeId: storeId))
            .toList(growable: false));
  }

  /// 매장 내 단일 메뉴 stream. 삭제되면 null.
  Stream<MenuItemModel?> streamById({
    required String storeId,
    required String menuItemId,
  }) {
    return _menuItems(storeId).doc(menuItemId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return MenuItemModel.fromFirestore(doc, storeId: storeId);
    });
  }

  /// 시드/관리용 upsert.
  Future<void> upsert(MenuItemModel model) async {
    await _menuItems(model.storeId)
        .doc(model.id)
        .set(model.toFirestore(), SetOptions(merge: true));
  }

  // ─── 점포 한정 메뉴 CRUD (sub-phase 3) ─────────────────────────────────

  /// 점포 한정 메뉴 신규 생성. 자동 ID. 생성된 ID 반환.
  Future<String> createStoreOnly(
    String storeId,
    Map<String, dynamic> data,
  ) async {
    final ref = _menuItems(storeId).doc();
    await ref.set(data);
    return ref.id;
  }

  /// 점포 한정 메뉴 partial update.
  Future<void> updateStoreOnly(
    String storeId,
    String menuItemId,
    Map<String, dynamic> partial,
  ) {
    return _menuItems(storeId).doc(menuItemId).update(partial);
  }

  /// 점포 한정 메뉴 삭제.
  Future<void> deleteStoreOnly(String storeId, String menuItemId) {
    return _menuItems(storeId).doc(menuItemId).delete();
  }

  /// admin 승인 큐: scope==store && status==pending (collectionGroup query).
  Stream<List<MenuItemModel>> streamPendingStoreOnly() {
    return _firestore
        .collectionGroup(FirestorePaths.menuItems)
        .where('scope', isEqualTo: 'store')
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              // collectionGroup path: stores/{storeId}/menuItems/{id}
              final segments = doc.reference.path.split('/');
              final storeId = segments.length >= 2 ? segments[1] : '';
              return MenuItemModel.fromFirestore(doc, storeId: storeId);
            }).toList(growable: false));
  }
}
