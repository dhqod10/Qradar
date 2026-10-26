import 'dart:developer' as developer;

import 'package:qradar/core/utils/search_normalizer.dart';
import 'package:qradar/core/utils/store_menu_visibility.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_search_hit_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/repositories/master_menu_item_repository.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';

/// 홈 검색 — 메뉴 검색 (Lazy Menu Index 1단계 + override 검증 2단계, spec §2.2 / §15).
///
/// **1단계 `buildIndex`** — 후보 매장의 출처 단위로 1회 `get()`:
/// - distinct `brandId` -> `brands/{id}/menuItems` (브랜드당 1회)
/// - 매장 자체 `stores/{id}/menuItems` (개인 매장 + 브랜드 매장의 점포 한정 메뉴, 매장당 1회 — D10)
/// 쿼리는 기존 stream 과 같은 문장(`orderBy('displayOrder')`)이라 새 인덱스가 필요 없다.
/// 1단계 값(마스터 가격·품절)은 override 가 적용되기 전이라 **화면에 쓰이지 않는다** — 2단계를 통과한 행만 그려진다.
///
/// **2단계 `planVerification` / `applyVerification`** (순수) — 일치한 브랜드 매장(거리순 상한)의 override 를
/// 읽어 `applyOverrideForCustomer` 로 제외·가격·품절을 반영한다. 읽기(I/O)는 provider 가 맡는다.
class SearchMenuItemsUseCase {
  final MenuItemRepository _menuRepository;
  final MasterMenuItemRepository _masterRepository;

  SearchMenuItemsUseCase(this._menuRepository, this._masterRepository);

  /// 출처별로 실패를 흡수한다. 일부 실패는 [MenuSearchIndex.failedSourceCount],
  /// **전부** 실패하면(출처 >= 1) 마지막 예외를 던져 호출 측이 전체 에러로 다루게 한다.
  Future<MenuSearchIndex> buildIndex({
    required List<StoreEntity> candidateStores,
  }) async {
    final brandStores = <String, List<StoreEntity>>{};
    final personalStores = <StoreEntity>[];
    for (final s in candidateStores) {
      final b = s.brandId;
      if (b == null || b.isEmpty) {
        personalStores.add(s);
      } else {
        (brandStores[b] ??= <StoreEntity>[]).add(s);
      }
    }

    Object? lastError;
    StackTrace? lastStack;
    var failed = 0;
    final hits = <MenuSearchHitEntity>[];

    Future<void> brandSource(String brandId, List<StoreEntity> stores) async {
      try {
        final items = await _masterRepository.fetchBrandMasterMenusOnce(
          brandId,
        );
        for (final item in items) {
          if (!item.visible || item.status != EntityApprovalStatus.approved) {
            continue;
          }
          for (final store in stores) {
            hits.add(_hit(item, store, MenuHitSource.brandMaster));
          }
        }
      } catch (e, st) {
        failed++;
        lastError = e;
        lastStack = st;
        developer.log('메뉴 인덱스 브랜드 출처 실패 brands/$brandId/menuItems: $e');
      }
    }

    // 매장 자체 메뉴(`stores/{id}/menuItems`): 개인 매장 + 브랜드 매장의 점포 한정 메뉴 (D10).
    // 개인 매장 메뉴는 status 가 null 일 수 있고(승인 불필요), 브랜드 매장의 점포 한정 메뉴는
    // 승인된 것만 매장 화면에 보인다 (`_mergeForBrandStore` 의 approvedStoreOnly 와 같은 기준).
    Future<void> storeOwnSource(
      StoreEntity store, {
      required bool brandStore,
    }) async {
      try {
        final items = await _menuRepository.fetchStoreMenusOnce(store.id);
        for (final item in items) {
          final okStatus = brandStore
              ? item.status == EntityApprovalStatus.approved
              : (item.status == null ||
                    item.status == EntityApprovalStatus.approved);
          if (!item.visible || !okStatus) continue;
          hits.add(_hit(item, store, MenuHitSource.storeOwn));
        }
      } catch (e, st) {
        failed++;
        lastError = e;
        lastStack = st;
        developer.log('메뉴 인덱스 매장 출처 실패 stores/${store.id}/menuItems: $e');
      }
    }

    final tasks = <Future<void>>[
      for (final e in brandStores.entries) brandSource(e.key, e.value),
      for (final s in personalStores) storeOwnSource(s, brandStore: false),
      for (final list in brandStores.values)
        for (final s in list) storeOwnSource(s, brandStore: true),
    ];
    await Future.wait(tasks); // 각 task 가 자체적으로 예외를 흡수하므로 Future.wait 가 죽지 않는다.

    if (tasks.isNotEmpty && failed == tasks.length) {
      Error.throwWithStackTrace(lastError!, lastStack ?? StackTrace.current);
    }

    // 거리 오름차순 -> 같으면 메뉴명 가나다. (storeId, menuItemId) 중복 제거.
    final seen = <String>{};
    final unique = <MenuSearchHitEntity>[];
    for (final h in hits) {
      if (seen.add('${h.storeId}|${h.menuItemId}')) unique.add(h);
    }
    unique.sort((a, b) {
      final da = a.distanceKm ?? double.infinity;
      final db = b.distanceKm ?? double.infinity;
      final c = da.compareTo(db);
      return c != 0 ? c : a.menuName.compareTo(b.menuName);
    });
    return MenuSearchIndex(
      hits: List.unmodifiable(unique),
      failedSourceCount: failed,
      searchedStoreCount: candidateStores.length,
    );
  }

