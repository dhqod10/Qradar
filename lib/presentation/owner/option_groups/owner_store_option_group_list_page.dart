import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/option_selection_type.dart';
import 'package:qradar/presentation/brand/option_groups/providers/brand_option_group_providers.dart';
import 'package:qradar/presentation/common/widgets/option_groups/option_group_delete_dialog.dart';
import 'package:qradar/presentation/owner/option_groups/owner_store_option_group_form_page.dart';
import 'package:qradar/presentation/owner/option_groups/providers/owner_option_group_providers.dart';

/// 점주 개인 매장 옵션 그룹 목록 페이지.
class OwnerStoreOptionGroupListPage extends ConsumerWidget {
  final String storeId;

  const OwnerStoreOptionGroupListPage({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync =
        ref.watch(ownerStoreOptionGroupsByIdProvider(storeId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textBody),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('옵션 그룹 관리'),
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textHeading,
        ),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                OwnerStoreOptionGroupFormPage(storeId: storeId),
          ),
        ),
        child: const Icon(Icons.add_rounded,
            color: AppColors.onPrimary, size: 24),
      ),
      body: groupsAsync.when(
        loading: () => const _LoadingBody(),
        error: (_, _) => _ErrorBody(
          onRetry: () => ref
              .invalidate(ownerStoreOptionGroupsByIdProvider(storeId)),
        ),
        data: (groups) {
          if (groups.isEmpty) return const _EmptyBody();
          return _GroupList(groups: groups, storeId: storeId);
        },
      ),
    );
  }
}

// ── 목록 ──────────────────────────────────────────────────────────────────

class _GroupList extends StatelessWidget {
  final List<OptionGroupEntity> groups;
  final String storeId;

  const _GroupList({required this.groups, required this.storeId});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: groups.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _OptionGroupCard(entity: groups[i], storeId: storeId),
      ),
    );
  }
}

// ── 카드 ──────────────────────────────────────────────────────────────────

class _OptionGroupCard extends ConsumerStatefulWidget {
  final OptionGroupEntity entity;
  final String storeId;

  const _OptionGroupCard({required this.entity, required this.storeId});

  @override
  ConsumerState<_OptionGroupCard> createState() =>
      _OptionGroupCardState();
}

class _OptionGroupCardState extends ConsumerState<_OptionGroupCard> {
  bool? _pendingActive;

  Future<void> _onSwitchChanged(bool newValue) async {
    setState(() => _pendingActive = newValue);
    try {
      await ref.read(toggleOptionGroupActiveUseCaseProvider).call(
            scope: widget.entity.scope,
            id: widget.entity.id,
            active: newValue,
            storeId: widget.entity.storeId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              newValue ? '옵션 그룹을 활성화했어요' : '옵션 그룹을 비활성화했어요'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingActive = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('처리에 실패했어요. 다시 시도해주세요')),
      );
    } finally {
      if (mounted) setState(() => _pendingActive = null);
    }
  }

  void _pushEdit() => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OwnerStoreOptionGroupFormPage(
              storeId: widget.storeId, editItem: widget.entity),
        ),
      );

  void _showDelete() => showDialog<void>(
        context: context,
        builder: (_) =>
            OptionGroupDeleteDialog(entity: widget.entity),
      );

  @override
  Widget build(BuildContext context) {
    final entity = widget.entity;
    final isActive = _pendingActive ?? entity.active;

    return Card(
      color: AppColors.surfaceElevated,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: _pushEdit,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: ListTile(
            leading: _OrderBadge(displayOrder: entity.displayOrder),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    entity.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? AppColors.textHeading
                          : AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                _SelectionTypeBadge(type: entity.selectionType),
                if (entity.required) ...[
                  const SizedBox(width: 4),
                  const _RequiredMarker(),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                _UsageChip(optionGroupId: entity.id),
                const SizedBox(height: 2),
                _ItemCountChip(count: entity.items.length),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch.adaptive(
                  value: isActive,
                  activeThumbColor: AppColors.primary,
                  activeTrackColor:
                      AppColors.primaryBright.withValues(alpha: 0.3),
                  inactiveThumbColor: AppColors.textMuted,
                  inactiveTrackColor: AppColors.surface,
                  onChanged: _onSwitchChanged,
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      size: 20, color: AppColors.textMuted),
                  onSelected: (v) {
                    if (v == 'edit') _pushEdit();
                    if (v == 'delete') _showDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('편집')),
                    PopupMenuItem(value: 'delete', child: Text('삭제')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 서브 위젯 ──────────────────────────────────────────────────────────────

class _OrderBadge extends StatelessWidget {
  final int displayOrder;
  const _OrderBadge({required this.displayOrder});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        '$displayOrder',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _SelectionTypeBadge extends StatelessWidget {
  final OptionSelectionType type;
  const _SelectionTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final isSingle = type == OptionSelectionType.single;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSingle
            ? AppColors.info.withValues(alpha: 0.12)
            : AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isSingle ? '단일' : '다중',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isSingle ? AppColors.info : AppColors.primary,
        ),
      ),
    );
  }
}

class _RequiredMarker extends StatelessWidget {
  const _RequiredMarker();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.star_rounded,
        size: 12, color: AppColors.accent);
  }
}

class _UsageChip extends ConsumerWidget {
  final String optionGroupId;
  const _UsageChip({required this.optionGroupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync =
        ref.watch(optionGroupUsageProvider(optionGroupId));
    return usageAsync.when(
      loading: () => Container(
        width: 60,
        height: 12,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      error: (_, _) => const Text('-',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
      data: (count) => Text(
        count == 0 ? '사용 없음' : '사용 중 $count개',
        style: const TextStyle(
            fontSize: 12, color: AppColors.textMuted),
      ),
    );
  }
}

class _ItemCountChip extends StatelessWidget {
  final int count;
  const _ItemCountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Text(
      count == 0 ? '항목 없음' : '항목 $count개',
      style: TextStyle(
        fontSize: 12,
        color: count == 0 ? AppColors.warning : AppColors.textMuted,
      ),
    );
  }
}

// ── 상태 UI ───────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: 4,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: _SkeletonCard(),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceElevated,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        leading: const _ShimmerBox(width: 36, height: 36, radius: 8),
        title: const _ShimmerBox(width: 120, height: 14, radius: 4),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SizedBox(height: 4),
            _ShimmerBox(width: 64, height: 10, radius: 4),
            SizedBox(height: 4),
            _ShimmerBox(width: 48, height: 10, radius: 4),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorBody({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          const Text(
            '옵션 그룹 목록을 불러오지 못했어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '잠시 후 다시 시도해주세요',
            style:
                TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text('다시 시도',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tune_outlined,
              size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            '등록된 옵션 그룹이 없어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textHeading,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '아래 버튼으로 첫 옵션 그룹을 추가해보세요',
            style:
                TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
