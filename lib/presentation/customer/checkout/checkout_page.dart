import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/core/utils/price_formatter.dart';
import 'package:qradar/domain/entities/cart_entity.dart';
import 'package:qradar/domain/entities/cart_item_entity.dart';
import 'package:qradar/domain/entities/order_item_entity.dart';
import 'package:qradar/domain/entities/payment_method.dart';
import 'package:qradar/presentation/customer/auth/providers/user_profile_provider.dart';
import 'package:qradar/presentation/customer/cart/providers/cart_providers.dart';
import 'package:qradar/presentation/customer/checkout/payment_result_page.dart';
import 'package:qradar/presentation/customer/checkout/widgets/checkout_summary_card.dart';
import 'package:qradar/presentation/customer/checkout/widgets/payment_method_tile.dart';
import 'package:qradar/presentation/customer/order/orders/providers/order_di_providers.dart';
import 'package:qradar/presentation/customer/order/widgets/price_summary.dart';

OrderItemEntity _toOrderItem(CartItemEntity c) => OrderItemEntity(
      menuItemId: c.menuItemId,
      menuItemName: c.menuItemName,
      imageUrl: c.imageUrl,
      quantity: c.quantity,
      selectedOptions: c.selectedOptions,
      unitPriceWithOptions: c.unitPriceWithOptions,
      lineTotal: c.lineTotal,
    );

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  PaymentMethod? _selectedMethod;
  bool _tosAgreed = false;
  bool _privacyAgreed = false;
  bool _processing = false;

  bool get _allAgreed => _tosAgreed && _privacyAgreed;
  bool get _canPay =>
      _selectedMethod != null && _allAgreed && !_processing;

  Future<void> _handlePay(CartEntity cart) async {
    final method = _selectedMethod;
    if (method == null) return;

    final profile = ref.read(currentUserProfileProvider).asData?.value;
    if (profile == null) return;

    setState(() => _processing = true);

    const uuid = Uuid();
    final idempotencyKey = uuid.v4();
    final amount = cart.subtotal;
    final items = cart.items;
    final orderName = items.isNotEmpty
        ? (items.length > 1
            ? '${items.first.menuItemName} 외 ${items.length - 1}건'
            : items.first.menuItemName)
        : '주문';

    try {
      final launchResult = await ref
          .read(launchPaymentUseCaseProvider)
          .call(
            context: context,
            method: method,
            idempotencyKey: idempotencyKey,
            amount: amount,
            orderName: orderName,
            customerEmail: profile.email ?? '',
            customerName: profile.displayName ?? 'Qrator',
          );

      if (!mounted) return;

      if (launchResult.cancelled) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const PaymentResultPage(
              variant: PaymentResultVariant.cancelled,
            ),
          ),
        );
        return;
      }

      if (!launchResult.success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PaymentResultPage(
              variant: PaymentResultVariant.fail,
              errorCode: launchResult.errorCode,
              errorMessage: launchResult.errorMessage,
            ),
          ),
        );
        return;
      }

      // 결제 성공 → verify & create order
      final paymentKey = launchResult.paymentKey!;
      final orderId = launchResult.orderId!;

      try {
        final order = await ref
            .read(verifyAndCreateOrderUseCaseProvider)
            .call(
              paymentKey: paymentKey,
              orderId: orderId,
              amount: amount,
              cartSnapshot: cart,
              uid: profile.uid,
              paymentMethod: method,
            );

        if (!mounted) return;

        await ref.read(clearCartUseCaseProvider).call();

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PaymentResultPage(
              variant: PaymentResultVariant.success,
              orderId: order.id,
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PaymentResultPage(
              variant: PaymentResultVariant.fail,
              errorMessage: e.toString(),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PaymentResultPage(
            variant: PaymentResultVariant.fail,
            errorMessage: e.toString(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);
    final cart = cartAsync.value;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return IgnorePointer(
      ignoring: _processing,
      child: Scaffold(
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
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text(
            '결제하기',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textHeading,
            ),
          ),
          centerTitle: false,
          bottom: _processing
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    color: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    minHeight: 2,
                  ),
                )
              : null,
        ),
        body: cart == null
            ? const _EmptyCart()
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CheckoutSummaryCard(
                            storeName: cart.storeName,
                            items: cart.items.map(_toOrderItem).toList(),
                            totalPrice: cart.subtotal,
                          ),
                          const SizedBox(height: 24),
                          _SectionHeader(title: '결제 수단'),
                          const SizedBox(height: 12),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                PaymentMethodTile(
                                  method: PaymentMethod.card,
                                  selected:
                                      _selectedMethod == PaymentMethod.card,
                                  onTap: () => setState(
                                      () => _selectedMethod = PaymentMethod.card),
                                ),
                                const SizedBox(height: 10),
                                PaymentMethodTile(
                                  method: PaymentMethod.kakaoPay,
                                  selected:
                                      _selectedMethod == PaymentMethod.kakaoPay,
                                  onTap: () => setState(() =>
                                      _selectedMethod = PaymentMethod.kakaoPay),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _SectionHeader(title: '약관 동의'),
                          const SizedBox(height: 8),
                          _TermsSection(
                            tosAgreed: _tosAgreed,
                            privacyAgreed: _privacyAgreed,
                            allAgreed: _allAgreed,
                            onAllChanged: (v) => setState(() {
                              _tosAgreed = v;
                              _privacyAgreed = v;
                            }),
                            onTosChanged: (v) =>
                                setState(() => _tosAgreed = v),
                            onPrivacyChanged: (v) =>
                                setState(() => _privacyAgreed = v),
                          ),
                          const SizedBox(height: 24),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: PriceSummary(
                              subtotal: cart.subtotal,
                              total: cart.subtotal,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceElevated,
                      border: Border(
                          top: BorderSide(color: AppColors.border)),
                    ),
                    padding: EdgeInsets.fromLTRB(
                        20, 12, 20, 12 + bottomInset),
                    child: SizedBox(
                      height: 54,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _canPay ? () => _handlePay(cart) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _canPay
                              ? AppColors.primary
                              : AppColors.surface,
                          foregroundColor: _canPay
                              ? AppColors.onPrimary
                              : AppColors.textMuted,
                          disabledBackgroundColor: AppColors.surface,
                          disabledForegroundColor: AppColors.textMuted,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _processing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.onPrimary,
                                ),
                              )
                            : Text(
                                '${PriceFormatter.formatKrw(cart.subtotal)} 결제하기',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textHeading,
        ),
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection({
    required this.tosAgreed,
    required this.privacyAgreed,
    required this.allAgreed,
    required this.onAllChanged,
    required this.onTosChanged,
    required this.onPrivacyChanged,
  });

  final bool tosAgreed;
  final bool privacyAgreed;
  final bool allAgreed;
  final ValueChanged<bool> onAllChanged;
  final ValueChanged<bool> onTosChanged;
  final ValueChanged<bool> onPrivacyChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          _TermsRow(
            label: '전체 동의',
            agreed: allAgreed,
            onChanged: onAllChanged,
            bold: true,
          ),
          const Divider(
              color: AppColors.border, height: 1, thickness: 1,
              indent: 16, endIndent: 16),
          _TermsRow(
            label: '(필수) 전자결제 이용 약관',
            agreed: tosAgreed,
            onChanged: onTosChanged,
          ),
          _TermsRow(
            label: '(필수) 개인정보 처리방침 동의',
            agreed: privacyAgreed,
            onChanged: onPrivacyChanged,
          ),
        ],
      ),
    );
  }
}

class _TermsRow extends StatelessWidget {
  const _TermsRow({
    required this.label,
    required this.agreed,
    required this.onChanged,
    this.bold = false,
  });

  final String label;
  final bool agreed;
  final ValueChanged<bool> onChanged;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: agreed,
          onChanged: (v) => onChanged(v ?? false),
          activeColor: AppColors.primary,
          checkColor: AppColors.onPrimary,
          side: const BorderSide(color: AppColors.border),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: bold ? 14 : 13,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              color: bold ? AppColors.textHeading : AppColors.textBody,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shopping_bag_outlined,
              size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text(
            '카트가 비어있어요',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textHeading),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('카트로 돌아가기',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
