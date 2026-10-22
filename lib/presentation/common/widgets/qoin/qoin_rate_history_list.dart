import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/qoin_rate_change_entity.dart';
import 'package:qradar/presentation/common/widgets/qoin/qoin_rate_history_tile.dart';

/// 이력 카드: 1차 원장 카드와 같은 모양 (`surfaceElevated` + `border` + radius 16, 헤어라인 구분).
class QoinRateHistoryList extends StatelessWidget {
  const QoinRateHistoryList({
    super.key,
    required this.items,
    required this.viewer,
    required this.now,
    this.onResume,
  });

  final List<QoinRateChangeEntity> items;
  final QoinHistoryViewer viewer;
  final DateTime now;
  final void Function(QoinRateChangeEntity change)? onResume;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 16, color: AppColors.border),
            QoinRateHistoryTile(
              key: ValueKey(items[i].id + items[i].targetId),
              change: items[i],
              viewer: viewer,
              now: now,
              onResume: onResume,
            ),
          ],
        ],
      ),
    );
  }
}

/// 이력 로딩 skeleton (카드 안 4행, `border` 색 정적 박스).
class QoinRateHistorySkeleton extends StatelessWidget {
  const QoinRateHistorySkeleton({super.key});

  Widget _box(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: AppColors.border,
      borderRadius: BorderRadius.circular(6),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 16, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.border,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [_box(160, 14), _box(80, 12)],
                        ),
                        const SizedBox(height: 8),
                        _box(90, 15),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
