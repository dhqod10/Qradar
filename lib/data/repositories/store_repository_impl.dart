import 'package:qradar/core/utils/distance_calculator.dart';
import 'package:qradar/data/datasources/remote/store_remote_data_source.dart';
import 'package:qradar/data/models/store_model.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/entities/user_location.dart';
import 'package:qradar/domain/repositories/store_repository.dart';

/// [StoreRepository] 구현체.
///
/// sub-phase 2:
/// - T4: ownership / role 검증 (currentUidGetter / currentRoleGetter).
/// - T7: customer 진입점에 client side status=approved 필터 적용.
/// - T2/결정 J: 핵심/운영 필드 분리 메서드.
/// - T1: StoreModel.fromFirestore 단계에서 missing status → approved fallback.
class StoreRepositoryImpl implements StoreRepository {
  final StoreRemoteDataSource _dataSource;

  /// 현재 로그인 UID 반환 콜백 (T4 ownership 검증용).
  final String? Function() _currentUidGetter;

  /// 현재 로그인 role 반환 콜백 (T4 role 가드용).
  final String? Function() _currentRoleGetter;

  StoreRepositoryImpl(
    this._dataSource, {
    String? Function() currentUidGetter = _defaultGetter,
    String? Function() currentRoleGetter = _defaultGetter,
    // currentBrandIdGetter: sub-phase 6 에서 submitStoreForApprovalByBrand 폐기로 제거.
    // 하위 호환성 유지를 위해 named param 은 남기되 무시한다.
    String? Function() currentBrandIdGetter = _defaultGetter,
  })  : _currentUidGetter = currentUidGetter,
        _currentRoleGetter = currentRoleGetter;

  static String? _defaultGetter() => null;

  // ── customer 진입점 (T7 status=approved 필터) ────────────────────────────

  @override
  Future<List<StoreEntity>> getNearbyStores({
    required UserLocation location,
    required double radiusKm,
    int limit = 10,
  }) async {
    final models = await _dataSource.fetchAll(limit: 100);
    final approved = _filterApproved(models);
    final withDistance = _attachDistance(approved, location);
    withDistance.sort((a, b) => a.$2.compareTo(b.$2));
    return withDistance
        .where((pair) => pair.$2 <= radiusKm)
        .take(limit)
        .map((pair) => pair.$1.toEntity(distanceKm: pair.$2))
        .toList(growable: false);
  }

  @override
  Future<List<StoreEntity>> getStoresByCategories({
    required List<String> categories,
    required UserLocation location,
  }) async {
    if (categories.isEmpty) return const [];
    final models = await _dataSource.fetchAll(limit: 100);
    final approved = _filterApproved(models);
    final filtered = approved.where((m) {
      return m.menuCategories.any(categories.contains);
    }).toList(growable: false);
    final withDistance = _attachDistance(filtered, location);
    withDistance.sort((a, b) => a.$2.compareTo(b.$2));
    return withDistance
        .map((pair) => pair.$1.toEntity(distanceKm: pair.$2))
        .toList(growable: false);
  }

  // ── owner 진입점 ─────────────────────────────────────────────────────────

  @override
  Stream<StoreEntity?> watchByOwner(String ownerId) {
    return _dataSource
        .watchByOwner(ownerId)
        .map((model) => model?.toEntity());
  }

  @override
  Future<void> deleteStore(String storeId) {
    return _dataSource.delete(storeId);
  }

  // ── admin 진입점 ─────────────────────────────────────────────────────────

  @override
  Future<StoreEntity?> getById(String storeId) async {
    final model = await _dataSource.getById(storeId);
    return model?.toEntity();
  }

  @override
  Stream<List<StoreEntity>> watchAllForAdmin() {
    return _dataSource
        .streamAll()
        .map((models) => models.map((m) => m.toEntity()).toList(growable: false));
  }

  @override
  Stream<List<StoreEntity>> watchPendingStoresForAdmin() {
    return _dataSource
        .streamPending()
        .map((models) => models.map((m) => m.toEntity()).toList(growable: false));
  }

