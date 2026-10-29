import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/core/constants/firestore_paths.dart';
import 'package:qradar/core/errors/brand_private_profile_save_exception.dart';
import 'package:qradar/data/datasources/remote/authority_callables_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/brand_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/store_remote_data_source.dart';
import 'package:qradar/data/models/brand_model.dart';
import 'package:qradar/data/models/brand_private_profile_model.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/brand_key_lookup.dart';
import 'package:qradar/domain/entities/brand_private_profile_entity.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/repositories/brand_repository.dart';

/// [BrandRepository] 구현체.
///
/// - `upsertBrand`: status=pending, submittedBy/At 자동 세팅. PII 는 `private/profile` 로 분리 저장.
/// - `approveBrand` / `rejectBrand`: admin uid 전달받아 메타 갱신.
/// - ownership 검증: UI 단 본인 brandId 만 노출 + 방어선.
class BrandRepositoryImpl implements BrandRepository {
  final BrandRemoteDataSource _dataSource;
  final StoreRemoteDataSource _storeDataSource;
  final AuthorityCallablesRemoteDataSource _callables;
  final String Function() _currentUidGetter;
  final String Function() _newBrandId;

  /// [newBrandIdGenerator] 는 테스트용 이음새 — 기본은 Firestore 자동 ID.
  BrandRepositoryImpl(
    this._dataSource,
    this._storeDataSource,
    this._callables, {
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
  Stream<BrandPrivateProfileEntity?> watchPrivateProfile(String brandId) {
    return _dataSource
        .streamPrivateProfile(brandId)
        .map((m) => m?.toEntity());
  }

  @override
  Future<BrandPrivateProfileEntity?> fetchPrivateProfile(
    String brandId,
  ) async {
    final model = await _dataSource.fetchPrivateProfile(brandId);
    return model?.toEntity();
  }

  /// PII 5개만 `private/profile` 에 merge-set 한다 (brandKey 는 모델이 쓰지 않는다).
  Future<void> _writePrivate(
    String brandId,
    BrandPrivateProfileEntity? profile,
  ) async {
    if (profile == null) return;
    await _dataSource.setPrivateProfile(
      brandId,
      BrandPrivateProfileModel.fromEntity(profile).toFirestore(),
    );
  }

  @override
  Future<String> upsertBrand(
    BrandEntity brand, {
    BrandPrivateProfileEntity? privateProfile,
  }) async {
    final uid = _currentUidGetter();
    final now = DateTime.now();

    // id 가 비어있으면 신규 등록 → Firestore 자동 ID 생성
    final brandId = brand.id.isEmpty ? _newBrandId() : brand.id;

    final isNew = brand.id.isEmpty;

    if (isNew) {
      // 신규 등록: 항상 status=pending 강제 (brandKey 는 승인 시 서버가 발급 — V1).
      final updated = brand.copyWith(
        id: brandId,
        status: EntityApprovalStatus.pending,
        submittedBy: uid,
        submittedAt: now,
        updatedAt: now,
      );
      final model = BrandModel.fromEntity(updated);

      // brand_authorization_hardening D1: `users/{uid}.brandId` 는 권한 값이라 클라이언트가 쓰지 않는다.
      // 1) 브랜드 문서 1건 2) 서버(claimSubmittedBrand)가 submittedBy == uid 를 검증하고 연결 3) private/profile.
      await _dataSource.set(brandId, model.toFirestore());
      try {
        await _dataSource.claimSubmittedBrand(brandId);
      } catch (e) {
        // 브랜드 문서는 이미 생겼다 — 여기서 실패로 되돌리면 사용자가 같은 브랜드를 다시 등록해 고아가 쌓인다.
        // 연결은 BrandScaffold 의 게이트(BrandIdMissingView)가 `brands where submittedBy == uid` 조회로 복구한다.
        developer.log('claimSubmittedBrand 실패 — 게이트가 복구한다', error: e);
      }
      // claim 이 실패해도 private 쓰기는 진행한다 (Rules 가 submitter 를 허용).
      // 이 쓰기가 실패하면 부모는 이미 있으므로 brandId 를 실어 던진다 — 폼이 같은 id 로 재시도해 중복 등록을 막는다.
      try {
        await _writePrivate(brandId, privateProfile);
      } catch (_) {
        throw BrandPrivateProfileSaveException(brandId);
      }
      return brandId;
    }

    // 기존 수정: 결정 J — 변경 필드 분석 (안 a, logoUrl 운영 필드 1개)
    // 기존 문서를 가져와 name/description 변경 여부 확인.
    // PII(private/profile) 변경은 이 판정에 들어가지 않는다 — PII 만 바뀌면 status 는 회귀하지 않는다.
    final existing = await _dataSource.fetchById(brandId);
    final existingEntity = existing?.toEntity();

    final coreChanged = existingEntity == null ||
        existingEntity.name != brand.name ||
        existingEntity.description != brand.description;

    if (coreChanged) {
      // 핵심 필드 변경 → status=pending 회귀 + submittedBy/At 갱신.
      // 부분 update: 화이트리스트 필드만 보낸다. createdAt / approvedBy / approvedAt / brandKey / rejectedReason 은
      // 보내지 않으므로 Firestore 에 그대로 보존되고, Rules(isBrandSelfUpdate) diff 금지 키에 걸리지 않는다.
      await _dataSource.update(brandId, <String, dynamic>{
        'name': brand.name,
        'logoUrl': brand.logoUrl,
        // 기존 set 동작과 동일: description 이 null 이면 필드 제거.
        'description': brand.description ?? FieldValue.delete(),
        'companyName': brand.companyName,
        'status': EntityApprovalStatus.pending.asString,
        'submittedBy': uid,
        'submittedAt': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // logoUrl 만 변경 → status / 승인 메타 / submittedBy/At 변경 없음
      await _dataSource.update(brandId, <String, dynamic>{
        'logoUrl': brand.logoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await _writePrivate(brandId, privateProfile);

    return brandId;
  }

  @override
  Future<void> approveBrand(String brandId, String adminUid) async {
    // 서버가 키를 발급(멱등)한 **뒤에만** 상태를 승인으로 바꾼다. 발급이 던지면 여기서 끝난다 — 문서 불변.
    // brandKey 필드는 쓰지 않는다 (private/profile 은 CF 전담).
    await _callables.issueBrandKey(brandId);
    return _dataSource.update(brandId, <String, dynamic>{
      'status': EntityApprovalStatus.approved.asString,
      'approvedBy': adminUid,
      'approvedAt': FieldValue.serverTimestamp(),
      'rejectedReason': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<BrandKeyLookup> lookupBrandByKey(String brandKey) =>
      _callables.lookupBrandByKey(brandKey);

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
