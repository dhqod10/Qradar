import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/domain/entities/order_entity.dart';
import 'package:qradar/domain/entities/order_status.dart';
import 'package:qradar/presentation/common/order_status_badge.dart';

/// 조리 중 (making / ready) 주문 카드 타일.
///
/// [onAction] 은 status 에 따라 다른 동작:
///   - making → "준비 완료" 버튼 (outlined primary)
///   - ready  → "픽업 완료" 버튼 (filled primary, 다이얼로그 포함)
///
/// [onTapDetail] 이 null 이 아니면 카드 탭 시 상세 페이지로 이동한다.
/// Q7 정책: making/ready 에서 환불 요청 자체가 차단되므로 환불 배지 없음.
class OwnerInProgressOrderTile extends StatelessWidget {
  const OwnerInProgressOrderTile({
    super.key,
    required this.order,
    required this.onAction,
    this.isLoading = false,
    this.onTapDetail,
  });

  final OrderEntity order;

  /// making → _markReady, ready → _completePickupWithDialog
  final VoidCallback onAction;
  final bool isLoading;

  /// 카드 전체 탭 콜백 (버튼 영역 제외). null 이면 탭 비활성.
  final VoidCallback? onTapDetail;

  static final _fmt = NumberFormat('#,###원', 'ko_KR');
  static final _timeFmt = DateFormat('MM/dd HH:mm');

  @override
  Widget build(BuildContext context) {
    final itemSummary = _buildItemSummary();

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTapDetail,
        splashColor: AppColors.primary.withValues(alpha: 0.04),
        highlightColor: AppColors.primary.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 행 1: 시간 + status 배지
              Row(
                children: [
                  Text(
                    _timeFmt.format(order.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  OrderStatusBadge(
                    status: order.status,
                    size: OrderStatusBadgeSize.small,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 행 2: 메뉴 요약
              Text(
                itemSummary,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textBody,
                ),
              ),
              const SizedBox(height: 4),
              // 행 3: 총액
              Text(
                _fmt.format(order.totalPrice),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHeading,
                ),
              ),
              // 행 4: 진행 시간 (makingStartedAt 있을 때)
              if (order.makingStartedAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  _elapsedLabel(order.makingStartedAt!),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // 행 5: 액션 버튼 (full width, status 별 분기)
              _buildActionButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (order.status == OrderStatus.accepted) {
      // accepted → "조리 시작" (outlined primary, 동일 톤)
      return SizedBox(
        width: double.infinity,
        height: 40,
        child: OutlinedButton(
          onPressed: isLoading ? null : onAction,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            backgroundColor: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : const Text(
                  '조리 시작',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      );
    }

    final isMaking = order.status == OrderStatus.making;

    if (isMaking) {
      // making → "준비 완료" (outlined primary)
      return SizedBox(
        width: double.infinity,
        height: 40,
        child: OutlinedButton(
          onPressed: isLoading ? null : onAction,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            backgroundColor: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : const Text(
                  '준비 완료',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      );
    } else {
      // ready → "픽업 완료" (filled primary)
      return SizedBox(
        width: double.infinity,
        height: 40,
        child: ElevatedButton(
          onPressed: isLoading ? null : onAction,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            disabledBackgroundColor: AppColors.surface,
            disabledForegroundColor: AppColors.textMuted,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                )
              : const Text(
                  '픽업 완료',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      );
    }
  }

  String _buildItemSummary() {
    if (order.items.isEmpty) return '항목 없음';
    final first = order.items.first.menuItemName;
    if (order.items.length == 1) return first;
    return '$first 외 ${order.items.length - 1}개';
  }

  /// makingStartedAt 기준 경과 시간 레이블.
  static String _elapsedLabel(DateTime makingStartedAt) {
    final diff = DateTime.now().difference(makingStartedAt);
    if (diff.inMinutes < 1) return '방금 조리 시작';
    if (diff.inMinutes < 60) return '조리 시작 ${diff.inMinutes}분 전';
    return '조리 시작 1시간 이상 전';
  }
}
