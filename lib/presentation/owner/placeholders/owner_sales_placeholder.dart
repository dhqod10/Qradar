import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

class OwnerSalesPlaceholder extends StatelessWidget {
  const OwnerSalesPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.bar_chart_rounded, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text(
              '매출',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '일별 / 월별 매출 지표가 이 자리에 들어옵니다.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
