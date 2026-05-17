import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/repositories/brand_repository.dart';
import 'package:qradar/domain/repositories/master_menu_item_repository.dart';
import 'package:qradar/presentation/brand/providers/brand_di_providers.dart';

// admin 모듈은 brand/master_menu repository 를 공유한다.

final adminBrandRepositoryProvider = Provider<BrandRepository>((ref) {
  return ref.watch(brandRepositoryProvider);
});

final adminMasterMenuItemRepositoryProvider =
    Provider<MasterMenuItemRepository>((ref) {
  return ref.watch(masterMenuItemRepositoryProvider);
});
