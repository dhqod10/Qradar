import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/data/models/menu_override_model.dart';

/// Firestore `stores/{storeId}/menuOverrides/{masterMenuItemId}` 원격 데이터소스.
///
/// collectionGroup query 는 별도 인덱스 필요 (task: firestore_indexes).
class MenuOverrideRemoteDataSource {
  final FirebaseFirestore _db;

  MenuOverrideRemoteDataSource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _overrideCol(String storeId) =>
      _db
          .collection(FirestorePaths.stores)
          .doc(storeId)
          .collection(FirestorePaths.menuOverrides);

  /// 특정 매장의 override 전체 실시간 스트림.
  Stream<List<MenuOverrideModel>> streamByStore(String storeId) {
    return _overrideCol(storeId).snapshots().map(
          (snap) => snap.docs
              .map((doc) => MenuOverrideModel.fromFirestore(doc, storeId))
              .toList(growable: false),
        );
  }

  /// admin 승인 큐: status==pending (collectionGroup query).
  ///
  /// 인덱스: menuOverrides collectionGroup + status asc + submittedAt desc.
  Stream<List<MenuOverrideModel>> streamPending() {
    return _db
        .collectionGroup(FirestorePaths.menuOverrides)
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) =>
                  MenuOverrideModel.fromFirestoreCollectionGroup(doc))
              .toList(growable: false),
        );
  }

  /// 단건 조회.
  Future<MenuOverrideModel?> getByStoreAndMaster(
    String storeId,
    String masterMenuItemId,
  ) async {
    final doc = await _overrideCol(storeId).doc(masterMenuItemId).get();
    return doc.exists ? MenuOverrideModel.fromFirestore(doc, storeId) : null;
  }

  /// set (upsert).
  Future<void> set(
    String storeId,
    String masterMenuItemId,
    Map<String, dynamic> data,
  ) {
    return _overrideCol(storeId)
        .doc(masterMenuItemId)
        .set(data, SetOptions(merge: true));
  }

  /// 부분 update.
  Future<void> update(
    String storeId,
    String masterMenuItemId,
    Map<String, dynamic> partial,
  ) {
    return _overrideCol(storeId).doc(masterMenuItemId).update(partial);
  }

  /// 단건 삭제.
  Future<void> delete(String storeId, String masterMenuItemId) {
    return _overrideCol(storeId).doc(masterMenuItemId).delete();
  }

  /// 마스터 메뉴 cascade 삭제 — collectionGroup 조회 → batch delete (U6).
  Future<void> cascadeDeleteByMaster(String masterMenuItemId) async {
    final snap = await _db
        .collectionGroup(FirestorePaths.menuOverrides)
        .where('masterMenuItemId', isEqualTo: masterMenuItemId)
        .get();

    if (snap.docs.isEmpty) return;

    // Firestore batch는 최대 500건. 실운영에서는 청크 처리 필요.
    const chunkSize = 490;
    for (var i = 0; i < snap.docs.length; i += chunkSize) {
      final chunk = snap.docs.skip(i).take(chunkSize);
      final batch = _db.batch();
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  /// 매장 등록 시 미선택 마스터 메뉴를 일괄 excluded=true 로 batch seed (U2).
  Future<void> seedExclusionsForStore({
    required String storeId,
    required String brandId,
    required List<String> excludedMasterMenuItemIds,
    required String submittedBy,
  }) async {
    if (excludedMasterMenuItemIds.isEmpty) return;

    final now = Timestamp.fromDate(DateTime.now());
    const chunkSize = 490;
    for (var i = 0; i < excludedMasterMenuItemIds.length; i += chunkSize) {
      final chunk = excludedMasterMenuItemIds.skip(i).take(chunkSize);
      final batch = _db.batch();
      for (final masterMenuItemId in chunk) {
        final ref = _overrideCol(storeId).doc(masterMenuItemId);
        batch.set(ref, {
          'masterMenuItemId': masterMenuItemId,
          'storeId': storeId,
          'brandId': brandId,
          'excluded': true,
          'soldOut': false,
          'disabledOptionGroupIds': <String>[],
          'disabledOptionItemIds': <String>[],
          'status': 'pending',
          'submittedBy': submittedBy,
          'submittedAt': now,
          'updatedBy': 'brand',
          'updatedAt': now,
        }, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  /// 특정 마스터 메뉴에 priceOverride 가 설정된 매장 수 반환 (U7).
  Future<int> countStoresUsingPriceOverride(String masterMenuItemId) async {
    final snap = await _db
        .collectionGroup(FirestorePaths.menuOverrides)
        .where('masterMenuItemId', isEqualTo: masterMenuItemId)
        .where('status', isEqualTo: 'approved')
        .get();

    return snap.docs
        .where((doc) => doc.data()['priceOverride'] != null)
        .length;
  }
}
