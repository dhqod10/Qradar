import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/constants/support_contact.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';

/// 계정 정지 안내 전체화면 (admin_user_moderation).
///
/// `RoleRouter` 가 `UserEntity.suspended == true` 일 때 역할 Scaffold 대신 직접 렌더한다 (전 역할 공통).
/// **UX 안내일 뿐 보안 경계가 아니다** — 집행은 서버(Auth disabled + 토큰 revoke + 결제 게이트)가 한다.
/// 정지 사유는 표시하지 않는다. 해제는 users 스트림 갱신으로 Router 가 자동 전환한다.
class AccountSuspendedView extends ConsumerStatefulWidget {
  const AccountSuspendedView({super.key});

  @override
  ConsumerState<AccountSuspendedView> createState() =>
      _AccountSuspendedViewState();
}

class _AccountSuspendedViewState extends ConsumerState<AccountSuspendedView> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await ref.read(authProvider.notifier).signOut();
      // 성공 시 프로필 스트림이 null 이 되어 Router 가 LoginPage 로 교체한다.
    } catch (_) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      await showErrorDialog(context, '잠시 후 다시 시도해 주세요.', title: '로그아웃 실패');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),
                      const _BadgeIcon(),
                      const SizedBox(height: 24),
                      const Text(
                        '계정이 정지되었어요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textHeading,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '운영 정책에 따라 이 계정의 이용이 일시적으로 제한되어 '
                        '현재 Qradar 서비스를 사용할 수 없어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textBody,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _ContactCard(),
                      const Spacer(flex: 3),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _signingOut ? null : _signOut,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            disabledBackgroundColor: AppColors.primary,
                            disabledForegroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _signingOut
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.onPrimary,
                                  ),
                                )
                              : const Text(
                                  '로그아웃',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const ExcludeSemantics(
          child: Icon(Icons.block_outlined, size: 36, color: AppColors.warning),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이의가 있거나 문의가 필요하신가요?',
            style: TextStyle(
              color: AppColors.textHeading,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            kSupportContact,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
