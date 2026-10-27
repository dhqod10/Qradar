import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 메뉴 목록 카드 (design §3.5). **결제 실패 화면과 체크아웃 차단 시트가 같은 위젯을 쓴다.**
///
/// [names] 는 고객 카트의 `menuItemName` 이다 (서버 문자열이 아니다). 개수를 줄이지 않고 전부 열거한다 (D5).
/// 카드 내부 중첩 스크롤은 만들지 않는다 — 스크롤은 바깥 본문 영역의 몫이다.
class PaymentMenuListCard extends StatelessWidget {
  const PaymentMenuListCard({
    super.key,
    required this.header,
    required this.names,
    this.margin = const EdgeInsets.only(top: 16),
    this.icon = Icons.remove_circle_outline_rounded,
  });

  final String header;
  final List<String> names;
  final EdgeInsetsGeometry margin;

  /// 행 아이콘. 사유별로 다르다 (품절 계열: 기본, 가격: price_change_outlined, 옵션: tune_rounded).
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$header: ${names.join(', ')}',
      child: ExcludeSemantics(
        child: Container(
          margin: margin,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                header,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < names.length; i++) ...[
                if (i > 0)
                  const Divider(
                    color: AppColors.border,
                    height: 1,
                    thickness: 1,
                  ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Icon(icon, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            names[i],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHeading,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
