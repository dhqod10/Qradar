import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/option_item_entity.dart';
import 'package:qradar/domain/entities/option_scope.dart';
import 'package:qradar/presentation/common/widgets/option_groups/option_item_list_editor.dart';

/// 메뉴 폼에서 옵션 그룹 다중 선택 위젯 (sub-phase 7 갱신).
///
/// - [masterGroups]: master scope 옵션 그룹 (read-only legacy 시드).
/// - [brandGroups]: brand scope 옵션 그룹 (brand 본사 CRUD — MasterMenuForm/BrandStoreOnlyMenuForm 에서 사용).
/// - [storeGroups]: store scope 옵션 그룹 (개인 매장 — OwnerStoreMenuForm 에서 사용).
/// - [selectedIds]: 현재 선택된 옵션 그룹 ID 목록.
/// - [onChanged]: 선택 변경 콜백.
/// - [disabledOptionItemIds]: 메뉴별 비활성 항목 compositeId 목록 (`'{groupId}_{itemId}'`).
/// - [onDisabledItemsChanged]: 항목 토글 시 변경된 목록 전달 콜백.
///
/// 섹션 헤더:
///   - master → '기본 옵션'
///   - brand  → '브랜드 옵션'
///   - store  → '매장 옵션'
///
/// inactive 그룹: 수정 모드에서 기존 선택된 inactive 그룹은 disabled 표시 (선택 해제만 가능).
/// 항목 토글 패널: 선택된(active) 그룹에만 노출. inactive 그룹은 미노출.
class OptionGroupSelector extends StatelessWidget {
  /// master scope 옵션 그룹 목록.
  final List<OptionGroupEntity> masterGroups;

  /// brand scope 옵션 그룹 목록.
  final List<OptionGroupEntity> brandGroups;

  /// store scope 옵션 그룹 목록.
  final List<OptionGroupEntity> storeGroups;

  /// 현재 선택된 옵션 그룹 ID 목록.
  final List<String> selectedIds;

  final ValueChanged<List<String>> onChanged;

  /// brandGroups 또는 storeGroups 빈 상태 CTA 진입 콜백 (선택적).
  final VoidCallback? onNavigateToBrandOptionGroups;
  final VoidCallback? onNavigateToStoreOptionGroups;

  /// 메뉴별 비활성 항목 compositeId 목록 (`'{groupId}_{itemId}'`).
  /// compositeId 가 목록에 없으면 ON(기본 활성).
  final List<String> disabledOptionItemIds;

  /// 항목 ON/OFF 토글 시 변경된 목록 전체를 전달하는 콜백.
  final ValueChanged<List<String>> onDisabledItemsChanged;

  const OptionGroupSelector({
    super.key,
    // legacy: optionGroups 파라미터로 전달 시 masterGroups 로 처리
    List<OptionGroupEntity> optionGroups = const [],
    this.brandGroups = const [],
    this.storeGroups = const [],
    // legacy: storeId 파라미터 (하위 호환용, 미사용)
    @Deprecated('storeId 는 더 이상 사용하지 않습니다.') String? storeId,
    required this.selectedIds,
    required this.onChanged,
    this.onNavigateToBrandOptionGroups,
    this.onNavigateToStoreOptionGroups,
    this.disabledOptionItemIds = const [],
    this.onDisabledItemsChanged = _noopDisabledItemsChanged,
  }) : masterGroups = optionGroups;

  static void _noopDisabledItemsChanged(List<String> _) {}

