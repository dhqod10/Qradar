import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/data/models/brand_model.dart';
import 'package:qradar/data/models/store_model.dart';

/// Firestore `brands/{brandId}` 원격 데이터소스.
class BrandRemoteDataSource {
  final FirebaseFirestore _db;

  BrandRemoteDataSource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.brands);

  /// 모든 브랜드 스트림 (admin).
  Stream<List<BrandModel>> streamAll() {
    return _col.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs
              .map((doc) => BrandModel.fromFirestore(doc))
              .toList(growable: false),
        );
  }

  /// status == pending 인 브랜드 스트림 (admin 승인 큐).
  Stream<List<BrandModel>> streamPending() {
    return _col
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => BrandModel.fromFirestore(doc))
              .toList(growable: false),
        );
  }

  /// 특정 brandId 의 브랜드 스트림.
  Stream<BrandModel?> streamById(String brandId) {
    return _col.doc(brandId).snapshots().map(
          (doc) => doc.exists ? BrandModel.fromFirestore(doc) : null,
        );
  }

  /// 특정 brandId 의 브랜드 문서 단발성 조회.
  ///
  /// 결정 J — [BrandRepositoryImpl.upsertBrand] 가 변경 필드 분석 시 사용.
  Future<BrandModel?> fetchById(String brandId) async {
    final doc = await _col.doc(brandId).get();
    return doc.exists ? BrandModel.fromFirestore(doc) : null;
  }

  /// 브랜드 문서 set (upsert).
  Future<void> set(String brandId, Map<String, dynamic> data) {
    return _col.doc(brandId).set(data, SetOptions(merge: true));
  }

  /// 브랜드 문서 부분 update.
  Future<void> update(String brandId, Map<String, dynamic> partial) {
    return _col.doc(brandId).update(partial);
  }

  /// 브랜드 문서 삭제.
  Future<void> delete(String brandId) {
    return _col.doc(brandId).delete();
  }

  // ─── sub-phase 3 보강 ────────────────────────────────────────────────────

  /// brand 가 운영하는 매장 목록 실시간 스트림 (stores 컬렉션 query).
  Stream<List<StoreModel>> streamStoresByBrand(String brandId) {
    return _db
        .collection(FirestorePaths.stores)
        .where('brandId', isEqualTo: brandId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => StoreModel.fromFirestore(doc))
              .toList(growable: false),
        );
  }

  // ─── sub-phase 6 보강 (V1, V4) ──────────────────────────────────────────

  /// brandKey 로 승인된 brand 단건 조회 (V4).
  ///
  /// `where('brandKey','==',key).where('status','==','approved').limit(1)` query.
  /// 미매칭 시 null 반환.
  Future<BrandModel?> findByBrandKey(String key) async {
    final snap = await _col
        .where('brandKey', isEqualTo: key)
        .where('status', isEqualTo: 'approved')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return BrandModel.fromFirestore(snap.docs.first);
  }

  /// brandKey 중복 여부 확인 (V1 unique 검증용).
  ///
  /// `where('brandKey','==',key).limit(1)` — status 무관하게 동일 key 존재 시 true.
  Future<bool> isBrandKeyTaken(String key) async {
    final snap = await _col
        .where('brandKey', isEqualTo: key)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }
}
