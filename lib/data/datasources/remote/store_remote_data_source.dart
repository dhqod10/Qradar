import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/data/models/store_model.dart';

/// Firestore `stores` 컬렉션 원격 데이터소스.
///
/// 주의: Firestore는 지리공간 쿼리를 기본 제공하지 않으므로,
/// 전체(또는 상한) 문서를 가져와 클라이언트에서 거리·카테고리 필터를 수행한다.
/// 매장 수가 많아지면 Geohash 기반 인덱싱으로 전환 필요.
///
/// sub-phase 2: 승인 관련 메서드 추가 (T4 ownership 검증은 RepositoryImpl 에서 수행).
class StoreRemoteDataSource {
  final FirebaseFirestore _firestore;

  StoreRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _stores =>
      _firestore.collection(FirestorePaths.stores);

  /// averageScore 내림차순 상위 limit개. 필터링은 Repository에서 수행.
  Future<List<StoreModel>> fetchAll({int limit = 100}) async {
    final snapshot = await _stores
        .orderBy('averageScore', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(StoreModel.fromFirestore).toList(growable: false);
  }

  /// 모든 매장 실시간 스트림 (status 무관 — admin 전용).
  Stream<List<StoreModel>> streamAll() {
    return _stores
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(StoreModel.fromFirestore).toList(growable: false));
  }

  /// status=pending 매장 실시간 스트림 (admin 승인 큐).
  Stream<List<StoreModel>> streamPending() {
    return _stores
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(StoreModel.fromFirestore).toList(growable: false));
  }

  /// 매장 단건 조회.
  Future<StoreModel?> getById(String storeId) async {
    final doc = await _stores.doc(storeId).get();
    if (!doc.exists) return null;
    return StoreModel.fromFirestore(doc);
  }

  /// 신규 매장 생성 (점주 등록 — brandId=null 강제). 생성된 문서 ID 반환.
  Future<String> create(StoreModel model) async {
    final ref = await _stores.add(model.toFirestoreForCreate());
    return ref.id;
  }

  /// brand 신규 매장 생성 (brandId 포함). 생성된 문서 ID 반환.
  Future<String> createForBrand(StoreModel model) async {
    final ref = await _stores.add(model.toFirestoreForBrandCreate());
    return ref.id;
  }

  /// 매장 핵심 필드 수정 (status=pending 회귀).
  Future<void> updateCoreFields(
    String storeId,
    Map<String, dynamic> fields,
  ) async {
    await _stores.doc(storeId).update(fields);
  }

  /// 매장 운영 필드 수정 (status 보존, partial update).
  Future<void> updateOperationFields(
    String storeId,
    Map<String, dynamic> fields,
  ) async {
    await _stores.doc(storeId).update(fields);
  }

  /// admin 승인/반려 partial update.
  Future<void> updateApprovalFields(
    String storeId,
    Map<String, dynamic> fields,
  ) async {
    await _stores.doc(storeId).update(fields);
  }

  /// 매장 삭제.
  Future<void> delete(String storeId) async {
    await _stores.doc(storeId).delete();
  }

  /// 특정 brandId 에 속하는 매장 실시간 스트림 (brand 전용).
  ///
  /// V6: brand 가맹점 화면은 approved 매장만 노출. pending/rejected 는 admin 승인 큐로.
  Stream<List<StoreModel>> streamByBrand(String brandId) {
    return _stores
        .where('brandId', isEqualTo: brandId)
        .where('status', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(StoreModel.fromFirestore).toList(growable: false));
  }

  /// 특정 ownerId 매장을 실시간 감시. MVP: owner 당 1개 매장 가정.
  Stream<StoreModel?> watchByOwner(String ownerId) {
    return _stores
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return StoreModel.fromFirestore(snapshot.docs.first);
    });
  }

  // ── Deprecated ──────────────────────────────────────────────────────────

  /// @deprecated updateCoreFields / updateOperationFields 사용.
  @Deprecated('updateCoreFields 또는 updateOperationFields 사용')
  Future<void> update(StoreModel model) async {
    await _stores.doc(model.id).update({
      'name': model.name,
      'imageUrl': model.imageUrl,
      'location': GeoPoint(model.latitude, model.longitude),
      'phone': model.phone,
      'address': model.address,
      'description': model.description,
      'menuCategories': model.menuCategories,
      if (model.businessHours != null)
        'businessHours': model.businessHours!.toMap(),
    });
  }
}
