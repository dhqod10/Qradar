import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/data/models/option_group_model.dart';
import 'package:qradar/domain/entities/option_scope.dart';

/// 옵션 그룹 CRUD 원격 데이터소스 (brand/store scope 신규 CRUD 전용).
///
/// - brand: `brands/{brandId}/optionGroups/{id}`
/// - store: `stores/{storeId}/optionGroups/{id}`
/// - master: read-only (기존 [OptionRemoteDataSource] 에서 담당)
class OptionGroupRemoteDataSource {
  final FirebaseFirestore _firestore;

  OptionGroupRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ── 컬렉션 참조 헬퍼 ────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _brandCol(String brandId) =>
      _firestore
          .collection(FirestorePaths.brands)
          .doc(brandId)
          .collection(FirestorePaths.brandOptionGroupsSubcollection);

  CollectionReference<Map<String, dynamic>> _storeCol(String storeId) =>
      _firestore
          .collection(FirestorePaths.stores)
          .doc(storeId)
          .collection(FirestorePaths.optionGroupsSubcollection);

  DocumentReference<Map<String, dynamic>> _brandDoc(
          String brandId, String id) =>
      _brandCol(brandId).doc(id);

  DocumentReference<Map<String, dynamic>> _storeDoc(
          String storeId, String id) =>
      _storeCol(storeId).doc(id);

  // ── Stream ──────────────────────────────────────────────────────────────

  /// brand scope 옵션 그룹 stream (displayOrder asc).
  Stream<List<OptionGroupModel>> watchByBrand({
    required String brandId,
    bool activeOnly = false,
  }) {
    Query<Map<String, dynamic>> q =
        _brandCol(brandId).orderBy('displayOrder');
    if (activeOnly) q = q.where('active', isEqualTo: true);
    return q.snapshots().map((snap) => snap.docs
        .map((doc) => OptionGroupModel.fromFirestore(doc,
            scope: 'brand', brandId: brandId))
        .toList(growable: false));
  }

  /// store scope 옵션 그룹 stream (displayOrder asc).
  Stream<List<OptionGroupModel>> watchByStore({
    required String storeId,
    bool activeOnly = false,
  }) {
    Query<Map<String, dynamic>> q =
        _storeCol(storeId).orderBy('displayOrder');
    if (activeOnly) q = q.where('active', isEqualTo: true);
    return q.snapshots().map((snap) => snap.docs
        .map((doc) => OptionGroupModel.fromFirestore(doc,
            scope: 'store', storeId: storeId))
        .toList(growable: false));
  }

  // ── CRUD ────────────────────────────────────────────────────────────────

