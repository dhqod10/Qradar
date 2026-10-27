import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/repositories/store_deletion_repository_impl.dart';
import 'package:qradar/domain/entities/store_deletion.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/domain/repositories/store_deletion_repository.dart';
import 'package:qradar/domain/usecases/admin_delete_store_use_case.dart';
import 'package:qradar/domain/usecases/preview_store_deletion_use_case.dart';
import 'package:qradar/presentation/admin/providers/admin_store_approval_providers.dart';
import 'package:qradar/presentation/brand/providers/brand_di_providers.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart';

// ── Repository / UseCase ───────────────────────────────────────────────────

final storeDeletionRepositoryProvider = Provider<StoreDeletionRepository>((
  ref,
) {
  return StoreDeletionRepositoryImpl(
    ref.watch(authorityCallablesRemoteDataSourceProvider),
  );
});

final previewStoreDeletionUseCaseProvider =
    Provider<PreviewStoreDeletionUseCase>((ref) {
      return PreviewStoreDeletionUseCase(
        ref.watch(storeDeletionRepositoryProvider),
      );
    });

final adminDeleteStoreUseCaseProvider = Provider<AdminDeleteStoreUseCase>((
  ref,
) {
  return AdminDeleteStoreUseCase(ref.watch(storeDeletionRepositoryProvider));
});

// ── 영향 범위 미리보기 ─────────────────────────────────────────────────────

/// `deleteStore(dryRun)` — 쓰기 0건. **실패는 `error`** 이고 화면은 삭제 버튼을 끈다 (fail-closed).
/// `다시 불러오기` 는 `ref.invalidate` (autoDispose -> 스켈레톤으로 복귀).
final storeDeletionPreviewProvider = FutureProvider.autoDispose
    .family<StoreDeletionPreview, String>((ref, storeId) {
      return ref.read(previewStoreDeletionUseCaseProvider).call(storeId);
    }, retry: readNoAutoRetry);

// ── 매장 관리 목록 ─────────────────────────────────────────────────────────

/// admin 전체 매장(status 무관) 실시간 목록. 기존 `WatchAllStoresForAdminUseCase` 를 재사용한다 (신규 UseCase 금지).
final adminAllStoresProvider = StreamProvider.autoDispose<List<StoreEntity>>((
  ref,
) {
  return ref.read(adminWatchAllStoresUseCaseProvider).call();
}, retry: readNoAutoRetry);