  void _toggle(String id, {required bool isInactiveUnselected}) {
    if (isInactiveUnselected) return; // inactive 이면서 미선택 → 재선택 불가
    final next = List<String>.from(selectedIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final hasBrand = brandGroups.isNotEmpty;
    final hasStore = storeGroups.isNotEmpty;
    final hasMaster = masterGroups.isNotEmpty;

    // master only (BrandMorePage 진입 전 레거시 동작)
    if (!hasBrand && !hasStore) {
      if (!hasMaster) {
        return _emptySection(
          scope: OptionScope.master,
          onNavigate: null,
        );
      }
      return _SectionBlock(
        header: _sectionHeader(OptionScope.master),
        child: _buildGroupList(masterGroups),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // master 섹션
        _SectionBlock(
          header: _sectionHeader(OptionScope.master),
          child: hasMaster
              ? _buildGroupList(masterGroups)
              : _emptySection(scope: OptionScope.master, onNavigate: null),
        ),
        const SizedBox(height: 8),

        // brand 섹션
        if (hasBrand || onNavigateToBrandOptionGroups != null) ...[
          _SectionBlock(
            header: _sectionHeader(OptionScope.brand),
            child: hasBrand
                ? _buildGroupList(brandGroups)
                : _emptySection(
                    scope: OptionScope.brand,
                    onNavigate: onNavigateToBrandOptionGroups,
                  ),
          ),
          const SizedBox(height: 8),
        ],

        // store 섹션
        if (hasStore || onNavigateToStoreOptionGroups != null)
          _SectionBlock(
            header: _sectionHeader(OptionScope.store),
            child: hasStore
                ? _buildGroupList(storeGroups)
                : _emptySection(
                    scope: OptionScope.store,
                    onNavigate: onNavigateToStoreOptionGroups,
                  ),
          ),
      ],
    );
  }

  Widget _sectionHeader(OptionScope scope) {
    final label = switch (scope) {
      OptionScope.master => '기본 옵션',
      OptionScope.brand => '브랜드 옵션',
      OptionScope.store => '매장 옵션',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6, left: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _emptySection({
    required OptionScope scope,
    VoidCallback? onNavigate,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '옵션 그룹이 없어요',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textBody,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '옵션 그룹 관리 화면에서 추가해보세요',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          if (onNavigate != null &&
              scope != OptionScope.master) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onNavigate,
              icon: const Icon(Icons.tune_rounded,
                  size: 14, color: AppColors.primaryBright),
              label: const Text(
                '옵션 그룹 관리',
                style: TextStyle(
                    fontSize: 12, color: AppColors.primaryBright),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupList(List<OptionGroupEntity> groups) {
    final hasInactiveSelected =
        groups.any((g) => !g.active && selectedIds.contains(g.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            final isSelected = selectedIds.contains(group.id);
            final isInactive = !group.active;
            // inactive 이면서 미선택: 재선택 불가
            final isInactiveUnselected = isInactive && !isSelected;

            if (isInactive) {
              return _InactiveGroupChip(
                group: group,
                isSelected: isSelected,
                onToggle: () =>
                    _toggle(group.id, isInactiveUnselected: isInactiveUnselected),
              );
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    value: isSelected,
                    onChanged: (_) =>
                        _toggle(group.id, isInactiveUnselected: false),
                    title: Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textBody,
                      ),
                    ),
                    subtitle: Builder(builder: (_) {
                      // 항목 OFF (disabledOptionItemIds 에 포함) 는 그룹 헤더
                      // 가격 표시에서도 제외 — 메뉴 폼 안 시각 일관성.
                      final activeItems = group.items.where((item) {
                        final compositeId = '${group.id}_${item.id}';
                        return !disabledOptionItemIds.contains(compositeId);
                      }).toList(growable: false);
                      if (activeItems.isEmpty) return const SizedBox.shrink();
                      return Wrap(
                        spacing: 4,
                        children: activeItems
                            .take(3)
                            .map((item) => PriceDeltaLabel(
                                  priceDelta: item.priceDelta,
                                ))
                            .toList(),
                      );
                    }),
                    activeColor: AppColors.primary,
                    checkColor: AppColors.onPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                  ),
                  // 선택된 active 그룹에만 항목 토글 패널 노출
                  if (isSelected)
                    _GroupItemTogglePanel(
                      group: group,
                      disabledOptionItemIds: disabledOptionItemIds,
                      onDisabledItemsChanged: onDisabledItemsChanged,
                    ),
                ],
              ),
            );
          },
        ),
        // inactive 그룹이 선택된 상태일 때 경고 라벨
        if (hasInactiveSelected)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: const [
                Icon(Icons.warning_amber_rounded,
                    size: 12, color: AppColors.warning),
                SizedBox(width: 4),
                Text(
                  '이 옵션 그룹은 비활성화되었습니다.',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.warning),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── 그룹 항목 토글 패널 ────────────────────────────────────────────────────

/// 선택된 active 그룹의 카드 하단에 노출되는 항목별 ON/OFF 토글 패널.
///
/// - 항목이 있으면 [_OptionItemToggleRow] 목록 렌더.
/// - 항목이 없으면 [_ItemEmptyState] 렌더.
class _GroupItemTogglePanel extends StatelessWidget {
  final OptionGroupEntity group;
  final List<String> disabledOptionItemIds;
  final ValueChanged<List<String>> onDisabledItemsChanged;

  const _GroupItemTogglePanel({
    required this.group,
    required this.disabledOptionItemIds,
    required this.onDisabledItemsChanged,
  });

  void _onItemToggle(String itemId, bool currentlyOn) {
    final compositeId = '${group.id}_$itemId';
    final next = List<String>.from(disabledOptionItemIds);
    if (currentlyOn) {
      // ON → OFF: compositeId 추가
      if (!next.contains(compositeId)) next.add(compositeId);
    } else {
      // OFF → ON: compositeId 제거
      next.remove(compositeId);
    }
    onDisabledItemsChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 체크박스 영역과 항목 영역 구분선
        const Divider(height: 1, thickness: 1, color: AppColors.border),
        // 패널 헤더
        const Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 4),
          child: Text(
            '이 메뉴에 제공할 항목 선택',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
        // 항목 목록 or 빈 상태
        if (group.items.isEmpty)
          const _ItemEmptyState()
        else
          ...() {
            final rows = <Widget>[];
            for (var i = 0; i < group.items.length; i++) {
              final item = group.items[i];
              final compositeId = '${group.id}_${item.id}';
              final isDisabled = disabledOptionItemIds.contains(compositeId);
              if (i > 0) {
                rows.add(const Divider(
                  height: 1,
                  color: AppColors.border,
                  indent: 16,
                  endIndent: 16,
                ));
              }
              rows.add(_OptionItemToggleRow(
                item: item,
                isDisabled: isDisabled,
                onToggle: (currentlyOn) => _onItemToggle(item.id, currentlyOn),
              ));
            }
            return rows;
          }(),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── 항목 1개 토글 row ─────────────────────────────────────────────────────

class _OptionItemToggleRow extends StatelessWidget {
  final OptionItemEntity item;
  final bool isDisabled;

  /// [currentlyOn] = Switch 가 ON → OFF 로 바뀔 때 true, OFF → ON 으로 바뀔 때 false.
  final ValueChanged<bool> onToggle;

  const _OptionItemToggleRow({
    required this.item,
    required this.isDisabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDisabled ? AppColors.textMuted : AppColors.textBody,
                    decoration: isDisabled
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: AppColors.textMuted,
                  ),
                ),
                if (item.priceDelta != 0) ...[
                  const SizedBox(height: 2),
                  PriceDeltaLabel(priceDelta: item.priceDelta),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: !isDisabled,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primaryBright.withValues(alpha: 0.3),
            inactiveThumbColor: AppColors.error,
            inactiveTrackColor: AppColors.error.withValues(alpha: 0.3),
            onChanged: (newValue) {
              // newValue = true → ON (현재 OFF → ON), false → OFF (현재 ON → OFF)
              // onToggle(currentlyOn): currentlyOn = !newValue (토글 전 상태가 ON)
              onToggle(!newValue);
            },
          ),
        ],
      ),
    );
  }
}

// ── 항목 0개 빈 상태 ──────────────────────────────────────────────────────

class _ItemEmptyState extends StatelessWidget {
  const _ItemEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          Icon(Icons.list_alt_outlined, size: 16, color: AppColors.textMuted),
          SizedBox(width: 8),
          Text(
            '이 그룹에 항목이 없어요',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── inactive 그룹 칩 ──────────────────────────────────────────────────────

class _InactiveGroupChip extends StatelessWidget {
  final OptionGroupEntity group;
  final bool isSelected;
  final VoidCallback onToggle;

  const _InactiveGroupChip({
    required this.group,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.7,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: CheckboxListTile(
          value: isSelected,
          // inactive 이면서 미선택 → 재선택 불가. 선택된 상태에서는 해제 가능.
          onChanged: isSelected ? (_) => onToggle() : null,
          title: Row(
            children: [
              Flexible(
                child: Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.warning,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  border: Border.all(
                      color:
                          AppColors.warning.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '비활성',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          activeColor: AppColors.warning,
          checkColor: AppColors.onPrimary,
          side: BorderSide(
              color: AppColors.warning.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 4),
        ),
      ),
    );
  }
}

// ── 섹션 블록 래퍼 ────────────────────────────────────────────────────────

class _SectionBlock extends StatelessWidget {
  final Widget header;
  final Widget child;

  const _SectionBlock({required this.header, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [header, child],
    );
  }
}
