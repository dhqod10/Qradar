import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/brand/approval_tracking/brand_approval_tracking_page.dart';
import 'package:qradar/presentation/brand/option_groups/brand_option_group_list_page.dart';
import 'package:qradar/presentation/brand/sub_categories/brand_sub_category_list_page.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';

/// 브랜드측 더보기 — 검토 현황 / 로그아웃 / 앱 정보.
class BrandMorePage extends ConsumerWidget {
  const BrandMorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final brandId = profile?.brandId;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Text(
              '더보기',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading,
              ),
            ),
          ),
          _Tile(
            icon: Icons.fact_check_rounded,
            title: '검토 현황',
            subtitle: '제출한 매장·메뉴·오버라이드 진행 상태',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const BrandApprovalTrackingPage(),
              ),
            ),
          ),
          _Tile(
            icon: Icons.label_rounded,
            title: '서브 카테고리 관리',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const BrandSubCategoryListPage(),
              ),
            ),
          ),
          // 옵션 그룹 관리 — brandId 가 있는 brand 본사만 노출 (sub-phase 7)
          if (brandId != null && brandId.isNotEmpty)
            _Tile(
              icon: Icons.tune_rounded,
              title: '옵션 그룹 관리',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      BrandOptionGroupListPage(brandId: brandId),
                ),
              ),
            ),
          _Tile(
            icon: Icons.logout_rounded,
            title: '로그아웃',
            onTap: () => ref.read(authProvider.notifier).signOut(),
          ),
          const _Tile(
            icon: Icons.info_outline_rounded,
            title: '앱 정보',
            subtitle: 'Qradar v0.1.0',
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 22, color: AppColors.textBody),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textHeading,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
      trailing: onTap == null
          ? null
          : const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
    );
  }
}
