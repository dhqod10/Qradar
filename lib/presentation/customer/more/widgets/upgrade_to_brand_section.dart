import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';
import 'package:qradar/presentation/customer/more/widgets/upgrade_to_brand_dialog.dart';

/// 고객 [MorePage] 에 노출되는 "브랜드로 전환" 진입 섹션.
///
/// 점주 섹션 (`UpgradeToOwnerSection`) 바로 아래 위치.
/// 색상 톤: `AppColors.primary` (점주 섹션의 `AppColors.accent` 와 차별).
class UpgradeToBrandSection extends ConsumerWidget {
  const UpgradeToBrandSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceElevated, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onTap(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.12),
                  ),
                  child: const Icon(
                    Icons.domain_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '브랜드 운영자이신가요?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textHeading,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '마스터 메뉴를 관리하고 가맹점을 통합 운영하세요',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    final confirmed = await showUpgradeToBrandDialog(context);
    if (!context.mounted || confirmed != true) return;

    final authUser = ref.read(authProvider).asData?.value;
    if (authUser == null) return;

    try {
      await ref.read(upgradeToBrandUseCaseProvider).call(authUser.uid);
      // currentUserProfileProvider 의 Stream 이 role 갱신을 자동 감지 → RoleRouter 전환.
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('브랜드 전환에 실패했어요: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
