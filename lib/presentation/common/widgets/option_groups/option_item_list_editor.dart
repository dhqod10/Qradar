import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/option_item_entity.dart';

/// 옵션 그룹 폼 내 항목 동적 추가/삭제/편집 위젯.
///
/// - 항목 0개: 빈 상태 + '+ 항목 추가' 버튼
/// - 각 항목: label 입력 + priceDelta (부호 토글 + 절댓값 숫자) + 삭제
/// - label 중복(같은 그룹 내 normalized): inline 에러 표시
/// - drag-drop reordering: Follow-up F3 (비범위)
class OptionItemListEditor extends StatefulWidget {
  final List<OptionItemEntity> initialItems;
  final ValueChanged<List<OptionItemEntity>> onChanged;

  const OptionItemListEditor({
    super.key,
    required this.initialItems,
    required this.onChanged,
  });

  @override
  State<OptionItemListEditor> createState() => _OptionItemListEditorState();
}

class _OptionItemListEditorState extends State<OptionItemListEditor> {
  late List<_ItemState> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.initialItems
        .map((e) => _ItemState.fromEntity(e))
        .toList();
  }

  void _addItem() {
    setState(() {
      _items.add(_ItemState.empty());
    });
    _notify();
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
    _notify();
  }

  void _notify() {
    final result = _items
        .map((s) => OptionItemEntity(
              id: s.id,
              label: s.labelCtrl.text.trim(),
              priceDelta: s.priceDelta,
            ))
        .toList();
    widget.onChanged(result);
  }

  /// 같은 그룹 내 label 중복 여부 (normalized).
  bool _isDuplicateLabel(int selfIndex) {
    final selfLabel =
        _items[selfIndex].labelCtrl.text.trim().toLowerCase();
    if (selfLabel.isEmpty) return false;
    for (var i = 0; i < _items.length; i++) {
      if (i == selfIndex) continue;
      final other = _items[i].labelCtrl.text.trim().toLowerCase();
      if (other == selfLabel) return true;
    }
    return false;
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.labelCtrl.dispose();
      item.priceCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_items.isEmpty) const _EmptyState(),
        for (var i = 0; i < _items.length; i++) ...[
          _OptionItemRow(
            key: ValueKey(_items[i].id),
            itemState: _items[i],
            isDuplicate: _isDuplicateLabel(i),
            onChanged: () {
              setState(() {});
              _notify();
            },
            onRemove: () => _removeItem(i),
          ),
          if (i < _items.length - 1)
            const Divider(height: 1, color: AppColors.border),
        ],
        const SizedBox(height: 8),
        _AddItemButton(onTap: _addItem),
      ],
    );
  }
}

// ── 빈 상태 ──────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.list_alt_rounded, size: 32, color: AppColors.textMuted),
          SizedBox(height: 8),
          Text(
            '아직 옵션 항목이 없어요',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── 항목 1행 ─────────────────────────────────────────────────────────────────

class _OptionItemRow extends StatefulWidget {
  final _ItemState itemState;
  final bool isDuplicate;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _OptionItemRow({
    super.key,
    required this.itemState,
    required this.isDuplicate,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_OptionItemRow> createState() => _OptionItemRowState();
}

class _OptionItemRowState extends State<_OptionItemRow> {
  late FocusNode _labelFocus;

  @override
  void initState() {
    super.initState();
    _labelFocus = FocusNode();
    // 새 항목(id 기반 empty) 이면 자동 포커스
    if (widget.itemState.isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _labelFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _labelFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDup = widget.isDuplicate;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // label 입력창
              Expanded(
                flex: 3,
                child: TextField(
                  controller: widget.itemState.labelCtrl,
                  focusNode: _labelFocus,
                  maxLength: 20,
                  onChanged: (_) => widget.onChanged(),
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textBody),
                  decoration: InputDecoration(
                    hintText: '항목 이름',
                    hintStyle: const TextStyle(
                        fontSize: 14, color: AppColors.textMuted),
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDup ? AppColors.error : AppColors.border,
                        width: isDup ? 1.5 : 1.0,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDup ? AppColors.error : AppColors.border,
                        width: isDup ? 1.5 : 1.0,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDup ? AppColors.error : AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                    suffixIcon: isDup
                        ? const Icon(Icons.error_outline_rounded,
                            size: 14, color: AppColors.error)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // priceDelta 입력
              _PriceDeltaField(
                itemState: widget.itemState,
                onChanged: widget.onChanged,
              ),
              const SizedBox(width: 4),
              // 삭제 버튼
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: AppColors.error.withValues(alpha: 0.7),
                ),
                onPressed: widget.onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          if (isDup)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 2),
              child: Text(
                '같은 이름의 항목이 있어요',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.error),
              ),
            ),
        ],
      ),
    );
  }
}

