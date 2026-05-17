import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/data/models/sub_category_model.dart';

/// Firestore 부 카테고리 원격 데이터소스 (2-tier).
///
/// brand scope : `brands/{brandId}/subCategories/`
/// store scope : `stores/{storeId}/subCategories/`
/// legacy global: `subCategories/` (customer 읽기 호환 유지)
class SubCategoryRemoteDataSource {
  final FirebaseFirestore _firestore;

  SubCategoryRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ── Legacy global (customer 호환) ────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _globalCol =>
      _firestore.collection(FirestorePaths.subCategories);

  /// 메인 카테고리 코드에 속한 active 부 카테고리 (legacy global).
  Stream<List<SubCategoryModel>> streamByMainCategory(String mainCategory) {
    return _globalCol
        .where('mainCategory', isEqualTo: mainCategory)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => SubCategoryModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      return list;
    });
  }

  // ── Brand scope ──────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _brandSubCol(String brandId) =>
      _firestore
          .collection(FirestorePaths.brands)
          .doc(brandId)
          .collection(FirestorePaths.subCategoriesSubcollection);

  Stream<List<SubCategoryModel>> streamByBrand({
    required String brandId,
    bool activeOnly = false,
  }) {
    Query<Map<String, dynamic>> q = _brandSubCol(brandId);
    if (activeOnly) q = q.where('active', isEqualTo: true);
    return q.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => SubCategoryModel.fromFirestore(
                doc,
                overrideBrandId: brandId,
                overrideScope: 'brand',
              ))
          .toList();
      list.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      return list;
    });
  }

  Future<SubCategoryModel?> getBrandSubById({
    required String brandId,
    required String id,
  }) async {
    final doc = await _brandSubCol(brandId).doc(id).get();
    if (!doc.exists) return null;
    return SubCategoryModel.fromFirestore(
      doc,
      overrideBrandId: brandId,
      overrideScope: 'brand',
    );
  }

  Future<void> upsertBrandSub({
    required String brandId,
    required SubCategoryModel model,
    required bool isNew,
  }) async {
    final ref = _brandSubCol(brandId).doc(model.id);
    final data = isNew ? model.toFirestoreCreate() : model.toFirestore();
    await ref.set(data, SetOptions(merge: true));
  }

  Future<void> toggleBrandSubActive({
    required String brandId,
    required String id,
    required bool active,
  }) async {
    await _brandSubCol(brandId).doc(id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteBrandSub({
    required String brandId,
    required String id,
  }) async {
    await _brandSubCol(brandId).doc(id).delete();
  }

  Future<bool> findDuplicateNameInBrand({
    required String brandId,
    required String normalizedName,
    String? excludeId,
  }) async {
    final snap = await _brandSubCol(brandId)
        .where('normalizedName', isEqualTo: normalizedName)
        .get();
    if (excludeId == null) return snap.docs.isNotEmpty;
    return snap.docs.any((d) => d.id != excludeId);
  }

  // ── Store scope ──────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _storeSubCol(String storeId) =>
      _firestore
          .collection(FirestorePaths.stores)
          .doc(storeId)
          .collection(FirestorePaths.subCategoriesSubcollection);

  Stream<List<SubCategoryModel>> streamByStore({
    required String storeId,
    bool activeOnly = false,
  }) {
    Query<Map<String, dynamic>> q = _storeSubCol(storeId);
    if (activeOnly) q = q.where('active', isEqualTo: true);
    return q.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => SubCategoryModel.fromFirestore(
                doc,
                overrideStoreId: storeId,
                overrideScope: 'store',
              ))
          .toList();
      list.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      return list;
    });
  }

  Future<SubCategoryModel?> getStoreSubById({
    required String storeId,
    required String id,
  }) async {
    final doc = await _storeSubCol(storeId).doc(id).get();
    if (!doc.exists) return null;
    return SubCategoryModel.fromFirestore(
      doc,
      overrideStoreId: storeId,
      overrideScope: 'store',
    );
  }

  Future<void> upsertStoreSub({
    required String storeId,
    required SubCategoryModel model,
    required bool isNew,
  }) async {
    final ref = _storeSubCol(storeId).doc(model.id);
    final data = isNew ? model.toFirestoreCreate() : model.toFirestore();
    await ref.set(data, SetOptions(merge: true));
  }

  Future<void> toggleStoreSubActive({
    required String storeId,
    required String id,
    required bool active,
  }) async {
    await _storeSubCol(storeId).doc(id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteStoreSub({
    required String storeId,
    required String id,
  }) async {
    await _storeSubCol(storeId).doc(id).delete();
  }

  Future<bool> findDuplicateNameInStore({
    required String storeId,
    required String normalizedName,
    String? excludeId,
  }) async {
    final snap = await _storeSubCol(storeId)
        .where('normalizedName', isEqualTo: normalizedName)
        .get();
    if (excludeId == null) return snap.docs.isNotEmpty;
    return snap.docs.any((d) => d.id != excludeId);
  }

  // ── Usage (collectionGroup) ───────────────────────────────────────────────

  /// subCategoryId 를 참조하는 menuItem 수 (collectionGroup).
  Future<int> countMenuItemUsage(String subCategoryId) async {
    final snap = await _firestore
        .collectionGroup(FirestorePaths.menuItems)
        .where('subCategoryId', isEqualTo: subCategoryId)
        .count()
        .get();
    return snap.count ?? 0;
  }

  // ── Legacy upsert (seed 호환) ────────────────────────────────────────────

  /// 시드/관리용 upsert (global collection).
  Future<void> upsert(SubCategoryModel model) async {
    await _globalCol
        .doc(model.id)
        .set(model.toFirestore(), SetOptions(merge: true));
  }
}
