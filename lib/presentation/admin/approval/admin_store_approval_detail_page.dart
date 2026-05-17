import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/admin/brand_store_management/admin_brand_store_management_page.dart';
import 'package:qradar/presentation/admin/providers/admin_store_approval_providers.dart';
import 'package:qradar/presentation/admin/widgets/approval_actions_bar.dart';
import 'package:qradar/presentation/admin/widgets/brand_scope_badge.dart';
import 'package:qradar/presentation/admin/widgets/store_scope_badge.dart';
import 'package:qradar/presentation/common/widgets/approval_status_badge.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/presentation/common/widgets/reject_reason_dialog.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';

/// 매장 승인 상세 — 매장 정보 + 승인/반려 액션.
class AdminStoreApprovalDetailPage extends ConsumerStatefulWidget {
  final StoreEntity store;
  const AdminStoreApprovalDetailPage({super.key, required this.store});

  @override
  ConsumerState<AdminStoreApprovalDetailPage> createState() =>
      _AdminStoreApprovalDetailPageState();
}

class _AdminStoreApprovalDetailPageState
    extends ConsumerState<AdminStoreApprovalDetailPage> {
  bool _isLoading = false;

  Future<void> _approve() async {
    setState(() => _isLoading = true);
    try {
      final uid = ref.read(authProvider).asData?.value?.uid ?? '';
      await ref
          .read(adminApproveStoreUseCaseProvider)
          .call(widget.store.id, uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('매장을 승인했어요')));
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
          .read(adminRejectStoreUseCaseProvider)
          .call(widget.store.id, uid, reason);
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
    // storeId 기반 실시간 stream — 처리 후 상태 즉시 반영
    final storeAsync =
        ref.watch(watchStoreByIdForAdminProvider(widget.store.id));

    final store = storeAsync.asData?.value ?? widget.store;
    final isPending = store.status == EntityApprovalStatus.pending;
    final firstImage =
        store.imageUrls.isNotEmpty ? store.imageUrls.first : store.imageUrl;

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
          '매장 승인',
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
            // 대표 이미지 + 이름 + 배지
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: firstImage.isNotEmpty
                          ? Image.network(firstImage, fit: BoxFit.cover)
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
                        Text(
                          store.name,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textHeading),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            ApprovalStatusBadge(status: store.status),
                            const SizedBox(width: 6),
                            if (store.brandId != null &&
                                store.brandId!.isNotEmpty)
                              BrandScopeBadge(brandId: store.brandId!)
                            else
                              const StoreScopeBadge.personal(),
                          ],
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
                message: store.status == EntityApprovalStatus.approved
                    ? '이미 승인된 매장입니다'
                    : '반려된 매장입니다. 재제출을 기다리세요',
                isApproved: store.status == EntityApprovalStatus.approved,
              ),
            // 매장 정보 섹션
            _SectionCard(
              children: [
                _InfoRow('매장 이름', store.name),
                if (store.address.isNotEmpty)
                  _InfoRow('주소', store.address),
                if (store.businessRegistrationNumber != null &&
                    store.businessRegistrationNumber!.isNotEmpty)
                  _InfoRow('사업자등록번호', store.businessRegistrationNumber!),
                if (store.menuCategories.isNotEmpty)
                  _InfoRow('카테고리', store.menuCategories.join(', ')),
                if (store.phone.isNotEmpty)
                  _InfoRow('전화번호', store.phone),
              ],
            ),
            const SizedBox(height: 16),
            // 영업시간
            if (store.businessHours != null) ...[
              _SectionCard(
                children: [
                  const Text(
                    '영업시간',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _businessHoursText(store),
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textBody),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            // 제출 / 처리 메타
            _SectionCard(
              children: [
                _InfoRow('제출자 UID', store.submittedBy ?? '-'),
                _InfoRow('제출 시각', _fmt(store.submittedAt)),
                if (store.approvedAt != null)
                  _InfoRow('처리 시각', _fmt(store.approvedAt)),
                if (store.approvedBy != null && store.approvedBy!.isNotEmpty)
                  _InfoRow('처리자 UID', store.approvedBy!),
              ],
            ),
            // 반려 사유
            if (store.status == EntityApprovalStatus.rejected &&
                store.rejectedReason != null) ...[
              const SizedBox(height: 16),
              _RejectedSection(reason: store.rejectedReason!),
            ],
            // 브랜드 매장 (approved 가 아닌 상태) — 안내 텍스트
            if (store.status != EntityApprovalStatus.approved &&
                store.brandId != null &&
                store.brandId!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '승인 후 메뉴 관리가 가능합니다',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            // 브랜드 매장 + approved 일 때만 CTA 노출 (매장 직접 관리 진입)
            if (store.status == EntityApprovalStatus.approved &&
                store.brandId != null &&
                store.brandId!.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(
                    Icons.menu_book_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  label: const Text(
                    '이 매장 메뉴 관리',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AdminBrandStoreManagementPage(
                        storeId: store.id,
                        brandId: store.brandId!,
                      ),
                    ),
                  ),
                ),
              ),
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

// ── Helpers ───────────────────────────────────────────────────────────────

String _businessHoursText(StoreEntity store) {
  final bh = store.businessHours;
  if (bh == null) return '-';
  return '${bh.openTime} ~ ${bh.closeTime}';
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

String _fmt(DateTime? dt) {
  if (dt == null) return '-';
  return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
