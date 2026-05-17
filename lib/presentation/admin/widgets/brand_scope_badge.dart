import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/presentation/admin/widgets/store_scope_badge.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart';

/// brandId 로 brand 이름을 조회한 뒤 [StoreScopeBadge.brand] 로 표시하는 배지.
///
/// brand fetch 가 끝나기 전에는 임시로 '브랜드' 라벨을 노출한다.
class BrandScopeBadge extends ConsumerWidget {
  final String brandId;
  const BrandScopeBadge({super.key, required this.brandId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandAsync = ref.watch(brandByIdProvider(brandId));
    final brandName = brandAsync.asData?.value?.name ?? '브랜드';
    return StoreScopeBadge.brand(brandName);
  }
}
