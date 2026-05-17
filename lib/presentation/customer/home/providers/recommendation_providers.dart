import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/order_log_remote_data_source.dart';
import 'package:qradar/data/repositories/order_log_repository_impl.dart';
import 'package:qradar/domain/entities/frequent_menu_item_entity.dart';
import 'package:qradar/domain/entities/frequent_store_entity.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/order_log_entity.dart';
import 'package:qradar/domain/entities/quick_reorder_candidate_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/repositories/order_log_repository.dart';
import 'package:qradar/domain/usecases/get_frequent_menu_items_use_case.dart';
import 'package:qradar/domain/usecases/get_frequent_stores_use_case.dart';
import 'package:qradar/domain/usecases/get_quick_reorder_candidates_use_case.dart';
import 'package:qradar/domain/usecases/write_order_log_use_case.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/home/providers/home_providers.dart';
import 'package:qradar/presentation/customer/order/favorites/providers/favorites_providers.dart';
import 'package:qradar/presentation/customer/order/store/providers/store_menu_providers.dart';

// ── DI ────────────────────────────────────────────────────────────────────────

final orderLogRemoteDataSourceProvider = Provider<OrderLogRemoteDataSource>(
  (_) => OrderLogRemoteDataSource(),
);

final orderLogRepositoryProvider = Provider<OrderLogRepository>((ref) {
  final ds = ref.watch(orderLogRemoteDataSourceProvider);
  String? currentUid() => ref.read(authProvider).asData?.value?.uid;
  return OrderLogRepositoryImpl(ds, currentUid);
});

// ── UseCase Provider ──────────────────────────────────────────────────────────

final getFrequentStoresUseCaseProvider =
    Provider<GetFrequentStoresUseCase>((ref) {
  String? currentUid() => ref.read(authProvider).asData?.value?.uid;
  return GetFrequentStoresUseCase(
    ref.watch(orderLogRepositoryProvider),
    currentUid,
  );
});

final getFrequentMenuItemsUseCaseProvider =
    Provider<GetFrequentMenuItemsUseCase>((ref) {
  String? currentUid() => ref.read(authProvider).asData?.value?.uid;
  return GetFrequentMenuItemsUseCase(
    ref.watch(orderLogRepositoryProvider),
    currentUid,
  );
});

final getQuickReorderCandidatesUseCaseProvider =
    Provider<GetQuickReorderCandidatesUseCase>((ref) {
  String? currentUid() => ref.read(authProvider).asData?.value?.uid;
  return GetQuickReorderCandidatesUseCase(
    ref.watch(orderLogRepositoryProvider),
    currentUid,
  );
});

final writeOrderLogUseCaseProvider = Provider<WriteOrderLogUseCase>((ref) {
  return WriteOrderLogUseCase(ref.watch(orderLogRepositoryProvider));
});

// ── State (Stream) ────────────────────────────────────────────────────────────

/// 사용자 OrderLog raw stream. 비로그인 → `[]`.
final _rawOrderLogsProvider = StreamProvider<List<OrderLogEntity>>((ref) {
  final user = ref.watch(authProvider).asData?.value;
  if (user == null) {
    return Stream<List<OrderLogEntity>>.value(const <OrderLogEntity>[]);
  }
  return ref.watch(orderLogRepositoryProvider).watchUserLogs(user.uid);
});

/// 다시 주문하기 candidate stream. UseCase 가 직접 가공.
final quickReorderCandidatesProvider =
    StreamProvider<List<QuickReorderCandidateEntity>>((ref) {
  // authProvider 변경 시 자연 재구성을 위해 watch.
  ref.watch(authProvider);
  return ref.watch(getQuickReorderCandidatesUseCaseProvider).call();
});

/// 매장 id → StoreEntity lookup. nearbyStoresProvider 결과 기반.
/// FrequentMenuCard 의 매장 진입에서도 사용.
final storesByIdProvider = Provider<Map<String, StoreEntity>>((ref) {
  final stores = ref.watch(nearbyStoresProvider).asData?.value ??
      const <StoreEntity>[];
  return {for (final s in stores) s.id: s};
});

/// 자주 찾는 매장 stream — logs + favoriteStoreIds + storesById 합성.
final frequentStoresProvider =
    Provider<AsyncValue<List<FrequentStoreEntity>>>((ref) {
  final logsAsync = ref.watch(_rawOrderLogsProvider);
  final favoriteIds =
      ref.watch(favoriteStoreIdsProvider).asData?.value ?? const <String>{};
  final storesById = ref.watch(storesByIdProvider);

  return logsAsync.whenData((logs) {
    return GetFrequentStoresUseCase.compute(
      logs: logs,
      favoriteStoreIds: favoriteIds,
      storesById: storesById,
    );
  });
});

/// OrderLog 안에서 등장하는 unique storeId 집합.
/// frequentMenuItemsProvider 가 이 집합을 통해 각 매장의 menus stream 을 구독.
final _orderedStoreIdsProvider = Provider<Set<String>>((ref) {
  final logs =
      ref.watch(_rawOrderLogsProvider).asData?.value ?? const <OrderLogEntity>[];
  return logs.map((l) => l.storeId).toSet();
});

/// 매장 id → menuItems lookup. orderLog 에 등장한 매장만 동적으로 watch.
/// 메뉴 stream 이 아직 emit 전이면 해당 매장은 skip (imageUrl/basePrice 미보강).
final _menuItemsByStoreProvider =
    Provider<Map<String, List<MenuItemEntity>>>((ref) {
  final storeIds = ref.watch(_orderedStoreIdsProvider);
  final result = <String, List<MenuItemEntity>>{};
  for (final id in storeIds) {
    final async = ref.watch(storeMenuItemsProvider(id));
    final items = async.asData?.value;
    if (items != null) result[id] = items;
  }
  return result;
});

/// 자주 찾는 메뉴 stream — logs + favoriteMenuItemKeys + menuItemsByStore 합성.
final frequentMenuItemsProvider =
    Provider<AsyncValue<List<FrequentMenuItemEntity>>>((ref) {
  final logsAsync = ref.watch(_rawOrderLogsProvider);
  final favoriteKeys =
      ref.watch(favoriteMenuItemKeysProvider).asData?.value ?? const <String>{};
  final menuItemsByStore = ref.watch(_menuItemsByStoreProvider);

  return logsAsync.whenData((logs) {
    return GetFrequentMenuItemsUseCase.compute(
      logs: logs,
      favoriteMenuItemKeys: favoriteKeys,
      menuItemsByStore: menuItemsByStore,
    );
  });
});
