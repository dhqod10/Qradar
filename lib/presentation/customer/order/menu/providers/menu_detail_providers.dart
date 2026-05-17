import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/option_remote_data_source.dart';
import 'package:qradar/data/repositories/option_repository_impl.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/option_selection_type.dart';
import 'package:qradar/domain/repositories/option_repository.dart';
import 'package:qradar/domain/usecases/get_option_groups_for_menu_item_use_case.dart';
import 'package:qradar/domain/usecases/watch_menu_item_detail_use_case.dart';
import 'package:qradar/presentation/customer/order/store/providers/store_menu_providers.dart';

/// (storeId, menuItemId) 식별 키.
class MenuItemKey {
  final String storeId;
  final String menuItemId;

  const MenuItemKey({required this.storeId, required this.menuItemId});

  @override
  bool operator ==(Object other) =>
      other is MenuItemKey &&
      other.storeId == storeId &&
      other.menuItemId == menuItemId;

  @override
  int get hashCode => Object.hash(storeId, menuItemId);
}

// ── DI ───────────────────────────────────────────────────────────────────

final _optionRemoteDataSourceProvider =
    Provider<OptionRemoteDataSource>((_) => OptionRemoteDataSource());

final optionRepositoryProvider = Provider<OptionRepository>(
  (ref) => OptionRepositoryImpl(ref.watch(_optionRemoteDataSourceProvider)),
);

final watchMenuItemDetailUseCaseProvider =
    Provider<WatchMenuItemDetailUseCase>(
  (ref) => WatchMenuItemDetailUseCase(ref.watch(menuItemRepositoryProvider)),
);

final getOptionGroupsForMenuItemUseCaseProvider =
    Provider<GetOptionGroupsForMenuItemUseCase>(
  (ref) =>
      GetOptionGroupsForMenuItemUseCase(ref.watch(optionRepositoryProvider)),
);

// ── Streams / Futures ────────────────────────────────────────────────────

/// 메뉴 상세 stream. 삭제되면 null.
final menuItemDetailProvider =
    StreamProvider.family<MenuItemEntity?, MenuItemKey>(
  (ref, key) => ref.watch(watchMenuItemDetailUseCaseProvider)(
    storeId: key.storeId,
    menuItemId: key.menuItemId,
  ),
);

/// 메뉴에 적용된 옵션 그룹 fetch (점주 비활성 필터 자동 적용 — customer 화면용).
final menuItemOptionGroupsProvider =
    FutureProvider.family<List<OptionGroupEntity>, MenuItemKey>(
        (ref, key) async {
  final detail = await ref.watch(menuItemDetailProvider(key).future);
  if (detail == null) return const [];
  return ref.watch(getOptionGroupsForMenuItemUseCaseProvider)(detail);
});

/// 메뉴에 적용된 옵션 그룹 fetch — 비활성 필터 없이 전체 (점주 옵션 관리 시트용).
final menuItemAllOptionGroupsProvider =
    FutureProvider.family<List<OptionGroupEntity>, MenuItemKey>(
        (ref, key) async {
  final detail = await ref.watch(menuItemDetailProvider(key).future);
  if (detail == null) return const [];
  // 비활성 필터를 적용하지 않고 원본 그대로 반환
  return ref.watch(optionRepositoryProvider).getOptionGroupsForMenuItem(detail);
});

// ── UI State ─────────────────────────────────────────────────────────────

/// 메뉴별 그룹별 선택된 itemId 집합.
/// `Map<groupId, Set<itemId>>`.
final menuItemSelectedOptionsProvider = NotifierProvider.family<
    MenuItemSelectedOptionsNotifier, Map<String, Set<String>>, String>(
  MenuItemSelectedOptionsNotifier.new,
);

