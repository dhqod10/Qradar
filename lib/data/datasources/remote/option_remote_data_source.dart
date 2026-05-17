import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/data/models/option_group_model.dart';

/// 옵션 그룹 원격 데이터소스.
///
/// - 글로벌(master): `optionGroups/{id}`
/// - 매장(store):  `stores/{storeId}/optionGroups/{id}`
class OptionRemoteDataSource {
  final FirebaseFirestore _firestore;

  OptionRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _master(String id) =>
      _firestore.collection(FirestorePaths.optionGroups).doc(id);

  DocumentReference<Map<String, dynamic>> _store(String storeId, String id) =>
      _firestore
          .collection(FirestorePaths.stores)
          .doc(storeId)
          .collection(FirestorePaths.optionGroupsSubcollection)
          .doc(id);

  /// 글로벌 옵션 그룹 1건. 없으면 null.
  Future<OptionGroupModel?> getMaster(String id) async {
    final doc = await _master(id).get();
    if (!doc.exists) return null;
    return OptionGroupModel.fromFirestore(doc, scope: 'master');
  }

  /// brand scope 옵션 그룹 1건. 없으면 null.
  Future<OptionGroupModel?> getBrand({
    required String brandId,
    required String id,
  }) async {
    final doc = await _firestore
        .collection(FirestorePaths.brands)
        .doc(brandId)
        .collection(FirestorePaths.brandOptionGroupsSubcollection)
        .doc(id)
        .get();
    if (!doc.exists) return null;
    return OptionGroupModel.fromFirestore(doc, scope: 'brand', brandId: brandId);
  }

  /// 매장 옵션 그룹 1건. 없으면 null.
  Future<OptionGroupModel?> getStore({
    required String storeId,
    required String id,
  }) async {
    final doc = await _store(storeId, id).get();
    if (!doc.exists) return null;
    return OptionGroupModel.fromFirestore(doc, scope: 'store', storeId: storeId);
  }

  /// 글로벌(master) 옵션 그룹 전체 목록.
  Future<List<OptionGroupModel>> fetchAllMaster() async {
    final snap =
        await _firestore.collection(FirestorePaths.optionGroups).get();
    return snap.docs
        .map((doc) => OptionGroupModel.fromFirestore(doc, scope: 'master'))
        .toList(growable: false);
  }

  /// 매장(store) 옵션 그룹 전체 목록.
  Future<List<OptionGroupModel>> fetchAllStore(String storeId) async {
    final snap = await _firestore
        .collection(FirestorePaths.stores)
        .doc(storeId)
        .collection(FirestorePaths.optionGroupsSubcollection)
        .get();
    return snap.docs
        .map((doc) => OptionGroupModel.fromFirestore(doc,
            scope: 'store', storeId: storeId))
        .toList(growable: false);
  }

  /// 시드/관리용 글로벌 upsert.
  Future<void> upsertMaster(OptionGroupModel model) async {
    await _master(model.id).set(model.toFirestore(), SetOptions(merge: true));
  }

  /// 시드/관리용 매장 upsert.
  Future<void> upsertStore(OptionGroupModel model) async {
    final storeId = model.storeId;
    if (storeId == null || storeId.isEmpty) {
      throw ArgumentError('store-scoped OptionGroup requires storeId');
    }
    await _store(storeId, model.id)
        .set(model.toFirestore(), SetOptions(merge: true));
  }
}
