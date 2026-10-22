import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/owner/owner_scaffold.dart';

/// 매장이 승인 상태가 아닐 때의 안내 배너 (승인 대기 / 수정 검토 중 / 반려).
/// 요약 카드는 항상 함께 렌더된다 (차단하지 않음). 탭 → "내 매장" 탭.
class SalesStoreStatusBanner extends ConsumerWidget {
  const SalesStoreStatusBanner({super.key, required this.store});

  final StoreEntity store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRejected = store.status == EntityApprovalStatus.rejected;
    final isRevision =
        store.status == EntityApprovalStatus.pending &&
        store.approvedAt != null;

    final String title;
    final String body;
    final IconData icon;
    final Color accent;
    final double bgAlpha;
    if (isRejected) {
      title = '매장 검토가 반려되었어요';
      body = '내 매장 탭에서 사유를 확인하고 다시 제출해 주세요';
      icon = Icons.cancel_outlined;
      accent = AppColors.error;
      bgAlpha = 0.06;
    } else if (isRevision) {
      title = '수정한 내용을 검토하고 있어요';
      body = '검토 중에도 기존 주문 매출은 그대로 확인할 수 있어요';
      icon = Icons.hourglass_empty_rounded;
      accent = AppColors.warning;
      bgAlpha = 0.08;
    } else {
      title = '매장 승인을 기다리고 있어요';
      body = '승인 완료 후 주문이 접수됩니다';
      icon = Icons.hourglass_empty_rounded;
      accent = AppColors.warning;
      bgAlpha = 0.08;
    }

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '$title. $body. 탭하면 내 매장 탭으로 이동',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => ref.read(ownerTabIndexProvider.notifier).set(0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: bgAlpha),
              border: Border.all(color: accent.withValues(alpha: 0.30)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textHeading,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: const TextStyle(
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
    );
  }
}
