import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/presentation/admin/approval/admin_brand_approval_detail_page.dart';
import 'package:qradar/presentation/admin/approval/admin_pending_brand_store_items_page.dart';
import 'package:qradar/presentation/admin/approval/admin_pending_menu_overrides_page.dart';
import 'package:qradar/presentation/admin/approval/admin_pending_menus_by_brand_page.dart';
import 'package:qradar/presentation/admin/approval/admin_pending_stores_page.dart';
import 'package:qradar/presentation/admin/providers/admin_brand_approval_providers.dart';
import 'package:qradar/presentation/admin/providers/admin_master_menu_approval_providers.dart';
import 'package:qradar/presentation/brand/providers/brand_info_providers.dart';
import 'package:qradar/presentation/common/widgets/approval_status_badge.dart';

/// 승인 — 세그먼트: 브랜드 / 메뉴 / 매장 / 매장 커스텀.
class AdminApprovalQueuePage extends ConsumerStatefulWidget {
  const AdminApprovalQueuePage({super.key});

  @override
  ConsumerState<AdminApprovalQueuePage> createState() =>
      _AdminApprovalQueuePageState();
}

class _AdminApprovalQueuePageState
    extends ConsumerState<AdminApprovalQueuePage> {
  int _segIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '승인',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                _SegTab(
                  label: '브랜드',
                  selected: _segIndex == 0,
                  onTap: () => setState(() => _segIndex = 0),
                ),
                _SegTab(
                  label: '메뉴',
                  selected: _segIndex == 1,
                  onTap: () => setState(() => _segIndex = 1),
                ),
                _SegTab(
                  label: '매장',
                  selected: _segIndex == 2,
                  onTap: () => setState(() => _segIndex = 2),
                ),
                _SegTab(
                  label: '매장 커스텀',
                  selected: _segIndex == 3,
                  onTap: () => setState(() => _segIndex = 3),
                ),
              ],
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _segIndex,
        children: const [
          _BrandPendingList(),
          _MasterMenuPendingList(),
          AdminPendingStoresPage(),
          _StoreCustomizationSection(),
        ],
      ),
    );
  }
}

class _SegTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
              ),
              if (selected)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(height: 2, color: AppColors.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Store Customization Section ───────────────────────────────────────────

class _StoreCustomizationSection extends StatefulWidget {
  const _StoreCustomizationSection();

  @override
  State<_StoreCustomizationSection> createState() =>
      _StoreCustomizationSectionState();
}

class _StoreCustomizationSectionState
    extends State<_StoreCustomizationSection> {
  int _subIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              _SubTab(
                label: '가격 오버라이드',
                selected: _subIndex == 0,
                onTap: () => setState(() => _subIndex = 0),
              ),
              _SubTab(
                label: '점포 한정 메뉴',
                selected: _subIndex == 1,
                onTap: () => setState(() => _subIndex = 1),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _subIndex,
            children: const [
              AdminPendingMenuOverridesPage(),
              AdminPendingBrandStoreItemsPage(),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SubTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color:
                      selected ? AppColors.primaryBright : AppColors.textMuted,
                ),
              ),
              if (selected)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(height: 2, color: AppColors.primaryBright),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Brand Pending List ────────────────────────────────────────────────────

class _BrandPendingList extends ConsumerWidget {
  const _BrandPendingList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandsAsync = ref.watch(pendingBrandsProvider);

    return brandsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.primaryBright)),
      error: (e, _) => _ErrorView(
        message: '데이터를 불러오는 데 실패했어요.\n인덱스 설정이 필요할 수 있습니다.',
        onRetry: () => ref.invalidate(pendingBrandsProvider),
      ),
      data: (brands) {
        if (brands.isEmpty) {
          return const _EmptyView(
            icon: Icons.check_circle_outline_rounded,
            message: '검토 대기 중인 브랜드가 없어요',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: brands.length,
          itemBuilder: (_, i) => _BrandQueueTile(brand: brands[i]),
        );
      },
    );
  }
}

