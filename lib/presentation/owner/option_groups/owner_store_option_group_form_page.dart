import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/errors/duplicate_option_group_name_exception.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/option_group_entity.dart';
import 'package:qradar/domain/entities/option_item_entity.dart';
import 'package:qradar/domain/entities/option_scope.dart';
import 'package:qradar/domain/entities/option_selection_type.dart';
import 'package:qradar/presentation/brand/option_groups/providers/brand_option_group_providers.dart';
import 'package:qradar/presentation/common/widgets/option_groups/option_item_list_editor.dart';

/// 점주 개인 매장 옵션 그룹 등록 / 수정 통합 폼 페이지.
class OwnerStoreOptionGroupFormPage extends ConsumerStatefulWidget {
  final String storeId;
  final OptionGroupEntity? editItem;

  const OwnerStoreOptionGroupFormPage({
    super.key,
    required this.storeId,
    this.editItem,
  });

  @override
  ConsumerState<OwnerStoreOptionGroupFormPage> createState() =>
      _OwnerStoreOptionGroupFormPageState();
}

class _OwnerStoreOptionGroupFormPageState
    extends ConsumerState<OwnerStoreOptionGroupFormPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _orderCtrl;

  OptionSelectionType _selectionType = OptionSelectionType.single;
  bool _required = false;
  bool _active = true;
  bool _isSaving = false;
  bool _isDuplicateChecking = false;

  String? _nameError;
  String? _nameSuccess;
  Timer? _debounce;

  List<OptionItemEntity> _items = [];
  bool _hasItemLabelDuplicate = false;

  bool get _isEditMode => widget.editItem != null;

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty &&
      _nameError == null &&
      !_isSaving &&
      !_isDuplicateChecking &&
      !_hasItemLabelDuplicate;

  @override
  void initState() {
    super.initState();
    final e = widget.editItem;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _orderCtrl =
        TextEditingController(text: e?.displayOrder.toString() ?? '0');
    _selectionType = e?.selectionType ?? OptionSelectionType.single;
    _required = e?.required ?? false;
    _active = e?.active ?? true;
    _items = List<OptionItemEntity>.from(e?.items ?? []);

    _nameCtrl.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    setState(() {
      _nameError = null;
      _nameSuccess = null;
      _isDuplicateChecking = true;
    });
    _debounce?.cancel();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _isDuplicateChecking = false);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final isDuplicate =
          await ref.read(findDuplicateOptionGroupNameUseCaseProvider).call(
                name: name,
                scope: OptionScope.store,
                storeId: widget.storeId,
                excludeId: _isEditMode ? widget.editItem!.id : null,
              );
      if (!mounted) return;
      setState(() {
        _nameError =
            isDuplicate ? '이미 같은 이름의 옵션 그룹이 있어요' : null;
        _nameSuccess = isDuplicate ? null : '사용 가능한 이름이에요';
        _isDuplicateChecking = false;
      });
    });
  }

  void _onItemsChanged(List<OptionItemEntity> items) {
    final labels = items
        .map((e) => e.label.trim().toLowerCase())
        .where((l) => l.isNotEmpty)
        .toList();
    final hasDup = labels.length != labels.toSet().length;
    setState(() {
      _items = items;
      _hasItemLabelDuplicate = hasDup;
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);
    try {
      final entity = OptionGroupEntity(
        id: _isEditMode ? widget.editItem!.id : '',
        scope: OptionScope.store,
        storeId: widget.storeId,
        name: _nameCtrl.text.trim(),
        selectionType: _selectionType,
        required: _required,
        active: _active,
        displayOrder: int.tryParse(_orderCtrl.text.trim()) ?? 0,
        items: _items,
      );
      await ref.read(upsertOptionGroupUseCaseProvider).call(entity);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _isEditMode ? '옵션 그룹을 수정했어요' : '옵션 그룹을 추가했어요'),
        ),
      );
      Navigator.of(context).pop();
    } on DuplicateOptionGroupNameException {
      if (!mounted) return;
      setState(
          () => _nameError = '이미 같은 이름의 옵션 그룹이 있어요. 다른 이름을 사용해주세요');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('처리에 실패했어요. 다시 시도해주세요')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textBody),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEditMode ? '옵션 그룹 수정' : '옵션 그룹 추가'),
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textHeading,
        ),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이름
            _FormSection(
              label: '옵션 그룹 이름',
              child: _NameField(
                controller: _nameCtrl,
                errorText: _nameError,
                successText: _nameSuccess,
                isChecking: _isDuplicateChecking,
              ),
            ),
            const SizedBox(height: 20),

            // 선택 타입
            _FormSection(
              label: '선택 타입',
              child: _SelectionTypeChips(
                selected: _selectionType,
                onSelect: (t) => setState(() => _selectionType = t),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '단일: 하나만 선택 (라디오) / 다중: 여러 개 선택 가능 (체크박스)',
              style:
                  TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),

            // 필수 여부
            _SwitchRow(
              title: '필수 옵션',
              subtitle: '고객이 반드시 선택해야 주문 가능해요',
              value: _required,
              onChanged: (v) => setState(() => _required = v),
            ),
            const SizedBox(height: 20),

            // 정렬 순서
            _FormSection(
              label: '정렬 순서',
              child: _OrderField(controller: _orderCtrl),
            ),
            const SizedBox(height: 20),

            // 활성화
            _SwitchRow(
              title: '활성화',
              subtitle: '비활성화 시 메뉴 폼과 고객 화면에서 숨겨져요',
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 20),

            // 옵션 항목
            _FormSection(
              label: '옵션 항목',
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: OptionItemListEditor(
                  initialItems: _items,
                  onChanged: _onItemsChanged,
                ),
              ),
            ),
            if (_hasItemLabelDuplicate) ...[
              const SizedBox(height: 4),
              const Text(
                '같은 이름의 항목이 있어요. 확인 후 다시 저장해주세요',
                style:
                    TextStyle(fontSize: 11, color: AppColors.error),
              ),
            ],
            const SizedBox(height: 32),

            // 버튼 Row
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        side:
                            const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textBody,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _canSave ? _save : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canSave
                            ? AppColors.primary
                            : AppColors.surface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : Text(
                              '저장',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _canSave
                                    ? AppColors.onPrimary
                                    : AppColors.textMuted,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── 이름 필드 ─────────────────────────────────────────────────────────────

class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;
  final String? successText;
  final bool isChecking;

  const _NameField({
    required this.controller,
    this.errorText,
    this.successText,
    required this.isChecking,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          maxLength: 30,
          style: const TextStyle(fontSize: 15, color: AppColors.textBody),
          decoration: InputDecoration(
            hintText: '예: 샷 추가, 시럽 선택, 사이즈',
            hintStyle: const TextStyle(
                fontSize: 15, color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            errorText: errorText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            errorStyle:
                const TextStyle(fontSize: 11, color: AppColors.error),
            counterStyle: const TextStyle(
                fontSize: 11, color: AppColors.textMuted),
          ),
        ),
        if (isChecking)
          const Padding(
            padding: EdgeInsets.only(top: 4, left: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
                SizedBox(width: 6),
                Text(
                  '확인 중...',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          )
        else if (successText != null && errorText == null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              successText!,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.success),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 4, left: 2),
            child: Text(
              '최대 30자',
              style: TextStyle(
                  fontSize: 11, color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }
}

// ── 선택 타입 칩 ─────────────────────────────────────────────────────────

class _SelectionTypeChips extends StatelessWidget {
  final OptionSelectionType selected;
  final ValueChanged<OptionSelectionType> onSelect;

  const _SelectionTypeChips({
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TypeChip(
          label: '단일 선택',
          icon: selected == OptionSelectionType.single
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_unchecked_rounded,
          isSelected: selected == OptionSelectionType.single,
          onTap: () => onSelect(OptionSelectionType.single),
        ),
        const SizedBox(width: 8),
        _TypeChip(
          label: '다중 선택',
          icon: selected == OptionSelectionType.multi
              ? Icons.check_box_rounded
              : Icons.check_box_outline_blank_rounded,
          isSelected: selected == OptionSelectionType.multi,
          onTap: () => onSelect(OptionSelectionType.multi),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? null
              : Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppColors.onPrimary
                  : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected
                    ? FontWeight.w600
                    : FontWeight.w500,
                color: isSelected
                    ? AppColors.onPrimary
                    : AppColors.textBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 정렬 순서 필드 ────────────────────────────────────────────────────────

class _OrderField extends StatelessWidget {
  final TextEditingController controller;
  const _OrderField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
              fontSize: 15, color: AppColors.textBody),
          decoration: InputDecoration(
            hintText: '0, 1, 2 ...',
            hintStyle: const TextStyle(
                fontSize: 15, color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '숫자가 낮을수록 앞에 표시돼요',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

// ── Switch Row ────────────────────────────────────────────────────────────

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textBody,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        Switch.adaptive(
          value: value,
          activeThumbColor: AppColors.primary,
          activeTrackColor:
              AppColors.primaryBright.withValues(alpha: 0.3),
          inactiveThumbColor: AppColors.textMuted,
          inactiveTrackColor: AppColors.surface,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ── FormSection ───────────────────────────────────────────────────────────

class _FormSection extends StatelessWidget {
  final String label;
  final Widget child;

  const _FormSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
