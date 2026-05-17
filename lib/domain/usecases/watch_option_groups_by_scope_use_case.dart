import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/repositories/option_group_repository.dart';

/// brand scope 옵션 그룹 stream.
class WatchOptionGroupsByBrandUseCase {
  final OptionGroupRepository _repository;
  WatchOptionGroupsByBrandUseCase(this._repository);

  Stream<List<OptionGroupEntity>> call({
    required String brandId,
    bool activeOnly = false,
  }) =>
      _repository.watchByBrand(brandId: brandId, activeOnly: activeOnly);
}

/// store scope 옵션 그룹 stream.
class WatchOptionGroupsByStoreUseCase {
  final OptionGroupRepository _repository;
  WatchOptionGroupsByStoreUseCase(this._repository);

  Stream<List<OptionGroupEntity>> call({
    required String storeId,
    bool activeOnly = false,
  }) =>
      _repository.watchByStore(storeId: storeId, activeOnly: activeOnly);
}