  @override
  Future<void> approveStore(String storeId, String adminUid) async {
    _assertAdmin();
    await _dataSource.updateApprovalFields(
      storeId,
      StoreModel.approveFields(adminUid),
    );
  }

  @override
  Future<void> rejectStore(
      String storeId, String adminUid, String reason) async {
    _assertAdmin();
    await _dataSource.updateApprovalFields(
      storeId,
      StoreModel.rejectFields(adminUid, reason),
    );
  }

  // ── 점주 핵심/운영 필드 분리 (결정 J) ────────────────────────────────────

  @override
  Future<void> submitStoreForApproval(StoreEntity store) async {
    if (store.id.isEmpty) {
      // 신규 등록 — sub-phase 6 (V4): 폼이 brandKey 매칭 후 brandId 채워서 보냄.
      // brandId 강제 null 하지 않음 (FAIL-1 해소).
      final uid = _currentUidGetter() ?? '';
      final model = StoreModel.fromEntity(
        store.copyWith(
          status: EntityApprovalStatus.pending,
          submittedBy: uid,
          submittedAt: DateTime.now(),
        ),
      );
      await _dataSource.create(model);
    } else {
      // 핵심 필드 수정 (updateStoreCoreFields 위임)
      await updateStoreCoreFields(store);
    }
  }

  @override
  Future<void> updateStoreCoreFields(StoreEntity store) async {
    _assertOwnership(store.ownerId);
    final uid = _currentUidGetter() ?? '';
    // T3: rejected 상태에서 수정 → 재제출 (approvedBy/At/rejectedReason 클리어)
    final isResubmit = store.status == EntityApprovalStatus.rejected;
    final model = StoreModel.fromEntity(
      store.copyWith(submittedBy: uid),
    );
    await _dataSource.updateCoreFields(
      store.id,
      model.toFirestoreForCoreUpdate(isResubmit: isResubmit),
    );
  }

  @override
  Future<void> updateStoreOperationFields(StoreEntity store) async {
    _assertOwnership(store.ownerId);
    final model = StoreModel.fromEntity(store);
    await _dataSource.updateOperationFields(
      store.id,
      model.toFirestoreForOperationUpdate(),
    );
  }

  // ── Deprecated ──────────────────────────────────────────────────────────

  @override
  @Deprecated('submitStoreForApproval 또는 updateStoreCoreFields 사용')
  Future<String> createStore(StoreEntity store) {
    return _dataSource.create(StoreModel.fromEntity(store));
  }

  @override
  @Deprecated('updateStoreCoreFields 또는 updateStoreOperationFields 사용')
  Future<void> updateStore(StoreEntity store) {
    // ignore: deprecated_member_use_from_same_package
    return _dataSource.update(StoreModel.fromEntity(store));
  }

  // ── 헬퍼 ─────────────────────────────────────────────────────────────────

  /// T7: client side status=approved 필터. legacy doc (status 누락) 은 fromFirestore 에서
  /// approved fallback 처리되므로 여기서는 단순 비교로 충분.
  List<StoreModel> _filterApproved(List<StoreModel> models) {
    return models
        .where((m) => m.status == EntityApprovalStatus.approved)
        .toList(growable: false);
  }

  List<(StoreModel, double)> _attachDistance(
    List<StoreModel> models,
    UserLocation origin,
  ) {
    return models
        .map((m) => (
              m,
              DistanceCalculator.calculateKm(
                lat1: origin.latitude,
                lon1: origin.longitude,
                lat2: m.latitude,
                lon2: m.longitude,
              ),
            ))
        .toList();
  }

  /// T4: ownership 검증. admin 은 통과. 본인 매장 아니면 예외.
  void _assertOwnership(String ownerId) {
    final role = _currentRoleGetter();
    if (role == 'admin') return;
    final uid = _currentUidGetter();
    if (uid == null || uid.isEmpty || uid != ownerId) {
      throw StateError('권한이 없습니다. 본인 매장만 수정할 수 있어요.');
    }
  }

  /// T4: admin role 가드.
  void _assertAdmin() {
    final role = _currentRoleGetter();
    if (role != 'admin') {
      throw StateError('관리자만 수행할 수 있는 작업입니다.');
    }
  }
}
