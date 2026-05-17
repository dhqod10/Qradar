import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
// DEV_ONLY_SEED — order_flow_phase1. 시드 제거 시 다음 import 와 사용처(앱 버전 텍스트 래퍼) 삭제.
import 'package:qradar/dev/seed/dev_seed_trigger.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/customer/more/widgets/upgrade_to_brand_section.dart';
import 'package:qradar/presentation/customer/more/widgets/upgrade_to_owner_section.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 40),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text(
              '더보기',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
          const UpgradeToOwnerSection(),
          const UpgradeToBrandSection(),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => ref.read(authProvider.notifier).signOut(),
              child: const Text(
                '로그아웃',
                style: TextStyle(color: AppColors.primaryBright),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // DEV_ONLY_SEED — order_flow_phase1. 시드 제거 시 아래 DevSeedTrigger 래퍼만 떼고 Text 만 남기면 됨.
          Center(
            child: DevSeedTrigger(
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  'Qradar v0.1.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
