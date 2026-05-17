import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/main_category_in_use_exception.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/main_category_entity.dart';
import 'package:qradar/presentation/customer/order/store/providers/main_category_providers.dart';

/// 메인 카테고리 삭제 확인 다이얼로그.
///
/// - 사용 중 (usageCount >= 1): 삭제 차단 + "비활성화로 전환" 버튼 제안
/// - 사용 없음 (usageCount == 0): hard delete 확인
///
/// "비활성화로 전환" 클릭 시 DeactivateConfirmDialog 를 거치지 않고
/// 직접 ToggleMainCategoryActiveUseCase(id, false) 를 호출한다.
class MainCategoryDeleteDialog extends ConsumerStatefulWidget {
  final MainCategoryEntity entity;

  const MainCategoryDeleteDialog({super.key, required this.entity});

  @override
  ConsumerState<MainCategoryDeleteDialog> createState() =>
      _MainCategoryDeleteDialogState();
}

class _MainCategoryDeleteDialogState
    extends ConsumerState<MainCategoryDeleteDialog> {
  bool _isActing = false;

  Future<void> _handleDeactivate() async {
    setState(() => _isActing = true);
    try {
      await ref
          .read(toggleMainCategoryActiveUseCaseProvider)
          .call(widget.entity.id, false);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카테고리를 비활성화했어요')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('처리에 실패했어요. 다시 시도해주세요')),
      );
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _handleDelete() async {
    setState(() => _isActing = true);
    try {
      await ref
          .read(deleteMainCategoryUseCaseProvider)
          .call(widget.entity.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카테고리를 삭제했어요')),
      );
    } on MainCategoryInUseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사용 중인 카테고리는 삭제할 수 없어요'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('처리에 실패했어요. 다시 시도해주세요')),
      );
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usageAsync =
        ref.watch(mainCategoryUsageProvider(widget.entity.id));

    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.delete_outline_rounded,
                    size: 24, color: AppColors.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '카테고리 삭제',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textHeading,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.entity.label,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 본문
            usageAsync.when(
              loading: () => const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  ),
                  SizedBox(width: 8),
                  Text('확인 중...',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ],
              ),
              error: (_, _) => const Text(
                '사용 정보를 확인하지 못했어요.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              data: (usageCount) => usageCount >= 1
                  ? _BlockedBody(
                      usageCount: usageCount,
                      isActing: _isActing,
                      onDeactivate: _handleDeactivate,
                    )
                  : _DeleteBody(
                      isActing: _isActing,
                      onDelete: _handleDelete,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedBody extends StatelessWidget {
  final int usageCount;
  final bool isActing;
  final VoidCallback onDeactivate;

  const _BlockedBody({
    required this.usageCount,
    required this.isActing,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(14),
          child: Text(
            '이 카테고리에 연결된 메뉴가 $usageCount개 있어요.\n삭제하려면 메뉴를 다른 카테고리로 먼저 이동해주세요.',
            style:
                const TextStyle(fontSize: 13, color: AppColors.textBody),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '카테고리를 지금 숨기려면 비활성화를 사용하세요.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _OutlineBtn(
                label: '취소',
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionBtn(
                label: isActing ? null : '비활성화로 전환',
                backgroundColor: AppColors.warning,
                onTap: isActing ? null : onDeactivate,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeleteBody extends StatelessWidget {
  final bool isActing;
  final VoidCallback onDelete;

  const _DeleteBody({required this.isActing, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '이 카테고리를 삭제할까요? 삭제 후에는 되돌릴 수 없어요.',
          style: TextStyle(fontSize: 13, color: AppColors.textBody),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _OutlineBtn(
                label: '취소',
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionBtn(
                label: isActing ? null : '삭제',
                backgroundColor: AppColors.error,
                onTap: isActing ? null : onDelete,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OutlineBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceElevated,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textBody,
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String? label;
  final Color backgroundColor;
  final VoidCallback? onTap;

  const _ActionBtn({
    this.label,
    required this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              onTap == null ? AppColors.textMuted : backgroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        child: label == null
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.onPrimary),
              )
            : Text(
                label!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onPrimary,
                ),
              ),
      ),
    );
  }
}
