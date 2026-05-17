import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/brand_key_collision_exception.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/brand_entity.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/presentation/admin/providers/admin_brand_approval_providers.dart';
import 'package:qradar/presentation/admin/widgets/approval_actions_bar.dart';
import 'package:qradar/presentation/common/widgets/approval_status_badge.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/presentation/common/widgets/reject_reason_dialog.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';

/// 브랜드 승인 상세 — 정보 + 승인/반려 액션.
class AdminBrandApprovalDetailPage extends ConsumerStatefulWidget {
  final BrandEntity brand;
  const AdminBrandApprovalDetailPage({super.key, required this.brand});

  @override
  ConsumerState<AdminBrandApprovalDetailPage> createState() =>
      _AdminBrandApprovalDetailPageState();
}

class _AdminBrandApprovalDetailPageState
    extends ConsumerState<AdminBrandApprovalDetailPage> {
  bool _isLoading = false;

  Future<void> _approve() async {
    setState(() => _isLoading = true);
    try {
      final uid = ref.read(authProvider).asData?.value?.uid ?? '';
      await ref
          .read(adminApproveBrandUseCaseProvider)
          .call(widget.brand.id, uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('브랜드를 승인했어요. 브랜드 키가 발급되었습니다'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    } on BrandKeyCollisionException {
      if (!mounted) return;
      await showErrorDialog(context, '브랜드 키 발급에 실패했어요. 다시 시도해주세요');
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
          .read(adminRejectBrandUseCaseProvider)
          .call(widget.brand.id, uid, reason);
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
    final brand = widget.brand;
    final isPending = brand.status == EntityApprovalStatus.pending;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textHeading),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '브랜드 승인 심사',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textHeading),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // 로고 + 이름 + 배지
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: brand.logoUrl.isNotEmpty
                          ? Image.network(brand.logoUrl, fit: BoxFit.cover)
                          : Container(
                              color: AppColors.surface,
                              child: const Icon(Icons.storefront_rounded,
                                  size: 36, color: AppColors.textMuted),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(brand.name,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textHeading)),
                        const SizedBox(height: 8),
                        ApprovalStatusBadge(
                          status: brand.status,
                          isRevision: brand.approvedAt != null &&
                              brand.status == EntityApprovalStatus.pending,
                          large: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!isPending)
              _InfoBanner(
                message: brand.status == EntityApprovalStatus.approved
                    ? '이미 승인된 브랜드입니다'
                    : '반려된 브랜드입니다. 재제출을 기다리세요',
                isApproved: brand.status == EntityApprovalStatus.approved,
              ),
            if (brand.description != null) ...[
              _SectionCard(
                children: [
                  Text(brand.description!,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textBody)),
                ],
              ),
              const SizedBox(height: 16),
            ],
            _SectionCard(
              children: [
                _InfoRow('제출자 UID', brand.submittedBy ?? '-'),
                _InfoRow('제출 시각', _fmt(brand.submittedAt)),
                if (brand.approvedAt != null)
                  _InfoRow('이전 처리 시각', _fmt(brand.approvedAt)),
              ],
            ),
            if (brand.companyName.isNotEmpty ||
                brand.businessRegistrationNumber.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionCardWithTitle(
                title: '사업자 정보',
                children: [
                  if (brand.companyName.isNotEmpty)
                    _InfoRow('회사명', brand.companyName),
                  if (brand.businessRegistrationNumber.isNotEmpty)
                    _InfoRow('사업자번호', brand.businessRegistrationNumber),
                  if (brand.contactName.isNotEmpty ||
                      brand.contactPhone.isNotEmpty)
                    _InfoRow(
                      '담당자',
                      [brand.contactName, brand.contactPhone]
                          .where((s) => s.isNotEmpty)
                          .join(' / '),
                    ),
                  if (brand.headOfficeAddress != null)
                    _InfoRow('본사 주소', brand.headOfficeAddress!),
                  if (brand.representativeName != null)
                    _InfoRow('대표자', brand.representativeName!),
                ],
              ),
            ],
            if (brand.status == EntityApprovalStatus.rejected &&
                brand.rejectedReason != null) ...[
              const SizedBox(height: 16),
              _RejectedSection(reason: brand.rejectedReason!),
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

class _SectionCardWithTitle extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCardWithTitle({required this.title, required this.children});

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
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          const Divider(color: AppColors.border, thickness: 1),
          ...children,
        ],
      ),
    );
  }
}

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
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textBody)),
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
            Text('기존 반려 사유',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error)),
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
        child: Text(message,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: color),
            textAlign: TextAlign.center),
      ),
    );
  }
}

String _fmt(DateTime? dt) {
  if (dt == null) return '-';
  return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
