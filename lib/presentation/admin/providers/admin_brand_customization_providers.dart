import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/domain/usecases/approve_store_only_menu_use_case.dart';
import 'package:qradar/domain/usecases/reject_store_only_menu_use_case.dart';
import 'package:qradar/domain/usecases/watch_pending_store_only_menus_use_case.dart';
import 'package:qradar/presentation/admin/providers/menu_override_providers.dart';
import 'package:qradar/presentation/brand/providers/brand_store_management_providers.dart';

// ── UseCase Provider ───────────────────────────────────────────────────────

final adminWatchPendingStoreOnlyMenusUseCaseProvider =
    Provider<WatchPendingStoreOnlyMenusUseCase>((ref) {
  return WatchPendingStoreOnlyMenusUseCase(
      ref.watch(brandMenuItemRepositoryProvider));
});

final adminApproveStoreOnlyMenuUseCaseProvider =
    Provider<ApproveStoreOnlyMenuUseCase>((ref) {
  return ApproveStoreOnlyMenuUseCase(
      ref.watch(brandMenuItemRepositoryProvider));
});

final adminRejectStoreOnlyMenuUseCaseProvider =
    Provider<RejectStoreOnlyMenuUseCase>((ref) {
  return RejectStoreOnlyMenuUseCase(
      ref.watch(brandMenuItemRepositoryProvider));
});

// ── Stream Provider ────────────────────────────────────────────────────────

/// admin 승인 큐: 가격 오버라이드 pending 목록 (collectionGroup query).
final pendingMenuOverridesProvider =
    StreamProvider<List<MenuOverrideEntity>>((ref) {
  return ref.read(watchPendingMenuOverridesUseCaseProvider).call();
});

/// admin 승인 큐: 점포 한정 메뉴 pending 목록 (collectionGroup query).
final pendingBrandStoreItemsProvider =
    StreamProvider<List<MenuItemEntity>>((ref) {
  return ref
      .read(adminWatchPendingStoreOnlyMenusUseCaseProvider)
      .call();
});

/// admin 직접 관리: 특정 매장의 가격 오버라이드 리스트 (storeId 기반).
final watchOverridesByStoreForAdminProvider =
    StreamProvider.family<List<MenuOverrideEntity>, String>((ref, storeId) {
  return ref
      .read(watchMenuOverridesByStoreUseCaseProvider)
      .call(storeId);
});

/// admin 직접 관리: 특정 매장의 점포 한정 메뉴 리스트 (storeId 기반).
final watchStoreOnlyMenusForAdminProvider =
    StreamProvider.family<List<MenuItemEntity>, String>((ref, storeId) {
  return ref.read(brandMenuItemRepositoryProvider).watchByStore(storeId);
});
