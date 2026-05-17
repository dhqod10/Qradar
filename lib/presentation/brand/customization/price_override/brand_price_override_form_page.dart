import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/domain/entities/store_entity.dart';
import 'package:qradar/presentation/admin/providers/menu_override_providers.dart';
import 'package:qradar/presentation/brand/customization/widgets/excluded_toggle.dart';
import 'package:qradar/presentation/brand/customization/widgets/price_override_input.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';

/// 특정 마스터 메뉴에 대한 매장 가격 오버라이드 등록 / 수정 폼.
///
/// - 신규: [currentOverride] == null
/// - 수정: [currentOverride] != null → submittedBy/At 갱신, approvedBy/At 보존 (S3 패턴)
class BrandPriceOverrideFormPage extends ConsumerStatefulWidget {
  final StoreEntity store;
  final MenuItemEntity masterMenu;
  final MenuOverrideEntity? currentOverride;

  const BrandPriceOverrideFormPage({
    super.key,
    required this.store,
    required this.masterMenu,
    this.currentOverride,
  });

  @override
  ConsumerState<BrandPriceOverrideFormPage> createState() =>
      _BrandPriceOverrideFormPageState();
}

class _BrandPriceOverrideFormPageState
    extends ConsumerState<BrandPriceOverrideFormPage> {
  int? _priceOverride;
  bool _excluded = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _priceOverride = widget.currentOverride?.priceOverride;
    _excluded = widget.currentOverride?.excluded ?? false;
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final profile = ref.read(currentUserProfileProvider).asData?.value;
      final uid = profile?.uid ?? '';
      final now = DateTime.now();
      final existing = widget.currentOverride;

      final override = MenuOverrideEntity(
        masterMenuItemId: widget.masterMenu.id,
        storeId: widget.store.id,
        brandId: widget.store.brandId ?? '',
        priceOverride: _priceOverride,
        excluded: _excluded,
        // 운영 필드 보존
        soldOut: existing?.soldOut ?? false,
        disabledOptionGroupIds: existing?.disabledOptionGroupIds ?? [],
        disabledOptionItemIds: existing?.disabledOptionItemIds ?? [],
        // status=pending 회귀 (신규/수정 모두)
        status: EntityApprovalStatus.pending,
        submittedBy: uid,
        submittedAt: now,
        // S3 패턴: 수정 시 approvedBy/At 보존, 신규 시 null
        approvedBy: existing?.approvedBy,
        approvedAt: existing?.approvedAt,
        rejectedReason: null,
        updatedAt: now,
      );

      await ref.read(upsertMenuOverrideCoreUseCaseProvider).call(override);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('검토 요청을 보냈어요')),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      await showErrorDialog(context, '저장에 실패했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final master = widget.masterMenu;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          '가격 오버라이드',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 마스터 메뉴 read-only 카드
            _MasterMenuInfoCard(master: master),
            const SizedBox(height: 24),
            // 가격 오버라이드 입력
            PriceOverrideInput(
              basePriceForPlaceholder: master.basePrice,
              initialValue: _priceOverride,
              onChanged: (v) => setState(() => _priceOverride = v),
            ),
            const SizedBox(height: 20),
            // 제외 토글
            ExcludedToggle(
              value: _excluded,
              onChanged: (v) => setState(() => _excluded = v),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _SaveButton(
        isLoading: _isLoading,
        onTap: _submit,
      ),
    );
  }
}

// ── 마스터 메뉴 read-only 카드 ─────────────────────────────────────────────

class _MasterMenuInfoCard extends StatelessWidget {
  final MenuItemEntity master;

  const _MasterMenuInfoCard({required this.master});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 64,
              height: 64,
              child: master.imageUrl.isNotEmpty
                  ? Image.network(master.imageUrl, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.surface,
                      child: const Icon(
                        Icons.local_cafe_outlined,
                        size: 26,
                        color: AppColors.textMuted,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  master.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHeading,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '마스터 가격: ₩${master.basePrice}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const _ReadOnlyBadge(),
        ],
      ),
    );
  }
}

class _ReadOnlyBadge extends StatelessWidget {
  const _ReadOnlyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        '마스터',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

// ── 저장 버튼 ──────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _SaveButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isLoading ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const Text(
                      '저장 (검토 요청)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
