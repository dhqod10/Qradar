import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/common/notification/notification_settings_page.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';

/// 점주측 더보기.
///
/// MVP: 고객 모드 전환 / 로그아웃 / 앱 정보 placeholder.
class OwnerMorePage extends ConsumerWidget {
  const OwnerMorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                color: AppColors.textDark,
              ),
            ),
          ),
          _Tile(
            icon: Icons.notifications_outlined,
            title: '알림 설정',
            subtitle: '신규 주문 · 환불 요청 알림을 설정해요',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationSettingsPage(),
              ),
            ),
          ),
          _Tile(
            icon: Icons.person_outline_rounded,
            title: '고객 모드로 전환',
            subtitle: '다시 Qrator로 돌아가 주문을 체험해보세요',
            onTap: () => _onSwitchToCustomer(context, ref),
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

  Future<void> _onSwitchToCustomer(BuildContext context, WidgetRef ref) async {
    final authUser = ref.read(authProvider).asData?.value;
    if (authUser == null) return;
    try {
      await ref.read(downgradeToCustomerUseCaseProvider).call(authUser.uid);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('전환에 실패했어요: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
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
      leading: Icon(icon, size: 22, color: AppColors.textDefault),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
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
