import 'package:qradar/data/datasources/remote/checkout_validation_remote_data_source.dart';
import 'package:qradar/domain/entities/checkout_validation.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/repositories/checkout_validation_repository.dart';

/// 기존 [MenuItemModel] / [MenuOverrideModel] 을 재사용해 Entity 로 변환한다 (spec §7.2 ③ — 문서 존재로 역추론).
class CheckoutValidationRepositoryImpl implements CheckoutValidationRepository {
  CheckoutValidationRepositoryImpl(this._ds);

  final CheckoutValidationRemoteDataSource _ds;

  @override
  Future<StoreSellabilityInput?> fetchStoreFresh(String storeId) async {
    final raw = await _ds.fetchStore(storeId);
    if (raw == null) return null;
    return StoreSellabilityInput(
      rawStatus: raw.rawStatus,
      hasApprovedAt: raw.hasApprovedAt,
      brandId: raw.brandId,
      temporaryClosed: raw.temporaryClosed,
    );
  }

  @override
  Future<Map<String, CheckoutMenuDocs>> fetchMenuDocsFresh({
    required String storeId,
    required String? brandId,
    required List<String> menuItemIds,
  }) async {
    final raw = await _ds.fetchMenuDocs(
      storeId: storeId,
      brandId: brandId,
      menuItemIds: menuItemIds,
    );
    return {
      for (final e in raw.entries)
        e.key: CheckoutMenuDocs(
          storeMenu: e.value.storeMenu?.toEntity(),
          master: e.value.master?.toEntity(),
          override: e.value.override?.toEntity(),
        ),
    };
  }

  @override
  Future<Map<String, OptionGroupEntity?>> fetchOptionGroupsFresh({
    required String storeId,
    required String? brandId,
    required List<OptionGroupRef> refs,
  }) async {
    final raw = await _ds.fetchOptionGroups(
      storeId: storeId,
      brandId: brandId,
      refs: [for (final r in refs) (scope: r.scope, id: r.id)],
    );
    return {
      for (final e in raw.entries) e.key: e.value?.toEntity(),
    };
  }
}
