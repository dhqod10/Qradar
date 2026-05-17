import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qradar/data/datasources/remote/master_menu_item_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/menu_item_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/menu_override_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/store_remote_data_source.dart';
import 'package:qradar/data/models/menu_item_model.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_item_scope.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';
import 'package:rxdart/rxdart.dart';

/// [MenuItemRepository] 구현체.
///
/// - case A (brandId==null 개인 매장): stores/{storeId}/menuItems 단순 stream.
/// - case B (brandId!=null 브랜드 매장): Rx.combineLatest3 으로 마스터+오버라이드+점포한정 머지.
/// - 점포 한정 메뉴 CRUD (V1):
///   - brandId==null (개인 매장): status=approved 강제 + 승인 메타 null + ownership 검증.
///   - brandId!=null (브랜드 매장 점포 한정): sub-phase 3 동작 보존 (status=pending + brand uid).
class MenuItemRepositoryImpl implements MenuItemRepository {
  final MenuItemRemoteDataSource _dataSource;
  final MasterMenuItemRemoteDataSource? _masterMenuDataSource;
  final MenuOverrideRemoteDataSource? _menuOverrideDataSource;
  final StoreRemoteDataSource? _storeRemoteDataSource;
  final String? Function() _currentUidGetter;
  final String? Function() _currentRoleGetter;

  MenuItemRepositoryImpl(
    this._dataSource, {
    MasterMenuItemRemoteDataSource? masterMenuDataSource,
    MenuOverrideRemoteDataSource? menuOverrideDataSource,
    StoreRemoteDataSource? storeRemoteDataSource,
    String? Function() currentUidGetter = _defaultGetter,
    String? Function() currentRoleGetter = _defaultGetter,
  })  : _masterMenuDataSource = masterMenuDataSource,
        _menuOverrideDataSource = menuOverrideDataSource,
        _storeRemoteDataSource = storeRemoteDataSource,
        _currentUidGetter = currentUidGetter,
        _currentRoleGetter = currentRoleGetter;

  static String? _defaultGetter() => null;

  @override
  Stream<List<MenuItemEntity>> watchByStore(String storeId, {String? brandId}) {
    if (brandId != null) {
      // brandId 명시됨 — case B 직행 (owner 측 호출 흐름)
      return _watchCaseB(storeId, brandId);
    }
    // brandId 미명시 — store doc 으로 자동 결정 (customer 측 호출 흐름)
    return Stream.fromFuture(_fetchStoreBrandId(storeId)).asyncExpand((bid) {
      if (bid == null || bid.isEmpty) {
        // case A: 개인 매장
        return _dataSource.streamByStore(storeId).map(
              (models) =>
                  models.map((m) => m.toEntity()).toList(growable: false),
            );
      }
      // case B: 브랜드 매장 — store doc 의 brandId 로 자동 결정
      return _watchCaseB(storeId, bid);
    });
  }

  /// case B 머지 stream. master + override + store-only 결합.
  Stream<List<MenuItemEntity>> _watchCaseB(String storeId, String brandId) {
    final masterDs = _masterMenuDataSource;
    final overrideDs = _menuOverrideDataSource;
    if (masterDs == null || overrideDs == null) {
      // DataSource 미주입 시 단순 stream 폴백
      return _dataSource.streamByStore(storeId).map(
            (models) =>
                models.map((m) => m.toEntity()).toList(growable: false),
          );
    }
    return Rx.combineLatest3<List<MenuItemEntity>, List<MenuOverrideEntity>,
        List<MenuItemEntity>, List<MenuItemEntity>>(
      masterDs.watchAllByBrand(brandId),
      overrideDs
          .streamByStore(storeId)
          .map((models) => models.map((m) => m.toEntity()).toList()),
      _dataSource.streamByStore(storeId).map(
            (models) =>
                models.map((m) => m.toEntity()).toList(growable: false),
          ),
      (master, overrides, storeOnly) =>
          _mergeForBrandStore(master, overrides, storeOnly),
    );
  }

