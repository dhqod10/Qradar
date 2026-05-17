import 'package:flutter/material.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/customer/order/orders/order_detail_page.dart';

enum PaymentResultVariant { success, fail, cancelled }

class PaymentResultPage extends StatelessWidget {
  const PaymentResultPage({
    super.key,
    required this.variant,
    this.orderId,
    this.errorCode,
    this.errorMessage,
  });

  final PaymentResultVariant variant;
  final String? orderId;
  final String? errorCode;
  final String? errorMessage;

  static String _mapErrorCode(String? code, String? message) {
    switch (code) {
      case 'USER_CANCEL':
        return '사용자가 결제를 취소했습니다';
      case 'PAY_PROCESS_CANCELED':
        return '결제가 취소되었습니다';
      case 'PAY_PROCESS_ABORTED':
        return '결제가 중단되었습니다';
      case 'REJECT_CARD_COMPANY':
        return '카드사 승인 거절. 다른 결제수단을 이용해주세요';
      case 'INVALID_CARD':
        return '유효하지 않은 카드입니다';
      case 'NOT_ENOUGH_BALANCE':
        return '잔액이 부족합니다';
      case 'INVALID_CARD_EXPIRATION':
        return '카드 유효기간이 올바르지 않아요';
      case 'EXCEED_MAX_CARD_INSTALLMENT_PLAN':
        return '할부 한도를 초과했어요';
      case 'INVALID_STOPPED_CARD':
        return '정지된 카드예요';
      case 'EXCEED_MAX_DAILY_PAYMENT_AMOUNT':
        return '하루 결제 한도를 초과했어요';
      case 'NOT_SUPPORTED_INSTALLMENT_PLAN_CARD_OR_MERCHANT':
        return '이 카드는 할부가 지원되지 않아요';
      default:
        if (code != null && message != null) {
          return '$message (코드: $code)';
        }
        return message ?? '결제에 실패했어요';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: switch (variant) {
            PaymentResultVariant.success => _SuccessBody(orderId: orderId),
            PaymentResultVariant.fail => _FailBody(
                message: _mapErrorCode(errorCode, errorMessage),
              ),
            PaymentResultVariant.cancelled => const _CancelledBody(),
          },
        ),
      ),
    );
  }
}

// ── Success ───────────────────────────────────────────────────────────────────

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({this.orderId});
  final String? orderId;

  String get _shortId {
    final id = orderId ?? '';
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 60),
          const Icon(
            Icons.check_circle_rounded,
            size: 80,
            color: AppColors.success,
          ),
          const SizedBox(height: 20),
          const Text(
            '결제가 완료되었어요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '주문번호',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            _shortId,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textBody,
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                final id = orderId;
                if (id == null || id.isEmpty) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => OrderDetailPage(orderId: id),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                '주문 상세 보기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 54,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textBody,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Log 로 이동',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Fail ─────────────────────────────────────────────────────────────────────

class _FailBody extends StatelessWidget {
  const _FailBody({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 60),
          const Icon(
            Icons.cancel_rounded,
            size: 80,
            color: AppColors.error,
          ),
          const SizedBox(height: 20),
          const Text(
            '결제에 실패했어요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                '다시 시도',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 54,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textBody,
                backgroundColor: AppColors.surfaceElevated,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                '결제 수단 변경',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '닫기',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Cancelled ─────────────────────────────────────────────────────────────────

class _CancelledBody extends StatelessWidget {
  const _CancelledBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 60),
          const Icon(
            Icons.info_rounded,
            size: 80,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 20),
          const Text(
            '결제가 취소되었어요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '결제를 다시 시도하시려면 카트로 돌아가주세요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const Spacer(),
          SizedBox(
            height: 54,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textBody,
                backgroundColor: AppColors.surfaceElevated,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                '닫기 (카트로 돌아가기)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
