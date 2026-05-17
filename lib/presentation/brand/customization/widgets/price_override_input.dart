import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 가격 오버라이드 입력 필드.
///
/// - [basePriceForPlaceholder]: TextField hint 에 `'₩{basePrice}'` 로 표시
/// - [initialValue]: 기존 override 수정 시 pre-fill
/// - [onChanged]: 입력 값 변화 시 콜백. 입력 없으면 null 전달.
class PriceOverrideInput extends StatefulWidget {
  final int basePriceForPlaceholder;
  final int? initialValue;
  final ValueChanged<int?> onChanged;

  const PriceOverrideInput({
    super.key,
    required this.basePriceForPlaceholder,
    this.initialValue,
    required this.onChanged,
  });

  @override
  State<PriceOverrideInput> createState() => _PriceOverrideInputState();
}

class _PriceOverrideInputState extends State<PriceOverrideInput> {
  late final TextEditingController _ctrl;
  int? _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
    _ctrl = TextEditingController(
      text: widget.initialValue != null ? widget.initialValue.toString() : '',
    );
    _ctrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _ctrl.text.trim();
    final parsed = int.tryParse(text);
    setState(() => _currentValue = parsed);
    widget.onChanged(parsed);
  }

  bool get _showPreview =>
      _currentValue != null &&
      _currentValue != widget.basePriceForPlaceholder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '변경할 가격',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textBody,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 16, color: AppColors.textBody),
          decoration: InputDecoration(
            hintText: '₩${widget.basePriceForPlaceholder}',
            hintStyle: const TextStyle(
              fontSize: 16,
              color: AppColors.textMuted,
            ),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 14, right: 8),
              child: Text(
                '₩',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textBody,
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            suffix: const Text(
              '원',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        if (_showPreview) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '₩${widget.basePriceForPlaceholder}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                '₩$_currentValue',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
