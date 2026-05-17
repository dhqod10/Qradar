import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/usecases/approve_brand_use_case.dart';
import 'package:qradar/domain/usecases/reject_brand_use_case.dart';
import 'package:qradar/domain/usecases/watch_all_brands_for_admin_use_case.dart';
import 'package:qradar/domain/usecases/watch_pending_brands_use_case.dart';
import 'package:qradar/presentation/admin/providers/admin_di_providers.dart';

// ── UseCase Provider ───────────────────────────────────────────────────────

final watchPendingBrandsUseCaseProvider =
    Provider<WatchPendingBrandsUseCase>((ref) {
  return WatchPendingBrandsUseCase(
      ref.watch(adminBrandRepositoryProvider));
});

final watchAllBrandsForAdminUseCaseProvider =
    Provider<WatchAllBrandsForAdminUseCase>((ref) {
  return WatchAllBrandsForAdminUseCase(
      ref.watch(adminBrandRepositoryProvider));
});

final adminApproveBrandUseCaseProvider = Provider<ApproveBrandUseCase>((ref) {
  return ApproveBrandUseCase(ref.watch(adminBrandRepositoryProvider));
});

final adminRejectBrandUseCaseProvider = Provider<RejectBrandUseCase>((ref) {
  return RejectBrandUseCase(ref.watch(adminBrandRepositoryProvider));
});

// ── Stream Provider ────────────────────────────────────────────────────────

/// admin 승인 큐: 브랜드 pending 목록.
final pendingBrandsProvider = StreamProvider<List<BrandEntity>>((ref) {
  return ref.read(watchPendingBrandsUseCaseProvider).call();
});
