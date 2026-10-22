import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/common/scaffold_with_nav.dart';
import 'package:qradar/presentation/customer/qoin/providers/qoin_providers.dart';

/// 진행 중 주문(paid~ready) 안내 배너. 건수와 시점만 안내하며 **금액은 표시하지 않는다**.
///
/// "방금 결제했는데 Qoin 이 그대로" 라는 오해를 그 순간에 막는 장치.
/// 로딩/에러/0건이면 아무것도 렌더하지 않는다 (조용히 생략).
class QoinInProgressBanner extends ConsumerWidget {
  const QoinInProgressBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(qoinInProgressOrderCountProvider);
    if (count == null || count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label: '진행 중인 주문이 $count건 있어요. 픽업이 완료되면 Qoin 이 적립돼요. '
            '탭하면 Log 탭으로 이동',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            // Log 탭 = 3
            onTap: () => ref.read(selectedTabIndexProvider.notifier).set(3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryBright.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryBright.withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '진행 중인 주문이 $count건 있어요',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textHeading,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '픽업이 완료되면 Qoin 이 적립돼요',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.textBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
