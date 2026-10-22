import 'dart:developer' as developer;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/core/errors/brand_key_collision_exception.dart';
import 'package:qradar/data/datasources/remote/brand_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/store_remote_data_source.dart';
import 'package:qradar/data/models/brand_model.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/repositories/brand_repository.dart';

/// [BrandRepository] 구현체.
///
/// - `upsertBrand`: status=pending, submittedBy/At 자동 세팅.
/// - `approveBrand` / `rejectBrand`: admin uid 전달받아 메타 갱신.
/// - ownership 검증: UI 단 본인 brandId 만 노출 + 방어선.
class BrandRepositoryImpl implements BrandRepository {
  final BrandRemoteDataSource _dataSource;
  final StoreRemoteDataSource _storeDataSource;
  final String Function() _currentUidGetter;
  final String Function() _newBrandId;

  /// [newBrandIdGenerator] 는 테스트용 이음새 — 기본은 Firestore 자동 ID.
  BrandRepositoryImpl(
    this._dataSource,
    this._storeDataSource, {
    required String Function() currentUidGetter,
    String Function()? newBrandIdGenerator,
  }) : _currentUidGetter = currentUidGetter,
       _newBrandId =
           newBrandIdGenerator ??
           (() => FirebaseFirestore.instance
               .collection(FirestorePaths.brands)
               .doc()
               .id);

  @override
  Stream<List<BrandEntity>> watchAll() {
    return _dataSource.streamAll().map(
          (models) =>
              models.map((m) => m.toEntity()).toList(growable: false),
        );
  }

  @override
  Stream<List<BrandEntity>> watchPendingForAdmin() {
    return _dataSource.streamPending().map(
          (models) =>
              models.map((m) => m.toEntity()).toList(growable: false),
        );
  }

  @override
  Stream<BrandEntity?> watchById(String brandId) {
    return _dataSource
        .streamById(brandId)
        .map((m) => m?.toEntity());
  }

