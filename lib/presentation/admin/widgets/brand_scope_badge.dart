import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/domain/entities/store_brand_link.dart';
import 'package:qradar/presentation/common/providers/store_brand_link_providers.dart';
import 'package:qradar/presentation/admin/widgets/store_scope_badge.dart';

/// 매장이 가리키는 브랜드를 보여주는 배지 (승인 상세 · 승인 대기 목록 공용).
///
/// **이름 폴백(`브랜드`)이 없다.** 조회 실패·미존재·미승인에도 이름을 지어내지 않는다 — admin 이 가짜 `brandId` 를 알아채야 한다
/// (brand_authorization_hardening D5). 분류는 [resolveStoreBrandLink] 한 함수의 결과를 상세 화면과 공유한다.
///
/// | 상태 | 배지 |
/// |---|---|
/// | 확인 중 | `브랜드 확인 중` (muted) |
/// | 승인됨 | `브랜드: {이름}` |
/// | 미승인 | `브랜드 미승인` (warning) |
/// | 없음 / 조회 실패 | `브랜드 확인 필요` (warning) |
class BrandScopeBadge extends ConsumerWidget {
  final String brandId;
  const BrandScopeBadge({super.key, required this.brandId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(storeBrandLinkProvider(brandId));
    switch (link.kind) {
      case StoreBrandLinkKind.personal:
        return const StoreScopeBadge.personal();
      case StoreBrandLinkKind.checking:
        return const StoreScopeBadge.brandChecking();
      case StoreBrandLinkKind.approved:
        return StoreScopeBadge.brand(link.brand!.name);
      case StoreBrandLinkKind.unapproved:
        return const StoreScopeBadge.brandUnapproved();
      case StoreBrandLinkKind.missing:
      case StoreBrandLinkKind.lookupFailed:
        return const StoreScopeBadge.brandNeedsCheck();
    }
  }
}
