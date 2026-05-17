import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/customer/order/providers/order_providers.dart';

/// 매장명 검색 입력창. 250ms debounce 이후 [orderSearchQueryProvider] 갱신.
///
/// [onFocusChange] 는 지도 탭에서 바텀시트 자동 닫힘 등 외부 상태 연동에 사용.
class OrderSearchBar extends ConsumerStatefulWidget {
  final ValueChanged<bool>? onFocusChange;

  const OrderSearchBar({super.key, this.onFocusChange});

  @override
  ConsumerState<OrderSearchBar> createState() => _OrderSearchBarState();
}

class _OrderSearchBarState extends ConsumerState<OrderSearchBar> {
  static const Duration _debounce = Duration(milliseconds: 250);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  bool _hasText = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
      widget.onFocusChange?.call(_focusNode.hasFocus);
    }
  }

  void _onChanged(String value) {
    final nextHasText = value.isNotEmpty;
    if (nextHasText != _hasText) {
      setState(() => _hasText = nextHasText);
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      if (!mounted) return;
      ref.read(orderSearchQueryProvider.notifier).set(value);
    });
  }

  void _onClearTap() {
    _debounceTimer?.cancel();
    _controller.clear();
    setState(() => _hasText = false);
    ref.read(orderSearchQueryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _focused ? AppColors.primary : AppColors.border,
          width: _focused ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              cursorColor: AppColors.primary,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textBody,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '매장명을 검색하세요',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (_hasText)
            GestureDetector(
              onTap: _onClearTap,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
