import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/core/errors/brand_claim_exception.dart';
import 'package:qradar/data/models/brand_model.dart';
import 'package:qradar/data/models/brand_private_profile_model.dart';
import 'package:qradar/data/models/store_model.dart';

/// Firestore `brands/{brandId}` 원격 데이터소스.
class BrandRemoteDataSource {
  final FirebaseFirestore _db;
  final FirebaseFunctions? _functionsOverride;

  BrandRemoteDataSource({FirebaseFirestore? db, FirebaseFunctions? functions})
      : _db = db ?? FirebaseFirestore.instance,
        _functionsOverride = functions;

  FirebaseFunctions get _functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

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

  // ─── payment_server_authority B1 — 비공개 프로필 ──────────────────────────

  DocumentReference<Map<String, dynamic>> _privateProfile(String brandId) =>
      _col
          .doc(brandId)
          .collection(FirestorePaths.brandPrivate)
          .doc(FirestorePaths.brandPrivateProfileDoc);

  /// `brands/{id}/private/profile` 실시간 스트림. 문서가 없으면 null.
  /// **읽기 실패(권한·네트워크)는 스트림 에러로 전파한다** — 빈 값으로 폴백하면 "미발급" 과 구별되지 않는다.
  Stream<BrandPrivateProfileModel?> streamPrivateProfile(String brandId) {
    return _privateProfile(brandId).snapshots().map(
      BrandPrivateProfileModel.fromFirestore,
    );
  }

  /// 단발성 조회. 실패는 예외.
  Future<BrandPrivateProfileModel?> fetchPrivateProfile(String brandId) async {
    final doc = await _privateProfile(brandId).get();
    return BrandPrivateProfileModel.fromFirestore(doc);
  }

  /// PII 5개 merge-set. [data] 는 [BrandPrivateProfileModel.toFirestore] 의 결과여야 한다 (brandKey 금지).
  Future<void> setPrivateProfile(String brandId, Map<String, dynamic> data) {
    return _privateProfile(brandId).set(data, SetOptions(merge: true));
  }

  // ─── brand_authorization_hardening (D1) ─────────────────────────────────

  /// `brands where submittedBy == uid` (단일 필드 등식 — 인덱스 불요). **실패는 예외로 전파한다** (빈 목록과 구별).
  Future<List<BrandModel>> fetchBySubmitter(String uid) async {
    final snap = await _col.where('submittedBy', isEqualTo: uid).get();
    return snap.docs.map(BrandModel.fromFirestore).toList(growable: false);
  }

  /// `claimSubmittedBrand` callable. `users.brandId` 는 클라이언트가 쓸 수 없다 (Rules) — 서버가
  /// `brands/{id}.submittedBy == uid` 를 검증하고 값과 역할 이력을 같은 트랜잭션에 쓴다. 멱등.
  Future<void> claimSubmittedBrand(String brandId) async {
    try {
      await _functions
          .httpsCallable(
            'claimSubmittedBrand',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          )
          .call<Object?>(<String, dynamic>{'brandId': brandId});
    } on FirebaseFunctionsException catch (e) {
      final d = e.details;
      final reason = (d is Map && d['reason'] is String)
          ? d['reason'] as String
          : BrandClaimException.reasonFromMessage(e.message);
      throw BrandClaimException(
        BrandClaimException.classify(e.code, reason: reason),
        code: e.code,
      );
    } catch (_) {
      throw const BrandClaimException(BrandClaimFailure.retryable);
    }
  }
}
