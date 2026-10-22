import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/store_brand_link.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart';

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
