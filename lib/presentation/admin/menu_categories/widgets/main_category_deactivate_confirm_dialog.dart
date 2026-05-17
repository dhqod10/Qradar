import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/main_category_entity.dart';
import 'package:qradar/presentation/customer/order/store/providers/main_category_providers.dart';

/// 메인 카테고리 비활성화 확인 다이얼로그 (4d Lite).
///
/// admin 이 카테고리 active Switch 를 true→false 로 전환할 때 표시.
/// 영향 데이터(매장 수 N, 메뉴 수 M)를 fetch 해서 경고와 함께 보여준다.
///
/// 반환값: `true` = 비활성화 확인, `null`/`false` = 취소 (switch 원상복구 책임은 호출부).
class MainCategoryDeactivateConfirmDialog extends ConsumerWidget {
  final MainCategoryEntity entity;

  const MainCategoryDeactivateConfirmDialog({super.key, required this.entity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync =
        ref.watch(mainCategoryDetailedUsageProvider(entity.id));

    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 24, color: AppColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '카테고리 비활성화',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textHeading,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entity.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 영향 데이터 영역
            usageAsync.when(
              loading: () => Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '영향 범위를 계산하고 있어요...',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              error: (_, _) => Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(16),
                child: const Text(
                  '영향 범위를 확인하지 못했어요. 계속 진행하면 영향이 있을 수 있어요.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
              data: (usage) {
                final hasImpact =
                    usage.storeCount > 0 || usage.menuCount > 0;
                if (!hasImpact) {
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 16, color: AppColors.success),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '현재 이 카테고리를 사용 중인 메뉴나 매장이 없어요.',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '비활성화하면 영향을 받아요',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _ImpactItem(
                            icon: Icons.store_rounded,
                            label: '매장',
                            count: usage.storeCount,
                            unit: '곳',
                          ),
                          const SizedBox(width: 24),
                          _ImpactItem(
                            icon: Icons.restaurant_menu_rounded,
                            label: '메뉴',
                            count: usage.menuCount,
                            unit: '개',
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // 안내 문구
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '비활성화하면:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                _BulletText('고객 화면의 카테고리 탭에서 숨겨져요'),
                const SizedBox(height: 4),
                _BulletText('메뉴 폼에서 이 카테고리에 속한 메뉴에 경고가 표시돼요'),
              ],
            ),
            const SizedBox(height: 20),

            // 버튼 Row
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textBody,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      // loading 중(fetch 완료 전)에는 비활성화
                      onPressed: usageAsync.isLoading
                          ? null
                          : () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: usageAsync.isLoading
                            ? AppColors.textMuted
                            : AppColors.warning,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        '비활성화',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImpactItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final String unit;

  const _ImpactItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.warning),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '$count$unit',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
      ],
    );
  }
}

class _BulletText extends StatelessWidget {
  final String text;

  const _BulletText(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}