  /// 순수 compute — 인덱스(이미 정렬됨)에서 일치하는 **전체** 행을 순서 보존해 반환한다.
  /// 표시 상한(`menuSearchResultLimit`)은 총 일치 수를 알아야 하므로 호출 측(provider)이 자른다.
  static List<MenuSearchHitEntity> filter({
    required List<MenuSearchHitEntity> index,
    required String normalizedQuery,
  }) {
    if (normalizedQuery.isEmpty) return const [];
    return index
        .where((h) => SearchNormalizer.matches(h.menuName, normalizedQuery))
        .toList(growable: false);
  }

  static MenuSearchHitEntity _hit(
    MenuItemEntity item,
    StoreEntity store,
    MenuHitSource source,
  ) {
    return MenuSearchHitEntity(
      menuItemId: item.id,
      menuName: item.name,
      menuImageUrl: item.imageUrl,
      mainCategoryCode: item.mainCategoryCode,
      storeId: store.id,
      storeName: store.name,
      distanceKm: store.distanceKm,
      source: source,
      basePrice: item.basePrice,
      soldOut: item.soldOut,
    );
  }

  // ── 2단계: override 검증 (spec §15.1 / §15.4) ─────────────────────────────

  /// 일치한 행에서 override 를 읽을 브랜드 매장을 고른다 (순수).
  /// 행은 이미 거리 오름차순이므로 등장 순서가 곧 가까운 순이다. 상한 밖 매장의 행은 [applyVerification] 이 버린다.
  /// 개인 매장·점포 한정 메뉴 행은 override 가 존재하지 않으므로 대상이 아니다.
  static MenuVerifyPlan planVerification(
    List<MenuSearchHitEntity> matched, {
    required int storeLimit,
  }) {
    final stores = <String>[];
    var truncated = false;
    for (final h in matched) {
      if (h.source != MenuHitSource.brandMaster) continue;
      if (stores.contains(h.storeId)) continue;
      if (stores.length < storeLimit) {
        stores.add(h.storeId);
      } else {
        truncated = true;
      }
    }
    return MenuVerifyPlan(storeIds: stores, truncated: truncated);
  }

  /// override 를 적용해 검증된 행만 남긴다 (순수). 규칙은 [applyOverrideForCustomer] 한 곳 —
  /// 여기서 excluded/priceOverride/soldOut 을 따로 판정하지 않는다.
  /// - 브랜드 마스터 행: 계획 밖 매장 -> 버림(+truncated) / 검증 실패 매장 -> 버림(R6) / excluded -> 버림 / 그 외 가격·품절 반영
  /// - 그 외 행(개인·점포 한정): 그대로 통과
  static VerifiedMenuHits applyVerification({
    required List<MenuSearchHitEntity> matched,
    required MenuVerifyPlan plan,
    required Map<String, List<MenuOverrideEntity>> overridesByStore,
    required Set<String> failedStores,
  }) {
    final planned = plan.storeIds.toSet();
    final maps = <String, Map<String, MenuOverrideEntity>>{
      for (final e in overridesByStore.entries)
        e.key: {for (final o in e.value) o.masterMenuItemId: o},
    };
    final out = <MenuSearchHitEntity>[];
    for (final h in matched) {
      if (h.source != MenuHitSource.brandMaster) {
        out.add(h);
        continue;
      }
      if (!planned.contains(h.storeId)) continue; // 상한 밖 (truncated 로 알린다)
      if (failedStores.contains(h.storeId)) continue; // 검증 못 한 행은 그리지 않는다
      final master = MenuItemEntity(
        id: h.menuItemId,
        storeId: h.storeId,
        name: h.menuName,
        mainCategoryCode: h.mainCategoryCode,
        basePrice: h.basePrice,
        soldOut: h.soldOut,
      );
      final applied = applyOverrideForCustomer(
        master: master,
        override: maps[h.storeId]?[h.menuItemId],
      );
      if (applied == null) continue; // 이 매장은 팔지 않는다 (excluded)
      out.add(h.copyWith(basePrice: applied.basePrice, soldOut: applied.soldOut));
    }
    return VerifiedMenuHits(
      hits: out,
      failedStoreCount: failedStores.length,
      truncated: plan.truncated,
    );
  }
}
