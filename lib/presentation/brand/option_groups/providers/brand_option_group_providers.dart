import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/option_group_remote_data_source.dart';
import 'package:qradar/data/repositories/option_group_repository_impl.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/repositories/option_group_repository.dart';
import 'package:qradar/domain/usecases/count_option_group_usage_use_case.dart';
import 'package:qradar/domain/usecases/delete_option_group_use_case.dart';
import 'package:qradar/domain/usecases/find_duplicate_option_group_name_use_case.dart';
import 'package:qradar/domain/usecases/toggle_option_group_active_use_case.dart';
import 'package:qradar/domain/usecases/upsert_option_group_use_case.dart';
import 'package:qradar/domain/usecases/watch_option_groups_by_scope_use_case.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';

// ── 인프라 ─────────────────────────────────────────────────────────────────

final optionGroupRemoteDataSourceProvider =
    Provider<OptionGroupRemoteDataSource>(
  (_) => OptionGroupRemoteDataSource(),
);

final optionGroupRepositoryProvider = Provider<OptionGroupRepository>(
  (ref) => OptionGroupRepositoryImpl(
    ref.watch(optionGroupRemoteDataSourceProvider),
  ),
);

// ── UseCase ────────────────────────────────────────────────────────────────

final watchOptionGroupsByBrandUseCaseProvider =
    Provider<WatchOptionGroupsByBrandUseCase>(
  (ref) => WatchOptionGroupsByBrandUseCase(
    ref.watch(optionGroupRepositoryProvider),
  ),
);

final upsertOptionGroupUseCaseProvider =
    Provider<UpsertOptionGroupUseCase>(
  (ref) => UpsertOptionGroupUseCase(
    ref.watch(optionGroupRepositoryProvider),
  ),
);

final toggleOptionGroupActiveUseCaseProvider =
    Provider<ToggleOptionGroupActiveUseCase>(
  (ref) => ToggleOptionGroupActiveUseCase(
    ref.watch(optionGroupRepositoryProvider),
  ),
);

final deleteOptionGroupUseCaseProvider =
    Provider<DeleteOptionGroupUseCase>(
  (ref) => DeleteOptionGroupUseCase(
    ref.watch(optionGroupRepositoryProvider),
  ),
);

final findDuplicateOptionGroupNameUseCaseProvider =
    Provider<FindDuplicateOptionGroupNameUseCase>(
  (ref) => FindDuplicateOptionGroupNameUseCase(
    ref.watch(optionGroupRepositoryProvider),
  ),
);

final countOptionGroupUsageUseCaseProvider =
    Provider<CountOptionGroupUsageUseCase>(
  (ref) => CountOptionGroupUsageUseCase(
    ref.watch(optionGroupRepositoryProvider),
  ),
);

// ── Stream ─────────────────────────────────────────────────────────────────

/// 현재 로그인 brand 의 옵션 그룹 stream (inactive 포함).
final brandOptionGroupsAllProvider =
    StreamProvider<List<OptionGroupEntity>>((ref) {
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  final brandId = profile?.brandId;
  if (brandId == null || brandId.isEmpty) return const Stream.empty();
  return ref
      .watch(watchOptionGroupsByBrandUseCaseProvider)
      .call(brandId: brandId, activeOnly: false);
});

/// 특정 brandId 의 옵션 그룹 stream (inactive 포함).
final brandOptionGroupsByIdProvider =
    StreamProvider.family<List<OptionGroupEntity>, String>((ref, brandId) {
  return ref
      .watch(watchOptionGroupsByBrandUseCaseProvider)
      .call(brandId: brandId, activeOnly: false);
});

/// 특정 brandId 의 옵션 그룹 stream (active 만 — 메뉴 폼 selector 용).
final brandOptionGroupsActiveByIdProvider =
    StreamProvider.family<List<OptionGroupEntity>, String>((ref, brandId) {
  return ref
      .watch(watchOptionGroupsByBrandUseCaseProvider)
      .call(brandId: brandId, activeOnly: true);
});

// ── Usage ──────────────────────────────────────────────────────────────────

final optionGroupUsageProvider =
    FutureProvider.family<int, String>((ref, optionGroupId) async {
  return ref.watch(countOptionGroupUsageUseCaseProvider).call(optionGroupId);
});
