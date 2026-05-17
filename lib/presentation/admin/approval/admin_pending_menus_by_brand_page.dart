import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/entity_approval_status.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/presentation/admin/approval/admin_master_menu_approval_detail_page.dart';
import 'package:qradar/presentation/admin/providers/admin_master_menu_approval_providers.dart';
import 'package:qradar/presentation/common/widgets/approval_status_badge.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/presentation/common/widgets/reject_reason_dialog.dart';
import 'package:qradar/presentation/customer/auth/auth_provider.dart';

/// Step 2 — 특정 브랜드의 pending 마스터 메뉴 목록 + 일괄 승인/반려.
class AdminPendingMenusByBrandPage extends ConsumerStatefulWidget {
  final String brandId;
  final String brandName;

  const AdminPendingMenusByBrandPage({
    super.key,
    required this.brandId,
    required this.brandName,
  });

  @override
  ConsumerState<AdminPendingMenusByBrandPage> createState() =>
      _AdminPendingMenusByBrandPageState();
}

class _AdminPendingMenusByBrandPageState
    extends ConsumerState<AdminPendingMenusByBrandPage> {
  final Set<String> _selectedIds = {};
  bool _isLoading = false;

  void _toggleItem(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleAll(List<MenuItemEntity> items) {
    setState(() {
      if (_selectedIds.length == items.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(items.map((e) => e.id));
      }
    });
  }

  Future<void> _bulkApprove(List<MenuItemEntity> items) async {
    if (_selectedIds.isEmpty) return;
    final ids = List<String>.from(_selectedIds);
    final count = ids.length;

    setState(() => _isLoading = true);
    try {
      final uid = ref.read(authProvider).asData?.value?.uid ?? '';
      await ref
          .read(bulkApproveMasterMenuItemsUseCaseProvider)
          .call(widget.brandId, ids, uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count개 메뉴를 승인했어요')),
      );
      setState(() => _selectedIds.clear());
    } catch (_) {
      if (!mounted) return;
      await showErrorDialog(context, '처리에 실패했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _bulkReject(List<MenuItemEntity> items) async {
    if (_selectedIds.isEmpty) return;

    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const RejectReasonDialog(),
    );
    if (reason == null || reason.isEmpty) return;

    final ids = List<String>.from(_selectedIds);
    final count = ids.length;

    setState(() => _isLoading = true);
    try {
      final uid = ref.read(authProvider).asData?.value?.uid ?? '';
      await ref
          .read(bulkRejectMasterMenuItemsUseCaseProvider)
          .call(widget.brandId, ids, uid, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count개 메뉴를 반려했어요')),
      );
      setState(() => _selectedIds.clear());
    } catch (_) {
      if (!mounted) return;
      await showErrorDialog(context, '처리에 실패했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync =
        ref.watch(pendingMasterMenuItemsByBrandIdProvider(widget.brandId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textHeading),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.brandName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textHeading,
              ),
            ),
            const Text(
              '메뉴 승인',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
      body: itemsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryBright)),
        error: (e, _) => _ErrorView(
          message: '데이터를 불러오는 데 실패했어요.',
          onRetry: () =>
              ref.invalidate(pendingMasterMenuItemsByBrandIdProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyView(
              icon: Icons.check_circle_outline_rounded,
              message: '승인 대기 중인 메뉴가 없어요',
            );
          }
          return Column(
            children: [
              // 전체 선택 헤더
              _SelectAllHeader(
                allCount: items.length,
                selectedCount: _selectedIds.length,
                onToggle: () => _toggleAll(items),
              ),
              // 메뉴 리스트
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return _MenuCheckTile(
                      item: item,
                      isSelected: _selectedIds.contains(item.id),
                      onCheckTap: () => _toggleItem(item.id),
                      onCardTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AdminMasterMenuApprovalDetailPage(item: item),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _isLoading
          ? _LoadingActionsBar()
          : itemsAsync.when(
              loading: () => null,
              error: (e, st) => null,
              data: (items) => items.isEmpty
                  ? null
                  : _BulkActionsBar(
                      selectedCount: _selectedIds.length,
                      isLoading: _isLoading,
                      onApprove: () => _bulkApprove(items),
                      onReject: () => _bulkReject(items),
                    ),
            ),
    );
  }
}

// ── 전체 선택 헤더 ────────────────────────────────────────────────────────

class _SelectAllHeader extends StatelessWidget {
  final int allCount;
  final int selectedCount;
  final VoidCallback onToggle;

  const _SelectAllHeader({
    required this.allCount,
    required this.selectedCount,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isAll = allCount > 0 && selectedCount == allCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: isAll,
                    tristate: false,
                    activeColor: AppColors.primary,
                    onChanged: (_) => onToggle(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '전체 선택',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textBody,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (selectedCount > 0)
            Text(
              '$selectedCount개 선택됨',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

// ── 메뉴 체크 타일 ────────────────────────────────────────────────────────

class _MenuCheckTile extends StatelessWidget {
  final MenuItemEntity item;
  final bool isSelected;
  final VoidCallback onCheckTap;
  final VoidCallback onCardTap;

  const _MenuCheckTile({
    required this.item,
    required this.isSelected,
    required this.onCheckTap,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.border,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onCardTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // 체크박스
              GestureDetector(
                onTap: onCheckTap,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Checkbox(
                    value: isSelected,
                    activeColor: AppColors.primary,
                    onChanged: (_) => onCheckTap(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 이미지
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: item.imageUrl.isNotEmpty
                      ? Image.network(item.imageUrl, fit: BoxFit.cover)
                      : Container(
                          color: AppColors.surface,
                          child: const Icon(Icons.local_cafe_outlined,
                              size: 24, color: AppColors.textMuted),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // 이름 + 가격
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHeading,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₩${_formatPrice(item.basePrice)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                    if (item.approvedAt != null &&
                        item.status == EntityApprovalStatus.pending)
                      const Text(
                        '수정 대기',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                  ],
                ),
              ),
              // 상태 배지 + chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.status != null) ApprovalStatusBadge(status: item.status!),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatPrice(int price) {
  return price
      .toString()
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}

// ── 일괄 액션 바 ──────────────────────────────────────────────────────────

class _BulkActionsBar extends StatelessWidget {
  final int selectedCount;
  final bool isLoading;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _BulkActionsBar({
    required this.selectedCount,
    required this.isLoading,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = selectedCount == 0 || isLoading;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: disabled ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: disabled
                          ? AppColors.surface
                          : AppColors.error.withValues(alpha: 0.1),
                      foregroundColor:
                          disabled ? AppColors.textMuted : AppColors.error,
                      side: BorderSide(
                        color: disabled ? AppColors.border : AppColors.error,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '선택 반려',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: disabled ? null : onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          disabled ? AppColors.surface : AppColors.primary,
                      foregroundColor:
                          disabled ? AppColors.textMuted : AppColors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '선택 승인',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingActionsBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: const SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primaryBright),
          ),
        ),
      ),
    );
  }
}

// ── 공용 위젯 ─────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyView({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppColors.textMuted),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textHeading,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

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
            '불러오기 실패',
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
