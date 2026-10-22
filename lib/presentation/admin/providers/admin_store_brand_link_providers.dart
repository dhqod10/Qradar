import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/utils/qoin_rate_resolver.dart';
import 'package:qradar/domain/entities/store_brand_link.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart';
import 'package:qradar/presentation/common/providers/qoin_config_providers.dart';

/// 매장이 가리키는 브랜드의 분류 (승인 상세 · 승인 대기 목록 배지 · 승인 버튼 공용). 파라미터는 `store.brandId`.
///
/// 조회 에러는 `lookupFailed` 로 따로 분류한다 — 미존재(`missing`)와 구별한다. 에러가 값 뒤에 와도 에러로 본다(fail-closed).
final storeBrandLinkProvider = Provider.autoDispose
    .family<StoreBrandLink, String?>((ref, brandId) {
      if (brandId == null || brandId.isEmpty) return StoreBrandLink.personal;
      final a = ref.watch(brandByIdProvider(brandId));
      final BrandLookup lookup = a.hasError
          ? const BrandLookupFailed()
          : a.hasValue
          ? BrandLookupLoaded(a.value)
          : const BrandLookupLoading();
      return resolveStoreBrandLink(brandId: brandId, lookup: lookup);
    });

/// 승인하면 이 매장이 따르게 될 적립률 (승인 상세 블록 · 승인 확인 다이얼로그가 같은 결과를 쓴다).
/// 브랜드가 `approved` 로 확인된 뒤에만 의미가 있다. 전역 설정(`config/qoin`) 로딩·실패는 그대로 전달한다 —
/// 임시 해석을 만들지 않는다. **적립률 읽기 실패는 승인을 막지 않는다**(승인 게이트는 브랜드 실재성이다, design §2-e).
final inheritedRateProvider = Provider.autoDispose
    .family<AsyncValue<InheritedRate?>, String?>((ref, brandId) {
      final link = ref.watch(storeBrandLinkProvider(brandId));
      final brand = link.brand;
      if (link.kind != StoreBrandLinkKind.approved || brand == null) {
        return const AsyncValue.data(null);
      }
      final cfg = ref.watch(qoinConfigProvider);
      if (cfg.hasError) {
        return AsyncValue.error(
          cfg.error!,
          cfg.stackTrace ?? StackTrace.current,
        );
      }
      if (!cfg.hasValue) return const AsyncValue.loading();
      return AsyncValue.data(
        resolveInheritedRate(
          brand: brand,
          global: cfg.value?.accrualRateSetting ?? QoinRateSetting.absent,
        ),
      );
    });
