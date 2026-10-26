import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 최근 검색어 (세션 메모리). 목록이 비면 호출 측이 [SearchInitialHint] 를 쓴다.
class RecentSearchList extends StatelessWidget {
  const RecentSearchList({
    super.key,
    required this.items,
    required this.onTap,
    required this.onRemove,
    required this.onClear,
  });

  final List<String> items;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Semantics(
              header: true,
              child: const Text(
                '최근 검색어',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHeading,
                ),
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: onClear,
              child: const SizedBox(
                height: 44,
                child: Center(
                  child: Text(
                    '전체 삭제',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.info,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const Text(
          '앱을 닫으면 지워져요',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        for (final text in items)
          InkWell(
            onTap: () => onTap(text),
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textBody,
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: '$text 삭제',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => onRemove(text),
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
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 질의 0글자 + 최근 검색어 없음 — 중앙 안내.
class SearchInitialHint extends StatelessWidget {
  const SearchInitialHint({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 64),
      child: Column(
        children: [
          Icon(Icons.search_rounded, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            '매장 이름, 주소, 메뉴로 찾아보세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textHeading,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '두 글자 이상 입력하면 메뉴도 찾아요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