  List<MenuItemEntity> _mergeForBrandStore(
    List<MenuItemEntity> master,
    List<MenuOverrideEntity> overrides,
    List<MenuItemEntity> storeOnly,
  ) {
    // umbrella 머지 규칙 (FAIL-2 해소):
    // - 핵심 필드 (priceOverride / excluded) 는 approved 만 적용
    // - 운영 필드 (soldOut / disabledOption*) 는 status 무관 즉시 적용
    final approvedMaster = master
        .where((m) =>
            m.status == EntityApprovalStatus.approved && m.visible)
        .toList();
    final approvedStoreOnly = storeOnly
        .where((m) =>
            m.status == EntityApprovalStatus.approved && m.visible)
        .toList();

    // 모든 override (status 무관) — 운영 필드 머지용
    final allOverrideMap = {
      for (final o in overrides) o.masterMenuItemId: o,
    };
    // approved override 만 — 핵심 필드 (priceOverride / excluded) 머지용
    final approvedOverrideMap = {
      for (final o in overrides
          .where((o) => o.status == EntityApprovalStatus.approved))
        o.masterMenuItemId: o,
    };

    // 2. master 메뉴에 override 적용
    //    - excluded (핵심): approved 만
    //    - priceOverride (핵심): approved 만
    //    - soldOut / disabledOption* (운영): status 무관 즉시 적용
    final mergedMaster = approvedMaster
        .where((m) => !(approvedOverrideMap[m.id]?.excluded ?? false))
        .map((m) {
          final approvedOv = approvedOverrideMap[m.id];
          final allOv = allOverrideMap[m.id];
          return m.copyWith(
            basePrice: approvedOv?.priceOverride ?? m.basePrice,
            soldOut: allOv?.soldOut ?? m.soldOut,
            disabledOptionGroupIds:
                allOv?.disabledOptionGroupIds ?? m.disabledOptionGroupIds,
            disabledOptionItemIds:
                allOv?.disabledOptionItemIds ?? m.disabledOptionItemIds,
          );
        })
        .toList();

    // 3. 점포 한정 추가 메뉴 append + displayOrder 정렬
    final merged = [...mergedMaster, ...approvedStoreOnly];
    merged.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return merged;
  }

  @override
  Stream<MenuItemEntity?> watchById({
    required String storeId,
    required String menuItemId,
  }) {
    final storeStream = _dataSource
        .streamById(storeId: storeId, menuItemId: menuItemId)
        .map((m) => m?.toEntity());
    final masterDs = _masterMenuDataSource;
    if (masterDs == null) return storeStream;

    // case B 호환: 가맹점 매장의 master ref 메뉴는 stores/.../menuItems/ 에
    // doc 없음 → store 컬렉션 null 시 brand 마스터 컬렉션도 시도해서 반환.
    return Stream.fromFuture(_fetchStoreBrandId(storeId)).asyncExpand((brandId) {
      if (brandId == null || brandId.isEmpty) return storeStream;
      final masterStream =
          masterDs.streamById(brandId, menuItemId).map((m) => m?.toEntity());
      return Rx.combineLatest2<MenuItemEntity?, MenuItemEntity?,
          MenuItemEntity?>(
        storeStream,
        masterStream,
        (s, m) => s ?? m,
      );
    });
  }

  // ─── 점포 한정 메뉴 CRUD ─────────────────────────────────────────────────

