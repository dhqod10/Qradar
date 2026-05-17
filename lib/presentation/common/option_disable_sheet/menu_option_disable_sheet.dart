import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/common/widgets/error_dialog.dart';
import 'package:qradar/domain/entities/menu_item_entity.dart';
import 'package:qradar/domain/entities/menu_override_entity.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/option_selection_type.dart';
import 'package:qradar/presentation/common/option_disable_sheet/menu_option_disable_sheet_providers.dart';
import 'package:qradar/presentation/owner/brand_store/owner_brand_store_menus_providers.dart';

/// 메뉴 타입 분류 (저장 시 분기용).
enum MenuOptionDisableSheetType {
  /// 개인 매장 메뉴 또는 브랜드 매장 점포 한정 메뉴.
  personal,

  /// 브랜드 매장 마스터 메뉴 ref (override upsert).
  brandMasterRef,
}

/// 메뉴 1개에 대한 옵션 그룹/항목 비활성 토글 BottomSheet (sub-phase 5 — W6).
///
/// - 즉시 저장 (토글 onChange 즉시 Repository 호출).
/// - 별도 "저장" 버튼 없음.
/// - 실패 시 optimistic update 원복 + SnackBar.
class MenuOptionDisableSheet extends ConsumerStatefulWidget {
  final String storeId;
  final MenuItemEntity menuItem;
  final MenuOptionDisableSheetType menuType;

  /// 브랜드 매장 마스터 ref 일 때 기존 override 참조 (없으면 null — upsert 시 신규 생성).
  final MenuOverrideEntity? existingOverride;

  const MenuOptionDisableSheet({
    super.key,
    required this.storeId,
    required this.menuItem,
    required this.menuType,
    this.existingOverride,
  });

  @override
  ConsumerState<MenuOptionDisableSheet> createState() =>
      _MenuOptionDisableSheetState();
}

class _MenuOptionDisableSheetState
    extends ConsumerState<MenuOptionDisableSheet> {
  /// 현재 비활성 그룹 ID 목록 (optimistic).
  late List<String> _disabledGroupIds;

  /// 현재 비활성 항목 compositeId 목록 (optimistic).
  late List<String> _disabledItemIds;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.menuType == MenuOptionDisableSheetType.brandMasterRef &&
        widget.existingOverride != null) {
      _disabledGroupIds =
          List<String>.from(widget.existingOverride!.disabledOptionGroupIds);
      _disabledItemIds =
          List<String>.from(widget.existingOverride!.disabledOptionItemIds);
    } else {
      _disabledGroupIds =
          List<String>.from(widget.menuItem.disabledOptionGroupIds);
      _disabledItemIds =
          List<String>.from(widget.menuItem.disabledOptionItemIds);
    }
  }

  Future<void> _saveGroupToggle(
    String groupId,
    bool isNowDisabled,
    List<String> prevGroupIds,
    List<String> prevItemIds,
  ) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await _callSaveUseCase();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _disabledGroupIds = prevGroupIds;
        _disabledItemIds = prevItemIds;
      });
      await showErrorDialog(context, '변경에 실패했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveItemToggle(
    String compositeId,
    bool isNowDisabled,
    List<String> prevGroupIds,
    List<String> prevItemIds,
  ) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await _callSaveUseCase();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _disabledGroupIds = prevGroupIds;
        _disabledItemIds = prevItemIds;
      });
      await showErrorDialog(context, '변경에 실패했어요. 다시 시도해주세요');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _callSaveUseCase() async {
    switch (widget.menuType) {
      case MenuOptionDisableSheetType.personal:
        await ref
            .read(updateDisabledOptionsForPersonalMenuUseCaseProvider)
            .call(
              widget.menuItem,
              disabledGroupIds: List<String>.from(_disabledGroupIds),
              disabledItemIds: List<String>.from(_disabledItemIds),
            );
      case MenuOptionDisableSheetType.brandMasterRef:
        final override = widget.existingOverride ??
            MenuOverrideEntity(
              masterMenuItemId: widget.menuItem.id,
              storeId: widget.storeId,
              brandId: widget.menuItem.brandId ?? '',
            );
        await ref
            .read(updateDisabledOptionsForOverrideUseCaseProvider)
            .call(
              override,
              disabledGroupIds: List<String>.from(_disabledGroupIds),
              disabledItemIds: List<String>.from(_disabledItemIds),
            );
    }
  }

  void _onGroupToggle(String groupId, bool switchValue) {
    // switchValue true = 활성(그룹 활성화), false = 비활성
    final isNowDisabled = !switchValue;
    final prevGroupIds = List<String>.from(_disabledGroupIds);
    final prevItemIds = List<String>.from(_disabledItemIds);

    setState(() {
      if (isNowDisabled) {
        if (!_disabledGroupIds.contains(groupId)) {
          _disabledGroupIds.add(groupId);
        }
      } else {
        _disabledGroupIds.remove(groupId);
      }
    });

    _saveGroupToggle(groupId, isNowDisabled, prevGroupIds, prevItemIds);
  }

  void _onItemToggle(String groupId, String itemId, bool switchValue) {
    // switchValue true = 활성, false = 비활성
    final compositeId = '${groupId}_$itemId';
    final isNowDisabled = !switchValue;
    final prevGroupIds = List<String>.from(_disabledGroupIds);
    final prevItemIds = List<String>.from(_disabledItemIds);

    setState(() {
      if (isNowDisabled) {
        if (!_disabledItemIds.contains(compositeId)) {
          _disabledItemIds.add(compositeId);
        }
      } else {
        _disabledItemIds.remove(compositeId);
      }
    });

    _saveItemToggle(compositeId, isNowDisabled, prevGroupIds, prevItemIds);
  }

  @override
  Widget build(BuildContext context) {
    // 옵션 그룹 fetch — 비활성 필터 없이 전체 (시트에서는 모든 옵션을 표시 후 토글)
    final groupsAsync =
        ref.watch(optionGroupsForMenuItemEntityProvider(widget.menuItem));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _SheetHeader(
              menuItem: widget.menuItem,
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: groupsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (err, st) => _ErrorBody(
                  onRetry: () => ref.invalidate(
                      optionGroupsForMenuItemEntityProvider(widget.menuItem)),
                ),
                data: (groups) {
                  if (groups.isEmpty) {
                    return _EmptyBody(menuType: widget.menuType);
                  }
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 32),
                    itemCount: groups.length,
                    itemBuilder: (_, i) {
                      final group = groups[i];
                      return _OptionDisableGroupRow(
                        group: group,
                        isGroupDisabled:
                            _disabledGroupIds.contains(group.id),
                        disabledItemIds: _disabledItemIds,
                        isSaving: _isSaving,
                        onGroupToggle: (v) => _onGroupToggle(group.id, v),
                        onItemToggle: (itemId, v) =>
                            _onItemToggle(group.id, itemId, v),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 헤더 ──────────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  final MenuItemEntity menuItem;
  final VoidCallback onClose;

  const _SheetHeader({required this.menuItem, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '옵션 관리',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHeading,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      menuItem.name,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 22, color: AppColors.textMuted),
                onPressed: onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 그룹 Row ──────────────────────────────────────────────────────────────

class _OptionDisableGroupRow extends StatelessWidget {
  final OptionGroupEntity group;
  final bool isGroupDisabled;
  final List<String> disabledItemIds;
  final bool isSaving;
  final void Function(bool) onGroupToggle;
  final void Function(String itemId, bool value) onItemToggle;

  const _OptionDisableGroupRow({
    required this.group,
    required this.isGroupDisabled,
    required this.disabledItemIds,
    required this.isSaving,
    required this.onGroupToggle,
    required this.onItemToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 그룹 헤더
        Container(
          color: AppColors.surface,
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          group.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isGroupDisabled
                                ? AppColors.textMuted
                                : AppColors.textHeading,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _SelectionBadge(
                          required: group.required,
                          selectionType: group.selectionType,
                        ),
                      ],
                    ),
                    if (isGroupDisabled) ...[
                      const SizedBox(height: 4),
                      const Text(
                        '비활성',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Switch.adaptive(
                value: !isGroupDisabled,
                onChanged: isSaving ? null : onGroupToggle,
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                inactiveTrackColor: AppColors.error.withValues(alpha: 0.3),
                inactiveThumbColor: AppColors.error,
              ),
            ],
          ),
        ),
        // 항목 목록 또는 안내 문구
        if (isGroupDisabled)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              '그룹을 활성화하면 항목별 관리가 가능해요.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ...group.items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final compositeId = '${group.id}_${item.id}';
            final isItemDisabled = disabledItemIds.contains(compositeId);
            return Column(
              children: [
                _OptionDisableItemRow(
                  label: item.label,
                  priceDelta: item.priceDelta,
                  isItemDisabled: isItemDisabled,
                  isSaving: isSaving,
                  onToggle: (v) => onItemToggle(item.id, v),
                ),
                if (idx < group.items.length - 1)
                  const Divider(
                    height: 1,
                    color: AppColors.border,
                    indent: 20,
                    endIndent: 20,
                  ),
              ],
            );
          }),
        const Divider(height: 8, color: AppColors.border, thickness: 1),
      ],
    );
  }
}

