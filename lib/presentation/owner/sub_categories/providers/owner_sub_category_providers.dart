import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/sub_category_entity.dart';
import 'package:qradar/domain/usecases/watch_sub_categories_by_scope_use_case.dart';
import 'package:qradar/presentation/brand/sub_categories/providers/brand_sub_category_providers.dart';
import 'package:qradar/presentation/owner/providers/owner_providers.dart';

final watchSubCategoriesByStoreUseCaseProvider =
    Provider<WatchSubCategoriesByStoreUseCase>(
  (ref) => WatchSubCategoriesByStoreUseCase(
    ref.watch(subCategoryRepositoryProvider),
  ),
);

/// 현재 점주 매장(개인 매장)의 sub-category stream (전체, inactive 포함).
final ownerStoreSubCategoriesAllProvider =
    StreamProvider<List<SubCategoryEntity>>((ref) {
  final asyncStore = ref.watch(myStoreProvider);
  final store = asyncStore.asData?.value;
  // 개인 매장(brandId==null)만 허용
  if (store == null || store.brandId != null) return const Stream.empty();
  return ref
      .watch(watchSubCategoriesByStoreUseCaseProvider)
      .call(storeId: store.id, activeOnly: false);
});

/// 현재 점주 매장(개인 매장)의 sub-category stream (active 만 — 메뉴 폼 칩용).
final ownerStoreSubCategoriesActiveProvider =
    StreamProvider<List<SubCategoryEntity>>((ref) {
  final asyncStore = ref.watch(myStoreProvider);
  final store = asyncStore.asData?.value;
  if (store == null || store.brandId != null) return const Stream.empty();
  return ref
      .watch(watchSubCategoriesByStoreUseCaseProvider)
      .call(storeId: store.id, activeOnly: true);
});

/// 특정 storeId 의 sub-category stream (active 만 — 외부 storeId 주입).
final storeSubCategoriesByIdProvider =
    StreamProvider.family<List<SubCategoryEntity>, String>((ref, storeId) {
  return ref
      .watch(watchSubCategoriesByStoreUseCaseProvider)
      .call(storeId: storeId, activeOnly: true);
});
