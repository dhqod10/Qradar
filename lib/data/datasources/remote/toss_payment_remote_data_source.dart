// ignore_for_file: depend_on_referenced_packages
//
// Toss 결제 SDK 어댑터.
// 패키지: tosspayments_widget_sdk_flutter ^2.2.0
//
// 선정 근거:
//   - pub.dev 공식 토스페이먼츠 Flutter SDK (토스 공식 계정 게시).
//   - Widget 기반 결제 UI — 카드·카카오페이 모두 단일 API 로 처리.
//   - 구버전 tosspayments_payment_sdk (WebView 레거시) 대비 최신 권장 패키지.
//   - 한국 카페 앱 + 카드 + 카카오페이 표준 사용 사례에 가장 적합.
//
// Toss client key: --dart-define=TOSS_CLIENT_KEY=test_ck_xxx 로 주입.
// 절대 코드 하드코딩 금지.

import 'package:flutter/material.dart';
import 'package:tosspayments_widget_sdk_flutter/model/payment_info.dart';
import 'package:tosspayments_widget_sdk_flutter/model/payment_widget_options.dart';
import 'package:tosspayments_widget_sdk_flutter/model/tosspayments_result.dart';
import 'package:tosspayments_widget_sdk_flutter/payment_widget.dart';
import 'package:tosspayments_widget_sdk_flutter/widgets/agreement.dart';
import 'package:tosspayments_widget_sdk_flutter/widgets/payment_method.dart';
import 'package:qradar/core/theme/app_colors.dart';

/// Toss 결제 어댑터 결과 sealed class.
///
/// [TossPaymentSuccess] — 결제창 완료(SDK success callback).
/// [TossPaymentFailure] — 결제창 실패(SDK fail callback).
/// [TossPaymentCancelled] — 사용자가 결제창을 닫음.
sealed class TossPaymentResult {
  const TossPaymentResult();
}

class TossPaymentSuccess extends TossPaymentResult {
  final String paymentKey;
  final String orderId;
  final int amount;

  const TossPaymentSuccess({
    required this.paymentKey,
    required this.orderId,
    required this.amount,
  });
}

class TossPaymentFailure extends TossPaymentResult {
  final String code;
  final String message;

  const TossPaymentFailure({required this.code, required this.message});
}

class TossPaymentCancelled extends TossPaymentResult {
  const TossPaymentCancelled();
}

/// Toss 결제 SDK 어댑터.
///
/// SDK 결제창 실행 + 결과(success / failure / cancelled) 반환.
/// [requestPayment] 호출 시 별도 결제 페이지를 push 하고 결과를 반환한다.
///
/// **SDK 직접 사용은 본 파일에서만**. (Clean Architecture 절대 규칙)
class TossPaymentRemoteDataSource {
  static const String _clientKey = String.fromEnvironment(
    'TOSS_CLIENT_KEY',
    defaultValue: 'test_ck_placeholder',
  );

  /// Toss 결제창 실행.
  ///
  /// [context] — 결제 페이지를 push 하기 위해 필요한 BuildContext.
  /// [method] — 'CARD' | 'KAKAO_PAY' 등 Toss SDK PaymentMethod 문자열 (미사용 — SDK 가 위젯에서 선택하게 함).
  /// [idempotencyKey] — uuid v4. Toss orderId 로 전달.
  /// [amount] — 결제 금액 (원).
  /// [orderName] — 주문명 (예: "아메리카노 외 2건").
  /// [customerEmail] — 고객 이메일.
  /// [customerName] — 고객 이름.
  Future<TossPaymentResult> requestPayment({
    required BuildContext context,
    required String method,
    required String idempotencyKey,
    required int amount,
    required String orderName,
    required String customerEmail,
    required String customerName,
  }) async {
    final prefix = _clientKey.length >= 12 ? _clientKey.substring(0, 12) : _clientKey;
    final suffix = _clientKey.length >= 4 ? _clientKey.substring(_clientKey.length - 4) : '';
    // ignore: avoid_print
    print('[DIAG] TOSS_CLIENT_KEY in build: $prefix...$suffix (length: ${_clientKey.length})');
    return _requestPaymentImpl(
      context: context,
      method: method,
      idempotencyKey: idempotencyKey,
      amount: amount,
      orderName: orderName,
      customerEmail: customerEmail,
      customerName: customerName,
    );
  }

