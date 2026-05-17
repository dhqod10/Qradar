import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/presentation/admin/approval/admin_menu_override_approval_detail_page.dart';
import 'package:qradar/presentation/admin/providers/admin_brand_customization_providers.dart';
import 'package:qradar/presentation/common/widgets/approval_status_badge.dart';

/// admin 가격 오버라이드 pending 큐 (IndexedStack 자식 — Scaffold 없음).
class AdminPendingMenuOverridesPage extends ConsumerWidget {
  const AdminPendingMenuOverridesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overridesAsync = ref.watch(pendingMenuOverridesProvider);

    return overridesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => _OverridesErrorView(
        message: '데이터를 불러오는 데 실패했어요.\n인덱스 설정이 필요할 수 있습니다.',
        onRetry: () => ref.invalidate(pendingMenuOverridesProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const _OverridesEmptyView();
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: items.length,
          itemBuilder: (_, i) => _MenuOverrideTile(menuOverride: items[i]),
        );
      },
    );
  }
}

// ── Tile ─────────────────────────────────────────────────────────────────

class _MenuOverrideTile extends StatelessWidget {
  final MenuOverrideEntity menuOverride;
  const _MenuOverrideTile({required this.menuOverride});

  @override
  Widget build(BuildContext context) {
    final mo = menuOverride;
    return Card(
      color: AppColors.surfaceElevated,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AdminMenuOverrideApprovalDetailPage(menuOverride: mo),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      mo.storeId,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHeading,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ApprovalStatusBadge(
                    status: mo.status,
                    isRevision: mo.approvedAt != null &&
                        mo.status == EntityApprovalStatus.pending,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.menu_book_outlined,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      mo.masterMenuItemId,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textBody),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _OverrideSummaryRow(menuOverride: mo),
              const SizedBox(height: 4),
              Text(
                '제출: ${_fmt(mo.submittedAt)}',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverrideSummaryRow extends StatelessWidget {
  final MenuOverrideEntity menuOverride;
  const _OverrideSummaryRow({required this.menuOverride});

  @override
  Widget build(BuildContext context) {
    final mo = menuOverride;
    final hasPriceOverride = mo.priceOverride != null;
    final isExcluded = mo.excluded;

    if (!hasPriceOverride && !isExcluded) {
      return const Text(
        '변경 내용 없음',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      );
    }

    final rows = <Widget>[];
    if (hasPriceOverride) {
      rows.add(Row(
        children: [
          Text(
            '₩${_formatPrice(mo.priceOverride!)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const Text(
            ' → ',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          Text(
            '₩${_formatPrice(mo.priceOverride!)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ));
    }
    if (isExcluded) {
      rows.add(const Row(
        children: [
          Icon(Icons.remove_circle_outline, size: 12, color: AppColors.error),
          SizedBox(width: 4),
          Text(
            '이 매장 제외',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
          ),
        ],
      ));
    }

    if (rows.length == 1) return rows.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }
}

// ── Empty / Error Views ───────────────────────────────────────────────────

class _OverridesEmptyView extends StatelessWidget {
  const _OverridesEmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.price_change_outlined,
              size: 56, color: AppColors.textMuted),
          SizedBox(height: 20),
          Text(
            '승인 대기 중인 가격 오버라이드가 없어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textHeading,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '새로운 가격 변경 요청이 들어오면 여기에 표시돼요.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OverridesErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _OverridesErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          const Text(
            '데이터를 불러오는 데 실패했어요.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('다시 시도',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

String _fmt(DateTime? dt) {
  if (dt == null) return '-';
  return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

String _formatPrice(int price) => price
    .toString()
    .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
