import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/presentation/admin/menu_categories/admin_main_category_list_page.dart';
import 'package:qradar/presentation/admin/more/admin_migration_page.dart'; // TEMP_MIGRATION_CARD (배포 ⑪ 에서 삭제)
import 'package:qradar/presentation/admin/qoin/admin_qoin_settings_page.dart';
import 'package:qradar/presentation/admin/store_management/admin_store_list_page.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/common/providers/qoin_config_providers.dart';

/// admin 더보기 — 로그아웃 / 앱 정보.
class AdminMorePage extends ConsumerWidget {
  const AdminMorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 로딩/에러 시 부제 생략 (타일은 항상 탭 가능).
    final qoinSubtitle = ref.watch(qoinConfigProvider).whenOrNull(
      data: (cfg) {
        if (cfg == null) return '설정되지 않음';
        final r = cfg.accrualRate;
        final rate = r == null ? '설정 없음' : QoinPolicy.formatRatePercent(r);
        // 적립률은 이제 계층(전역/브랜드/매장)이라 "적립률 3%" 가 전체를 뜻하는 것처럼 읽히면 거짓이다.
        return '전역 기본값 $rate · ${cfg.enabled ? '적립 중' : '적립 중단됨'}';
      },
    );
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
            icon: Icons.category_rounded,
            title: '메인 카테고리 관리',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminMainCategoryListPage(),
              ),
            ),
          ),
          _Tile(
            icon: Icons.toll_rounded,
            title: 'Qoin 설정',
            subtitle: qoinSubtitle,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminQoinSettingsPage(),
              ),
            ),
          ),
          _Tile(
            icon: Icons.storefront_rounded,
            title: '매장 관리',
            subtitle: '매장 삭제 (되돌릴 수 없음)',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminStoreListPage(),
              ),
            ),
          ),
          // TEMP_MIGRATION_CARD — 배포 ⑪ 정리 커밋에서 이 타일과 import 를 삭제한다.
          _Tile(
            icon: Icons.build_circle_outlined,
            title: '배포 마이그레이션 (임시)',
            subtitle: 'payment_server_authority ③⑤⑨',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminMigrationPage(),
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
          : const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
    );
  }
}
