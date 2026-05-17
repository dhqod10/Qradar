import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/data/models/main_category_model.dart';

/// Firestore `mainCategories/{id}` 원격 데이터소스.
class MainCategoryRemoteDataSource {
  final FirebaseFirestore _firestore;

  MainCategoryRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirestorePaths.mainCategories);

  /// 전체 또는 active 만 stream. displayOrder asc (client sort).
  ///
  /// orderBy('displayOrder') + where('active') 복합 인덱스 누락 시 stream 이
  /// error/retry 를 반복해 customer 측 카테고리 탭이 깜빡이는 회귀 발생 →
  /// orderBy 를 client 단으로 옮겨 인덱스 의존 제거.
  Stream<List<MainCategoryModel>> streamAll({bool activeOnly = false}) {
    Query<Map<String, dynamic>> query = _col;
    if (activeOnly) {
      query = query.where('active', isEqualTo: true);
    }
    return query.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => MainCategoryModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      return list;
    });
  }

  /// id 로 단건 조회.
  Future<MainCategoryModel?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return MainCategoryModel.fromFirestore(doc);
  }

  /// 등록 또는 수정 (set merge).
  Future<void> upsert(MainCategoryModel model) async {
    await _col.doc(model.id).set(model.toFirestore(), SetOptions(merge: true));
  }

  /// 삭제.
  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  /// menuItem 사용 수 (collectionGroup query).
  Future<int> countMenuItemUsage(String categoryId) async {
    final snap = await _firestore
        .collectionGroup(FirestorePaths.menuItems)
        .where('mainCategory', isEqualTo: categoryId)
        .count()
        .get();
    return snap.count ?? 0;
  }

  /// subCategory 사용 수.
  Future<int> countSubCategoryUsage(String categoryId) async {
    final snap = await _firestore
        .collection(FirestorePaths.subCategories)
        .where('mainCategory', isEqualTo: categoryId)
        .count()
        .get();
    return snap.count ?? 0;
  }

  /// 영향 데이터 상세: menuCount + distinctStoreCount.
  Future<({int menuCount, int storeCount})> countDetailedUsage(
      String categoryId) async {
    final menuSnap = await _firestore
        .collectionGroup(FirestorePaths.menuItems)
        .where('mainCategory', isEqualTo: categoryId)
        .get();
    final menuCount = menuSnap.docs.length;
    final storeCount = menuSnap.docs
        .map((doc) => doc.reference.parent.parent?.id ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;
    return (menuCount: menuCount, storeCount: storeCount);
  }

  /// 컬렉션이 비어있으면 기본 3개 시드 (idempotent).
  Future<void> seedDefaultsIfEmpty() async {
    final snap = await _col.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final batch = _firestore.batch();
    final defaults = [
      MainCategoryModel(
          id: 'coffee', label: '커피', displayOrder: 0, active: true),
      MainCategoryModel(
          id: 'nonCoffee', label: '논커피', displayOrder: 1, active: true),
      MainCategoryModel(
          id: 'dessert', label: '디저트', displayOrder: 2, active: true),
    ];
    for (final model in defaults) {
      batch.set(
        _col.doc(model.id),
        model.toFirestore(),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }
}
