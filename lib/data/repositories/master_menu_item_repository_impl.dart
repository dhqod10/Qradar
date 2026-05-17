import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/data/datasources/remote/master_menu_item_remote_data_source.dart';
import 'package:qradar/data/models/menu_item_model.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_item_scope.dart';
import 'package:qradar/domain/repositories/master_menu_item_repository.dart';
import 'package:qradar/domain/repositories/menu_override_repository.dart';

/// [MasterMenuItemRepository] 구현체.
///
/// - ownership 검증 (S6): 본인 brandId 가 아닌 entity 조작 시 [PermissionDeniedException].
/// - optionGroupRefs scope 검증 (S2): store scope 포함 시 [ArgumentError].
/// - status 전이 (S3): create/update 시 pending 강제.
class MasterMenuItemRepositoryImpl implements MasterMenuItemRepository {
  final MasterMenuItemRemoteDataSource _dataSource;
  final MenuOverrideRepository? _menuOverrideRepository;
  final String Function() _currentUidGetter;
  final String? Function() _currentBrandIdGetter;

  MasterMenuItemRepositoryImpl(
    this._dataSource, {
    required String Function() currentUidGetter,
    required String? Function() currentBrandIdGetter,
    MenuOverrideRepository? menuOverrideRepository,
  })  : _currentUidGetter = currentUidGetter,
        _currentBrandIdGetter = currentBrandIdGetter,
        _menuOverrideRepository = menuOverrideRepository;

  @override
  Stream<List<MenuItemEntity>> watchByBrand(String brandId) {
    return _dataSource.streamByBrand(brandId).map(
          (models) =>
              models.map((m) => m.toEntity()).toList(growable: false),
        );
  }

  @override
  Stream<List<MenuItemEntity>> watchPendingForAdmin() {
    return _dataSource.streamPending().map(
          (models) =>
              models.map((m) => m.toEntity()).toList(growable: false),
        );
  }

  @override
  Future<String> createMasterMenuItem(MenuItemEntity item) async {
    _assertOwnership(item.brandId);
    _assertOptionGroupRefsScope(item);

    final uid = _currentUidGetter();
    final now = DateTime.now();

    final brandId = item.brandId ?? _currentBrandIdGetter() ?? '';
    final updated = item.copyWith(
      scope: MenuItemScope.brand,
      brandId: brandId,
      storeId: '', // 마스터 메뉴는 storeId 빈 문자열
      status: EntityApprovalStatus.pending,
      submittedBy: uid,
      submittedAt: now,
      // 신규 생성이므로 승인 메타 초기화
      approvedBy: null,
      approvedAt: null,
      rejectedReason: null,
    );

    final model = MenuItemModel.fromEntity(updated);
    return _dataSource.create(brandId, model.toFirestore());
  }

  // ─── 결정 J: 핵심/운영 필드 분리 ────────────────────────────────────────

  @override
  Future<void> updateMasterMenuItemCore(MenuItemEntity item) async {
    _assertOwnership(item.brandId);
    _assertOptionGroupRefsScope(item);

    final uid = _currentUidGetter();
    final now = DateTime.now();
    final brandId = item.brandId ?? '';

    // S3: 핵심 필드 수정 → pending 회귀.
    // approvedBy/At 는 보존 (수정 대기 라벨 구분용).
    final updated = item.copyWith(
      status: EntityApprovalStatus.pending,
      submittedBy: uid,
      submittedAt: now,
      // approvedBy / approvedAt 는 item 에서 그대로 유지 (copyWith 기본 동작)
    );

    final model = MenuItemModel.fromEntity(updated);
    await _dataSource.update(brandId, item.id, model.toFirestore());
  }

