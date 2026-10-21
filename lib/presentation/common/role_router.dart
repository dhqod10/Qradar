import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/navigation/app_navigator_key.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/user_role.dart';
import 'package:qradar/presentation/admin/admin_scaffold.dart';
import 'package:qradar/presentation/brand/brand_scaffold.dart';
import 'package:qradar/presentation/common/notification/notification_navigator.dart';
import 'package:qradar/presentation/common/notification/pending_notification_holder.dart';
import 'package:qradar/presentation/common/scaffold_with_nav.dart';
import 'package:qradar/presentation/customer/auth/login_page.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';
import 'package:qradar/presentation/owner/owner_scaffold.dart';

/// 인증 상태 + 역할에 따라 메인 화면을 분기한다.
///
/// - 비로그인       → LoginPage
/// - customer       → ScaffoldWithNav
/// - owner          → OwnerScaffold
/// - brand          → BrandScaffold
/// - admin          → AdminScaffold
class RoleRouter extends ConsumerWidget {
  const RoleRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider);

    return profile.when(
      loading: () => const _Loading(),
      error: (e, st) => _ErrorView(error: e, stack: st),
      data: (user) {
        if (user == null) return const LoginPage();

        // 앱 종료 상태에서 알림 탭으로 진입한 경우의 deep link 처리.
        // SplashScreen 의 pushReplacement 로 스택이 교체된 뒤인 이 시점에
        // 소비해야 주문 상세 화면이 덮어써지지 않는다.
        // consume() 은 1회성이라 rebuild 시 중복 실행되지 않는다.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final pending = PendingNotificationHolder.consume();
          if (pending == null) return;
          NotificationNavigator.navigate(
            navigatorKey: navigatorKey,
            message: pending,
          );
        });

        switch (user.role) {
          case UserRole.owner:
            return const OwnerScaffold();
          case UserRole.brand:
            return const BrandScaffold();
          case UserRole.admin:
            return const AdminScaffold();
          case UserRole.customer:
            return const ScaffoldWithNav();
        }
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primaryBright),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.stack});

  final Object error;
  final StackTrace stack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '프로필 로드 실패',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  error.toString(),
                  style: const TextStyle(color: AppColors.textDark, fontSize: 13),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  stack.toString(),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
