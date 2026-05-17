import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/presentation/admin/providers/admin_brand_customization_providers.dart';
import 'package:qradar/presentation/admin/providers/admin_store_approval_providers.dart';
import 'package:qradar/presentation/common/widgets/approval_status_badge.dart';

/// admin 이 특정 브랜드 매장의 메뉴 (가격 오버라이드 / 점포 한정 메뉴) 직접 관리.
///
/// 본 sub-phase 는 list 만 노출. "+ 추가" 는 placeholder SnackBar (admin 직접 등록 폼은 후속).
class AdminBrandStoreManagementPage extends ConsumerWidget {
  final String storeId;
  final String brandId;

  const AdminBrandStoreManagementPage({
    super.key,
    required this.storeId,
    required this.brandId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(watchStoreByIdForAdminProvider(storeId));
    final overridesAsync = ref.watch(watchOverridesByStoreForAdminProvider(storeId));
    final storeOnlyAsync = ref.watch(watchStoreOnlyMenusForAdminProvider(storeId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '매장 직접 관리',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // 안내 배너
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'admin 이 직접 등록하면 즉시 승인 상태로 반영됩니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 매장 정보 카드
          storeAsync.when(
            loading: () => const _SectionLoading(),
            error: (e, _) => _SectionError(message: '$e'),
            data: (store) {
              if (store == null) {
                return const _SectionError(message: '매장을 찾을 수 없어요.');
              }
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHeading,
                      ),
                    ),
                    if (store.address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        store.address,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'brandId: $brandId',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // 가격 오버라이드 섹션
          _SectionHeader(
            title: '가격 오버라이드',
            onAdd: () => _showPlaceholder(context),
          ),
          const SizedBox(height: 8),
          overridesAsync.when(
            loading: () => const _SectionLoading(),
            error: (e, _) => _SectionError(message: '$e'),
            data: (overrides) {
              if (overrides.isEmpty) {
                return const _SectionEmpty(message: '가격 오버라이드가 없어요.');
              }
              return Column(
                children: [
                  for (final o in overrides) _OverrideTile(entity: o),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          // 점포 한정 메뉴 섹션
          _SectionHeader(
            title: '점포 한정 메뉴',
            onAdd: () => _showPlaceholder(context),
          ),
          const SizedBox(height: 8),
          storeOnlyAsync.when(
            loading: () => const _SectionLoading(),
            error: (e, _) => _SectionError(message: '$e'),
            data: (items) {
              if (items.isEmpty) {
                return const _SectionEmpty(message: '점포 한정 메뉴가 없어요.');
              }
              return Column(
                children: [
                  for (final m in items) _StoreOnlyTile(menu: m),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showPlaceholder(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('곧 활성화돼요')),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;
  const _SectionHeader({required this.title, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
          label: const Text(
            '추가',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _OverrideTile extends StatelessWidget {
  final MenuOverrideEntity entity;
  const _OverrideTile({required this.entity});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entity.masterMenuItemId,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeading,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entity.priceOverride != null
                      ? '₩${entity.priceOverride}'
                      : '가격 변경 없음',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                if (entity.excluded)
                  const Text(
                    '· 제외됨',
                    style: TextStyle(fontSize: 12, color: AppColors.error),
                  ),
              ],
            ),
          ),
          ApprovalStatusBadge(status: entity.status),
        ],
      ),
    );
  }
}

class _StoreOnlyTile extends StatelessWidget {
  final MenuItemEntity menu;
  const _StoreOnlyTile({required this.menu});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  menu.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeading,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₩${menu.basePrice}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (menu.status != null) ApprovalStatusBadge(status: menu.status!),
        ],
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  final String message;
  const _SectionError({required this.message});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12, color: AppColors.error),
      ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  final String message;
  const _SectionEmpty({required this.message});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
    );
  }
}
