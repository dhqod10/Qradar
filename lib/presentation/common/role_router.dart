import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/navigation/app_navigator_key.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/user_role.dart';
import 'package:qradar/presentation/admin/admin_scaffold.dart';
import 'package:qradar/presentation/brand/brand_scaffold.dart';
import 'package:qradar/presentation/common/account_suspended_view.dart';
import 'package:qradar/presentation/common/notification/notification_navigator.dart';
import 'package:qradar/presentation/common/notification/pending_notification_holder.dart';
import 'package:qradar/presentation/common/scaffold_with_nav.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
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
      error: (e, st) => _ProfileLoadError(error: e),
      data: (user) {
        if (user == null) return const LoginPage();

        // 계정 정지 (admin_user_moderation) — 역할 분기·알림 deep link 소비보다 먼저.
        // pending 알림을 소비하지 않고 반환해 정지 유저가 알림 탭으로 다른 화면에 가지 못한다.
        if (user.suspended) return const AccountSuspendedView();

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

/// 프로필 스트림 오류 화면. raw 예외·stack 은 노출하지 않는다.
///
/// 토큰 무효화(정지 revoke 등) 직후 users 스트림이 permission-denied 로 끊기는 경로가 정확히 여기다 —
/// 이 경우 자동으로 로그아웃해 LoginPage 로 보낸다. 그 외(일시 장애)는 재시도/로그아웃 선택지를 준다.
class _ProfileLoadError extends ConsumerStatefulWidget {
  const _ProfileLoadError({required this.error});

  final Object error;

  @override
  ConsumerState<_ProfileLoadError> createState() => _ProfileLoadErrorState();
}

class _ProfileLoadErrorState extends ConsumerState<_ProfileLoadError> {
  bool _autoSignOut = false;
  bool _busy = false;

  bool get _isPermissionDenied =>
      widget.error.toString().toLowerCase().contains('permission-denied');

  @override
  void initState() {
    super.initState();
    if (_isPermissionDenied) {
      _autoSignOut = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _signOut());
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // 성공하면 authProvider 가 null → 프로필 스트림 재계산 → Router 가 LoginPage 를 렌더한다.
      await ref.read(authProvider.notifier).signOut();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _autoSignOut = false; // 자동 경로 실패 시 수동 버튼 노출
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_autoSignOut) return const _Loading();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '정보를 불러오지 못했어요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textHeading,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '잠시 후 다시 시도해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textBody, fontSize: 14),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => ref.invalidate(currentUserProfileProvider),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
                child: const Text('다시 시도'),
              ),
              TextButton(
                onPressed: _busy ? null : _signOut,
                child: const Text(
                  '로그아웃',
                  style: TextStyle(color: AppColors.primaryBright),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