  /// brand scope 옵션 그룹 upsert.
  Future<String> upsertBrand({
    required String brandId,
    required OptionGroupModel model,
  }) async {
    final data = {
      ...model.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (model.id.isEmpty) {
      final ref = await _brandCol(brandId).add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } else {
      await _brandDoc(brandId, model.id).set(data, SetOptions(merge: true));
      return model.id;
    }
  }

  /// store scope 옵션 그룹 upsert.
  Future<String> upsertStore({
    required String storeId,
    required OptionGroupModel model,
  }) async {
    final data = {
      ...model.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (model.id.isEmpty) {
      final ref = await _storeCol(storeId).add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } else {
      await _storeDoc(storeId, model.id).set(data, SetOptions(merge: true));
      return model.id;
    }
  }

  /// brand scope active 토글.
  Future<void> toggleActiveBrand({
    required String brandId,
    required String id,
    required bool active,
  }) async {
    await _brandDoc(brandId, id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// store scope active 토글.
  Future<void> toggleActiveStore({
    required String storeId,
    required String id,
    required bool active,
  }) async {
    await _storeDoc(storeId, id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// brand scope 옵션 그룹 삭제.
  Future<void> deleteBrand({
    required String brandId,
    required String id,
  }) =>
      _brandDoc(brandId, id).delete();

  /// store scope 옵션 그룹 삭제.
  Future<void> deleteStore({
    required String storeId,
    required String id,
  }) =>
      _storeDoc(storeId, id).delete();

  // ── 검증 ────────────────────────────────────────────────────────────────

  /// brand scope 내 동일 이름 존재 여부 (normalized: trim + toLowerCase).
  Future<bool> findDuplicateNameBrand({
    required String brandId,
    required String name,
    String? excludeId,
  }) async {
    final normalized = name.trim().toLowerCase();
    final snap = await _brandCol(brandId).get();
    return snap.docs.any((doc) {
      if (excludeId != null && doc.id == excludeId) return false;
      final docName = ((doc.data()['name'] as String?) ?? '').trim().toLowerCase();
      return docName == normalized;
    });
  }

  /// store scope 내 동일 이름 존재 여부.
  Future<bool> findDuplicateNameStore({
    required String storeId,
    required String name,
    String? excludeId,
  }) async {
    final normalized = name.trim().toLowerCase();
    final snap = await _storeCol(storeId).get();
    return snap.docs.any((doc) {
      if (excludeId != null && doc.id == excludeId) return false;
      final docName = ((doc.data()['name'] as String?) ?? '').trim().toLowerCase();
      return docName == normalized;
    });
  }

  /// 특정 옵션 그룹 ID 를 참조하는 menuItem 수.
  ///
  /// Firestore 배열 직렬화 제약으로 인해 평면 필드 fallback 사용:
  /// `optionGroupRefIds: List<String>` 에 arrayContains 쿼리.
  ///
  /// brand 마스터 메뉴(`brands/{brandId}/menuItems`) + store 메뉴(`stores/{storeId}/menuItems`)
  /// 양쪽이 동일한 collection id `menuItems` 라 collectionGroup 한 번 쿼리로
  /// 양쪽을 합산한다 (이전에 두 번 쿼리해서 결과 2배 회귀).
  Future<int> countUsage({required String id}) async {
    final snap = await _firestore
        .collectionGroup(FirestorePaths.menuItems)
        .where('optionGroupRefIds', arrayContains: id)
        .count()
        .get();
    return snap.count ?? 0;
  }

  // ── Batch fetch (selector 용) ────────────────────────────────────────────

  /// brand scope 전체 1회 fetch (active 필터 선택).
  Future<List<OptionGroupModel>> fetchAllBrand({
    required String brandId,
    bool activeOnly = true,
  }) async {
    Query<Map<String, dynamic>> q =
        _brandCol(brandId).orderBy('displayOrder');
    if (activeOnly) q = q.where('active', isEqualTo: true);
    final snap = await q.get();
    return snap.docs
        .map((doc) => OptionGroupModel.fromFirestore(doc,
            scope: 'brand', brandId: brandId))
        .toList(growable: false);
  }

  /// store scope 전체 1회 fetch.
  Future<List<OptionGroupModel>> fetchAllStore({
    required String storeId,
    bool activeOnly = true,
  }) async {
    Query<Map<String, dynamic>> q =
        _storeCol(storeId).orderBy('displayOrder');
    if (activeOnly) q = q.where('active', isEqualTo: true);
    final snap = await q.get();
    return snap.docs
        .map((doc) => OptionGroupModel.fromFirestore(doc,
            scope: 'store', storeId: storeId))
        .toList(growable: false);
  }

  /// scope 에 따라 단일 doc fetch.
  Future<OptionGroupModel?> fetchOne({
    required OptionScope scope,
    required String id,
    String? brandId,
    String? storeId,
  }) async {
    DocumentSnapshot<Map<String, dynamic>> doc;
    switch (scope) {
      case OptionScope.brand:
        if (brandId == null) return null;
        doc = await _brandDoc(brandId, id).get();
        if (!doc.exists) return null;
        return OptionGroupModel.fromFirestore(doc,
            scope: 'brand', brandId: brandId);
      case OptionScope.store:
        if (storeId == null) return null;
        doc = await _storeDoc(storeId, id).get();
        if (!doc.exists) return null;
        return OptionGroupModel.fromFirestore(doc,
            scope: 'store', storeId: storeId);
      case OptionScope.master:
        return null; // master 는 OptionRemoteDataSource 에서 담당
    }
  }
}
