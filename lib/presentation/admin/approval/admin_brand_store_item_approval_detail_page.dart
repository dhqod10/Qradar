import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/presentation/admin/providers/admin_brand_customization_providers.dart';
import 'package:qradar/presentation/admin/widgets/approval_actions_bar.dart';
import 'package:qradar/presentation/common/widgets/approval_status_badge.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/presentation/common/widgets/reject_reason_dialog.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';

/// 점포 한정 메뉴 승인 상세 — 메뉴 정보 + 승인/반려 액션.
class AdminBrandStoreItemApprovalDetailPage extends ConsumerStatefulWidget {
  final MenuItemEntity menuItem;
  const AdminBrandStoreItemApprovalDetailPage({
    super.key,
    required this.menuItem,
  });

  @override
  ConsumerState<AdminBrandStoreItemApprovalDetailPage> createState() =>
      _AdminBrandStoreItemApprovalDetailPageState();
}

class _AdminBrandStoreItemApprovalDetailPageState
    extends ConsumerState<AdminBrandStoreItemApprovalDetailPage> {
  bool _isLoading = false;

  Future<void> _approve() async {
    setState(() => _isLoading = true);
    try {
      final uid = ref.read(authProvider).asData?.value?.uid ?? '';
      await ref
          .read(adminApproveStoreOnlyMenuUseCaseProvider)
          .call(widget.menuItem.storeId, widget.menuItem.id, uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('점포 한정 메뉴를 승인했어요')));
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      await showErrorDialog(context, '처리에 실패했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const RejectReasonDialog(),
    );
    if (reason == null || reason.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final uid = ref.read(authProvider).asData?.value?.uid ?? '';
      await ref
          .read(adminRejectStoreOnlyMenuUseCaseProvider)
          .call(widget.menuItem.storeId, widget.menuItem.id, uid, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('반려 처리되었습니다')));
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      await showErrorDialog(context, '처리에 실패했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.menuItem;
    final isPending = item.status == EntityApprovalStatus.pending;
    final isRevision =
        item.approvedAt != null && item.status == EntityApprovalStatus.pending;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textHeading),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '점포 한정 메뉴 심사',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // 이미지 + 이름 + 배지
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: item.imageUrl.isNotEmpty
                          ? Image.network(item.imageUrl, fit: BoxFit.cover)
                          : Container(
                              color: AppColors.surface,
                              child: const Icon(Icons.add_business_outlined,
                                  size: 36, color: AppColors.textMuted),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textHeading),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₩${_formatPrice(item.basePrice)}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary),
                        ),
                        const SizedBox(height: 8),
                        if (item.status != null)
                          ApprovalStatusBadge(
                            status: item.status!,
                            isRevision: isRevision,
                            large: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 처리 완료 배너
            if (!isPending)
              _InfoBanner(
                message: item.status == EntityApprovalStatus.approved
                    ? '이미 승인된 메뉴입니다'
                    : '반려된 메뉴입니다. 재제출을 기다리세요',
                isApproved: item.status == EntityApprovalStatus.approved,
              ),
            // 메뉴 정보
            _SectionCard(
              children: [
                _InfoRow('매장 ID', item.storeId),
                _InfoRow('브랜드 ID', item.brandId ?? '-'),
                _InfoRow('카테고리', item.mainCategoryCode),
                _InfoRow('노출 여부', item.visible ? '노출' : '숨김'),
                _InfoRow('제출자 UID', item.submittedBy ?? '-'),
                _InfoRow('제출 시각', _fmt(item.submittedAt)),
                if (item.approvedAt != null)
                  _InfoRow('이전 처리 시각', _fmt(item.approvedAt)),
              ],
            ),
            // 설명
            if (item.description != null && item.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionCard(
                children: [
                  const Text(
                    '설명',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.description!,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textBody),
                  ),
                ],
              ),
            ],
            // 반려 사유
            if (item.status == EntityApprovalStatus.rejected &&
                item.rejectedReason != null) ...[
              const SizedBox(height: 16),
              _RejectedSection(reason: item.rejectedReason!),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: isPending
          ? ApprovalActionsBar(
              isLoading: _isLoading,
              onApprove: _approve,
              onReject: _reject,
            )
          : null,
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textBody),
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectedSection extends StatelessWidget {
  final String reason;
  const _RejectedSection({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.info_outline_rounded, size: 16, color: AppColors.error),
            SizedBox(width: 6),
            Text(
              '반려 사유',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error),
            ),
          ]),
          const SizedBox(height: 8),
          Text(reason,
              style: const TextStyle(fontSize: 13, color: AppColors.textBody)),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String message;
  final bool isApproved;
  const _InfoBanner({required this.message, required this.isApproved});

  @override
  Widget build(BuildContext context) {
    final color = isApproved ? AppColors.success : AppColors.error;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500, color: color),
          textAlign: TextAlign.center,
        ),
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
