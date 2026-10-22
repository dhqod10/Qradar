import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/qoin_formatters.dart';
import 'package:qradar/core/utils/qoin_policy.dart';
import 'package:qradar/domain/entities/qoin_config_entity.dart';
import 'package:qradar/domain/entities/user_entity.dart';
import 'package:qradar/presentation/common/q_logo.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';
import 'package:qradar/presentation/customer/qoin/providers/qoin_providers.dart';

/// Qoin 탭 잔액 카드 + 적립 정책 안내 plate.
///
/// 잔액은 이미 구독 중인 `currentUserProfileProvider` 에서 온다 (신규 구독 없음).
/// **로딩 중에는 `0 Q` 를 절대 보이지 않는다** (skeleton) — `0 Q` 는 정상 값이라 로딩과 혼동되면 안 된다.
class QoinBalanceCard extends ConsumerWidget {
  const QoinBalanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider);
    final config = ref.watch(qoinConfigProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LabelRow(),
          const SizedBox(height: 8),
          _BalanceArea(
            profile: profile,
            onRetry: () => ref.invalidate(currentUserProfileProvider),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),
          QoinPolicyPlate(config: config.asData?.value),
        ],
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent.withValues(alpha: 0.18),
          ),
          child: const ExcludeSemantics(
            child: QLogo(size: 16, animate: false, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          '내 Qoin',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _BalanceArea extends StatelessWidget {
  const _BalanceArea({required this.profile, required this.onRetry});

  final AsyncValue<UserEntity?> profile;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return profile.when(
      // 새로고침 중에도 이전 값을 유지(skipLoadingOnRefresh 기본). 최초 로딩만 skeleton.
      loading: () => Semantics(
        label: '잔액을 불러오는 중',
        excludeSemantics: true,
        child: Container(
          height: 34,
          width: 140,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      error: (_, _) => _BalanceFallback(
        message: '잔액을 불러오지 못했어요',
        onRetry: onRetry,
      ),
      data: (user) {
        if (user == null) {
          return const _BalanceFallback(message: '로그인이 필요해요');
        }
        final b = user.qoinBalance;
        return Semantics(
          label: '내 Qoin 잔액 ${QoinFormatters.balanceSpoken(b)}',
          excludeSemantics: true,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: QoinFormatters.number(b),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textHeading,
                      height: 1.1,
                      letterSpacing: -0.5,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const TextSpan(
                    text: ' Q',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        );
      },
    );
  }
}

class _BalanceFallback extends StatelessWidget {
  const _BalanceFallback({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '-',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
            child: const Text(
              '다시 시도',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

/// 적립 시점 / 사용 불가 안내 plate. 적립 시점 문구는 임의 수정 금지
/// (`결제 시 적립` 류 금지 — 사용자가 결제 직후 잔액을 찾다가 오해한다).
class QoinPolicyPlate extends StatelessWidget {
  const QoinPolicyPlate({super.key, required this.config});

  /// null = 로딩 중 / 읽기 실패 / 문서 없음 → 비율 생략 (틀린 비율을 보이지 않는다).
  final QoinConfigEntity? config;

  bool get _paused {
    final c = config;
    if (c == null) return false;
    final r = c.accrualRate;
    return !c.enabled || r == null || r == 0;
  }

  @override
  Widget build(BuildContext context) {
    final c = config;
    final paused = _paused;

    final IconData icon;
    final String title;
    final String sub;
    if (paused) {
      icon = Icons.pause_circle_outline_rounded;
      title = '지금은 Qoin 적립이 잠시 중단되어 있어요';
      sub = '이 기간에 픽업 완료된 주문은 적립 대상에서 빠질 수 있어요';
    } else {
      icon = Icons.shopping_bag_outlined;
      title = c?.accrualRate == null
          ? '픽업 완료 시 적립돼요'
          : '픽업 완료 시 결제액의 ${QoinPolicy.formatRatePercent(c!.accrualRate!)} 적립';
      sub = '결제 직후가 아니라, 매장에서 픽업 완료 처리가 되면 반영돼요';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: paused
            ? AppColors.warning.withValues(alpha: 0.10)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: '$title. $sub',
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: paused ? AppColors.warning : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textBody,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Semantics(
            label: 'Qoin 사용은 준비 중이에요',
            excludeSemantics: true,
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Qoin 사용은 준비 중이에요',
                    style: TextStyle(fontSize: 13, color: AppColors.textBody),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
