import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';

class OwnerOrdersPlaceholder extends StatelessWidget {
  const OwnerOrdersPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const _OwnerPlaceholder(
      icon: Icons.receipt_long_rounded,
      title: '주문 접수',
      message: '곧 고객 주문을 이곳에서 받게 될 거예요.',
    );
  }
}

class _OwnerPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _OwnerPlaceholder({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(
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
