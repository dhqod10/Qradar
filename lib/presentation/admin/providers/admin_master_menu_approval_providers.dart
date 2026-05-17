import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/usecases/approve_master_menu_item_use_case.dart';
import 'package:qradar/domain/usecases/bulk_approve_master_menu_items_use_case.dart';
import 'package:qradar/domain/usecases/bulk_reject_master_menu_items_use_case.dart';
import 'package:qradar/domain/usecases/reject_master_menu_item_use_case.dart';
import 'package:qradar/domain/usecases/watch_pending_master_menu_items_use_case.dart';
import 'package:qradar/presentation/admin/providers/admin_di_providers.dart';

// ── UseCase Provider ───────────────────────────────────────────────────────

final watchPendingMasterMenuItemsUseCaseProvider =
    Provider<WatchPendingMasterMenuItemsUseCase>((ref) {
  return WatchPendingMasterMenuItemsUseCase(
      ref.watch(adminMasterMenuItemRepositoryProvider));
});

final adminApproveMasterMenuItemUseCaseProvider =
    Provider<ApproveMasterMenuItemUseCase>((ref) {
  return ApproveMasterMenuItemUseCase(
      ref.watch(adminMasterMenuItemRepositoryProvider));
});

final adminRejectMasterMenuItemUseCaseProvider =
    Provider<RejectMasterMenuItemUseCase>((ref) {
  return RejectMasterMenuItemUseCase(
      ref.watch(adminMasterMenuItemRepositoryProvider));
});

final bulkApproveMasterMenuItemsUseCaseProvider =
    Provider<BulkApproveMasterMenuItemsUseCase>((ref) {
  return BulkApproveMasterMenuItemsUseCase(
      ref.watch(adminMasterMenuItemRepositoryProvider));
});

final bulkRejectMasterMenuItemsUseCaseProvider =
    Provider<BulkRejectMasterMenuItemsUseCase>((ref) {
  return BulkRejectMasterMenuItemsUseCase(
      ref.watch(adminMasterMenuItemRepositoryProvider));
});

// ── Stream Provider ────────────────────────────────────────────────────────

/// admin 승인 큐: 마스터 메뉴 pending 목록 (collectionGroup query).
final pendingMasterMenuItemsProvider =
    StreamProvider<List<MenuItemEntity>>((ref) {
  return ref.read(watchPendingMasterMenuItemsUseCaseProvider).call();
});

/// 브랜드별 grouping: `Map<brandId, List<MenuItemEntity>>`
final pendingMasterMenuItemsByBrandProvider =
    Provider<AsyncValue<Map<String, List<MenuItemEntity>>>>((ref) {
  final allAsync = ref.watch(pendingMasterMenuItemsProvider);
  return allAsync.whenData((items) {
    final map = <String, List<MenuItemEntity>>{};
    for (final item in items) {
      final brandId = item.brandId ?? '';
      if (brandId.isEmpty) continue;
      map.putIfAbsent(brandId, () => []).add(item);
    }
    return map;
  });
});

/// 특정 brandId 의 pending 메뉴 목록 (Step 2 화면용).
final pendingMasterMenuItemsByBrandIdProvider =
    Provider.family<AsyncValue<List<MenuItemEntity>>, String>((ref, brandId) {
  final allAsync = ref.watch(pendingMasterMenuItemsProvider);
  return allAsync.whenData(
    (items) => items.where((i) => i.brandId == brandId).toList(growable: false),
  );
});
