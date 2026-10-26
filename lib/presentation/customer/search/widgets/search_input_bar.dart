import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:qradar/core/theme/app_colors.dart';

/// 검색 입력창 (46h pill). 힌트는 홈 박스와 글자 그대로 같다.
/// debounce 는 호출 측(페이지)이 맡고, `×` 와 제출은 debounce 를 기다리지 않는다.
class SearchInputBar extends StatelessWidget {
  const SearchInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmitted;

  static const String hint = '매장이나 메뉴 검색';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: hint,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Focus(
          // 포커스 테두리: 자식 TextField 포커스를 따라 primary 1.5px.
          child: ListenableBuilder(
            listenable: Listenable.merge([focusNode, controller]),
            builder: (context, _) {
              final focused = focusNode.hasFocus;
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: focused
                      ? Border.all(color: AppColors.primary, width: 1.5)
                      : null,
                ),
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        autofocus: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        maxLength: 40,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        textInputAction: TextInputAction.search,
                        cursorColor: AppColors.primary,
                        onChanged: onChanged,
                        onSubmitted: onSubmitted,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textBody,
                        ),
                        decoration: const InputDecoration(
                          hintText: hint,
                          hintStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                          counterText: '',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (controller.text.isNotEmpty)
                      Semantics(
                        button: true,
                        label: '질의 지우기',
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: onClear,
                          behavior: HitTestBehavior.opaque,
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 16),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
