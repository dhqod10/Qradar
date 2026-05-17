import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/presentation/admin/providers/menu_override_providers.dart';
import 'package:qradar/presentation/admin/widgets/approval_actions_bar.dart';
import 'package:qradar/presentation/common/widgets/reject_reason_dialog.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';

/// 가격 오버라이드 승인 상세 — 변경 내용 + 승인/반려 액션.
class AdminMenuOverrideApprovalDetailPage extends ConsumerStatefulWidget {
  final MenuOverrideEntity menuOverride;
  const AdminMenuOverrideApprovalDetailPage(
      {super.key, required this.menuOverride});

  @override
  ConsumerState<AdminMenuOverrideApprovalDetailPage> createState() =>
      _AdminMenuOverrideApprovalDetailPageState();
}

class _AdminMenuOverrideApprovalDetailPageState
    extends ConsumerState<AdminMenuOverrideApprovalDetailPage> {
  bool _isLoading = false;

  Future<void> _approve() async {
    setState(() => _isLoading = true);
    try {
      final uid = ref.read(authProvider).asData?.value?.uid ?? '';
      await ref.read(approveMenuOverrideUseCaseProvider).call(
            widget.menuOverride.storeId,
            widget.menuOverride.masterMenuItemId,
            uid,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('승인했어요')));
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
      await ref.read(rejectMenuOverrideUseCaseProvider).call(
            widget.menuOverride.storeId,
            widget.menuOverride.masterMenuItemId,
            uid,
            reason,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('반려했어요')));
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
    final mo = widget.menuOverride;
    final isPending = mo.status == EntityApprovalStatus.pending;
    final isApproved = mo.status == EntityApprovalStatus.approved;
    final isRejected = mo.status == EntityApprovalStatus.rejected;

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
          '오버라이드 검토',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 16),
              // SectionA — 상태 배너
              if (isApproved)
                _StatusBanner(
                  message: '승인되었어요',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
              if (isRejected)
                _StatusBanner(
                  message: '반려되었어요',
                  icon: Icons.cancel_rounded,
                  color: AppColors.error,
                ),
              // SectionB — 매장 정보
              _DetailSection(
                title: '매장 정보',
                children: [
                  _InfoRow('매장 ID', mo.storeId),
                  _InfoRow('브랜드 ID', mo.brandId),
                ],
              ),
              const SizedBox(height: 12),
              // SectionC — 마스터 메뉴 정보
              _DetailSection(
                title: '마스터 메뉴',
                children: [
                  _InfoRow('메뉴 ID', mo.masterMenuItemId),
                ],
              ),
              const SizedBox(height: 12),
              // SectionD — 변경 내용
              _DetailSection(
                title: '변경 내용',
                children: [
                  if (mo.priceOverride != null)
                    _ChangeRow(
                      label: '가격 변경',
                      child: Row(
                        children: [
                          Text(
                            '₩${_formatPrice(mo.priceOverride!)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textMuted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const Text(
                            ' → ',
                            style: TextStyle(
                                fontSize: 14, color: AppColors.textMuted),
                          ),
                          Text(
                            '₩${_formatPrice(mo.priceOverride!)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (mo.excluded)
                    _ChangeRow(
                      label: '메뉴 제외',
                      child: Row(
                        children: const [
                          Icon(Icons.remove_circle_rounded,
                              size: 18, color: AppColors.error),
                          SizedBox(width: 6),
                          Text(
                            '이 매장에서 제외',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!mo.excluded && mo.priceOverride == null)
                    const _InfoRow('변경 없음', '-'),
                ],
              ),
              const SizedBox(height: 12),
              // SectionE — 처리 정보
              _DetailSection(
                title: '처리 정보',
                children: [
                  _InfoRow('제출자', mo.submittedBy ?? '-'),
                  _InfoRow('제출일', _fmt(mo.submittedAt)),
                  if (isApproved) ...[
                    _InfoRow('승인자', mo.approvedBy ?? '-'),
                    _InfoRow('승인일', _fmt(mo.approvedAt)),
                  ],
                  if (isRejected && mo.rejectedReason != null)
                    _RejectedReasonRow(reason: mo.rejectedReason!),
                ],
              ),
              const SizedBox(height: 100),
            ]),
          ),
        ],
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

class _StatusBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;
  const _StatusBanner(
      {required this.message, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _DetailSection({required this.title, required this.children});

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
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 5),
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
                color: AppColors.textBody,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _ChangeRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          child,
        ],
      ),
    );
  }
}

class _RejectedReasonRow extends StatelessWidget {
  final String reason;
  const _RejectedReasonRow({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '반려 사유',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            reason,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.error,
            ),
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
