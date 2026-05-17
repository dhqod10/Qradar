import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/data/datasources/remote/menu_override_remote_data_source.dart';
import 'package:qradar/data/models/menu_override_model.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/domain/repositories/menu_override_repository.dart';

/// [MenuOverrideRepository] 구현체.
///
/// - ownership 검증: brand role 은 본인 brandId 매장만 조작 가능.
/// - 핵심 필드(priceOverride / excluded) 변경 → status=pending 회귀.
/// - collectionGroup cascade delete: 마스터 메뉴 삭제 시 연관 override 일괄 삭제.
class MenuOverrideRepositoryImpl implements MenuOverrideRepository {
  final MenuOverrideRemoteDataSource _dataSource;
  final String? Function() _currentUidGetter;
  final String? Function() _currentBrandIdGetter;

  MenuOverrideRepositoryImpl(
    this._dataSource, {
    String? Function() currentUidGetter = _defaultGetter,
    String? Function() currentBrandIdGetter = _defaultGetter,
  })  : _currentUidGetter = currentUidGetter,
        _currentBrandIdGetter = currentBrandIdGetter;

  static String? _defaultGetter() => null;

  @override
  Stream<List<MenuOverrideEntity>> watchByStore(String storeId) {
    return _dataSource.streamByStore(storeId).map(
          (models) => models.map((m) => m.toEntity()).toList(growable: false),
        );
  }

  @override
  Stream<List<MenuOverrideEntity>> watchPendingForAdmin() {
    return _dataSource.streamPending().map(
          (models) => models.map((m) => m.toEntity()).toList(growable: false),
        );
  }

  @override
  Future<MenuOverrideEntity?> getByStoreAndMaster(
    String storeId,
    String masterMenuItemId,
  ) async {
    final model = await _dataSource.getByStoreAndMaster(storeId, masterMenuItemId);
    return model?.toEntity();
  }

  @override
  Future<void> upsertOverrideCore(MenuOverrideEntity override) async {
    _assertBrandOwnership(override.brandId);
    final uid = _currentUidGetter() ?? '';
    final now = DateTime.now();

    final data = <String, dynamic>{
      ...MenuOverrideModel.fromEntity(override).toFirestore(),
      'status': EntityApprovalStatus.pending.asString,
      'submittedBy': uid,
      'submittedAt': Timestamp.fromDate(now),
      'updatedBy': 'brand',
      'updatedAt': Timestamp.fromDate(now),
    };

    await _dataSource.set(
      override.storeId,
      override.masterMenuItemId,
      data,
    );
  }

  @override
  Future<void> approveOverride(
    String storeId,
    String masterMenuItemId,
    String adminUid,
  ) {
    return _dataSource.update(
      storeId,
      masterMenuItemId,
      <String, dynamic>{
        'status': EntityApprovalStatus.approved.asString,
        'approvedBy': adminUid,
        'approvedAt': FieldValue.serverTimestamp(),
        'rejectedReason': null,
        'updatedBy': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  @override
  Future<void> rejectOverride(
    String storeId,
    String masterMenuItemId,
    String adminUid,
    String reason,
  ) {
    return _dataSource.update(
      storeId,
      masterMenuItemId,
      <String, dynamic>{
        'status': EntityApprovalStatus.rejected.asString,
        'approvedBy': adminUid,
        'rejectedReason': reason,
        'updatedBy': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  @override
  Future<void> deleteOverride(String storeId, String masterMenuItemId) {
    return _dataSource.delete(storeId, masterMenuItemId);
  }

  @override
  Future<void> deleteAllForMaster(String masterMenuItemId) {
    return _dataSource.cascadeDeleteByMaster(masterMenuItemId);
  }

  @override
  Future<void> seedExclusionsForStore({
    required String storeId,
    required String brandId,
    required List<String> excludedMasterMenuItemIds,
  }) {
    final uid = _currentUidGetter() ?? '';
    return _dataSource.seedExclusionsForStore(
      storeId: storeId,
      brandId: brandId,
      excludedMasterMenuItemIds: excludedMasterMenuItemIds,
      submittedBy: uid,
    );
  }

  @override
  Future<int> countStoresUsingPriceOverride(
    String brandId,
    String masterMenuItemId,
  ) {
    return _dataSource.countStoresUsingPriceOverride(masterMenuItemId);
  }

  @override
  Future<void> updateOverrideOperationFields(MenuOverrideEntity override) async {
    _assertOwnerOfBrandStore();
    final uid = _currentUidGetter() ?? '';
    final now = DateTime.now();

    final existing = await _dataSource.getByStoreAndMaster(
      override.storeId,
      override.masterMenuItemId,
    );

    if (existing == null) {
      // W2: override 없으면 신규 생성 — status='approved', 운영 필드만 채움
      final data = <String, dynamic>{
        'storeId': override.storeId,
        'brandId': override.brandId,
        'priceOverride': null,
        'excluded': false,
        'soldOut': override.soldOut,
        'disabledOptionGroupIds': override.disabledOptionGroupIds,
        'disabledOptionItemIds': override.disabledOptionItemIds,
        'status': EntityApprovalStatus.approved.asString,
        'submittedBy': uid,
        'submittedAt': Timestamp.fromDate(now),
        'approvedBy': null,
        'approvedAt': null,
        'rejectedReason': null,
        'updatedBy': 'owner',
        'updatedAt': Timestamp.fromDate(now),
      };
      await _dataSource.set(
        override.storeId,
        override.masterMenuItemId,
        data,
      );
    } else {
      // W2: override 있으면 운영 필드만 partial update — status/핵심 필드 보존
      await _dataSource.update(
        override.storeId,
        override.masterMenuItemId,
        <String, dynamic>{
          'soldOut': override.soldOut,
          'disabledOptionGroupIds': override.disabledOptionGroupIds,
          'disabledOptionItemIds': override.disabledOptionItemIds,
          'updatedBy': 'owner',
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }
  }

  // ── 내부 검증 ──────────────────────────────────────────────────────────

  /// brand role 사용자가 본인 brandId 가 아닌 override 조작 시 차단.
  /// admin(brandId==null) 은 통과.
  void _assertBrandOwnership(String targetBrandId) {
    final myBrandId = _currentBrandIdGetter();
    if (myBrandId == null) return; // admin → 통과
    if (targetBrandId != myBrandId) {
      throw StateError(
        '다른 브랜드의 override 에 접근할 수 없습니다. '
        'target=$targetBrandId, mine=$myBrandId',
      );
    }
  }

  /// W3: 브랜드 매장 점주 ownership 검증 (sub-phase 5 신규).
  ///
  /// - role == 'admin' → 통과
  /// - role == 'owner' → 통과 (storeId 기반 검증은 Firestore 규칙에 위임)
  /// - role == 'brand' → 통과 (브랜드 자체 작업 허용)
  /// - 그 외 → StateError
  void _assertOwnerOfBrandStore() {
    final uid = _currentUidGetter();
    if (uid == null || uid.isEmpty) {
      throw StateError('로그인이 필요합니다.');
    }
    // role 검증은 currentRoleGetter 가 없으므로 uid 존재 여부로 통과.
    // Firestore 보안 규칙이 최종 권한 검증을 담당.
  }
}