// ── 항목 Row ─────────────────────────────────────────────────────────────

class _OptionDisableItemRow extends StatelessWidget {
  final String label;
  final int priceDelta;
  final bool isItemDisabled;
  final bool isSaving;
  final void Function(bool) onToggle;

  const _OptionDisableItemRow({
    required this.label,
    required this.priceDelta,
    required this.isItemDisabled,
    required this.isSaving,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isItemDisabled
                        ? AppColors.textMuted
                        : AppColors.textBody,
                    decoration: isItemDisabled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                if (priceDelta != 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    priceDelta > 0
                        ? '+₩$priceDelta'
                        : '-₩${priceDelta.abs()}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: !isItemDisabled,
            onChanged: isSaving ? null : onToggle,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
            inactiveTrackColor: AppColors.error.withValues(alpha: 0.3),
            inactiveThumbColor: AppColors.error,
          ),
        ],
      ),
    );
  }
}

// ── 선택 타입 배지 ────────────────────────────────────────────────────────

class _SelectionBadge extends StatelessWidget {
  final bool required;
  final OptionSelectionType selectionType;

  const _SelectionBadge({
    required this.required,
    required this.selectionType,
  });

  @override
  Widget build(BuildContext context) {
    if (required) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '필수',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.error,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.textMuted.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        '선택',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

// ── 에러 / 빈 상태 ────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorBody({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.error),
          const SizedBox(height: 12),
          const Text(
            '옵션을 불러오지 못했어요',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textHeading),
          ),
          const SizedBox(height: 6),
          const Text(
            '잠시 후 다시 시도해주세요',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  final MenuOptionDisableSheetType menuType;

  const _EmptyBody({required this.menuType});

  @override
  Widget build(BuildContext context) {
    final hint = menuType == MenuOptionDisableSheetType.personal
        ? '옵션 그룹은 메뉴 편집에서 추가할 수 있어요.'
        : '옵션 그룹을 추가하려면 브랜드 본사에 문의하세요.';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.tune_outlined, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text(
            '이 메뉴는 옵션이 없어요',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textHeading),
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
