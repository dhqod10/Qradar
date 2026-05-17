import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/usecases/watch_option_groups_by_scope_use_case.dart';
import 'package:qradar/presentation/brand/option_groups/providers/brand_option_group_providers.dart';
import 'package:qradar/presentation/owner/providers/owner_providers.dart';

// ── UseCase 재사용 (brand_option_group_providers 에서 공유) ─────────────────

final watchOptionGroupsByStoreUseCaseProvider =
    Provider<WatchOptionGroupsByStoreUseCase>(
  (ref) => WatchOptionGroupsByStoreUseCase(
    ref.watch(optionGroupRepositoryProvider),
  ),
);

// ── Stream ─────────────────────────────────────────────────────────────────

/// 현재 로그인 점주의 매장 옵션 그룹 stream (inactive 포함).
final ownerStoreOptionGroupsAllProvider =
    StreamProvider<List<OptionGroupEntity>>((ref) {
  final asyncStore = ref.watch(myStoreProvider);
  final storeId = asyncStore.asData?.value?.id;
  if (storeId == null || storeId.isEmpty) return const Stream.empty();
  return ref
      .watch(watchOptionGroupsByStoreUseCaseProvider)
      .call(storeId: storeId, activeOnly: false);
});

/// 특정 storeId 의 옵션 그룹 stream (inactive 포함).
final ownerStoreOptionGroupsByIdProvider =
    StreamProvider.family<List<OptionGroupEntity>, String>((ref, storeId) {
  return ref
      .watch(watchOptionGroupsByStoreUseCaseProvider)
      .call(storeId: storeId, activeOnly: false);
});

/// 특정 storeId 의 옵션 그룹 stream (active 만 — 메뉴 폼 selector 용).
final ownerStoreOptionGroupsActiveByIdProvider =
    StreamProvider.family<List<OptionGroupEntity>, String>((ref, storeId) {
  return ref
      .watch(watchOptionGroupsByStoreUseCaseProvider)
      .call(storeId: storeId, activeOnly: true);
});
