import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/common/q_logo.dart';

class QoinPage extends StatelessWidget {
  const QoinPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderScreen(
      title: 'Qoin',
      icon: _QoinIcon(),
    );
  }
}

class _QoinIcon extends StatelessWidget {
  const _QoinIcon();

  @override
  Widget build(BuildContext context) {
    return const QLogo(size: 64);
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final Widget icon;
  const _PlaceholderScreen({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
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
            const Text(
              '준비 중입니다',
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