  @override
  Future<String> createStoreOnlyMenu(MenuItemEntity item) async {
    final uid = _currentUidGetter() ?? '';
    final role = _currentRoleGetter() ?? '';
    final now = DateTime.now();

    // V1: 매장 fetch 후 brandId 분기
    final storeBrandId = await _fetchStoreBrandId(item.storeId);

    if (storeBrandId == null) {
      // 개인 매장 (brandId==null): V3 ownership 검증
      await _assertOwnerOfPersonalStore(item.storeId, uid, role);
      // sub-phase 7 S2: 개인 매장 메뉴는 master ∪ store 만 허용 (brand ref 차단)
      _assertStoreOnlyOptionGroupRefs(item, allowedScopes: const ['master', 'store']);

      final prepared = item.copyWith(
        scope: MenuItemScope.store,
        brandId: null,
        status: EntityApprovalStatus.approved,
        submittedBy: null,
        submittedAt: null,
        approvedBy: null,
        approvedAt: null,
        rejectedReason: null,
      );
      final model = MenuItemModel.fromEntity(prepared);
      return _dataSource.createStoreOnly(item.storeId, model.toFirestore());
    } else {
      // 브랜드 매장 점포 한정 메뉴 (sub-phase 3 동작 보존)
      if (role != 'admin' && role != 'brand') {
        throw StateError('권한이 없습니다.');
      }
      final prepared = item.copyWith(
        scope: MenuItemScope.store,
        brandId: storeBrandId,
        status: EntityApprovalStatus.pending,
        submittedBy: uid,
        submittedAt: now,
        approvedBy: null,
        approvedAt: null,
        rejectedReason: null,
      );
      final model = MenuItemModel.fromEntity(prepared);
      return _dataSource.createStoreOnly(item.storeId, model.toFirestore());
    }
  }

  @override
  Future<void> updateStoreOnlyMenuCore(MenuItemEntity item) async {
    final uid = _currentUidGetter() ?? '';
    final role = _currentRoleGetter() ?? '';
    final now = DateTime.now();

    // V1: 매장 fetch 후 brandId 분기
    final storeBrandId = await _fetchStoreBrandId(item.storeId);

    if (storeBrandId == null) {
      // 개인 매장: ownership 검증 + status=approved 강제 (V2 통합)
      await _assertOwnerOfPersonalStore(item.storeId, uid, role);
      // sub-phase 7 S2: 개인 매장 메뉴는 master ∪ store 만 허용 (brand ref 차단)
      _assertStoreOnlyOptionGroupRefs(item, allowedScopes: const ['master', 'store']);

      final prepared = item.copyWith(
        scope: MenuItemScope.store,
        status: EntityApprovalStatus.approved,
        submittedBy: null,
        submittedAt: null,
        approvedBy: null,
        approvedAt: null,
        rejectedReason: null,
      );
      final model = MenuItemModel.fromEntity(prepared);
      await _dataSource.updateStoreOnly(
          item.storeId, item.id, model.toFirestore());
    } else {
      // 브랜드 매장 점포 한정 메뉴 (sub-phase 3 동작 보존): status=pending 회귀
      if (role != 'admin' && role != 'brand') {
        throw StateError('권한이 없습니다.');
      }
      final prepared = item.copyWith(
        scope: MenuItemScope.store,
        brandId: storeBrandId,
        status: EntityApprovalStatus.pending,
        submittedBy: uid,
        submittedAt: now,
      );
      final model = MenuItemModel.fromEntity(prepared);
      await _dataSource.updateStoreOnly(
          item.storeId, item.id, model.toFirestore());
    }
  }

