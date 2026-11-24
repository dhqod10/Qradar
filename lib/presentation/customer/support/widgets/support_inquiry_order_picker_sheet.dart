import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qradar/core/theme/app_colors.dart';
import 'package:qradar/presentation/customer/order/orders/providers/order_view_providers.dart';
import 'package:qradar/presentation/customer/support/providers/support_inquiry_providers.dart';
import 'package:qradar/presentation/customer/support/widgets/support_inquiry_order_summary.dart';

/// 문의할 주문 선택 시트. 최근 주문 10건(`myOrdersProvider` — 최신순 스트림).
///
/// spec 은 `users/{uid}/orderLogs` 를 제안했으나 logId 는 orderId 가 아니라(`verifyTossPayment` 의 uuid 별도 발급)
/// CF 가 검증할 `orders/{orderId}` 를 얻을 수 없어 기존 주문 스트림을 재사용한다.
/// 선택하면 [LinkedOrder] 로 pop, '연결 안 함' 은 [kNoOrderSelected] 로 pop.
const Object kNoOrderSelected = Object();

Future<Object?> showSupportInquiryOrderPicker(
  BuildContext context, {
  String? selectedOrderId,
}) {
  return showModalBottomSheet<Object>(
    context: context,
    backgroundColor: AppColors.surfaceElevated,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _OrderPickerSheet(selectedOrderId: selectedOrderId),
  );
}

class _OrderPickerSheet extends ConsumerWidget {
  const _OrderPickerSheet({this.selectedOrderId});

  final String? selectedOrderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '문의할 주문 선택',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeading,
                  ),
                ),
              ),
            ),
            Flexible(
              child: orders.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
                error: (_, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '주문을 불러오지 못했어요',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(myOrdersProvider),
                        child: const Text(
                          '다시 시도',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                data: (list) {
                  final recent = list.take(10).toList(growable: false);
                  if (recent.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          '최근 주문이 없어요',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: recent.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, i) {
                      final o = recent[i];
                      return InkWell(
                        onTap: () =>
                            Navigator.of(context).pop(LinkedOrder.fromOrder(o)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: SupportInquiryOrderSummary(
                                  storeName: o.storeName,
                                  pickupNumber: o.pickupNumber,
                                  totalPrice: o.totalPrice,
                                  date: o.createdAt,
                                ),
                              ),
                              Icon(
                                o.id == selectedOrderId
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                size: 20,
                                color: o.id == selectedOrderId
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(kNoOrderSelected),
              child: const Text(
                '연결 안 함',
                style: TextStyle(color: AppColors.textBody),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
