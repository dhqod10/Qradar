import 'package:qradar/domain/repositories/master_menu_item_repository.dart';

class CountStoresUsingPriceOverrideUseCase {
  final MasterMenuItemRepository _repository;

  const CountStoresUsingPriceOverrideUseCase(this._repository);

  /// priceOverride 가 적용된 매장 수 조회 (S8).
  /// 본 sub-phase 에서는 항상 0 반환.
  Future<int> call(String brandId, String menuItemId) =>
      _repository.countStoresUsingPriceOverride(brandId, menuItemId);
}
