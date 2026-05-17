import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/presentation/common/widgets/approval_status_badge.dart';

/// 마스터 메뉴 + override 현황을 머지하여 표시하는 카드.
///
/// [BrandPriceOverrideListPage] 에서 각 마스터 메뉴 행으로 사용.
class MasterMenuOverrideCard extends StatelessWidget {
  final MenuItemEntity master;
  final MenuOverrideEntity? menuOverride;
  final VoidCallback? onTap;

  const MasterMenuOverrideCard({
    super.key,
    required this.master,
    this.menuOverride,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasOverride = menuOverride != null;
    final isRevision = hasOverride && menuOverride!.approvedAt != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 행 1: 메뉴명 + override 승인 뱃지
              Row(
                children: [
                  Expanded(
                    child: Text(
                      master.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHeading,
                      ),
                    ),
                  ),
                  if (hasOverride)
                    ApprovalStatusBadge(
                      status: menuOverride!.status,
                      isRevision: isRevision,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // 행 2: 가격 미리보기
              _PriceRow(master: master, menuOverride: menuOverride),
              const SizedBox(height: 8),
              // 행 3: excluded 칩 + 화살표
              Row(
                children: [
                  if (hasOverride && menuOverride!.excluded)
                    _ExcludedChip(status: menuOverride!.status),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 가격 미리보기 행 ───────────────────────────────────────────────────────

class _PriceRow extends StatelessWidget {
  final MenuItemEntity master;
  final MenuOverrideEntity? menuOverride;

  const _PriceRow({required this.master, required this.menuOverride});

  @override
  Widget build(BuildContext context) {
    final basePrice = master.basePrice;

    if (menuOverride == null || menuOverride!.priceOverride == null) {
      return Text(
        '₩$basePrice',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textBody,
        ),
      );
    }

    final priceOverride = menuOverride!.priceOverride!;
    final status = menuOverride!.status;

    if (status == EntityApprovalStatus.approved) {
      // 확정 변경: 취소선 → override 가격
      return Row(
        children: [
          Text(
            '₩$basePrice',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            '→',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(width: 6),
          Text(
            '₩$priceOverride',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      );
    } else if (status == EntityApprovalStatus.pending) {
      // 검토 중
      return Row(
        children: [
          Text(
            '₩$basePrice',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textBody,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '→ ₩$priceOverride (검토 중)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.warning,
            ),
          ),
        ],
      );
    } else {
      // rejected — 마스터 가격만 표시 (override 미적용)
      return Text(
        '₩$basePrice',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textBody,
        ),
      );
    }
  }
}

// ── 제외 칩 ───────────────────────────────────────────────────────────────

class _ExcludedChip extends StatelessWidget {
  final EntityApprovalStatus status;

  const _ExcludedChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPending = status == EntityApprovalStatus.pending;
    final color = isPending ? AppColors.warning : AppColors.error;
    final label = isPending ? '제외 검토 중' : '이 매장 제외';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.remove_circle_outline_rounded, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