class _BrandQueueTile extends StatelessWidget {
  final BrandEntity brand;
  const _BrandQueueTile({required this.brand});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 52,
            height: 52,
            child: brand.logoUrl.isNotEmpty
                ? Image.network(brand.logoUrl, fit: BoxFit.cover)
                : Container(
                    color: AppColors.surface,
                    child: const Icon(Icons.storefront_rounded,
                        size: 24, color: AppColors.textMuted),
                  ),
          ),
        ),
        title: Text(
          brand.name,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textHeading),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '제출: ${_fmt(brand.submittedAt)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (brand.approvedAt != null &&
                brand.status == EntityApprovalStatus.pending)
              const Text(
                '수정 대기',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ApprovalStatusBadge(status: brand.status),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminBrandApprovalDetailPage(brand: brand),
          ),
        ),
      ),
    );
  }
}

// ── Master Menu Pending List ──────────────────────────────────────────────

/// Step 1 — 브랜드 리스트 (sub-phase 6 재설계: 2-step 일괄 승인 흐름).
///
/// 각 브랜드별 pending 마스터 메뉴 카운트 표시.
/// onTap → AdminPendingMenusByBrandPage (체크박스 + 일괄 승인/반려).
class _MasterMenuPendingList extends ConsumerWidget {
  const _MasterMenuPendingList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedAsync = ref.watch(pendingMasterMenuItemsByBrandProvider);

    return groupedAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBright),
      ),
      error: (e, _) => _ErrorView(
        message: '데이터를 불러오는 데 실패했어요.\n인덱스 설정이 필요할 수 있습니다.',
        onRetry: () => ref.invalidate(pendingMasterMenuItemsProvider),
      ),
      data: (groups) {
        if (groups.isEmpty) {
          return const _EmptyView(
            icon: Icons.check_circle_outline_rounded,
            message: '검토 대기 중인 메뉴가 없어요',
          );
        }
        final entries = groups.entries.toList();
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: entries.length,
          itemBuilder: (_, i) => _BrandPendingTile(
            brandId: entries[i].key,
            count: entries[i].value.length,
          ),
        );
      },
    );
  }
}

/// 브랜드별 pending 메뉴 카운트 타일. onTap → 일괄 승인 화면 push.
class _BrandPendingTile extends ConsumerWidget {
  final String brandId;
  final int count;
  const _BrandPendingTile({required this.brandId, required this.count});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandAsync = ref.watch(brandByIdProvider(brandId));
    final brand = brandAsync.asData?.value;
    final brandName = brand?.name ?? '브랜드';
    final logoUrl = brand?.logoUrl ?? '';

    return Card(
      color: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 52,
            height: 52,
            child: logoUrl.isNotEmpty
                ? Image.network(logoUrl, fit: BoxFit.cover)
                : Container(
                    color: AppColors.surface,
                    child: const Icon(
                      Icons.business_rounded,
                      size: 24,
                      color: AppColors.textMuted,
                    ),
                  ),
          ),
        ),
        title: Text(
          brandName,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textHeading,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '검토 대기 $count건',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: AppColors.textMuted,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AdminPendingMenusByBrandPage(
              brandId: brandId,
              brandName: brandName,
            ),
          ),
        ),
      ),
    );
  }
}

// _MasterMenuQueueTile: sub-phase 6 (2-step 일괄 승인) 으로 폐기. AdminPendingMenusByBrandPage 가 메뉴 리스트 + 일괄 승인 담당.

// ── Shared ────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyView({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppColors.textMuted),
          const SizedBox(height: 20),
          Text(message,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textHeading)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          const Text('불러오기 실패',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textHeading)),
          const SizedBox(height: 8),
          Text(message,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('다시 시도', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

String _fmt(DateTime? dt) {
  if (dt == null) return '-';
  return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