  @override
  Future<void> updateMasterMenuItemOperation(MenuItemEntity item) async {
    _assertOwnership(item.brandId);

    final brandId = item.brandId ?? '';

    // 운영 필드만 partial update — status / 승인 메타 / submittedBy/At 변경 없음.
    await _dataSource.update(brandId, item.id, <String, dynamic>{
      'visible': item.visible,
      'tags': item.tags,
      'displayOrder': item.displayOrder,
      'imageUrl': item.imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteWithCascade(String brandId, String menuItemId) async {
    _assertOwnership(brandId);
    // S9: cascade — MenuOverrideRepository 주입 시 실제 batch delete, 미주입 시 no-op.
    if (_menuOverrideRepository != null) {
      await _menuOverrideRepository.deleteAllForMaster(menuItemId);
    } else {
      await _dataSource.cascadeDeleteOverrides(menuItemId);
    }
    await _dataSource.delete(brandId, menuItemId);
  }

  @override
  Future<MenuItemEntity> cloneAsDraft(String brandId, String sourceId) async {
    final model = await _dataSource.fetchById(brandId, sourceId);
    if (model == null) {
      throw StateError('cloneAsDraft: 원본 메뉴를 찾을 수 없습니다. id=$sourceId');
    }
    final entity = model.toEntity();
    // copyWith: id='', name='{원본} 복사', 승인 메타 reset
    return entity.copyWith(
      id: '',
      name: '${entity.name} 복사',
      status: null,
      submittedBy: null,
      submittedAt: null,
      approvedBy: null,
      approvedAt: null,
      rejectedReason: null,
      createdAt: null,
      updatedAt: null,
    );
  }

  @override
  Future<int> countStoresUsingPriceOverride(
      String brandId, String menuItemId) async {
    // S8: 본 sub-phase 항상 0. sub-phase 3 이후 실제 집계.
    return 0;
  }

  @override
  Future<void> approveMasterMenuItem(
      String brandId, String menuItemId, String adminUid) {
    return _dataSource.update(brandId, menuItemId, <String, dynamic>{
      'status': EntityApprovalStatus.approved.asString,
      'approvedBy': adminUid,
      'approvedAt': FieldValue.serverTimestamp(),
      'rejectedReason': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> rejectMasterMenuItem(
      String brandId, String menuItemId, String adminUid, String reason) {
    return _dataSource.update(brandId, menuItemId, <String, dynamic>{
      'status': EntityApprovalStatus.rejected.asString,
      'approvedBy': adminUid,
      'rejectedReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> bulkApprove(
      String brandId, List<String> menuItemIds, String adminUid) {
    // admin 전용: brandId != null 인 brand/owner role 은 차단.
    _assertAdminOnly();
    return _dataSource.bulkApprove(brandId, menuItemIds, adminUid);
  }

  @override
  Future<void> bulkReject(String brandId, List<String> menuItemIds,
      String adminUid, String reason) {
    // admin 전용: brandId != null 인 brand/owner role 은 차단.
    _assertAdminOnly();
    return _dataSource.bulkReject(brandId, menuItemIds, adminUid, reason);
  }

  // ── 내부 검증 ──────────────────────────────────────────────────────────

  /// admin role 만 허용 (brandId == null 이어야 함).
  void _assertAdminOnly() {
    final myBrandId = _currentBrandIdGetter();
    if (myBrandId != null) {
      throw PermissionDeniedException(
        'admin 전용 작업입니다. brandId=$myBrandId',
      );
    }
  }

  /// 본인 brandId 가 아닌 경우 차단 (S6).
  void _assertOwnership(String? targetBrandId) {
    final myBrandId = _currentBrandIdGetter();
    if (myBrandId == null) return; // admin 은 brandId null → 통과
    if (targetBrandId != null && targetBrandId != myBrandId) {
      throw PermissionDeniedException(
        '다른 브랜드의 메뉴에 접근할 수 없습니다. '
        'target=$targetBrandId, mine=$myBrandId',
      );
    }
  }

  /// optionGroupRefs scope 검증 (S2 — sub-phase 7 갱신).
  ///
  /// 마스터/브랜드스토어온리 메뉴: master ∪ brand 허용. store 차단.
  void _assertOptionGroupRefsScope(MenuItemEntity item) {
    final hasStoreScope = item.optionGroupRefs.any(
      (r) => r.scope.asString == 'store',
    );
    if (hasStoreScope) {
      throw ArgumentError(
        '마스터 메뉴의 optionGroupRefs 는 master/brand scope 만 허용됩니다. store scope 는 불가.',
      );
    }
  }
}

/// brand role 사용자가 다른 브랜드 entity 에 접근할 때 발생.
class PermissionDeniedException implements Exception {
  final String message;
  const PermissionDeniedException(this.message);

  @override
  String toString() => 'PermissionDeniedException: $message';
}
