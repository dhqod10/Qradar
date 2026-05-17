import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/data/datasources/remote/brand_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/master_menu_item_remote_data_source.dart';
import 'package:qradar/data/datasources/remote/storage_data_source.dart';
import 'package:qradar/data/datasources/remote/store_remote_data_source.dart';
import 'package:qradar/data/repositories/brand_repository_impl.dart';
import 'package:qradar/data/repositories/master_menu_item_repository_impl.dart';
import 'package:qradar/domain/repositories/brand_repository.dart';
import 'package:qradar/domain/repositories/master_menu_item_repository.dart';
import 'package:qradar/domain/usecases/lookup_brand_by_key_use_case.dart';
import 'package:qradar/presentation/admin/providers/menu_override_providers.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';

// ── DataSource ─────────────────────────────────────────────────────────────

final brandRemoteDataSourceProvider = Provider<BrandRemoteDataSource>((ref) {
  return BrandRemoteDataSource();
});

final brandStoreRemoteDataSourceProvider = Provider<StoreRemoteDataSource>((ref) {
  return StoreRemoteDataSource();
});

final masterMenuItemRemoteDataSourceProvider =
    Provider<MasterMenuItemRemoteDataSource>((ref) {
  return MasterMenuItemRemoteDataSource();
});

final brandStorageDataSourceProvider = Provider<StorageDataSource>((ref) {
  return StorageDataSource();
});

// ── Repository ─────────────────────────────────────────────────────────────

final brandRepositoryProvider = Provider<BrandRepository>((ref) {
  final authUser = ref.watch(authProvider).asData?.value;
  return BrandRepositoryImpl(
    ref.watch(brandRemoteDataSourceProvider),
    ref.watch(brandStoreRemoteDataSourceProvider),
    currentUidGetter: () => authUser?.uid ?? '',
  );
});

// ── UseCase ────────────────────────────────────────────────────────────────

final lookupBrandByKeyUseCaseProvider =
    Provider<LookupBrandByKeyUseCase>((ref) {
  return LookupBrandByKeyUseCase(ref.watch(brandRepositoryProvider));
});

// ── Repository (MasterMenu) ────────────────────────────────────────────────

final masterMenuItemRepositoryProvider =
    Provider<MasterMenuItemRepository>((ref) {
  final authUser = ref.watch(authProvider).asData?.value;
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  return MasterMenuItemRepositoryImpl(
    ref.watch(masterMenuItemRemoteDataSourceProvider),
    currentUidGetter: () => authUser?.uid ?? '',
    currentBrandIdGetter: () => profile?.brandId,
    menuOverrideRepository: ref.watch(menuOverrideRepositoryProvider),
  );
});
