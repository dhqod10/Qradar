import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// 점주 주문 액션 다이얼로그 모음.
///
/// [OwnerOrdersPage] 와 [OwnerOrderDetailPage] 양쪽에서 재사용한다.
/// 각 함수는 `BuildContext` 를 받아 `showDialog` 를 호출하고 결과를 반환한다.
abstract final class OwnerOrderActionDialogs {
  OwnerOrderActionDialogs._();

  /// 주문 거절 사유 다이얼로그.
  ///
  /// 반환값: 사유 문자열 (빈 문자열 포함). null 은 취소.
  static Future<String?> showRejectOrder(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '주문을 거절하시겠어요?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: '거절 사유 (선택 입력)',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textBody,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '아니요',
              style: TextStyle(color: AppColors.textBody),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('거절'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  /// 환불 승인 확인 다이얼로그.
  ///
  /// 반환값: true = 승인. null / false = 취소.
  static Future<bool?> showApproveRefund(
    BuildContext context, {
    required int totalPrice,
  }) async {
    final fmt = NumberFormat('#,###원', 'ko_KR');
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '환불을 승인하시겠어요?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        content: Text(
          '전액 ${fmt.format(totalPrice)}이 환불됩니다.',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textBody,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              '취소',
              style: TextStyle(color: AppColors.textBody),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('환불 승인'),
          ),
        ],
      ),
    );
  }

  /// 픽업 완료 확정 다이얼로그.
  ///
  /// 반환값: true = 확인. null / false = 취소.
  static Future<bool?> showCompletePickup(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '픽업 완료로 표시할까요?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        content: const Text(
          '주문이 완료 상태로 전환되며\n더 이상 수정할 수 없어요.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textBody,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              '취소',
              style: TextStyle(color: AppColors.textBody),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 환불 거절 사유 다이얼로그.
  ///
  /// 반환값: 사유 문자열 (빈 문자열 포함). null 은 취소.
  static Future<String?> showDenyRefund(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '환불 요청 거절',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: '거절 사유를 입력해주세요',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textBody,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '취소',
              style: TextStyle(color: AppColors.textBody),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('거절'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}
