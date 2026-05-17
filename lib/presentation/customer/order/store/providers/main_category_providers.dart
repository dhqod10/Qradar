import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/main_category_remote_data_source.dart';
import 'package:qradar/data/repositories/main_category_repository_impl.dart';
import 'package:qradar/domain/entities/main_category_entity.dart';
import 'package:qradar/domain/repositories/main_category_repository.dart';
import 'package:qradar/domain/usecases/count_main_category_detailed_usage_use_case.dart';
import 'package:qradar/domain/usecases/delete_main_category_use_case.dart';
import 'package:qradar/domain/usecases/toggle_main_category_active_use_case.dart';
import 'package:qradar/domain/usecases/upsert_main_category_use_case.dart';
import 'package:qradar/domain/usecases/watch_main_categories_use_case.dart';

// ── DI ───────────────────────────────────────────────────────────────────

final _mainCategoryRemoteDataSourceProvider =
    Provider<MainCategoryRemoteDataSource>(
  (_) => MainCategoryRemoteDataSource(),
);

final mainCategoryRepositoryProvider = Provider<MainCategoryRepository>(
  (ref) => MainCategoryRepositoryImpl(
    ref.watch(_mainCategoryRemoteDataSourceProvider),
  ),
);

// ── UseCase providers ─────────────────────────────────────────────────────

final watchMainCategoriesAllUseCaseProvider =
    Provider<WatchMainCategoriesAllUseCase>(
  (ref) => WatchMainCategoriesAllUseCase(
    ref.watch(mainCategoryRepositoryProvider),
  ),
);

final watchMainCategoriesActiveUseCaseProvider =
    Provider<WatchMainCategoriesActiveUseCase>(
  (ref) => WatchMainCategoriesActiveUseCase(
    ref.watch(mainCategoryRepositoryProvider),
  ),
);

final upsertMainCategoryUseCaseProvider =
    Provider<UpsertMainCategoryUseCase>(
  (ref) => UpsertMainCategoryUseCase(
    ref.watch(mainCategoryRepositoryProvider),
  ),
);

final deleteMainCategoryUseCaseProvider =
    Provider<DeleteMainCategoryUseCase>(
  (ref) => DeleteMainCategoryUseCase(
    ref.watch(mainCategoryRepositoryProvider),
  ),
);

final toggleMainCategoryActiveUseCaseProvider =
    Provider<ToggleMainCategoryActiveUseCase>(
  (ref) => ToggleMainCategoryActiveUseCase(
    ref.watch(mainCategoryRepositoryProvider),
  ),
);

final countMainCategoryDetailedUsageUseCaseProvider =
    Provider<CountMainCategoryDetailedUsageUseCase>(
  (ref) => CountMainCategoryDetailedUsageUseCase(
    ref.watch(mainCategoryRepositoryProvider),
  ),
);

// ── Stream providers ──────────────────────────────────────────────────────

/// 메인 카테고리 전체 stream (admin 용, inactive 포함).
final mainCategoriesAllProvider = StreamProvider<List<MainCategoryEntity>>(
  (ref) => ref.watch(watchMainCategoriesAllUseCaseProvider)(),
);

/// 메인 카테고리 active 만 stream (customer/brand/owner 공용).
final mainCategoriesActiveProvider = StreamProvider<List<MainCategoryEntity>>(
  (ref) => ref.watch(watchMainCategoriesActiveUseCaseProvider)(),
);

// ── Usage providers ───────────────────────────────────────────────────────

/// 카테고리별 사용 수. list UI 의 _UsageChip 에서 독립 watch.
final mainCategoryUsageProvider =
    FutureProvider.family<int, String>((ref, categoryId) async {
  return ref.watch(mainCategoryRepositoryProvider).countUsage(categoryId);
});

/// 카테고리별 영향 데이터 상세 (menuCount, storeCount).
/// DeactivateConfirmDialog 에서 사용.
final mainCategoryDetailedUsageProvider =
    FutureProvider.family<({int menuCount, int storeCount}), String>(
  (ref, categoryId) async {
    return ref
        .watch(mainCategoryRepositoryProvider)
        .countDetailedUsage(categoryId);
  },
);