// ── priceDelta 입력 영역 ───────────────────────────────────────────────────

class _PriceDeltaField extends StatefulWidget {
  final _ItemState itemState;
  final VoidCallback onChanged;

  const _PriceDeltaField({
    required this.itemState,
    required this.onChanged,
  });

  @override
  State<_PriceDeltaField> createState() => _PriceDeltaFieldState();
}

class _PriceDeltaFieldState extends State<_PriceDeltaField> {
  void _toggleSign() {
    setState(() {
      widget.itemState.isNegative = !widget.itemState.isNegative;
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isNeg = widget.itemState.isNegative;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 부호 토글 버튼
        GestureDetector(
          onTap: _toggleSign,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isNeg
                  ? AppColors.error.withValues(alpha: 0.12)
                  : AppColors.success.withValues(alpha: 0.12),
              border: Border.all(
                color: isNeg
                    ? AppColors.error.withValues(alpha: 0.5)
                    : AppColors.success.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              isNeg ? '-' : '+',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isNeg ? AppColors.error : AppColors.success,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // 절댓값 숫자 입력
        SizedBox(
          width: 72,
          child: TextField(
            controller: widget.itemState.priceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => widget.onChanged(),
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontSize: 14, color: AppColors.textBody),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: const TextStyle(
                  fontSize: 14, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surfaceElevated,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          '원',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted),
        ),
      ],
    );
  }
}

// ── '+ 항목 추가' 버튼 ──────────────────────────────────────────────────────

class _AddItemButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddItemButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add_circle_outline_rounded,
          size: 16, color: AppColors.primary),
      label: const Text(
        '항목 추가',
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.primary),
      ),
      style: TextButton.styleFrom(
        backgroundColor: AppColors.primary.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }
}

// ── 내부 상태 모델 ────────────────────────────────────────────────────────────

class _ItemState {
  final String id;
  final TextEditingController labelCtrl;
  final TextEditingController priceCtrl;
  bool isNegative;
  final bool isNew;

  _ItemState({
    required this.id,
    required this.labelCtrl,
    required this.priceCtrl,
    required this.isNegative,
    this.isNew = false,
  });

  factory _ItemState.fromEntity(OptionItemEntity entity) {
    final absValue = entity.priceDelta.abs();
    return _ItemState(
      id: entity.id,
      labelCtrl: TextEditingController(text: entity.label),
      priceCtrl: TextEditingController(
          text: absValue == 0 ? '' : absValue.toString()),
      isNegative: entity.priceDelta < 0,
      isNew: false,
    );
  }

  factory _ItemState.empty() {
    return _ItemState(
      id: 'new_${DateTime.now().millisecondsSinceEpoch}',
      labelCtrl: TextEditingController(),
      priceCtrl: TextEditingController(),
      isNegative: false,
      isNew: true,
    );
  }

  /// 저장값 = 부호 × 절댓값. 0원이면 항상 0.
  int get priceDelta {
    final abs = int.tryParse(priceCtrl.text.trim()) ?? 0;
    if (abs == 0) return 0;
    return isNegative ? -abs : abs;
  }
}

// ── priceDelta 표시 위젯 (목록/selector 재사용) ───────────────────────────────

class PriceDeltaLabel extends StatelessWidget {
  final int priceDelta;

  const PriceDeltaLabel({super.key, required this.priceDelta});

  @override
  Widget build(BuildContext context) {
    if (priceDelta == 0) {
      return const Text(
        '0원',
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted),
      );
    }
    final isNeg = priceDelta < 0;
    return Text(
      '${isNeg ? '-' : '+'}${priceDelta.abs()}원',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isNeg ? AppColors.error : AppColors.success,
      ),
    );
  }
}