class MenuItemSelectedOptionsNotifier
    extends Notifier<Map<String, Set<String>>> {
  MenuItemSelectedOptionsNotifier(this.menuItemId);
  final String menuItemId;

  @override
  Map<String, Set<String>> build() => const <String, Set<String>>{};

  /// 단일 선택. (라디오)
  void selectSingle(String groupId, String itemId) {
    final next = Map<String, Set<String>>.from(state);
    next[groupId] = <String>{itemId};
    state = next;
  }

  /// 단일 선택 해제 (선택 안함).
  void clearSingle(String groupId) {
    final next = Map<String, Set<String>>.from(state);
    next.remove(groupId);
    state = next;
  }

  /// 다중 선택 토글. (체크박스)
  void toggleMulti(String groupId, String itemId) {
    final next = Map<String, Set<String>>.from(state);
    final current = <String>{...?next[groupId]};
    if (current.contains(itemId)) {
      current.remove(itemId);
    } else {
      current.add(itemId);
    }
    if (current.isEmpty) {
      next.remove(groupId);
    } else {
      next[groupId] = current;
    }
    state = next;
  }

  /// 옵션 그룹 fetch 완료 시 단일/필수 그룹 첫 항목 자동 선택.
  void primeRequiredDefaults(List<OptionGroupEntity> groups) {
    final next = Map<String, Set<String>>.from(state);
    var changed = false;
    for (final g in groups) {
      if (g.selectionType != OptionSelectionType.single) continue;
      if (!g.required) continue;
      if (next.containsKey(g.id)) continue;
      if (g.items.isEmpty) continue;
      next[g.id] = <String>{g.items.first.id};
      changed = true;
    }
    if (changed) state = next;
  }
}

/// 메뉴별 수량.
final menuItemQuantityProvider =
    NotifierProvider.family<MenuItemQuantityNotifier, int, String>(
  MenuItemQuantityNotifier.new,
);

class MenuItemQuantityNotifier extends Notifier<int> {
  MenuItemQuantityNotifier(this.menuItemId);
  final String menuItemId;

  static const int min = 1;
  static const int max = 99;

  @override
  int build() => 1;

  void increment() {
    if (state >= max) return;
    state = state + 1;
  }

  void decrement() {
    if (state <= min) return;
    state = state - 1;
  }

  void set(int value) {
    if (value < min) {
      state = min;
      return;
    }
    if (value > max) {
      state = max;
      return;
    }
    state = value;
  }
}

/// 실시간 합계: (basePrice + Σ priceDelta) × quantity.
final menuItemCurrentPriceProvider =
    Provider.family<int, MenuItemKey>((ref, key) {
  final detail = ref.watch(menuItemDetailProvider(key)).value;
  if (detail == null) return 0;
  final groups = ref.watch(menuItemOptionGroupsProvider(key)).value;
  final selected = ref.watch(menuItemSelectedOptionsProvider(key.menuItemId));
  final quantity = ref.watch(menuItemQuantityProvider(key.menuItemId));

  var unit = detail.basePrice;
  if (groups != null) {
    for (final g in groups) {
      final selectedIds = selected[g.id] ?? const <String>{};
      for (final item in g.items) {
        if (selectedIds.contains(item.id)) {
          unit += item.priceDelta;
        }
      }
    }
  }
  return unit * quantity;
});

/// "담기" 버튼 활성 여부 — 모든 required 그룹이 1개 이상 선택됨.
final menuItemAddToCartReadyProvider =
    Provider.family<bool, MenuItemKey>((ref, key) {
  final groups = ref.watch(menuItemOptionGroupsProvider(key)).value;
  if (groups == null) return false;
  final selected = ref.watch(menuItemSelectedOptionsProvider(key.menuItemId));
  for (final g in groups) {
    if (!g.required) continue;
    final picked = selected[g.id];
    if (picked == null || picked.isEmpty) return false;
  }
  return true;
});

/// 미충족 필수 그룹 이름들 — 토스트 메시지용.
final menuItemMissingRequiredGroupsProvider =
    Provider.family<List<String>, MenuItemKey>((ref, key) {
  final groups = ref.watch(menuItemOptionGroupsProvider(key)).value;
  if (groups == null) return const [];
  final selected = ref.watch(menuItemSelectedOptionsProvider(key.menuItemId));
  return groups
      .where((g) {
        if (!g.required) return false;
        final picked = selected[g.id];
        return picked == null || picked.isEmpty;
      })
      .map((g) => g.name)
      .toList(growable: false);
});
