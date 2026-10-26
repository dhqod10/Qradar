import 'dart:developer' as developer;

import 'package:qradar/core/utils/search_normalizer.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_search_hit_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/repositories/master_menu_item_repository.dart';
import 'package:qradar/domain/repositories/menu_item_repository.dart';

/// 홈 검색 — 메뉴 검색 (Lazy Menu Index, spec §2.2).
///
/// 인덱스는 후보 매장의 **출처 단위로 1회 `get()`** 해서 만든다:
/// - distinct `brandId` -> `brands/{id}/menuItems` (브랜드당 1회)
/// - `brandId == null` -> `stores/{id}/menuItems` (매장당 1회)
/// 쿼리는 기존 stream 과 같은 문장(`orderBy('displayOrder')`)이라 새 인덱스가 필요 없다.
/// 인덱스는 override 를 읽지 않으므로 **가격 필드를 만들지 않는다** (`MenuSearchHitEntity` 참조).
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

    Future<void> personalSource(StoreEntity store) async {
      try {
        final items = await _menuRepository.fetchStoreMenusOnce(store.id);
        for (final item in items) {
          // 개인 매장 메뉴는 status 가 null 일 수 있다 (승인 불필요). StoreMenuPage 와 같은 기준.
          final okStatus =
              item.status == null ||
              item.status == EntityApprovalStatus.approved;
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
      for (final s in personalStores) personalSource(s),
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
    );
  }
}