  @override
  Future<String> upsertBrand(BrandEntity brand) async {
    final uid = _currentUidGetter();
    final now = DateTime.now();

    // id 가 비어있으면 신규 등록 → Firestore 자동 ID 생성
    final brandId = brand.id.isEmpty ? _newBrandId() : brand.id;

    final isNew = brand.id.isEmpty;

    if (isNew) {
      // 신규 등록: 항상 status=pending 강제, brandKey='' (V1 — 승인 시점 발급)
      final updated = brand.copyWith(
        id: brandId,
        status: EntityApprovalStatus.pending,
        brandKey: '',
        submittedBy: uid,
        submittedAt: now,
        updatedAt: now,
      );
      final model = BrandModel.fromEntity(updated);

      // brand_authorization_hardening D1: `users/{uid}.brandId` 는 권한 값이라 클라이언트가 쓰지 않는다.
      // (구 방식은 브랜드 문서 + users.brandId 를 한 batch 로 썼다 — Rules 가 더 이상 허용하지 않는다.)
      // 1) 브랜드 문서 1건만 쓴다. 2) 서버(claimSubmittedBrand)가 submittedBy == uid 를 검증하고 연결한다.
      await _dataSource.set(brandId, model.toFirestore());
      try {
        await _dataSource.claimSubmittedBrand(brandId);
      } catch (e) {
        // 브랜드 문서는 이미 생겼다 — 여기서 실패로 되돌리면 사용자가 같은 브랜드를 다시 등록해 고아가 쌓인다.
        // 연결은 BrandScaffold 의 게이트(BrandIdMissingView)가 `brands where submittedBy == uid` 조회로 복구한다.
        developer.log('claimSubmittedBrand 실패 — 게이트가 복구한다', error: e);
      }
      return brandId;
    }

    // 기존 수정: 결정 J — 변경 필드 분석 (안 a, logoUrl 운영 필드 1개)
    // 기존 문서를 가져와 name/description 변경 여부 확인
    final existing = await _dataSource.fetchById(brandId);
    final existingEntity = existing?.toEntity();

    final coreChanged = existingEntity == null ||
        existingEntity.name != brand.name ||
        existingEntity.description != brand.description;

    if (coreChanged) {
      // 핵심 필드 변경 → status=pending 회귀 + submittedBy/At 갱신 + approvedBy/At 보존
      // brandKey 는 보존 (V1 불변성)
      final updated = brand.copyWith(
        id: brandId,
        status: EntityApprovalStatus.pending,
        submittedBy: uid,
        submittedAt: now,
        updatedAt: now,
        // approvedBy / approvedAt 는 brand 에서 그대로 유지 (수정 대기 라벨 구분용)
      );
      final model = BrandModel.fromEntity(updated);
      await _dataSource.set(brandId, model.toFirestore());
    } else {
      // logoUrl 만 변경 → status / 승인 메타 / submittedBy/At 변경 없음
      await _dataSource.update(brandId, <String, dynamic>{
        'logoUrl': brand.logoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return brandId;
  }

  @override
  Future<void> approveBrand(String brandId, String adminUid) async {
    // V1: brandKey 자동 생성 + unique 검증 + 1-2회 재시도
    final brandKey = await _generateUniqueBrandKey();
    return _dataSource.update(brandId, <String, dynamic>{
      'status': EntityApprovalStatus.approved.asString,
      'approvedBy': adminUid,
      'approvedAt': FieldValue.serverTimestamp(),
      'brandKey': brandKey,
      'rejectedReason': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// V1: `BR-` prefix + 32 char alphabet × 8자리 random key 생성.
  ///
  /// alphabet: A-Z + 2-9 (0/O/I/1 제외) = 32 chars.
  /// 충돌 시 최대 2회 재시도. 3회 모두 충돌 시 [BrandKeyCollisionException] throw.
  Future<String> _generateUniqueBrandKey() async {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();

    for (var attempt = 0; attempt < 3; attempt++) {
      final chars = List.generate(8, (_) => alphabet[rng.nextInt(alphabet.length)]);
      final key = 'BR-${chars.join()}';
      final taken = await _dataSource.isBrandKeyTaken(key);
      if (!taken) return key;
    }
    throw BrandKeyCollisionException();
  }

  @override
  Future<BrandEntity?> findByBrandKey(String brandKey) async {
    final model = await _dataSource.findByBrandKey(brandKey);
    return model?.toEntity();
  }

  @override
  Future<void> rejectBrand(
      String brandId, String adminUid, String reason) {
    return _dataSource.update(brandId, <String, dynamic>{
      'status': EntityApprovalStatus.rejected.asString,
      'approvedBy': adminUid,
      'rejectedReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteBrand(String brandId) {
    return _dataSource.delete(brandId);
  }

  @override
  Stream<List<StoreEntity>> watchStoresByBrand(String brandId) {
    return _storeDataSource.streamByBrand(brandId).map(
          (models) => models.map((m) => m.toEntity()).toList(growable: false),
        );
  }

  @override
  Future<List<BrandEntity>> fetchMySubmittedBrands() async {
    final uid = _currentUidGetter();
    if (uid.isEmpty) return const [];
    final models = await _dataSource.fetchBySubmitter(uid);
    final list = models.map((m) => m.toEntity()).toList();
    // 가장 이른 submittedAt 이 먼저 (제출 시각이 없는 옛 문서는 뒤로). 인덱스 없이 클라이언트에서 정렬한다.
    list.sort((a, b) {
      final x = a.submittedAt;
      final y = b.submittedAt;
      if (x == null && y == null) return a.id.compareTo(b.id);
      if (x == null) return 1;
      if (y == null) return -1;
      final c = x.compareTo(y);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    return list;
  }

  @override
  Future<void> claimSubmittedBrand(String brandId) =>
      _dataSource.claimSubmittedBrand(brandId);
}
