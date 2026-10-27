import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/admin/providers/admin_store_deletion_providers.dart';
import 'package:qradar/presentation/admin/store_management/admin_store_delete_page.dart';
import 'package:qradar/presentation/admin/widgets/brand_scope_badge.dart';
import 'package:qradar/presentation/admin/widgets/store_scope_badge.dart';
import 'package:qradar/presentation/common/providers/store_brand_link_providers.dart';
import 'package:qradar/presentation/common/widgets/approval_status_badge.dart';

/// 목록·삭제 확인 입력이 공유하는 매장 표시 이름 — 브랜드 매장은 `'{브랜드명} {지점명}'`, 개인 매장은 매장명.
///
/// 같은 이름 지점을 구분하려는 것이라 **목록에 보이는 이름과 삭제 확인에 입력할 이름이 같아야 한다.**
/// 브랜드 이름을 모르면(확인 중·조회 실패) 지점명만 쓴다 — 이름을 지어내지 않는다.
String adminStoreDisplayName(StoreEntity store, String? brandName) {
  final isBrand = store.brandId != null && store.brandId!.isNotEmpty;
  if (!isBrand || brandName == null || brandName.isEmpty) return store.name;
  return '$brandName ${store.name}';
}

/// admin 매장 관리 — 전체 매장 목록(검색) -> 행 탭 -> [AdminStoreDeletePage].
class AdminStoreListPage extends ConsumerStatefulWidget {
  const AdminStoreListPage({super.key});

  @override
  ConsumerState<AdminStoreListPage> createState() => _AdminStoreListPageState();
}

class _AdminStoreListPageState extends ConsumerState<AdminStoreListPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminAllStoresProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textHeading,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '매장 관리',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: TextField(
              key: const ValueKey('adminStoreList.search'),
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 14, color: AppColors.textBody),
              decoration: InputDecoration(
                hintText: '매장 이름으로 검색',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: () => const _SkeletonList(),
              error: (_, _) => _ErrorView(
                onRetry: () => ref.invalidate(adminAllStoresProvider),
              ),
              data: (stores) {
                if (stores.isEmpty) {
                  return const _EmptyView(
                    icon: Icons.storefront_outlined,
                    title: '등록된 매장이 없어요',
                  );
                }
                final q = _query.trim().toLowerCase();
                final filtered = q.isEmpty
                    ? stores
                    : stores.where((s) {
                        // 브랜드 이름은 배지가 쓰는 것과 같은 provider 에서 읽는다 (한 사실에 한 출처).
                        final brandName = ref
                            .watch(storeBrandLinkProvider(s.brandId))
                            .brand
                            ?.name;
                        return adminStoreDisplayName(
                              s,
                              brandName,
                            ).toLowerCase().contains(q) ||
                            s.name.toLowerCase().contains(q);
                      }).toList();
                if (filtered.isEmpty) {
                  return _EmptyView(
                    icon: Icons.search_off_rounded,
                    title: "'${_query.trim()}' 와 일치하는 매장이 없어요",
                    subtitle: '검색어를 지우면 전체 목록이 보여요',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _StoreRow(store: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreRow extends ConsumerWidget {
  const _StoreRow({required this.store});
  final StoreEntity store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBrand = store.brandId != null && store.brandId!.isNotEmpty;
    final brandName = ref
        .watch(storeBrandLinkProvider(store.brandId))
        .brand
        ?.name;
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('adminStoreList.row.${store.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AdminStoreDeletePage(store: store),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      adminStoreDisplayName(store, brandName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHeading,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ApprovalStatusBadge(
                    status: store.status,
                    isRevision:
                        store.approvedAt != null &&
                        store.status == EntityApprovalStatus.pending,
                  ),
                ],
              ),
              if (store.address.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  store.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: isBrand
                    ? BrandScopeBadge(brandId: store.brandId!)
                    : const StoreScopeBadge.personal(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const ValueKey('adminStoreList.loading'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Container(
        height: 76,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          const Text(
            '매장 목록을 불러오지 못했어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              '다시 시도',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.icon, required this.title, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: subtitle == null ? 16 : 14,
                fontWeight: subtitle == null
                    ? FontWeight.w700
                    : FontWeight.w400,
                color: subtitle == null
                    ? AppColors.textHeading
                    : AppColors.textBody,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