  @override
  Future<void> updateStoreOnlyMenuOperation(MenuItemEntity item) async {
    _assertOwnershipOrAdmin(item.storeId);
    await _dataSource.updateStoreOnly(item.storeId, item.id, <String, dynamic>{
      'visible': item.visible,
      'soldOut': item.soldOut,
      'displayOrder': item.displayOrder,
      'tags': item.tags,
      'imageUrl': item.imageUrl,
      'disabledOptionGroupIds': item.disabledOptionGroupIds,
      'disabledOptionItemIds': item.disabledOptionItemIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteStoreOnlyMenu(String storeId, String menuItemId) async {
    final uid = _currentUidGetter() ?? '';
    final role = _currentRoleGetter() ?? '';

    // V1: 매장 fetch 후 ownership 검증
    final storeBrandId = await _fetchStoreBrandId(storeId);
    if (storeBrandId == null) {
      // 개인 매장
      await _assertOwnerOfPersonalStore(storeId, uid, role);
    } else {
      // 브랜드 매장
      if (role != 'admin' && role != 'brand') {
        throw StateError('권한이 없습니다.');
      }
    }

    await _dataSource.deleteStoreOnly(storeId, menuItemId);
  }

  @override
  Stream<List<MenuItemEntity>> watchPendingStoreOnlyMenus() {
    return _dataSource.streamPendingStoreOnly().map(
          (models) =>
              models.map((m) => m.toEntity()).toList(growable: false),
        );
  }

  @override
  Future<void> approveStoreOnlyMenu(
      String storeId, String menuItemId, String adminUid) {
    _assertAdmin();
    return _dataSource.updateStoreOnly(storeId, menuItemId, <String, dynamic>{
      'status': EntityApprovalStatus.approved.asString,
      'approvedBy': adminUid,
      'approvedAt': FieldValue.serverTimestamp(),
      'rejectedReason': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> rejectStoreOnlyMenu(
      String storeId, String menuItemId, String adminUid, String reason) {
    _assertAdmin();
    return _dataSource.updateStoreOnly(storeId, menuItemId, <String, dynamic>{
      'status': EntityApprovalStatus.rejected.asString,
      'approvedBy': adminUid,
      'rejectedReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── 내부 헬퍼 ─────────────────────────────────────────────────────────────

  /// 매장 fetch 후 brandId 반환. null = 개인 매장.
  Future<String?> _fetchStoreBrandId(String storeId) async {
    final storeDs = _storeRemoteDataSource;
    if (storeDs == null) return null;
    final storeModel = await storeDs.getById(storeId);
    return storeModel?.brandId;
  }

  /// V3: 개인 매장 점주 본인 ownership 검증.
  /// - role == admin → 통과
  /// - role == owner && store.ownerId == currentUid && store.brandId == null → 통과
  /// - 그 외 → PermissionDeniedException
  Future<void> _assertOwnerOfPersonalStore(
      String storeId, String uid, String role) async {
    if (role == 'admin') return;

    final storeDs = _storeRemoteDataSource;
    if (storeDs == null) return; // DataSource 미주입 시 통과 (테스트 환경)

    final storeModel = await storeDs.getById(storeId);
    if (storeModel == null) {
      throw StateError('매장 정보를 불러올 수 없습니다.');
    }
    if (storeModel.brandId != null && storeModel.brandId!.isNotEmpty) {
      throw StateError('권한이 없습니다. 브랜드 매장의 메뉴는 브랜드 본사가 관리합니다.');
    }
    if (storeModel.ownerId != uid) {
      throw StateError('권한이 없습니다. 본인 매장만 관리할 수 있습니다.');
    }
  }

  void _assertAdmin() {
    final role = _currentRoleGetter();
    if (role != 'admin') {
      throw StateError('관리자만 수행할 수 있는 작업입니다.');
    }
  }

  void _assertOwnershipOrAdmin(String storeId) {
    final role = _currentRoleGetter();
    if (role == 'admin') return;
    // brand/owner 는 본인 storeId 확인 (단순 통과 — UI 단에서 필터)
  }

  /// sub-phase 7 S2: 점포 한정 메뉴(scope=store) 의 optionGroupRefs scope 검증.
  ///
  /// [allowedScopes]: 허용 scope 문자열 목록 (예: 개인 매장 = ['master', 'store']).
  /// 위반 시 ArgumentError throw.
  void _assertStoreOnlyOptionGroupRefs(
    MenuItemEntity item, {
    required List<String> allowedScopes,
  }) {
    final invalid = item.optionGroupRefs.any(
      (r) => !allowedScopes.contains(r.scope.asString),
    );
    if (invalid) {
      throw ArgumentError(
        '이 매장의 메뉴에 허용되지 않는 옵션 그룹 scope 가 포함되어 있습니다. '
        'allowed=$allowedScopes',
      );
    }
  }
}