  Future<TossPaymentResult> _requestPaymentImpl({
    required BuildContext context,
    required String method,
    required String idempotencyKey,
    required int amount,
    required String orderName,
    required String customerEmail,
    required String customerName,
  }) async {
    try {
      final result = await Navigator.of(context).push<Result?>(
        MaterialPageRoute(
          builder: (_) => _TossPaymentPage(
            clientKey: _clientKey,
            customerKey: customerEmail.isNotEmpty ? customerEmail : 'anonymous',
            orderId: idempotencyKey,
            orderName: orderName,
            customerEmail: customerEmail,
            customerName: customerName,
            amount: amount,
          ),
        ),
      );

      if (result == null) {
        return const TossPaymentCancelled();
      }

      if (result.success != null) {
        return TossPaymentSuccess(
          paymentKey: result.success!.paymentKey,
          orderId: result.success!.orderId,
          amount: result.success!.amount.toInt(),
        );
      }

      if (result.fail != null) {
        final code = result.fail!.errorCode;
        // 사용자 취소 코드 처리
        if (code == 'USER_CANCEL' || code == 'PAY_PROCESS_CANCELED') {
          return const TossPaymentCancelled();
        }
        return TossPaymentFailure(
          code: code,
          message: result.fail!.errorMessage,
        );
      }

      // pending (해외 간편결제 등) — 현재 미지원, 취소로 처리
      return const TossPaymentCancelled();
    } catch (e) {
      return TossPaymentFailure(code: 'UNKNOWN', message: e.toString());
    }
  }
}

/// 토스페이먼츠 결제 위젯 페이지.
///
/// [PaymentMethodWidget] + [AgreementWidget] 을 렌더링하고
/// "결제하기" 버튼으로 [PaymentWidget.requestPayment] 를 실행한다.
/// 결과(Result)를 pop 으로 반환한다.
class _TossPaymentPage extends StatefulWidget {
  const _TossPaymentPage({
    required this.clientKey,
    required this.customerKey,
    required this.orderId,
    required this.orderName,
    required this.customerEmail,
    required this.customerName,
    required this.amount,
  });

  final String clientKey;
  final String customerKey;
  final String orderId;
  final String orderName;
  final String customerEmail;
  final String customerName;
  final int amount;

  @override
  State<_TossPaymentPage> createState() => _TossPaymentPageState();
}

class _TossPaymentPageState extends State<_TossPaymentPage> {
  late final PaymentWidget _paymentWidget;
  AgreementWidgetControl? _agreementControl;
  bool _isRequestingPayment = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _paymentWidget = PaymentWidget(
      clientKey: widget.clientKey,
      customerKey: widget.customerKey,
    );

    () async {
      try {
        await _paymentWidget.renderPaymentMethods(
          selector: 'methods',
          amount: Amount(value: widget.amount),
        );
      } catch (e) {
        if (mounted) setState(() => _initError = _formatInitError(e));
      }
    }();

    _paymentWidget
        .renderAgreement(selector: 'agreement')
        .then((control) {
      if (mounted) {
        setState(() => _agreementControl = control);
      }
    }).catchError((e) {
      if (mounted && _initError == null) {
        setState(() => _initError = _formatInitError(e));
      }
    });
  }

  String _formatInitError(Object e) {
    if (e is Fail) {
      final code = e.errorCode;
      final msg = e.errorMessage;
      if (code == 'INVALID_CLIENT_KEY' || code == 'NOT_FOUND_CLIENT_KEY') {
        return 'Toss client key 가 잘못되었습니다. --dart-define=TOSS_CLIENT_KEY=test_ck_xxx 로 실행했는지 확인해 주세요. (코드: $code)';
      }
      return '$msg (코드: $code)';
    }
    return e.toString();
  }

  Future<void> _handlePay() async {
    if (_isRequestingPayment) return;

    final agreementStatus = await _agreementControl?.getAgreementStatus();
    if (agreementStatus?.agreedRequiredTerms != true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필수 약관에 동의해 주세요')),
      );
      return;
    }

    setState(() => _isRequestingPayment = true);
    try {
      final result = await _paymentWidget.requestPayment(
        paymentInfo: PaymentInfo(
          orderId: widget.orderId,
          orderName: widget.orderName,
          customerEmail: widget.customerEmail.isNotEmpty ? widget.customerEmail : null,
          customerName: widget.customerName.isNotEmpty ? widget.customerName : null,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      // pop with fail result
      Navigator.of(context).pop(
        Result(fail: Fail('UNKNOWN', e.toString(), widget.orderId)),
      );
    } finally {
      if (mounted) setState(() => _isRequestingPayment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.textHeading,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '결제',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeading,
          ),
        ),
      ),
      body: _initError != null
          ? _ErrorView(
              message: _initError!,
              onBack: () => Navigator.of(context).pop(),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      PaymentMethodWidget(
                        paymentWidget: _paymentWidget,
                        selector: 'methods',
                      ),
                      AgreementWidget(
                        paymentWidget: _paymentWidget,
                        selector: 'agreement',
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceElevated,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  padding:
                      EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
                  child: SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isRequestingPayment ? null : _handlePay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        disabledBackgroundColor: AppColors.surface,
                        disabledForegroundColor: AppColors.textMuted,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isRequestingPayment
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : const Text(
                              '결제하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onBack});
  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              '결제 초기화 중 오류가 발생했습니다',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textHeading,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onBack,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('돌아가기'),
            ),
          ],
        ),
      ),
    );
  }
}
