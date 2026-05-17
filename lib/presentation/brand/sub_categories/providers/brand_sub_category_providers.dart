import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/sub_category_remote_data_source.dart';
import 'package:qradar/data/repositories/sub_category_repository_impl.dart';
import 'package:qradar/domain/entities/sub_category_entity.dart';
import 'package:qradar/domain/repositories/sub_category_repository.dart';
import 'package:qradar/domain/usecases/count_sub_category_usage_use_case.dart';
import 'package:qradar/domain/usecases/delete_sub_category_use_case.dart';
import 'package:qradar/domain/usecases/find_duplicate_sub_category_name_use_case.dart';
import 'package:qradar/domain/usecases/toggle_sub_category_active_use_case.dart';
import 'package:qradar/domain/usecases/upsert_sub_category_use_case.dart';
import 'package:qradar/domain/usecases/watch_sub_categories_by_scope_use_case.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';

// ── 인프라 ────────────────────────────────────────────────────────────────

final subCategoryRemoteDataSourceProvider =
    Provider<SubCategoryRemoteDataSource>(
  (_) => SubCategoryRemoteDataSource(),
);

final subCategoryRepositoryProvider = Provider<SubCategoryRepository>(
  (ref) => SubCategoryRepositoryImpl(
    ref.watch(subCategoryRemoteDataSourceProvider),
  ),
);

// ── UseCase ───────────────────────────────────────────────────────────────

final watchSubCategoriesByBrandUseCaseProvider =
    Provider<WatchSubCategoriesByBrandUseCase>(
  (ref) => WatchSubCategoriesByBrandUseCase(
    ref.watch(subCategoryRepositoryProvider),
  ),
);

final upsertSubCategoryUseCaseProvider =
    Provider<UpsertSubCategoryUseCase>(
  (ref) => UpsertSubCategoryUseCase(
    ref.watch(subCategoryRepositoryProvider),
  ),
);

final toggleSubCategoryActiveUseCaseProvider =
    Provider<ToggleSubCategoryActiveUseCase>(
  (ref) => ToggleSubCategoryActiveUseCase(
    ref.watch(subCategoryRepositoryProvider),
  ),
);

final deleteSubCategoryUseCaseProvider =
    Provider<DeleteSubCategoryUseCase>(
  (ref) => DeleteSubCategoryUseCase(
    ref.watch(subCategoryRepositoryProvider),
  ),
);

final findDuplicateSubCategoryNameUseCaseProvider =
    Provider<FindDuplicateSubCategoryNameUseCase>(
  (ref) => FindDuplicateSubCategoryNameUseCase(
    ref.watch(subCategoryRepositoryProvider),
  ),
);

final countSubCategoryUsageUseCaseProvider =
    Provider<CountSubCategoryUsageUseCase>(
  (ref) => CountSubCategoryUsageUseCase(
    ref.watch(subCategoryRepositoryProvider),
  ),
);

// ── Stream ────────────────────────────────────────────────────────────────

/// 현재 로그인 brand 의 sub-category stream (전체, inactive 포함).
final brandSubCategoriesAllProvider =
    StreamProvider<List<SubCategoryEntity>>((ref) {
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  final brandId = profile?.brandId;
  if (brandId == null || brandId.isEmpty) return const Stream.empty();
  return ref
      .watch(watchSubCategoriesByBrandUseCaseProvider)
      .call(brandId: brandId, activeOnly: false);
});

/// 현재 로그인 brand 의 sub-category stream (active 만 — 메뉴 폼 칩용).
final brandSubCategoriesActiveProvider =
    StreamProvider<List<SubCategoryEntity>>((ref) {
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  final brandId = profile?.brandId;
  if (brandId == null || brandId.isEmpty) return const Stream.empty();
  return ref
      .watch(watchSubCategoriesByBrandUseCaseProvider)
      .call(brandId: brandId, activeOnly: true);
});

/// 특정 brandId 의 sub-category stream (active 만 — 외부 brandId 주입).
final brandSubCategoriesByIdProvider =
    StreamProvider.family<List<SubCategoryEntity>, String>((ref, brandId) {
  return ref
      .watch(watchSubCategoriesByBrandUseCaseProvider)
      .call(brandId: brandId, activeOnly: true);
});

// ── Usage ─────────────────────────────────────────────────────────────────

final subCategoryUsageProvider =
    FutureProvider.family<int, String>((ref, subCategoryId) async {
  return ref.watch(countSubCategoryUsageUseCaseProvider).call(subCategoryId);
});
