import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/usecases/approve_store_use_case.dart';
import 'package:qradar/domain/usecases/reject_store_use_case.dart';
import 'package:qradar/domain/usecases/watch_all_stores_for_admin_use_case.dart';
import 'package:qradar/domain/usecases/watch_pending_stores_for_admin_use_case.dart';
import 'package:qradar/presentation/owner/providers/owner_providers.dart';

// ── UseCase Provider ───────────────────────────────────────────────────────

final adminWatchPendingStoresUseCaseProvider =
    Provider<WatchPendingStoresForAdminUseCase>((ref) {
  return WatchPendingStoresForAdminUseCase(ref.watch(storeRepositoryProvider));
});

final adminWatchAllStoresUseCaseProvider =
    Provider<WatchAllStoresForAdminUseCase>((ref) {
  return WatchAllStoresForAdminUseCase(ref.watch(storeRepositoryProvider));
});

final adminApproveStoreUseCaseProvider = Provider<ApproveStoreUseCase>((ref) {
  return ApproveStoreUseCase(ref.watch(storeRepositoryProvider));
});

final adminRejectStoreUseCaseProvider = Provider<RejectStoreUseCase>((ref) {
  return RejectStoreUseCase(ref.watch(storeRepositoryProvider));
});

// ── Stream Provider ────────────────────────────────────────────────────────

/// admin 승인 큐: 매장 pending 목록.
final adminPendingStoresProvider = StreamProvider<List<StoreEntity>>((ref) {
  return ref.read(adminWatchPendingStoresUseCaseProvider).call();
});

/// admin 매장 단건 실시간 감시 (storeId 기반).
final watchStoreByIdForAdminProvider =
    StreamProvider.family<StoreEntity?, String>((ref, storeId) {
  return ref
      .read(adminWatchAllStoresUseCaseProvider)
      .call()
      .map((list) => list.where((s) => s.id == storeId).firstOrNull);
});
