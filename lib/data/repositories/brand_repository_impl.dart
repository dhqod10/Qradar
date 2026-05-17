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

  BrandRepositoryImpl(
    this._dataSource,
    this._storeDataSource, {
    required String Function() currentUidGetter,
  }) : _currentUidGetter = currentUidGetter;

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
    final brandId = brand.id.isEmpty
        ? FirebaseFirestore.instance.collection(FirestorePaths.brands).doc().id
        : brand.id;

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

      // V2-1: brand doc 생성 + users/{uid}.brandId 갱신을 batch write 로 원자적 처리.
      // 두 동작 모두 set + merge 로 — users doc 미존재 케이스에서도 안전 (update 는
      // doc 없으면 NOT_FOUND throw).
      final batch = FirebaseFirestore.instance.batch();
      batch.set(
        FirebaseFirestore.instance
            .collection(FirestorePaths.brands)
            .doc(brandId),
        model.toFirestore(),
        SetOptions(merge: true),
      );
      batch.set(
        FirebaseFirestore.instance
            .collection(FirestorePaths.users)
            .doc(uid),
        <String, dynamic>{'brandId': brandId},
        SetOptions(merge: true),
      );
      await batch.commit();
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
}
